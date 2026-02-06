#Requires AutoHotkey v2.0
; ==============================================================================
; * @description GUI to configure, run, and kill emulator executables.
; * @class EmulatorConfigGui
; * @location lib/ui/EmulatorConfigGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\config\ConfigManager.ahk
#Include DialogsGui.ahk
#Include ..\window\WindowManager.ahk
#Include ..\emulator\tools\RomScanner.ahk

class EmulatorConfigGui {
    static MainGui := ""

    ; Added 'RomExts' to define supported file types
    static Emulators := [{ Name: "DOLPHIN", Section: "DOLPHIN_PATH", Key: "DolphinPath", RomExts: ["gcm", "iso", "rvz", "wbfs"] }, { Name: "DUCKSTATION", Section: "DUCKSTATION_PATH", Key: "DuckStationPath", RomExts: ["bin", "chd", "cue", "iso"] }, { Name: "PCSX2", Section: "PCSX2_PATH", Key: "Pcsx2Path", RomExts: ["bin", "chd", "gz", "iso"] }, { Name: "PPSSPP", Section: "PPSSPP_PATH", Key: "PpssppPath", RomExts: ["cso", "elf", "iso", "pbp"] }, { Name: "REDREAM", Section: "REDREAM_PATH", Key: "RedreamPath", RomExts: ["gdi", "cdi", "chd"] }, { Name: "RPCS3", Section: "RPCS3_PATH", Key: "Rpcs3Path" }, { Name: "RPCS3_FIGHTER", Section: "RPCS3_FIGHTER_PATH", Key: "Rpcs3FighterPath" }, { Name: "RPCS3_SHOOTER", Section: "RPCS3_SHOOTER_PATH", Key: "Rpcs3ShooterPath" }, { Name: "RPCS3_TCRS", Section: "RPCS3_TCRS_PATH", Key: "Rpcs3TcrsPath" }, { Name: "SHADPS4", Section: "SHADPS4_PATH", Key: "ShadPs4Path", RomExts: ["elf", "pkg"] }, { Name: "TEKNO", Section: "TEKNO_PATH", Key: "TeknoPath" }, { Name: "VITA3K", Section: "VITA3K_PATH", Key: "Vita3kPath" }, { Name: "VITA3K_3830", Section: "VITA3K_3830_PATH", Key: "Vita3k3830Path" }, { Name: "VIVANONNO", Section: "VIVANONNO_PATH", Key: "VivaNonnoPath", RomExts: ["zip"] }, { Name: "YUZU", Section: "YUZU_PATH", Key: "YuzuPath", RomExts: ["nsp", "xci"] },
    ]

    static Show() {
        if (this.MainGui)
            this.MainGui.Destroy()
        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Configure Emulators")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s12 cWhite", "Segoe UI")

        guiW := 805

        title := this.MainGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background2A2A2A", "  Nexus :: Configure Emulators")
        title.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.MainGui.Destroy())

        y := 45
        for index, emu in this.Emulators {
            this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "")
            currentPath := IniRead(ConfigManager.IniPath, emu.Section, emu.Key, "")

            this.MainGui.Add("Text", "x10 y" y " w125 h26 Right", emu.Name ":")
            edt := this.MainGui.Add("Edit", "x+10 yp h26 w510 +0x200 ReadOnly Background2A2A2A", currentPath)

            this.BtnAddTheme(" 📂 ", this.OnBrowse.Bind(this, emu, edt), "x+5 yp +0x200 Background2B3B45")
            this.BtnAddTheme(" ▶️ ", this.OnRun.Bind(this, edt), "x+5 yp Background0C660C")
            this.BtnAddTheme(" ❌ ", this.OnKill.Bind(this, edt), "x+5 yp Background6E0000")

            ; [NEW] Render Scan Button if supported
            if (emu.HasOwnProp("RomExts")) {
                this.BtnAddTheme(" 💿 ", this.OnScan.Bind(this, emu), "x+5 yp Background4A2A5A")
            }

            y += 35
        }
        this.MainGui.Show("w" guiW " h" (y + 10))
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static OnScan(emu, *) {
        if (!emu.HasOwnProp("RomExts"))
            return

        RomScanner.Scan(emu.Name, emu.RomExts)
    }

    static OnBrowse(emu, editCtrl, *) {
        newPath := FileSelect(3, editCtrl.Value, "Select " emu.Name " Executable", "Applications (*.exe)")
        if (newPath != "") {
            editCtrl.Value := newPath
            IniWrite(newPath, ConfigManager.IniPath, emu.Section, emu.Key)
        }
    }

    static OnRun(editCtrl, *) {
        exePath := editCtrl.Value
        if (exePath == "")
            return

        SplitPath(exePath, &exeName, &dir)

        if (exeName = "TeknoParrotUi.exe") {
            WindowManager.ForceKillAll()
            Sleep(200)
        }

        try Run(exePath, dir)
    }

    static OnKill(editCtrl, *) {
        if (editCtrl.Value == "")
            return
        SplitPath(editCtrl.Value, &exeName)

        if (exeName = "TeknoParrotUi.exe") {
            WindowManager.ForceKillAll()
            DialogsGui.CustomTrayTip("TeknoParrot (All Processes) Killed", 1)
            return
        }

        if ProcessExist(exeName)
            ProcessClose(exeName)
        DialogsGui.CustomTrayTip("Terminated: " exeName, 1)
    }
}