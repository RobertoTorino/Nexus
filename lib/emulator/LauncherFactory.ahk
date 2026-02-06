#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Returns specific launcher instances based on type string.
; * @class LauncherFactory
; * @location lib/emulator/LauncherFactory.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; Example: When Nexus.ahk calls: launcher := LauncherFactory.GetLauncher(gameObj.LauncherType)
; If gameObj.LauncherType is "VITA3K_3830" and that case is missing from the switch block above, the Factory returns StandardLauncher.
; The Standard Launcher doesn't know how to handle Title IDs or special flags, it just runs the file path you gave it.
; By adding the case, you ensure the robust Vita3kLauncher class handles the request.

; --- DEPENDENCY IMPORTS ---
#Include EmulatorBase.ahk
#Include types/StandardLauncher.ahk
#Include types/Vita3kLauncher.ahk
#Include types/PpssppLauncher.ahk
#Include types/Pcsx2Launcher.ahk
#Include types/DuckStationLauncher.ahk
#Include types/TeknoParrotLauncher.ahk
#Include types/DolphinLauncher.ahk
#Include types/Rpcs3UniversalLauncher.ahk
#Include types/RedreamLauncher.ahk
#Include types/ShadPs4Launcher.ahk
#Include types/VivaNonnoLauncher.ahk
#Include types/YuzuLauncher.ahk

class LauncherFactory {
    ; We store the instances here so we don't have to re-create them
    static _instances := Map()

    static GetLauncher(launcherType) {
        ; Normalize the type to handle your RPCS3/VITA variants
        type := StrUpper(launcherType)

        ; Map variants to their core class keys
        if InStr(type, "RPCS3")
            targetKey := "RPCS3"
        else if InStr(type, "VITA3K")
            targetKey := "VITA3K"
        else
            targetKey := type

        ; If we already created this launcher before, just return it!
        if this._instances.Has(targetKey)
            return this._instances[targetKey]

        ; Otherwise, create it once and save it
        launcher := this.CreateInstance(targetKey)
        this._instances[targetKey] := launcher
        return launcher
    }

    static CreateInstance(key) {
        switch key, 0 {
            case "DOLPHIN": return DolphinLauncher()
            case "DUCKSTATION": return DuckStationLauncher()
            case "PCSX2": return Pcsx2Launcher()
            case "PPSSPP": return PpssppLauncher()
            case "REDREAM": return RedreamLauncher()
            case "RPCS3": return Rpcs3UniversalLauncher()
            case "SHADPS4": return ShadPs4Launcher()
            case "TEKNO": return TeknoParrotLauncher()
            case "VITA3K": return Vita3kLauncher()
            case "VIVANONNO": return VivaNonnoLauncher()
            case "YUZU": return YuzuLauncher()
            default: return StandardLauncher()
        }
    }
}