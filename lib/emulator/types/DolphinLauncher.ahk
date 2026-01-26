#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class DolphinLauncher
; * @location lib/emulator/types/DolphinLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class DolphinLauncher extends EmulatorBase {

    Launch(gameObj) {
        this.GameId := gameObj.Id

        ; 1. Get Emulator Path
        emuPath := this.GetEmulatorPath("DOLPHIN_PATH", "DolphinPath")
        if !emuPath {
            DialogsGui.CustomMsgBox("Launch Error", "Dolphin executable not configured.", 0x10)
            return false
        }

        SplitPath(emuPath, &exeName, &emuDir)

        ; 2. Path Validation
        ; Support both old (EbootIsoPath) and new (ApplicationPath) JSON keys
        gamePath := gameObj.HasProp("ApplicationPath") ? gameObj.ApplicationPath : ""
        if (gamePath == "" && gameObj.HasProp("EbootIsoPath"))
            gamePath := gameObj.EbootIsoPath

        ; Fallback: Open GUI if no game file
        if (gamePath == "") {
            try {
                Run(emuPath, emuDir)
                return true
            } catch {
                return false
            }
        }

        ; 3. Cleanup & Prep
        this.KillProcess(exeName)
        CaptureManager.CurrentProcessName := exeName

        ; 4. Construct Command
        ; FIX: Use dashes (-) instead of slashes (/) for Qt-based Dolphin versions.
        ; -b = Batch (Exit when done)
        ; -e = Execute/Load File
        runCmd := Format('"{1}" -b -e "{2}"', emuPath, gamePath)

        Logger.Info("Launching Dolphin: " runCmd)

        try {
            Run(runCmd, emuDir, "UseErrorLevel", &newPid)

            if (newPid > 0) {
                this.UpdateLastPlayed(emuPath, newPid)

                ; 5. Ninja Move (Force Monitor 1)
                ; Wait up to 5 seconds for the window to appear
                if WinWait("ahk_pid " newPid, , 5) {
                    WindowManager.SetGameContext("ahk_pid " newPid, 1)

                    ; Double check focus
                    WinActivate("ahk_pid " newPid)
                    return true
                }

                ; Even if window isn't found immediately, return true as process is running
                Logger.Warn("Dolphin launched (PID: " newPid ") but window delay exceeded.")
                WindowManager.SetGameContext("ahk_pid " newPid, 1)
                return true
            }
            return false
        } catch as err {
            Logger.Error("Dolphin Launch Failed: " err.Message)
            DialogsGui.CustomMsgBox("Launch Error", "Dolphin failed to start.`n" . err.Message, 0x10)
            return false
        }
    }
}