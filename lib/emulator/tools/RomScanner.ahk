#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Scans folders for ROMs and adds them to the ConfigManager
; * @class RomScanner
; * @location lib/utils/RomScanner.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ================================================================================

; --- DEPENDENCY IMPORTS --
#Include ..\..\config\ConfigManager.ahk
#Include ..\..\ui\DialogsGui.ahk
#Include ..\..\core\Logger.ahk

class RomScanner {

    static PrefixMap := Map(
        "PPSSPP",       "[PSP]",
        "PCSX2",        "[PS2]",
        "DUCKSTATION",  "[PS1]",
        "RPCS3",        "[PS3]",
        "VITA3K",       "[VITA]",
        "DOLPHIN",      "[GC/WII]",
        "TEKNO",        "[ARCADE]",
        "REDREAM",      "[DC]",
        "SHADPS4",      "[PS4]",
        "VIVANONNO",    "[RR]",
        "YUZU",         "[SW]"
    )

    static Scan(emulatorName, extensionList) {
        iniSection := "ROM_PATHS"
        iniKey := emulatorName . "_RomDir"

        currentDir := IniRead(ConfigManager.IniPath, iniSection, iniKey, "")

        if (currentDir != "" && DirExist(currentDir)) {
            msg := "Current " . emulatorName . " Folder:`n" . currentDir . "`n`nScan this folder?"

            ; --- FIX: Adjusted parameters for new DialogsGui ---
            ; Arg 3 (Timeout) = 0 (No timeout)
            ; Arg 4 (Options) = 4 (Yes/No buttons)
            if (DialogsGui.CustomMsgBox("Scan Setup", msg, 0, 4) == "No")
                currentDir := ""
        }

        if (currentDir == "") {
            currentDir := DirSelect("", 3, "Select " . emulatorName . " ROMs Folder")
            if (currentDir == "") {
                Logger.Info("Scan Cancelled: User did not select a folder.", "RomScanner")
                return
            }
            IniWrite(currentDir, ConfigManager.IniPath, iniSection, iniKey)
        }

        Logger.Info("Starting Scan :: Emu: " . emulatorName . " | Path: " . currentDir, "RomScanner")

        addedCount := 0
        skippedCount := 0
        prefix := this.PrefixMap.Has(emulatorName) ? this.PrefixMap[emulatorName] . " " : ""

        ; --- SINGLE OPTIMIZED LOOP ---
        Loop Files, currentDir . "\*.*", "R" {
            if (this.HasExtension(A_LoopFileExt, extensionList)) {

                ; 1. Clean Path and Name
                safePath := StrReplace(A_LoopFileFullPath, "\", "/")
                cleanName := StrReplace(A_LoopFileName, "." . A_LoopFileExt, "")
                cleanName := StrReplace(cleanName, "_", " ")

                ; 2. Path Normalization Duplicate Check (Highest Accuracy)
                alreadyExists := false
                for id, game in ConfigManager.Games {
                    existingPath := (Type(game) == "Map") ? game["ApplicationPath"] : game.ApplicationPath
                    if (existingPath == safePath) {
                        alreadyExists := true
                        break
                    }
                }

                if (alreadyExists) {
                    skippedCount++
                    continue
                }

                ; 3. Generate ID and Handle Collisions
                safeName := Utilities.SanitizeName(cleanName)
                gameId := "GAME_" . StrUpper(emulatorName) . "_" . StrUpper(safeName)

                if ConfigManager.Games.Has(gameId)
                    gameId .= "_" . A_TickCount

                ; 4. Prepare and Register
                newGame := Map()
                newGame["Id"] := gameId
                newGame["SavedName"] := prefix . cleanName
                newGame["ApplicationPath"] := safePath
                newGame["LauncherType"] := StrUpper(emulatorName)
                newGame["AddedDate"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")

                ; We pass 'false' to defer saving until the loop is done
                ConfigManager.RegisterGame(gameId, newGame, false)
                addedCount++

                Logger.Info("Scanned: " . cleanName . " -> ID: " . gameId, "RomScanner")
            }
        }

        ; --- FINISH AND NOTIFY ---
        if (addedCount > 0) {
            ; --- PERFORMANCE FIX: SAVE ONCE AT THE END ---
            ConfigManager.SaveGames()

            Logger.Info("Scan Finished. Added: " . addedCount, "RomScanner")
            DialogsGui.CustomStatusPop("Added: " . addedCount . " (Skipped: " . skippedCount . ")")

            if IsSet(GuiBuilder)
                GuiBuilder.RefreshDropdown()
        } else {
            Logger.Info("Scan Finished. No new games found.", "RomScanner")
            DialogsGui.CustomStatusPop("No new games found.")
        }
    }

    static HasExtension(ext, list) {
        needle := StrLower(ext)
        for item in list {
            if (StrLower(item) == needle)
                return true
        }
        return false
    }
}