#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; * @description Project Entry Point - Unified JSON Architecture
; * @class Nexus
; * @location Nexus.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; lib\capture\
#Include lib\capture\AudioManager.ahk
#Include lib\capture\CaptureManager.ahk
; lib\config\
#Include lib\config\ConfigManager.ahk
#Include lib\config\GameRegistrarManager.ahk
#Include lib\config\TranslationManager.ahk
#Include lib\config\TeknoParrotManager.ahk
; lib\core\
#Include lib\core\JSON.ahk
#Include lib\core\Logger.ahk
#Include lib\core\Utilities.ahk
#Include lib\core\GlobalHotkeys.ahk
; lib\emulator\
#Include lib\emulator\EmulatorBase.ahk
#Include lib\emulator\LauncherFactory.ahk
; lib\emulator\tools\
#Include lib\emulator\tools\DuckStationAudioTool.ahk
#Include lib\emulator\tools\RomScanner.ahk
#Include lib\emulator\tools\Rpcs3AudioTool.ahk
; lib\emulator\types\
#Include lib\emulator\types\DolphinLauncher.ahk
#Include lib\emulator\types\DuckStationLauncher.ahk
#Include lib\emulator\types\Pcsx2Launcher.ahk
#Include lib\emulator\types\PpssppLauncher.ahk
#Include lib\emulator\types\Rpcs3UniversalLauncher.ahk
#Include lib\emulator\types\StandardLauncher.ahk
#Include lib\emulator\types\TeknoParrotLauncher.ahk
#Include lib\emulator\types\Vita3kLauncher.ahk
; lib\media\
#Include lib\media\SnapshotGallery.ahk
#Include lib\media\MusicPlayer.ahk
#Include lib\media\VideoPlayer.ahk
; lib\process\
#Include lib\process\ProcessManager.ahk
; lib\tools\
#Include lib\tools\AtracConverterTool.ahk
#Include lib\tools\FileValidatorTool.ahk
#Include lib\tools\GameDatabaseTool.ahk
#Include lib\tools\CloneWizardTool.ahk
#Include lib\tools\PatchServiceTool.ahk
#Include lib\tools\SystemInfoTool.ahk
; lib\ui\
#Include lib\ui\DialogsGui.ahk
#Include lib\ui\EmulatorConfigGui.ahk
#Include lib\ui\CloneGameWizardGui.ahk
#Include lib\ui\IconManagerGui.ahk
#Include lib\ui\GuiBuilder.ahk
#Include lib\ui\LoggerGui.ahk
#Include lib\ui\PatchManagerGui.ahk
#Include lib\ui\WindowManagerGui.ahk
#Include lib/ui/ConfigViewerGui.ahk
; lib\window\
#Include lib\window\MonitorHelper.ahk
#Include lib\window\WindowManager.ahk

; --- GLOBAL STATE ---
global CurrentLauncher := ""
global AppIsExiting := false
global SessionStartTick := 0
global BaseDir := A_ScriptDir
global ConfigFilePath := A_ScriptDir . "\nexus.ini"
global JsonFilePath := A_ScriptDir . "\nexus.json"

; --- BOOTSTRAP ---
ConfigManager.Init()
ProcessManager.InitMonitor()

Utilities.LogMonitorStats()

; --- HIGH DPI SETTINGS (Prevents Blurry Text) ---
try {
    ; Windows 8.1+ (Per-Monitor DPI Aware - The best setting)
    DllCall("shcore\SetProcessDpiAwareness", "Int", 2)
} catch {
    ; Windows Vista/7 Fallback (System DPI Aware)
    try DllCall("user32\SetProcessDPIAware")
}

; ---- CHECKS ----
if !FileExist(ConfigFilePath) {
    MsgBox("FATAL: nexus.ini not found at:`n" ConfigFilePath)
    return
}
if !FileExist(JsonFilePath) {
    MsgBox("FATAL: nexus.json not found at:`n" JsonFilePath)
    return
}
Logger.Info("Configuration File: " . ConfigFilePath)
Logger.Info("Games Database: " . JsonFilePath)

if !AudioManager.Init()
    Logger.Warn("Audio Manager: Voicemeeter not found.")
try {
    GuiBuilder.Create(StartGame)
} catch as err {
    Logger.Error("GUI Crash: " err.Message)
    MsgBox("Critical UI Error: " err.Message)
}

; Read the INI
try {
    sections := IniRead(ConfigFilePath)
} catch {
    MsgBox("FATAL: Could not read nexus.ini. Is it open in another program?")
    return
}

; Register Exit Handler (CRITICAL: Do not remove this!)
OnExit(MainExitHandler)
; Set a number for the frequency between 37 and 32767
SoundBeep(987, 150)

; ---- END OF AUTO-EXECUTE SECTION ----

; --- TRAY MENU ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Show Dashboard", (*) => GuiBuilder.MainGui.Show())
A_TrayMenu.Add("System Log", (*) => (WinExist("Nexus :: Logger") ? LoggerGui.Hide() : LoggerGui.Show()))
A_TrayMenu.Add("Clone Wizard", (*) => CloneGameWizardGui.Show())
A_TrayMenu.Add("Manage Audio", (*) => AudioManager.ShowGui())
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())


