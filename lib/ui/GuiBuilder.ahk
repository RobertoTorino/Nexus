#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Main GUI. Modern "Superslick" UI.
; * @class GuiBuilder
; * @location lib/ui/GuiBuilder.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include EmulatorConfigGui.ahk
#Include CloneGameWizardGui.ahk
#Include WindowManagerGui.ahk
#Include ..\capture\AudioManager.ahk
#Include ..\capture\CaptureManager.ahk
#Include ..\config\GameRegistrarManager.ahk
#Include ..\config\TeknoParrotManager.ahk
#Include ..\emulator\LauncherFactory.ahk
#Include ..\emulator\types\StandardLauncher.ahk
#Include ..\input\ControllerManager.ahk
#Include ..\input\ControllerTester.ahk
#Include ..\input\VoiceCommands.ahk
#Include ..\input\VoiceCommandCatalog.ahk
#Include ..\media\SnapshotGallery.ahk
#Include ..\media\MusicPlayer.ahk
#Include ..\media\VideoPlayer.ahk
#Include ..\process\ProcessManager.ahk
#Include ..\tools\AtracConverterTool.ahk
#Include ..\tools\SystemInfoTool.ahk
#Include ..\tools\FileValidatorTool.ahk
#Include ..\tools\GameDatabaseTool.ahk
#Include ..\tools\PatchServiceTool.ahk
#Include ..\ui\ConfigViewerGui.ahk
#Include ..\ui\IconManagerGui.ahk
#Include ..\ui\PatchManagerGui.ahk
#Include ..\config\TranslationManager.ahk


class GuiBuilder {
    static MainGui := ""
    static UseIcons := true

    static LastPadPress := 0

    ; --- [HELPER] Translation Wrappers ---
    static T(text) => TranslationManager.T(text)

    static Label(icon, text) {
        return this.UseIcons ? " " icon " " : "  " this.T(text) "  "
    }

    ; --- [ACTION] Toggle Translation ---
    static ToggleLanguage() {
        TranslationManager.Cycle()
        this.ReloadUI()
    }

    ; --- [ACTION] Toggle UI Mode ---
    static ToggleUiMode() {
        if HasProp(this, "ToggleTimers")
            this.ToggleTimers(false)
        this.UseIcons := !this.UseIcons
        this.ReloadUI()
    }

    static ReloadUI() {
        ; Stop timers BEFORE destroying window to prevent crashes
        this.ToggleTimers(false)

        x := "", y := ""
        if (this.MainGui) {
            try this.MainGui.GetPos(&x, &y)
            this.MainGui.Destroy()
            this.MainGui := ""
        }

        this.Create(this.StartGameCallback)

        if (x != "" && y != "")
            this.MainGui.Show("x" x " y" y " AutoSize")
    }

    ; --- CONTROL GROUPS ---
    static AdvancedControls := []
    static BannerControl := ""
    static BtnHideAdvanced := ""
    static StartGameCallback := ""
    static LastAudioState := -1
    static LastVideoState := -1
    static TimerStatusObj := "", TimerRecObj := "", TimerTitleObj := ""
    static Voice := ""    ; holds VoiceCommands instance if initialized

    ; --- CONTROLS ---
    static GameSelector := ""
    static TimerAudio := "", TimerVideo := "", BurstInput := ""
    static StatsHeader := 0
    static TitleControl := ""
    static StatusText := ""

    static BtnStart := 0, BtnRestart := 0, BtnExit := 0
    static BtnRecAudio := 0, BtnRecVideo := 0
    static BtnBurstStart := 0
    static BtnCpu := []
    static BtnPatch := 0      ; New Patch Button
    static AllGamesList := [] ; For the Search feature

    static CachedGameCount := 0
    static CachedTotalTime := "0h"
    static AuthDot := ""
    static AuthDotState := "off"
    ; Microphone Voice Indicator
    static MicIcon := ""
    static VoiceModeBtn := ""

    ; --- [METHOD] Create ---
    static Create(startCallback := "") {
        loadStart := A_TickCount
        this.LastAudioState := -1
        this.LastVideoState := -1
        Logger.Debug("GUI creation started...")

        if (startCallback)
            this.StartGameCallback := startCallback

        guiW := 805

        ; Initialize voice command recognizer if available
        try {
            ; Instantiate VoiceCommands, supplying logger (HWND passed previously was wrong)
            this.Voice := VoiceCommands(Logger)
        } catch {
            ; VoiceCommands class might not be present or fail; ignore
            Logger.Warn("VoiceCommands: ", "No voice commands received.")
        }

        this.TimerStatusObj := ObjBindMethod(this, "UpdateStatusBar")
        this.TimerRecObj := ObjBindMethod(this, "UpdateRecordingTimers")
        this.TimerTitleObj := ObjBindMethod(this, "UpdateTitle")

        this.MainGui := Gui("-Caption +AlwaysOnTop +LastFound +Border", "Nexus")
        this.MainGui.MarginX := 0
        this.MainGui.MarginY := 0
        this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "")
        this.MainGui.OnEvent("Close", (*) => ExitApp())
        this.MainGui.SetFont("s11 cSilver", "Segoe UI")
        this.MainGui.BackColor := "2A2A2A"

        ; [HOTKEY] F9 Translation Toggle
        Hotkey "F9", (*) => this.ToggleLanguage(), "On"
        ; [HOTKEY] Ctrl+F10 Voice Catalog Debug Toggle
        Hotkey "^F10", (*) => this.ToggleVoiceCatalogDebug(), "On"

        ; --- TOOLBAR ---
        titleText := "Nexus :: " Chr(169) "" A_YYYY ""
        DragWin := (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd)
        ToggleMode := (*) => this.ToggleUiMode()

        this.TitleControl := this.MainGui.Add("Text", "x0 y0 w" (guiW - 345) " h30 +0x200 Background2A2A2A", titleText)
        this.TitleControl.OnEvent("Click", DragWin)
        this.TitleControl.OnEvent("DoubleClick", ToggleMode)

        this.AuthDot := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border cSilver", "●")
        this.AuthDot.OnEvent("Click", DragWin)
        this.SetAuthIndicator(this.AuthDotState)

