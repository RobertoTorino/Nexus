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
        ; --- CRITICAL FIX: PREVENT KILL ON APP EXIT ---
        global AppIsExiting
        if (IsSet(AppIsExiting) && AppIsExiting) {
            Logger.Info("App exiting. Keeping game process alive (PID: " this.Pid ")")
            return
        }

        ; [FIX] Smart Kill for TeknoParrot
        if (this.ExeName = "TeknoParrotUi.exe" || InStr(this.ExeName, "Tekno")) {
            WindowManager.ForceKillAll()
            return
        }

        if (this.Pid && ProcessExist(this.Pid)) {
            Logger.Info("Stopping PID: " . this.Pid)
            try ProcessClose(this.Pid)
        }
        else if (this.ExeName && ProcessExist(this.ExeName)) {
            Logger.Info("Stopping Process: " . this.ExeName)
            try ProcessClose(this.ExeName)
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