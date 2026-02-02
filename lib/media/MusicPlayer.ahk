#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Music Player (Superslick). Features: Metadata, Visualizer, Edge-to-Edge List.
; * @class MusicPlayer
; * @location lib/media/MusicPlayer.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class MusicPlayer {
    static MainGui := ""
    static Player := ""
    static PlayerCtrl := ""
    static TrackList := ""
    static TimerObj := ""

    ; State
    static Playlist := []
    static CurrentIndex := 0
    static AudioDir := ""
    static FFmpegPath := A_ScriptDir . "\core\ffmpeg.exe"

    ; Playback State
    static IsRepeating := false
    static IsDraggingSlider := false

    ; Window State
    static IsFullScreen := false
    static PrevPos := { x: 0, y: 0, w: 800, h: 500 }

    ; Controls
    static UIControls := []
    static BtnPlay := "", BtnStop := "", BtnNext := "", BtnBrowse := "", BtnRepeat := ""
    static SliderVol := "", TextVolLabel := "", TextTime := "", SliderSeek := ""
    static ContextMenu := ""
    static TitleText := "", BtnMin := "", BtnMax := "", BtnFull := "", BtnClose := ""

    ; ---- OPEN PLAYER ----
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        try {
            this.AudioDir := IniRead(ConfigManager.IniPath, "SETTINGS", "LastMusicPath", "")
        }
        if (this.AudioDir == "") {
            this.AudioDir := A_ScriptDir . "\captures"
        }
        if !DirExist(this.AudioDir) {
            try DirCreate(this.AudioDir)
        }

        guiW := 800
        guiH := 500
        this.PrevPos := { x: -1, y: -1, w: guiW, h: guiH }

        this.MainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus :: Music Player")
        this.MainGui.BackColor := "252523"
        this.MainGui.SetFont("s10 c05FBE4", "Segoe UI")
        this.MainGui.OnEvent("Close", (*) => this.Hide())
        this.MainGui.OnEvent("DropFiles", (guiObj, ctrl, files, *) => this.OnDropFiles(files))
        this.MainGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnResize(minMax, w, h))

        this.UIControls := []

        ; ---- TITLE BAR ----
        this.TitleText := this.MainGui.Add("Text", "x0 y0 w" (guiW - 120) " h30 +0x200 Background252523", "  Nexus :: Music Player :: In fullscreen mode use F12 to switch between monitors")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.UIControls.Push(this.TitleText)

        this.MainGui.SetFont("s10 Norm")
        this.BtnMin := this.AddCtrl("Text", "x+0 yp w30 h30 +0x200 +Center Background252523 c05FBE4", "_")
        this.BtnMin.OnEvent("Click", (*) => this.MainGui.Minimize())

        this.BtnMax := this.AddCtrl("Text", "x+0 yp w30 h30 +0x200 +Center Background252523 c05FBE4", "□")
        this.BtnMax.OnEvent("Click", (*) => this.ToggleMaximize())

        this.BtnFull := this.AddCtrl("Text", "x+0 yp w30 h30 +0x200 +Center Background252523 c05FBE4", "⛶")
        this.BtnFull.OnEvent("Click", (*) => this.ToggleFullScreen())

        this.BtnClose := this.AddCtrl("Text", "x+0 yp w30 h30 +0x200 +Center Background252523", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Hide())
        this.MainGui.SetFont("s10 c05FBE4")

        ; ---- LISTVIEW ----
        this.TrackList := this.MainGui.Add("ListView", "x0 y30 w" guiW " h10 AltSubmit -Grid -VScroll -HScroll Background252523 c05FBE4 +ReadOnly", ["Name", "Artist", "Album", "Length", "Bitrate", "Size", "Type", "FullPath"])
        DllCall("SendMessage", "Ptr", this.TrackList.Hwnd, "UInt", 0x1036, "Ptr", 0x2000, "Ptr", 0x2000)
        this.TrackList.ModifyCol(1, 150) ; Name
        this.TrackList.ModifyCol(2, 100) ; Artist
        this.TrackList.ModifyCol(3, 100) ; Album
        this.TrackList.ModifyCol(4, 60)  ; Length
        this.TrackList.ModifyCol(5, 60)  ; Bitrate
        this.TrackList.OnEvent("DoubleClick", (*) => this.PlaySelected())
        this.TrackList.OnEvent("ContextMenu", (*) => this.ShowContext())
        this.UIControls.Push(this.TrackList)

        ; ---- ACTIVE X PLAYER ----
        try {
            this.PlayerCtrl := this.MainGui.Add("ActiveX", "x0 y0 w0 h0", "WMPlayer.OCX")
            this.Player := this.PlayerCtrl.Value
            this.Player.uiMode := "none"
            this.Player.settings.volume := 50
            this.Player.settings.autoStart := true
        } catch {
            DialogsGui.CustomMsgBox("Error", "Could not load Windows Media Player ActiveX.")
            return
        }

        ; ---- SLIDERS & BUTTONS ----
        this.SliderSeek := this.AddCtrl("Slider", "x0 y420 w" guiW " h24 Range0-1000 ToolTip NoTicks")
        this.SliderSeek.OnEvent("Change", (*) => this.OnSeek())
        this.MainGui.Add("Text", "x0 y0 w0 h0", "") ; Focus Trap

        yBtn := 460
        this.BtnPlay := this.BtnAddTheme("   Play   ", (*) => this.TogglePlay(), "x5 y" yBtn)
        this.BtnStop := this.BtnAddTheme("   Stop   ", (*) => this.Stop(), "x+0 yp")
        this.BtnNext := this.BtnAddTheme("   Next   ", (*) => this.Next(), "x+0 yp")
        this.BtnRepeat := this.BtnAddTheme("  Repeat  ", (*) => this.ToggleRepeat(), "x+0 yp")
        this.BtnBrowse := this.BtnAddTheme("   Browse   ", (*) => this.OnBrowseFiles(), "x+0 yp")

        this.MainGui.SetFont("s9 c05FBE4")
        this.TextVolLabel := this.AddCtrl("Text", "x+15 yp w80 h26 +0x200 +Center +Border", "Sound +/-")
        this.SliderVol := this.AddCtrl("Slider", "x+5 yp w100 h26 Range0-100 ToolTip NoTicks", 50)
        this.SliderVol.OnEvent("Change", (*) => this.SetVolume())
        this.TextTime := this.AddCtrl("Text", "x0 yp+4 w130 h20 Right c05FBE4", "00:00 / 00:00")

        this.CreateContextMenu()

        this.MainGui.Show("w" guiW " h" guiH)
        this.OnResize(0, guiW, guiH)

        ; --- HOTKEYS ---
        HotIfWinActive("ahk_id " this.MainGui.Hwnd)
        Hotkey("F11", (*) => this.ToggleFullScreen(), "On")
        Hotkey("Escape", (*) => this.ExitFullScreen(), "On")
        Hotkey("F12", (*) => this.SwitchMonitor(), "On")
        HotIf()

        this.LoadPlaylist()
        this.TimerObj := ObjBindMethod(this, "UpdateUI")
        SetTimer(this.TimerObj, 100)
    }

    static Hide() {
        if IsObject(this.TimerObj)
            SetTimer(this.TimerObj, 0)
        try {
            if IsObject(this.Player)
                this.Player.controls.stop()
        }
        if (this.MainGui) {
            try {
                HotIfWinActive("ahk_id " this.MainGui.Hwnd)
                Hotkey("F11", "Off")
                Hotkey("Escape", "Off")
                Hotkey("F12", "Off")
                HotIf()
            }
            this.MainGui.Destroy()
        }
        this.MainGui := ""
        this.Player := ""
        this.PlayerCtrl := ""
        this.IsFullScreen := false
    }

    static AddCtrl(type, options, text := "") {
        ctrl := this.MainGui.Add(type, options, text)
        this.UIControls.Push(ctrl)
        return ctrl
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        this.UIControls.Push(btn)
        return btn
    }

    ; ---- RESIZE / FULLSCREEN / MONITOR SWITCH ----

    static ToggleMaximize() {
        if !this.MainGui
            return
        if (this.IsFullScreen)
            this.ExitFullScreen()
        state := WinGetMinMax(this.MainGui.Hwnd)
        if (state == 1) {
            this.MainGui.Restore()
            if (this.PrevPos.w > 0)
                this.MainGui.Move(this.PrevPos.x, this.PrevPos.y, this.PrevPos.w, this.PrevPos.h)
        } else {
            this.MainGui.GetPos(&x, &y, &w, &h)
            this.PrevPos := { x: x, y: y, w: w, h: h }
            this.MainGui.Maximize()
        }
    }

    static ToggleFullScreen() {
        if (this.IsFullScreen)
            this.ExitFullScreen()
        else
            this.EnterFullScreen()
    }

    static EnterFullScreen() {
        if !this.MainGui
            return
        if (WinGetMinMax(this.MainGui.Hwnd) == 0) {
            this.MainGui.GetPos(&x, &y, &w, &h)
            this.PrevPos := { x: x, y: y, w: w, h: h }
        }
        this.IsFullScreen := true
        for ctrl in this.UIControls
            try ctrl.Visible := false
        this.MainGui.Opt("-Border")
        this.MainGui.Move(0, 0, A_ScreenWidth, A_ScreenHeight)
        try {
            this.PlayerCtrl.Visible := true
            this.PlayerCtrl.Move(0, 0, A_ScreenWidth, A_ScreenHeight)
        }
    }

    static ExitFullScreen() {
        if !this.MainGui || !this.IsFullScreen
            return
        this.IsFullScreen := false
        try {
            this.PlayerCtrl.Visible := false
            this.PlayerCtrl.Move(0, 0, 0, 0)
        }
        this.MainGui.Opt("+Border")
        this.MainGui.Restore()
        if (this.PrevPos.w > 0)
            this.MainGui.Move(this.PrevPos.x, this.PrevPos.y, this.PrevPos.w, this.PrevPos.h)
        for ctrl in this.UIControls {
            try {
                ctrl.Visible := true
                ctrl.Redraw()
            }
        }
        WinRedraw(this.MainGui.Hwnd)
        this.MainGui.GetPos(, , &w, &h)
        this.OnResize(0, w, h)
    }

    ; FIXED: Robust Monitor Cycling Logic
    static SwitchMonitor() {
        if (!this.IsFullScreen)
            return

        ; 1. Get Window Center Point (Most reliable way to find monitor)
        this.MainGui.GetPos(&curX, &curY, &curW, &curH)
        centerX := curX + (curW / 2)
        centerY := curY + (curH / 2)

        count := MonitorGetCount()
        currentMon := 1

        ; Find which monitor contains the center point
        Loop count {
            MonitorGet(A_Index, &mL, &mT, &mR, &mB)
            if (centerX >= mL && centerX < mR && centerY >= mT && centerY < mB) {
                currentMon := A_Index
                break
            }
        }

        ; 2. Calculate Next Monitor (Wrap around: 1 -> 2 -> ... -> 1)
        nextMon := currentMon + 1
        if (nextMon > count)
            nextMon := 1

        ; 3. Move to the exact bounds of the next monitor
        MonitorGet(nextMon, &nL, &nT, &nR, &nB)
        newW := nR - nL
        newH := nB - nT

        this.MainGui.Move(nL, nT, newW, newH)
        try this.PlayerCtrl.Move(0, 0, newW, newH)
    }

    static OnResize(minMax, w, h) {
        if (minMax == -1)
            return
        if (this.IsFullScreen) {
            try this.PlayerCtrl.Move(0, 0, w, h)
            return
        }

        try {
            this.TitleText.Move(0, 0, w - 120, 30)
            this.BtnMin.Move(w - 120, 0)
            this.BtnMax.Move(w - 90, 0)
            this.BtnFull.Move(w - 60, 0)
            this.BtnClose.Move(w - 30, 0)
        }

        btnH := 26
        seekH := 24
        yBtn := h - btnH - 15
        ySeek := yBtn - seekH - 10
        listH := ySeek - 30 - 10
        if (listH < 50)
            listH := 50

        try {
            this.TrackList.Move(-2, 30, w + 4, listH)
            this.TrackList.ModifyCol(8, 0) ; Hide Path
            this.TrackList.ModifyCol(1, 200) ; Name
            DllCall("ShowScrollBar", "Ptr", this.TrackList.Hwnd, "Int", 3, "Int", 0)
        }

        try {
            this.SliderSeek.Move(0, ySeek, w, seekH)
            currX := 10
            btns := [this.BtnPlay, this.BtnStop, this.BtnNext, this.BtnRepeat, this.BtnBrowse]
            for btn in btns {
                btn.GetPos(, , &btnW)
                btn.Move(currX, yBtn, btnW, btnH)
                currX += btnW - 1
            }

            timeW := 130
            timeX := w - timeW - 10
            this.TextTime.Move(timeX, yBtn + 4, timeW, 20)

            volSliderW := 150
            volSliderX := timeX - volSliderW - 10
            this.SliderVol.Move(volSliderX, yBtn, volSliderW, btnH)

            this.TextVolLabel.GetPos(, , &volLblW)
            volLblX := volSliderX - volLblW - 5
            this.TextVolLabel.Move(volLblX, yBtn, volLblW, btnH)
        }
    }

    ; ---- METADATA & FILES ----

    static OnBrowseFiles() {
        selected := FileSelect("M3", this.AudioDir, "Select Audio Files", "Audio Files (*.mp3; *.wav; *.wma; *.aac)")

        if (selected == "")
            return

        this.Playlist := []
        this.TrackList.Delete()
        this.TrackList.Opt("-Redraw")

        filesToAdd := []
        if (Type(selected) == "Array") {
            filesToAdd := selected
        } else {
            filesToAdd.Push(selected)
        }

        for filePath in filesToAdd {
            if (filePath == "")
                continue

            this.Playlist.Push(filePath)

            fSize := Round(FileGetSize(filePath) / 1048576, 2) " MB"
            meta := this.GetAudioMetadata(filePath)
            SplitPath(filePath, &fName, &fDir, &fExt)
            this.TrackList.Add(, fName, meta.Artist, meta.Album, meta.Duration, meta.Bitrate, fSize, fExt, filePath)
        }

        this.TrackList.ModifyCol(1, "AutoHdr")
        this.TrackList.Opt("+Redraw")

        if (filesToAdd.Length > 0) {
            SplitPath(filesToAdd[1], , &dir)
            this.AudioDir := dir
            try IniWrite(this.AudioDir, ConfigManager.IniPath, "SETTINGS", "LastMusicPath")
        }
    }

    static LoadPlaylist() {
        this.Playlist := []
        this.TrackList.Delete()
        this.TrackList.Opt("-Redraw")

        if DirExist(this.AudioDir) {
            Loop Files, this.AudioDir . "\*.*" {
                if (A_LoopFileExt ~= "i)^(mp3|wav|wma|aac)$") {
                    this.Playlist.Push(A_LoopFileFullPath)
                    fSize := Round(FileGetSize(A_LoopFileFullPath) / 1048576, 2) " MB"
                    meta := this.GetAudioMetadata(A_LoopFileFullPath)
                    this.TrackList.Add(, A_LoopFileName, meta.Artist, meta.Album, meta.Duration, meta.Bitrate, fSize, A_LoopFileExt, A_LoopFileFullPath)
                }
            }
        }
        this.TrackList.ModifyCol(1, "AutoHdr")
        this.TrackList.Opt("+Redraw")
    }

    static GetAudioMetadata(path) {
        meta := { Artist: "", Album: "", Duration: "", Bitrate: "" }
        try {
            sh := ComObject("Shell.Application")
            dir := RegExReplace(path, "(.*)\\.*", "$1")
            file := RegExReplace(path, ".*\\(.*)", "$1")
            folder := sh.Namespace(dir)
            item := folder.ParseName(file)

            meta.Artist := folder.GetDetailsOf(item, 13)
            meta.Album := folder.GetDetailsOf(item, 14)
            meta.Duration := folder.GetDetailsOf(item, 27)
            meta.Bitrate := folder.GetDetailsOf(item, 28)
        }
        return meta
    }

    static PlaySelected() {
        row := this.TrackList.GetNext()
        if (row == 0)
            return
        fullPath := this.TrackList.GetText(row, 8)
        this.CurrentIndex := row
        this.PlayFile(fullPath)
    }

    static PlayFile(path) {
        if !FileExist(path)
            return
        try {
            this.Player.URL := path
            this.Player.controls.play()

            ; This prevents the next song from starting quietly if previous one was fading out
            this.Player.settings.volume := this.SliderVol.Value

            this.BtnPlay.Text := "  Play  "
            this.BtnPlay.Opt("cLime")

            this.TrackList.Modify(0, "-Select -Focus")
            if (this.CurrentIndex > 0 && this.CurrentIndex <= this.TrackList.GetCount()) {
                this.TrackList.Modify(this.CurrentIndex, "Select Focus")
                this.TrackList.EnsureVisible(this.CurrentIndex)
            }
            this.MainGui.GetPos(, , &w, &h)
            this.OnResize(0, w, h)
        }
    }

    static TogglePlay() {
        if !IsObject(this.Player)
            return
        if (this.Player.playState == 3) {
            this.Player.controls.pause()
            this.BtnPlay.Text := "  Play  "
            this.BtnPlay.Opt("c05FBE4")
        } else if (this.Player.playState == 2) {
            this.Player.controls.play()
            this.BtnPlay.Text := "  Play  "
            this.BtnPlay.Opt("cGreen")
        } else {
            this.PlaySelected()
        }
        this.MainGui.GetPos(, , &w, &h)
        this.OnResize(0, w, h)
    }

    static Stop() {
        if IsObject(this.Player) {
            this.Player.controls.stop()
            this.TextTime.Value := "Stopped"
            this.SliderSeek.Value := 0
            this.BtnPlay.Text := "   Play   "
            this.BtnPlay.Opt("c05FBE4")
            this.MainGui.GetPos(, , &w, &h)
            this.OnResize(0, w, h)
        }
    }

