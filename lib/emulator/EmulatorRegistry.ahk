#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Central emulator metadata registry used by UI, scanner, and add-game logic.
; * @class EmulatorRegistry
; * @location lib/emulator/EmulatorRegistry.ahk
; * @author Philip
; * @date 2026/07/08
; * @version 1.0.00
; ==============================================================================

class EmulatorRegistry {
    static _defs := [
        { Name: "DOLPHIN", Section: "DOLPHIN_PATH", Key: "DolphinPath", RomExts: ["gcm", "iso", "rvz", "wbfs"], Prefix: "[GC/WII]", SupportsIsoChoice: true, LauncherClass: "DOLPHIN", SettingsSection: "DOLPHIN_SETTINGS" },
        { Name: "DUCKSTATION", Section: "DUCKSTATION_PATH", Key: "DuckStationPath", RomExts: ["bin", "chd", "cue", "iso"], Prefix: "[PS1]", SupportsIsoChoice: true, LauncherClass: "DUCKSTATION", SettingsSection: "DUCKSTATION_SETTINGS" },
        { Name: "PCSX2", Section: "PCSX2_PATH", Key: "Pcsx2Path", RomExts: ["bin", "chd", "gz", "iso"], Prefix: "[PS2]", SupportsIsoChoice: true, LauncherClass: "PCSX2", SettingsSection: "PCSX2_SETTINGS" },
        { Name: "PCSX2X6", Section: "PCSX2X6_PATH", Key: "Pcsx2x6Path", RomExts: ["acgame"], Prefix: "[ARCADE]", SupportsIsoChoice: false, LauncherClass: "PCSX2X6", SettingsSection: "PCSX2X6_SETTINGS" },
        { Name: "PPSSPP", Section: "PPSSPP_PATH", Key: "PpssppPath", RomExts: ["cso", "elf", "iso", "pbp"], Prefix: "[PSP]", SupportsIsoChoice: true, LauncherClass: "PPSSPP", SettingsSection: "PPSSPP_SETTINGS" },
        { Name: "REDREAM", Section: "REDREAM_PATH", Key: "RedreamPath", RomExts: ["gdi", "cdi", "chd"], Prefix: "[DC]", SupportsIsoChoice: false, LauncherClass: "REDREAM", SettingsSection: "REDREAM_SETTINGS" },
        { Name: "RPCS3", Section: "RPCS3_PATH", Key: "Rpcs3Path", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3", SettingsSection: "RPCS3_SETTINGS" },
        { Name: "RPCS3_FIGHTER", Section: "RPCS3_FIGHTER_PATH", Key: "Rpcs3FighterPath", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3", SettingsSection: "RPCS3_FIGHTER_SETTINGS" },
        { Name: "RPCS3_SHOOTER", Section: "RPCS3_SHOOTER_PATH", Key: "Rpcs3ShooterPath", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3", SettingsSection: "RPCS3_SHOOTER_SETTINGS" },
        { Name: "RPCS3_TCRS", Section: "RPCS3_TCRS_PATH", Key: "Rpcs3TcrsPath", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3", SettingsSection: "RPCS3_TCRS_SETTINGS" },
        { Name: "SHADPS4", Section: "SHADPS4_PATH", Key: "ShadPs4Path", RomExts: ["bin"], Prefix: "[PS4]", SupportsIsoChoice: false, LauncherClass: "SHADPS4", SettingsSection: "SHADPS4_SETTINGS" },
        { Name: "SHADPS4_GUI", Section: "SHADPS4_GUI_PATH", Key: "ShadPs4GuiPath", Prefix: "[PS4]", SupportsIsoChoice: false, LauncherClass: "SHADPS4_GUI", SettingsSection: "SHADPS4_GUI_SETTINGS" },
        { Name: "TEKNO", Section: "TEKNO_PATH", Key: "TeknoPath", Prefix: "[ARCADE]", SupportsIsoChoice: false, LauncherClass: "TEKNO", SettingsSection: "TEKNO_SETTINGS" },
        { Name: "VITA3K", Section: "VITA3K_PATH", Key: "Vita3kPath", Prefix: "[VITA]", SupportsIsoChoice: false, LauncherClass: "VITA3K", SettingsSection: "VITA3K_SETTINGS" },
        { Name: "VIVANONNO", Section: "VIVANONNO_PATH", Key: "VivaNonnoPath", RomExts: ["zip"], Prefix: "[RR]", SupportsIsoChoice: false, LauncherClass: "VIVANONNO", SettingsSection: "VIVANONNO_SETTINGS" },
        { Name: "YUZU", Section: "YUZU_PATH", Key: "YuzuPath", RomExts: ["nsp", "xci"], Prefix: "[SW]", SupportsIsoChoice: false, LauncherClass: "YUZU", SettingsSection: "YUZU_SETTINGS" }
    ]

    static _customDefs := []

    static _launcherAliases := Map(
        "FIGHTER", "RPCS3",
        "SHOOTER", "RPCS3",
        "TCRS", "RPCS3",
        "RPCS3_FIGHTER", "RPCS3",
        "RPCS3_SHOOTER", "RPCS3",
        "RPCS3_TCRS", "RPCS3"
    )

    static _ebootPathRules := [
        { MatchRegex: "(app|ux0|mai)", Action: { Launcher: "VITA3K" } }
    ]

    static _ebootPrompts := Map(
        "PLATFORM", {
            Title: "Select Platform",
            Prompt: "Which console is this game for?",
            Options: [
                { Label: "PS3  (RPCS3)", NextPrompt: "RPCS3_BUILD" },
                { Label: "PS4  (shadPS4)", Action: { Launcher: "SHADPS4" } }
            ]
        },
        "RPCS3_BUILD", {
            Title: "Select RPCS3 Build",
            Prompt: "Which specialized build is this for?",
            Options: [
                { Label: "Standard RPCS3", Action: { Launcher: "RPCS3" } },
                { Label: "Fighter Build", Action: { Launcher: "FIGHTER", IniSection: "RPCS3_FIGHTER_PATH", IniKey: "Rpcs3FighterPath", Flags: { PatchGroup: "T6BR", IsPatchable: true } } },
                { Label: "Shooter Build", Action: { Launcher: "SHOOTER", IniSection: "RPCS3_SHOOTER_PATH", IniKey: "Rpcs3ShooterPath", Flags: { IsPatchable: true } } },
                { Label: "TCRS Build", Action: { Launcher: "TCRS", IniSection: "RPCS3_TCRS_PATH", IniKey: "Rpcs3TcrsPath" } }
            ]
        }
    )

    static GetAll() {
        this.SyncCustomProfilesFromConfig()

        allDefs := []
        for _, def in this._defs
            allDefs.Push(def)
        for _, def in this._customDefs
            allDefs.Push(def)
        return allDefs
    }

    static FindByName(name) {
        normalized := StrUpper(name)
        for _, def in this.GetAll() {
            if (this.GetDefValue(def, "Name") = normalized)
                return def
        }
        return ""
    }

    static GetIniMeta(name) {
        def := this.FindByName(name)
        if !IsObject(def)
            return ""
        return { Section: def.Section, Key: def.Key }
    }

    static GetRomPrefix(name) {
        def := this.FindByName(name)
        if !IsObject(def)
            return ""
        return this.GetDefValue(def, "Prefix", "")
    }

    static GetIsoChoiceNames() {
        choices := []
        for _, def in this.GetAll() {
            if (this.GetDefValue(def, "SupportsIsoChoice", false))
                choices.Push(this.GetDefValue(def, "Name"))
        }
        return choices
    }

    static GetIsoExtRegex() {
        uniqueExts := Map()
        for _, name in this.GetIsoChoiceNames() {
            def := this.FindByName(name)
            if !IsObject(def) || !def.HasOwnProp("RomExts")
                continue

            for _, ext in def.RomExts {
                normalized := this.NormalizeExt(ext)
                if (normalized != "")
                    uniqueExts[normalized] := true
            }
        }

        regex := ""
        for ext, _ in uniqueExts {
            regex .= (regex = "" ? "" : "|") . ext
        }
        return regex
    }

    static BuildGameFileFilter() {
        uniqueExts := Map("exe", true, "bat", true, "lnk", true)

        for _, def in this.GetAll() {
            exts := this.GetDefValue(def, "RomExts", "")
            if !IsObject(exts)
                continue
            for _, ext in exts {
                normalized := this.NormalizeExt(ext)
                if (normalized != "")
                    uniqueExts[normalized] := true
            }
        }

        extFilter := ""
        for ext, _ in uniqueExts {
            extFilter .= (extFilter = "" ? "" : "; ") . "*." . ext
        }
        return "All Supported (" . extFilter . ")"
    }

    static ResolveLauncherKey(launcherType) {
        normalized := StrUpper(launcherType)
        if this._launcherAliases.Has(normalized)
            return this._launcherAliases[normalized]

        if InStr(normalized, "RPCS3")
            return "RPCS3"
        if InStr(normalized, "VITA3K")
            return "VITA3K"

        return normalized
    }

    static ResolveLauncherClassKey(launcherType) {
        resolved := this.ResolveLauncherKey(launcherType)
        def := this.FindByName(resolved)
        if (IsObject(def) && this.HasDefKey(def, "LauncherClass"))
            return this.GetDefValue(def, "LauncherClass")
        return resolved
    }

    static GetDefaultSettingsSchema() {
        return [
            { Key: "UiBackground", Label: "UI Background", Type: "text", Default: "101010" },
            { Key: "UiFontColor", Label: "UI Font Color", Type: "text", Default: "White" }
        ]
    }

    static GetSettingsSchema(name) {
        def := this.FindByName(name)
        if !IsObject(def)
            return this.GetDefaultSettingsSchema()

        schema := this.GetDefValue(def, "SettingsSchema", "")
        return IsObject(schema) ? schema : this.GetDefaultSettingsSchema()
    }

    static GetSettingsSection(name) {
        def := this.FindByName(name)
        if !IsObject(def)
            return StrUpper(name) . "_SETTINGS"

        explicit := this.GetDefValue(def, "SettingsSection", "")
        if (explicit != "")
            return explicit

        return this.GetDefValue(def, "Name", StrUpper(name)) . "_SETTINGS"
    }

    static GetUiTheme(name) {
        section := this.GetSettingsSection(name)
        if !IsSet(ConfigManager)
            return { BackColor: "101010", FontColor: "White" }

        bg := IniRead(ConfigManager.IniPath, section, "UiBackground", "101010")
        font := IniRead(ConfigManager.IniPath, section, "UiFontColor", "White")
        return { BackColor: bg, FontColor: font }
    }

    static GetEbootPathAction(fullPath) {
        for _, rule in this._ebootPathRules {
            if (fullPath ~= "i)" . this.GetDefValue(rule, "MatchRegex", ""))
                return this.GetDefValue(rule, "Action", "")
        }
        return ""
    }

    static GetEbootPrompt(promptId) {
        id := StrUpper(promptId)
        return this._ebootPrompts.Has(id) ? this._ebootPrompts[id] : ""
    }

    static SyncCustomProfilesFromConfig() {
        if !IsSet(ConfigManager)
            return

        profiles := ConfigManager.GetEmulatorProfiles()
        this.SetCustomProfiles(profiles)
    }

    static SetCustomProfiles(profileArray) {
        this._customDefs := []
        if !IsObject(profileArray)
            return

        for _, profileRaw in profileArray {
            normalized := this.NormalizeProfile(profileRaw)
            if IsObject(normalized)
                this._customDefs.Push(normalized)
        }
    }

    static NormalizeProfile(profileRaw) {
        name := StrUpper(Trim(this.GetDefValue(profileRaw, "Name", "")))
        name := RegExReplace(name, "[^A-Z0-9_]", "_")
        if (name = "")
            return ""

        section := this.GetDefValue(profileRaw, "Section", name . "_PATH")
        key := this.GetDefValue(profileRaw, "Key", name . "Path")
        launcherClass := this.GetDefValue(profileRaw, "LauncherClass", "STANDARD")
        prefix := this.GetDefValue(profileRaw, "Prefix", "")
        supportsIso := !!this.GetDefValue(profileRaw, "SupportsIsoChoice", false)
        settingsSection := this.GetDefValue(profileRaw, "SettingsSection", name . "_SETTINGS")
        schema := this.GetDefValue(profileRaw, "SettingsSchema", this.GetDefaultSettingsSchema())
        romExtsRaw := this.GetDefValue(profileRaw, "RomExts", [])

        normalizedExts := []
        if IsObject(romExtsRaw) {
            for _, ext in romExtsRaw {
                fixedExt := this.NormalizeExt(ext)
                if (fixedExt != "")
                    normalizedExts.Push(fixedExt)
            }
        }

        return {
            Name: name,
            Section: section,
            Key: key,
            LauncherClass: launcherClass,
            Prefix: prefix,
            SupportsIsoChoice: supportsIso,
            RomExts: normalizedExts,
            SettingsSection: settingsSection,
            SettingsSchema: schema
        }
    }

    static GetDefValue(def, key, fallback := "") {
        if !IsObject(def)
            return fallback
        if (Type(def) = "Map")
            return def.Has(key) ? def[key] : fallback
        return def.HasOwnProp(key) ? def.%key% : fallback
    }

    static HasDefKey(def, key) {
        if !IsObject(def)
            return false
        if (Type(def) = "Map")
            return def.Has(key)
        return def.HasOwnProp(key)
    }

    static NormalizeExt(ext) {
        val := StrLower(Trim(ext))
        if (val = "")
            return ""

        if InStr(val, ".") {
            parts := StrSplit(val, ".")
            val := parts[parts.Length]
        }

        return RegExReplace(val, "[^a-z0-9]")
    }
}
