#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Scans Nexus.ahk + lib folder, updates @date, increments @version.
; * @class VersionManager
; * @location VersionManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

global CountUpdated := 0

; 1. Confirmation
if (MsgBox("Update Date & Increment Version for:`n- Nexus.ahk (Root)`n- All scripts in \lib\`n`nContinue?", "Version Manager", 4 + 32) == "No")
    ExitApp

; 2. Process Root File
if FileExist("Nexus.ahk") {
    ProcessFile("Nexus.ahk")
} else {
    MsgBox("Warning: Nexus.ahk not found in root.", "Error", 48)
}

; 3. Process Library Files (Recursive)
Loop Files, A_ScriptDir . "\lib\*.ahk", "R" {
    ProcessFile(A_LoopFileFullPath)
}

; 4. Result
MsgBox("Success!`nUpdated " . CountUpdated . " files to today's timestamp and new version.", "Version Manager", 64)

; --- CORE LOGIC ---
ProcessFile(filePath) {
    global CountUpdated
    try {
        fileContent := FileRead(filePath)
        isModified := false

        ; A. Update Date
        ; Looks for: * @date YYYY/MM/DD
        currentDate := FormatTime(, "yyyy/MM/dd")
        if RegExMatch(fileContent, "i)\* @date\s+\d{4}/\d{2}/\d{2}", &match) {
            if (match[0] != "* @date " . currentDate) {
                fileContent := RegExReplace(fileContent, "i)\* @date\s+\d{4}/\d{2}/\d{2}", "* @date " . currentDate)
                isModified := true
            }
        }

        ; B. Increment Version
        ; Looks for: * @version 1.0.00 (or 1.0.5)
        if RegExMatch(fileContent, "i)\* @version\s+(\d+)\.(\d+)\.(\d+)", &verMatch) {
            major := verMatch[1]
            minor := verMatch[2]
            patch := Integer(verMatch[3]) + 1

            ; Auto-detect padding: if old was '05', new is '06'. If old was '5', new is '6'.
            strLenOld := StrLen(verMatch[3])
            newPatchStr := (strLenOld >= 2) ? Format("{:02}", patch) : patch

            newVersion := "* @version " . major . "." . minor . "." . newPatchStr

            fileContent := StrReplace(fileContent, verMatch[0], newVersion)
            isModified := true
        }

        ; C. Save
        if (isModified) {
            FileOpen(filePath, "w").Write(fileContent)
            CountUpdated++
        }

    } catch as err {
        MsgBox("Error processing: " . filePath . "`n" . err.Message)
    }
}