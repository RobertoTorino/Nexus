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
#Include ..\EmulatorRegistry.ahk

class RomScanner {

    static Scan(emulatorName, extensionList) {
        iniSection := "ROM_PATHS"
        iniKey := emulatorName . "_RomDir"
        currentDir := IniRead(ConfigManager.IniPath, iniSection, iniKey, "")

        if (currentDir != "" && DirExist(currentDir)) {
            msg := "Current " . emulatorName . " Game Folder:`n" . currentDir . "`n`nScan this folder?"
            if (DialogsGui.CustomMsgBox("Scan Setup", msg, 0, 4) == "No")
                currentDir := ""
        }

        if (currentDir == "") {
            currentDir := DialogsGui.SelectFolder("Select " . emulatorName . " Game Folder")
            if (currentDir == "")
                return
            IniWrite(currentDir, ConfigManager.IniPath, iniSection, iniKey)
        }

        Logger.Info("Starting Scan :: Emu: " . emulatorName, "RomScanner")
        addedCount := 0
        skippedCount := 0
        prefixTag := EmulatorRegistry.GetRomPrefix(emulatorName)
        prefix := (prefixTag != "") ? prefixTag . " " : ""

        ; --- VIVANONNO / TEKNO ZIP FIX ---
        ; If scanning for Arcade, force add .zip to the allowed list if not present
        if (emulatorName = "VIVANONNO" || emulatorName = "TEKNO") {
            hasZip := false
            for ext in extensionList
                if (ext = "zip")
                    hasZip := true
            if !hasZip
                extensionList.Push("zip")
        }
        ; ---------------------------------

        Loop Files, currentDir . "\*.*", "R" {
            ext := StrLower(A_LoopFileExt)

            ; 1. Extension Check
            if (!this.HasExtension(ext, extensionList))
                continue

            SplitPath(A_LoopFileFullPath, , &dir, , &nameNoExt)

            ; 2a. SHADPS4 / SHADPS4_GUI: only accept eboot.bin; derive game name from parent folder
            if (emulatorName = "SHADPS4" || emulatorName = "SHADPS4_GUI") {
                if (StrLower(A_LoopFileExt) != "bin" || StrLower(A_LoopFileName) != "eboot.bin") {
                    skippedCount++
                    continue
                }
                ; Use the parent folder name as the game title, strip leading [PS4] tag
                ; since PrefixMap will prepend it again
                SplitPath(dir, &folderName)
                cleanName := RegExReplace(folderName, "i)^\\[PS4\\]\\s*", "")
                cleanName := Trim(cleanName)
                safePath  := StrReplace(A_LoopFileFullPath, "\\", "/")

                ; Duplicate check
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

                safeName := Utilities.SanitizeName(cleanName)
                gameId   := "GAME_SHADPS4_" . StrUpper(safeName)
                if ConfigManager.Games.Has(gameId)
                    gameId .= "_" . A_TickCount

                launcherType := (emulatorName = "SHADPS4_GUI") ? "SHADPS4_GUI" : "SHADPS4"

                newGame := Map()
                newGame["Id"]              := gameId
                newGame["SavedName"]       := prefix . cleanName
                newGame["ApplicationPath"] := safePath
                newGame["LauncherType"]    := launcherType
                newGame["AddedDate"]       := FormatTime(, "yyyy-MM-dd HH:mm:ss")
                newGame["GameApplication"] := "eboot.bin"

                ConfigManager.RegisterGame(gameId, newGame, false)
                addedCount++
                continue
            }

            ; 2a2. VITA3K: expect ...\ux0\app\<TITLEID>\eboot.bin and use TITLEID as display name
            if (emulatorName = "VITA3K") {
                if (StrLower(A_LoopFileExt) != "bin" || StrLower(A_LoopFileName) != "eboot.bin") {
                    skippedCount++
                    continue
                }

                if !RegExMatch(A_LoopFileFullPath, "i)\\ux0\\app\\([^\\]+)\\eboot\.bin$", &m) {
                    skippedCount++
                    continue
                }

                titleId := Trim(m[1])
                if (titleId = "") {
                    skippedCount++
                    continue
                }

                safePath := StrReplace(A_LoopFileFullPath, "\\", "/")

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

                safeName := Utilities.SanitizeName(titleId)
                gameId   := "GAME_VITA3K_" . StrUpper(safeName)
                if ConfigManager.Games.Has(gameId)
                    gameId .= "_" . A_TickCount

                newGame := Map()
                newGame["Id"]              := gameId
                newGame["SavedName"]       := prefix . titleId
                newGame["ApplicationPath"] := safePath
                newGame["LauncherType"]    := "VITA3K"
                newGame["AddedDate"]       := FormatTime(, "yyyy-MM-dd HH:mm:ss")
                newGame["GameApplication"] := "eboot.bin"

                ConfigManager.RegisterGame(gameId, newGame, false)
                addedCount++
                continue
            }

            ; 2b. INTELLIGENT FILTER: Ignore .bin if .cue exists
            if (ext == "bin") {
                ; A. Check for exact match (Game.bin -> Game.cue)
                cuePath := dir . "\" . nameNoExt . ".cue"
                if (FileExist(cuePath)) {
                    skippedCount++
                    continue
                }

                ; B. Check for "Track" files (Game (Track 1).bin)
                ; Most PS1 games split into tracks. We only want the .cue file.
                if (InStr(nameNoExt, "Track") || InStr(nameNoExt, "(Track")) {
                    skippedCount++
                    continue
                }
            }

            ; 3. Prepare Data
            safePath := StrReplace(A_LoopFileFullPath, "\", "/")
            cleanName := nameNoExt
            cleanName := StrReplace(cleanName, "_", " ")

            ; 4. Check for Duplicates (Path based)
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

            ; 5. Register
            safeName := Utilities.SanitizeName(cleanName)
            gameId := "GAME_" . StrUpper(emulatorName) . "_" . StrUpper(safeName)
            if ConfigManager.Games.Has(gameId)
                gameId .= "_" . A_TickCount

            newGame := Map()
            newGame["Id"] := gameId
            newGame["SavedName"] := prefix . cleanName
            newGame["ApplicationPath"] := safePath
            newGame["LauncherType"] := StrUpper(emulatorName)
            newGame["AddedDate"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")

            if (cleanName = "EBOOT.BIN")
                newGame["GameApplication"] := "EBOOT.BIN"

            ConfigManager.RegisterGame(gameId, newGame, false)
            addedCount++
        }

        if (addedCount > 0) {
            ConfigManager.SaveGames()
            DialogsGui.CustomStatusPop("Added: " . addedCount . " (Skipped: " . skippedCount . ")")
            if IsSet(GuiBuilder)
                GuiBuilder.RefreshDropdown()
        } else {
            DialogsGui.CustomStatusPop("No new games found.`nSkipped: " . skippedCount)
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