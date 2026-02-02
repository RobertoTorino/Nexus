#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Reads/Writes Audio Device settings in RPCS3 config.yml.
; * @class Rpcs3AudioTool
; * @location lib/emulator/tools/Rpcs3AudioTool.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class Rpcs3AudioTool {

    ; Get list of enabled Audio Render Devices via PowerShell
    static GetAudioDevices() {
        ; PowerShell command to list active audio output devices
        psScript := "Get-PnpDevice -Class AudioEndpoint | Where-Object { $_.Status -eq 'OK' } | Select-Object -ExpandProperty FriendlyName"
        cmd := "powershell.exe -NoProfile -Command `"" psScript "`""

        try {
            shell := ComObject("WScript.Shell")
            exec := shell.Exec(cmd)
            output := exec.StdOut.ReadAll()

            deviceList := []
            Loop Parse, output, "`n", "`r" {
                if (A_LoopField != "")
                    deviceList.Push(A_LoopField)
            }
            return deviceList
        } catch {
            Logger.Error("Failed to fetch audio devices via PowerShell")
            return ["Default"]
        }
    }

    ; Update config.yml with selected device
    static SetDevice(deviceName) {
        ; 1. Find RPCS3 Config
        rpcs3Path := IniRead(ConfigManager.IniPath, "RPCS3_PATH", "Rpcs3Path", "")
        if (rpcs3Path == "")
            return false

        SplitPath(rpcs3Path, , &dir)
        configPath := dir "\config.yml"

        if !FileExist(configPath) {
            Logger.Error("RPCS3 config.yml not found at: " configPath)
            return false
        }

        ; 2. Read and Replace
        try {
            fileContent := FileRead(configPath)
            newContent := ""
            inAudioSection := false
            replaced := false

            Loop Parse, fileContent, "`n", "`r" {
                line := A_LoopField

                ; Detect Section
                if (Trim(line) = "Audio:")
                    inAudioSection := true
                else if (inAudioSection && RegExMatch(line, "^\S")) ; New section starts
                    inAudioSection := false

                ; Replace Key
                if (inAudioSection && InStr(line, "Audio Device:")) {
                    newContent .= "  Audio Device: " deviceName "`r`n"
                    replaced := true
                } else {
                    newContent .= line "`r`n"
                }
            }

            ; 3. Write Back
            if (replaced) {
                FileDelete(configPath)
                FileAppend(newContent, configPath)
                Logger.Info("RPCS3 Audio Device set to: " deviceName, this.__Class)
                return true
            } else {
                Logger.Warn("Could not find 'Audio Device' key in config.yml. Is it a fresh install?")
                return false
            }
        } catch as err {
            Logger.Error("Failed to update RPCS3 config: " err.Message)
            return false
        }
    }
}