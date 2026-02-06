#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Redream DreamCast emulator
; * @class RedreamLauncher
; * @location lib/emulator/types/RedreamLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk

class RedreamLauncher extends EmulatorBase {

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
        
        emuPath := this.GetEmulatorPath("REDREAM_PATH", "RedreamPath")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)
        gamePath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""

        ; UI Mode
        if (gamePath == "") {
            Run(emuPath, emuDir, , &pid)
            this.TrackProcess(pid, emuPath, "REDREAM_UI")
            return true
        }

        this.KillProcess(exeName)

        ; Redream auto-fullscreens if configured in its internal UI,
        ; but passing the path directly works best.
        runCmd := Format('"{1}" "{2}"', emuPath, gamePath)

        try {
            Run(runCmd, emuDir, , &pid)
            if (pid > 0) {
                this.TrackProcess(pid, emuPath, this.GameId)
                WindowManager.SetGameContext("ahk_pid " pid, 1)
                return true
            }
        } catch as err {
            Logger.Error("Redream Launch Failed: " err.Message)
        }
        return false
    }
}