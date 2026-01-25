#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class Pcsx2Launcher
; * @location lib/emulator/types/Pcsx2Launcher.ahk
; * @author Philip
; * @date 2026/01/06
; * @version 1.0.02 (Fixed Monitor Logic)
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk

class Pcsx2Launcher extends EmulatorBase {

    Launch(gameObj) {
        this.GameId := gameObj.Id

        ; Get Emulator Path (Using Base Class Helper)
        emuPath := this.GetEmulatorPath("PCSX2_PATH", "Pcsx2Path")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; Path Validation (Support both New and Old JSON keys)
        rawPath := gameObj.HasProp("ApplicationPath") ? gameObj.ApplicationPath : ""
        if (rawPath == "" && gameObj.HasProp("EbootIsoPath"))
            rawPath := gameObj.EbootIsoPath

        ; Fallback: Launch UI if no game selected
        if (rawPath == "") {
            Logger.Info("PCSX2: No ISO selected, launching UI.")
            try {
                Run(emuPath, emuDir)
                return true
            } catch {
                return false
            }
        }

        ; CRITICAL FIX: FORCE WINDOWS BACKSLASHES
        ; PCSX2 Command Line fails if paths use forward slashes (JSON style)
        isoPath := StrReplace(rawPath, "/", "\")

        ; Cleanup & Prep
        this.KillProcess(exeName)
        CaptureManager.CurrentProcessName := exeName ; Sync for Recording

        ; Launch
        ; ARGS: -batch (Exit on close) -fullscreen (Start FS) -- (File separator)
        runCmd := Format('"{1}" -batch -fullscreen -- "{2}"', emuPath, isoPath)
        Logger.Info("Launching PCSX2: " runCmd)

        try {
            Run(runCmd, emuDir, "UseErrorLevel", &newPid)

            if (newPid > 0) {
                this.UpdateLastPlayed(emuPath, newPid)

                ; "Ninja Move" Technique (Restored)
                ; Wait for the window to actually exist (max 3 seconds)
                if WinWait("ahk_pid " newPid, , 3) {

                    ; Force move immediately via WindowManager
                    WindowManager.SetGameContext("ahk_pid " newPid, 1)

                    Logger.Info("PCSX2 Launched & Moved (PID: " newPid ")")
                    return true
                }

                Logger.Warn("PCSX2 launched, but window not found within timeout.")
                return true
            }
            return false
        } catch as err {
            Logger.Error("PCSX2 Launch Failed: " err.Message)
            return false
        }
    }
}