static Next() {
        if (this.Playlist.Length == 0)
            return

        ; If Repeating (Manual Click), just restart the song cleanly.
        if (this.IsRepeating) {
            if (this.CurrentIndex == 0)
                this.CurrentIndex := 1

            ; Seek to 0 is faster than reloading the URL
            if (this.Player.playState == 3) {
                this.Player.controls.currentPosition := 0
            } else {
                ; If stopped, we must reload
                path := this.TrackList.GetText(this.CurrentIndex, 8)
                this.PlayFile(path)
            }
            return
        }

        ; Normal Advance Logic (Next Song)
        count := this.TrackList.GetCount()
        this.CurrentIndex++
        if (this.CurrentIndex > count)
            this.CurrentIndex := 1

        path := this.TrackList.GetText(this.CurrentIndex, 8)
        this.PlayFile(path)
    }

    static ToggleRepeat() {
        this.IsRepeating := !this.IsRepeating
        if (this.IsRepeating) {
            this.BtnRepeat.Text := "  Repeat  "
            this.BtnRepeat.Opt("cLime")
        } else {
            this.BtnRepeat.Text := "  Repeat  "
            this.BtnRepeat.Opt("c05FBE4")
        }
        this.MainGui.GetPos(, , &w, &h)
        this.OnResize(0, w, h)
    }

    static SetVolume() {
        if IsObject(this.Player)
            this.Player.settings.volume := this.SliderVol.Value
    }

    static OnSeek() {
        if !IsObject(this.Player) || !this.Player.currentMedia
            return
        try {
            this.IsDraggingSlider := true
            dur := this.Player.currentMedia.duration
            if (dur > 0) {
                newPos := (this.SliderSeek.Value / 1000) * dur
                this.Player.controls.currentPosition := newPos
            }
            this.IsDraggingSlider := false
        }
    }

