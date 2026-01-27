#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Handles adding games and assigning them to the Universal Launcher.
; * @class GameRegistrarManager
; * @location lib/config/GameRegistrarManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ConfigManager.ahk
#Include ..\core\Utilities.ahk
#Include ..\ui\DialogsGui.ahk
#Include TeknoParrotManager.ahk

class GameRegistrarManager {

    ; MAIN ENTRY POINT
    static AddGame() {
        path := FileSelect(3, , "Select Game Executable, ISO, or EBOOT",
            "All Supported (*.exe; *.bat; *.lnk; *.iso; *.cso; *.bin; *.cue; *.chd; *.pbp; *.elf; *.rvz; *.wbfs; *.gcm)")

        if (path == "")
            return false

        SplitPath(path, &fileName, &dir, &ext, &nameNoExt)

        ; Use a Map for the temporary config to keep things consistent
        config := Map("Path", path, "Dir", dir, "Name", nameNoExt, "Ext", ext, "Launcher", "NORMAL", "App", fileName)

        ; Better Naming for EBOOTs
        if (fileName ~= "i)^eboot\.(bin|elf)$") {
            SplitPath(dir, &parentFolder)
            if (parentFolder ~= "i)^USRDIR$") {
                SplitPath(dir . "\..", &grandParent)
                config["Name"] := grandParent
            } else {
                config["Name"] := parentFolder
            }
        }

        ; Routing Logic
        if (fileName ~= "i)^eboot\.(bin|elf)$") {
            if !this.HandleEboot(config)
                return false
        }
        else if (ext ~= "i)^(iso|cso|bin|cue|chd|pbp|rvz|wbfs|gcm)$") {
            if !this.HandleIso(config)
                return false
        }
        else {
            if !this.HandleStandard(config)
                return false
        }

        return this.FinalizeRegistration(config)
    }

    ; HANDLERS
    static HandleStandard(config) {
        if (config["App"] ~= "i)TeknoParrotUi\.exe") {
            if (DialogsGui.CustomMsgBox("TeknoParrot Detected",
                "You selected the TeknoParrot Launcher.`nTo play TeknoParrot games, use the Profile Manager.`nOpen it now?", 0, 4) == "Yes") {
                TeknoParrotManager.ShowPicker()
            }
            return false
        }
        config["Launcher"] := "STANDARD"
        return true
    }

    static HandleEboot(config) {
        ; --- VITA3K DETECTION ---
        if (config["Path"] ~= "i)(app|ux0|mai)") {
            choice := DialogsGui.AskForChoice("Select Vita3K Build", "Which emulator version?",
                ["Standard Vita3K", "Vita3K Build 3830"])

            if (choice == "")
                return false

            if (choice == "Vita3K Build 3830") {
                return this.ConfigureEmulator(config, "VITA3K_3830", "VITA3K_3830", "Vita3k3830Path")
            } else {
                return this.ConfigureEmulator(config, "VITA3K", "VITA3K_PATH", "Vita3kPath")
            }
        }

        ; --- RPCS3 DETECTION ---
        choice := DialogsGui.AskForChoice("Select RPCS3 Build", "Which specialized build is this for?",
            ["Standard RPCS3", "Fighter Build", "Shooter Build", "TCRS Build"])

        if (choice == "")
            return false

        switch choice {
            case "Standard RPCS3":
                return this.ConfigureEmulator(config, "RPCS3", "RPCS3_PATH", "Rpcs3Path")
            case "Fighter Build":
                config["PatchGroup"] := "T6BR"
                config["IsPatchable"] := true
                return this.ConfigureEmulator(config, "FIGHTER", "RPCS3_FIGHTER", "Rpcs3FighterPath")
            case "Shooter Build":
                config["IsPatchable"] := true
                return this.ConfigureEmulator(config, "SHOOTER", "RPCS3_SHOOTER", "Rpcs3ShooterPath")
            case "TCRS Build":
                return this.ConfigureEmulator(config, "TCRS", "RPCS3_TCRS", "Rpcs3TcrsPath")
        }
        return false
    }

