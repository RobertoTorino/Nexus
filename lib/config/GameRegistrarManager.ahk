#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Handles adding games and assigning them to the Universal Launcher.
; * @class GameRegistrarManager
; * @location lib/config/GameRegistrarManager.ahk
; * @author Philip
; * @version 1.1.01 (Strict Sanitization Restored)
; ==============================================================================

#Include ConfigManager.ahk
#Include ..\core\Utilities.ahk
#Include ..\ui\DialogsGui.ahk
#Include TeknoParrotManager.ahk

class GameRegistrarManager {

    static AddGame() {
        path := FileSelect(3, , "Select Game Executable, ISO, or EBOOT",
            "All Supported (*.exe; *.bat; *.lnk; *.iso; *.cso; *.bin; *.cue; *.chd; *.pbp; *.elf; *.rvz; *.wbfs; *.gcm)")

        if (path == "")
            return false

        SplitPath(path, &fileName, &dir, &ext, &nameNoExt)

        config := { Path: path, Dir: dir, Name: nameNoExt, Ext: ext, Launcher: "NORMAL", App: fileName }

        if (fileName ~= "i)^eboot\.(bin|elf)$") {
            SplitPath(dir, &parentFolder)
            if (parentFolder ~= "i)^USRDIR$") {
                SplitPath(dir . "\..", &grandParent)
                config.Name := grandParent
            } else {
                config.Name := parentFolder
            }
        }

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

    static HandleStandard(config) {
        if (config.App ~= "i)TeknoParrotUi\.exe") {
            if (DialogsGui.AskForConfirmation("TeknoParrot Detected",
                "You selected the TeknoParrot Launcher.`nTo play TeknoParrot games, use the Profile Manager.`nOpen it now?")) {
                TeknoParrotManager.ShowPicker()
            }
            return false
        }
        config.Launcher := "STANDARD"
        return true
    }

    static HandleEboot(config) {
        if (config.Path ~= "i)(app|ux0|mai)") {
            choice := DialogsGui.AskForChoice("Select Vita3K Build", "Which emulator version?",
                ["Standard Vita3K", "Vita3K Build 3830"])
            if (choice == "")
            return false
            if (choice == "Vita3K Build 3830")
                return this.ConfigureEmulator(config, "VITA3K_3830", "VITA3K_3830", "Vita3k3830Path")
            else
                return this.ConfigureEmulator(config, "VITA3K", "VITA3K_PATH", "Vita3kPath")
        }

        choice := DialogsGui.AskForChoice("Select RPCS3 Build", "Which specialized build is this for?",
            ["Standard RPCS3", "Fighter Build", "Shooter Build", "TCRS Build"])
        if (choice == "")
        return false

        switch choice {
            case "Standard RPCS3": return this.ConfigureEmulator(config, "RPCS3", "RPCS3_PATH", "Rpcs3Path")
            case "Fighter Build":
                config.PatchGroup := "T6BR"
                config.IsPatchable := true
                return this.ConfigureEmulator(config, "FIGHTER", "RPCS3_FIGHTER", "Rpcs3FighterPath")
            case "Shooter Build":
                config.IsPatchable := true
                return this.ConfigureEmulator(config, "SHOOTER", "RPCS3_SHOOTER", "Rpcs3ShooterPath")
            case "TCRS Build": return this.ConfigureEmulator(config, "TCRS", "RPCS3_TCRS", "Rpcs3TcrsPath")
        }
        return false
    }

    static HandleIso(config) {
        choice := DialogsGui.AskForChoice("Select Platform", "Select Emulator:", ["PCSX2", "DUCKSTATION", "PPSSPP", "DOLPHIN"])
        if (choice == "")
        return false
        return this.ConfigureEmulator(config, choice, choice "_PATH", StrTitle(choice) "Path")
    }

    static ConfigureEmulator(config, type, iniSec, iniKey) {
        config.Launcher := type
        emuPath := IniRead(ConfigManager.IniPath, iniSec, iniKey, "")
        if (!FileExist(emuPath)) {
            emuPath := FileSelect(3, , "Select " type " Executable", "Emulator (*.exe)")
            if (!emuPath)
            return false
            IniWrite(emuPath, ConfigManager.IniPath, iniSec, iniKey)
        }
        return true
    }

    static FinalizeRegistration(config) {
        for id, game in ConfigManager.Games {
            existingPath := (Type(game) == "Map") ? (game.Has("ApplicationPath") ? game["ApplicationPath"] : "") : (game.HasOwnProp("ApplicationPath") ? game.ApplicationPath : "")
            if (StrReplace(existingPath, "/", "\") == StrReplace(config.Path, "/", "\")) {
                gameName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                if (DialogsGui.CustomMsgBox("Game Exists", "The game '" . gameName . "' is already in your library.`nPlay it now?", 4) == "Yes") {
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

        ; --- RESTORED STRICT SANITIZATION ---
        cleanDef := Utilities.SanitizeName(config.Name)

        if (config.Launcher != "STANDARD") {
            suffix := "_" . config.Launcher
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

        uniqueId := Utilities.GenerateUniqueId(friendlyName, ConfigManager.Games)
        safePath := StrReplace(config.Path, "\", "/")

        newGame := {
            Id: uniqueId,
            SavedName: friendlyName,
            ApplicationPath: safePath,
            LauncherType: config.Launcher,
            GameApplication: config.App,
            SnapshotDir: "snapshots/" . uniqueId,
            CaptureDir: "captures/" . uniqueId,
            EbootIsoPath: safePath
        }

        patchInfo := PatchServiceTool.IdentifyPatchableGame(config.App, config.Path)
        if (patchInfo != "") {
            newGame.IsPatchable := "true"
            newGame.PatchGroup := patchInfo.Name
            Logger.Info("Registrar: Detected Patchable Game (" . patchInfo.Name . ")")
        } else {
            newGame.IsPatchable := "false"
            newGame.PatchGroup := ""
        }

        if (newGame.ApplicationPath == "") {
            DialogsGui.CustomMsgBox("Error", "Invalid Game Path.", 16)
            return false
        }

        ConfigManager.RegisterGame(uniqueId, newGame)
        ConfigManager.CurrentGameId := uniqueId
        IniWrite(uniqueId, ConfigManager.IniPath, "LAST_PLAYED", "GameID")

        if IsSet(GuiBuilder) {
            GuiBuilder.RefreshDropdown()
            GuiBuilder.SelectLastPlayed()
            DialogsGui.CustomTrayTip("Added: " . friendlyName, 1)
        }
        return true
    }
}