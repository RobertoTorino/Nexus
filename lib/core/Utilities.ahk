#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Utilities Module (v2) - Common helper functions for Nexus.
; * @class Utilities
; * @location lib/core/Utilities.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include Logger.ahk ; [RESTORED] Required for GetCommandOutput logging

class Utilities {

    ; SanitizeName(str)
    ; Removes invalid characters, ensures single underscores.
    ; [UPDATED] Now supports Unicode (Japanese, Chinese, etc.)
    static SanitizeName(str) {
        if (str == "")
            return ""

        ; 1. Replace common separators (Space, Dash, Dot, Colon, Brackets) with Underscore
        Clean := RegExReplace(str, "[ \-\.\:\[\]\(\)]", "_")

        ; 2. Remove anything that is NOT Alphanumeric, Underscore, or Unicode (\x{0080}-\x{FFFF})
        ; This ensures we don't delete Japanese characters
        Clean := RegExReplace(Clean, "[^a-zA-Z0-9_\x{0080}-\x{FFFF}]", "")

        ; 3. Collapse multiple underscores into one
        Clean := RegExReplace(Clean, "_+", "_")

        ; 4. Trim leading and trailing underscores (Crucial for file paths)
        Clean := Trim(Clean, "_")

        return StrUpper(Clean)
    }

    ; JoinArray(arr, sep)
    ; Joins array elements with separator
    static JoinArray(arr, sep := ",") {
        str := ""
        for index, val in arr {
            if (str != "")
                str .= sep
            str .= val
        }
        return str
    }

    ; GetCommandOutput(cmd)
    ; Executes a command via ComSpec and captures stdout
    static GetCommandOutput(cmd) {
        tmpFile := A_Temp "\cmd_output.txt"
        ; Wrap the entire cmd in double-quotes to preserve quoted paths inside
        fullCmd := A_ComSpec . " /c `"" . cmd . " > `"" . tmpFile . "`" 2>&1`""

        ; [RESTORED] Logging logic
        if IsSet(Logger)
            Logger.Debug("Utilities: Running command: " . fullCmd)

        try {
            RunWait(fullCmd, , "Hide")

            if FileExist(tmpFile) {
                output := FileRead(tmpFile)
                FileDelete(tmpFile)

                if IsSet(Logger)
                    Logger.Debug("Utilities: Command output: " . output)

                return Trim(output)
            }
        } catch as err {
            if IsSet(Logger)
                Logger.Error("Utilities: GetCommandOutput failed: " . err.Message)
        }
        return ""
    }

    ; TrimQuotesAndSpaces(str)
    ; Removes leading/trailing quotes and spaces
    static TrimQuotesAndSpaces(str) {
        str := Trim(str)  ; trim spaces first

        ; Remove leading double quote
        while (SubStr(str, 1, 1) = '"')
            str := SubStr(str, 2)

        ; Remove trailing double quote (V2 SubStr: -1 is last char)
        while (SubStr(str, -1) = '"')
            str := SubStr(str, 1, StrLen(str) - 1)

        return str
    }

    ; FileNameNoExt(filePath)
    ; Extracts filename without extension
    static FileNameNoExt(filePath) {
        SplitPath(filePath, , , , &fileNoExt)
        return fileNoExt
    }

    ; GetFileExtension(filePath)
    ; Extracts file extension (including dot)
    static GetFileExtension(filePath) {
        SplitPath(filePath, , , &ext)
        return ext != "" ? "." ext : ""
    }

    ; IsValidExePath(path)
    ; Validates that path points to a real executable file
    static IsValidExePath(path) {
        if (path = "" || !FileExist(path))
            return false

        ; Optimized check
        return (SubStr(path, -4) = ".exe")
    }

    ; IsValidIsoPath(path)
    ; Validates that path points to an ISO/CSO/RVZ etc
    static IsValidIsoPath(path) {
        if (path = "" || !FileExist(path))
            return false

        ext := SubStr(path, -3)
        ; V2 string comparison is case-insensitive by default
        return (ext = "iso" || ext = "cso" || ext = "rvz" || SubStr(path, -4) = ".iso" || SubStr(path, -4) = ".cso")
    }