    static HandleIso(config) {
        choice := DialogsGui.AskForChoice("Select Platform", "Select Emulator:", ["PCSX2", "DUCKSTATION", "PPSSPP", "DOLPHIN"])
        if (choice == "")
            return false

        ; [FIX] Manual mapping to avoid "StrTitle is not a function" error
        iniKey := ""
        switch choice {
            case "PCSX2":       iniKey := "Pcsx2Path"
            case "DUCKSTATION": iniKey := "DuckStationPath"
            case "PPSSPP":      iniKey := "PpssppPath"
            case "DOLPHIN":     iniKey := "DolphinPath"
        }

        return this.ConfigureEmulator(config, choice, choice "_PATH", iniKey)
    }

    static ConfigureEmulator(config, type, iniSec, iniKey) {
        config["Launcher"] := type
        emuPath := IniRead(ConfigManager.IniPath, iniSec, iniKey, "")

        if (!FileExist(emuPath)) {
            emuPath := FileSelect(3, , "Select " type " Executable", "Emulator (*.exe)")
            if (!emuPath)
                return false
            IniWrite(emuPath, ConfigManager.IniPath, iniSec, iniKey)
        }
        return true
    }

    ; REGISTRATION FINALIZATION
    static FinalizeRegistration(config) {

        ; 1. DUPLICATE CHECK
        for id, game in ConfigManager.Games {
            ; Robust property extraction (works for Map or Object)
            existingPath := (Type(game) == "Map") ? (game.Has("ApplicationPath") ? game["ApplicationPath"] : "") : (game.HasOwnProp("ApplicationPath") ? game.ApplicationPath : "")

            ; Normalize checks (Backslashes can match Forward slashes)
            if (StrReplace(existingPath, "/", "\") == StrReplace(config["Path"], "/", "\")) {

                gameName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName

                if (DialogsGui.CustomMsgBox("Game Exists", "The game '" . gameName . "' is already in your library.`nPlay it now?", 0, 4) == "Yes") {
                    ConfigManager.CurrentGameId := id
                    if IsSet(GuiBuilder) {
                        GuiBuilder.RefreshDropdown()
                        GuiBuilder.SelectLastPlayed()
                    }
                    return true
                }
                return false
            }
        }

        ; 2. SANITIZE & NAME
        cleanDef := Utilities.SanitizeName(config["Name"])
        if (config["Launcher"] != "STANDARD") {
            suffix := "_" . config["Launcher"]
            defName := !InStr(cleanDef, suffix) ? cleanDef . suffix : cleanDef
        } else {
            defName := cleanDef
        }

        userInput := DialogsGui.AskForString("Game Name", "Enter display name:", defName)
        if (userInput == "")
            return false

        friendlyName := Utilities.SanitizeName(userInput)
        if (friendlyName == "")
            friendlyName := defName

        ; 3. GENERATE ID & PATHS
        uniqueId := Utilities.GenerateUniqueId(friendlyName, ConfigManager.Games)
        safePath := StrReplace(config["Path"], "\", "/")

        ; 4. BUILD MAP (Use Map, NOT Object, for better JSON/ConfigManager compatibility)
        newGame := Map()
        newGame["Id"] := uniqueId
        newGame["SavedName"] := friendlyName
        newGame["ApplicationPath"] := safePath
        newGame["LauncherType"] := config["Launcher"]
        newGame["GameApplication"] := config["App"]
        newGame["SnapshotDir"] := "snapshots/" . uniqueId
        newGame["CaptureDir"] := "captures/" . uniqueId
        newGame["EbootIsoPath"] := safePath

        ; Transfer Patch flags if detected earlier
        if (config.Has("IsPatchable"))
            newGame["IsPatchable"] := config["IsPatchable"]
        else
            newGame["IsPatchable"] := "false"

        if (config.Has("PatchGroup"))
            newGame["PatchGroup"] := config["PatchGroup"]
        else {
            ; Check patch tool just in case
            if IsSet(PatchServiceTool) {
                patchInfo := PatchServiceTool.IdentifyPatchableGame(config["App"], config["Path"])
                if (patchInfo != "") {
                    newGame["IsPatchable"] := "true"
                    newGame["PatchGroup"] := patchInfo.Name
                }
            }
        }

        ; 5. SAVE AND REFRESH
        ConfigManager.RegisterGame(uniqueId, newGame)
        ConfigManager.CurrentGameId := uniqueId
        IniWrite(uniqueId, ConfigManager.IniPath, "LAST_PLAYED", "GameID")

        if IsSet(GuiBuilder) {
            GuiBuilder.RefreshDropdown()
            GuiBuilder.SelectLastPlayed()
            DialogsGui.CustomStatusPop("Added: " . friendlyName)
        }

        return true
    }
}