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
    static SettingRows := []
    static DynamicY := 250

    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Emulator Wizard")
        this.MainGui.BackColor := "101010"
        this.MainGui.SetFont("s10 cSilver", "Segoe UI")
        this.MainGui.OnEvent("Close", (*) => this.Destroy())

        if IsSet(WindowManagerGui)
            WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        w := 860
        this.MainGui.Add("Text", "x0 y0 w" (w - 30) " h30 +0x200 Background101010", "  Nexus :: Emulator Wizard")
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background101010 cRed", "✕")
            .OnEvent("Click", (*) => this.Destroy())
        this.MainGui.Add("Text", "x0 y+2 w" w " h1 BackgroundC0C0C0")

        this.MainGui.Add("Text", "x20 y45 cSilver", "Select Emulator")

        names := []
        for _, emu in EmulatorRegistry.GetAll()
            names.Push(emu.Name)

        this.LstEmulators := this.MainGui.Add("ListBox", "x20 y+5 w220 h360 Choose1 Background101010 cSilver", names)
        this.LstEmulators.OnEvent("Change", (*) => this.OnSelect())

        this.MainGui.Add("Text", "x260 y45 cSilver", "Executable Path")
        this.EdtPath := this.MainGui.Add("Edit", "x260 y+5 w560 h26 ReadOnly Background101010 cSilver +Border", "")

        this.MainGui.Add("Text", "x260 y+15 cSilver", "ROM Extensions (Registry)")
        this.EdtExts := this.MainGui.Add("Edit", "x260 y+5 w560 h26 ReadOnly Background101010 cSilver +Border", "")

        this.MainGui.Add("Text", "x260 y+15 cSilver", "INI Mapping")
        this.EdtIni := this.MainGui.Add("Edit", "x260 y+5 w560 h26 ReadOnly Background101010 cSilver +Border", "")

        this.MainGui.Add("Text", "x260 y+15 w560 h38 cSilver +Wrap Background101010",
            "Create or override emulator profiles and store custom settings from this wizard.")

        this.BtnAddTheme(" Browse Path ", (*) => this.OnBrowse(), "x260 y+30 w130 h28 Background2B3B45")
        this.BtnAddTheme(" Save Path ", (*) => this.OnSave(), "x+10 yp w120 h28 Background0C660C")
        this.BtnAddTheme(" Add/Update Profile ", (*) => this.OnAddProfile(), "x+10 yp w160 h28 Background4A2A5A")

        this.MainGui.Add("Text", "x260 y+18 cSilver", "Emulator Settings Schema")
        this.MainGui.Add("Text", "x260 y+2 w560 h20 cSilver", "Values are saved to nexus.ini under each emulator settings section.")

        this.DynamicY := 248
        this.SettingRows := []

        this.BtnAddTheme(" Save Settings ", (*) => this.OnSaveSettings(), "x260 y460 w130 h28 Background0C660C")
        this.BtnAddTheme(" Open Emulator Grid ", (*) => EmulatorConfigGui.Show(), "x+10 yp w180 h28 Background101010")
        this.BtnAddTheme(" Close ", (*) => this.Destroy(), "x+10 yp w100 h28 Background6E0000")

        this.MainGui.Show("w" w " h510")
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
        this.SettingRows := []
    }

    static OnSelect() {
        if !this.LstEmulators
            return

        emuName := StrUpper(this.LstEmulators.Text)
        emu := EmulatorRegistry.FindByName(emuName)
        if !IsObject(emu)
            return

        this.CurrentEmu := EmulatorRegistry.GetDefValue(emu, "Name")

        path := IniRead(ConfigManager.IniPath, EmulatorRegistry.GetDefValue(emu, "Section"), EmulatorRegistry.GetDefValue(emu, "Key"), "")
        this.EdtPath.Value := path

        exts := ""
        allExts := EmulatorRegistry.GetDefValue(emu, "RomExts", [])
        if IsObject(allExts) {
            for _, ext in allExts
                exts .= (exts = "" ? "" : ", ") . ext
        }
        this.EdtExts.Value := exts
        this.EdtIni.Value := EmulatorRegistry.GetDefValue(emu, "Section") "/" EmulatorRegistry.GetDefValue(emu, "Key")

        this.RenderSettingsSchema(this.CurrentEmu)
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

        IniWrite(newPath, ConfigManager.IniPath, EmulatorRegistry.GetDefValue(emu, "Section"), EmulatorRegistry.GetDefValue(emu, "Key"))
        DialogsGui.CustomTrayTip("Saved: " this.CurrentEmu, 1)
    }

    static OnSaveSettings() {
        if (this.CurrentEmu = "")
            return

        settingsSection := EmulatorRegistry.GetSettingsSection(this.CurrentEmu)
        for _, row in this.SettingRows {
            IniWrite(Trim(row.Edit.Value), ConfigManager.IniPath, settingsSection, row.Key)
        }

        DialogsGui.CustomTrayTip("Settings Saved: " this.CurrentEmu, 1)
    }

    static OnAddProfile() {
        rawName := DialogsGui.AskForString("Profile Name", "Enter unique profile name (A-Z, 0-9, _):", "")
        if (rawName = "")
            return

        name := StrUpper(RegExReplace(Trim(rawName), "[^A-Z0-9_]", "_"))
        if (name = "") {
            DialogsGui.CustomMsgBox("Invalid Name", "Profile name cannot be empty.")
            return
        }

        defaultSection := name . "_PATH"
        defaultKey := name . "Path"

        iniSection := DialogsGui.AskForString("INI Section", "Path section for this profile:", defaultSection)
        if (iniSection = "")
            return

        iniKey := DialogsGui.AskForString("INI Key", "Path key for this profile:", defaultKey)
        if (iniKey = "")
            return

        extCsv := DialogsGui.AskForString("Extensions", "ROM extensions (comma-separated), optional:", "")
        prefix := DialogsGui.AskForString("Prefix", "Library prefix, optional (example: [PSX]):", "")

        launcherChoices := ["STANDARD"]
        for _, def in EmulatorRegistry.GetAll() {
            defName := EmulatorRegistry.GetDefValue(def, "Name", "")
            if (defName != "")
                launcherChoices.Push(defName)
        }
        launcherClass := DialogsGui.AskForChoice("Launcher Class", "Which launcher class should this profile use?", launcherChoices)
        if (launcherClass = "")
            return

        isoChoice := DialogsGui.AskForChoice("ISO Picker", "Show this profile in ISO platform choice?", ["Yes", "No"])
        if (isoChoice = "")
            return

        romExts := []
        if (extCsv != "") {
            for _, ext in StrSplit(extCsv, ",") {
                normalized := EmulatorRegistry.NormalizeExt(ext)
                if (normalized != "")
                    romExts.Push(normalized)
            }
        }

        profile := {
            Name: name,
            Section: iniSection,
            Key: iniKey,
            RomExts: romExts,
            Prefix: Trim(prefix),
            SupportsIsoChoice: (isoChoice = "Yes"),
            LauncherClass: StrUpper(launcherClass),
            SettingsSection: name . "_SETTINGS",
            SettingsSchema: EmulatorRegistry.GetDefaultSettingsSchema()
        }

        if !ConfigManager.UpsertEmulatorProfile(profile) {
            DialogsGui.CustomMsgBox("Save Failed", "Could not persist this emulator profile.")
            return
        }

        EmulatorRegistry.SyncCustomProfilesFromConfig()
        this.RefreshEmulatorList(name)
        DialogsGui.CustomTrayTip("Profile Saved: " name, 1)
    }

    static RefreshEmulatorList(selectName := "") {
        names := []
        for _, emu in EmulatorRegistry.GetAll()
            names.Push(EmulatorRegistry.GetDefValue(emu, "Name", ""))

        this.LstEmulators.Delete()
        this.LstEmulators.Add(names)

        if (selectName != "") {
            for i, item in names {
                if (item = selectName) {
                    this.LstEmulators.Choose(i)
                    break
                }
            }
        } else {
            this.LstEmulators.Choose(1)
        }

        this.OnSelect()
    }

    static RenderSettingsSchema(emulatorName) {
        for _, row in this.SettingRows {
            try row.Label.Visible := false
            try row.Edit.Visible := false
        }
        this.SettingRows := []

        schema := EmulatorRegistry.GetSettingsSchema(emulatorName)
        section := EmulatorRegistry.GetSettingsSection(emulatorName)
        y := this.DynamicY

        for _, item in schema {
            key := EmulatorRegistry.GetDefValue(item, "Key", "")
            if (key = "")
                continue

            label := EmulatorRegistry.GetDefValue(item, "Label", key)
            defaultValue := String(EmulatorRegistry.GetDefValue(item, "Default", ""))
            savedValue := IniRead(ConfigManager.IniPath, section, key, defaultValue)

            lblCtrl := this.MainGui.Add("Text", "x260 y" y " w190 h24 +0x200 cSilver", label ":")
            edtCtrl := this.MainGui.Add("Edit", "x455 y" y " w365 h24 Background101010 cSilver +Border", savedValue)

            this.SettingRows.Push({ Key: key, Label: lblCtrl, Edit: edtCtrl })
            y += 30
        }
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " +0x200 +Center +Border cSilver", label)
        btn.OnEvent("Click", callback)
        return btn
    }
}
