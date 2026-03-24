#Requires AutoHotkey v2.0
; ==============================================================================
; * @description ShadPs4GuiLauncher — opens shadPS4QtLauncher.exe without CLI game args.
; *              Use this entry to open the emulator's own GUI (settings, update, etc.)
; *              Use the SHADPS4 entry (shadPS4.exe) for launching games from the library.
; * @class ShadPs4GuiLauncher
; * @location lib/emulator/types/ShadPs4GuiLauncher.ahk
; * @author Philip
; * @date 2026/02/22
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk
#Include ..\..\config\ConfigManager.ahk
#Include ..\..\core\Logger.ahk

class ShadPs4GuiLauncher extends EmulatorBase {

    Launch(gameMap) {
        Logger.Info("ShadPS4 GUI Launcher: Opening Qt launcher...", "ShadPs4GuiLauncher")

        ; Locate configured exe
        emuPath := IniRead(ConfigManager.IniPath, "SHADPS4_GUI_PATH", "ShadPs4GuiPath", "")
        if (emuPath == "" || !FileExist(emuPath)) {
            Logger.Error("ShadPS4 GUI Launcher: Exe not found at '" . emuPath . "'")
            DialogsGui.CustomMsgBox("Emulator Error", "shadPS4 Qt Launcher not found.`nCheck Emulator Config.", 0x10)
            return false
        }

        SplitPath(emuPath, &emuExe, &emuDir)
        CaptureManager.CurrentProcessName := emuExe

        ; No game args — just open the launcher UI
        try {
            Run(emuPath, emuDir)
            Logger.Info("ShadPS4 GUI Launcher: Opened.", "ShadPs4GuiLauncher")
            return true
        } catch as err {
            Logger.Error("ShadPS4 GUI Launcher: Failed: " . err.Message)
        }
        return false
    }
}
