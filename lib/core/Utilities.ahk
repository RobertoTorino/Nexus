#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Utilities Module (v2) - Common helper functions for Nexus.
; * @class Utilities
; * @location lib/core/Utilities.ahk
; * @author Philip
; * @date 2026/01/06
; * @version 1.0.01
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class Utilities {

    ; SanitizeName(str)
    ; Removes invalid characters, ensures single underscores, no spaces.
    static SanitizeName(str) {
        if (str == "")
            return ""

        ; 1. Replace common separators (Space, Dash, Dot, Colon) with Underscore first
        Clean := RegExReplace(str, "[ \-\.\:\[\]\(\)]", "_")

        ; 2. Remove anything that is NOT Alphanumeric or Underscore
        Clean := RegExReplace(Clean, "[^A-Za-z0-9_]", "")

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

        Logger.Debug("Running command: " . fullCmd)

        try {
            RunWait(fullCmd, , "Hide")

            if FileExist(tmpFile) {
                output := FileRead(tmpFile)
                FileDelete(tmpFile)
                Logger.Debug("Command output: " . output)
                return Trim(output)
            }
        } catch as err {
            Logger.Error("GetCommandOutput failed: " . err.Message)
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
        if (path = "")
            return false
        if (!FileExist(path))
            return false
        if (SubStr(path, -4) != ".exe") ; -4 checks last 4 chars (.exe)
            return false
        return true
    }

    ; IsValidIsoPath(path)
    ; Validates that path points to an ISO/CSO file
    static IsValidIsoPath(path) {
        if (path = "")
            return false
        if (!FileExist(path))
            return false

        ext := SubStr(path, -3) ; Check last 3 (.iso / .cso)
        ; V2 string comparison is case-insensitive by default
        if (ext != "iso" && ext != "cso" && SubStr(path, -4) != ".iso" && SubStr(path, -4) != ".cso")
            return false

        return true
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
    ; Returns current date/time in standard format
    static GetCurrentTimestamp() {
        return FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }

    ; GetDateTimestampShort()
    ; Returns current date/time in file-safe format
    ;
    static GetDateTimestampShort() {
        return FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    }

    ; CustomTrayTip(text, iconType)
    ; Wrapper for TrayTip with consistent titling
    ; iconType: 1=Info, 2=Warning, 3=Error
    static CustomTrayTip(text, iconType := 1) {
        title := "Game Screen Manager Lite"
        options := (iconType == 2) ? 2 : (iconType == 3) ? 3 : 1
        TrayTip(text, title, options)
        ; Hide tray tip after 3 seconds (V2 doesn't have a built-in timeout)
        SetTimer(() => TrayTip(), -3000)
    }

    ; IsInternetAvailable()
    ; Checks local network adapter status via WinAPI (Instant, Non-blocking).
    ; Returns: 1 (True) or 0 (False)
    static IsInternetAvailable() {
        ; 0x40 = INTERNET_CONNECTION_CONFIGURED
        ; This checks if the OS "thinks" it has internet. It does not ping a server.
        ; This prevents the UI from freezing for seconds if the internet is down.
        return DllCall("Wininet.dll\InternetGetConnectedState", "UInt*", 0, "UInt", 0)
    }

    ; GenerateUniqueId(friendlyName, existingGamesMap)
    ; Generates a strictly unique ID (e.g., GAME_DOOM, GAME_DOOM_2)
    static GenerateUniqueId(friendlyName, existingGamesMap) {
        ; 1. Get the clean base (e.g., "STREET_FIGHTER")
        clean := this.SanitizeName(friendlyName)

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
}