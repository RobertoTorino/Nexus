#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Slick Dark Editor for nexus.json AND nexus.ini
; * @class ConfigViewerGui
; * @location lib/ui/ConfigViewerGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

#Include ..\config\ConfigManager.ahk
#Include DialogsGui.ahk

class ConfigViewerGui {
    static MainGui := ""
    static EditCtrl := ""
    static BgBlock := "" ; The black background behind the edit box

    ; Controls
    static BtnEdit := "", BtnSave := ""
    static BtnClose := "", BtnMin := ""
    static TitleText := ""

    ; State
    static IsEditing := false
    static CurrentMode := "JSON"
    static CurrentPath := ""

    ; Config
    static BorderThick := 1
    static RightBorderWidth := 15
    static BorderColor := "008000"

    ; Color Constants
    static ColorJson := "008000"  ; Green
    static ColorIni := "00E5FF"  ; Aqua

    ; Borders (4 Lines)
    static BorderTop := "", BorderBottom := "", BorderLeft := "", BorderRight := ""

    static ShowGui(mode := "JSON") {
        this.CurrentMode := mode

        if (mode == "INI") {
            this.CurrentPath := ConfigManager.IniPath
            this.BorderColor := this.ColorIni
            title := "Nexus :: System Configuration (INI)"
        } else {
            this.CurrentPath := ConfigManager.JsonPath
            this.BorderColor := this.ColorJson
            title := "Nexus :: Game Database (JSON)"
        }

        if (this.MainGui) {
            this.MainGui.Destroy()
        }

        this.BuildGui(title)
    }

    static BuildGui(title) {
        guiW := 900
        guiH := 650
        this.IsEditing := false

        this.MainGui := Gui("-Caption +ToolWindow +AlwaysOnTop", title)
        this.MainGui.BackColor := "1E1E1E"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")
        this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "") ; Focus Trap

        this.MainGui.OnEvent("Close", (*) => this.Close())
        this.MainGui.OnEvent("Escape", (*) => this.Close())

        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        ; ======================================================================
        ; 1. BORDERS (4 Thin Lines - 1px)
        ; ======================================================================
        t := this.BorderThick
        c := this.BorderColor

        ; Top & Bottom
        this.BorderTop := this.MainGui.Add("Text", "x0 y0 w" guiW " h" t " Background" c, "")
        this.BorderBottom := this.MainGui.Add("Text", "x0 y" (guiH - t) " w" guiW " h" t " Background" c, "")

        ; Left & Right (Full Height)
        this.BorderLeft := this.MainGui.Add("Text", "x0 y0 w" t " h" guiH " Background" c, "")
        this.BorderRight := this.MainGui.Add("Text", "x" (guiW - t) " y0 w" t " h" guiH " Background" c, "")

        ; ======================================================================
        ; 2. HEADER & TOOLBAR
        ; ======================================================================
        headerW := guiW - 100
        HeaderBg := this.MainGui.Add("Text", "x" t " y" t " w" headerW " h32 Background1E1E1E", "")
        HeaderBg.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        this.MainGui.SetFont("s10 Bold cSilver")
        this.TitleText := this.MainGui.Add("Text", "x15 y" t " w500 h32 +0x200 BackgroundTrans cSilver", title)
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        ; Window Buttons
        this.MainGui.SetFont("s12 Bold cWhite")
        xMin := guiW - 85 - t
        this.BtnMin := this.MainGui.Add("Text", "x" xMin " y" t " w40 h32 +0x200 Center Background1E1E1E", "_")
        this.BtnMin.OnEvent("Click", (*) => this.MainGui.Minimize())

        this.MainGui.SetFont("s12 cRed")
        xClose := guiW - 40 - t
        this.BtnClose := this.MainGui.Add("Text", "x" xClose " y" t " w40 h32 +0x200 Center Background1E1E1E", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Close())

        ; Toolbar
        this.MainGui.SetFont("s10 Norm cWhite")
        toolY := 35 + t

        this.MainGui.Add("Text", "x10 y" toolY " h26 +0x200 Center Border", "  ♻️  ")
            .OnEvent("Click", (*) => this.RefreshContent())
        this.MainGui.Add("Text", "x+5 yp h26 +0x200 Center Border", "  📋  ")
            .OnEvent("Click", (*) => this.CopyToClipboard())

