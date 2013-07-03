Attribute VB_Name = "Selection_Handler"
'***************************************************************************
'Selection Interface
'Copyright �2012-2013 by Tanner Helland
'Created: 21/June/13
'Last updated: 26/June/13
'Last update: user-facing implementations of load/save selections to file
'
'Selection tools have existed in PhotoDemon for awhile, but this module is the first to support Process varieties of
' selection operations - e.g. internal actions like "Process "Create Selection"".  Selection commands must be passed
' through the Process module so they can be recorded as macros, and as part of the program's Undo/Redo chain.  This
' module provides all selection-related functions that the Process module can call.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://www.tannerhelland.com/photodemon/#license
'
'***************************************************************************

Option Explicit

'Create a new selection using the settings stored in a pdParamString-compatible string
Public Sub CreateNewSelection(ByVal paramString As String)
    
    'Use the passed parameter string to initialize the selection
    pdImages(CurrentImage).mainSelection.initFromParamString paramString
    pdImages(CurrentImage).mainSelection.lockIn pdImages(CurrentImage).containingForm
    pdImages(CurrentImage).selectionActive = True
    
    'Change the selection-related menu items to match
    tInit tSelection, True
    
    'Draw the new selection to the screen
    RenderViewport pdImages(CurrentImage).containingForm

End Sub

'Create a new selection using the settings stored in a pdParamString-compatible string
Public Sub RemoveCurrentSelection(Optional ByVal paramString As String)
    
    'Use the passed parameter string to initialize the selection
    pdImages(CurrentImage).mainSelection.lockRelease
    pdImages(CurrentImage).selectionActive = False
    
    'Change the selection-related menu items to match
    tInit tSelection, False
    
    'Redraw the image (with selection removed)
    RenderViewport pdImages(CurrentImage).containingForm

End Sub

'Create a new selection using the settings stored in a pdParamString-compatible string
Public Sub SelectWholeImage()
    
    'Unselect any existing selection
    pdImages(CurrentImage).mainSelection.lockRelease
    pdImages(CurrentImage).selectionActive = False
    
    'Select the rectangular selection tool
    g_PreviousTool = g_CurrentTool
    g_CurrentTool = 0
    FormMain.selectNewTool 0
        
    'Create a new selection at the size of the image
    pdImages(CurrentImage).mainSelection.selectAll
    
    'Lock in this selection
    pdImages(CurrentImage).mainSelection.lockIn pdImages(CurrentImage).containingForm
    pdImages(CurrentImage).selectionActive = True
    
    'Change the selection-related menu items to match
    tInit tSelection, True
    
    'Draw the new selection to the screen
    RenderViewport pdImages(CurrentImage).containingForm

End Sub

'Load a previously saved selection.  Note that this function also handles creation and display of the relevant common dialog.
Public Sub LoadSelectionFromFile()

    'Simple open dialog
    Dim CC As cCommonDialog
        
    Dim sFile As String
    Set CC = New cCommonDialog
    
    Dim cdFilter As String
    cdFilter = PROGRAMNAME & " " & g_Language.TranslateMessage("Selection") & " (." & SELECTION_EXT & ")|*." & SELECTION_EXT & "|"
    cdFilter = cdFilter & g_Language.TranslateMessage("All files") & "|*.*"
    
    Dim cdTitle As String
    cdTitle = g_Language.TranslateMessage("Load a previously saved selection")
    
    If CC.VBGetOpenFileName(sFile, , , , , True, cdFilter, , g_UserPreferences.getSelectionPath, cdTitle, , FormMain.hWnd, 0) Then
        
        Dim tmpSelection As pdSelection
        Set tmpSelection = New pdSelection
        Set tmpSelection.containingPDImage = pdImages(CurrentImage)
        
        If tmpSelection.readSelectionFromFile(sFile, True) Then
            
            'Save the new directory as the default path for future usage
            g_UserPreferences.setSelectionPath sFile
            
            'Activate and redraw the seletion
            Process "Load selection", False, tmpSelection.getSelectionParamString, 2
            
        Else
            pdMsgBox "An error occurred while attempting to load %1.  Please verify that the file is a valid PhotoDemon selection file.", vbOKOnly + vbExclamation + vbApplicationModal, "Selection Error", sFile
        End If
        
        'Release the temporary selection object
        Set tmpSelection.containingPDImage = Nothing
        Set tmpSelection = Nothing
        
    End If
    
End Sub

