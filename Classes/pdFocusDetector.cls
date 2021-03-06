VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "pdFocusDetector"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon Window Focus Detection class
'Copyright 2014-2016 by Tanner Helland
'Created: 07/May/15  (but built from many parts existing earlier)
'Last updated: 07/May/15
'Last update: abstract API focus detection bits into this class, so I don't have to keep copying the code into new UCs
'
'VB's internal Got/LostFocus events play very poorly with PD, as we generate a lot of our own API windows for
' various controls.  To receive failsafe Got/LostFocus events, simply add this class to a user control and initialize
' it with the hWnd you want tracked.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'This class raises correct Got/LostFocus events for any window, by subclassing both WM_NCACTIVATE (generally not needed,
' except for top-level windows) and WM_SETFOCUS/WM_KILLFOCUS.
Public Event GotFocusReliable()
Public Event LostFocusReliable()

'Various subclassing constants
Private Const WM_ACTIVATE As Long = &H6
Private Const WM_NCACTIVATE As Long = &H86
Private Const WA_INACTIVE      As Long = 0
Private Const WA_ACTIVE        As Long = 1
Private Const WA_CLICKACTIVE   As Long = 2

Private Const WM_SETFOCUS As Long = &H7
Private Const WM_KILLFOCUS As Long = &H8

'The window being subclassed
Private m_hWnd As Long

'Subclasser for intercepting window messages
Private cSubclass As cSelfSubHookCallback

'If the window currently has focus, this will be set to TRUE.
Private m_HasFocus As Boolean

Private Sub Class_Initialize()
    m_hWnd = 0
End Sub

Private Sub Class_Terminate()
    If ((m_hWnd <> 0) And (Not cSubclass Is Nothing) And g_IsProgramRunning) Then
        cSubclass.ssc_UnSubclass m_hWnd
        cSubclass.ssc_Terminate
    End If
End Sub

'This function should be called in a UserControl's Initialize event.  For best results, check for the IDE and do not
' load this class.
Public Sub StartFocusTracking(ByVal srcHwnd As Long)
    
    'Release any existing subclassers
    If ((Not (cSubclass Is Nothing)) And (m_hWnd <> 0)) And g_IsProgramRunning Then
        cSubclass.ssc_UnSubclass m_hWnd
        cSubclass.ssc_Terminate
    End If
    
    m_hWnd = srcHwnd
    
    'Subclass all necessary messages for proper focus detection
    If ((m_hWnd <> 0) And g_IsProgramRunning) Then
        Set cSubclass = New cSelfSubHookCallback
        cSubclass.ssc_Subclass m_hWnd, , , Me
        cSubclass.ssc_AddMsg m_hWnd, MSG_BEFORE, WM_NCACTIVATE, WM_KILLFOCUS, WM_SETFOCUS
    End If
    
End Sub

'Outside functions can use this to retrieve the current "has focus" state of the tracked control
Public Function HasFocus() As Boolean
    HasFocus = m_HasFocus
End Function

'If an outside function received a mouse or keyboard event but the control does *not* have focus, they can call this function
' to force an immedate GotFocus event.  (Windows will process hooks prior to focus messages, so some of PD's controls may raise
' input events prior to receiving focus events; this function gives us a way to work around that.)
Public Sub SetFocusManually()
    If (Not m_HasFocus) Then g_WindowManager.SetFocusAPI m_hWnd
End Sub

Private Function GetHiWord(ByVal lParam As Long) As Integer
    If lParam And &H80000000 Then
        GetHiWord = (lParam \ 65535) - 1
    Else
        GetHiWord = lParam \ 65535
    End If
End Function

Private Function GetLoWord(ByVal lParam As Long) As Integer
    If lParam And &H8000& Then
        GetLoWord = &H8000 Or (lParam And &H7FFF&)
    Else
        GetLoWord = lParam And &HFFFF&
    End If
End Function

'All events subclassed by this window are processed here.
Private Sub myWndProc(ByVal bBefore As Boolean, _
                      ByRef bHandled As Boolean, _
                      ByRef lReturn As Long, _
                      ByVal lng_hWnd As Long, _
                      ByVal uMsg As Long, _
                      ByVal wParam As Long, _
                      ByVal lParam As Long, _
                      ByRef lParamUser As Long)
'*************************************************************************************************
'* bBefore    - Indicates whether the callback is before or after the original WndProc. Usually
'*              you will know unless the callback for the uMsg value is specified as
'*              MSG_BEFORE_AFTER (both before and after the original WndProc).
'* bHandled   - In a before original WndProc callback, setting bHandled to True will prevent the
'*              message being passed to the original WndProc and (if set to do so) the after
'*              original WndProc callback.
'* lReturn    - WndProc return value. Set as per the MSDN documentation for the message value,
'*              and/or, in an after the original WndProc callback, act on the return value as set
'*              by the original WndProc.
'* lng_hWnd   - Window handle.
'* uMsg       - Message value.
'* wParam     - Message related data.
'* lParam     - Message related data.
'* lParamUser - User-defined callback parameter. Change vartype as needed (i.e., Object, UDT, etc)
'*************************************************************************************************
    
    'By design, this subclasser does not report any messages as handled.
    bHandled = False
    
    Select Case uMsg
        
        Case WM_ACTIVATE
            
            'The low-order portion of wParam contains a notification of whether we are gaining or losing focus.
            Select Case GetLoWord(wParam)
                
                'Window is losing focus
                Case WA_INACTIVE
                    If m_HasFocus Then
                        m_HasFocus = False
                        UserControl_Support.PDControlLostFocus m_hWnd
                        RaiseEvent LostFocusReliable
                    End If
                    
                'Window is gaining focus
                Case Else
                    If (Not m_HasFocus) Then
                        m_HasFocus = True
                        UserControl_Support.PDControlReceivedFocus m_hWnd
                        RaiseEvent GotFocusReliable
                    End If
                    
            End Select
            
        'This message doesn't really apply to PD, but we cover it for completeness' sake
        Case WM_NCACTIVATE
            
            If (Not m_HasFocus) And (wParam <> 0) Then
                m_HasFocus = True
                UserControl_Support.PDControlReceivedFocus m_hWnd
                RaiseEvent GotFocusReliable
            End If
            
            If wParam <> 1 Then lReturn = 1
        
        'Window is losing focus
        Case WM_KILLFOCUS
            
            If m_HasFocus Then
                m_HasFocus = False
                UserControl_Support.PDControlLostFocus m_hWnd
                RaiseEvent LostFocusReliable
            End If
        
        'Window is gaining focus
        Case WM_SETFOCUS
            
            If (Not m_HasFocus) Then
                m_HasFocus = True
                UserControl_Support.PDControlReceivedFocus m_hWnd
                RaiseEvent GotFocusReliable
            End If
        
    End Select
    

' *************************************************************
' C A U T I O N   C A U T I O N   C A U T I O N   C A U T I O N
' -------------------------------------------------------------
' DO NOT ADD ANY OTHER CODE BELOW THE "END SUB" STATEMENT BELOW
'   add this warning banner to the last routine in your class
' *************************************************************
End Sub

