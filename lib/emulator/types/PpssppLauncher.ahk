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

        ; Handle "Launch UI Only"
        if (gameObj.EbootIsoPath == "") {
            try {
                Run(emuPath, emuDir)
                return true
            } catch {
                return false
            }
        }

        this.KillProcess(exeName)

        ; PPSSPP Specific Arguments
        runCmd := Format('"{1}" --fullscreen "{2}"', emuPath, gameObj.EbootIsoPath)
        Logger.Info("Launching PPSSPP: " runCmd)

        try {
            Run(runCmd, emuDir, "UseErrorLevel", &newPid)
            if (newPid > 0) {
                this.UpdateLastPlayed(emuPath, newPid)
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