StartGame(*) {
    global CurrentLauncher, SessionStartTick
    launcher := ""

    ; Get Game Data
    rawGameData := ConfigManager.GetCurrentGame()

    if (!IsObject(rawGameData)) {
        DialogsGui.CustomTrayTip("No Game Selected", 2)
        return
    }

    ; Normalize Data (Map -> Object)
    gameObj := {}
    if (Type(rawGameData) == "Map") {
        for key, value in rawGameData
            gameObj.%key% := value
    } else {
        for key, value in rawGameData.OwnProps()
            gameObj.%key% := value
    }

    if !gameObj.HasOwnProp("Id") || (gameObj.Id == "")
        gameObj.Id := ConfigManager.CurrentGameId

    ; --- CRITICAL FIX: ROBUST PROCESS CLEANUP ---
    if IsObject(CurrentLauncher) {
        oldPid := (CurrentLauncher.HasProp("Pid")) ? CurrentLauncher.Pid : 0

        try CurrentLauncher.Stop()

        ; If we know the PID, wait for it to actually die (Max 2 seconds)
        if (oldPid > 0) {
            ProcessWaitClose(oldPid, 2)
        } else {
            Sleep(500) ; Fallback sleep for launchers without PIDs
        }

        ; Extra safety buffer for Windows to release file handles
        Sleep(200)
    }

    ; Pre-Sync Capture Name
    if gameObj.HasOwnProp("ExeName")
        CaptureManager.CurrentProcessName := gameObj.ExeName

    ; ROUTE TO CORRECT LAUNCHER
    try {
        launcherType := gameObj.HasOwnProp("LauncherType") ? gameObj.LauncherType : "STANDARD"

        ; Using the Factory is cleaner if you have it,
        ; but here is the direct switch block for safety in Nexus.ahk
        switch launcherType {
            case "RPCS3", "FIGHTER", "SHOOTER", "TCRS", "RPCS3_FIGHTER", "RPCS3_SHOOTER", "RPCS3_TCRS":
                CurrentLauncher := Rpcs3UniversalLauncher()
            case "VITA3K", "VITA3K_3830":
                CurrentLauncher := Vita3kLauncher()
            case "PCSX2":
                CurrentLauncher := Pcsx2Launcher()
            case "PPSSPP":
                CurrentLauncher := PpssppLauncher()
            case "DUCKSTATION":
                CurrentLauncher := DuckStationLauncher()
            case "DOLPHIN":
                CurrentLauncher := DolphinLauncher()
            case "TEKNO":
                CurrentLauncher := TeknoParrotLauncher()
            default:
                CurrentLauncher := StandardLauncher()
        }

        ; EXECUTE
        Logger.Info("Launching Type: " . launcherType)

        ; Explicitly reset WindowManager context before launch to prevent ghosting
        if IsSet(WindowManager)
            WindowManager.ActiveGamePid := 0

        if CurrentLauncher.Launch(gameObj) {
            CurrentLauncher.Id := gameObj.Id
            SessionStartTick := A_TickCount
            ConfigManager.UpdateLastPlayed(gameObj.Id)

            GuiBuilder.StatusText.Text := "Running..."
            GuiBuilder.MainGui.Minimize()
        } else {
            CurrentLauncher := ""
        }

    } catch as err {
        Logger.Error("Launch Error: " . err.Message)
        DialogsGui.CustomMsgBox("Launch Error", err.Message, 0x10)
    }
}

; ---- RESTART GAME ----
RestartGame() {
    global CurrentLauncher
    if IsObject(CurrentLauncher) {
        gameId := CurrentLauncher.Id ; Grab the ID before stopping
        CurrentLauncher.Stop()
        Sleep(1000)

        ; Force ConfigManager to re-select this ID to refresh metadata
        ConfigManager.CurrentGameId := gameId
        StartGame() ; This will now re-run the "Universal Adapter" and re-set the ExeName
    }
}

; ---- UNIFIED EXIT HANDLER ----
MainExitHandler(ExitReason, ExitCode) {
    global SessionStartTick, AppIsExiting, CurrentLauncher

    if (IsSet(AppIsExiting) && AppIsExiting)
        return 0

    AppIsExiting := true
    Logger.Info("App Exiting (Reason: " . ExitReason . ")")

    ; ---- ACCURATE TIME TRACKING ----
    try {
        ; Use the ID stored in the Launcher (the game actually running)
        ; Fallback to ConfigManager.CurrentGameId if launcher is gone
        activeId := (IsObject(CurrentLauncher) && CurrentLauncher.HasProp("Id"))
            ? CurrentLauncher.Id
            : ConfigManager.CurrentGameId

        if (activeId != "" && IsSet(SessionStartTick) && SessionStartTick > 0) {
            elapsed := Round((A_TickCount - SessionStartTick) / 1000)

            if (elapsed > 5) { ; Minimum 5 seconds to count
                ConfigManager.AddPlayTime(activeId, elapsed)
                Logger.Info("Saved " . elapsed . "s play time for ID: " . activeId)
            }
        }
    } catch as err {
        Logger.Error("Exit Handler (Time Tracking) failed: " . err.Message)
    }

    ; ---- SAFE SHUTDOWN (Audio & GDI+) ----
    try {
        AudioManager.Shutdown()

        ; Only shutdown GDI+ if CaptureManager was actually initialized
        if IsSet(CaptureManager) && CaptureManager.HasProp("pToken") && CaptureManager.pToken {
            DllCall("gdiplus\GdiplusShutdown", "Ptr", CaptureManager.pToken)
            CaptureManager.pToken := 0
        }
    } catch {
        ; Silent fail to ensure we reach the save step
    }

    ; ---- FINAL DATABASE SYNC ----
    try {
        ConfigManager.SaveGames()
    } catch as err {
        Logger.Error("Exit Handler (Save) failed: " . err.Message)
    }

    return 0
}