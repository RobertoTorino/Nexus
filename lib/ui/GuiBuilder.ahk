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

class GuiBuilder {
    static MainGui := ""

    ; --- STATE ---
    static UseIcons := true  ; Default: true (Icons), false (Text)

    ; --- HELPER: Returns Icon or Text based on mode ---
    static Label(icon, text) {
        ; Adds spaces for padding so buttons aren't too thin
        return this.UseIcons ? " " icon " " : "  " text "  "
    }

    ; --- TOGGLE ACTION ---
    static ToggleUiMode() {
        ; 1. STOP TIMERS CRITICAL FIX
        ; Prevents "Control is destroyed" error by stopping updates immediately
        if HasProp(this, "ToggleTimers")
            this.ToggleTimers(false)

        this.UseIcons := !this.UseIcons

        if (this.MainGui)
            this.MainGui.GetPos(&x, &y)

        this.MainGui.Destroy()
        this.MainGui := "" ; Clear reference

        ; Rebuild
        this.Create(this.StartGameCallback)

        if IsSet(x)
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

    ; --- CONTROLS ---
    static GameSelector := ""
    static TimerAudio := "", TimerVideo := "", BurstInput := ""
    static StatsHeader := 0
    static TitleControl := ""
    static StatusText := ""
    static BtnStart := 0, BtnRestart := 0, BtnExit := 0
    static BtnRecAudio := 0, BtnRecVideo := 0
    static BtnCpu := []

    ; Added := "" to startCallback to prevent potential reload crashes
    static Create(startCallback := "") {
        loadStart := A_TickCount

                ; RESET STATES
                this.LastAudioState := -1
                this.LastVideoState := -1

        Logger.Debug("GUI creation started...")

        ; Keep existing callback if we are just toggling the view
        if (startCallback)
            this.StartGameCallback := startCallback

        ; DYNAMIC WIDTH: 805 for Icons, 1150 for Text Mode
        guiW := 805

        this.TimerStatusObj := ObjBindMethod(this, "UpdateStatusBar")
        this.TimerRecObj := ObjBindMethod(this, "UpdateRecordingTimers")
        this.TimerTitleObj := ObjBindMethod(this, "UpdateTitle")

        this.MainGui := Gui("-Caption +AlwaysOnTop +LastFound +Border", "Nexus")

        this.MainGui.MarginX := 0
        this.MainGui.MarginY := 0

        this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "")
        this.MainGui.OnEvent("Close", (*) => ExitApp())
        this.MainGui.SetFont("s12 q5 cSilver", "Segoe UI")
        this.MainGui.BackColor := "2A2A2A"

        ; ======================================================================
        ; TOP TOOLBAR
        ; ======================================================================
        titleText := "Nexus :: " Chr(169) "" A_YYYY ""

        ; 1. Define Actions for consistency
        DragWin := (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd)
        ToggleMode := (*) => this.ToggleUiMode()

        ; 2. Title Control
        this.TitleControl := this.MainGui.Add("Text", "x0 y0 w" (guiW - 345) " h30 +0x200 Background2A2A2A", titleText)
        this.TitleControl.OnEvent("Click", DragWin)
        this.TitleControl.OnEvent("DoubleClick", ToggleMode)

        ; 3. Audio Stats (Now Draggable)
        this.MainGui.Add("Text", "x+20 h30 +0x200 Center -Border", "{ A:").OnEvent("Click", DragWin)

        this.TimerAudio := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " 00:00:00 ")
        this.TimerAudio.OnEvent("Click", DragWin)
        this.TimerAudio.OnEvent("DoubleClick", ToggleMode)

