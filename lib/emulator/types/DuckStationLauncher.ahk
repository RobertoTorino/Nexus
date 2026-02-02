#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class DuckStationLauncher
; * @location lib/emulator/types/DuckStationLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk ; <--- CRITICAL IMPORT
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk

; --- CRITICAL CHANGE: Inherit from EmulatorBase ---
class DuckStationLauncher extends EmulatorBase {

    ; Note: 'Pid' is already defined in EmulatorBase, so we don't need to redeclare it here.

    Launch(gameMap) {
        ; 1. Map Adapter (Kept for compatibility)
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

        ; 3. Get Emulator Path (Using Base Class Helper)
        emuPath := this.GetEmulatorPath("DUCKSTATION_PATH", "DuckStationPath")
        if !emuPath
            return false

        SplitPath(emuPath, &emuExe, &emuDir)

        ; 4. Prepare Capture
        if IsSet(CaptureManager)
            CaptureManager.CurrentProcessName := emuExe

        ; 5. Launch Arguments
        runCmd := Format('"{1}" -batch -fullscreen -- "{2}"', emuPath, gamePath)

        try {
            Run(runCmd, emuDir, , &outPid)
            this.Pid := outPid

            if (this.Pid > 0) {
                ; --- THE FIX: CONNECT TO PROCESS MANAGER ---
                ; This triggers RAM monitoring, Session Timer, and Config updates
                this.TrackProcess(this.Pid, emuPath, game.Id)

                ; Force Monitor 1 (Specific DuckStation logic)
                WindowManager.SetGameContext("ahk_pid " this.Pid, 1)

                ; Wait for window to ensure it snaps correctly
                if WinWait("ahk_pid " this.Pid, , 10) {
                    WinActivate("ahk_pid " this.Pid)
                    WindowManager.SetGameContext("ahk_pid " this.Pid, 1)
                }
            }
            return true

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Failed", "DuckStation Error: " . err.Message, 0x10)
            return false
        }
    }

    ; Note: Removed the Stop() method because EmulatorBase already has a
    ; robust Stop() method that handles PIDs and ProcessManager sessions automatically.
}