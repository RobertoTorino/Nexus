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
    ; Pre-allocate buffers to avoid re-creating them every second
    static _memBuffer := Buffer(64, 0)
    static _pmBuffer := Buffer(A_PtrSize = 8 ? 72 : 40, 0)
    static _lastPID := 0
    static _hProcess := 0

    static GetSystemMemoryInfo() {
        ; Use the pre-allocated buffer
        NumPut("UInt", 64, this._memBuffer, 0)
        if !DllCall("kernel32\GlobalMemoryStatusEx", "ptr", this._memBuffer)
            return 0

        ; We pull only what we need directly from the pointer
        ; Offset 8: Total Phys, Offset 16: Avail Phys
        total := NumGet(this._memBuffer, 8, "UInt64")
        avail := NumGet(this._memBuffer, 16, "UInt64")

        ; Return a simple array [UsedMB, Load%] to avoid object overhead
        used := (total - avail) // 1048576 ; Integer division is faster than Round()
        load := NumGet(this._memBuffer, 4, "UInt") ; Memory Load is already at Offset 4

        return [used, load, total // 1048576]
    }

    ; SESSION TRACKING
    static StartSession(name) {
        this.SessionStart := A_TickCount
        this.PeakRAM := 0
        this.GameName := (name != "") ? name : "Unknown Game"

        if IsSet(Logger)
            Logger.Info("ProcessManager: Session Started for '" this.GameName "'", this.__Class)
    }

    ; ... (Keep Session Stats and StartSession as they are) ...

static EndSession() {
        if (this.SessionStart == 0)
            return ""

        ; --- 1. CLEANUP HANDLE (Important for the RAM optimization) ---
        if (this.HasProp("_hProcess") && this._hProcess) {
            DllCall("CloseHandle", "ptr", this._hProcess)
            this._hProcess := 0
            this._lastPID := 0
        }

        ; --- 2. DEFINE FINALPEAK (This was missing!) ---
        finalPeak := (this.PeakRAM > 0) ? this.PeakRAM . " MB" : "No Data"

        ; Calculate Duration
        duration := A_TickCount - this.SessionStart
        seconds := Round(duration / 1000)
        h := Floor(seconds / 3600), m := Floor(Mod(seconds, 3600) / 60), s := Mod(seconds, 60)
        timeStr := (h > 0 ? h "h " : "") . Format("{:02}m {:02}s", m, s)

        ; Build Report
        report := "Session Ended: " . this.GameName . "`n"
        report .= "--------------------------------`n"
        report .= "Duration:  " . timeStr . "`n"
        report .= "Peak RAM:  " . finalPeak

        ; --- 3. SAVE STATS TO DATABASE ---
        ; We use ConfigManager's current ID to ensure we save to the right game
        if (ConfigManager.CurrentGameId != "")
            ConfigManager.AddPlayTime(ConfigManager.CurrentGameId, seconds)

        ; Reset for next session
        this.SessionStart := 0
        this.PeakRAM := 0
        return report
    }

    ; MONITORING (Refined for zero-impact)
static GetMonitorText(gameExeName := "") {
        if (gameExeName == "")
            gameExeName := ConfigManager.ActiveProcessName

        ; Get array [Used, Load, Total]
        stats := this.GetSystemMemoryInfo()
        if !IsObject(stats)
        return "RAM: --"

        msg := "System: " stats[1] "MB (" stats[2] "%)"

        if (gameExeName != "") {
            pid := ProcessExist(gameExeName)
            if (pid) {
                mbGame := this.GetProcessMemoryMB(pid)
                if (mbGame > 0) {
                    if (mbGame > this.PeakRAM) this.PeakRAM := mbGame
                    ; Quick math: (GameMB / TotalMB) * 100
                    percGame := Round((mbGame / stats[3]) * 100, 1)
                    msg .= " | Game: " mbGame "MB (" percGame "%)"
                }
            }
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
                Logger.Info("Priority set to [" level "] for: " targetExe, this.__Class)
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
            Logger.Info("Kill Switch Activated for PID: " pid, this.__Class)
        try RunWait(A_ComSpec " /c taskkill /PID " pid " /F /T", , "Hide")
    }

    static KillProcessByName(exeName) {
        if (exeName == "")
            return
        if IsSet(Logger)
            Logger.Info("Kill Switch Activated for EXE: " exeName, this.__Class)
        try RunWait(A_ComSpec " /c taskkill /IM " exeName " /F /T", , "Hide")
    }

static GetProcessMemoryMB(pid) {
        if !pid
        return 0

        ; OPTIMIZATION: Only open/close handle if the PID changes
        if (pid != this._lastPID) {
            if (this._hProcess)
                DllCall("CloseHandle", "ptr", this._hProcess)

            this._hProcess := DllCall("OpenProcess", "uint", 0x400 | 0x10, "int", 0, "uint", pid, "ptr")
            this._lastPID := pid
        }

        if !this._hProcess
        return 0

        NumPut("UInt", this._pmBuffer.Size, this._pmBuffer, 0)
        if !DllCall("psapi\GetProcessMemoryInfo", "ptr", this._hProcess, "ptr", this._pmBuffer, "uint", this._pmBuffer.Size)
            return 0

        ; Offset 16 (x64) or 8 (x86) is WorkingSetSize
        return NumGet(this._pmBuffer, (A_PtrSize = 8 ? 16 : 8), "UPtr") // 1048576
    }
}