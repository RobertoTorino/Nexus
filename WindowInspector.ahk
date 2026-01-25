#Requires AutoHotkey v2.0
#SingleInstance Force

F11::
{
    Output := "=== WINDOW INSPECTION REPORT ===`n`n"

    ; 1. Detect Hidden Windows is CRITICAL
    DetectHiddenWindows(true)

    ; 2. Define target processes to look for
    TargetProcs := ["TeknoParrotUi.exe", "TeknoParrot.exe", "BudgieLoader.exe", "Play.exe", "game.exe", "elfldr2.exe", "sdaemon.exe", "parrotloader.exe", "OpenParrotLoader.exe", "OpenParrotLoader64.exe"]

    Output .= "--- PROCESS SCAN ---`n"
    FoundPIDs := Map()

    ; Scan all running processes
    for proc in TargetProcs {
        pid := ProcessExist(proc)
        if (pid) {
            Output .= "Found Process: " proc " (PID: " pid ")`n"
            FoundPIDs[pid] := proc
        }
    }

    Output .= "`n--- WINDOW DUMP ---`n"

    ; Get ALL windows in the system
    AllIds := WinGetList()

    count := 0
    for hwnd in AllIds {
        try {
            ; Get Process Name and PID for this window
            thisPid := WinGetPID("ahk_id " hwnd)
            thisProc := WinGetProcessName("ahk_id " hwnd)

            ; Check if this window belongs to one of our target PIDs OR has a suspicious title
            isTarget := false
            if (FoundPIDs.Has(thisPid))
                isTarget := true

            thisTitle := WinGetTitle("ahk_id " hwnd)

            ; Check specifically for the title keywords
            if (InStr(thisTitle, "Tekno") || InStr(thisTitle, "Play!") || InStr(thisTitle, "TK5"))
                isTarget := true

            if (isTarget) {
                count++

                ; Gather Deep Details
                thisClass := WinGetClass("ahk_id " hwnd)
                WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
                style := WinGetStyle("ahk_id " hwnd)
                exStyle := WinGetExStyle("ahk_id " hwnd)

                isVisible := (style & 0x10000000) ? "YES" : "NO"

                Output .= "--------------------------------------------------`n"
                Output .= "HWND:      " hwnd "`n"
                Output .= "Title:     " (thisTitle = "" ? "[NO TITLE]" : thisTitle) "`n"
                Output .= "Class:     " thisClass "`n"
                Output .= "Process:   " thisProc " (PID: " thisPid ")`n"
                Output .= "Geometry:  x" x " y" y " w" w " h" h "`n"
                Output .= "Visible:   " isVisible "`n"
                Output .= "Style:     " Format("0x{:X}", style) "`n"
                Output .= "ExStyle:   " Format("0x{:X}", exStyle) "`n"
            }
        }
    }

    if (count == 0)
        Output .= "No TeknoParrot/Loader windows found!`n"

    ; Copy to clipboard automatically
    A_Clipboard := Output
    MsgBox(Output, "Debug Report (Copied to Clipboard)")
}