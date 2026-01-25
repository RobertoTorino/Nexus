#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Returns specific launcher instances based on type string.
; * @class LauncherFactory
; * @location lib/emulator/LauncherFactory.ahk
; * @author Philip
; * @date 2026/01/06
; * @version 1.0.01
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

class LauncherFactory {

    static GetLauncher(launcherType) {
        switch launcherType, 0 { ; Case insensitive

            ; --- Universal RPCS3 Builds ---
            ; Maps all variants to the single Universal Class
            case "RPCS3": return Rpcs3UniversalLauncher()
            case "FIGHTER": return Rpcs3UniversalLauncher()
            case "SHOOTER": return Rpcs3UniversalLauncher()
            case "TCRS": return Rpcs3UniversalLauncher()

            ; Added fully qualified names just in case
            case "RPCS3_FIGHTER": return Rpcs3UniversalLauncher()
            case "RPCS3_SHOOTER": return Rpcs3UniversalLauncher()
            case "RPCS3_TCRS": return Rpcs3UniversalLauncher()

            ; --- Vita3K Builds ---
            ; Both Standard and 3830 use the same class (handled internally)
            case "VITA3K": return Vita3kLauncher()
            case "VITA3K_3830": return Vita3kLauncher()

            ; --- Dedicated Class Launchers ---
            case "PPSSPP": return PpssppLauncher()
            case "PCSX2": return Pcsx2Launcher()
            case "DUCKSTATION": return DuckStationLauncher()
            case "TEKNO": return TeknoParrotLauncher()
            case "DOLPHIN": return DolphinLauncher()

            ; --- Standard Windows ---
            case "NORMAL": return StandardLauncher()
            case "STANDARD": return StandardLauncher()

            default: return StandardLauncher()
        }
    }
}