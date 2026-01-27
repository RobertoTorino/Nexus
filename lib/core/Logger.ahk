#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Logging Module - Isolated logging functionality for Nexus (v2).
; * @class Logger
; * @location lib/core/Logger.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Logging Module - Robust File Access & Source Detection.
; * @class Logger
; * @location lib/core/Logger.ahk
; * @version 1.2.00 (Production Grade - Shared Write Access)
; ==============================================================================

class Logger {
    ; Configuration
    static LogFile := "nexus.log"
    static FallbackLog := "nexus_fallback.log"
    static MaxSize := 1024 * 1024 ; 1MB Limit

    ; State
    static InLog := false ; Recursion guard

    ; ---- Core Logging Method ----
    static Log(level, msg, source := "") {
        if (this.InLog)
            return
        this.InLog := true

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        ; Format: [Time] [Level] [Class.Method] Message
        srcStr := (source != "") ? "[" . source . "] " : ""
        logEntry := "[" timestamp "] [" level "] " srcStr . msg . "`n"

        ; 1. Visual Log Update (GUI)
        if (IsSet(LoggerGui) && HasProp(LoggerGui, "IsActive") && LoggerGui.IsActive) {
            LoggerGui.Log(msg, level)
        }

        ; 2. File Write (Robust Mode)
        try {
            this._WriteToFile(logEntry)
        }
        catch as err {
            ; Fallback: If main log is locked/broken, try fallback
            try {
                FileAppend("[" timestamp "] [LOG-CRASH] " err.Message "`n", this.FallbackLog)
                FileAppend(logEntry, this.FallbackLog)
            }
        }

        this.InLog := false
    }

    ; ---- INTERNAL HELPER: Safe File Access ----
    static _WriteToFile(text) {
        ; Check Rotation
        if FileExist(this.LogFile) {
            try {
                if (FileGetSize(this.LogFile) > this.MaxSize) {
                    archiveTime := FormatTime(, "yyyyMMdd_HHmmss")
                    try FileMove(this.LogFile, "nexus_" archiveTime ".log", 1)
                }
            }
        }

        ; Open File with Sharing Flags (rw = Read/Write, - = Shared Read/Write)
        ; This prevents "File in use" errors if you have the log open in Notepad
        f := FileOpen(this.LogFile, "a-wd", "UTF-8")

        if (f) {
            f.Write(text)
            f.Close()
        } else {
            ; If FileOpen failed (e.g. permission denied), assume simple append
            FileAppend(text, this.LogFile, "UTF-8")
        }
    }

    ; ---- WRAPPERS (Auto-Detect Source) ----

    ; 'Error("", -1).What' gets the name of the function calling this wrapper
    static Info(msg) => this.Log("INFO", msg, Error("", -1).What)

    static Warn(msg) => this.Log("WARN", msg, Error("", -1).What)

    static Error(msg) => this.Log("ERROR", msg, Error("", -1).What)

    static Debug(msg) => this.Log("DEBUG", msg, Error("", -1).What)

    ; ---- UTILS ----

    static GetLogFilePath() {
        return this.LogFile
    }

    static ClearLogFile() {
        try {
            if FileExist(this.LogFile) {
                FileDelete(this.LogFile)
                return true
            }
        } catch {
            return false
        }
        return false
    }
}