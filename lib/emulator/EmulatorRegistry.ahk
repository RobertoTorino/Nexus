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
        { Name: "DOLPHIN", Section: "DOLPHIN_PATH", Key: "DolphinPath", RomExts: ["gcm", "iso", "rvz", "wbfs"], Prefix: "[GC/WII]", SupportsIsoChoice: true, LauncherClass: "DOLPHIN" },
        { Name: "DUCKSTATION", Section: "DUCKSTATION_PATH", Key: "DuckStationPath", RomExts: ["bin", "chd", "cue", "iso"], Prefix: "[PS1]", SupportsIsoChoice: true, LauncherClass: "DUCKSTATION" },
        { Name: "PCSX2", Section: "PCSX2_PATH", Key: "Pcsx2Path", RomExts: ["bin", "chd", "gz", "iso"], Prefix: "[PS2]", SupportsIsoChoice: true, LauncherClass: "PCSX2" },
        { Name: "PCSX2X6", Section: "PCSX2X6_PATH", Key: "Pcsx2x6Path", RomExts: ["acgame"], Prefix: "[ARCADE]", SupportsIsoChoice: false, LauncherClass: "PCSX2X6" },
        { Name: "PPSSPP", Section: "PPSSPP_PATH", Key: "PpssppPath", RomExts: ["cso", "elf", "iso", "pbp"], Prefix: "[PSP]", SupportsIsoChoice: true, LauncherClass: "PPSSPP" },
        { Name: "REDREAM", Section: "REDREAM_PATH", Key: "RedreamPath", RomExts: ["gdi", "cdi", "chd"], Prefix: "[DC]", SupportsIsoChoice: false, LauncherClass: "REDREAM" },
        { Name: "RPCS3", Section: "RPCS3_PATH", Key: "Rpcs3Path", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3" },
        { Name: "RPCS3_FIGHTER", Section: "RPCS3_FIGHTER_PATH", Key: "Rpcs3FighterPath", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3" },
        { Name: "RPCS3_SHOOTER", Section: "RPCS3_SHOOTER_PATH", Key: "Rpcs3ShooterPath", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3" },
        { Name: "RPCS3_TCRS", Section: "RPCS3_TCRS_PATH", Key: "Rpcs3TcrsPath", RomExts: ["EBOOT.BIN"], Prefix: "[PS3]", SupportsIsoChoice: false, LauncherClass: "RPCS3" },
        { Name: "SHADPS4", Section: "SHADPS4_PATH", Key: "ShadPs4Path", RomExts: ["bin"], Prefix: "[PS4]", SupportsIsoChoice: false, LauncherClass: "SHADPS4" },
        { Name: "SHADPS4_GUI", Section: "SHADPS4_GUI_PATH", Key: "ShadPs4GuiPath", Prefix: "[PS4]", SupportsIsoChoice: false, LauncherClass: "SHADPS4_GUI" },
        { Name: "TEKNO", Section: "TEKNO_PATH", Key: "TeknoPath", Prefix: "[ARCADE]", SupportsIsoChoice: false, LauncherClass: "TEKNO" },
        { Name: "VITA3K", Section: "VITA3K_PATH", Key: "Vita3kPath", Prefix: "[VITA]", SupportsIsoChoice: false, LauncherClass: "VITA3K" },
        { Name: "VIVANONNO", Section: "VIVANONNO_PATH", Key: "VivaNonnoPath", RomExts: ["zip"], Prefix: "[RR]", SupportsIsoChoice: false, LauncherClass: "VIVANONNO" },
        { Name: "YUZU", Section: "YUZU_PATH", Key: "YuzuPath", RomExts: ["nsp", "xci"], Prefix: "[SW]", SupportsIsoChoice: false, LauncherClass: "YUZU" }
    ]

    static _launcherAliases := Map(
        "FIGHTER", "RPCS3",
        "SHOOTER", "RPCS3",
        "TCRS", "RPCS3",
        "RPCS3_FIGHTER", "RPCS3",
        "RPCS3_SHOOTER", "RPCS3",
        "RPCS3_TCRS", "RPCS3"
    )

    static GetAll() {
        return this._defs
    }

    static FindByName(name) {
        normalized := StrUpper(name)
        for _, def in this._defs {
            if (def.Name = normalized)
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
        if !IsObject(def) || !def.HasOwnProp("Prefix")
            return ""
        return def.Prefix
    }

    static GetIsoChoiceNames() {
        choices := []
        for _, def in this._defs {
            if (def.HasOwnProp("SupportsIsoChoice") && def.SupportsIsoChoice)
                choices.Push(def.Name)
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

        for _, def in this._defs {
            if !def.HasOwnProp("RomExts")
                continue
            for _, ext in def.RomExts {
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
        if (IsObject(def) && def.HasOwnProp("LauncherClass"))
            return def.LauncherClass
        return resolved
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
