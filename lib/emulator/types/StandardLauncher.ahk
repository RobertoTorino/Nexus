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
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class StandardLauncher extends EmulatorBase {

    Pid := 0
    ExeName := ""

    ; --- WATCHER STATE ---
    SearchTimer := ""
    ScanStartTime := 0
    ScanDuration := 15000 ; Scan for 15 seconds

    Launch(gameObj) {
        this.GameId := gameObj.HasProp("Id") ? gameObj.Id : ""

        ; 1. Resolve Path
        rawPath := ""
        if (gameObj.HasProp("ApplicationPath") && gameObj.ApplicationPath != "")
            rawPath := gameObj.ApplicationPath
        else if (gameObj.HasProp("Path") && gameObj.Path != "")
            rawPath := gameObj.Path

        ; 2. NORMALIZE PATH (The Critical Fix)
        ; Replace forward slashes (/) with backslashes (\) so SplitPath works correctly.
        gamePath := StrReplace(rawPath, "/", "\")

        ; Remove quotes
        gamePath := StrReplace(gamePath, '"', "")

        if (gamePath == "" || !FileExist(gamePath)) {
            DialogsGui.CustomMsgBox("Launch Error", "Game file not found:`n" . gamePath, 0x10)
            return false
        }

        ; 3. Setup Context
        SplitPath(gamePath, &exeName, &dir, &ext)
        this.ExeName := exeName

        ; SNAPSHOT: Record running processes BEFORE we launch
        oldPids := this.GetProcessList()

        Logger.Info("Launching Standard: " . gamePath)

        if IsSet(GuiBuilder)
            GuiBuilder.StatusText.Text := "Launching: " . exeName

        try {
            ; 4. EXECUTE

            if (ext = "bat" || ext = "cmd") {
                ; FORCE ENVIRONMENT CHANGE
                ; Now that 'dir' is correct (e.g. D:\PC_GAMES\...), this will work.

                savedDir := A_WorkingDir
                SetWorkingDir(dir)

                Run(exeName, , "Min", &launchPid)

                SetWorkingDir(savedDir)
            } else {
                ; Standard EXE
                Run(gamePath, dir, "UseErrorLevel", &launchPid)

                if (launchPid > 0) {
                    this.Pid := launchPid
                    WindowManager.SetGameContext("ahk_pid " this.Pid, 1)
                }
            }

            ; 5. START SMART WATCHER
            this.ScanStartTime := A_TickCount
            this.SearchTimer := this.DetectNewProcess.Bind(this, oldPids)
            SetTimer(this.SearchTimer, 1000)

            return true

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Failed", "Could not run file.`n" . err.Message, 0x10)
            return false
        }
    }

    ; --- SMART PROCESS DETECTION ---
    DetectNewProcess(oldPids) {
        elapsed := A_TickCount - this.ScanStartTime

        if (elapsed > this.ScanDuration) {
            SetTimer(this.SearchTimer, 0)
            return
        }

        newPids := this.GetProcessList()
        bestPid := 0
        bestName := ""
        hasWindow := false

        for pid, name in newPids {
            if !oldPids.Has(pid) {
                if (name = "cmd.exe" || name = "conhost.exe" || name = "werfault.exe" || name = "taskhostw.exe" || name = "git.exe")
                    continue

                thisWindow := WinExist("ahk_pid " pid)

                if (thisWindow) {
                    bestPid := pid
                    bestName := name
                    hasWindow := true
                    break
                } else if (bestPid == 0) {
                    bestPid := pid
                    bestName := name
                }
            }
        }

        if (bestPid > 0 && bestPid != this.Pid) {
            currentHasWindow := (this.Pid > 0 && WinExist("ahk_pid " this.Pid))

            if (this.Pid == 0 || (hasWindow && !currentHasWindow) || (hasWindow && currentHasWindow)) {
                Logger.Info("Launcher: Locked Process: " bestName " (" bestPid ")")

                this.Pid := bestPid
                this.ExeName := bestName

                WindowManager.SetGameContext("ahk_pid " bestPid, 1)
                CaptureManager.CurrentProcessName := bestName

                if IsSet(GuiBuilder)
                    GuiBuilder.StatusText.Text := "Running: " . bestName
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

    Stop() {
        if (this.SearchTimer)
            SetTimer(this.SearchTimer, 0)

        if (this.Pid > 0) {
            try ProcessClose(this.Pid)
            this.Pid := 0

            if IsSet(GuiBuilder)
                GuiBuilder.StatusText.Text := "Game Stopped"
        }
    }
}