static UpdateUI() {
        if (!this.MainGui || !IsObject(this.Player))
            return

        if GetKeyState("LButton", "P")
            return

        try {
            state := this.Player.playState

            ; --- SEAMLESS CROSSFADE LOOP ---
            if (this.IsRepeating && state == 3) { ; 3 = Playing
                try {
                    dur := this.Player.currentMedia.duration
                    pos := this.Player.controls.currentPosition

                    ; CONFIGURATION
                    fadeStart    := 2.5   ; Start fading 2.5s before end
                    rewindPoint  := 0.5   ; Cut off last 0.5s (Volume is 0 here anyway)
                    userVol      := this.SliderVol.Value

                    remaining := dur - pos

                    ; 1. FADE ZONE
                    if (dur > 0 && remaining < fadeStart && remaining > rewindPoint) {
                        ; Map the remaining time to 0-100% volume
                        ; As remaining gets closer to rewindPoint, progress goes 1 -> 0
                        progress := (remaining - rewindPoint) / (fadeStart - rewindPoint)

                        ; Apply volume
                        newVol := Integer(userVol * progress)
                        this.Player.settings.volume := newVol
                    }

                    ; 2. JUMP ZONE (Rewind before song ends)
                    else if (dur > 0 && remaining <= rewindPoint) {
                        this.Player.controls.currentPosition := 0
                        this.Player.settings.volume := userVol ; Restore full volume immediately
                        return
                    }

                    ; 3. NORMAL ZONE (Ensure volume is correct if we seeked back manually)
                    else if (remaining >= fadeStart) {
                        currentEngineVol := this.Player.settings.volume
                        if (currentEngineVol != userVol)
                             this.Player.settings.volume := userVol
                    }
                }
            }
            ; -------------------------------

            ; 8 = MediaEnded.
            ; If we are repeating, we should have caught it above.
            ; If we ended up here, the timer missed the window (lag), so we force a Next() call which handles restart.
            if (state == 8) {
                this.Player.settings.volume := this.SliderVol.Value ; Ensure volume is back up
                this.Next()
                return
            }

            if (state == 3) { ; Playing
                if (this.BtnPlay.Text != "  Play  ") {
                    this.BtnPlay.Text := "  Play  "
                    this.BtnPlay.Opt("cLime")
                    this.MainGui.GetPos(, , &w, &h)
                    this.OnResize(0, w, h)
                }

                pos := this.Player.controls.currentPosition
                dur := this.Player.currentMedia.duration

                if (dur > 0) {
                    timeStr := this.FormatTime(pos) " / " this.FormatTime(dur)
                    this.TextTime.Value := timeStr
                    if (!this.IsDraggingSlider)
                        this.SliderSeek.Value := (pos / dur) * 1000
                }
            } else {
                if (this.BtnPlay.Text != "   Play   ") {
                    this.BtnPlay.Text := "   Play   "
                    this.BtnPlay.Opt("c05FBE4")
                    this.MainGui.GetPos(, , &w, &h)
                    this.OnResize(0, w, h)
                }
            }
        }
    }

    static FormatTime(s) {
        h := Integer(s / 3600)
        m := Integer(Mod(s, 3600) / 60)
        s := Integer(Mod(s, 60))
        if (h > 0)
            return Format("{:02}:{:02}:{:02}", h, m, s)
        return Format("{:02}:{:02}", m, s)
    }

    ; ---- CONTEXT MENU & FILES ----
    static CreateContextMenu() {
        this.ContextMenu := Menu()
        this.ContextMenu.Add("Show in Explorer", (*) => this.OnShowInExplorer())
        this.ContextMenu.Add("Copy Path", (*) => this.OnCopyPath())
        this.ContextMenu.Add("Rename", (*) => this.OnRename())
        this.ContextMenu.Add("Delete", (*) => this.OnDelete())
        this.ContextMenu.Add()
        this.ContextMenu.Add("Convert to MP3", (*) => this.OnConvertToMp3())
    }

    static ShowContext() {
        if (this.TrackList.GetNext() > 0)
            this.ContextMenu.Show()
    }

    static OnShowInExplorer() {
        path := this.GetSelectedPath()
        if (path != "")
            Run('explorer.exe /select,"' . path . '"')
    }

    static OnCopyPath() {
        path := this.GetSelectedPath()
        if (path != "")
            A_Clipboard := path
    }

    static OnRename() {
        path := this.GetSelectedPath()
        if (path == "")
            return
        SplitPath(path, &name, &dir, &ext, &nameNoExt)
        input := InputBox("Enter new name:", "Rename File", "w300 h130", nameNoExt)
        if (input.Result == "Cancel" || input.Value == "")
            return
        newPath := dir . "\" . input.Value . "." . ext
        try {
            FileMove(path, newPath)
            this.LoadPlaylist()
        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Rename failed: " err.Message)
        }
    }

    static OnDelete() {
        path := this.GetSelectedPath()
        if (path == "")
            return
        if (DialogsGui.CustomMsgBox("Delete File", "Are you sure you want to delete:`n" path, 0x34) == "Yes") {
            try {
                FileRecycle(path)
                this.LoadPlaylist()
            } catch as err {
                DialogsGui.CustomMsgBox("Error", "Delete failed: " err.Message)
            }
        }
    }

    static OnConvertToMp3() {
        path := this.GetSelectedPath()
        if (path == "")
            return
        if !FileExist(this.FFmpegPath) {
            DialogsGui.CustomMsgBox("Error", "FFmpeg not found.")
            return
        }
        SplitPath(path, , &dir, &ext, &nameNoExt)
        if (ext = "mp3")
            return
        outPath := dir . "\" . nameNoExt . ".mp3"
        if FileExist(outPath) {
            if (DialogsGui.CustomMsgBox("Overwrite", "File exists. Overwrite?", 0x34) != "Yes")
                return
            FileDelete(outPath)
        }
        cmd := Format('"{1}" -y -i "{2}" -codec:a libmp3lame -qscale:a 2 "{3}"', this.FFmpegPath, path, outPath)
        try {
            RunWait(cmd, , "Hide")
            this.LoadPlaylist()
        }
    }

    static OnDropFiles(files) {
        for f in files {
            if (f ~= "i)\.(mp3|wav|wma|aac)$") {
                this.Playlist.Push(f)
                fSize := Round(FileGetSize(f) / 1048576, 2) " MB"
                meta := this.GetAudioMetadata(f)
                SplitPath(f, , , &ext)
                this.TrackList.Add(, A_LoopFileName, meta.Artist, meta.Album, meta.Duration, meta.Bitrate, fSize, ext, f)
            }
        }
    }

    static GetSelectedPath() {
        row := this.TrackList.GetNext()
        return (row == 0) ? "" : this.TrackList.GetText(row, 8)
    }
}