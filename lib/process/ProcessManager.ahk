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
#Include ..\config\ConfigManager.ahk

class ProcessManager {
    static _wmi := ""
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

    ; MONITORING
    static GetMonitorText(gameExeName := "") {
        mem := this.GetSystemMemoryInfo()
        msg := ""

        ; 1. SYSTEM RAM
        if (mem.HasOwnProp("total")) {
            mbTotal := Round(mem.total / 1024, 0)
            mbUsed := Round(mem.used / 1024, 0)
            msg .= "SYSTEM: " mbUsed "/" mbTotal "MB (" mem.load "%)"
        } else {
            msg .= "no-data"
        }

        ; 2. APP RAM
        kbScript := this.GetProcessMemoryKB(ProcessExist())
        if (kbScript >= 0) {
            mbScript := Round(kbScript / 1024, 1)
            percScript := (mem.HasOwnProp("total") && mem.total > 0) ? Round((kbScript / mem.total) * 100, 2) : "0"
            msg .= " | APP: " mbScript "MB (" percScript "%)"
        } else {
            msg .= " | APP: no-data"
        }

        ; 3. GAME RAM
        if (gameExeName != "") {
            pid := ProcessExist(gameExeName)
            if (pid) {
                kbGame := this.GetProcessMemoryKB(pid)
                actualName := ProcessGetName(pid)

                if (kbGame > 0) {
                    mbGame := Round(kbGame / 1024, 1)

                    ; [FIX] Calculate Game Percentage
                    percGame := (mem.HasOwnProp("total") && mem.total > 0) ? Round((kbGame / mem.total) * 100, 1) : "0"

                    if (mbGame > this.PeakRAM)
                        this.PeakRAM := mbGame

                    ; [FIX] Add Percentage to display
                    msg .= " | GAME: " mbGame "MB (" percGame "%) [PEAK: " this.PeakRAM "MB]"
                } else {
                    msg .= " | GAME: no-data (" actualName ")"
                }
            } else {
                msg .= " | GAME: " gameExeName " [waiting]"
            }
        } else {
            msg .= " | GAME: waiting"
        }

        return msg
    }

    ; HELPERS
    static GetSystemMemoryInfo() {
        ms := Buffer(64, 0)
        NumPut("UInt", 64, ms, 0)
        if !DllCall("kernel32\GlobalMemoryStatusEx", "ptr", ms)
            return {}
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

        pm := Buffer((A_PtrSize = 8) ? 72 : 40, 0)
        NumPut("UInt", pm.Size, pm, 0)
        if !DllCall("psapi\GetProcessMemoryInfo", "ptr", hProcess, "ptr", pm, "uint", pm.Size) {
            DllCall("CloseHandle", "ptr", hProcess)
            return -1
        }
        res := Round(NumGet(pm, (A_PtrSize = 8) ? 16 : 8, "UPtr") / 1024)
        DllCall("CloseHandle", "ptr", hProcess)
        return res
    }
}