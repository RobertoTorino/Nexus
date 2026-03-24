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
    static LogFile := "nexus.log"
    static FallbackLog := "nexus_fallback.log"
    static MaxSize := 1024 * 1024
    static InLog := false

    static Log(level, msg, source := "") {
        if (this.InLog)
            return
        this.InLog := true

        ; If source is empty, auto-detect it from the call stack
        if (source == "" || source == "Class") {
            source := this._DetectCaller()
        }

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        logEntry := "[" timestamp "] [" level "] [" source "] " msg . "`n"

        ; File Write Logic (Ensuring shared access)
        this._WriteToFile(logEntry)

        this.InLog := false
    }

    ; --- SMART CALLER DETECTION ---
    static _DetectCaller() {
        try {
            ; Peeking back to find the actual call site
            ; -1: _DetectCaller, -2: Logger.Info, -3: The actual code
            err := Error("", -3)
            caller := err.What

            ; 1. If it's a class method (e.g., AudioManager.Init)
            if InStr(caller, ".") {
                return StrSplit(caller, ".")[1] ; Returns 'AudioManager'
            }

            ; 2. If it's the main script (Nexus.ahk) or a global function
            SplitPath(err.File, &fileName)
            return fileName ; Returns 'Nexus.ahk'
        } catch {
            return "Nexus"
        }
    }

    static _WriteToFile(text) {
        ; --- AUTO-CREATE FIX ---
        ; If file doesn't exist, create it immediately to prevent ShellExecute errors later
        if !FileExist(this.LogFile) {
            FileAppend("", this.LogFile, "UTF-8")
        }

        if (FileGetSize(this.LogFile) > this.MaxSize) {
            archiveTime := FormatTime(, "yyyyMMdd_HHmmss")
            try FileMove(this.LogFile, "nexus_" archiveTime ".log", 1)
        }

        f := FileOpen(this.LogFile, "a-wd", "UTF-8")
        if (f) {
            f.Write(text)
            f.Close()
        } else {
            FileAppend(text, this.LogFile, "UTF-8")
        }
    }

    ; Update wrappers to pass empty strings by default
    static Info(msg, src := "") => this.Log("INFO", msg, src)
    static Warn(msg, src := "") => this.Log("WARN", msg, src)
    static Error(msg, src := "") => this.Log("ERROR", msg, src)
    static Debug(msg, src := "") => this.Log("DEBUG", msg, src)

    ; --- NEW: SAFE LOG VIEWER ---
    static ViewLog() {
        if !FileExist(this.LogFile) {
            this.Info("Log file requested but missing. Creating now.")
        }

        try {
            ; Try to open with system default (usually Notepad or VS Code)
            Run(this.LogFile)
        } catch {
            ; Hard-coded fallback to Notepad if no association exists
            try Run("notepad.exe " . this.LogFile)
        }
    }

    static GetLogFilePath() => A_ScriptDir . "\" . this.LogFile

    static ClearLogFile() {
        try {
            if FileExist(this.LogFile) {
                FileDelete(this.LogFile)
                this.Info("Log file cleared by user.")
                return true
            }
        } catch {
            return false
        }
        return false
    }
}