
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
#Include ..\..\core\Logger.ahk ; <--- NEW IMPORT

class RomScanner {

    static PrefixMap := Map(
        "PPSSPP",       "[PSP]",
        "PCSX2",        "[PS2]",
        "DUCKSTATION",  "[PS1]",
        "RPCS3",        "[PS3]",
        "VITA3K",       "[VITA]",
        "DOLPHIN",      "[GC/WII]",
        "TEKNO",        "[ARCADE]"
    )

    static Scan(emulatorName, extensionList) {
        iniSection := "ROM_PATHS"
        iniKey := emulatorName . "_RomDir"

        currentDir := IniRead(ConfigManager.IniPath, iniSection, iniKey, "")

        if (currentDir != "" && DirExist(currentDir)) {
            msg := "Current " . emulatorName . " Folder:`n" . currentDir . "`n`nScan this folder?"
            if (DialogsGui.CustomMsgBox("Scan Setup", msg, 4) == "No")
                currentDir := ""
        }

        if (currentDir == "") {
            currentDir := DirSelect("", 3, "Select " . emulatorName . " ROMs Folder")
            if (currentDir == "") {
                Logger.Info("Scan Cancelled: User did not select a folder.", this.__Class)
                return
            }
            IniWrite(currentDir, ConfigManager.IniPath, iniSection, iniKey)
        }

        Logger.Info("Starting Scan :: Emu: " . emulatorName . " | Path: " . currentDir, "RomScanner")

        addedCount := 0
        skippedCount := 0
        prefix := this.PrefixMap.Has(emulatorName) ? this.PrefixMap[emulatorName] . " " : ""

        Loop Files, currentDir . "\*.*", "R" {
            if (this.HasExtension(A_LoopFileExt, extensionList)) {

                ; 1. Clean filename
                cleanName := StrReplace(A_LoopFileName, "." . A_LoopFileExt, "")
                cleanName := StrReplace(cleanName, "_", " ")

                ; 2. GENERATE CLEAN ID (Unicode Safe)
                safeName := Utilities.SanitizeName(cleanName)

                gameId := "GAME_" . StrUpper(emulatorName) . "_" . StrUpper(safeName)

                ; 3. Check for Duplicates
                if (ConfigManager.Games.Has(gameId)) {
                    ; Log skips at DEBUG level to avoid spamming the main log file
                    ; (Change to Info if you really want to see every skip)
                    skippedCount++
                    continue
                }

                newGame := Map()
                newGame["Id"] := gameId
                newGame["SavedName"] := prefix . cleanName
                newGame["ApplicationPath"] := A_LoopFileFullPath
                newGame["LauncherType"] := StrUpper(emulatorName)
                newGame["AddedDate"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")

                ConfigManager.Games[gameId] := newGame
                addedCount++

                ; Log Success
                Logger.Info("Scanned: " . cleanName . " -> ID: " . gameId, this.__Class)
            }
        }

        addedCount := 0
                skippedCount := 0
                prefix := this.PrefixMap.Has(emulatorName) ? this.PrefixMap[emulatorName] . " " : ""

                Loop Files, currentDir . "\*.*", "R" {
                    if (this.HasExtension(A_LoopFileExt, extensionList)) {

                        ; 1. Clean filename
                        cleanName := StrReplace(A_LoopFileName, "." . A_LoopFileExt, "")
                        cleanName := StrReplace(cleanName, "_", " ")

                        ; 2. Path Normalization (Crucial for Duplicate Checking)
                        ; We replace backslashes to match ConfigManager's internal format
                        safePath := StrReplace(A_LoopFileFullPath, "\", "/")

                        ; 3. IMPROVED DUPLICATE CHECK
                        ; Instead of guessing the ID, we check if the path already exists
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

                        ; 4. Generate New ID
                        safeName := Utilities.SanitizeName(cleanName)
                        gameId := "GAME_" . StrUpper(emulatorName) . "_" . StrUpper(safeName)

                        ; Ensure ID is unique even if name is similar
                        if ConfigManager.Games.Has(gameId)
                            gameId .= "_" . A_TickCount

                        newGame := Map()
                        newGame["Id"] := gameId
                        newGame["SavedName"] := prefix . cleanName
                        newGame["ApplicationPath"] := safePath
                        newGame["LauncherType"] := StrUpper(emulatorName)
                        newGame["AddedDate"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")

                        ; 5. Use RegisterGame for proper validation and saving
                        ConfigManager.RegisterGame(gameId, newGame)
                        addedCount++

                        Logger.Info("Scanned: " . cleanName . " -> ID: " . gameId, "RomScanner")
                    }
                }

                if (addedCount > 0) {
                    Logger.Info("Scan Finished. Added: " . addedCount, "RomScanner")
                    ; FIX: Change this.__Class to a valid color code or name
                    DialogsGui.CustomStatusPop("Added: " . addedCount . " (Skipped: " . skippedCount . ")", "004466")

                    if IsSet(GuiBuilder)
                        GuiBuilder.RefreshDropdown()
                } else {
                    Logger.Info("Scan Finished. No new games found.", "RomScanner")
                    ; FIX: Change this.__Class to a valid color code or name
                    DialogsGui.CustomStatusPop("No new games found.", "Silver")
                }
            }
            }