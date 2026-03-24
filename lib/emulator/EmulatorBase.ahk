#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Parent class for all launchers. Handles common process tracking.
; * @class EmulatorBase
; * @location lib/emulator/EmulatorBase.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\window\WindowManager.ahk ; Added for ForceKillAll

class EmulatorBase {
    ; Instance State
    GameId := ""
    Pid := 0
    ExeName := ""
    ExePath := ""

    ; Public API (Override these in subclasses)
    Launch(gameObj) {
        Logger.Error("Launch() not implemented for " . Type(this))
        return false
    }

    ; Clean shutdown
    Stop() {
        global AppIsExiting
        if (IsSet(AppIsExiting) && AppIsExiting) {
            Logger.Info("App exiting. Keeping game process alive (PID: " this.Pid ")")
            return
        }

        ; 1. END THE MONITORING SESSION
        if IsSet(ProcessManager) {
            ; New ProcessManager handles logging internally
            ProcessManager.EndSession()
        }

        ; 2. Handle TeknoParrot specifically
        if (InStr(this.ExeName, "TeknoParrot") || InStr(this.ExeName, "Tekno")) {
            WindowManager.ForceKillAll()
            return
        }

        ; 3. Standard Kill
        target := this.Pid ? this.Pid : this.ExeName
        if (target && ProcessExist(target)) {
            Logger.Info("Stopping: " . target)
            ProcessClose(target)
        }
    }

    ; Call this inside your specific Launchers (DolphinLauncher, etc.) after Run()
    TrackProcess(pid, fullPath, gameId) {
        SplitPath(fullPath, &name)
        this.Pid := pid
        this.ExeName := name
        this.ExePath := fullPath
        this.GameId := gameId

        ; 1. Update ConfigManager Global State
        ConfigManager.ActiveProcessName := name
        ConfigManager.UpdateLastPlayed(gameId)

        ; 2. Start the High-Performance Monitor
        if IsSet(ProcessManager) {
            ; We now send BOTH the ID and the PID to satisfy the new manager
            ProcessManager.StartSession(String(gameId), Integer(pid))
        }

        ; 3. Write Session Info to INI for external tools
        try {
            IniWrite(pid, ConfigManager.IniPath, "LAST_PLAYED", "ExePID")
            IniWrite(name, ConfigManager.IniPath, "LAST_PLAYED", "ExeName")
        }
    }

    ; Helpers for Subclasses
    GetEmulatorPath(section, key) {
        path := IniRead(ConfigManager.IniPath, section, key, "")
        path := this.SanitizePath(path)

        if (path == "" || !FileExist(path)) {
            Logger.Error("Emulator path missing for [" . section . "] " . key)
            DialogsGui.CustomMsgBox("Error", "Emulator path not configured for: " . section)
            return ""
        }
        return path
    }

    SanitizePath(path) {
        path := Trim(path)
        path := Trim(path, '"')
        path := Trim(path, "'")
        return path
    }

    UpdateLastPlayed(fullPath, pid) {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        SplitPath(fullPath, &name)

        this.Pid := pid
        this.ExeName := name
        this.ExePath := fullPath

        try {
            IniWrite(timestamp, ConfigManager.IniPath, "LAST_PLAYED", "TimeStamp")
            IniWrite(name, ConfigManager.IniPath, "LAST_PLAYED", "ExeName")
            IniWrite(fullPath, ConfigManager.IniPath, "LAST_PLAYED", "ExePath")
            IniWrite(pid, ConfigManager.IniPath, "LAST_PLAYED", "ExePID")

            if (this.GameId != "")
                IniWrite(this.GameId, ConfigManager.IniPath, "LAST_PLAYED", "GameID")
        }
    }

    KillProcess(exeName) {
        if ProcessExist(exeName) {
            Logger.Debug("Killing previous instance: " . exeName)
            try RunWait(A_ComSpec . " /c taskkill /im " . exeName . " /f", , "Hide")
            Sleep(500)
        }
    }
}