'Save the current selection to file.  Note that this function also handles creation and display of the relevant common dialog.
Public Sub SaveSelectionToFile()

    'Simple save dialog
    Dim CC As cCommonDialog
        
    Dim sFile As String
    Set CC = New cCommonDialog
    
    Dim cdFilter As String
    cdFilter = PROGRAMNAME & " " & g_Language.TranslateMessage("Selection") & " (." & SELECTION_EXT & ")|*." & SELECTION_EXT
    
    Dim cdTitle As String
    cdTitle = g_Language.TranslateMessage("Save the current selection")
    
    If CC.VBGetSaveFileName(sFile, , True, cdFilter, , g_UserPreferences.getSelectionPath, cdTitle, "." & SELECTION_EXT, FormMain.hWnd, 0) Then
        
        'Save the new directory as the default path for future usage
        g_UserPreferences.setSelectionPath sFile
        
        'Write out the selection file
        If pdImages(CurrentImage).mainSelection.writeSelectionToFile(sFile) Then
            Message "Selection saved."
        Else
            Message "Unknown error occurred.  Selection was not saved.  Please try again."
        End If
        
    End If
    
End Sub

'Use this to populate the text boxes on the main form with the current selection values
Public Sub syncTextToCurrentSelection(ByVal formID As Long)

    'Only synchronize the text boxes if a selection is active and transformable; otherwise, clear them
    If (NumOfWindows > 0) And pdImages(formID).selectionActive And (Not pdImages(formID).mainSelection Is Nothing) And pdImages(formID).mainSelection.isTransformable Then
        
        tInit tSelectionTransform, True
        pdImages(formID).mainSelection.rejectRefreshRequests = True
        
        'Different types of selections will display size and position differently
        Select Case pdImages(formID).mainSelection.getSelectionShape
        
            'Rectangular and elliptical selections display left, top, width and height
            Case sRectangle, sCircle
                FormMain.tudSel(0).Value = pdImages(formID).mainSelection.selLeft
                FormMain.tudSel(1).Value = pdImages(formID).mainSelection.selTop
                FormMain.tudSel(2).Value = pdImages(formID).mainSelection.selWidth
                FormMain.tudSel(3).Value = pdImages(formID).mainSelection.selHeight
    
            'Line selections display x1, y1, x2, y2
            Case sLine
                FormMain.tudSel(0).Value = pdImages(formID).mainSelection.x1
                FormMain.tudSel(1).Value = pdImages(formID).mainSelection.y1
                FormMain.tudSel(2).Value = pdImages(formID).mainSelection.x2
                FormMain.tudSel(3).Value = pdImages(formID).mainSelection.y2
    
        End Select
    
        pdImages(formID).mainSelection.rejectRefreshRequests = False
    
    Else
    
        tInit tSelectionTransform, False
        Dim i As Long
        For i = 0 To FormMain.tudSel.Count - 1
            FormMain.tudSel(i).Value = 0
        Next i
        
    End If
    
End Sub

