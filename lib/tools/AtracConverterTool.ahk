#Requires AutoHotkey v2.0
; ==============================================================================
; * @description ATRAC3 (AT3) to WAV Converter. Features: Batch Conversion, Auto-Install (core folder).
; * @class AtracConverterTool
; * @location lib/tools/AtracConverterTool.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class AtracConverterTool {
    static MainGui := ""
    static ListCtrl := ""
    static TempDir := A_Temp . "\core"
    static CLIExe := ""

    ; Window State
    static PrevPos := { x: 0, y: 0, w: 600, h: 400 }

    ; Controls
    static BtnAdd := "", BtnConvert := "", BtnClear := "", BtnOpenDir := ""
    static TitleText := "", BtnMin := "", BtnMax := "", BtnClose := ""

    ; OPEN TOOL
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        ; Install Dependencies (Silent)
        this.InstallTools()

        ; DEFINE SIZE & LAYOUT
        guiW := 600
        guiH := 400
        this.PrevPos := { x: -1, y: -1, w: guiW, h: guiH }

        ; Layout Math
        titleH := 30
        btnAreaH := 40

        ; List Height = Total - Title - Bottom
        listH := guiH - titleH - btnAreaH

        ; Button Y Position
        btnY := guiH - 35

        ; CREATE GUI
        this.MainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow +MinSize500x300", "ATRAC3 Converter")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")

        this.MainGui.OnEvent("Close", (*) => this.Close())
        this.MainGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnResize(minMax, w, h))
        this.MainGui.OnEvent("DropFiles", (guiObj, ctrl, files, *) => this.OnDropFiles(files))

        ; --- CUSTOM TITLE BAR ---
        this.TitleText := this.MainGui.Add("Text", "x0 y0 w" (guiW - 90) " h" titleH " +0x200 Background2A2A2A", "   ATRAC3 Converter")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        this.MainGui.SetFont("s10 Norm")
        this.BtnMin := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "_")
        this.BtnMin.OnEvent("Click", (*) => this.MainGui.Minimize())

        this.BtnMax := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "□")
        this.BtnMax.OnEvent("Click", (*) => this.ToggleMaximize())

        this.BtnClose := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Close())
        this.MainGui.SetFont("s10 cWhite")

        ; --- LISTVIEW (Dark Mode) ---
        this.ListCtrl := this.MainGui.Add("ListView", "x-2 y" titleH " w" (guiW + 4) " h" listH " AltSubmit -Grid Background2A2A2A cWhite", ["File Name", "Status", "Size", "FullPath"])
        this.ListCtrl.ModifyCol(1, 250) ; Name
        this.ListCtrl.ModifyCol(2, 100) ; Status
        this.ListCtrl.ModifyCol(3, 80)  ; Size
        this.ListCtrl.ModifyCol(4, 0)   ; Hide Path

        ; --- BUTTONS (Flat Style) ---
        this.BtnAdd := this.BtnAddTheme("  Add Files  ", (*) => this.BrowseFiles(), "x5 y" btnY)
        this.BtnConvert := this.BtnAddTheme("  Convert All  ", (*) => this.ConvertAll(), "x+0 yp")
        this.BtnClear := this.BtnAddTheme("  Clear List  ", (*) => this.ClearList(), "x+0 yp")
        this.BtnOpenDir := this.BtnAddTheme("  Open Folder  ", (*) => this.OpenFolder(), "x+0 yp")

        this.MainGui.Show("w" guiW " h" guiH)
    }

    static Close() {
        if (this.MainGui) {
            this.MainGui.Destroy()
        }
        this.MainGui := ""
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static ToggleMaximize() {
        if !this.MainGui
            return
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

    ; RESIZE LOGIC
    static OnResize(minMax, w, h) {
        if (minMax == -1)
            return

        ; Move Title Bar
        try {
            this.TitleText.Move(0, 0, w - 90, 30)
            xPos := w - 90
            this.BtnMin.Move(xPos, 0)
            this.BtnMax.Move(xPos + 30, 0)
            this.BtnClose.Move(xPos + 60, 0)
        }

        ; Calculate Layout
        titleH := 30
        btnAreaH := 40
        btnY := h - 35 ; Button Y Position

        listH := h - titleH - btnAreaH
        if (listH < 100) listH := 100
            ; Resize List
            try this.ListCtrl.Move(-2, titleH, w + 4, listH)

        ; Move Buttons
        try {
            this.BtnAdd.Move(5, btnY)
            this.BtnAdd.GetPos(, , &w1)

            xNext := 5 + w1
            this.BtnConvert.Move(xNext, btnY)
            this.BtnConvert.GetPos(, , &w2)

            xNext += w2
            this.BtnClear.Move(xNext, btnY)
            this.BtnClear.GetPos(, , &w3)

            xNext += w3
            this.BtnOpenDir.Move(xNext, btnY)
        }
    }

    ; LOGIC
    static BrowseFiles() {
        files := FileSelect("M3", , "Select AT3 Files", "Audio (*.at3)")
        if (files == "") {
            return
        }

        for f in files {
            this.AddFile(f)
        }
    }

    static OnDropFiles(files) {
        for f in files {
            if (f ~= "i)\.at3$") {
                this.AddFile(f)
            }
        }
    }

    static AddFile(path) {
        SplitPath(path, &name)
        sizeMB := Round(FileGetSize(path) / 1024, 0) " KB"
        this.ListCtrl.Add(, name, "Queued", sizeMB, path)
    }

    static ClearList() {
        this.ListCtrl.Delete()
    }

    static OpenFolder() {
        row := this.ListCtrl.GetNext()
        path := (row > 0) ? this.ListCtrl.GetText(row, 4) : ""

        if (path != "") {
            Run('explorer.exe /select,"' path '"')
        } else {
            Run(A_ScriptDir)
        }
    }

    static ConvertAll() {
        count := this.ListCtrl.GetCount()
        if (count == 0) {
            return
        }

        if !FileExist(this.CLIExe) {
            DialogsGui.CustomMsgBox("Error", "Converter tool missing:`n" this.CLIExe)
            return
        }

        Loop count {
            row := A_Index
            fullPath := this.ListCtrl.GetText(row, 4)
            status := this.ListCtrl.GetText(row, 2)

            if (status == "Done") {
                continue
            }

            this.ListCtrl.Modify(row, "Vis", "", "Converting...")

            SplitPath(fullPath, &name, &dir, , &nameNoExt)
            outPath := dir . "\" . nameNoExt . "_converted.wav"

            ; vgmstream syntax
            cmd := Format('"{1}" "{2}" -o "{3}"', this.CLIExe, fullPath, outPath)

            try {
                RunWait(cmd, , "Hide")
                if FileExist(outPath) {
                    this.ListCtrl.Modify(row, "", "", "Done")
                } else {
                    this.ListCtrl.Modify(row, "", "", "Failed")
                }
            } catch {
                this.ListCtrl.Modify(row, "", "", "Error")
            }
        }
        DialogsGui.CustomMsgBox("Success", "Batch conversion completed.")
    }

    ; TOOL INSTALLATION (From 'core' folder)
    static InstallTools() {
        if !DirExist(this.TempDir) {
            DirCreate(this.TempDir)
        }

        this.CLIExe := this.TempDir . "\vgmstream-cli.exe"

        ; If tools exist in temp, we skip to save time
        if FileExist(this.CLIExe) {
            return
        }

        ; Install files from "core" to TempDir
        try {
            ; Core Executable
            FileInstall "core\vgmstream-cli.exe", this.TempDir . "\vgmstream-cli.exe", 1

            ; Required DLLs for ATRAC/VGM
            FileInstall "core\avcodec-vgmstream-59.dll", this.TempDir . "\avcodec-vgmstream-59.dll", 1
            FileInstall "core\avformat-vgmstream-59.dll", this.TempDir . "\avformat-vgmstream-59.dll", 1
            FileInstall "core\avutil-vgmstream-57.dll", this.TempDir . "\avutil-vgmstream-57.dll", 1
            FileInstall "core\libatrac9.dll", this.TempDir . "\libatrac9.dll", 1
            FileInstall "core\libcelt-0061.dll", this.TempDir . "\libcelt-0061.dll", 1
            FileInstall "core\libcelt-0110.dll", this.TempDir . "\libcelt-0110.dll", 1
            FileInstall "core\libg719_decode.dll", this.TempDir . "\libg719_decode.dll", 1
            FileInstall "core\libmpg123-0.dll", this.TempDir . "\libmpg123-0.dll", 1
            FileInstall "core\libspeex-1.dll", this.TempDir . "\libspeex-1.dll", 1
            FileInstall "core\libvorbis.dll", this.TempDir . "\libvorbis.dll", 1
        } catch as err {
            ; Silent fail or log if Logger exists
            if IsSet(Logger)
                Logger.Error("AtracConverterTool: Failed to install tools. " err.Message)
        }
    }
}