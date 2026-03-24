#Requires AutoHotkey v2.0
; ==============================================================================
; * @description
; * @class ConfigManager
; * @location lib/config/ConfigManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\core\JSON.ahk
#Include ..\ui\DialogsGui.ahk

class ConfigManager {
    static RootDir := StrReplace(A_ScriptDir, "\lib\config", "")
    static JsonPath := this.RootDir . "\nexus.json"
    static IniPath := this.RootDir . "\nexus.ini"
    static ActiveProcessName := ""
    static Games := Map()
    static WasLoaded := false
    static CurrentGameId := ""

    ; INITIALIZATION & LOADING
    static Init() {
        Logger.Info("Initializing ConfigManager...", "ConfigManager")
        this.EnsureRuntimeBootstrap()
        this.BackupConfig()

        this.LoadSettings()

        success := this.LoadGamesFromJson()

        if (success) {
            Logger.Info("Database loaded. Items: " . this.Games.Count, "ConfigManager")
            this.SanityCheck()
        }
        return success
    }

    static EnsureRuntimeBootstrap() {
        try {
            ; Runtime folders required on first launch
            if !DirExist(this.RootDir . "\data")
                DirCreate(this.RootDir . "\data")
            if !DirExist(this.RootDir . "\media")
                DirCreate(this.RootDir . "\media")
            if !DirExist(this.RootDir . "\media\snapshots")
                DirCreate(this.RootDir . "\media\snapshots")
            if !DirExist(this.RootDir . "\media\captures")
                DirCreate(this.RootDir . "\media\captures")

            ; Create default INI on first run when missing
            if !FileExist(this.IniPath) {
                defaultIni := "[SETTINGS]`n"
                    . "AudioFormat=wav`n"
                    . "SnapShotFormat=png`n"
                    . "LastGalleryPath=`n"
                    . "LastMusicPath=`n"
                    . "LastVideoPath=`n"
                    . "DebugVoiceCatalog=0`n"
                    . "VoiceDbRequirePrefix=0`n"
                    . "VoiceDbRequireWakeWord=0`n"
                    . "VoiceDbWakeWord=nexus`n"
                    . "VoiceDbUseConfidenceGate=0`n"
                    . "VoiceDbConfidenceMin=0.25`n"
                    . "VoiceDbHybridStt=0`n"
                    . "VoiceDbHybridSttTimeoutMs=7000`n"
                    . "VoiceUseWhisper=0`n"
                    . "VoiceWhisperTimeoutMs=10000`n"
                    . "VoiceUseConfidenceGate=0`n"
                    . "VoiceConfidenceMin=0.40`n"
                    . "VoiceLowConfidenceTipCooldownMs=3000`n"
                    . "VoiceDebugDeferredMs=1500`n"
                    . "BetaAuthEnabled=0`n"
                    . "BetaAuthHealthCheckOnStartup=0`n`n"
                    . "[LAST_PLAYED]`n"
                    . "GameID=`n"
                    . "GameTitle=`n"
                    . "LauncherType=`n"
                    . "ExePath=`n"
                    . "TimeStamp=`n"
                FileAppend(defaultIni, this.IniPath, "UTF-8")
                Logger.Info("ConfigMgr: Created default nexus.ini", "ConfigManager")
            }

            ; Create default JSON database on first run when missing
            if !FileExist(this.JsonPath) {
                FileAppend('{"GAMES":[]}', this.JsonPath, "UTF-8")
                Logger.Info("ConfigMgr: Created default nexus.json", "ConfigManager")
            }
        } catch as err {
            Logger.Warn("ConfigMgr: Runtime bootstrap failed: " . err.Message, "ConfigManager")
        }
    }

