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

class Logger {
    ; Configuration
    static LogFile := "nexus.log"
    static FallbackLog := "nexus_fallback.log"
    static MaxSize := 1024 * 1000 ; ~1MB (Consistent with v1 logic)

    ; State
    static InLog := false ; Recursion guard

    ; ---- Core Logging Method ----
    static Log(level, msg) {
        ; Recursion Guard: Prevent infinite loops if logging itself fails
        if (this.InLog)
            return
        this.InLog := true

        ; 1. Timestamp generation
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        logEntry := "[" timestamp "] [" level "] " msg "`n"

        ; 2. Visual Log Update
        ; [FIX] Use IsSet() to check if LoggerGui exists before touching it.
        ; This prevents the "Warning: This local variable appears to never be assigned" error.
        if (IsSet(LoggerGui) && HasProp(LoggerGui, "IsActive") && LoggerGui.IsActive) {
            LoggerGui.Log(msg, level)
        }

        try {
            ; 3. Rotation Check
            ; Note: We check size before writing to ensure we don't grow indefinitely
            if FileExist(this.LogFile) {
                try {
                    if (FileGetSize(this.LogFile) > this.MaxSize) {
                        archiveTime := FormatTime(, "yyyyMMdd_HHmmss")
                        archiveName := "nexus_" archiveTime ".log"
                        FileMove(this.LogFile, archiveName, 1) ; 1 = Overwrite
                    }
                } catch {
                    ; If rotation fails (e.g., file locked), ignore and proceed to append
                }
            }

            ; 4. Write to Main Log
            FileAppend(logEntry, this.LogFile)
        }
        catch as err {
            ; 5. Fallback Logging (if main log fails)
            try {
                fallbackMsg := "[" timestamp "] [MAIN-LOG-FAILED] " err.Message "`n"
                FileAppend(fallbackMsg, this.FallbackLog)
                FileAppend(logEntry, this.FallbackLog)
            }
        }

        this.InLog := false
    }

    ; Convenience Wrappers (Used by other modules)
    static Info(msg) => this.Log("INFO", msg)
    static Warn(msg) => this.Log("WARN", msg)
    static Error(msg) => this.Log("ERROR", msg)
    static Debug(msg) => this.Log("DEBUG", msg)

    ; Returns the path to the current log file
    static GetLogFilePath() {
        return this.LogFile
    }

    ; Returns the path to the fallback log file
    static GetFallbackLogPath() {
        return this.FallbackLog
    }

    ; Clears the main log file
    static ClearLogFile() {
        if FileExist(this.LogFile) {
            try {
                ; Open with "w" (Write) mode overwrites/clears the file
                f := FileOpen(this.LogFile, "w")
                f.Close()
                return true
            } catch {
                return false
            }
        }
        return false
    }
}