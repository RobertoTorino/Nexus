#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Universal Launcher that coordinates Build + Game Patches
; * @class Rpcs3UniversalLauncher
; * @location lib/emulator/types/Rpcs3Launcher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk
#Include ..\..\config\ConfigManager.ahk
#Include ..\..\core\Logger.ahk

class Rpcs3UniversalLauncher {

    Pid := 0

    Launch(gameMap) {
        Logger.Info("RPCS3 Launcher: Starting launch sequence...")

        ; Universal map adapter
        game := {}
        if (Type(gameMap) == "Map") {
            for k, v in gameMap
                game.%k% := v
        } else {
            game := gameMap
        }

        ; 1. Path validation
        rawPath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""
        if (rawPath == "" && game.HasProp("EbootIsoPath"))
            rawPath := game.EbootIsoPath

        Logger.Debug("RPCS3 Launcher: Raw Path from Config: " . rawPath)

        if (rawPath == "") {
            Logger.Error("RPCS3 Launcher: Path is empty.")
            DialogsGui.CustomMsgBox("Launch Error", "Game file (EBOOT/ISO) path is missing.", 0x10)
            return false
        }

        ; FIX 1: Normalize Path
        gamePath := StrReplace(rawPath, "/", "\")
        Logger.Debug("RPCS3 Launcher: Normalized Path: " . gamePath)

        ; 2. Config Selection Logic
        iniKey := "Rpcs3Path"
        iniSec := "RPCS3_PATH"
        currentType := "Standard"

        if (game.HasProp("LauncherType")) {
            currentType := game.LauncherType
            Logger.Debug("RPCS3 Launcher: Detected Type: " . currentType)

            ; FIX 2: Correct INI Section Names
            switch StrUpper(game.LauncherType) {
                case "FIGHTER", "RPCS3_FIGHTER":
                    iniSec := "RPCS3_FIGHTER_PATH"
                    iniKey := "Rpcs3FighterPath"

                case "SHOOTER", "RPCS3_SHOOTER":
                    iniSec := "RPCS3_SHOOTER_PATH"
                    iniKey := "Rpcs3ShooterPath"

                case "TCRS", "RPCS3_TCRS":
                    iniSec := "RPCS3_TCRS_PATH"
                    iniKey := "Rpcs3TcrsPath"
            }
        }

        Logger.Debug("RPCS3 Launcher: Looking for Emulator in INI [" . iniSec . "] Key: " . iniKey)
        emuPath := IniRead(ConfigManager.IniPath, iniSec, iniKey, "")

        if (emuPath == "" || !FileExist(emuPath)) {
            err := "RPCS3 Launcher: Emulator EXE not found at '" . emuPath . "' using section [" . iniSec . "]"
            Logger.Error(err)
            DialogsGui.CustomMsgBox("Emulator Error", "RPCS3 Executable not found.`nCheck logs/config.", 0x10)
            return false
        }

        Logger.Info("RPCS3 Launcher: Emulator found: " . emuPath)

        SplitPath(emuPath, &emuExe, &emuDir)

        ; Tell CaptureManager what to watch
        CaptureManager.CurrentProcessName := emuExe

        ; 3. Run Command
        ; Log the exact command for future debugging
        runCmd := Format('"{1}" --no-gui --fullscreen "{2}"', emuPath, gamePath)
        Logger.Debug("RPCS3 Launcher: Command Line: " . runCmd)
        Logger.Debug("RPCS3 Launcher: Working Directory: " . emuDir)

        try {
            Run(runCmd, emuDir, , &outPid)
            this.Pid := outPid
            Logger.Info("RPCS3 Launcher: Process started successfully. PID: " . this.Pid)

            ; Tell WindowManager the PID
            if (this.Pid > 0) {
                WindowManager.SetGameContext("ahk_pid " this.Pid, 1)

                if (WinWait("ahk_pid " this.Pid, , 10)) {
                    WinActivate("ahk_pid " this.Pid)
                    WindowManager.SetGameContext("ahk_pid " this.Pid, 1)
                    Logger.Info("RPCS3 Launcher: Window activated and context set.")
                } else {
                    Logger.Warn("RPCS3 Launcher: Process started, but window did not appear within 10s.")
                }
            }
            return true

        } catch as err {
            Logger.Error("RPCS3 Launcher: Run() Exception: " . err.Message)
            DialogsGui.CustomMsgBox("Launch Failed", "RPCS3 Error: " . err.Message, 0x10)
            return false
        }
    }

    Stop() {
        if (this.Pid) {
            Logger.Info("RPCS3 Launcher: Stopping PID " . this.Pid)
            try ProcessClose(this.Pid)
            this.Pid := 0
        }
    }
}