    static LoadGamesFromJson() {
        if !FileExist(this.JsonPath)
            return false

        try {
            rawText := FileRead(this.JsonPath, "UTF-8")
            rawText := RegExReplace(rawText, "^\x{FEFF}") ; Strip BOM

            ; Load RAW data (Usually returns Maps)
            data := JSON.parse(rawText)

            ; Extract the Array of games
            gameArray := []
            if (Type(data) == "Map" && data.Has("GAMES")) {
                gameArray := data["GAMES"]
            } else if (IsObject(data) && data.HasProp("GAMES")) {
                gameArray := data.GAMES
            }

            if !IsObject(gameArray)
                return false

            this.Games.Clear()

            ; Process each game entry
            for index, gameRaw in gameArray {

                ; NORMALIZE: Ensure we have an ID
                gameId := ""

                ; Check if it's a Map or Object
                isMap := (Type(gameRaw) == "Map")

                ; Helper to read properties safely
                GetProp := (obj, key) => (isMap ? (obj.Has(key) ? obj[key] : "") : (obj.HasOwnProp(key) ? obj.%key% : ""))

                gameId := GetProp(gameRaw, "Id")
                savedName := GetProp(gameRaw, "SavedName")

                ; If ID is missing, generate one from the name (Self-Repair on Load)
                if (gameId == "") {
                    if (savedName != "")
                        gameId := "GAME_" . RegExReplace(StrUpper(savedName), "[^A-Z0-9]", "_")
                    else
                        gameId := "GAME_UNKNOWN_" . index

                    ; Store the new ID inside the object
                    if (isMap)
                        gameRaw["Id"] := gameId
                    else
                        gameRaw.Id := gameId
                }

                ; STORE using ID as the Key
                this.Games[gameId] := gameRaw
            }

            this.WasLoaded := (this.Games.Count > 0)
            return true

        } catch as err {
            DialogsGui.CustomMsgBox("JSON Error", "Failed to parse nexus.json:`n" . err.Message, 0)
            return false
        }
    }

    static LoadSettings() {
        if FileExist(this.IniPath)
            this.CurrentGameId := IniRead(this.IniPath, "LAST_PLAYED", "GameID", "")
    }

    ; DATA INTEGRITY & VALIDATION (The Gatekeeper)
    static ValidateGameData(gameData) {
        ; Helper for Map/Object compatibility
        isMap := (Type(gameData) == "Map")
        Has := (k) => (isMap ? gameData.Has(k) : gameData.HasOwnProp(k))
        Get := (k) => (isMap ? gameData[k] : gameData.%k%)

        if !Has("Id") || (Get("Id") == "")
            throw Error("Game ID is missing.")

        if !Has("ApplicationPath") || (Get("ApplicationPath") == "")
            throw Error("ApplicationPath is missing.")

        if (Has("LauncherType") && Get("LauncherType") == "TEKNO") {
            if !Has("ProfileFile") || (Get("ProfileFile") == "")
                throw Error("TeknoParrot game is missing 'ProfileFile'.")
        }
        return true
    }

    static SanityCheck() {
        idsToDelete := []
        repairedCount := 0

        for id, game in this.Games {
            dirty := false
            isMap := (Type(game) == "Map")

            ; --- REPAIR: Ensure ID matches Key ---
            currentId := ""
            if (isMap)
                currentId := game.Has("Id") ? game["Id"] : ""
            else
                currentId := game.HasOwnProp("Id") ? game.Id : ""

            if (currentId == "") {
                if (isMap)
                    game["Id"] := id
                else
                    game.Id := id
                dirty := true
            }

            ; --- REPAIR: ApplicationPath (Legacy Support) ---
            appPath := ""
            if (isMap)
                appPath := game.Has("ApplicationPath") ? game["ApplicationPath"] : ""
            else
                appPath := game.HasOwnProp("ApplicationPath") ? game.ApplicationPath : ""

            if (appPath == "") {
                legacy := ""

                ; Check "Path"
                if (isMap)
                    legacy := game.Has("Path") ? game["Path"] : ""
                else
                    legacy := game.HasOwnProp("Path") ? game.Path : ""

                ; Check "EbootIsoPath"
                if (legacy == "") {
                    if (isMap)
                        legacy := game.Has("EbootIsoPath") ? game["EbootIsoPath"] : ""
                    else
                        legacy := game.HasOwnProp("EbootIsoPath") ? game.EbootIsoPath : ""
                }

                ; Check lowercase "applicationpath"
                if (legacy == "" && isMap && game.Has("applicationpath"))
                    legacy := game["applicationpath"]

                if (legacy != "") {
                    if (isMap)
                        game["ApplicationPath"] := legacy
                    else
                        game.ApplicationPath := legacy
                    dirty := true
                }
            }

            if (dirty)
                repairedCount++

            ; --- VALIDATE ---
            try {
                this.ValidateGameData(game)
            } catch as err {
                ; Get name for error message
                name := ""
                if (isMap)
                    name := game.Has("SavedName") ? game["SavedName"] : ""
                else
                    name := game.HasOwnProp("SavedName") ? game.SavedName : ""

                msg := "Corrupt Entry: " . (name ? name : id) . "`n"
                    . "Reason: " . err.Message . "`n`n"
                    . "Delete this entry?"

                if (DialogsGui.CustomMsgBox("Integrity Check", msg, 4) == "Yes")
                    idsToDelete.Push(id)
            }
        }

        if (repairedCount > 0 || idsToDelete.Length > 0) {
            for badId in idsToDelete
                this.Games.Delete(badId)

            this.SaveGames()
            if (repairedCount > 0)
                DialogsGui.CustomStatusPop("Repaired " . repairedCount . " legacy entries.")
        }
    }


