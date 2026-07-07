#Requires AutoHotkey v2.0
; ==============================================================================
; * @description MVP wizard shell for emulator onboarding and configuration.
; * @class EmulatorWizardGui
; * @location lib/ui/EmulatorWizardGui.ahk
; * @author Philip
; * @date 2026/07/08
; * @version 0.1.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\config\ConfigManager.ahk
#Include ..\ui\DialogsGui.ahk
#Include ..\emulator\EmulatorRegistry.ahk
#Include EmulatorConfigGui.ahk

class EmulatorWizardGui {
    static MainGui := ""
    static LstEmulators := ""
    static EdtPath := ""
    static EdtExts := ""
    static EdtIni := ""
    static CurrentEmu := ""

    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Emulator Wizard")
        this.MainGui.BackColor := "1E1E1E"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")
        this.MainGui.OnEvent("Close", (*) => this.Destroy())

        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        w := 760
        this.MainGui.Add("Text", "x0 y0 w" (w - 30) " h30 +0x200 Background2A2A2A", "  Nexus :: Emulator Wizard (MVP)")
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
            .OnEvent("Click", (*) => this.Destroy())

        this.MainGui.Add("Text", "x20 y45 cSilver", "Select Emulator")

        names := []
        for _, emu in EmulatorRegistry.GetAll()
            names.Push(emu.Name)

        this.LstEmulators := this.MainGui.Add("ListBox", "x20 y+5 w220 h280 Choose1", names)
        this.LstEmulators.OnEvent("Change", (*) => this.OnSelect())

        this.MainGui.Add("Text", "x260 y45 cSilver", "Executable Path")
        this.EdtPath := this.MainGui.Add("Edit", "x260 y+5 w420 h26 ReadOnly Background2A2A2A", "")

        this.MainGui.Add("Text", "x260 y+15 cSilver", "ROM Extensions (Registry)")
        this.EdtExts := this.MainGui.Add("Edit", "x260 y+5 w420 h26 ReadOnly Background2A2A2A", "")

        this.MainGui.Add("Text", "x260 y+15 cSilver", "INI Mapping")
        this.EdtIni := this.MainGui.Add("Edit", "x260 y+5 w420 h26 ReadOnly Background2A2A2A", "")

        this.MainGui.Add("Text", "x260 y+15 w420 h85 cAAAAAA +Wrap Background1E1E1E",
            "Phase 1 MVP: centralized metadata + path management from one place.`n"
            . "Next iteration: create new emulator profiles and emulator-specific settings.")

        this.BtnAddTheme(" Browse Path ", (*) => this.OnBrowse(), "x260 y+15 w130 h28 Background2B3B45")
        this.BtnAddTheme(" Save Path ", (*) => this.OnSave(), "x+10 yp w120 h28 Background0C660C")
        this.BtnAddTheme(" Add Profile (Soon) ", (*) => this.OnAddProfile(), "x+10 yp w160 h28 Background4A2A5A")

        this.BtnAddTheme(" Open Emulator Grid ", (*) => EmulatorConfigGui.Show(), "x260 y+15 w180 h28 Background333333")
        this.BtnAddTheme(" Close ", (*) => this.Destroy(), "x+10 yp w100 h28 Background6E0000")

        this.MainGui.Show("w" w " h370")
        this.OnSelect()
    }

    static Destroy() {
        if (this.MainGui)
            this.MainGui.Destroy()
        this.MainGui := ""
        this.LstEmulators := ""
        this.EdtPath := ""
        this.EdtExts := ""
        this.EdtIni := ""
        this.CurrentEmu := ""
    }

    static OnSelect() {
        if !this.LstEmulators
            return

        emuName := StrUpper(this.LstEmulators.Text)
        emu := EmulatorRegistry.FindByName(emuName)
        if !IsObject(emu)
            return

        this.CurrentEmu := emu.Name

        path := IniRead(ConfigManager.IniPath, emu.Section, emu.Key, "")
        this.EdtPath.Value := path

        exts := ""
        if (emu.HasOwnProp("RomExts")) {
            for _, ext in emu.RomExts
                exts .= (exts = "" ? "" : ", ") . ext
        }
        this.EdtExts.Value := exts
        this.EdtIni.Value := emu.Section "/" emu.Key
    }

    static OnBrowse() {
        if (this.CurrentEmu = "")
            return
        this.EdtPath.Value := FileSelect(3, this.EdtPath.Value, "Select " this.CurrentEmu " Executable", "Applications (*.exe)")
    }

    static OnSave() {
        if (this.CurrentEmu = "")
            return

        emu := EmulatorRegistry.FindByName(this.CurrentEmu)
        if !IsObject(emu)
            return

        newPath := Trim(this.EdtPath.Value)
        if (newPath = "") {
            DialogsGui.CustomMsgBox("Path Required", "Please browse to an emulator executable first.")
            return
        }

        IniWrite(newPath, ConfigManager.IniPath, emu.Section, emu.Key)
        DialogsGui.CustomTrayTip("Saved: " this.CurrentEmu, 1)
    }

    static OnAddProfile() {
        DialogsGui.CustomMsgBox("Coming Soon",
            "Profile creation is part of the next wizard iteration.`n"
            "For now, this wizard centralizes path setup using the shared registry.")
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " +0x200 +Center +Border cWhite", label)
        btn.OnEvent("Click", callback)
        return btn
    }
}
