#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Launcher for Yuzu (Nintendo Switch)
; * @class YuzuLauncher
; * @location lib/emulator/types/YuzuLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class YuzuLauncher extends EmulatorBase {

    Launch(gameMap) {
        ; --- UNIVERSAL ADAPTER (Fixes "Map has no property" error) ---
        game := {}
        if (Type(gameMap) == "Map") {
            for k, v in gameMap
                game.%k% := v
        } else {
            game := gameMap
        }

        this.GameId := game.Id

        ; 1. Get Emulator Path
        emuPath := this.GetEmulatorPath("YUZU_PATH", "YuzuPath")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; 2. Validate Game Path
        gamePath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""

        ; If path is missing, check the fallback key
        if (gamePath == "" && game.HasProp("EbootIsoPath"))
            gamePath := game.EbootIsoPath

        ; --- UI ONLY MODE ---
        if (gamePath == "") {
            try {
                Run(emuPath, emuDir, , &pid)
                this.TrackProcess(pid, emuPath, "YUZU_UI")
                return true
            } catch {
                return false
            }
        }

        ; 3. Prepare Launch
        this.KillProcess(exeName)

        ; 4. Construct Command
        ; Syntax: yuzu.exe -f -g "C:\Path\To\Game.nsp"
        runCmd := Format('"{1}" -f -g "{2}"', emuPath, gamePath)

        Logger.Info("Launching Yuzu: " . runCmd, this.__Class)

        try {
            Run(runCmd, emuDir, , &pid)

            if (pid > 0) {
                ; 5. Process Tracking
                this.TrackProcess(pid, emuPath, this.GameId)

                ; 6. Window Management
                if WinWait("ahk_pid " pid, , 5) {
                    WindowManager.SetGameContext("ahk_pid " pid, 1)
                    WinActivate("ahk_pid " pid)
                }

                return true
            }
            return false

        } catch as err {
            Logger.Error("Yuzu Launch Failed: " . err.Message)
            DialogsGui.CustomMsgBox("Launch Error", "Yuzu failed to start.`n" . err.Message, 0x10)
            return false
        }
    }
}