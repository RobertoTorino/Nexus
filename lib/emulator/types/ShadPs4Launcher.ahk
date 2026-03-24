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
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk
#Include ..\..\config\ConfigManager.ahk
#Include ..\..\core\Logger.ahk

class ShadPs4Launcher extends EmulatorBase {

    Launch(gameMap) {
        Logger.Info("ShadPS4 Launcher: Starting launch sequence...", "ShadPs4Launcher")

        ; Universal map adapter
        game := {}
        if (Type(gameMap) == "Map") {
            for k, v in gameMap
                game.%k% := v
        } else {
            game := gameMap
        }

        this.GameId := game.HasProp("Id") ? game.Id : ""

        ; 1. Path validation
        rawPath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""
        Logger.Debug("ShadPS4 Launcher: Raw Path from Config: " . rawPath)

        if (rawPath == "") {
            Logger.Error("ShadPS4 Launcher: ApplicationPath is empty.")
            DialogsGui.CustomMsgBox("Launch Error", "Game file (eboot.bin) path is missing.", 0x10)
            return false
        }

        ; Normalize slashes
        gamePath := StrReplace(rawPath, "/", "\")

        ; 2. Locate emulator
        emuPath := IniRead(ConfigManager.IniPath, "SHADPS4_PATH", "ShadPs4Path", "")
        if (emuPath == "" || !FileExist(emuPath)) {
            Logger.Error("ShadPS4 Launcher: Emulator EXE not found at '" . emuPath . "'")
            DialogsGui.CustomMsgBox("Emulator Error", "shadPS4 executable not found.`nCheck logs/config.", 0x10)
            return false
        }

        SplitPath(emuPath, &emuExe, &emuDir)
        Logger.Info("ShadPS4 Launcher: Using exe: " . emuExe, "ShadPs4Launcher")

        ; Tell CaptureManager what to watch
        CaptureManager.CurrentProcessName := emuExe
        this.KillProcess(emuExe)

        ; shadPS4 CLI:  -f true     = fullscreen (requires explicit true/false value)
        ;               -g "path"   = game to launch
        runCmd := Format('"{1}" -f true -g "{2}"', emuPath, gamePath)
        Logger.Debug("ShadPS4 Launcher: Command Line: " . runCmd)

        try {
            Run(runCmd, emuDir, , &pid)
            this.Pid := pid
            Logger.Info("ShadPS4 Launcher: Process started. PID: " . pid, "ShadPs4Launcher")

            if (pid > 0) {
                this.TrackProcess(pid, emuPath, this.GameId)

                if (WinWait("ahk_pid " pid, , 20)) {
                    WinActivate("ahk_pid " pid)
                    WindowManager.SetGameContext("ahk_pid " pid, 1)
                    Logger.Info("ShadPS4 Launcher: Window activated, context set.", "ShadPs4Launcher")
                } else {
                    Logger.Warn("ShadPS4 Launcher: Process started but window did not appear within 20s.")
                }
                return true
            }
        } catch as err {
            Logger.Error("ShadPS4 Launch Failed: " . err.Message)
        }
        return false
    }
}