        ; 4. Video Stats (Now Draggable)
        this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " -  V:").OnEvent("Click", DragWin)

        this.TimerVideo := this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", " 00:00:00 ")
        this.TimerVideo.OnEvent("Click", DragWin)
        this.TimerVideo.OnEvent("DoubleClick", ToggleMode)

        ; 5. Final Separator
        this.MainGui.Add("Text", "x+0 h30 +0x200 Center -Border", "} ").OnEvent("Click", DragWin)

        ; [UPDATED] Double-Click Title to Toggle Mode
        this.TitleControl.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd)) ; Drag
        this.TitleControl.OnEvent("DoubleClick", (*) => this.ToggleUiMode())

        BtnAppReload := this.MainGui.Add("Text", "x+10 yp h30 +0x200 +Center Background2A2A2A cSilver", "↻")
        BtnAppReload.OnEvent("Click", (*) => Reload())
        this.AddNavBtn("  ?  ", (*) => this.ShowHelp(), "x+3 yp-3 h35 -Border")
        this.AddNavBtn("  i  ", (*) => SystemInfoTool.Show(), "x+0 yp h35 -Border")
        this.MainGui.Add("Text", "x+0 yp-3 w30 h35 +0x200 Center Background2A2A2A", "_").OnEvent("Click", (*) => this.MainGui.Minimize())
        this.MainGui.Add("Text", "x+-4 yp+5 w30 h30 +0x200 Center cRed", "✕").OnEvent("Click", (*) => ExitApp())

        ; 1. Separator Line
        this.MainGui.Add("Text", "x0 y+2 w" guiW " h1 Background333333")

        ; ======================================================================
        ; ROW 1 (Adaptive Font & Layout)
        ; ======================================================================
        ; [UPDATED] s16 for Icons (Big), s12 for Text (Compact)
        this.MainGui.SetFont(this.UseIcons ? "s16" : "s12")

        ; --- GROUP A (Top Line in Text Mode) ---
        this.AddNavBtn(this.Label("➕", "Set Launch Path"), (btn, *) => (this.FlashButton(btn), this.OnAddGame()), "x5 y40 Background006666")
        this.AddNavBtn(this.Label("🕹️", "Profiles"), (btn, *) => (this.FlashButton(btn), TeknoParrotManager.ShowPicker()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🧹", "Delete Game"), (btn, *) => (this.FlashButton(btn), this.OnDeleteGame()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🛠️", "Emulators"), (btn, *) => (this.FlashButton(btn), EmulatorConfigGui.Show()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🗑️", "Clear Path"), (btn, *) => (this.FlashButton(btn), this.OnClearPath()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🔧", "Restore Path"), (btn, *) => (this.FlashButton(btn), this.OnRefreshPath()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🔲", "Window Manager"), (btn, *) => (this.FlashButton(btn), WindowManagerGui.Show()), "x+10 Background333333")

        ; --- SPLIT LOGIC ---
        ; Icons: Continue Right (x+10) | Text: New Line Below (x5 y+10)
        NextX := this.UseIcons ? "x+10" : "x5"
        NextY := this.UseIcons ? "yp"   : "y+10"

        ; --- GROUP B (Bottom Line in Text Mode) ---
        this.AddNavBtn(this.Label("👁️", "Focus"), (btn, *) => (this.FlashButton(btn), this.OnFocusGame()), NextX " " NextY " Background333333")

        this.AddNavBtn(this.Label("🎵", "Music"), (btn, *) => (this.FlashButton(btn), MusicPlayer.Show()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🎬", "Video"), (btn, *) => (this.FlashButton(btn), VideoPlayer.Show()), "x+10 Background333333")
        this.AddNavBtn(this.Label("🖼️", "Gallery"), (btn, *) => (this.FlashButton(btn), this.OnOpenGallery()), "x+10 Background333333")

        this.AddNavBtn(this.Label("🗄️", "Database"), (btn, *) => (this.FlashButton(btn), GameDatabaseTool.Show()), "x+10 Background006666")
        this.AddNavBtn(this.Label("📝", "Notes"), (btn, *) => (this.FlashButton(btn), this.OnNotes()), "x+10 Background006666")
        this.AddNavBtn(this.Label("📁", "Browser"), (btn, *) => (this.FlashButton(btn), this.OnFileBrowser()), "x+10 Background006666")

        ; ======================================================================
        ; ROW 2
        ; ======================================================================
        this.MainGui.SetFont("s16", "Segoe UI") ; <--- FORCE SIZE 16 HERE
        this.BtnStart := this.AddNavBtn("  ▶️  ", (*) => this.OnStartAction(), "x5 y+10 h35")
        this.BtnRestart := this.AddNavBtn(" ♻️ ", (*) => this.OnRestartAction(), "x+10 h35")
        this.BtnExit := this.AddNavBtn(" ❌ ", (*) => this.OnExitAction(), "x+10 h35")

        this.MainGui.SetFont("s12", "Segoe UI")
        ; Fake dropdown list
        ; 1. GET DATA
        gamesList := ConfigManager.GetSortedList()

        this.MainGui.Add("Text", "x+10 yp w476 h35 Background333333")

        ; THE DISPLAY (Centered Text)
        ; Dropdown width
        this.GameSelector := this.MainGui.Add("Edit", "xp+3 yp+2 w441 h22 Background02A2A2A -E0x200 +ReadOnly -VScroll Center", "")

        ; THE ARROW
        this.MainGui.Add("Text", "x+4 yp w25 h22 cSilver Background333333 +0x200 +Center", "▼")

        ; THE CLICK MASK
        BtnOverlay := this.MainGui.Add("Text", "xp-521 yp-2 w550 h28 BackgroundTrans")
        BtnOverlay.OnEvent("Click", (*) => this.OpenGameList(ConfigManager.GetSortedList()))

        this.MainGui.SetFont("s16", "Segoe UI")

        this.AddNavBtn(" 📸 ", (*) => CaptureManager.TakeSnapshot(false), "x+10 Background333333 h35")
        this.BurstInput := this.MainGui.Add("Edit", "x+10 h35 w42 Number Center +0x200 Limit2 Background02A2A2A", " 5 ")
        this.BtnBurstStart := this.AddNavBtn("  ▶️  ", (*) => this.OnBurstSnap(), "x+10 Background333333 h35")

        ; ======================================================================
        ; ROW 3 (Adaptive Font & Layout)
        ; ======================================================================
        ; [UPDATED] Apply Dynamic Font here too (s16 vs s12)
      size := this.UseIcons ? "s16" : "s12"
              this.MainGui.SetFont(size, "Segoe UI")

        ; [UPDATED] Passing 'btn' to the handlers
        this.BtnRecAudio := this.AddNavBtn(this.Label("🎙️", "Rec Audio"), (btn, *) => this.OnRecAudioClick(btn), "x5 y+10 Background333333")
        this.BtnRecVideo := this.AddNavBtn(this.Label("🎬", "Rec Video"), (btn, *) => this.OnRecVideoClick(btn), "x+10 Background333333")

        this.AddNavBtn(this.Label("🖼️", "Icon Manager"), (*) => IconManagerGui.Show(), "x+10 Background333333")

        this.MainGui.SetFont("s12", "Segoe UI")

        ; --- SPLIT LOGIC ---
        ; Icons: Continue Right | Text: New Line Below
        NextX := this.UseIcons ? "x+10" : "x5"
        NextY := this.UseIcons ? "yp"   : "y+10"

        cBtn := " Background333333"
        this.BtnCpu := []

        ; First CPU button uses the Split Logic coordinates
        this.BtnCpu.Push(this.AddNavBtn("  Idle  ", (*) => this.OnCpuClick("Low", 1), NextX " " NextY . cBtn))

        this.BtnCpu.Push(this.AddNavBtn("  Normal --  ", (*) => this.OnCpuClick("BelowNormal", 2), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  Normal  ", (*) => this.OnCpuClick("Normal", 3), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  Normal ++  ", (*) => this.OnCpuClick("AboveNormal", 4), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  High  ", (*) => this.OnCpuClick("High", 5), "x+10" . cBtn))
        this.BtnCpu.Push(this.AddNavBtn("  Realtime  ", (*) => this.OnCpuClick("Realtime", 6), "x+10" . cBtn))


this.BtnCpu[3].SetFont("c05FBE4")

        this.AddNavBtn("  GPU  ", (*) => ProcessManager.OpenOverclock(), "x+10 yp Background333333")

        ; ======================================================================
        ; ADVANCED AREA (Rows 4, 5, 6) - OVERLAY STRATEGY
        ; ======================================================================
        this.AdvancedControls := []

        ; 1. Mark Start Position
        marker := this.MainGui.Add("Text", "x5 y+10 w0 h0", "")
        marker.GetPos(&advX, &advY)

        ; Define the color for this section
        cAdv := " Background333333"

        ; Row 4
        this.AdvancedControls.Push(this.AddNavBtn("  Clone Wizard  ", (*) => CloneGameWizardGui.Show(), "x5 y" advY . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  Patch Manager  ", (*) => PatchManagerGui.Show(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  Purge Logs  ", (*) => this.OnClearLogs(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  Purge List  ", (*) => this.OnClearAllGames(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  View Logs  ", (*) => this.OnViewLogs(), "x+10" . cAdv))

        ; Row 5
        this.AdvancedControls.Push(this.AddNavBtn("  View System Config  ", (*) => ConfigViewerGui.ShowGui("INI"), "x5 y+5" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  Show Games Config  ", (*) => ConfigViewerGui.ShowGui(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  RPCS3 Audio Fix  ", (*) => AudioManager.ShowGui(), "x+10" . cAdv))
        this.AdvancedControls.Push(this.AddNavBtn("  AT3 Converter  ", (*) => AtracConverterTool.Show(), "x+10 Background333333" . cAdv))

        ; Row 6
        this.AdvancedControls.Push(this.AddNavBtn("  Hash Calc / Validator  ", (*) => FileValidatorTool.Show(), "x5 y+5" . cAdv))

        ; The "Hide" button can match the theme (333333) or stay distinct.
        ; Here I applied the same background but kept your cyan text color.
        this.BtnHideAdvanced := this.AddNavBtn("  ▲ Hide Advanced  ", (*) => this.ToggleAdvanced(false), "x+10 c05FBE4" . cAdv)
        this.AdvancedControls.Push(this.BtnHideAdvanced)

        ; 2. Measure Total Height
        this.BtnHideAdvanced.GetPos(, &lastY, , &lastH)
        totalH := (lastY + lastH) - advY

        ; 3. Create BANNER (Height matches total advanced area)
        ; DYNAMIC BANNER WIDTH
        this.BannerControl := this.MainGui.Add("Text", "x5 y" advY " w" (guiW - 10) " h" totalH " Border Right Background333333", "▼ Show Advanced Utilities ▼  ")
        this.BannerControl.OnEvent("Click", (*) => this.ToggleAdvanced(true))

        ; ======================================================================
        ; FOOTER SECTION (SYMMETRICAL LAYOUT)
        ; ======================================================================
        ; 1. Separator Line
        this.MainGui.Add("Text", "x0 y+10 w" guiW " h1 Background333333")

        ; 2. Stats Header (Fake Status Bar) - Height 24
        this.StatsHeader := this.MainGui.Add("Text", "x5 y+0 w" (guiW - 10) " h24 +0x200 vStatsHeader Background333333", "Loading Statistics...")

        ; 3. Separator Line
        this.MainGui.Add("Text", "x0 y+0 w" guiW " h1 Background333333")

        ; 4. Real Status Bar - Height 22
        ; this.StatusText := this.MainGui.Add("Text", "x5 y+2 w" (guiW - 10) " h22 +0x200 c05FBE4 BackgroundTrans", "Ready")
        this.StatusText := this.MainGui.Add("Text", "x5 y+2 w" (guiW - 10) " h22 +0x200 BackgroundTrans", "Ready")

        ; 6. Bottom Margin
        this.MainGui.Add("Text", "x0 y+5 w0 h0", "")

        ; ======================================================================
        ; FINAL DISPLAY
        ; ======================================================================

        this.ToggleAdvanced(false)

        this.MainGui.Show("AutoSize w" guiW)
        this.MainGui.Opt("+AlwaysOnTop")

        if (HasProp(this, "ToggleTimers"))
            this.ToggleTimers(true)
        if (HasProp(this, "SelectLastPlayed"))
            this.SelectLastPlayed()
        if (HasProp(this, "RefreshTopPlayed"))
            this.RefreshTopPlayed()
        if (HasProp(this, "UpdateTitle"))
            this.UpdateTitle()

        loadTime := A_TickCount - loadStart
        Logger.Info("Main GUI loaded in " . loadTime . " ms")
        DialogsGui.CustomStatusPop("GUI Load Time: " . loadTime . "ms")
    }

    ; --- HANDLERS (UPDATED TO FLASH) ---

    static OnClearPath(btnCtrl := "") {
        if (btnCtrl)
            this.FlashButton(btnCtrl)

        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }

        ; [FIX] Added Confirmation Popup
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

        ; 1. Safety: Is an ID selected?
        if (id == "") {
            DialogsGui.CustomStatusPop("No game selected")
            return
        }

        ; 2. Safety: Does the game actually exist? (Prevents "Item has no value" error)
        if (!ConfigManager.Games.Has(id)) {
            DialogsGui.CustomStatusPop("Error: Game ID not found")
            ConfigManager.CurrentGameId := "" ; Auto-fix the stale ID
            this.RefreshDropdown()
            return
        }

        gameObj := ConfigManager.Games[id]

        ; 3. Hybrid Check (Map vs Object) to avoid "No method named Has" error
        current := ""
        if (Type(gameObj) == "Map") {
            if (gameObj.Has("ApplicationPath"))
                current := gameObj["ApplicationPath"]
        } else {
            if (gameObj.HasProp("ApplicationPath"))
                current := gameObj.ApplicationPath
        }

        ; 4. Select File
        newPath := FileSelect(3, current, "Select New Executable")

        ; 5. Update if valid
        if (newPath != "") {
            ConfigManager.UpdateGamePath(id, newPath)
            if (this.StatusText)
                this.StatusText.Text := "Updated path: " . newPath
            DialogsGui.CustomStatusPop("Path updated")
        }
    }

    ; --- TOGGLE LOGIC ---
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

    ; --- LOGIC METHODS ---

    ; TITLE BAR
    static UpdateTitle() {
        status := Utilities.IsInternetAvailable() ? "online" : "offline"
        timestamp := FormatTime(, "MM-dd hh:mm:ss tt")
        ; Add the Library Stats into the string
        statsPart := " :: " . this.CachedGameCount . " Games (" . this.CachedTotalTime . ")"
        this.UpdateButtonState()
        if this.TitleControl
            this.TitleControl.Text := "  Nexus :: " Chr(169) "" A_YYYY " :: " status . statsPart . " :: " timestamp
    }

    static SetRecordingStatus(isRecording, activeExe := "") {
        if !this.MainGui
            return

        ; 1. Update Main Status (Clean)
        statusText := isRecording ? "   ⏺ RECORDING ACTIVE" : "   Ready"

        if (this.HasProp("StatusText") && this.StatusText) {
            this.StatusText.Text := statusText
            ;this.StatusText.Opt(isRecording ? "cSilver" : "cSilver")
        }

        ; 2. Update Debug Row (Shows the EXE/Path for debugging)
        if (this.HasProp("DebugText") && this.DebugText) {
            if (activeExe != "")
                this.DebugText.Text := "Target: " . activeExe
            else
                this.DebugText.Text := "Debug: Ready"
        }
    }

static OnRecAudioClick(btnCtrl) {
        ; 1. Visual Feedback (Flash only)
        this.FlashButton(btnCtrl)

        ; 2. Toggle Backend
        CaptureManager.ToggleAudioRecording()

        ; 3. Start Timer loop immediately if recording started
        if (CaptureManager.IsRecordingAudio)
            SetTimer(this.TimerRecObj, 1000)
        else
            this.UpdateRecordingTimers() ; Run once to reset text to 00:00:00 immediately
    }

    static OnRecVideoClick(btnCtrl) {
        ; 1. Visual Feedback (Flash only)
        this.FlashButton(btnCtrl)

        ; 2. Toggle Backend
        CaptureManager.ToggleVideoRecording()

        ; 3. Start Timer loop
        if (CaptureManager.IsRecordingVideo)
            SetTimer(this.TimerRecObj, 1000)
        else
            this.UpdateRecordingTimers() ; Run once to reset text to 00:00:00 immediately
    }

static UpdateRecordingTimers() {
        ; STRICTLY update text labels only. Do not touch buttons.

        if CaptureManager.IsRecordingAudio
            this.TimerAudio.Text := "   " . CaptureManager.GetDuration("Audio") . "  "

        if CaptureManager.IsRecordingVideo
            this.TimerVideo.Text := "  " . CaptureManager.GetDuration("Video") . "  "

        ; If both stopped, kill timer and reset text
        if (!CaptureManager.IsRecordingAudio && !CaptureManager.IsRecordingVideo) {
            if (this.TimerRecObj)
                SetTimer(this.TimerRecObj, 0)

            this.TimerAudio.Text := "   00:00:00  "
            this.TimerVideo.Text := "  00:00:00  "
        }
    }

static UpdateButtonState() {
        if !this.HasProp("MainGui") || !this.MainGui
            return

        ; Check if game is running
        activeGame := ConfigManager.GetCurrentGame()
        isActive := IsObject(activeGame)

        ; [FIX] Removed "BtnExit", "BtnRecAudio", and "BtnRecVideo" from this list.
        ; We want them to stay ENABLED (High Quality) even if no game is running.
        ; Clicking them when no game is running is harmless.
        controls := [
            "BtnSnap",
            "BtnIdle", "BtnNormalMin", "BtnNormal", "BtnNormalPlus", "BtnHigh", "BtnRealtime"
        ]

        for ctrlName in controls {
            if (this.HasProp(ctrlName) && this.%ctrlName%) {
                ctrl := this.%ctrlName%
                ; Debounce: Only update if state actually changed to prevent flickering
                if (ctrl.Enabled != isActive)
                    ctrl.Enabled := isActive
            }
        }
    }

    ; Add confirmation message
    static OnClearLogs() {
        Logger.ClearLogFile()
        DialogsGui.CustomTrayTip("Logs purged successfully.")
    }

    ; Ensure OnClearAllGames refreshes the list properly
    static OnClearAllGames() {
        if (DialogsGui.CustomMsgBox("Wipe", "Delete ALL games?", 300) == "Yes") {
            ConfigManager.Games := Map()
            ConfigManager.SaveGames()
            this.RefreshDropdown()
            DialogsGui.CustomTrayTip("Database wiped.")
        }
    }

    static AddNavBtn(label, callback, options := "x+10 yp") {
        ; Dynamic Height: h35 for Icons (s16), h30 for Text (s12)
        hBtn := this.UseIcons ? "h35" : "h30"
        btn := this.MainGui.Add("Text", hBtn " +0x200 +Center +Border " options, label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static UpdateStatusBar() {
        global CurrentLauncher, SessionStartTick
        if !this.MainGui
            return

        ; --- 1. SESSION MANAGEMENT (Keep existing logic) ---
        ; If the game was running but is now gone
        if (IsObject(CurrentLauncher) && CurrentLauncher.HasProp("Pid") && CurrentLauncher.Pid > 0 && !ProcessExist(CurrentLauncher.Pid)) {
            if (SessionStartTick > 0) {
                ConfigManager.AddPlayTime(ConfigManager.CurrentGameId, Round((A_TickCount - SessionStartTick) / 1000))
                SessionStartTick := 0
            }
            this.RefreshTopPlayed()
            report := ProcessManager.EndSession()
            if (report != "")
                DialogsGui.CustomMsgBox("Session Ended", report)

            CurrentLauncher := ""
            ; Don't return here—fall through to update the text one last time
        }

        ; --- 2. DETERMINE TARGET ---
        target := ""
        if (IsSet(CurrentLauncher) && IsObject(CurrentLauncher)) {
            if (CurrentLauncher.HasProp("Pid") && CurrentLauncher.Pid > 0) {
                target := CurrentLauncher.Pid
            } else if (CurrentLauncher.HasProp("ExeName") && CurrentLauncher.ExeName != "") {
                target := CurrentLauncher.ExeName
            }
        }

        ; If no active launcher, maybe we have a selected game in the dropdown?
        ; (Optional: Pass the selected game name just to show "Game: Selected [inactive]")
        if (target == "") {
            game := ConfigManager.GetCurrentGame()
            if IsObject(game) {
                ; We pass the Exe Name so ProcessManager can say "Game: Tekken.exe [inactive]"
                target := (Type(game) == "Map")
                    ? (game.Has("GameApplication") ? game["GameApplication"] : "")
                    : (game.HasProp("GameApplication") ? game.GameApplication : "")
            }
        }

        ; --- 3. THE FIX: ALWAYS CALL MONITOR ---
        ; Even if target is "", ProcessManager will now return "System: ... | App: ... | Game: not set"
        stats := ProcessManager.GetMonitorText(target)
        this.StatusText.Text := stats
    }

    ; ROW 8 STATISTICS
    static RefreshTopPlayed() {
        ; Update the Cache (for the Title Bar to use)
        this.CachedGameCount := ConfigManager.Games.Count
        this.CachedTotalTime := ConfigManager.GetTotalLibraryTime()

        ; Get Top 3 Games for the GUI Body
        topList := ConfigManager.GetTopGames(2)
        topLine := ""

        if (topList.Length == 0) {
            topLine .= "None"
        } else {
            for index, game in topList {
                safeName := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
                timeStr := (Type(game) == "Map") ? (game.Has("PlayTimeReadable") ? game["PlayTimeReadable"] : "0s")
                    : (game.HasProp("PlayTimeReadable") ? game.PlayTimeReadable : "0s")

                topLine .= index . ". " . safeName . " (" . timeStr . ")  "
                if (index < topList.Length)
                    topLine .= "| "
            }
        }

        ; Update the control inside the GUI
        if (this.StatsHeader)
            this.StatsHeader.Text := topLine
    }

    static SelectLastPlayed() {
        lastId := IniRead(ConfigManager.IniPath, "LAST_PLAYED", "GameID", "")

        ; If no last played game, or the ID is invalid, stop.
        if (lastId == "" || !ConfigManager.Games.Has(lastId)) {
            this.GameSelector.Value := ""
            return
        }

        game := ConfigManager.Games[lastId]

        ; --- START: Universal Map/Object Support ---
        nameToSelect := ""

        ; Check if it's a Map (JSON style) or Object (Internal style)
        if (Type(game) == "Map") {
            nameToSelect := game.Has("SavedName") ? game["SavedName"] : lastId
        } else {
            nameToSelect := game.HasOwnProp("SavedName") ? game.SavedName : lastId
        }

        try {
            if (this.GameSelector) {
                ; [FIX] 'Edit' controls use .Value to set text. .Choose() does not exist.
                this.GameSelector.Value := nameToSelect
            }

            ; Update the UI details for the selected game
            this.OnGameChanged(this.GameSelector, 0)
        } catch {
            ; [FIX] Fallback for Edit Control (Set text, don't choose Index 1)
            if (this.GameSelector)
                this.GameSelector.Value := ""
        }
    }

    ; ---- JSON-BACKED DATA LOGIC ----
    static GetGameList() {
        if (ConfigManager.Games.Count == 0)
            ConfigManager.Init()

        list := ["- List Games -"]
        for name in ConfigManager.GetGameList() {
            list.Push(name)
        }

        if (list.Length == 1)
            list.Push("ERROR: No games found in JSON")

        list.Push("Available Games...")
        return list
    }

    static OnSelectionChange(selectedName) {
        ; Update the Global State in ConfigManager
        success := ConfigManager.SetCurrentGameByName(selectedName)

        if (success) {
            Logger.Info("UI: Selection changed to " . selectedName)
            ; Enable your buttons (Start, Record, etc.) because a game is now "Active" in the UI
            this.UpdateButtonState()
        } else {
            Logger.Warn("UI: Could not find ID for game: " . selectedName)
        }
    }

    static RefreshDropdown() {
        if !this.GameSelector
            return

        ; 1. Get the Current Game ID
        targetId := ConfigManager.CurrentGameId
        nameToDisplay := ""

        ; 2. Look up the Name
        if (targetId != "" && ConfigManager.Games.Has(targetId)) {
            game := ConfigManager.Games[targetId]
            ; Handle Map vs Object compatibility
            nameToDisplay := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
        }

        ; 3. Update the Text (Since it's an Edit control now, we use .Value)
        this.GameSelector.Value := nameToDisplay
    }


    ; ---- ACTION HANDLERS ----

    ; Handles Dropdown Selection Changes
    static OnGameChanged(ctrl, *) {
        selectedName := ctrl.Text

        ; 1. Handle Invalid Selection
        if (selectedName == "" || selectedName == "No Games Found" || selectedName == "- Select Game -") {
            if (this.HasProp("BtnPatch") && this.BtnPatch)
                this.BtnPatch.Enabled := false
            ConfigManager.CurrentGameId := ""
            this.UpdateButtonState()
            return
        }

        ; 2. Find Game ID
        foundId := ""
        for id, game in ConfigManager.Games {
            name := (Type(game) == "Map") ? game["SavedName"] : game.SavedName
            if (name == selectedName) {
                foundId := id
                break
            }
        }

        ; 3. Update State
        if (foundId != "") {
            ConfigManager.CurrentGameId := foundId
            IniWrite(foundId, ConfigManager.IniPath, "LAST_PLAYED", "GameID")

            ; --- NEW: DYNAMIC PATCH BUTTON STATUS ---
            game := ConfigManager.Games[foundId]

            ; Get the filename (Works for Map or Object)
            appFile := ""
            if (Type(game) == "Map") {
                if game.Has("GameApplication")
                    appFile := game["GameApplication"]
            } else {
                if game.HasProp("GameApplication")
                    appFile := game.GameApplication
            }

            ; Check the database directly. If the tool knows this file, enable the button.
            if (this.HasProp("BtnPatch") && this.BtnPatch) {
                this.BtnPatch.Enabled := PatchServiceTool.KnownPatches.Has(appFile)
            }
            if (this.MainGui) {
                try {
                    this.RefreshTopPlayed()
                    this.UpdateButtonState()
                }
            }
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

    static OnKillGame() {
        global CurrentLauncher

        ; 1. Try to use the Launcher's own cleanup (Best for normal games)
        if IsObject(CurrentLauncher) && HasProp(CurrentLauncher, "Stop") {
            CurrentLauncher.Stop()
        }

        ; 2. FALLBACK: Use WindowManager's "Smart Close"
        ; This handles the case where CurrentLauncher is lost/null,
        ; OR if it's a TeknoParrot game that needs a hard kill.
        WindowManager.CloseActiveGame()

        ; 3. Clear State
        CurrentLauncher := ""
        DialogsGui.CustomStatusPop("Game Terminated")
    }

    ; FBetter Restart Logic
    static OnRestartGame() {
        global CurrentLauncher

        if IsObject(CurrentLauncher) {
            CurrentLauncher.Stop()

            ; Wait for it to close, but timeout after 2 seconds to prevent infinite hang
            if (CurrentLauncher.HasProp("Pid") && CurrentLauncher.Pid > 0)
                ProcessWaitClose(CurrentLauncher.Pid, 2)
            else
                Sleep(500) ; Default sleep for non-PID launchers
        }

        ; Allow a brief moment for OS to release file locks
        Sleep(500)

        ; Start the game again
        this.StartGameCallback.Call()
    }

    static OnFocusGame() {
        if (hwnd := WindowManager.GetValidHwnd())
            WindowManager.ForceFocus(hwnd)
    }

    static OnDeleteGame() {
        if (ConfigManager.CurrentGameId == "")
            return

        if (DialogsGui.CustomMsgBox("Delete", "Delete selected game from database?", 300) == "Yes") {
            ConfigManager.DeleteGame(ConfigManager.CurrentGameId)

            ; [CRITICAL FIX] Clear the ID immediately so we don't crash looking for a dead game
            ConfigManager.CurrentGameId := ""
            IniWrite("", ConfigManager.IniPath, "LAST_PLAYED", "GameID")

            this.RefreshDropdown()
            this.UpdateButtonState()
            DialogsGui.CustomStatusPop("Game Deleted")
        }
    }

    static OnGameSelect(selectedName) {
        ; Find the ID by the name and set it globally
        for id, game in ConfigManager.Games {
            if (game["SavedName"] == selectedName) {
                ConfigManager.CurrentGameId := id
                Logger.Info("Selected Game changed to: " . selectedName)
                break
            }
        }
        this.UpdateButtonState() ; Enable buttons now that a game is "active" in the UI
    }

    static OnPatchGame() {
        if (ConfigManager.CurrentGameId == "") {
            DialogsGui.CustomTrayTip("No Game Selected", 2)
            return
        }

        game := ConfigManager.GetCurrentGame()

        ; 1. Check if game object is valid
        if !IsObject(game)
            return

        ; 2. Check if the game is actually patchable
        if (!game.HasProp("IsPatchable") || game.IsPatchable != "true") {
            DialogsGui.CustomTrayTip("Not Available", "No patches available for this game.")
            return
        }

        ; 3. Trigger the Tool
        PatchServiceTool.OpenPatcher(game)
    }

    static OnOpenGallery() => SnapshotGallery.Show("")

    static OnViewLogs() => Run(Logger.GetLogFilePath())

    static OnBurstSnap() {
        ; 1. Validation
        count := Integer(this.BurstInput.Value)
        if (count < 1)
            return

        ; 2. Visual Feedback ON
        this.SetBtnHighlight(this.BtnBurstStart, true, "c05FBE4")

        ; Force a quick sleep to let the UI redraw the green color before processing starts
        Sleep(50)

        try {
            ; 3. Perform the Burst
            ; (Assuming CaptureManager logic blocks until done. If it runs via Timer, let me know!)
            CaptureManager.TakeSnapshot(true, count)
        } finally {
            ; 4. Visual Feedback OFF (Reset to default)
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
        ; Assuming ListView control is named 'GameList'
        if !this.GameList
            return ""

        row := this.GameList.GetNext(0, "Focused")
        if (row == 0)
            row := this.GameList.GetNext(0, "Selected")

        return (row > 0) ? this.GameList.GetText(row, 1) : "" ; Returns the ID from Column 1
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

        ; Create UI
        notesGui := Gui("-Caption +Border +Owner" . this.MainGui.Hwnd, "Notes: " . cleanName)
        notesGui.BackColor := "1a1a1a"

        ; Draggable Header
        notesGui.SetFont("s12 Bold cSilver")
        hdr := notesGui.Add("Text", "x15 y10 w470 h25 +0x200", "NOTES: " . StrUpper(cleanName))
        hdr.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, notesGui.Hwnd))

        ; Edit Box (No Scrollbars) and set the text fontsize here
        notesGui.SetFont("s16 Norm cSilver", "Segoe UI")
        existingNotes := ""
        try {
            existingNotes := (Type(game) == "Map") ? (game.Has("Notes") ? game["Notes"] : "") : (game.HasProp("Notes") ? game.Notes : "")
        }
        editCtrl := notesGui.Add("Edit", "x15 y+10 w500 h300 Background333333 cSilver -E0x200 -VScroll -HScroll", existingNotes)

        ; Button Row (2A2A2A / Silver)
        notesGui.SetFont("s11 cSilver")

        ; STAMP
        btnStamp := notesGui.Add("Text", "x15 y+15 w70 h30 +0x200 Center Background333333", "Stamp")
        btnStamp.OnEvent("Click", (*) => EditPaste(FormatTime(, "MM-dd hh:mm tt") . ": ", editCtrl))

        ; SAVE (Explicit Save)
        btnSave := notesGui.Add("Text", "x+10 yp w110 h30 +0x200 Center Background333333", "Save & Close")
        btnSave.OnEvent("Click", (*) => (
            ConfigManager.UpdateGameNotes(id, editCtrl.Value),
            DialogsGui.CustomStatusPop("Notes Saved"),
            notesGui.Destroy()
        ))

        ; CANCEL (Destroy without saving)
        btnCancel := notesGui.Add("Text", "x+10 yp w70 h30 +0x200 Center Background333333", "Cancel")
        btnCancel.OnEvent("Click", (*) => notesGui.Destroy())

        ; Shortcuts
        ; Pressing ESC will now trigger the Cancel behavior (no save)
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

    ;    static SetBtnHighlight(btnObj, isHighlighted := true, activeColor := "05FBE4") {
    ;        if (isHighlighted) {
    ;            ; Background: Slightly lighter grey (Subtle 3D effect)
    ;            btnObj.Opt("Background3A3A3A")
    ;
    ;            ; Text: Neon Cyan (The "Glow")
    ;            ; We add the 'c' here manually
    ;            btnObj.SetFont("c" . activeColor)
    ;
    ;        } else {
    ;            ; Reset to app background (Invisible)
    ;            btnObj.Opt("Background333333")
    ;
    ;            ; Reset text to standard Silver
    ;            btnObj.SetFont("cSilver")
    ;        }
    ;        btnObj.Redraw()
    ;    }

    ; --- The State Cleanup Helper ---
    static ClearGameGroup() {
        ; Use HasProp to prevent the "IsSet" error we saw earlier
        if (this.HasProp("BtnStart") && this.BtnStart)
            this.SetBtnHighlight(this.BtnStart, false)

        if (this.HasProp("BtnRestart") && this.BtnRestart)
            this.SetBtnHighlight(this.BtnRestart, false)
    }

    ; --- INITIAL START OF GAME ---
    static OnStartAction() {
        this.ClearGameGroup()
        this.SetBtnHighlight(this.BtnStart, true)

        ; Your original working logic
        this.StartGameCallback.Call()
    }

    ; --- RESTART ---
    static OnRestartAction() {
        this.ClearGameGroup()
        this.SetBtnHighlight(this.BtnRestart, true)

        ; Your original working logic
        this.OnRestartGame()
    }

    ; --- EXIT ---
    static OnExitAction() {
        ; Visual feedback
        this.SetBtnHighlight(this.BtnExit, true)
        this.ClearGameGroup()

        ; Kill the game process
        this.OnKillGame()

        ; THE KEY STEP: Refresh the data now that the session is over
        ; This updates the cache for the Title Bar and the Top Played list
        this.RefreshTopPlayed()

        ; Reset the Exit button highlight
        SetTimer(() => this.SetBtnHighlight(this.BtnExit, false), -300)

        DialogsGui.CustomStatusPop("🛑 Session Ended - Stats Updated")
        DialogsGui.CustomStatusPop("🛑 Session Ended - Stats Updated")
    }

static OnCpuClick(priorityName, index) {
        ; 1. Reset all to Silver
        for btn in this.BtnCpu {
            btn.SetFont("cSilver")
            btn.Redraw()
        }

        ; 2. Highlight the selected one (Cyan)
        this.BtnCpu[index].SetFont("c05FBE4")
        this.BtnCpu[index].Redraw()

        ; 3. Execute Logic
        try {
            ProcessManager.SetPriority(priorityName)
            DialogsGui.CustomStatusPop("CPU: " . priorityName)
        } catch {
            DialogsGui.CustomStatusPop("Failed to set CPU priority")
        }
    }

    static OnToggleAudio() {
        static isRecording := false
        isRecording := !isRecording ; Flip the state

        this.SetBtnHighlight(this.BtnRecAudio, isRecording, "000666")

        if (isRecording) {
            ; StartRecordingAudio() ; Call your actual recording script here
            DialogsGui.CustomStatusPop("Audio Recording Started")
        } else {
            ; StopRecordingAudio()
            DialogsGui.CustomStatusPop("Audio Recording Saved")
        }
    }

    static OnToggleVideo() {
        static isRecording := false
        isRecording := !isRecording

        this.SetBtnHighlight(this.BtnRecVideo, isRecording, "000666")

        if (isRecording) {
            ; StartRecordingVideo() ; Call your actual video script here
            DialogsGui.CustomStatusPop("Video Recording Started")
        } else {
            ; StopRecordingVideo()
            DialogsGui.CustomStatusPop("Video Recording Saved")
        }
    }

    ; --- CUSTOM DROPDOWN LOGIC ---
    static OpenGameList(items) {
        if !items
            return

        if WinExist("NexusGameListPopup")
            return

        this.GameSelector.GetPos(&gx, &gy, &gw, &gh)
        pt := Buffer(8)
        NumPut("int", gx, "int", gy + gh, pt)
        DllCall("ClientToScreen", "Ptr", this.MainGui.Hwnd, "Ptr", pt)
        screenX := NumGet(pt, 0, "int")
        screenY := NumGet(pt, 4, "int")

        PopupGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner" this.MainGui.Hwnd, "NexusGameListPopup")
        PopupGui.BackColor := "Silver"
        PopupGui.SetFont("s12", "Segoe UI")
        PopupGui.MarginX := 1, PopupGui.MarginY := 1

        ; Add ListBox
        LB := PopupGui.Add("ListBox", "w" (gw + 30) " r15 Background333333 cSilver -E0x200", items)

        ; [FIX] Apply Dark Mode to Scrollbar
        ; This turns the ugly white scrollbar into a sleek dark grey one
        try {
            DllCall("uxtheme\SetWindowTheme", "Ptr", LB.Hwnd, "Str", "DarkMode_Explorer", "Str", 0)
        }

        LB.OnEvent("Change", (*) => this.SelectGame(LB, PopupGui))
        PopupGui.OnEvent("Escape", (*) => PopupGui.Destroy())

        PopupGui.Show("x" screenX " y" screenY)

        SetTimer(CloseIfInactive, 200)

        CloseIfInactive() {
            try {
                if WinExist("ahk_id " PopupGui.Hwnd) {
                    if !WinActive("ahk_id " PopupGui.Hwnd) {
                        SetTimer(, 0)
                        PopupGui.Destroy()
                    }
                } else {
                    SetTimer(, 0)
                }
            }
        }
    }

    static SelectGame(ListBoxCtrl, PopupGui) {
        selected := ListBoxCtrl.Text
        if (selected = "")
            return

        ; Update the visual text box
        this.GameSelector.Value := selected

        ; Close the popup
        PopupGui.Destroy()

        ; Trigger the original logic (Load images, configs, etc.)
        this.OnGameChanged(this.GameSelector)
    }

static FlashButton(btnCtrl, color := "05FBE4") {
        ; 1. Turn ON (Cyan)
        btnCtrl.SetFont("c" . color)
        btnCtrl.Redraw()

        ; 2. Turn OFF (Silver) after 200ms
        SetTimer(() => (btnCtrl.SetFont("cSilver"), btnCtrl.Redraw()), -200)
    }


    ;    static ShowHelp() {
    ;        helpText := "(1) Add Games via 'Set Game Path'.`n(2) Start/Stop via Green/Red buttons.`n(3) Use Window Manager for resizing.`n(4) Track play time in real-time."
    ;        DialogsGui.ShowTextViewer("Quick Start", helpText, 400, 300)
    ;    }
    ;}

    ; HELP WINDOW
    static ShowHelp() {
        helpText := "
        (
    1. ADDING GAME PATHS:
       - Click 'Set Launch Path' to add the main game excutable.
       - For TeknoParrot select a game profile in "Profiles".

    2. EMULATORS:
       - Click 'Emulator Profiles' to set the paths.

    3. RUNNING GAMES:
       - Selecting an .ISO/'EBOOT.BIN will ask you which emulator to use.
       - Or select a game from the list and click 'Start Game'.

    4. WHEN THE GAME IS ACTIVE:
       - Use 'Window Manager' to identify, resize and position the window.
       - Use 'CPU' buttons to fix lag/stutter.
       - 'Burst' takes rapid screenshots (max. 99).

    5. RECORDING:
       - Record only the audio or record a video including sound.
       - Recordings are saved in 'Captures' or 'Recordings' folder.

    6. TOOLS:
       - Game Notes: Create/Edit specific notes for each game.
       - Atrac3 Converter: Convert ATRAC3 audio format to WAV.
       - File Validator: Check MD5/SHA1 hashes of ISOs.
       - Game Search Database.

    7. HOTKEYS:
       - Escape button, exit the game.
       - Escape + 1, hard reset.
       - Control L opens live log trail.

    8. QUICK LAUNCH
       - Right click on the tray icon for quick launch.

    9. MAGNETIC WINDOWS
       - hOLD "Control" on the Main UI to detach it.

    T. TROUBLESHOOTING:
       - If a game does not respond, use Exit Game (X).
       - To reboot a game use 'Restart Game'.
       - Use 'View Logs' to look for errors.
       - The statusbar shows the RAM usage.
       - Audio related, check 'Audio Manager'.
    )"
        DialogsGui.ShowTextViewer(" GML :: Quick Start", helpText, 450, 810)
    }
}