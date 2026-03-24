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
        ; 1. Safe Property Access (Handles Map vs Object distinction)
        ; We try to get 'EbootIsoPath', but fallback to 'ApplicationPath' which always exists.
        isoPath := ""
        gameId := ""

        if (gameObj is Map) {
            gameId := gameObj.Has("Id") ? gameObj["Id"] : "Unknown"
            if gameObj.Has("EbootIsoPath")
                isoPath := gameObj["EbootIsoPath"]
            else if gameObj.Has("ApplicationPath")
                isoPath := gameObj["ApplicationPath"]
        }
        else {
            ; It's a standard Object
            gameId := gameObj.HasOwnProp("Id") ? gameObj.Id : "Unknown"
            if gameObj.HasOwnProp("EbootIsoPath")
                isoPath := gameObj.EbootIsoPath
            else if gameObj.HasOwnProp("ApplicationPath")
                isoPath := gameObj.ApplicationPath
        }

        this.GameId := gameId

        ; 2. Get Emulator Path
        emuPath := this.GetEmulatorPath("PPSSPP_PATH", "PpssppPath")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; 3. Handle "Launch UI Only" (No ROM provided)
        if (isoPath == "") {
            try {
                Run(emuPath, emuDir, , &newPid)
                this.TrackProcess(newPid, emuPath, gameId)
                return true
            } catch {
                return false
            }
        }

        ; 4. Cleanup & Launch
        this.KillProcess(exeName)

        ; Construct command: "path/to/emu.exe" --fullscreen "path/to/rom.iso"
        runCmd := Format('"{1}" --fullscreen "{2}"', emuPath, isoPath)
        Logger.Info("Launching PPSSPP: " runCmd)

        try {
            Run(runCmd, emuDir, , &newPid)

            if (newPid > 0) {
                Logger.Info("PPSSPPLauncher: Process started successfully. PID: " . newPid, "PpssppLauncher")
                this.TrackProcess(newPid, emuPath, gameId)
                WindowManager.SetGameContext("ahk_pid " newPid)
                return true
            }
            return false
        } catch as err {
            ; THIS LINE IS THE KEY:
            Logger.Error(Format("LAUNCH CRASH: {1} | File: {2} | Line: {3}", err.Message, err.File, err.Line))
            return false
        }
    }
}