#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class DuckStationLauncher
; * @location lib/emulator/types/DuckStationLauncher.ahk
; * @author Philip
; * @date 2026/01/17
; * @version 1.0.0
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class DuckStationLauncher {

    Pid := 0

    Launch(gameMap) {
        ; 1. Map Adapter
        game := {}
        if (Type(gameMap) == "Map") {
            for k, v in gameMap
                game.%k% := v
        } else {
            game := gameMap
        }

        ; 2. Validate Game Path
        gamePath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""
        if (gamePath == "" && game.HasProp("EbootIsoPath"))
            gamePath := game.EbootIsoPath

        if (gamePath == "") {
            DialogsGui.CustomMsgBox("Launch Error", "Game ISO/CUE path is missing.", 0x10)
            return false
        }

        ; 3. Get Emulator Path
        emuPath := IniRead(ConfigManager.IniPath, "DUCKSTATION_PATH", "DuckStationPath", "")
        if (emuPath == "" || !FileExist(emuPath)) {
            DialogsGui.CustomMsgBox("Emulator Error", "DuckStation Executable not found.", 0x10)
            return false
        }

        SplitPath(emuPath, &emuExe, &emuDir)

        ; 4. Prepare Capture
        CaptureManager.CurrentProcessName := emuExe

        ; 5. Launch
        ; -batch: Exit when closed
        ; -fullscreen: Start in fullscreen
        ; -- : End arguments, start path
        runCmd := Format('"{1}" -batch -fullscreen -- "{2}"', emuPath, gamePath)

        try {
            Run(runCmd, emuDir, , &outPid)
            this.Pid := outPid

            if (this.Pid > 0) {
                ; --- CRITICAL FIX: FORCE MONITOR 1 ---
                WindowManager.SetGameContext("ahk_pid " this.Pid, 1)

                ; Wait for window to appear
                if WinWait("ahk_pid " this.Pid, , 10) {
                    WinActivate("ahk_pid " this.Pid)

                    ; Re-assert Monitor 1
                    WindowManager.SetGameContext("ahk_pid " this.Pid, 1)
                }
            }
            return true

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Failed", "DuckStation Error: " . err.Message, 0x10)
            return false
        }
    }

    Stop() {
        if (this.Pid) {
            try ProcessClose(this.Pid)
            this.Pid := 0
        }
    }
}