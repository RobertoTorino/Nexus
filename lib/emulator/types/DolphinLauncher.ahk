#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class DolphinLauncher
; * @location lib/emulator/types/DolphinLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class DolphinLauncher extends EmulatorBase {

    Launch(gameObj) {
        this.GameId := gameObj.Id
        Logger.Info("DolphinLauncher: Starting launch sequence for ID: [" . this.GameId . "]", "DolphinLauncher")

        ; 1. Get Emulator Path
        emuPath := this.GetEmulatorPath("DOLPHIN_PATH", "DolphinPath")
        if !emuPath {
            Logger.Error("DolphinLauncher: emuPath is empty. Check nexus.ini.", "DolphinLauncher")
            DialogsGui.CustomMsgBox("Launch Error", "Dolphin executable not configured.", 0x10)
            return false
        }

        SplitPath(emuPath, &exeName, &emuDir)
        Logger.Debug("DolphinLauncher: Resolved Exe: " . exeName . " | Dir: " . emuDir, "DolphinLauncher")

        ; 2. Path Validation
        gamePath := gameObj.HasProp("ApplicationPath") ? gameObj.ApplicationPath : ""
        if (gamePath == "" && gameObj.HasProp("EbootIsoPath"))
            gamePath := gameObj.EbootIsoPath

        if (gamePath == "") {
            Logger.Warn("DolphinLauncher: No ROM path found. Launching emulator GUI only.", "DolphinLauncher")
            try {
                Run(emuPath, emuDir)
                return true
            } catch as err {
                Logger.Error("DolphinLauncher: Failed to open GUI: " . err.Message, "DolphinLauncher")
                return false
            }
        }

        Logger.Info("DolphinLauncher: Target ROM detected -> " . gamePath, "DolphinLauncher")

        ; 3. Cleanup & Prep
        Logger.Debug("DolphinLauncher: Cleaning up existing instances of " . exeName, "DolphinLauncher")
        this.KillProcess(exeName)
        CaptureManager.CurrentProcessName := exeName

        ; 4. Construct Command
        runCmd := Format('"{1}" -b -e "{2}"', emuPath, gamePath)
        Logger.Info("DolphinLauncher: Executing Command: " . runCmd, "DolphinLauncher")

        try {
            ; Capture PID using the 4th parameter (3 commas)
            Run(runCmd, emuDir, , &newPid)

            if (newPid > 0) {
                Logger.Info("DolphinLauncher: Process started successfully. PID: " . newPid, "DolphinLauncher")
                this.UpdateLastPlayed(emuPath, newPid)

                ; 5. Hand-off to WindowManager
                ; This triggers the loop that waits for the visible window
                Logger.Debug("DolphinLauncher: Registering with WindowManager...", "DolphinLauncher")
                WindowManager.RegisterGame(newPid, this.GameId, 1, exeName)

                return true
            } else {
                Logger.Error("DolphinLauncher: Run executed but failed to return a valid PID.", "DolphinLauncher")
                return false
            }
        } catch as err {
            Logger.Error("DolphinLauncher: Exception during Run -> " . err.Message, "DolphinLauncher")
            DialogsGui.CustomMsgBox("Launch Error", "Dolphin failed to start.`n" . err.Message, 0x10)
            return false
        }
    }
}