    ; CORE GAME MANAGEMENT

    ; Retrieves the currently selected game object
    static GetCurrentGame() {
        ; 1. PRIORITY: Check the Live Variable first
        if (this.CurrentGameId != "" && this.Games.Has(this.CurrentGameId)) {
            return this.Games[this.CurrentGameId]
        }

        ; 2. FALLBACK: Only check INI if memory is empty
        iniId := IniRead(this.IniPath, "LAST_PLAYED", "GameID", "")
        if (iniId != "" && this.Games.Has(iniId)) {
            ; Sync memory with INI so next time it's faster
            this.CurrentGameId := iniId
            return this.Games[iniId]
        }

        return ""
    }

    ; Sets current game by ID (Preferred)
    static SetCurrentGame(gameId) {
        if this.Games.Has(gameId) {
            this.CurrentGameId := gameId
            return true
        }
        return false
    }

    ; Legacy support: Set by Name (Avoid if possible)
    static SetCurrentGameByName(name) {
        for id, gameData in this.Games {
            val := (Type(gameData) == "Map") ? gameData["SavedName"] : gameData.SavedName
            if (val == name) {
                this.CurrentGameId := id
                return true
            }
        }
        return false
    }


    static RegisterGame(gameId, dataObj, saveToDisk := true) {
        try {
            this.ValidateGameData(dataObj)
        } catch as err {
            Logger.Error("Registration Validation Failed: " err.Message, "ConfigManager")
            DialogsGui.CustomMsgBox("Save Aborted", "Cannot save game:`n" . err.Message, 0)
            return false
        }

        this.Games[gameId] := dataObj

        if (saveToDisk) {
            return this.SaveGames()
        }
        return true
    }

    ; Helper for when you are done with a bulk scan
    static CommitToDisk() {
        return this.SaveGames()
    }


    ; Legacy alias for compatibility
    static AddOrUpdateGame(name, path, launcherType) {
        ; NOTE: This is the old way. Ideally, refactor callers to use RegisterGame.
        ; Attempt to find existing ID by name
        foundId := ""
        for id, g in this.Games {
            sName := (Type(g) == "Map") ? g["SavedName"] : g.SavedName
            if (sName == name) {
                foundId := id
                break
            }
        }

        if (foundId == "") {
            ; Generate new ID
            foundId := "GAME_" . RegExReplace(StrUpper(name), "[^A-Z0-9]", "_")
        }

        newGame := Map()
        newGame["Id"] := foundId
        newGame["SavedName"] := name
        newGame["ApplicationPath"] := path
        newGame["LauncherType"] := launcherType
        newGame["SnapshotDir"] := "snapshots/" . foundId
        newGame["CaptureDir"] := "captures/" . foundId

        return this.RegisterGame(foundId, newGame)
    }

