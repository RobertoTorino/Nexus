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
    static ActivePid := 0      ; Required for ControllerManager
    static CurrentGameId := "" ; Required for Stats
    static TimerObj := ""

    ; INITIALIZATION
    static InitMonitor() {
        try {
            this._wmi := ComObject("WbemScripting.SWbemLocator").ConnectServer(".", "root\cimv2")
            Logger.Info("ProcessManager: WMI Connected", "ProcessManager")
        } catch as err {
            if IsSet(Logger)
                Logger.Error("ProcessManager: Failed to init WMI. " err.Message)
        }
    }

    ; SESSION TRACKING
    static StartSession(gameId := "Unknown", pid := 0) {
        if (pid == 0) {
            Logger.Warn("ProcessManager: Blocked invalid StartSession (PID 0)")
            return
        }

        if (this.TimerObj)
            SetTimer(this.TimerObj, 0)

        this.SessionStart := A_TickCount
        this.PeakRAM := 0
        this.ActivePid := pid
        this.CurrentGameId := gameId

        ; Try to get the friendly name for the report
        try {
            this.GameName := ConfigManager.Games[gameId]["SavedName"]
        } catch {
            this.GameName := gameId
        }

        Logger.Info("ProcessManager: Session Started for '" this.GameName "' (PID: " pid ")")

        if IsSet(WindowManager) && WindowManager.HasMethod("SetGameContext")
            WindowManager.SetGameContext("ahk_pid " . pid)

        this.TimerObj := ObjBindMethod(this, "MonitorProcess")
        SetTimer(this.TimerObj, 1000)
    }

    static MonitorProcess() {
        if (this.ActivePid > 0 && !ProcessExist(this.ActivePid)) {
            this.EndSession()
        }
    }

    static EndSession() {
        if (this.SessionStart == 0)
            return ""

        if (this.TimerObj) {
            SetTimer(this.TimerObj, 0)
            this.TimerObj := ""
        }

        duration := (A_TickCount - this.SessionStart) // 1000
        h := Floor(duration / 3600)
        m := Floor(Mod(duration, 3600) / 60)
        s := Mod(duration, 60)
        timeStr := (h > 0 ? h "h " : "") . Format("{:02}m {:02}s", m, s)

        Logger.Info("ProcessManager: Session Ended. Duration: " timeStr " | Peak RAM: " this.PeakRAM "MB")

        ; Save Stats to ConfigManager (The Phillip Logic)
        if (this.CurrentGameId != "" && duration > 1) {
            try ConfigManager.UpdatePlayStats(this.CurrentGameId, duration)
            try ConfigManager.SaveGameDatabase()
        }

        ; Cleanup
        this.ActivePid := 0
        this.SessionStart := 0
        this.CurrentGameId := ""

        if IsSet(WindowManager) && WindowManager.HasMethod("ClearGameContext")
            WindowManager.ClearGameContext()

        return "Session Ended: " . this.GameName . " [" . timeStr . "]"
    }

    ; MONITORING (Your Original High-Detail Logic)
    static GetMonitorText() {
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

        ; 2. APP RAM (Nexus Memory)
        kbScript := this.GetProcessMemoryKB(ProcessExist())
        if (kbScript >= 0) {
            mbScript := Round(kbScript / 1024, 1)
            percScript := (mem.total > 0) ? Round((kbScript / mem.total) * 100, 2) : "0"
            msg .= " | APP: " mbScript "MB (" percScript "%)"
        }

        ; 3. GAME RAM (Live Game Memory)
        if (this.ActivePid > 0 && ProcessExist(this.ActivePid)) {
            kbGame := this.GetProcessMemoryKB(this.ActivePid)
            if (kbGame > 0) {
                mbGame := Round(kbGame / 1024, 1)
                percGame := (mem.total > 0) ? Round((kbGame / mem.total) * 100, 1) : "0"

                if (mbGame > this.PeakRAM)
                    this.PeakRAM := mbGame

                msg .= " | GAME: " mbGame "MB (" percGame "%) [PEAK: " this.PeakRAM "MB]"
            }
        } else {
            msg .= " | GAME: waiting"
        }

        return msg
    }

    static CloseActiveGame() {
        if (this.ActivePid > 0) {
            ProcessClose(this.ActivePid)
        }
    }

    ; HELPERS
    static GetSystemMemoryInfo() {
        ms := Buffer(64, 0)
        NumPut("UInt", 64, ms, 0)
        if !DllCall("kernel32\GlobalMemoryStatusEx", "ptr", ms)
            return { total: 0, used: 0, load: 0 }
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