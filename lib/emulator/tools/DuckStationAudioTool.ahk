#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Reads/Writes Audio Device settings in DuckStation settings.ini.
; * @class DuckStationAudioTool
; * @location lib/emulator/tools/DuckStationAudioTool.ahk
; * @author Philip
; * @date 2026/01/06
; * @version 1.0.01
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class DuckStationAudioTool {

    static SetDevice(deviceName) {
        ; 1. Find DuckStation Path
        duckPath := IniRead(ConfigManager.IniPath, "DUCKSTATION_PATH", "DuckStationPath", "")
        if (duckPath == "")
            return false

        SplitPath(duckPath, , &emuDir)

        ; 2. Locate settings.ini
        ; Priority 1: Portable mode (in same folder)
        configPath := emuDir "\settings.ini"

        ; Priority 2: Documents folder (Standard install)
        if !FileExist(configPath) {
            docsPath := A_MyDocuments "\DuckStation\settings.ini"
            if FileExist(docsPath)
                configPath := docsPath
        }

        if !FileExist(configPath) {
            Logger.Error("DuckStation settings.ini not found.")
            return false
        }

        ; 3. Write Config
        try {
            ; DuckStation uses standard INI format
            IniWrite(deviceName, configPath, "Audio", "Device")
            Logger.Info("DuckStation Audio Device set to: " deviceName)
            return true
        } catch as err {
            Logger.Error("Failed to update DuckStation config: " err.Message)
            return false
        }
    }
}