    ; FormatFileSize(bytes)
    ; Converts bytes to human-readable format (KB, MB, GB)
    static FormatFileSize(bytes) {
        if (bytes < 1024)
            return bytes . " B"
        else if (bytes < 1024 * 1024)
            return Round(bytes / 1024, 2) . " KB"
        else if (bytes < 1024 * 1024 * 1024)
            return Round(bytes / (1024 * 1024), 2) . " MB"
        else
            return Round(bytes / (1024 * 1024 * 1024), 2) . " GB"
    }

    ; GetCurrentTimestamp()
    static GetCurrentTimestamp() {
        return FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }

    ; GetDateTimestampShort()
    static GetDateTimestampShort() {
        return FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    }

    ; CustomTrayTip(text, iconType)
    ; Wrapper for TrayTip with consistent titling
    ; iconType: 1=Info, 2=Warning, 3=Error
    static CustomTrayTip(text, iconType := 1) {
        title := "Nexus"
        options := (iconType == 2) ? 2 : (iconType == 3) ? 3 : 1
        try {
            TrayTip(text, title, options)
            SetTimer(() => TrayTip(), -3000)
        }
    }

    ; IsInternetAvailable()
    ; Checks local network adapter status via WinAPI
    static IsInternetAvailable() {
        return DllCall("Wininet.dll\InternetGetConnectedState", "UInt*", 0, "UInt", 0)
    }

    ; GenerateUniqueId(friendlyName, existingGamesMap)
    ; Generates a strictly unique ID
    static GenerateUniqueId(friendlyName, existingGamesMap) {
        ; 1. Get the clean base (Uses the new Unicode-Safe logic)
        clean := this.SanitizeName(friendlyName)

        if (clean == "")
            clean := "GAME"

        ; 2. Form the base ID
        baseId := "GAME_" . clean

        ; 3. Check for collisions and increment if necessary
        finalId := baseId
        counter := 1

        ; Loop until we find an ID that isn't in the map
        while (existingGamesMap.Has(finalId)) {
            counter++
            finalId := baseId . "_" . counter
        }

        return finalId
    }

    ; --- MONITOR & GEOMETRY HELPERS ---

        static GetMonitorCount() {
            return MonitorGetCount()
        }

        static GetMonitorGeometry(index) {
            if (index > MonitorGetCount())
                return false

            try {
                MonitorGet(index, &L, &T, &R, &B)
                width := R - L
                height := B - T

                ; Safety check
                if (width <= 0 || height <= 0)
                    return false

                return {Left: L, Top: T, Right: R, Bottom: B, Width: width, Height: height}
            } catch {
                return false
            }
        }

        static GetMonitorIndexFromPoint(x, y) {
            count := MonitorGetCount()
            Loop count {
                try {
                    MonitorGet(A_Index, &L, &T, &R, &B)
                    if (x >= L && x < R && y >= T && y < B)
                        return A_Index
                }
            }
            return 1 ; Default to Primary
        }

        ; --- LOGGING ROUTINE ---
        ; Call this method from Nexus.ahk at startup
        static LogMonitorStats() {
            if !IsSet(Logger)
                return

            count := this.GetMonitorCount()
            Logger.Debug("--------------------------------------------------")
            Logger.Debug("SYSTEM MONITOR INFO")
            Logger.Debug("Monitor Count: " . count)

            Loop count {
                m := this.GetMonitorGeometry(A_Index)
                if (m) {
                    msg := "Monitor " . A_Index . ": "
                         . "L=" . m.Left . " T=" . m.Top . " "
                         . "W=" . m.Width . " H=" . m.Height
                    Logger.Debug(msg)
                } else {
                    Logger.Warn("Monitor " . A_Index . " geometry could not be read.")
                }
            }

            ; Specific check for Monitor 2 (as per your legacy code)
            if (count < 2) {
                Logger.Info("Monitor 2 not available (Single Monitor Setup).")
            }

            Logger.Debug("--------------------------------------------------")
        }
    }