'This sub will return a constant correlating to the nearest selection point. Its return values are:
' 0 - Cursor is not near a selection point
' 1 - NW corner
' 2 - NE corner
' 3 - SE corner
' 4 - SW corner
' 5 - N edge
' 6 - E edge
' 7 - S edge
' 8 - W edge
' 9 - interior of selection, not near a corner or edge
Public Function findNearestSelectionCoordinates(ByRef x1 As Single, ByRef y1 As Single, ByRef srcForm As Form) As Long

    'If the current selection is NOT transformable, return 0.
    If Not pdImages(srcForm.Tag).mainSelection.isTransformable Then
        findNearestSelectionCoordinates = 0
        Exit Function
    End If

    'Grab the current zoom value
    Dim ZoomVal As Double
    ZoomVal = g_Zoom.ZoomArray(pdImages(srcForm.Tag).CurrentZoomValue)

    'Calculate x and y positions, while taking into account zoom and scroll values
    x1 = srcForm.HScroll.Value + Int((x1 - pdImages(srcForm.Tag).targetLeft) / ZoomVal)
    y1 = srcForm.VScroll.Value + Int((y1 - pdImages(srcForm.Tag).targetTop) / ZoomVal)
    
    'With x1 and y1 now representative of a location within the image, it's time to start calculating distances.
    Dim tLeft As Double, tTop As Double, tRight As Double, tBottom As Double
    
    If (pdImages(srcForm.Tag).mainSelection.getSelectionShape = sRectangle) Or (pdImages(srcForm.Tag).mainSelection.getSelectionShape = sCircle) Then
        tLeft = pdImages(srcForm.Tag).mainSelection.selLeft
        tTop = pdImages(srcForm.Tag).mainSelection.selTop
        tRight = pdImages(srcForm.Tag).mainSelection.selLeft + pdImages(srcForm.Tag).mainSelection.selWidth
        tBottom = pdImages(srcForm.Tag).mainSelection.selTop + pdImages(srcForm.Tag).mainSelection.selHeight
    Else
        tLeft = pdImages(srcForm.Tag).mainSelection.boundLeft
        tTop = pdImages(srcForm.Tag).mainSelection.boundTop
        tRight = pdImages(srcForm.Tag).mainSelection.boundLeft + pdImages(srcForm.Tag).mainSelection.boundWidth
        tBottom = pdImages(srcForm.Tag).mainSelection.boundTop + pdImages(srcForm.Tag).mainSelection.boundHeight
    End If
    
    'Adjust the mouseAccuracy value based on the current zoom value
    Dim mouseAccuracy As Double
    mouseAccuracy = mouseSelAccuracy * (1 / ZoomVal)
    
    'Before doing anything else, make sure the pointer is actually worth checking - e.g. make sure it's near the selection
    'If (x1 < tLeft - mouseAccuracy) Or (x1 > tRight + mouseAccuracy) Or (y1 < tTop - mouseAccuracy) Or (y1 > tBottom + mouseAccuracy) Then
    '    findNearestSelectionCoordinates = 0
    '    Exit Function
    'End If
    
    'Find the smallest distance for this mouse position
    Dim minDistance As Double
    minDistance = mouseAccuracy
    
    Dim closestPoint As Long
    
    'If we made it here, this mouse location is worth evaluating.  How we evaluate it depends on the shape of the current selection.
    Select Case pdImages(srcForm.Tag).mainSelection.getSelectionShape
    
        Case SELECT_RECT, SELECT_CIRC
    
            'Corners get preference, so check them first.
            Dim nwDist As Double, neDist As Double, seDist As Double, swDist As Double
            
            nwDist = distanceTwoPoints(x1, y1, tLeft, tTop)
            neDist = distanceTwoPoints(x1, y1, tRight, tTop)
            swDist = distanceTwoPoints(x1, y1, tLeft, tBottom)
            seDist = distanceTwoPoints(x1, y1, tRight, tBottom)
            
            'Find the smallest distance for this mouse position
            closestPoint = -1
            
            If nwDist <= minDistance Then
                minDistance = nwDist
                closestPoint = 1
            End If
            
            If neDist <= minDistance Then
                minDistance = neDist
                closestPoint = 2
            End If
            
            If seDist <= minDistance Then
                minDistance = seDist
                closestPoint = 3
            End If
            
            If swDist <= minDistance Then
                minDistance = swDist
                closestPoint = 4
            End If
            
            'Was a close point found? If yes, then return that value
            If closestPoint <> -1 Then
                findNearestSelectionCoordinates = closestPoint
                Exit Function
            End If
        
            'If we're at this line of code, a closest corner was not found. So check edges next.
            Dim nDist As Double, eDist As Double, sDist As Double, wDist As Double
            
            nDist = distanceOneDimension(y1, tTop)
            eDist = distanceOneDimension(x1, tRight)
            sDist = distanceOneDimension(y1, tBottom)
            wDist = distanceOneDimension(x1, tLeft)
            
            If (nDist <= minDistance) And (x1 > (tLeft - minDistance)) And (x1 < (tRight + minDistance)) Then
                minDistance = nDist
                closestPoint = 5
            End If
            
            If (eDist <= minDistance) And (y1 > (tTop - minDistance)) And (y1 < (tBottom + minDistance)) Then
                minDistance = eDist
                closestPoint = 6
            End If
            
            If (sDist <= minDistance) And (x1 > (tLeft - minDistance)) And (x1 < (tRight + minDistance)) Then
                minDistance = sDist
                closestPoint = 7
            End If
            
            If (wDist <= minDistance) And (y1 > (tTop - minDistance)) And (y1 < (tBottom + minDistance)) Then
                minDistance = wDist
                closestPoint = 8
            End If
            
            'Was a close point found? If yes, then return that value.
            If closestPoint <> -1 Then
                findNearestSelectionCoordinates = closestPoint
                Exit Function
            End If
        
            'If we're at this line of code, a closest edge was not found. Perform one final check to ensure that the mouse is within the
            ' image's boundaries, and if it is, return the "move selection" ID, then exit.
            If (x1 > tLeft) And (x1 < tRight) And (y1 > tTop) And (y1 < tBottom) Then
                findNearestSelectionCoordinates = 9
            Else
                findNearestSelectionCoordinates = 0
            End If
            
        Case SELECT_LINE
    
            'Line selections are simple - we only care if the mouse is by (x1,y1) or (x2,y2)
            Dim xCoord As Double, yCoord As Double
            Dim firstDist As Double, secondDist As Double
            
            closestPoint = 0
            
            pdImages(srcForm.Tag).mainSelection.getSelectionCoordinates 1, xCoord, yCoord
            firstDist = distanceTwoPoints(x1, y1, xCoord, yCoord)
            
            pdImages(srcForm.Tag).mainSelection.getSelectionCoordinates 2, xCoord, yCoord
            secondDist = distanceTwoPoints(x1, y1, xCoord, yCoord)
                        
            If firstDist <= minDistance Then closestPoint = 1
            If secondDist <= minDistance Then closestPoint = 2
            
            'Was a close point found? If yes, then return that value.
            findNearestSelectionCoordinates = closestPoint
            Exit Function
            
        Case Else
            findNearestSelectionCoordinates = 0
            Exit Function
            
    End Select

End Function

