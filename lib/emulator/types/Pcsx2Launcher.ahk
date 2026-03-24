#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class Pcsx2Launcher
; * @location lib/emulator/types/Pcsx2Launcher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk

class Pcsx2Launcher extends EmulatorBase {

    Launch(gameObj) {
        this.GameId := gameObj.Id

        ; 1. Get Emulator Path
        emuPath := this.GetEmulatorPath("PCSX2_PATH", "Pcsx2Path")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; 2. Path Validation
        rawPath := gameObj.HasProp("ApplicationPath") ? gameObj.ApplicationPath : ""
        if (rawPath == "" && gameObj.HasProp("EbootIsoPath"))
            rawPath := gameObj.EbootIsoPath

        ; --- FIX 1: TRACK UI SESSION ---
        if (rawPath == "") {
            Logger.Info("PCSX2: No ISO selected, launching UI.")
            try {
                Run(emuPath, emuDir, , &guiPid)
                if (guiPid > 0)
                    this.TrackProcess(guiPid, emuPath, "PCSX2_UI")
                return true
            } catch {
                return false
            }
        }

        ; 3. Normalization (Force Backslashes for PCSX2 CLI)
        isoPath := StrReplace(rawPath, "/", "\")

        ; 4. Prep
        this.KillProcess(exeName)
        CaptureManager.CurrentProcessName := exeName

        ; 5. Launch Arguments
        ; -batch (Exit on close) -fullscreen -- (File separator)
        runCmd := Format('"{1}" -batch -fullscreen -- "{2}"', emuPath, isoPath)
        Logger.Info("Launching PCSX2: " runCmd)

        try {
            ; --- FIX 2: REMOVE LEGACY "UseErrorLevel" ---
            Run(runCmd, emuDir, , &newPid)

            if (newPid > 0) {
                Logger.Info("PCSX2Launcher: Process started successfully. PID: " . newPid, "PCSX2Launcher")

                ; Hook into Process Manager
                this.TrackProcess(newPid, emuPath, gameObj.Id)

                ; 6. Window Management ("Ninja Move")
                ; Wait up to 3 seconds for the window to appear so we can snap it
                if WinWait("ahk_pid " newPid, , 3) {
                    WindowManager.SetGameContext("ahk_pid " newPid, 1)
                    Logger.Info("PCSX2 Launched & Moved (PID: " newPid ")")
                    return true
                }

                Logger.Warn("PCSX2 launched, but window not found within timeout.")
                return true
            }
            return false
        } catch as err {
            Logger.Error("PCSX2 Launch Failed: " err.Message)
            return false
        }
    }
}