        this.MainGui.Add("Text", "x+12 h30 +0x200 Center -Border", "   A:").OnEvent("Click", DragWin)
        this.TimerAudio := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " 00:00:00  ")
        this.TimerAudio.OnEvent("Click", DragWin)
        this.TimerAudio.OnEvent("DoubleClick", ToggleMode)

        this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " -  V:").OnEvent("Click", DragWin)
        this.TimerVideo := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " 00:00:00 ")
        this.TimerVideo.OnEvent("Click", DragWin)
        this.TimerVideo.OnEvent("DoubleClick", ToggleMode)
        this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " - ").OnEvent("Click", DragWin)

        ; --- TOOLBAR BUTTONS ---
        this.MainGui.SetFont("s12 cSilver", "Segoe UI")

        BtnAppReload := this.MainGui.Add("Text", "x+10 yp h30 +0x200 +Center Background2A2A2A cSilver", "↻")
        BtnAppReload.OnEvent("Click", (*) => Reload())

        ; Open help window
        this.AddNavBtn("  ?  ", (*) => this.ShowHelp(), "x+3 yp-3 h35 -Border")

        ; Open system info window
        this.AddNavBtn("  i  ", (*) => SystemInfoTool.Show(), "x+0 yp h35 -Border")

        this.MainGui.Add("Text", "x+0 yp-3 w30 h35 +0x200 Center Background2A2A2A", "_").OnEvent("Click", (*) => this.MainGui.Minimize())
        this.MainGui.Add("Text", "x+-4 yp+5 w30 h30 +0x200 Center cRed", "✕").OnEvent("Click", (*) => ExitApp())
        this.MainGui.Add("Text", "x0 y+2 w" guiW " h1 Background333333")

        ; --- ROW 1 ---
        ; [FIX] Define Dynamic Width: for Icons, Auto for Text
        btnW := this.UseIcons ? "w40" : ""

        this.MainGui.SetFont(this.UseIcons ? "s14" : "s12")

        this.AddNavBtn(this.Label("➕", "Set Launch Path"), (btn, *) => (this.FlashButton(btn), this.OnAddGame()), "x5 y40 c05FBE4 Background333333 " btnW)
        this.AddNavBtn(this.Label("🕹️", "Profiles"), (btn, *) => (this.FlashButton(btn), TeknoParrotManager.ShowPicker()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("🧹", "Delete Game"), (btn, *) => (this.FlashButton(btn), this.OnDeleteGame()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("⚙️", "Emulators"), (btn, *) => (this.FlashButton(btn), EmulatorConfigGui.Show()), "x+10 Background333333 " btnW)

        ; KISS: Just a standard button. No disabling. No font tricks.
        this.AddNavBtn(this.Label("🩹", "Patch Game"), (btn, *) => (this.FlashButton(btn), this.OnPatchGame()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("🗑️", "Clear Path"), (btn, *) => (this.FlashButton(btn), this.OnClearPath()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("🔧", "Restore Path"), (btn, *) => (this.FlashButton(btn), this.OnRefreshPath()), "x+10 Background333333 " btnW)

        NextX := this.UseIcons ? "x+10" : "x5"
        NextY := this.UseIcons ? "yp" : "y+10"
        this.AddNavBtn(this.Label("🔲", "Window Manager"), (btn, *) => (this.FlashButton(btn), WindowManagerGui.Show()), NextX " " NextY " Background333333 " btnW)
        this.AddNavBtn(this.Label("🎯", "Focus"), (btn, *) => (this.FlashButton(btn), this.OnFocusGame()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("🎵", "Music"), (btn, *) => (this.FlashButton(btn), MusicPlayer.Show()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("🎞️", "Video"), (btn, *) => (this.FlashButton(btn), VideoPlayer.Show()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("🌄", "Gallery"), (btn, *) => (this.FlashButton(btn), this.OnOpenGallery()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("📦", "Database"), (btn, *) => (this.FlashButton(btn), GameDatabaseTool.Show()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("📝", "Notes"), (btn, *) => (this.FlashButton(btn), this.OnNotes()), "x+10 Background333333 " btnW)
        this.AddNavBtn(this.Label("📁", "Browser"), (btn, *) => (this.FlashButton(btn), this.OnFileBrowser()), "x+10 Background333333 " btnW)

        ; --- ROW 2 ---
        this.MainGui.SetFont("s14", "Segoe UI")
        this.BtnStart := this.AddNavBtn("  ▶️  ", (*) => this.OnStartAction(), "x5 y+10 h35 Background333333 " btnW)

        startFn := (*) => this.OnStartAction()
        restartFn := (*) => this.OnRestartAction()
        exitFn := (*) => this.OnExitAction()
        helpFn := (*) => this.ShowHelp()
        browserFn := (*) => this.OnFileBrowser()
        databaseFn := (*) => GameDatabaseTool.Show()
        galleryFn := (*) => this.OnOpenGallery()
        snapshotFn := (*) => CaptureManager.TakeSnapshot(false)
        focusFn := (*) => this.OnFocusGame()
        musicFn := (*) => MusicPlayer.Show()
        videoFn := (*) => VideoPlayer.Show()
        ; voice will call startFn as well
        ; make sure we have a valid recogniser (the initial try/catch above
        ; may have created it already). the constructor requires the HWND.
        if !IsObject(this.Voice) {
            try {
                this.Voice := VoiceCommands(Logger)
            } catch {
                ; ignore if it failed or the class is absent
            }
        }

        voiceDebugEnabled := this.IsVoiceCatalogDebugEnabled()
        if IsObject(this.Voice)
            this.Voice.debugHeard := voiceDebugEnabled

        voiceCallbacks := Map(
            "start", startFn,
            "restart", restartFn,
            "exit", exitFn,
            "help", helpFn,
            "browser", browserFn,
            "database", databaseFn,
            "gallery", galleryFn,
            "snapshot", snapshotFn,
            "focus", focusFn,
            "music", musicFn,
            "video", videoFn
        )
        ; voice toggle (F8)
        Hotkey("*F8", (*) => this.ToggleVoiceListening())

        this.BtnRestart := this.AddNavBtn(" ♻️ ", (*) => this.OnRestartAction(), "x+10 h35 Background333333 " btnW)
        this.BtnExit := this.AddNavBtn(" ❌ ", (*) => this.OnExitAction(), "x+10 h35 Background333333 " btnW)

        this.MainGui.SetFont("s12", "Segoe UI")

        ; --- DROPDOWN SECTION ---
        ; 1. Container (Background)
        this.MainGui.Add("Text", "x+10 yp w480 h35 Background333333")

        ; 2. Edit Box
        this.GameSelector := this.MainGui.Add("Edit", "xp+3 yp+2 w447 h22 Background02A2A2A -E0x200 +ReadOnly -VScroll Center", "")

        ; 3. Arrow
        this.MainGui.SetFont("s14", "Segoe UI")
        arrow := this.MainGui.Add("Text", "x+2 yp-1 w40 h33 cSilver Background333333 +0x200 +Center", "▼")
        this.MainGui.SetFont("s12", "Segoe UI")

        ; 4. Overlay - compute bounds based on selector + arrow
        this.GameSelector.GetPos(&gx, &gy, &gw, &gh)
        arrow.GetPos(&ax, &ay, &aw, &ah)
        overlayX := gx
        overlayW := (ax + aw) - gx
        BtnOverlay := this.MainGui.Add("Text", "x" . overlayX . " yp-2 w" . overlayW . " h35 BackgroundTrans")

        ; --- CAMERA SECTION ---
        this.MainGui.SetFont("s14 Bold", "Segoe UI")
        ; create the snapshot button and keep a reference so the overlay callback
        ; can determine whether we clicked on the camera icon.
        snapX := overlayX + overlayW + 10
        snapOpts := "x" . snapX . " yp +0x200 +Center Background333333 h35 " . btnW
        this.BtnSnap := this.AddNavBtn(" 🔘 ", (btn, *) => (this.FlashButton(btn), CaptureManager.TakeSnapshot(false)), snapOpts)

        ; modify overlay handler so that clicks falling over the snap button are
        ; redirected to the snapshot logic instead of opening the game list.
        BtnOverlay.OnEvent("Click", ObjBindMethod(this, "OverlayClick"))

        ; Burst Input
        this.MainGui.Add("Text", "yp w42 h35 x+10 Border Background333333", "")
        this.BurstInput := this.MainGui.Add("Edit", "xp+1 yp+5 h29 w40 Number Center -E0x200 -Border Limit2 Background333333 cSilver", "5")
        this.BtnBurstStart := this.AddNavBtn("  ▶️ ", (*) => this.OnBurstSnap(), "x+10 yp-5 Background333333 h35 " btnW)

        ; --- ROW 3 ---
        ; 1. Audio/Video/Icon Manager
        ; Use global mode (Icons=s14, Text=s12)
        this.MainGui.SetFont(this.UseIcons ? "s14 Norm" : "s12 Norm", "Segoe UI")

        this.BtnRecAudio := this.AddNavBtn(this.Label("🔴", "Rec Audio"), (btn, *) => this.OnRecAudioClick(btn), "x5 y+10 Background333333 " btnW)
        this.BtnRecVideo := this.AddNavBtn(this.Label("🎬", "Rec Video"), (btn, *) => this.OnRecVideoClick(btn), "x+10 Background333333 " btnW)

        ;this.BtnSpeechSetup := this.AddNavBtn("S1", (*) => this.OpenSpeechWizard(), "x+10 Background333333 " btnW)
        ;this.BtnSpeechControlPanel := this.AddNavBtn("S2", (*) => this.OpenSpeechControlPanel(), "x+10 Background333333 " btnW)
        ;this.BtnMicPrivacySettings := this.AddNavBtn("S3", (*) => this.OpenMicPrivacySettings(), "x+10 Background333333 " btnW)

        ; Microphone Voice Indicator (F8 toggles color)
        this.MicIcon := this.MainGui.Add("Text", "x+10 h34 w40 cSilver +0x200 +Center +Border Background333333", "🎤")
        this.MicIcon.OnEvent("Click", (*) => this.ToggleVoiceListening())

        ; Voice mode indicator — click to toggle Whisper ↔ SAPI
        whisperOn := IsObject(this.Voice) && this.Voice.IsWhisperMode()
        this.VoiceModeBtn := this.MainGui.Add("Text", "x+2 h34 w28 +0x200 +Center +Border Background333333 " (whisperOn ? "cFF8800" : "cSilver"), whisperOn ? "W" : "S")
        this.VoiceModeBtn.OnEvent("Click", (*) => this.ToggleVoiceMode())

        this.AddNavBtn(this.Label("🖼️", "Icon Manager"), (*) => IconManagerGui.Show(), "x+10 yp Background333333 " btnW)

        ; --- CPU SECTION ---
        NextX := this.UseIcons ? "x+10" : "x5"
        NextY := this.UseIcons ? "yp" : "y+10"
        cBtn := " Background333333"
        this.BtnCpu := []

        ; 2. "CPU" Label -> Render as a button for perfect alignment, but pass empty callback ""
        this.MainGui.SetFont("s12", "Segoe UI")
        ; [FIX] changed "" to (*) => true
        ; This satisfies the requirement for a callback function without actually doing anything.
        this.AddNavBtn("  CPU  ", (*) => true, NextX " " NextY . cBtn)

        ; 3. Priority Buttons -> s14 if Icons, s12 if Text
        this.MainGui.SetFont(this.UseIcons ? "s14" : "s12", "Segoe UI")

        ; Attach first button to CPU label
        btnW := this.UseIcons ? "w40" : ""

        this.BtnCpu.Push(this.AddNavBtn(this.UseIcons ? " 💤 " : "  " this.T("Idle") "  ", (*) => this.OnCpuClick("Low", 1), "x+0 yp " btnW . cBtn))
        this.BtnCpu.Push(this.AddNavBtn(this.UseIcons ? " 🔻 " : "  " this.T("Normal") " --  ", (*) => this.OnCpuClick("BelowNormal", 2), "x+0 " btnW . cBtn))
        this.BtnCpu.Push(this.AddNavBtn(this.UseIcons ? " 🧊 " : "  " this.T("Normal") "  ", (*) => this.OnCpuClick("Normal", 3), "x+0 " btnW . cBtn))
        this.BtnCpu.Push(this.AddNavBtn(this.UseIcons ? " 🔺 " : "  " this.T("Normal") " ++  ", (*) => this.OnCpuClick("AboveNormal", 4), "x+0 " btnW . cBtn))
        this.BtnCpu.Push(this.AddNavBtn(this.UseIcons ? " ⚡ " : "  " this.T("High") "  ", (*) => this.OnCpuClick("High", 5), "x+0 " btnW . cBtn))
        this.BtnCpu.Push(this.AddNavBtn(this.UseIcons ? " ☢️ " : "  " this.T("Realtime") "  ", (*) => this.OnCpuClick("Realtime", 6), "x+0 " btnW . cBtn))

        this.BtnCpu[3].SetFont("c05FBE4")

        ; 4. "GPU" Label -> ALWAYS s12
        this.MainGui.SetFont("s12", "Segoe UI")
        this.AddNavBtn("  GPU  ", (*) => true, "x+10 yp Background333333")

        ; --- START ADVANCED SECTION ---
        ; [TRICK] The "State Swap"
        ; We save the current Icon Mode state and FORCE it to 'false' (Text Mode).
        ; This ensures AddNavBtn calculates the correct 'Small' height/padding
        ; instead of using the 'Large' Icon dimensions.
        savedState := this.UseIcons
        this.UseIcons := false

        ; Force Font to s12 explicitly
        this.MainGui.SetFont("s12 cSilver", "Segoe UI")

        this.AdvancedControls := []

        ; Add explicit height (h30) to cAdv ensures boxes are never too tall
        cAdv := " h30 Background333333"

        ; Marker for positioning
        marker := this.MainGui.Add("Text", "x5 y+10 w0 h0", "")
        marker.GetPos(&advX, &advY)

        ; --- ROW 1 ---
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Clone Wizard") "  ", (*) => CloneGameWizardGui.Show(), "x5 y" advY . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Patch Manager") "  ", (*) => PatchManagerGui.Show(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("View Logs") "  ", (*) => this.OnViewLogs(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("View System Config") "  ", (*) => ConfigViewerGui.ShowGui("INI"), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Show Games Config") "  ", (*) => ConfigViewerGui.ShowGui(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("ATRAC Tool") "  ", (*) => AtracConverterTool.Show(), "x+10" . cAdv))

        ; --- ROW 2 ---
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("RPCS3 Audio Fix") "  ", (*) => AudioManager.ShowGui(), "x5 y+10" . cAdv))
        ; Example inside GuiBuilder Create method's Advanced section:
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Hash Calc / Validator") "  ", (*) => FileValidatorTool.Show(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Purge Logs") "  ", (*) => this.OnClearLogs(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Wipe Full List") "  ", (*) => this.OnClearAllGames(), "x+10" . cAdv))

        ; --- ROW 3 ---
        this.AdvancedControls.Push(this.AddNavBtn("  " this.T("Controller Test") "  ", (*) => ControllerTester.Show(), "x5 y+10" . cAdv))

        ; --- ROW 4 ---
        ; Hide Button (Blue Text)
        this.BtnHideAdvanced := this.AddNavBtn("  ▲ " this.T("Hide Advanced") "  ", (*) => this.ToggleAdvanced(false), "x5 y+10 c05FBE4" . cAdv)
        this.AdvancedControls.Push(this.BtnHideAdvanced)

        ; --- MASK / BANNER ---
        this.BtnHideAdvanced.GetPos(, &lastY, , &lastH)
        totalH := (lastY + lastH) - advY

        this.BannerControl := this.MainGui.Add("Text", "x5 y" advY " w" (guiW - 10) " h" totalH " Border Right Background333333", "▼ " this.T("Show Advanced Utilities") " ▼  ")
        this.BannerControl.OnEvent("Click", (*) => this.ToggleAdvanced(true))

        ; [RESTORE] Restore the original Icon Mode state so the rest of the app behaves normally
        this.UseIcons := savedState

        ; --- END ADVANCED SECTION ---

        ; --- FOOTER ---
        this.MainGui.SetFont("s10", "Segoe UI")

        this.MainGui.Add("Text", "x0 y+10 w" guiW " h1 Background333333")
        this.StatsHeader := this.MainGui.Add("Text", "x5 y+0 w" (guiW - 10) " h24 +0x200 vStatsHeader Background333333", "Loading Statistics...")
        this.MainGui.Add("Text", "x0 y+0 w" guiW " h1 Background333333")

        ; [STATUS BAR]
        this.StatusText := this.MainGui.Add("Text", "x5 y+2 w" (guiW - 55) " h22 +0x200 BackgroundTrans", "Ready")

        ; [LANGUAGE TEXT] - Plain Text, No Emojis, No weird fonts
        currentCode := TranslationManager.GetCurrentCode()
        BtnFlag := this.MainGui.Add("Text", "x+20 yp+1 w25 h22 +0x200 Center BackgroundTrans cSilver", currentCode)
        BtnFlag.OnEvent("Click", (*) => this.ToggleLanguage())

        this.MainGui.SetFont("s12", "Segoe UI")
        this.MainGui.Add("Text", "x0 y+5 w0 h0", "")

        ; --- DISPLAY ---
        this.ToggleAdvanced(false)
        this.MainGui.Show("AutoSize w" guiW)
        this.MainGui.Opt("+AlwaysOnTop")

        ; Defer voice setup/diagnostics until after render to minimize startup time.
        if IsObject(this.Voice)
            SetTimer(() => this.InitializeVoiceSystem(voiceCallbacks, voiceDebugEnabled), -50)

        if (HasProp(this, "ToggleTimers"))
            this.ToggleTimers(true)
        if (HasProp(this, "SelectLastPlayed"))
            this.SelectLastPlayed()
        if (HasProp(this, "RefreshTopPlayed"))
            this.RefreshTopPlayed()
        if (HasProp(this, "UpdateTitle"))
            this.UpdateTitle()

        ; Route controller input to the shared ControllerManager so we don't bind
        ; to a non-existent GuiBuilder method (previous timer caused runtime error).
        ControllerManager.Init(this.MainGui.Hwnd)

        loadTime := A_TickCount - loadStart
        Logger.Info("Main GUI loaded in " . loadTime . " ms", "GuiBuilder")
        DialogsGui.CustomStatusPop("GUI Load Time: " . loadTime . "ms")
    }


    ; --- HANDLERS ---
    static OverlayClick(*) {
        ; determine mouse position relative to the main GUI
        MouseGetPos(&mx, &my)
        this.MainGui.GetPos(&gx, &gy)
        lx := mx - gx
        ly := my - gy

        ; fetch the current snap button bounds
        sx := 0, sy := 0, sw := 0, sh := 0
        if IsObject(this.BtnSnap)
            this.BtnSnap.GetPos(&sx, &sy, &sw, &sh)

        if (lx >= sx && lx <= sx + sw && ly >= sy && ly <= sy + sh) {
            ; clicked on the snapshot icon
            if IsObject(this.BtnSnap)
                this.FlashButton(this.BtnSnap)
            CaptureManager.TakeSnapshot(false)
        } else {
            this.OpenGameList(ConfigManager.GetSortedList())
        }
    }

    static OnClearPath(btnCtrl := "") {
        if (btnCtrl)
            this.FlashButton(btnCtrl)
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }
        if (DialogsGui.CustomMsgBox("Clear Path", "Remove the executable path for this game?", 300) != "Yes")
            return
        ConfigManager.UpdateGamePath(ConfigManager.CurrentGameId, "")
        this.RefreshDropdown()
        DialogsGui.CustomStatusPop("Path cleared")
    }

    static OnRefreshPath(btnCtrl := "") {
        if (btnCtrl)
            this.FlashButton(btnCtrl)
        id := ConfigManager.CurrentGameId
        if (id == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }
        if (!ConfigManager.Games.Has(id)) {
            DialogsGui.CustomStatusPop("Error: Game ID not found")
            ConfigManager.CurrentGameId := ""
            this.RefreshDropdown()
            return
        }
        gameObj := ConfigManager.Games[id]
        current := (Type(gameObj) == "Map") ? gameObj["ApplicationPath"] : gameObj.ApplicationPath
        newPath := FileSelect(3, current, "Select New Executable")

        if (newPath != "") {
            ConfigManager.UpdateGamePath(id, newPath)
            if (this.StatusText)
                this.StatusText.Text := "Updated path: " . newPath
            DialogsGui.CustomStatusPop("Path updated")
        }
    }

    static ToggleAdvanced(show) {
        if (show) {
            this.BannerControl.Visible := false
            for ctrl in this.AdvancedControls
                ctrl.Visible := true
        } else {
            for ctrl in this.AdvancedControls
                ctrl.Visible := false
            this.BannerControl.Visible := true
        }
        this.MainGui.Opt("+AlwaysOnTop")
    }

    ; --- [FIX] SAFE TIMER METHODS ---
    static UpdateTitle() {
        if !this.MainGui || !this.TitleControl
            return

        status := Utilities.IsInternetAvailable() ? "online" : "offline"
        timestamp := FormatTime(, "MM-dd hh:mm:ss tt")
        statsPart := " :: " . this.CachedGameCount . " Games (" . this.CachedTotalTime . ")"
        this.UpdateButtonState()

        try {
            if (this.TitleControl)
                this.TitleControl.Text := "  Nexus :: " Chr(169) "" A_YYYY " :: " status . statsPart . " :: " timestamp
        }
    }

    static UpdateRecordingTimers() {
        if !this.MainGui || !this.TimerAudio || !this.TimerVideo
            return

        try {
            if CaptureManager.IsRecordingAudio {
                duration := "00:00:00"
                try {
                    duration := CaptureManager.GetAudioDuration()
                } catch {
                    duration := "00:00:00"
                }
                this.TimerAudio.Text := "   " . duration . "  "
            }
            if CaptureManager.IsRecordingVideo {
                duration := "00:00:00"
                try {
                    duration := CaptureManager.GetVideoDuration()
                } catch {
                    duration := "00:00:00"
                }
                this.TimerVideo.Text := "  " . duration . "  "
            }
            if (!CaptureManager.IsRecordingAudio && !CaptureManager.IsRecordingVideo) {
                if (this.TimerRecObj)
                    SetTimer(this.TimerRecObj, 0)
                this.TimerAudio.Text := "   00:00:00  "
                this.TimerVideo.Text := "  00:00:00  "
            }
        }
    }

    static UpdateStatusBar() {
        if !this.MainGui || !this.StatusText
            return

        ; 1. GET DATA (Passive Mode)
        ; We just ask ProcessManager: "What is the current status?"
        ; It will return "SYSTEM: ... | GAME: ..." automatically.
        stats := ProcessManager.GetMonitorText()

        ; 2. UPDATE UI
        try {
            this.StatusText.Text := stats
        }
    }

    ; --- [HANDLERS] ---

    static SetRecordingStatus(isRecording, activeExe := "") {
        if !this.MainGui
            return
        statusText := isRecording ? "   ⏺ RECORDING ACTIVE" : "   Ready"
        if (this.HasProp("StatusText") && this.StatusText)
            this.StatusText.Text := statusText
    }

    static SetAuthIndicator(state := "off") {
        this.AuthDotState := state

        color := "Silver"
        switch state {
            case "ok":
                color := "05FBE4"
            case "fail":
                color := "Red"
            case "pending":
                color := "FF8800"
            default:
                color := "Silver"
        }

        if (this.HasProp("AuthDot") && IsObject(this.AuthDot)) {
            this.AuthDot.SetFont("c" color)
            this.AuthDot.Redraw()
        }
    }

    static ToggleVoiceListening() {
        if !IsObject(this.Voice)
            return

        if this.Voice.IsWhisperMode() {
            if this.Voice.IsWhisperActive()
                return  ; already recording, ignore repeated press
            if (this.HasProp("MicIcon") && IsObject(this.MicIcon)) {
                this.MicIcon.SetFont("cFF8800")  ; orange = recording
                this.MicIcon.Redraw()
            }
            this.SetVoiceStatus("Listening...")
            this.Voice.onWhisperDone := ObjBindMethod(this, "_OnWhisperCmdDone")
            this.Voice.TriggerWhisperCmd()
            return
        }

        newState := !this.Voice.listening
        this.Voice.Enable(newState)
        if (this.HasProp("MicIcon") && IsObject(this.MicIcon)) {
            this.MicIcon.SetFont(newState ? "c05FBE4" : "cSilver")
            this.MicIcon.Redraw()
        }
        stateText := newState ? "ON" : "OFF"
        Logger.Info("VoiceCommands: listening " stateText, "VoiceCommands")
        try DialogsGui.CustomTrayTip("Voice listening: " stateText)
    }

    static _OnWhisperCmdDone(resultText := "") {
        if (this.HasProp("MicIcon") && IsObject(this.MicIcon)) {
            this.MicIcon.SetFont("cSilver")
            this.MicIcon.Redraw()
        }
        hint := (resultText != "") ? "Heard: " SubStr(resultText, 1, 50) : "Ready"
        this.SetVoiceStatus(hint)
    }

    static ToggleVoiceMode() {
        if !IsObject(this.Voice)
            return

        nowWhisper := this.Voice.IsWhisperMode()
        this.Voice.SetWhisperMode(!nowWhisper)
        newWhisper := !nowWhisper

        if (this.HasProp("VoiceModeBtn") && IsObject(this.VoiceModeBtn)) {
            this.VoiceModeBtn.SetFont(newWhisper ? "cFF8800" : "cSilver")
            this.VoiceModeBtn.Value := newWhisper ? "W" : "S"
            this.VoiceModeBtn.Redraw()
        }
        ; In SAPI mode reset mic icon to off-state silver
        if (!newWhisper && this.HasProp("MicIcon") && IsObject(this.MicIcon)) {
            this.MicIcon.SetFont("cSilver")
            this.MicIcon.Redraw()
        }
        modeLabel := newWhisper ? "Whisper (tap F8 to speak)" : "SAPI (F8 to toggle)"
        this.SetVoiceStatus("Voice mode: " modeLabel)
        try DialogsGui.CustomTrayTip("Voice mode: " (newWhisper ? "Whisper" : "SAPI"))
    }

    static OnRecAudioClick(btnCtrl) {
        this.FlashButton(btnCtrl)

        starting := !CaptureManager.IsRecordingAudio
        if (starting && GetKeyState("Shift", "P")) {
            CaptureManager.SetSessionForceVoicemeeter(true)
            DialogsGui.CustomTrayTip("Recording will use Voicemeeter", 1)
        }

        useVM := starting ? CaptureManager.GetUseVoicemeeterForThisSession() : false
        if (starting && IsObject(this.Voice))
            this.Voice.UseVoicemeeter(useVM)

        CaptureManager.ToggleAudioRecording()

        ; Switch back to direct mic after stopping
        if (!CaptureManager.IsRecordingAudio && IsObject(this.Voice)) {
            this.Voice.UseVoicemeeter(false)
        }

        if (CaptureManager.IsRecordingAudio)
            SetTimer(this.TimerRecObj, 1000)
        else
            this.UpdateRecordingTimers()
    }

    static OnRecVideoClick(btnCtrl) {
        this.FlashButton(btnCtrl)

        starting := !CaptureManager.IsRecordingVideo
        if (starting && GetKeyState("Shift", "P")) {
            CaptureManager.SetSessionForceVoicemeeter(true)
            DialogsGui.CustomTrayTip("Recording will use Voicemeeter", 1)
        }

        useVM := starting ? CaptureManager.GetUseVoicemeeterForThisSession() : false
        if (starting && IsObject(this.Voice))
            this.Voice.UseVoicemeeter(useVM)

        CaptureManager.ToggleVideoRecording()

        ; Switch back to direct mic after stopping
        if (!CaptureManager.IsRecordingVideo && IsObject(this.Voice)) {
            this.Voice.UseVoicemeeter(false)
        }

        if (CaptureManager.IsRecordingVideo)
            SetTimer(this.TimerRecObj, 1000)
        else
            this.UpdateRecordingTimers()
    }

    static UpdateButtonState() {
        if !this.HasProp("MainGui") || !this.MainGui
            return
        game := ConfigManager.GetCurrentGame()
        isActive := IsObject(game)
        controls := ["BtnSnap", "BtnIdle", "BtnNormalMin", "BtnNormal", "BtnNormalPlus", "BtnHigh", "BtnRealtime"]
        for ctrlName in controls {
            if (this.HasProp(ctrlName) && this.%ctrlName%) {
                ctrl := this.%ctrlName%
                if (ctrl.Enabled != isActive)
                    ctrl.Enabled := isActive
            }
        }
    }

    static OnClearLogs() {
        Logger.ClearLogFile()
        DialogsGui.CustomTrayTip("Logs purged successfully.")
    }

    static OnClearAllGames() {
        if (DialogsGui.CustomMsgBox("Wipe List", "Delete ALL games from database?", 0, 4) == "Yes") {
            ConfigManager.Games := Map()
            ConfigManager.SaveGames()
            this.GameSelector.Text := ""
            this.RefreshDropdown()
            DialogsGui.CustomTrayTip("Database Wiped.")
        }
    }

    static AddNavBtn(label, callback, options := "x+10 yp") {
        hBtn := this.UseIcons ? "h35" : "h30"
        btn := this.MainGui.Add("Text", hBtn " +0x200 +Center +Border " options, label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static RefreshTopPlayed() {
        this.CachedGameCount := ConfigManager.Games.Count
        this.CachedTotalTime := ConfigManager.GetTotalLibraryTime()

        topList := ConfigManager.GetTopGames(2)
        topLine := ""

        if (topList.Length == 0) {
            topLine .= "None"
        } else {
            for index, game in topList {
                ; Safe Name Access
                safeName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName

                ; Safe Time Access (Prefer Readable, Fallback to Calculation)
                timeStr := "0s"

                ; Try to get the pre-calculated string
                if (Type(game) == "Map")
                    timeStr := (game.Has("PlayTimeReadable") ? game["PlayTimeReadable"] : "")
                else
                    timeStr := (HasProp(game, "PlayTimeReadable") ? game.PlayTimeReadable : "")

                ; [SAFETY] If string is empty or stale, calculate it manually from raw seconds
                if (timeStr == "" || timeStr == "0s") {
                    rawSeconds := (Type(game) == "Map") ? (game.Has("PlayTime") ? game["PlayTime"] : 0) : (HasProp(game, "PlayTime") ? game.PlayTime : 0)
                    if (rawSeconds > 0) {
                        timeStr := (rawSeconds >= 3600)
                            ? Round(rawSeconds / 3600, 1) "h"
                            : Round(rawSeconds / 60, 0) "m"
                    }
                }

                topLine .= index . ". " . safeName . " (" . timeStr . ")  "
                if (index < topList.Length)
                    topLine .= "| "
            }
        }

        if (this.StatsHeader)
            this.StatsHeader.Text := topLine

        ; [ADDED] Also update title bar while we are here
        if (HasProp(this, "UpdateTitle"))
            this.UpdateTitle()
    }

    static SelectLastPlayed() {
        lastId := IniRead(ConfigManager.IniPath, "LAST_PLAYED", "GameID", "")
        if (lastId == "" || !ConfigManager.Games.Has(lastId)) {
            this.GameSelector.Value := ""
            return
        }
        game := ConfigManager.Games[lastId]
        nameToSelect := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
        try {
            if (this.GameSelector)
                this.GameSelector.Value := nameToSelect
            this.OnGameChanged(this.GameSelector, 0)
        } catch {
            if (this.GameSelector)
                this.GameSelector.Value := ""
        }
    }

    static GetGameList() {
        if (ConfigManager.Games.Count == 0)
            ConfigManager.Init()
        list := ["- List Games -"]
        for name in ConfigManager.GetGameList()
            list.Push(name)
        if (list.Length == 1)
            list.Push("ERROR: No games found in JSON")
        list.Push("Available Games...")
        return list
    }

    static OnSelectionChange(selectedName) {
        success := ConfigManager.SetCurrentGameByName(selectedName)
        if (success) {
            Logger.Info("UI: Selection changed to " . selectedName, "GuiBuilder")
            this.UpdateButtonState()
        } else {
            Logger.Warn("UI: Could not find ID for game: " . selectedName)
        }
    }

    static RefreshDropdown() {
        if !this.GameSelector
            return
        targetId := ConfigManager.CurrentGameId
        nameToDisplay := ""
        if (targetId != "" && ConfigManager.Games.Has(targetId)) {
            game := ConfigManager.Games[targetId]
            nameToDisplay := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
        }
        this.GameSelector.Value := nameToDisplay
    }

    static OnGameChanged(ctrl, *) {
        ; 1. Get the name from the text box
        selectedName := Trim(ctrl.Value) ; [FIX] Trim spaces to ensure match

        if (selectedName == "" || selectedName == "- List Games -" || selectedName == "No Games Found") {
            ConfigManager.CurrentGameId := ""
            this.UpdateButtonState()
            return
        }

        foundId := ""

        ; 2. DEBUG SEARCH LOOP
        ; We loop through every game to find one with a matching "SavedName"
        for id, game in ConfigManager.Games {

            ; Handle Map vs Object
            name := ""
            if (Type(game) == "Map")
                name := game.Has("SavedName") ? game["SavedName"] : ""
            else
                name := HasProp(game, "SavedName") ? game.SavedName : ""

            ; Compare
            if (name == selectedName) {
                foundId := id
                break
            }
        }

        ; 3. RESULT HANDLER
        if (foundId != "") {
            ; SUCCESS: ID found
            ConfigManager.CurrentGameId := foundId

            ; Save to INI immediately
            try IniWrite(foundId, ConfigManager.IniPath, "LAST_PLAYED", "GameID")

            this.RefreshTopPlayed()
            this.UpdateButtonState()
        } else {
            ; FAILURE: Name is there, but ID not found
            ; This MsgBox will tell us if the database is actually empty or mismatching
            MsgBox("Error: Could not find Game ID for name: '" selectedName "'`n`nGames in Database: " ConfigManager.Games.Count, "Selection Error", 0x10)
            ConfigManager.CurrentGameId := ""
        }
    }

    static OnAddGame() {
        this.ToggleTimers(false)
        this.MainGui.Opt("-AlwaysOnTop")
        try {
            if GameRegistrarManager.AddGame()
                this.RefreshDropdown()
        } finally {
            this.MainGui.Opt("+AlwaysOnTop")
            this.ToggleTimers(true)
        }
    }

    static OnStartAction() {
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }

        rawGameData := ConfigManager.GetCurrentGame()
        if (!rawGameData)
            return

        ; Universal Adapter (Map -> Object)
        game := {}
        if (Type(rawGameData) = "Map") {
            for key, value in rawGameData {
                try game.%key% := value
            }
        } else {
            game := rawGameData
        }

        this.ClearGameGroup()
        this.SetBtnHighlight(this.BtnStart, true)

        launcherType := HasProp(game, "LauncherType") ? game.LauncherType : "Standard"
        savedName := HasProp(game, "SavedName") ? game.SavedName : "Unknown Game"

        try {
            launcherInstance := LauncherFactory.GetLauncher(launcherType)
            Logger.Info("UI Launching: " . savedName, "GuiBuilder")

            if (launcherInstance.Launch(game)) {

                ; --- [CRITICAL RESTORATION] ---
                ; We must set this so UpdateStatusBar knows what to monitor!
                ; We try to get the PID or ExeName from the launcher.
                if (launcherInstance.HasProp("Pid") && launcherInstance.Pid > 0) {
                    ConfigManager.ActiveProcessName := launcherInstance.Pid
                } else {
                    ; Fallback to ExeName if PID isn't available
                    ConfigManager.ActiveProcessName := HasProp(launcherInstance, "ExeName") ? launcherInstance.ExeName : ""
                }

                ProcessManager.StartSession(savedName)
                ConfigManager.UpdateLastPlayed(ConfigManager.CurrentGameId)
                this.UpdateButtonState()

            } else {
                DialogsGui.CustomStatusPop("Launch Failed")
            }

        } catch as err {
            DialogsGui.CustomMsgBox("Launch Error", err.Message, 0x10)
            this.ClearGameGroup()
        }
    }

    static OnRestartAction() {
        this.ClearGameGroup()
        this.SetBtnHighlight(this.BtnRestart, true)
        this.OnKillGame(false)
        Sleep(500)
        this.OnStartAction()
    }

    static OnKillGame(resetUI := true) {
        targetExe := ConfigManager.ActiveProcessName

        if (targetExe != "") {
            if IsSet(Logger)
                Logger.Info("Terminating: " . targetExe, "GuiBuilder")
            if ProcessExist(targetExe) {
                ProcessClose(targetExe)
                DialogsGui.CustomStatusPop("Terminated: " . targetExe)
            }
            WindowManager.ForceKillAll()
        } else {
            WindowManager.ForceKillAll()
        }
        if (resetUI) {
            this.ClearGameGroup()
            ConfigManager.ActiveProcessName := ""
        }
    }

    static OnFocusGame() {
        if (hwnd := WindowManager.GetValidHwnd())
            WindowManager.ForceFocus(hwnd)
    }

    static OnDeleteGame() {
        ; Use exactly TWO parameters
        Logger.Info("Delete request initiated for ID: " . ConfigManager.CurrentGameId, "GuiBuilder")

        if (ConfigManager.CurrentGameId == "") {
            Logger.Warn("Delete aborted. No game selected.", "GuiBuilder")
            return
        }

        ; Confirm with Yes/No (Option 4)
        if (DialogsGui.CustomMsgBox("Delete Game", "Are you sure?", 0, 4) == "Yes") {
            Logger.Info("User confirmed delete for: " . ConfigManager.CurrentGameId, "GuiBuilder")

            if ConfigManager.DeleteGame(ConfigManager.CurrentGameId) {
                this.RefreshDropdown()
                DialogsGui.CustomStatusPop("Game Deleted")
            }
        }
    }


    static OnGameSelect(selectedName) {
        for id, game in ConfigManager.Games {
            if (game["SavedName"] == selectedName) {
                ConfigManager.CurrentGameId := id
                break
            }
        }
        this.UpdateButtonState()
    }

    static OnPatchGame() {
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomTrayTip("No Game Selected", 2)
            return
        }

        game := ConfigManager.GetCurrentGame()
        if !IsObject(game)
            return

        ; Let the tool handle the logic.
        ; It already has its own error message if no patch is found.
        PatchServiceTool.OpenPatcher(game)
    }

    static OnOpenGallery() => SnapshotGallery.Show("")
    static OnViewLogs() => Run(Logger.GetLogFilePath())

    static OnBurstSnap() {
        count := Integer(this.BurstInput.Value)
        if (count < 1)
            return
        this.SetBtnHighlight(this.BtnBurstStart, true, "c05FBE4")
        Sleep(50)
        try {
            CaptureManager.TakeSnapshot(true, count)
        } finally {
            this.SetBtnHighlight(this.BtnBurstStart, false)
            DialogsGui.CustomStatusPop("Burst Sequence Complete")
        }
    }

    static OnFileBrowser() {
        game := ConfigManager.GetCurrentGame()
        if (game && Type(game) == "Map" && game.Has("ApplicationPath") && FileExist(game["ApplicationPath"])) {
            SplitPath(game["ApplicationPath"], , &dir)
            Run(dir)
        } else Run("explorer.exe")
    }

    static GetSelectedId() {
        if !this.GameList
            return ""
        row := this.GameList.GetNext(0, "Focused")
        if (row == 0)
            row := this.GameList.GetNext(0, "Selected")
        return (row > 0) ? this.GameList.GetText(row, 1) : ""
    }

    static OnNotes() {
        id := ConfigManager.CurrentGameId
        if (id == "") {
            DialogsGui.CustomStatusPop("Select a game first")
            return
        }
        if !ConfigManager.Games.Has(id)
            return
        game := ConfigManager.Games[id]
        cleanName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName

        notesGui := Gui("-Caption +Border +Owner" . this.MainGui.Hwnd, "Notes: " . cleanName)

        notesGui.BackColor := "1a1a1a"

        notesGui.SetFont("s10 Bold cGray")

        hdr := notesGui.Add("Text", "x15 y10 w470 h25 +0x200", "NOTES: " . StrUpper(cleanName))
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, notesGui.Hwnd))

        notesGui.SetFont("s14 Norm cWhite", "Segoe UI")

        existingNotes := (Type(game) == "Map") ? (game.Has("Notes") ? game["Notes"] : "") : (game.HasProp("Notes") ? game.Notes : "")
        editCtrl := notesGui.Add("Edit", "x15 y+10 w500 h300 Background333333 cWhite -E0x200 -VScroll -HScroll", existingNotes)

        notesGui.SetFont("s9 cSilver")

        btnStamp := notesGui.Add("Text", "x15 y+15 w70 h30 +0x200 Center Background333333", "Stamp")
        btnStamp.OnEvent("Click", (*) => EditPaste(FormatTime(, "MM-dd hh:mm tt") . ": ", editCtrl))
        btnSave := notesGui.Add("Text", "x+10 yp w110 h30 +0x200 Center Background333333", "Save & Close")
        btnSave.OnEvent("Click", (*) => (
            ConfigManager.UpdateGameNotes(id, editCtrl.Value),
            DialogsGui.CustomStatusPop("Notes Saved"),
            notesGui.Destroy()
        ))
        btnCancel := notesGui.Add("Text", "x+10 yp w70 h30 +0x200 Center Background333333", "Cancel")
        btnCancel.OnEvent("Click", (*) => notesGui.Destroy())
        notesGui.OnEvent("Escape", (*) => notesGui.Destroy())
        notesGui.Show()
    }

    static SaveGameNotes(gameId, text) {
        if ConfigManager.UpdateGameNotes(gameId, text)
            DialogsGui.CustomStatusPop("Notes Saved")
    }

    static ToggleTimers(state) {
        period := state ? 1000 : 0
        SetTimer(this.TimerStatusObj, period)
        SetTimer(this.TimerRecObj, period)
        SetTimer(this.TimerTitleObj, state ? 10000 : 0)
    }

    static ClearGameGroup() {
        if (this.HasProp("BtnStart") && this.BtnStart)
            this.SetBtnHighlight(this.BtnStart, false)
        if (this.HasProp("BtnRestart") && this.BtnRestart)
            this.SetBtnHighlight(this.BtnRestart, false)
    }

    static OnExitAction() {
        this.SetBtnHighlight(this.BtnExit, true)
        this.ClearGameGroup()
        this.OnKillGame()
        this.RefreshTopPlayed()
        SetTimer(() => this.SetBtnHighlight(this.BtnExit, false), -300)
        DialogsGui.CustomStatusPop("🛑 Session Ended - Stats Updated")
    }

    static OnCpuClick(priorityName, index) {
        for btn in this.BtnCpu {
            this.SetBtnHighlight(btn, false)
        }
        this.SetBtnHighlight(this.BtnCpu[index], true)
        try {
            procName := ConfigManager.ActiveProcessName
            if (procName != "" && ProcessExist(procName)) {
                ProcessSetPriority(priorityName, procName)
                DialogsGui.CustomStatusPop("CPU: " . priorityName)
            } else {
                DialogsGui.CustomStatusPop("No active game process")
            }
        } catch {
            DialogsGui.CustomStatusPop("Failed to set CPU priority")
        }
    }

    static OnToggleAudio() {
        static isRecording := false
        isRecording := !isRecording

        ; [FIX] Removed "FF0000". Now it uses the standard theme highlight.
        this.SetBtnHighlight(this.BtnRecAudio, isRecording)

        if (isRecording) {
            ; [FIX] Removed "Red". Popup will use standard text color.
            DialogsGui.CustomStatusPop("Audio Recording Started")
        } else {
            DialogsGui.CustomStatusPop("Audio Recording Saved")
        }
    }

    static OnToggleVideo() {
        static isRecording := false
        isRecording := !isRecording

        ; [FIX] Removed "FF0000".
        this.SetBtnHighlight(this.BtnRecVideo, isRecording)

        if (isRecording) {
            ; [FIX] Removed "Red".
            DialogsGui.CustomStatusPop("Video Recording Started")
        } else {
            DialogsGui.CustomStatusPop("Video Recording Saved")
        }
    }

    ; --- SEARCHABLE GAME LIST (Fixed Scroll Wheel) ---
    static OpenGameList(items := "") {
        if WinExist("NexusGameListPopup")
            return

        ; 1. Load Data
        if (items != "")
            this.AllGamesList := items
        else
            this.AllGamesList := ConfigManager.GetGameList()

        ; 2. Calculate Position
        this.GameSelector.GetPos(&gx, &gy, &gw, &gh)
        popupWidth := gw + 30
        listWidth := popupWidth + 25

        pt := Buffer(8)
        NumPut("int", gx, "int", gy + gh, pt)
        DllCall("ClientToScreen", "Ptr", this.MainGui.Hwnd, "Ptr", pt)
        screenX := NumGet(pt, 0, "int")
        screenY := NumGet(pt, 4, "int")

        PopupGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner" this.MainGui.Hwnd, "NexusGameListPopup")
        PopupGui.BackColor := "2A2A2A"
        PopupGui.SetFont("s11", "Segoe UI")
        PopupGui.MarginX := 2, PopupGui.MarginY := 2

        ; 3. Search Box
        SearchBox := PopupGui.Add("Edit", "w" popupWidth " h26 Background333333 cWhite Center", "")
        SearchBox.SetFont("s10 Italic")
        try DllCall("SendMessage", "Ptr", SearchBox.Hwnd, "UInt", 0x1501, "Ptr", 1, "WStr", "Type to search...", "Ptr")

        ; 4. List Box
        LB := PopupGui.Add("ListBox", "y+2 w" listWidth " r15 Background202020 cSilver -E0x200 -HScroll", this.AllGamesList)
        try DllCall("uxtheme\SetWindowTheme", "Ptr", LB.Hwnd, "Str", "DarkMode_Explorer", "Str", 0)

        ; 5. Events
        LB.OnEvent("Change", (*) => (
            this.GameSelector.Value := LB.Text,
            this.OnGameChanged(this.GameSelector),
            PopupGui.Destroy()
        ))

        SearchBox.OnEvent("Change", (*) => this.FilterGameList(LB, SearchBox.Value))
        PopupGui.OnEvent("Escape", (*) => PopupGui.Destroy())

        PopupGui.Show("x" screenX " y" screenY " w" (popupWidth + 4))

        SetTimer(CheckFocus, 200)

        CheckFocus() {
            try {
                if !WinExist("ahk_id " PopupGui.Hwnd) {
                    SetTimer(, 0)
                    return
                }
            } catch {
                SetTimer(, 0)
                return
            }
            if (!WinActive("ahk_id " PopupGui.Hwnd) && !WinActive("ahk_id " this.MainGui.Hwnd)) {
                SetTimer(, 0)
                PopupGui.Destroy()
            }
        }
    }


    static FilterGameList(ListBoxCtrl, query) {
        if (query == "") {
            ListBoxCtrl.Delete()
            ListBoxCtrl.Add(this.AllGamesList)
            return
        }

        filtered := []
        for name in this.AllGamesList {
            if InStr(name, query)
                filtered.Push(name)
        }
        ListBoxCtrl.Delete()
        if (filtered.Length > 0)
            ListBoxCtrl.Add(filtered)
    }

    static SelectGame(ListBoxCtrl, PopupGui) {
        selected := ListBoxCtrl.Text
        if (selected = "")
            return
        this.GameSelector.Value := selected
        PopupGui.Destroy()
        this.OnGameChanged(this.GameSelector)
    }

    static FlashButton(btnCtrl, color := "05FBE4") {
        btnCtrl.SetFont("c" . color)
        btnCtrl.Redraw()
        SetTimer(() => (btnCtrl.SetFont("cSilver"), btnCtrl.Redraw()), -200)
    }

    static SetBtnHighlight(btnObj, isHighlighted := true, activeColor := "05FBE4") {
        if !IsObject(btnObj)
            return
        if (isHighlighted) {
            btnObj.SetFont("c" . activeColor)
        } else {
            btnObj.SetFont("cSilver")
        }
        btnObj.Redraw()
    }

    static OpenSpeechWizard() {
        Send "#^s"  ; Win+Ctrl+S
    }

    static OpenSpeechControlPanel() {
        Run 'control.exe /name Microsoft.SpeechRecognition'
    }

    static OpenMicPrivacySettings() {
        Run "ms-settings:privacy-microphone"
    }

    static ShowHelp() {
        ; Use the Translation Manager to get the big block of text
        helpText := TranslationManager.T("HELP_TEXT_MAIN")

        ; Pass it to the Viewer (which now centers itself on the Owner)
        DialogsGui.ShowTextViewer("NEXUS :: Help", helpText, 675, 950)
    }

    static IsVoiceCatalogDebugEnabled() {
        enabled := IniRead(ConfigManager.IniPath, "SETTINGS", "DebugVoiceCatalog", "0")
        return (enabled = "1")
    }

    static ToggleVoiceCatalogDebug() {
        current := this.IsVoiceCatalogDebugEnabled()
        next := current ? "0" : "1"

        try IniWrite(next, ConfigManager.IniPath, "SETTINGS", "DebugVoiceCatalog")

        stateText := (next = "1") ? "ON" : "OFF"
        Logger.Info("VoiceCommands: DebugVoiceCatalog " stateText, "VoiceCommands")
        if (this.StatusText)
            this.StatusText.Text := "Voice catalog debug: " stateText
        try DialogsGui.CustomTrayTip("Voice catalog debug: " stateText)
    }

    static OnVoiceUnmatched(text, raw := "") {
        normalized := Trim(text)
        if (normalized = "")
            return

        firstToken := StrSplit(normalized, " ")[1]
        if (firstToken = "help" || firstToken = "halp" || firstToken = "aide"
            || firstToken = "aiuto" || firstToken = "ayuda"
            || normalized = "question" || normalized = "question mark") {
            try this.ShowHelp()
            Logger.Info("Voice Help fallback: " normalized, "VoiceCommands")
            return
        }

        if MusicPlayer.IsOpen() {
            if (normalized = "fullscreen" || normalized = "full screen") {
                MusicPlayer.ToggleFullScreen()
                Logger.Info("Voice Music fullscreen", "VoiceCommands")
                return
            }
        }
    }

    static ShouldExecuteVoiceCommand(key, text := "", raw := "") {
        query := Trim(text)

        if MusicPlayer.IsOpen() {
            if (query = "play") {
                MusicPlayer.TogglePlay()
                Logger.Info("Voice Music play", "VoiceCommands")
                return false
            }

            if (query = "stop") {
                MusicPlayer.Hide()
                Logger.Info("Voice Music stop/close", "VoiceCommands")
                return false
            }

            if (query = "fullscreen" || query = "full screen") {
                MusicPlayer.ToggleFullScreen()
                Logger.Info("Voice Music fullscreen", "VoiceCommands")
                return false
            }

            if (key = "start" || key = "exit")
                return false
        }

        return true
    }

    static GetVoiceDebugDeferredMs() {
        value := "1500"
        try value := IniRead(ConfigManager.IniPath, "SETTINGS", "VoiceDebugDeferredMs", "1500")

        ms := 1500
        try ms := Integer(value)
        catch
            ms := 1500

        if (ms < 0)
            ms := 0
        if (ms > 10000)
            ms := 10000

        return ms
    }

    static InitializeVoiceSystem(voiceCallbacks, voiceDebugEnabled := false) {
        if !IsObject(this.Voice)
            return

        setupStart := A_TickCount
        try {
            VoiceCommandCatalog.RegisterAll(this.Voice, voiceCallbacks)
            this.Voice.SetUnmatchedHandler((text, raw) => this.OnVoiceUnmatched(text, raw))
            this.Voice.SetCommandFilter((key, text, raw) => this.ShouldExecuteVoiceCommand(key, text, raw))
            this.Voice.Commit()
            this.Voice.Enable(false)

            if (voiceDebugEnabled) {
                deferMs := this.GetVoiceDebugDeferredMs()
                SetTimer(() => (
                    VoiceCommandCatalog.LogCatalog(Logger),
                    this.Voice.LogSapiAudioInputs()
                ), -deferMs)
            }

            Logger.Info("Voice setup loaded in " (A_TickCount - setupStart) " ms", "VoiceCommands")
        } catch as err {
            Logger.Warn("Voice setup deferred init failed: " err.Message, "VoiceCommands")
        }
    }

    static SetVoiceStatus(msg, maxLen := 64) {
        if !this.StatusText
            return

        text := Trim(msg)
        if (text = "")
            return

        if (StrLen(text) > maxLen)
            text := SubStr(text, 1, maxLen - 1) . "…"

        try this.StatusText.Text := text
    }
}