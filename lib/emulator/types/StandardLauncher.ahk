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
        this.GameId := (Type(gameObj) == "Map") ? gameObj["Id"] : gameObj.Id

        ; [CRITICAL] Snapshot running processes BEFORE launch
        this.OldPids := this.GetFastProcessMap()

        if IsSet(Logger)
            Logger.Info("StandardLauncher: Starting " . exeName)

        try {
            ; 4. EXECUTE
            oldDir := A_WorkingDir

            ; Safety: Only change directory if 'dir' is valid
            if (dir != "")
                SetWorkingDir(dir)

            ; Initialize PID to 0 to prevent "Expected Number" errors
            launchPid := 0

            try {
                if (ext = "bat" || ext = "cmd") {
                    ; Run batch files
                    Run('"' . exeName . '"', dir, "Min", &launchPid)

                    ; Don't track the batch PID directly, use the Watcher to find the child EXE
                    ConfigManager.ActiveProcessName := ""
                }
                else {
                    ; Run Executables normally
                    ; We pass " " as options to ensure the comma count is correct
                    Run('"' . exeName . '"', dir, " ", &launchPid)

                    if (IsNumber(launchPid) && launchPid > 0) {
                        this.Pid := launchPid

                        ; Track immediately
                        this.TrackProcess(launchPid, gamePath, this.GameId)

                        WindowManager.SetGameContext("ahk_pid " launchPid, 1)
                    }
                }
            } finally {
                SetWorkingDir(oldDir)
            }

            ; 5. START SMART WATCHER (Finds the real game exe if the launcher closes)
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

        newPids := this.GetFastProcessMap()

        ; Compare New List vs Old List
        for pid, name in newPids {
            if !this.OldPids.Has(pid) {

                ; Ignore System/Console noise
                if (name ~= "i)^(cmd|conhost|werfault|taskhostw|git|timeout)\.exe$")
                    continue

                hwnd := WinExist("ahk_pid " pid)

                ; If we found a windowed process, it's definitively the game
                if (hwnd) {
                    if IsSet(Logger)
                        Logger.Info("StandardLauncher: Detected Child Process -> " name " (" pid ")")

                    ; Hand over to ProcessManager
                    this.TrackProcess(pid, name, this.GameId)

                    ; Snap Window
                    WindowManager.SetGameContext("ahk_pid " pid, 1)

                    ; Stop scanning immediately
                    SetTimer(this.SearchTimer, 0)
                    return
                }

                ; If we haven't tracked anything yet, track this background process
                if (this.Pid == 0) {
                    this.TrackProcess(pid, name, this.GameId)
                }
            }
        }
    }

    ; --- HIGH PERFORMANCE SNAPSHOT ---
    GetFastProcessMap() {
        pids := Map()
        ; CreateToolhelp32Snapshot (TH32CS_SNAPPROCESS = 0x2)
        hSnap := DllCall("CreateToolhelp32Snapshot", "uint", 0x2, "uint", 0, "ptr")
        if (hSnap == -1)
            return pids

        ; PROCESSENTRY32 Structure
        ; Size: 568 (x64) or 296 (x86)
        structSize := (A_PtrSize = 8) ? 568 : 296
        pe := Buffer(structSize, 0)

        ; Explicit v2 NumPut Syntax: Type, Value, Target, Offset
        NumPut("uint", structSize, pe, 0)

        if DllCall("Process32First", "ptr", hSnap, "ptr", pe) {
            loop {
                ; th32ProcessID is at offset 8
                pid := NumGet(pe, 8, "uint")
                ; szExeFile is at offset 44 (x64) or 36 (x86)
                name := StrGet(pe.Ptr + (A_PtrSize = 8 ? 44 : 36), "cp0")

                pids[pid] := name

                if !DllCall("Process32Next", "ptr", hSnap, "ptr", pe)
                    break
            }
        }
        DllCall("CloseHandle", "ptr", hSnap)
        return pids
    }
}