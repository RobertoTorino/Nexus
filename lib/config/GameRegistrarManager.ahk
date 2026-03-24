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
        Logger.Info("AddGame sequence initiated.", "GameRegistrarManager")

        path := FileSelect(3, , "Select Game Executable, ISO, or EBOOT",
            "All Supported (*.exe; *.bat; *.lnk; *.iso; *.cso; *.bin; *.cue; *.chd; *.pbp; *.elf; *.rvz; *.wbfs; *.gcm)")

        if (path == "") {
            Logger.Warn("File selection cancelled by user.", "GameRegistrarManager")
            return false
        }

        SplitPath(path, &fileName, &dir, &ext, &nameNoExt)
        Logger.Debug("Path selected: " . path, "GameRegistrarManager")

        ; Use a Map for the temporary config to keep things consistent
        config := Map("Path", path, "Dir", dir, "Name", nameNoExt, "Ext", ext, "Launcher", "NORMAL", "App", fileName)

        ; Better Naming for EBOOTs
        if (fileName ~= "i)^eboot\.(bin|elf)$") {
            Logger.Debug("EBOOT detected. Adjusting naming logic...", "GameRegistrarManager")
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
            Logger.Info("Routing to EBOOT handler.", "GameRegistrarManager")
            if !this.HandleEboot(config)
                return false
        }
        else if (ext ~= "i)^(iso|cso|bin|cue|chd|pbp|rvz|wbfs|gcm)$") {
            Logger.Info("Routing to ISO handler.", "GameRegistrarManager")
            if !this.HandleIso(config)
                return false
        }
        else {
            Logger.Info("Routing to Standard (EXE) handler.", "GameRegistrarManager")
            if !this.HandleStandard(config)
                return false
        }

        return this.FinalizeRegistration(config)
    }

    ; HANDLERS
    static HandleStandard(config) {
        if (config["App"] ~= "i)TeknoParrotUi\.exe") {
            Logger.Info("TeknoParrot executable detected. Redirecting to TP Manager.", "GameRegistrarManager")
            if (DialogsGui.CustomMsgBox("TeknoParrot Detected",
                "You selected the TeknoParrot Launcher.`nTo play TeknoParrot games, use the Profile Manager.`nOpen it now?", 0, 4) == "Yes") {
                TeknoParrotManager.ShowPicker()
            }
            return false
        }
        config["Launcher"] := "STANDARD"
        Logger.Debug("Launcher type set to: STANDARD", "GameRegistrarManager")
        return true
    }

    static HandleEboot(config) {
        ; --- VITA3K DETECTION ---
        if (config["Path"] ~= "i)(app|ux0|mai)") {
            Logger.Info("Vita3K structure detected.", "GameRegistrarManager")
            choice := DialogsGui.AskForChoice("Select Vita3K Build", "Which emulator version?",
                ["Standard Vita3K", "Vita3K Build 3830"])

            if (choice == "") {
                Logger.Warn("Vita3K selection cancelled.", "GameRegistrarManager")
                return false
            }

            if (choice == "Vita3K Build 3830") {
                return this.ConfigureEmulator(config, "VITA3K_3830", "VITA3K_3830", "Vita3k3830Path")
            } else {
                return this.ConfigureEmulator(config, "VITA3K", "VITA3K_PATH", "Vita3kPath")
            }
        }

        ; --- PS3 vs PS4 DETECTION ---
        Logger.Info("EBOOT detected, requesting platform choice.", "GameRegistrarManager")
        platform := DialogsGui.AskForChoice("Select Platform", "Which console is this game for?",
            ["PS3  (RPCS3)", "PS4  (shadPS4)"])

        if (platform == "") {
            Logger.Warn("Platform selection cancelled.", "GameRegistrarManager")
            return false
        }

        ; --- PS4 / SHADPS4 ---
        if (InStr(platform, "PS4")) {
            Logger.Info("PS4 selected. Routing to shadPS4.", "GameRegistrarManager")
            return this.ConfigureEmulator(config, "SHADPS4", "SHADPS4_PATH", "ShadPs4Path")
        }

        ; --- PS3 / RPCS3 ---
        Logger.Info("PS3 selected. Requesting RPCS3 Build choice.", "GameRegistrarManager")
        choice := DialogsGui.AskForChoice("Select RPCS3 Build", "Which specialized build is this for?",
            ["Standard RPCS3", "Fighter Build", "Shooter Build", "TCRS Build"])

        if (choice == "") {
            Logger.Warn("RPCS3 selection cancelled.", "GameRegistrarManager")
            return false
        }

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
        Logger.Info("ISO/ROM detected, requesting platform choice.", "GameRegistrarManager")
        choice := DialogsGui.AskForChoice("Select Platform", "Select Emulator:", ["PCSX2", "DUCKSTATION", "PPSSPP", "DOLPHIN"])

        if (choice == "") {
            Logger.Warn("ISO Platform selection cancelled.", "GameRegistrarManager")
            return false
        }

        Logger.Info("User selected platform: " . choice, "GameRegistrarManager")

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
        Logger.Debug("Checking emulator path for " . type . " in INI.", "GameRegistrarManager")

        if (!FileExist(emuPath)) {
            Logger.Warn("Emulator path missing on disk for " . type, "GameRegistrarManager")
            emuPath := FileSelect(3, , "Select " type " Executable", "Emulator (*.exe)")
            if (!emuPath) {
                Logger.Error("Manual emulator selection cancelled.", "GameRegistrarManager")
                return false
            }
            IniWrite(emuPath, ConfigManager.IniPath, iniSec, iniKey)
            Logger.Info("Updated INI with new emulator path: " . emuPath, "GameRegistrarManager")
        }
        return true
    }

    ; REGISTRATION FINALIZATION
    static FinalizeRegistration(config) {
        Logger.Info("Finalizing registration for: " . config["Name"], "GameRegistrarManager")

        ; 1. DUPLICATE CHECK
        for id, game in ConfigManager.Games {
            existingPath := (Type(game) == "Map") ? (game.Has("ApplicationPath") ? game["ApplicationPath"] : "") : (game.HasOwnProp("ApplicationPath") ? game.ApplicationPath : "")

            if (StrReplace(existingPath, "/", "\") == StrReplace(config["Path"], "/", "\")) {
                gameName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                Logger.Warn("Duplicate detected: '" . gameName . "' already exists with ID: " . id, "GameRegistrarManager")

                if (DialogsGui.CustomMsgBox("Game Exists", "The game '" . gameName . "' is already in your library.`nPlay it now?", 0, 4) == "Yes") {
                    ConfigManager.CurrentGameId := id
                    if IsSet(GuiBuilder) {
                        GuiBuilder.RefreshDropdown()
                        GuiBuilder.SelectLastPlayed()
                        GuiBuilder.OnStartAction()
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

        Logger.Debug("Prompting user for display name. Default: " . defName, "GameRegistrarManager")
        userInput := DialogsGui.AskForString("Game Name", "Enter display name:", defName)
        if (userInput == "") {
            Logger.Warn("User aborted at naming step.", "GameRegistrarManager")
            return false
        }

        friendlyName := Utilities.SanitizeName(userInput)
        if (friendlyName == "")
            friendlyName := defName

        ; 3. GENERATE ID & PATHS
        uniqueId := Utilities.GenerateUniqueId(friendlyName, ConfigManager.Games)
        Logger.Info("Generated Unique ID: [" . uniqueId . "]", "GameRegistrarManager")
        safePath := StrReplace(config["Path"], "\", "/")

        ; 4. BUILD MAP
        Logger.Debug("Building game data map...", "GameRegistrarManager")
        newGame := Map()
        newGame["Id"] := uniqueId
        newGame["SavedName"] := friendlyName
        newGame["ApplicationPath"] := safePath
        newGame["LauncherType"] := config["Launcher"]
        newGame["GameApplication"] := config["App"]
        newGame["SnapshotDir"] := "snapshots/" . uniqueId
        newGame["CaptureDir"] := "captures/" . uniqueId
        newGame["EbootIsoPath"] := safePath

        ; Transfer Patch flags
        if (config.Has("IsPatchable"))
            newGame["IsPatchable"] := config["IsPatchable"]
        else
            newGame["IsPatchable"] := "false"

        if (config.Has("PatchGroup")) {
            newGame["PatchGroup"] := config["PatchGroup"]
        } else {
            Logger.Debug("Scanning for available patches...", "GameRegistrarManager")
            if IsSet(PatchServiceTool) {
                patchInfo := PatchServiceTool.IdentifyPatchableGame(config["App"], config["Path"])
                if (patchInfo != "") {
                    newGame["IsPatchable"] := "true"
                    newGame["PatchGroup"] := patchInfo.Name
                    Logger.Info("Patch group identified: " . patchInfo.Name, "GameRegistrarManager")
                }
            }
        }

        ; 5. SAVE AND REFRESH
        Logger.Info("Sending new game data to ConfigManager...", "GameRegistrarManager")
        ConfigManager.RegisterGame(uniqueId, newGame)
        Logger.Info("Successfully registered game: " . uniqueId, "GameRegistrarManager")

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