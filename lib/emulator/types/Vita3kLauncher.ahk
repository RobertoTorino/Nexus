#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Contains the correct arguments for launching games in fullscreen without the Gui.
; * @class Vita3kLauncher
; * @location lib/emulator/types/Vita3kLauncher.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\..\window\WindowManager.ahk
#Include ..\..\capture\CaptureManager.ahk
#Include ..\..\ui\DialogsGui.ahk

class Vita3kLauncher {

    Pid := 0

    Launch(gameMap) {
        ; Map Adapter
        game := {}
        if (Type(gameMap) == "Map") {
            for k, v in gameMap
                game.%k% := v
        } else {
            game := gameMap
        }

        ; Validate Game Path
        gamePath := game.HasProp("ApplicationPath") ? game.ApplicationPath : ""
        if (gamePath == "" && game.HasProp("EbootIsoPath"))
            gamePath := game.EbootIsoPath

        if (gamePath == "") {
            DialogsGui.CustomMsgBox("Launch Error", "EBOOT.BIN path is missing.", 0x10)
            return false
        }

        ; Determine Emulator Version (Standard vs 3830)
        iniSection := "VITA3K_PATH"
        iniKey := "Vita3kPath"
        typeLabel := "Standard"

        if (game.HasProp("LauncherType") && game.LauncherType == "VITA3K_3830") {
            iniSection := "VITA3K_3830_PATH"
            iniKey := "Vita3k3830Path"
            typeLabel := "Build 3830"
        }

        emuPath := IniRead(ConfigManager.IniPath, iniSection, iniKey, "")
        if (emuPath == "" || !FileExist(emuPath)) {
            DialogsGui.CustomMsgBox("Emulator Error", "Vita3K Executable not found for: " . typeLabel, 0x10)
            return false
        }

        SplitPath(emuPath, &emuExe, &emuDir)

        ; Extract Title ID
        titleId := this.GetTitleId(gamePath)

        if (titleId == "") {
            DialogsGui.CustomMsgBox("Launch Error", "Could not determine Title ID from path:`n" . gamePath, 0x10)
            return false
        }

        Logger.Info("Vita3K Launching ID: " . titleId . " using " . typeLabel)

        ; Prepare Capture
        CaptureManager.CurrentProcessName := emuExe

        ; Launch
        ; Use Uppercase -F and place it BEFORE -r
        runCmd := Format('"{1}" -F -r {2}', emuPath, titleId)

        try {
            Run(runCmd, emuDir, , &outPid)

            ; WAIT FOR WINDOW (Legacy Logic Restored)
            ; Vita3K might spawn a secondary process. Wait for the EXE window.
            if WinWait("ahk_exe " emuExe, , 7) {
                ; Get the REAL PID from the visible window
                realPid := WinGetPID("ahk_exe " emuExe)
                this.Pid := realPid

                ; Force Monitor 1 immediately
                WindowManager.SetGameContext("ahk_pid " this.Pid, 1)

                ; Ensure it's active
                WinActivate("ahk_pid " this.Pid)
                return true
            } else {
                ; Fallback if window detection fails (e.g. invalid game ID)
                this.Pid := outPid
                return true
            }

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Failed", "Vita3K Error: " . err.Message, 0x10)
            return false
        }
    }

    Stop() {
        if (this.Pid) {
            try ProcessClose(this.Pid)
            this.Pid := 0
        }
    }

    ; ROBUST TITLE ID PARSER
    GetTitleId(fullPath) {
        cleanPath := StrReplace(fullPath, "/", "\")

        SplitPath(cleanPath, , &parentDir)
        SplitPath(parentDir, &folderName)

        if (this.IsValidId(folderName))
            return folderName

        SplitPath(parentDir, , &grandParentDir)
        SplitPath(grandParentDir, &grandFolderName)

        if (this.IsValidId(grandFolderName))
            return grandFolderName

        if RegExMatch(cleanPath, "i)[\\/]([A-Z]{4}\d{5})[\\/]", &match)
            return match[1]

        return ""
    }

    IsValidId(id) {
        return RegExMatch(id, "i)^[A-Z]{4}\d{5}$")
    }
}