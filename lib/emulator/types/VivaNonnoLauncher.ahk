#Requires AutoHotkey v2.0
; ==============================================================================
; * @description VivaNonnoLauncher Namco Arcade emulator
; * @class VivaNonnoLauncher
; * @location lib/emulator/types/VivaNonnoLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk

class VivaNonnoLauncher extends EmulatorBase {
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

        emuPath := this.GetEmulatorPath("VIVANONNO_PATH", "VivaNonnoPath")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)
        gamePath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""

        if (gamePath == "") {
            Run(emuPath, emuDir, , &pid)
            this.TrackProcess(pid, emuPath, "VIVANONNO_UI")
            return true
        }

        this.KillProcess(exeName)

        ; VivaNonno usually expects JUST the ROM name (e.g. "rr1.zip" or just "rr1")
        ; It also MUST run from its own directory.
        SplitPath(gamePath, &romFileName, , , &romNameNoExt)

        ; Logic: If file is zip, pass the name without extension
        targetArg := (SubStr(romFileName, -4) = ".zip") ? romNameNoExt : romFileName

        runCmd := Format('"{1}" {2}', emuPath, targetArg)

        try {
            ; Critical: WorkingDir must be emuDir
            Run(runCmd, emuDir, , &pid)
            if (pid > 0) {
                this.TrackProcess(pid, emuPath, this.GameId)
                WindowManager.SetGameContext("ahk_pid " pid, 1)
                return true
            }
        } catch as err {
            Logger.Error("VivaNonno Launch Failed: " err.Message)
        }
        return false
    }
}