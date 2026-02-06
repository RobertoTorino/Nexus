#Requires AutoHotkey v2.0
; ==============================================================================
; * @description ShadPs4Launcher PS4 emulator
; * @class ShadPs4Launcher
; * @location lib/emulator/types/ShadPs4Launcher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk

class ShadPs4Launcher extends EmulatorBase {

    Launch(gameMap) {
        ; --- MAP FIX ---
        game := {}
        if (Type(gameMap) == "Map") {
            for k, v in gameMap
                game.%k% := v
        } else {
            game := gameMap
        }

        this.GameId := game.Id

        emuPath := this.GetEmulatorPath("SHADPS4_PATH", "ShadPs4Path")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)
        gamePath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""

        if (gamePath == "") {
            Run(emuPath, emuDir, , &pid)
            this.TrackProcess(pid, emuPath, "SHADPS4_UI")
            return true
        }

        this.KillProcess(exeName)

        ; Arguments: -f (fullscreen) is standard for Qt-based emus
        runCmd := Format('"{1}" -f "{2}"', emuPath, gamePath)

        try {
            Run(runCmd, emuDir, , &pid)
            if (pid > 0) {
                this.TrackProcess(pid, emuPath, this.GameId)

                ; Qt windows can be slow to appear
                if WinWait("ahk_pid " pid, , 5)
                    WindowManager.SetGameContext("ahk_pid " pid, 1)

                return true
            }
        } catch as err {
            Logger.Error("ShadPS4 Launch Failed: " err.Message)
        }
        return false
    }
}