#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Handles Priorities, Kill Switch, System Monitoring, and Session Stats.
; * @class ProcessManager
; * @location lib/process/ProcessManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\config\ConfigManager.ahk ; [NEW] Required to read ActiveProcessName

class ProcessManager {
    static _wmi := ""

    ; Session Stats State
    static SessionStart := 0
    static PeakRAM := 0
    static GameName := ""

    ; INITIALIZATION
    static InitMonitor() {
        try {
            this._wmi := ComObject("WbemScripting.SWbemLocator").ConnectServer(".", "root\cimv2")
        } catch as err {
            if IsSet(Logger)
                Logger.Error("ProcessManager: Failed to init WMI. " err.Message)
        }
    }

    ; SESSION TRACKING
    static StartSession(name) {
        this.SessionStart := A_TickCount
        this.PeakRAM := 0
        this.GameName := (name != "") ? name : "Unknown Game"

        if IsSet(Logger)
            Logger.Info("ProcessManager: Session Started for '" this.GameName "'")
    }

    static EndSession() {
        if (this.SessionStart == 0)
            return ""

        duration := A_TickCount - this.SessionStart
        seconds := Round(duration / 1000)
        h := Floor(seconds / 3600)
        m := Floor(Mod(seconds, 3600) / 60)
        s := Mod(seconds, 60)
        timeStr := (h > 0 ? h "h " : "") . Format("{:02}m {:02}s", m, s)

        report := "Session Ended: " . this.GameName . "`n"
        report .= StrReplace(Format("{:16}", ""), " ", Chr(0x2500)) . "`n"
        report .= "Duration:  " . timeStr . "`n"
        report .= "Peak RAM:  " . this.PeakRAM . " MB"

        if IsSet(Logger)
            Logger.Info("ProcessManager: Session Ended. Duration: " timeStr " | Peak RAM: " this.PeakRAM "MB")

        this.SessionStart := 0
        return report
    }

    ; MONITORING (Updated for Compact Display)
    static GetMonitorText(gameExeName := "") {
        if (gameExeName == "")
            gameExeName := ConfigManager.ActiveProcessName

        mem := this.GetSystemMemoryInfo()
        msg := ""

        ; SYSTEM RAM
        if (mem.HasOwnProp("total")) {
            mbTotal := Round(mem.total / 1024, 0)
            mbUsed := Round(mem.used / 1024, 0)
            msg .= "Sys: " mbUsed "/" mbTotal "MB (" mem.load "%)"
        } else {
            msg .= "no-data"
        }

        ; APP (This Script)
        kbScript := this.GetProcessMemoryKB(ProcessExist())
        if (kbScript >= 0) {
            mbScript := Round(kbScript / 1024, 1)
            percScript := (mem.HasOwnProp("total")) ? Round((kbScript / mem.total) * 100, 1) : "0"
            msg .= " | App: " mbScript "MB (" percScript "%)"
        }

        ; GAME
        if (gameExeName != "") {
            pid := ProcessExist(gameExeName)
            if (pid) {
                kbGame := this.GetProcessMemoryKB(pid)

                if (kbGame > 0) {
                    mbGame := Round(kbGame / 1024, 1)

                    ; Calculate Percentage (1 decimal place)
                    percGame := (mem.HasOwnProp("total") && mem.total > 0) ? Round((kbGame / mem.total) * 100, 1) : "0.0"

                    ; Still track Peak in background for the end report, but don't show it live
                    if (mbGame > this.PeakRAM) {
                        this.PeakRAM := mbGame
                    }

                    ; [COMPACT FORMAT] "Game: 150.5MB (1.2%)"
                    msg .= " | Game: " mbGame "MB (" percGame "%)"
                } else {
                    msg .= " | Game: no-data"
                }
            } else {
                msg .= " | Game: [waiting]"
            }
        } else {
            msg .= " | Game: waiting"
        }

        return msg
    }

    ; PRIORITY MANAGEMENT
    static SetPriority(level) {
        targetExe := ConfigManager.ActiveProcessName

        if (targetExe == "" || !ProcessExist(targetExe)) {
            if IsSet(DialogsGui)
                DialogsGui.CustomTrayTip("No active game process found", 2)
            return
        }

        try {
            ProcessSetPriority(level, targetExe)
            if IsSet(Logger)
                Logger.Info("Priority set to [" level "] for: " targetExe)
            if IsSet(DialogsGui)
                DialogsGui.CustomTrayTip("Priority: " level, 1)
        } catch as err {
            if IsSet(Logger)
                Logger.Error("Failed to set priority: " err.Message)
        }
    }

    static OpenOverclock() {
        paths := [
            "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe",
            "C:\Program Files\MSI Afterburner\MSIAfterburner.exe"
        ]
        for path in paths {
            if FileExist(path) {
                Run(path)
                if IsSet(DialogsGui)
                    DialogsGui.CustomTrayTip("Afterburner Started", 1)
                return
            }
        }
        if IsSet(DialogsGui)
            DialogsGui.CustomMsgBox("Error", "MSI Afterburner not found.")
    }

    ; KILL SWITCH
    static KillProcessTree(pid) {
        if !pid
            return
        if IsSet(Logger)
            Logger.Info("Kill Switch Activated for PID: " pid)
        try RunWait(A_ComSpec " /c taskkill /PID " pid " /F /T", , "Hide")
    }

    static KillProcessByName(exeName) {
        if (exeName == "")
            return
        if IsSet(Logger)
            Logger.Info("Kill Switch Activated for EXE: " exeName)
        try RunWait(A_ComSpec " /c taskkill /IM " exeName " /F /T", , "Hide")
    }

    ; HELPERS
    static GetSystemMemoryInfo() {
        ms := Buffer(64, 0)
        NumPut("UInt", 64, ms, 0)
        if !DllCall("kernel32\GlobalMemoryStatusEx", "ptr", ms)
            return {}

        ; Return KB for consistency with GetProcessMemoryKB
        total := NumGet(ms, 8, "UInt64") / 1024
        avail := NumGet(ms, 16, "UInt64") / 1024
        used := total - avail
        load := Round((used / total) * 100, 1)

        return { total: total, available: avail, used: used, load: load }
    }

    static GetProcessMemoryKB(pid) {
        if !pid
            return -1
        hProcess := DllCall("OpenProcess", "uint", 0x400 | 0x10, "int", 0, "uint", pid, "ptr")
        if !hProcess
            return -1
        size := (A_PtrSize = 8) ? 72 : 40
        pm := Buffer(size, 0)
        NumPut("UInt", size, pm, 0)
        if !DllCall("psapi\GetProcessMemoryInfo", "ptr", hProcess, "ptr", pm, "uint", size) {
            DllCall("CloseHandle", "ptr", hProcess)
            return -1
        }
        offset := (A_PtrSize = 8) ? 16 : 8
        workingSet := NumGet(pm, offset, "UPtr")
        DllCall("CloseHandle", "ptr", hProcess)
        return Round(workingSet / 1024)
    }
}