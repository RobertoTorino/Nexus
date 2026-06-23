#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching PCSX2x6 arcade games.
; * @class Pcsx2x6Launcher
; * @location lib/emulator/types/Pcsx2x6Launcher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\config\ConfigManager.ahk

class Pcsx2x6Launcher extends EmulatorBase {

    Launch(gameObj) {
        this.GameId := gameObj.Id

        ; 1. Get Emulator Path
        emuPath := this.GetEmulatorPath("PCSX2X6_PATH", "Pcsx2x6Path")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; 2. Path Validation
        rawPath := gameObj.HasProp("ApplicationPath") ? gameObj.ApplicationPath : ""
        if (rawPath == "" && gameObj.HasProp("EbootIsoPath"))
            rawPath := gameObj.EbootIsoPath

        if (rawPath == "") {
            Logger.Info("PCSX2x6: No game file selected.")
            return false
        }

        ; 3. Normalization (Force Backslashes for CLI)
        gamePath := StrReplace(rawPath, "/", "\")

        ; 4. Prep
        this.KillProcess(exeName)
        CaptureManager.CurrentProcessName := exeName

        ; 5. Launch Arguments
        ; PCSX2x6 expects direct game-file invocation: pcsx2-qt.exe "file.acgame"
        ; runCmd := Format('"{1}" "{2}"', emuPath, gamePath)
        runCmd := Format('"{1}" -batch -fullscreen -- "{2}"', emuPath, gamePath)
        Logger.Info("Launching PCSX2x6: " runCmd)

        try {
            Run(runCmd, emuDir, , &newPid)

            if (newPid > 0) {
                Logger.Info("Pcsx2x6Launcher: Process started successfully. PID: " . newPid, "Pcsx2x6Launcher")

                ; Hook into Process Manager
                this.TrackProcess(newPid, emuPath, gameObj.Id)

                ; 6. Window Management
                ; Wait up to 3 seconds for the window to appear so we can snap it
                if WinWait("ahk_pid " newPid, , 3) {
                    WindowManager.SetGameContext("ahk_pid " newPid, 1)
                    Logger.Info("PCSX2x6 Launched & Moved (PID: " newPid ")")
                    return true
                }

                Logger.Warn("PCSX2x6 launched, but window not found within timeout.")
                return true
            }
            return false
        } catch as err {
            Logger.Error("PCSX2x6 Launch Failed: " err.Message)
            return false
        }
    }
}
