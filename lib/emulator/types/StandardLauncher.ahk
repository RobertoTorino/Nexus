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
        ; 1. Resolve & Normalize Path
        rawPath := (Type(gameObj) == "Map") ? (gameObj.Has("ApplicationPath") ? gameObj["ApplicationPath"] : gameObj["Path"]) : (gameObj.HasProp("ApplicationPath") ? gameObj.ApplicationPath : gameObj.Path)
        gamePath := StrReplace(StrReplace(rawPath, "/", "\"), '"', "")

        if (gamePath == "" || !FileExist(gamePath)) {
            DialogsGui.CustomMsgBox("Launch Error", "File not found:`n" . gamePath)
            return false
        }

        SplitPath(gamePath, &exeName, &dir, &ext)
        this.ExeName := exeName
        this.GameId := (Type(gameObj) == "Map") ? gameObj["Id"] : gameObj.Id

        ; [CRITICAL] Snapshot running processes using a faster method than WMI
        this.OldPids := this.GetFastProcessMap()

        try {
            oldDir := A_WorkingDir
            SetWorkingDir(dir)
            try {
                if (ext = "bat" || ext = "cmd") {
                    Run('"' . exeName . '"', dir, "Min", &launchPid)
                } else {
                    Run('"' . exeName . '"', dir, , &launchPid)
                    ; Initial tracking (might be replaced by child detection later)
                    if (launchPid > 0)
                        this.TrackProcess(launchPid, gamePath, this.GameId)
                }
            } finally {
                SetWorkingDir(oldDir)
            }

            ; Start Smart Watcher for chain-loaders
            this.ScanStartTime := A_TickCount
            this.SearchTimer := this.DetectNewProcess.Bind(this)
            SetTimer(this.SearchTimer, 1000)
            return true
        } catch as err {
            DialogsGui.CustomMsgBox("Launch Failed", err.Message)
            return false
        }


    DetectNewProcess() {
        if (A_TickCount - this.ScanStartTime > this.ScanDuration) {
            SetTimer(this.SearchTimer, 0)
            return
        }

        newPids := this.GetFastProcessMap()
        for pid, name in newPids {
            if !this.OldPids.Has(pid) {
                ; Filter noise
                if (name ~= "i)^(cmd|conhost|werfault|taskhostw|git|timeout)\.exe$")
                    continue

                hasWindow := WinExist("ahk_pid " pid)

                ; If we found a child process, hand it over to the parent tracking system
                if (hasWindow || this.Pid == 0) {
                    if IsSet(Logger)
                        Logger.Info("StandardLauncher: Detected Child -> " name " (" pid ")", this.__Class)

                    ; Use the new EmulatorBase method to trigger RAM/Session monitoring
                    this.TrackProcess(pid, name, this.GameId)

                    ; If it has a window, we've likely found the main game. Stop scanning.
                    if (hasWindow) {
                        SetTimer(this.SearchTimer, 0)
                        break
                    }
                }
            }
        }
    }

GetFastProcessMap() {
        pids := Map()
        ; TH32CS_SNAPPROCESS = 0x00000002
        hSnap := DllCall("CreateToolhelp32Snapshot", "uint", 0x00000002, "uint", 0, "ptr")
        if (hSnap = -1)
            return pids

        ; ProcessEntry32 structure size: 568 bytes on x64, 296 on x86
        structSize := (A_PtrSize = 8) ? 568 : 296
        pe := Buffer(structSize, 0)
        NumPut("uint", structSize, pe, 0)

        if DllCall("Process32First", "ptr", hSnap, "ptr", pe) {
            loop {
                ; Offset 8 is th32ProcessID
                pid := NumGet(pe, 8, "uint")
                ; Offset 36 (x64) or 28 (x86) is szExeFile (the name)
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
            if (name ~= "i)^(cmd|conhost|werfault|taskhostw|git|timeout)\.exe$")
                continue

            hwnd := WinExist("ahk_pid " pid)

            ; If we find a windowed process, it's definitely the game
            if (hwnd) {
                this.TrackProcess(pid, name, this.GameId)
                SetTimer(this.SearchTimer, 0) ; We found it! Stop searching.
                return
            }

            ; If we haven't tracked anything yet, track this background process for now
            if (this.Pid == 0) {
                this.TrackProcess(pid, name, this.GameId)
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
                    Logger.Info("StandardLauncher: Detected Child Process -> " bestName " (" bestPid ")", "StandardLauncher")

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