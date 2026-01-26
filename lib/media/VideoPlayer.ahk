#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Video Manager (Dark Mode). Features: Buttons at Bottom, Invisible Borders, Strict Formatting.
; * @class VideoPlayer
; * @location lib/media/VideoPlayer.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class VideoPlayer {
    static MainGui := ""
    static ListCtrl := ""
    static VideoDir := ""

    ; Window State
    static IsFullScreen := false
    static PrevPos := { x: 0, y: 0, w: 800, h: 500 }

    ; Title Bar Controls
    static TitleText := "", BtnMin := "", BtnMax := "", BtnFull := "", BtnClose := ""

    ; Bottom Controls
    static BtnPlay := "", BtnStop := "", BtnRefresh := "", BtnDelete := "", BtnCopy := "", BtnBrowse := ""

    ; ---- OPEN MANAGER ----
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        ; --- LOAD SETTINGS ---
        try {
            this.VideoDir := IniRead(ConfigManager.IniPath, "SETTINGS", "LastVideoPath", "")
        }
        if (this.VideoDir == "") {
            this.VideoDir := A_ScriptDir . "\captures"
        }
        if !DirExist(this.VideoDir) {
            try DirCreate(this.VideoDir)
        }

        ; --- DEFINE DEFAULT SIZE ---
        guiW := 900
        guiH := 500
        this.PrevPos := { x: -1, y: -1, w: guiW, h: guiH }

        ; --- GUI SETUP ---
        this.MainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus :: Video Manager")
        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")

        this.MainGui.OnEvent("Close", (*) => this.Close())
        this.MainGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnResize(minMax, w, h))
        this.MainGui.OnEvent("DropFiles", (guiObj, ctrl, files, *) => this.OnDropFiles(files))

        ; HOTKEY: F11 for Full Screen
        HotIfWinActive("ahk_id " this.MainGui.Hwnd)
        Hotkey("F11", (*) => this.ToggleFullScreen(), "On")
        HotIf()

        ; --- CUSTOM TITLE BAR ---
        this.TitleText := this.MainGui.Add("Text", "x0 y0 w" (guiW - 120) " h30 +0x200 Background2A2A2A", "  Nexus :: Video Manager")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        this.MainGui.SetFont("s10 Norm")
        this.BtnMin := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "_")
        this.BtnMin.OnEvent("Click", (*) => this.MainGui.Minimize())

        this.BtnMax := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "□")
        this.BtnMax.OnEvent("Click", (*) => this.ToggleMaximize())

        this.BtnFull := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "⛶")
        this.BtnFull.OnEvent("Click", (*) => this.ToggleFullScreen())

        this.BtnClose := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Close())
        this.MainGui.SetFont("s10 cWhite")

        ; ---- LISTVIEW (Dark Mode) ----
        ; Changed h400 to h(guiH - 80)
        ; This fills the window but leaves room (80px) for the buttons at the bottom.
        this.ListCtrl := this.MainGui.Add("ListView", "x-2 y30 w" (guiW + 4) " h" (guiH - 80) " AltSubmit -Grid Background2A2A2A cWhite", ["Filename", "Duration", "Size", "Date Created", "FullPath"])
        this.ListCtrl.ModifyCol(1, 300) ; Name
        this.ListCtrl.ModifyCol(2, 80)  ; Duration
        this.ListCtrl.ModifyCol(3, 80)  ; Size
        this.ListCtrl.ModifyCol(4, 140) ; Date
        this.ListCtrl.ModifyCol(5, 200)   ; Hidden Path

        this.ListCtrl.OnEvent("DoubleClick", (ctrl, row) => this.PlaySelected(row))
        this.ListCtrl.OnEvent("ContextMenu", (*) => this.ShowContext())

        ; ---- BUTTONS (Bottom) ----
        ; We create them at a safe Y position, OnResize will snap them.
        yBtn := guiH - 40
        this.BtnPlay := this.BtnAddTheme("  Play Video  ", (*) => this.PlaySelected(), "x5 y" yBtn)
        this.BtnStop := this.BtnAddTheme("  Close Player  ", (*) => this.CloseExternalPlayers(), "x+0 yp")
        this.BtnRefresh := this.BtnAddTheme("  Refresh  ", (*) => this.LoadVideos(), "x+0 yp")
        this.BtnDelete := this.BtnAddTheme("  Delete  ", (*) => this.DeleteVideo(), "x+0 yp")
        this.BtnCopy := this.BtnAddTheme("  Copy  ", (*) => this.CopyVideo(), "x+0 yp")
        this.BtnBrowse := this.BtnAddTheme("  Browse  ", (*) => this.BrowseFolder(), "x+0 yp")

        this.MainGui.Show("w" guiW " h" guiH)
        this.LoadVideos()
    }

    static Close() {
        if (this.MainGui) {
            try {
                HotIfWinActive("ahk_id " this.MainGui.Hwnd)
                Hotkey("F11", "Off")
                HotIf()
            }
            this.MainGui.Destroy()
        }
        this.MainGui := ""
        this.IsFullScreen := false
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; ---- RESIZE & FULLSCREEN LOGIC ----
    static ToggleMaximize() {
        if !this.MainGui
            return

        if (this.IsFullScreen)
            this.ToggleFullScreen()

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
        if !this.MainGui
            return

        if (this.IsFullScreen) {
            ; ---- RESTORE ----
            this.MainGui.Opt("+Border")
            this.MainGui.Move(this.PrevPos.x, this.PrevPos.y, this.PrevPos.w, this.PrevPos.h)
            this.IsFullScreen := false
        } else {
            ; ---- GO FULLSCREEN ----
            if (WinGetMinMax(this.MainGui.Hwnd) == 0) {
                this.MainGui.GetPos(&x, &y, &w, &h)
                this.PrevPos := { x: x, y: y, w: w, h: h }
            }
            this.MainGui.Opt("-Border")
            this.MainGui.Move(0, 0, A_ScreenWidth, A_ScreenHeight)
            this.IsFullScreen := true
        }
    }

    static OnResize(minMax, w, h) {
        if (minMax == -1)
            return

        ; Title Bar Buttons (Right Anchor)
        try {
            this.TitleText.Move(0, 0, w - 120, 30)
            xPos := w - 120
            this.BtnMin.Move(xPos, 0)
            this.BtnMax.Move(xPos + 30, 0)
            this.BtnFull.Move(xPos + 60, 0)
            this.BtnClose.Move(xPos + 90, 0)
        }

        ; Calculate Bottom Layout
        btnH := 26
        margin := 10
        btnY := h - btnH - margin

        listH := btnY - 40 ; 30 for title, 10 for margin
        if (listH < 100) listH := 100
            ; Move List
            try this.ListCtrl.Move(-2, 30, w + 4, listH)
        ; Inside OnResize method:
        ; -2 = X position
        ; 30 = Y position (Title bar height)
        ; w + 4 = Width
        ; h - 80 = New Height (Total Height minus TitleBar and Bottom Buttons)
        this.ListCtrl.Move(-2, 30, w + 4, h - 80)

        ; Move Buttons
        try {
            this.BtnPlay.Move(5, btnY)
            this.BtnPlay.GetPos(, , &w1)

            xNext := 5 + w1
            this.BtnStop.Move(xNext, btnY)
            this.BtnStop.GetPos(, , &w2)

            xNext += w2
            this.BtnRefresh.Move(xNext, btnY)
            this.BtnRefresh.GetPos(, , &w3)

            xNext += w3
            this.BtnDelete.Move(xNext, btnY)
            this.BtnDelete.GetPos(, , &w4)

            xNext += w4
            this.BtnCopy.Move(xNext, btnY)
            this.BtnCopy.GetPos(, , &w5)

            xNext += w5
            this.BtnBrowse.Move(xNext, btnY)
        }
    }

    ; ---- DATA LOADING ----
    static LoadVideos() {
        this.ListCtrl.Delete()
        if !DirExist(this.VideoDir) {
            return
        }

        try IniWrite(this.VideoDir, ConfigManager.IniPath, "SETTINGS", "LastVideoPath")

        sh := ComObject("Shell.Application")
        lastDir := ""
        objFolder := ""
        count := 0

        Loop Files, this.VideoDir . "\*.mp4", "R" {
            fullPath := A_LoopFileFullPath
            dir := A_LoopFileDir
            name := A_LoopFileName
            sizeMB := Round(FileGetSize(fullPath) / 1048576, 2) " MB"
            created := FormatTime(FileGetTime(fullPath, "C"), "yyyy-MM-dd HH:mm")
            duration := ""

            try {
                if (dir != lastDir) {
                    objFolder := sh.NameSpace(dir)
                    lastDir := dir
                }
                if (objFolder) {
                    objItem := objFolder.ParseName(name)
                    if (objItem) {
                        duration := objFolder.GetDetailsOf(objItem, 27)
                    }
                }
            }
            this.ListCtrl.Add(, name, duration, sizeMB, created, fullPath)
            count++
        }

        this.ListCtrl.ModifyCol(1, "AutoHdr")
    }

    ; ---- INTERACTIONS ----
    static PlaySelected(row := 0) {
        if (!row) {
            row := this.ListCtrl.GetNext()
        }
        if (!row) {
            return
        }

        path := this.ListCtrl.GetText(row, 5)
        if FileExist(path) {
            try {
                Run(path)
            } catch as err {
                DialogsGui.CustomMsgBox("Error", "Could not launch:`n" err.Message)
            }
        }
    }

    static CloseExternalPlayers() {
        players := ["ahk_exe vlc.exe", "ahk_exe mpc-hc64.exe", "ahk_exe mpc-be64.exe", "ahk_exe ApplicationFrameHost.exe"]
        for p in players {
            if WinExist(p) {
                if (p == "ahk_exe ApplicationFrameHost.exe") {
                    if (WinGetTitle(p) ~= "Movies & TV|Films & TV") {
                        WinClose(p)
                    }
                } else {
                    WinClose(p)
                }
            }
        }
    }

    static ShowContext() {
        if (this.ListCtrl.GetNext() == 0) {
            return
        }
        m := Menu()
        m.Add("Play", (*) => this.PlaySelected())
        m.Add("Open File Location", (*) => this.OpenFolder())
        m.Add()
        m.Add("Copy to...", (*) => this.CopyVideo())
        m.Add("Delete", (*) => this.DeleteVideo())
        m.Show()
    }

    static OpenFolder() {
        path := this.GetSelectedPath()
        if (path != "") {
            Run('explorer.exe /select,"' path '"')
        }
    }

    static DeleteVideo() {
        path := this.GetSelectedPath()
        if (path == "") {
            return
        }
        if (DialogsGui.CustomMsgBox("Confirm Delete", "Recycle video?`n" path, 0x34) == "Yes") {
            try {
                FileRecycle(path)
                this.LoadVideos()
            }
        }
    }

    static CopyVideo() {
        path := this.GetSelectedPath()
        if (path == "") {
            return
        }
        targetDir := DirSelect("*C:\", 3, "Select folder to copy video to")
        if (targetDir == "") {
            return
        }
        SplitPath(path, &name)
        try {
            FileCopy(path, targetDir . "\" . name)
            DialogsGui.CustomMsgBox("Success", "Video copied.")
        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Copy failed:`n" err.Message)
        }
    }

    static BrowseFolder() {
        selected := DirSelect("*" this.VideoDir, 3, "Select Video Folder")
        if (selected != "") {
            this.VideoDir := selected
            this.LoadVideos()
        }
    }

    static OnDropFiles(files) {
        for f in files {
            if (f ~= "i)\.mp4$") {
                SplitPath(f, , &dir)
                this.VideoDir := dir
                this.LoadVideos()
                break
            }
        }
    }

    static GetSelectedPath() {
        row := this.ListCtrl.GetNext()
        return (row == 0) ? "" : this.ListCtrl.GetText(row, 5)
    }
}