#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class PpssppLauncher
; * @location lib/emulator/types/PpssppLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk

class PpssppLauncher extends EmulatorBase {

    Launch(gameObj) {
        this.GameId := gameObj.Id

        emuPath := this.GetEmulatorPath("PPSSPP_PATH", "PpssppPath")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; Handle "Launch UI Only" (No ROM provided)
        if (gameObj.EbootIsoPath == "") {
            try {
                Run(emuPath, emuDir, , &newPid)
                ; Even for the UI, we should track it so it appears in Window Manager
                this.TrackProcess(newPid, emuPath, gameObj.Id)
                return true
            } catch {
                return false
            }
        }

        ; Clean up any hanging instances before starting
        this.KillProcess(exeName)

        ; Construct command: "path/to/emu.exe" --fullscreen "path/to/rom.iso"
        runCmd := Format('"{1}" --fullscreen "{2}"', emuPath, gameObj.EbootIsoPath)
        Logger.Info("Launching PPSSPP: " runCmd, this.__Class)

        try {
            ; Start the emulator and capture the PID via &newPid
            Run(runCmd, emuDir, , &newPid)

            if (newPid > 0) {

                Logger.Info("PPSSPPLauncher: Process started successfully. PID: " . newPid, "PPSSPPLauncher")
                ; --- THE SURGICAL FIX ---
                ; This triggers the ProcessManager session, RAM monitor,
                ; and updates ConfigManager all in one call.
                this.TrackProcess(newPid, emuPath, gameObj.Id)

                ; Tell Window Manager which process we are focusing on
                WindowManager.SetGameContext("ahk_pid " newPid)
                return true
            }
            return false
        } catch as err {
            Logger.Error("PPSSPP Launch Failed: " err.Message)
            return false
        }
    }
}