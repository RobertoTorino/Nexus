#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Global Hotkeys (Game Controls & Tools)
; * @class GlobalHotkeys
; * @location lib/core/GlobalHotkeys.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\window\WindowManager.ahk
#Include ..\capture\AudioManager.ahk
#Include ..\core\Logger.ahk
#Include ..\ui\LoggerGui.ahk

; 1. TOOL SHORTCUTS

; CTRL + SHIFT + A -> Open Audio Manager
^+a:: AudioManager.ShowGui()

; CTRL + L -> Toggle Logger Console
^l:: {
    if (WinExist("Nexus :: Logger")) {
        LoggerGui.Hide()
        Logger.Info("Visual Log Disabled via Hotkey", "GlobalHotkeys")
    } else {
        LoggerGui.Show()
        Logger.Info("Visual Log Enabled via Hotkey", "GlobalHotkeys")
    }
}

; 2. GAME CONTROLS

#HotIf (WindowManager.ActiveGamePid > 0)

$Escape:: WindowManager.CloseActiveGame()

; [UPDATED] Uses the new "Nuclear Option" to kill all related processes
Escape & 1:: WindowManager.KillActiveGame()

#HotIf