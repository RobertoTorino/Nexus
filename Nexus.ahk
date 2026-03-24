#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

; Disable hotkey rate limiting to prevent warning dialogs
A_MaxHotkeysPerInterval := 99999999
A_HotkeyInterval := 2000

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
; lib\input\
#Include lib\input\ControllerManager.ahk
#Include lib\input\ControllerTester.ahk
#Include lib\input\VoiceCommands.ahk
; lib\media\
#Include lib\media\SnapshotGallery.ahk
#Include lib\media\MusicPlayer.ahk
#Include lib\media\VideoPlayer.ahk
; lib\process\
#Include lib\process\ProcessManager.ahk
; lib\security\
#Include lib\security\AuthManager.ahk
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

Utilities.LogMonitorStats()

; [ADMIN FORCE START]
full_command_line := DllCall("GetCommandLine", "str")
if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)")) {
    try {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '" /restart'
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
    }
    ExitApp
}
; [ADMIN FORCE END]

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
Logger.Info("Configuration File: " . ConfigFilePath, "Nexus.ahk")
Logger.Info("Games Database: " . JsonFilePath, "Nexus.ahk")

authIndicatorState := "off"

; Optional beta auth bootstrap (non-blocking)
if (AuthManager.IsEnabled()) {
    authIndicatorState := "pending"
    try {
        AuthManager.Init()
        if !AuthManager.EnsureSession() {
            authIndicatorState := "fail"
            Logger.Warn("Beta auth is enabled but session could not be established.", "Nexus.ahk")
        } else {
            authIndicatorState := "ok"
        }
    } catch as err {
        authIndicatorState := "fail"
        Logger.Warn("Beta auth bootstrap failed: " err.Message, "Nexus.ahk")
    }
}

if !AudioManager.Init()
    Logger.Warn("Audio Manager: Voicemeeter not found.")
try {
    GuiBuilder.Create(StartGame)
    GuiBuilder.SetAuthIndicator(authIndicatorState)
} catch as err {
    Logger.Error("GUI Crash: " err.Message)
    MsgBox("Critical UI Error: " err.Message)
}

; Optional backend health check (deferred so startup remains responsive)
if (AuthManager.IsEnabled() && AuthManager.IsHealthCheckEnabled()) {
    GuiBuilder.SetAuthIndicator("pending")
    SetTimer(RunBetaHealthCheck, -250)
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
A_TrayMenu.Add("Clear Beta Auth", (*) => ClearBetaAuthTokens())
A_TrayMenu.Add("Reload", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => (SetTimer(ObjBindMethod(ControllerManager, "HandleControllerInput"), 0), ExitApp()))


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
        Logger.Info("Launching Type: " . launcherType, "Nexus.ahk")

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
    Logger.Info("App Exiting (Reason: " . ExitReason . ")", "Nexus.ahk")

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
                Logger.Info("Saved " . elapsed . "s play time for ID: " . activeId, "Nexus.ahk")
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

RunBetaHealthCheck() {
    ok := AuthManager.RunStartupHealthCheck()
    try GuiBuilder.SetAuthIndicator(ok ? "ok" : "fail")
}

ClearBetaAuthTokens() {
    if !AuthManager.IsEnabled() {
        DialogsGui.CustomTrayTip("Beta auth is currently disabled.", 1)
        return
    }

    if (DialogsGui.CustomMsgBox("Clear Beta Auth", "Revoke session and clear local beta auth tokens?", 0, 4) != "Yes")
        return

    ok := false
    try ok := AuthManager.RevokeSession()

    if ok {
        try GuiBuilder.SetAuthIndicator("off")
        DialogsGui.CustomTrayTip("Beta auth tokens cleared.", 1)
        Logger.Info("Beta auth tokens revoked and cleared via tray action.", "Nexus.ahk")
    } else {
        try GuiBuilder.SetAuthIndicator("fail")
        DialogsGui.CustomTrayTip("Failed to clear beta auth tokens.", 2)
        Logger.Warn("Failed to revoke/clear beta auth tokens via tray action.", "Nexus.ahk")
    }
}