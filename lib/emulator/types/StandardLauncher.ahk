#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Handles .exe and .bat execution with Chain-Load Detection.
; * @class StandardLauncher
; * @location lib/emulator/types/StandardLauncher.ahk
; * @author Philip
; * @date 2026/01/17
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\config\ConfigManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class StandardLauncher extends EmulatorBase {

    Pid := 0
    ExeName := ""

    ; --- WATCHER STATE ---
    SearchTimer := ""
    ScanStartTime := 0
    ScanDuration := 15000 ; Scan for 15 seconds
    OldPids := Map()

    Launch(gameObj) {
        ; 1. Resolve Path
        rawPath := ""
        if (Type(gameObj) == "Map") {
            if gameObj.Has("ApplicationPath")
                rawPath := gameObj["ApplicationPath"]
            else if gameObj.Has("Path")
                rawPath := gameObj["Path"]
        } else {
            if gameObj.HasProp("ApplicationPath")
                rawPath := gameObj.ApplicationPath
            else if gameObj.HasProp("Path")
                rawPath := gameObj.Path
        }

        ; 2. Normalize
        gamePath := StrReplace(rawPath, "/", "\")
        gamePath := StrReplace(gamePath, '"', "")

        if (gamePath == "" || !FileExist(gamePath)) {
            DialogsGui.CustomMsgBox("Launch Error", "File not found:`n" . gamePath)
            return false
        }

        ; 3. Context
        SplitPath(gamePath, &exeName, &dir, &ext)
        this.ExeName := exeName

        ; [CRITICAL] Snapshot running processes BEFORE launch
        this.OldPids := this.GetProcessList()

        if IsSet(Logger)
            Logger.Info("StandardLauncher: Starting " . exeName, this.__Class)

        try {
            ; 4. EXECUTE
            oldDir := A_WorkingDir
            SetWorkingDir(dir)

            try {
                if (ext = "bat" || ext = "cmd") {
                    ; Run batch files
                    Run('"' . exeName . '"', dir, "Min", &launchPid)

                    ; Don't track the batch PID directly, use the Watcher to find the child EXE
                    ConfigManager.ActiveProcessName := ""
                }
                else {
                    ; Run Executables normally
                    Run('"' . exeName . '"', dir, "UseErrorLevel", &launchPid)

                    if (launchPid > 0) {
                        this.Pid := launchPid
                        ConfigManager.ActiveProcessName := exeName
                        WindowManager.SetGameContext("ahk_pid " launchPid, 1)
                    }
                }
            } finally {
                SetWorkingDir(oldDir)
            }

            ; 5. START SMART WATCHER (Finds the real game exe)
            this.ScanStartTime := A_TickCount
            this.SearchTimer := this.DetectNewProcess.Bind(this)
            SetTimer(this.SearchTimer, 1000)

            return true

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Failed", err.Message)
            return false
        }
    }

    ; --- SMART PROCESS DETECTION ---
    DetectNewProcess() {
        elapsed := A_TickCount - this.ScanStartTime

        ; Stop scanning after timeout
        if (elapsed > this.ScanDuration) {
            SetTimer(this.SearchTimer, 0)
            return
        }

        newPids := this.GetProcessList()
        bestPid := 0
        bestName := ""
        hasWindow := false

        ; Compare New List vs Old List
        for pid, name in newPids {
            if !this.OldPids.Has(pid) {

                ; Ignore System/Console noise
                if (name = "cmd.exe" || name = "conhost.exe" || name = "werfault.exe" || name = "taskhostw.exe" || name = "git.exe" || name = "timeout.exe")
                    continue

                thisWindow := WinExist("ahk_pid " pid)

                if (thisWindow) {
                    ; Preference 1: New Process with a Visible Window
                    bestPid := pid
                    bestName := name
                    hasWindow := true
                    break
                } else if (bestPid == 0) {
                    ; Preference 2: New Process (Background) - keep looking for a better one
                    bestPid := pid
                    bestName := name
                }
            }
        }

        ; If we found a candidate
        if (bestPid > 0) {
            ; Logic:
            ; 1. If we have NO active game tracked yet -> Take this one.
            ; 2. If we found a windowed process -> Override whatever we had.

            if (ConfigManager.ActiveProcessName == "" || (hasWindow && this.Pid != bestPid)) {

                if IsSet(Logger)
                    Logger.Info("StandardLauncher: Detected Child Process -> " bestName " (" bestPid ")", this.__Class)

                this.Pid := bestPid
                this.ExeName := bestName

                ; [CRITICAL] Update Global State so WindowManager & Kill Switch work
                ConfigManager.ActiveProcessName := bestName
                WindowManager.SetGameContext("ahk_pid " bestPid, 1)

                if IsSet(CaptureManager)
                    CaptureManager.CurrentProcessName := bestName

                if IsSet(GuiBuilder) && GuiBuilder.HasProp("StatusText")
                    GuiBuilder.StatusText.Text := " Active: " . bestName

                ; If we found a window, we are done scanning.
                if (hasWindow)
                    SetTimer(this.SearchTimer, 0)
            }
        }
    }

    GetProcessList() {
        pids := Map()
        try {
            for process in ComObjGet("winmgmts:").ExecQuery("Select ProcessId, Name from Win32_Process") {
                pids[process.ProcessId] := process.Name
            }
        }
        return pids
    }
}