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
#Include ..\window\WindowManager.ahk ; Required for ForceKillAll

class EmulatorConfigGui {
    static MainGui := ""

    static Emulators := [
    { Name: "RPCS3", Section: "RPCS3_PATH", Key: "Rpcs3Path" },
    { Name: "RPCS3_FIGHTER", Section: "RPCS3_FIGHTER_PATH", Key: "Rpcs3FighterPath" },
    { Name: "RPCS3_SHOOTER", Section: "RPCS3_SHOOTER_PATH", Key: "Rpcs3ShooterPath" },
    { Name: "RPCS3_TCRS", Section: "RPCS3_TCRS_PATH", Key: "Rpcs3TcrsPath" },
    { Name: "VITA3K", Section: "VITA3K_PATH", Key: "Vita3kPath" },
    { Name: "VITA3K_3830", Section: "VITA3K_3830_PATH", Key: "Vita3k3830Path" },
    { Name: "PPSSPP", Section: "PPSSPP_PATH", Key: "PpssppPath" },
    { Name: "PCSX2", Section: "PCSX2_PATH", Key: "Pcsx2Path" },
    { Name: "DUCKSTATION", Section: "DUCKSTATION_PATH", Key: "DuckStationPath" },
    { Name: "TEKNO", Section: "TEKNO_PATH", Key: "TeknoPath" },
    { Name: "DOLPHIN", Section: "DOLPHIN_PATH", Key: "DolphinPath" },
    { Name: "VIVANONNO", Section: "VIVANONNO_PATH", Key: "VivaNonnoPath" }
    ]

    static Show() {
        if (this.MainGui)
            this.MainGui.Destroy()
        this.MainGui := Gui("-Caption +Border +ToolWindow +AlwaysOnTop", "Nexus :: Configure Emulators")

        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s12 q5 cWhite", "Segoe UI")

        guiW := 805
        title := this.MainGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background2A2A2A", "  Nexus :: Configure Emulators")
        title.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕").OnEvent("Click", (*) => this.MainGui.Destroy())

        y := 35
        for index, emu in this.Emulators {
            this.MainGui.Add("Button", "x-100 y-100 w0 h0 Default", "")
            currentPath := IniRead(ConfigManager.IniPath, emu.Section, emu.Key, "")

            this.MainGui.Add("Text", "x10 y" y " w120 h26 Right", emu.Name ":")
            edt := this.MainGui.Add("Edit", "x+10 yp h26 w465 +0x200 ReadOnly Background2A2A2A", currentPath)

            this.BtnAddTheme(" 📂 ", this.OnBrowse.Bind(this, emu, edt), "x+5 yp +0x200 Background2B3B45")
            this.BtnAddTheme(" ▶️ ", this.OnRun.Bind(this, edt), "x+5 yp Background0C660C")
            this.BtnAddTheme(" ❌ ", this.OnKill.Bind(this, edt), "x+5 yp Background6E0000")
            y += 35
        }
        this.MainGui.Show("w" guiW " h" (y + 10))
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
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

        ; [FIX] Pre-emptive Strike: Kill zombies before launching
        if (exeName = "TeknoParrotUi.exe") {
             WindowManager.ForceKillAll()
             Sleep(200) ; Brief pause to ensure OS releases handles
        }

        try Run(exePath, dir)
    }

    static OnKill(editCtrl, *) {
        if (editCtrl.Value == "")
            return
        SplitPath(editCtrl.Value, &exeName)

        ; [FIX] Use Nuclear Option for TeknoParrot
        if (exeName = "TeknoParrotUi.exe") {
            WindowManager.ForceKillAll()
            DialogsGui.CustomTrayTip("TeknoParrot (All Processes) Killed", 1)
            return
        }

        ; Standard Kill
        if ProcessExist(exeName)
            ProcessClose(exeName)
        DialogsGui.CustomTrayTip("Terminated: " exeName, 1)
    }
}