    static DeleteGame(gameId) {
        if (this.Games.Has(gameId)) {
            this.Games.Delete(gameId)
            this.SaveGames()
            if (this.CurrentGameId == gameId)
                this.CurrentGameId := ""
            ; Clear LAST_PLAYED if it points to the deleted game (regardless of what's selected now)
            try {
                if (IniRead(this.IniPath, "LAST_PLAYED", "GameID", "") == gameId) {
                    IniDelete(this.IniPath, "LAST_PLAYED", "GameID")
                    IniDelete(this.IniPath, "LAST_PLAYED", "ExeName")
                    IniDelete(this.IniPath, "LAST_PLAYED", "ExePID")
                }
            }
            return true
        }
        return false
    }

    static UpdateGamePath(gameId, newPath) {
        if (this.Games.Has(gameId)) {
            game := this.Games[gameId]
            if (Type(game) == "Map")
                game["ApplicationPath"] := newPath
            else
                game.ApplicationPath := newPath
            this.SaveGames()
            return true
        }
        return false
    }

    ; --- NOTES MANAGEMENT ---

    static UpdateGameNotes(gameId, noteText) {
        if !this.Games.Has(gameId)
            return false

        game := this.Games[gameId]

        ; Handle both Map (JSON) and Object types safely
        if (Type(game) == "Map") {
            game["Notes"] := noteText
        } else {
            game.Notes := noteText
        }

        return this.SaveGames()
    }

    static UpdateLastPlayed(gameId) {
        if (gameId == "" || !this.Games.Has(gameId))
            return

        game := this.Games[gameId]
        timeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        ; 1. Helper to extract data regardless of Map vs Object
        Val := (k) => (Type(game) == "Map" ? (game.Has(k) ? game[k] : "") : (game.HasOwnProp(k) ? game.%k% : ""))

        ; 2. Update Memory
        if (Type(game) == "Map")
            game["LastPlayed"] := timeStr
        else
            game.LastPlayed := timeStr

        this.CurrentGameId := gameId
        this.SaveGames()

        ; 3. Write Clean INI Section
        ; We explicitly define what to write to avoid "leftover" junk from previous runs
        IniWrite(gameId, this.IniPath, "LAST_PLAYED", "GameID")
        IniWrite(Val("SavedName"), this.IniPath, "LAST_PLAYED", "GameTitle")
        IniWrite(Val("LauncherType"), this.IniPath, "LAST_PLAYED", "LauncherType")

        ; Optional Fields (Only write if they exist)
        path := Val("ApplicationPath")
        if (path == "")
            path := Val("EbootIsoPath")

        IniWrite(path, this.IniPath, "LAST_PLAYED", "ExePath")
        IniWrite(timeStr, this.IniPath, "LAST_PLAYED", "TimeStamp")

        ; Clear old specific fields to prevent confusion (like PPSSPP showing for Tekno)
        try IniDelete(this.IniPath, "LAST_PLAYED", "ExeName")
        try IniDelete(this.IniPath, "LAST_PLAYED", "ExePID")
    }

    static SaveGames() {
        Logger.Debug("ConfigMgr: Writing database to disk...", "ConfigManager")
        try {
            gameArray := []
            for id, gameObj in ConfigManager.Games {
                gameArray.Push(gameObj)
            }
            finalData := Map("GAMES", gameArray)
            jsonString := JSON.stringify(finalData, 4)

            if FileExist(this.JsonPath)
                FileDelete(this.JsonPath)
            FileAppend(jsonString, this.JsonPath, "UTF-8")
            return true
        } catch as err {
            Logger.Error("ConfigMgr: File IO Error -> " . err.Message, "ConfigManager")
            return false
        }
    }

    ; --- UI HELPER METHODS ---

    static GetSortedList() {
        if !this.HasProp("Games") || this.Games.Count == 0
            return ["No Games Found"]

        nameArray := []
        for id, gameData in this.Games {
            name := (Type(gameData) == "Map") ? gameData["SavedName"] : gameData.SavedName
            nameArray.Push(name)
        }

        ; Simple Alphabetical Sort
        Loop nameArray.Length - 1 {
            i := A_Index
            Loop nameArray.Length - i {
                j := i + A_Index
                if (StrCompare(nameArray[i], nameArray[j]) > 0) {
                    temp := nameArray[i]
                    nameArray[i] := nameArray[j]
                    nameArray[j] := temp
                }
            }
        }
        return nameArray
    }

    ; DASHBOARD UI HELPERS

    static GetTotalLibraryTime() {
        totalSeconds := 0
        for id, game in this.Games {
            ; Handle both Map (JSON) and Object types safely
            t := (Type(game) == "Map") ? (game.Has("TotalPlayTime") ? game["TotalPlayTime"] : 0) : (game.HasOwnProp("TotalPlayTime") ? game.TotalPlayTime : 0)
            totalSeconds += t
        }
        return this.FormatSeconds(totalSeconds)
    }

    static GetTopGames(count := 3) {
        tempList := []
        for id, game in this.Games {
            ; Safety check for PlayTime presence
            t := (Type(game) == "Map") ? (game.Has("TotalPlayTime") ? game["TotalPlayTime"] : 0) : (game.HasOwnProp("TotalPlayTime") ? game.TotalPlayTime : 0)

            if (t > 0)
                tempList.Push(game)
        }

        ; Bubble Sort by PlayTime (Descending)
        if (tempList.Length > 1) {
            loop tempList.Length {
                i := A_Index
                loop tempList.Length - i {
                    j := A_Index

                    ; Helper to get time from item J and J+1
                    timeJ := (Type(tempList[j]) == "Map") ? tempList[j]["TotalPlayTime"] : tempList[j].TotalPlayTime
                    timeNext := (Type(tempList[j + 1]) == "Map") ? tempList[j + 1]["TotalPlayTime"] : tempList[j + 1].TotalPlayTime

                    if (timeJ < timeNext) {
                        temp := tempList[j], tempList[j] := tempList[j + 1], tempList[j + 1] := temp
                    }
                }
            }
        }

        ; Return top N results
        topResults := []
        loop Min(count, tempList.Length)
            topResults.Push(tempList[A_Index])
        return topResults
    }

    static FormatSeconds(s) {
        if (!IsNumber(s))
            return "0s"
        if (s < 60)
            return s . "s"
        if (s < 3600)
            return Round(s / 60, 1) . "m"
        return Round(s / 3600, 1) . "h"
    }

    static GetGameList() {
        list := []
        for id, game in this.Games
            list.Push(id)
        return list
    }

    ; Adds seconds to the total play time and saves
    static AddPlayTime(gameId, seconds) {
        if (gameId == "" || !this.Games.Has(gameId))
            return

        game := this.Games[gameId]

        ; 1. Get Current Time (Handle Map vs Object)
        currentTotal := 0
        if (Type(game) == "Map")
            currentTotal := game.Has("TotalPlayTime") ? game["TotalPlayTime"] : 0
        else
            currentTotal := game.HasOwnProp("TotalPlayTime") ? game.TotalPlayTime : 0

        ; 2. Add New Time
        newTotal := currentTotal + seconds

        ; 3. Save Back (Handle Map vs Object)
        if (Type(game) == "Map") {
            game["TotalPlayTime"] := newTotal
            game["PlayTimeReadable"] := this.FormatSeconds(newTotal)
        } else {
            game.TotalPlayTime := newTotal
            game.PlayTimeReadable := this.FormatSeconds(newTotal)
        }

        this.SaveGames()
    }

    ; --- WINDOW MANAGEMENT ---

    ; Saves window coordinates for a specific game
    static UpdateGameWindowProfile(gameId, x, y, w, h) {
        if (!this.Games.Has(gameId))
            return false

        game := this.Games[gameId]
        Logger.Info("ConfigMgr: Updating Window Profile for " . gameId . " [" w "x" h "]", "ConfigManager")

        isMap := (Type(game) == "Map")
        if (isMap) {
            game["WinX"] := x, game["WinY"] := y
            game["WinW"] := w, game["WinH"] := h
            game["HasWindowProfile"] := 1
        } else {
            game.WinX := x, game.WinY := y
            game.WinW := w, game.WinH := h
            game.HasWindowProfile := 1
        }

        return this.SaveGames()
    }

    static BackupConfig() {
        try {
            if FileExist(this.JsonPath)
                FileCopy(this.JsonPath, StrReplace(this.JsonPath, ".json", ".bak.json"), true)

            if FileExist(this.IniPath)
                FileCopy(this.IniPath, StrReplace(this.IniPath, ".ini", ".bak.ini"), true)

            Logger.Info("ConfigMgr: Safety backups created.", "ConfigManager")
        }
    }

    ; [PATCH] Compatibility for ProcessManager 2.0

    ; Updates playtime in memory only (No disk write = No lag)
    static UpdatePlayStats(gameId := "", seconds := 0) {
        if (gameId == "" || !this.Games.Has(gameId))
            return

        game := this.Games[gameId]

        ; Logic from your original AddPlayTime, but without saving
        currentTotal := (Type(game) == "Map")
            ? (game.Has("TotalPlayTime") ? game["TotalPlayTime"] : 0)
            : (game.HasOwnProp("TotalPlayTime") ? game.TotalPlayTime : 0)

        newTotal := currentTotal + seconds

        if (Type(game) == "Map") {
            game["TotalPlayTime"] := newTotal
            game["PlayTimeReadable"] := this.FormatSeconds(newTotal)
            game["LastPlayed"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        } else {
            game.TotalPlayTime := newTotal
            game.PlayTimeReadable := this.FormatSeconds(newTotal)
            game.LastPlayed := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        }
    }

    ; Alias for ProcessManager to call your existing save logic
    static SaveGameDatabase() {
        this.SaveGames()
    }

    normalOut := "Speakers (Realtek High Definition Audio)"
    normalIn  := "Microphone (Realtek High Definition Audio)"

    recOut := "Voicemeeter Input (VB-Audio Voicemeeter VAIO)"
    recIn  := "Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)"

}