        this.BtnEdit := this.MainGui.Add("Text", "x+5 yp h26 +0x200 Center Border Background0x333333", "  🔒 Unlock  ")
        this.BtnEdit.OnEvent("Click", (*) => this.ToggleEditMode())

        this.BtnSave := this.MainGui.Add("Text", "x+5 yp h26 +0x200 Center Border Background0x990000 cWhite Hidden", "  💾 SAVE  ")
        this.BtnSave.OnEvent("Click", (*) => this.SaveChanges())

        ; ======================================================================
        ; 3. EDIT AREA (Black Background + Padded Control)
        ; ======================================================================
        outerY := 75
        outerH := guiH - 75 - t ; Height remaining minus bottom border

        ; A. Black Background Block (Fills the area inside the borders)
        ; This ensures the margin area is BLACK, not Green/Aqua
        this.BgBlock := this.MainGui.Add("Text", "x" t " y" outerY " w" (guiW - t * 2) " h" outerH " Background101010", "")

        ; B. Edit Control (Indented by 10px)
        padX := 10
        padY := 10

        innerX := t + padX
        innerY := outerY + padY
        innerW := guiW - t * 2 - padX - this.RightBorderWidth
        innerH := outerH - padY * 2 ; Pad top and bottom

        this.MainGui.SetFont("s10", "Consolas")
        textColor := (this.CurrentMode == "INI") ? "c" this.ColorIni : "c" this.ColorJson

        this.EditCtrl := this.MainGui.Add("Edit", "x" innerX " y" innerY " w" innerW " h" innerH " +Multi +ReadOnly +VScroll -HScroll -Border -E0x200 Background101010 " . textColor)

        this.RefreshContent()
        this.MainGui.Show("w" guiW " h" guiH)
    }

    static ToggleEditMode() {
        this.IsEditing := !this.IsEditing

        if (this.IsEditing) {
            this.EditCtrl.Opt("-ReadOnly")
            this.EditCtrl.SetFont("cYellow")

            this.BtnEdit.Text := "  🔓 Lock  "
            this.BtnEdit.Opt("Background0x555555")
            this.BtnSave.Visible := true
            DialogsGui.CustomTrayTip("Edit Mode Unlocked", 1)
        } else {
            this.EditCtrl.Opt("+ReadOnly")
            c := (this.CurrentMode == "INI") ? "c" this.ColorIni : "c" this.ColorJson
            this.EditCtrl.SetFont(c)

            this.BtnEdit.Text := "  🔒 Unlock  "
            this.BtnEdit.Opt("Background0x333333")
            this.BtnSave.Visible := false
            this.RefreshContent()
        }
    }

    static SaveChanges() {
        if (!this.IsEditing)
            return

        newContent := this.EditCtrl.Value

        if (this.CurrentMode == "JSON") {
            if (SubStr(Trim(newContent), 1, 1) != "{") {
                if (DialogsGui.CustomMsgBox("Warning", "Invalid JSON structure.`nSave anyway?", 0x30) != "Yes")
                    return
            }
        }

        try {
            FileCopy(this.CurrentPath, this.CurrentPath . ".bak", 1)

            if FileExist(this.CurrentPath)
                FileDelete(this.CurrentPath)

            FileAppend(newContent, this.CurrentPath, "UTF-8")
            ConfigManager.Init()
            DialogsGui.CustomStatusPop("Saved & Reloaded")
            this.ToggleEditMode()
        } catch as err {
            DialogsGui.CustomMsgBox("Save Error", err.Message, 0x10)
        }
    }

    static RefreshContent() {
        if !FileExist(this.CurrentPath) {
            this.EditCtrl.Value := "Error: File not found at:`n" . this.CurrentPath
            return
        }
        try {
            this.EditCtrl.Value := FileRead(this.CurrentPath)
        } catch as err {
            this.EditCtrl.Value := "Error reading file:`n" . err.Message
        }
    }

    static CopyToClipboard() {
        if (this.EditCtrl) {
            A_Clipboard := this.EditCtrl.Value
            DialogsGui.CustomTrayTip("Copied to Clipboard", 1)
        }
    }

    static Close() {
        if (this.MainGui)
            this.MainGui.Destroy()
        this.MainGui := ""
        this.EditCtrl := ""
        this.BtnClose := ""
        this.BtnMin := ""
        this.BtnEdit := ""
        this.BtnSave := ""
        this.BgBlock := ""
        this.BorderTop := ""
        this.BorderBottom := ""
        this.BorderLeft := ""
        this.BorderRight := ""
    }
}