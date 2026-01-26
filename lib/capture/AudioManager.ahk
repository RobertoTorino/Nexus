#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Manages System Audio, Emulator Config, and VoiceMeeter Hardware.
; * @class AudioManager
; * @location lib/capture/AudioManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\emulator\tools\Rpcs3AudioTool.ahk
#Include ..\emulator\tools\DuckStationAudioTool.ahk
#Include ..\config\ConfigManager.ahk
#Include ..\core\Logger.ahk
#Include ..\ui\DialogsGui.ahk

class AudioManager {
    ; Configuration
    static VmDllPath := "C:\Program Files (x86)\VB\Voicemeeter\VoicemeeterRemote64.dll"
    static VmAppPath := "C:\Program Files (x86)\VB\Voicemeeter\voicemeeterpro.exe"

    static IsConnected := false
    static GuiObj := ""

    ; Controls
    static DropdownRpcs3 := "", DropdownDuck := ""
    static DropdownA1 := "", DropdownA2 := "", DropdownA3 := ""
    static BtnSoftReset := ""

    static DeviceListCache := []

    ; ---- PUBLIC API ----
    static Init() {
        if !FileExist(this.VmDllPath) {
            Logger.Warn("VoiceMeeter DLL not found.")
            return false
        }
        try {
            DllCall("LoadLibrary", "Str", this.VmDllPath, "Ptr")
            if (DllCall(this.VmDllPath "\VBVMR_Login", "Int") == 0) {
                this.IsConnected := true
                Logger.Info("Audio Manager Connected")
                return true
            }
        } catch as err {
            Logger.Error("Audio Init Exception: " err.Message)
        }
        return false
    }

    static Shutdown() {
        if this.IsConnected && FileExist(this.VmDllPath) {
            try DllCall(this.VmDllPath "\VBVMR_Logout")
            this.IsConnected := false
        }
    }

    ; ---- GUI INTERFACE ----
    static ShowGui() {
        if (this.GuiObj) {
            this.GuiObj.Show()
            return
        }

        ; ---- BORDERLESS DARK WINDOW ----
        this.GuiObj := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Audio Manager")
        this.GuiObj.BackColor := "2A2A2A"
        this.GuiObj.SetFont("s9 cWhite", "Segoe UI")

        ; ---- CUSTOM TITLE BAR ----
        this.GuiObj.Add("Text", "x0 y0 w370 h30 +0x200 Background2A2A2A", "   Nexus :: Audio Manager")
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.GuiObj.Hwnd)) ; Drag

        this.GuiObj.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
            .OnEvent("Click", (*) => this.Destroy())

        ; --- LOAD DEVICES ---
        if (this.DeviceListCache.Length == 0)
            this.RefreshDeviceList(false)

        allDevices := this.DeviceListCache

        ; Filter for Hardware Only
        hwDevices := []
        for dev in allDevices {
            if (dev != "Default" && !InStr(dev, "Voicemeeter") && !InStr(dev, "CABLE"))
                hwDevices.Push(dev)
        }
        if (hwDevices.Length == 0)
            hwDevices.Push("Speakers")

        ; ---- SECTION 1: EMULATOR CONFIG (y40 start) ----
        this.GuiObj.Add("GroupBox", "x10 y40 w380 h130 cWhite", "Emulator Audio Config")

        this.GuiObj.Add("Text", "x20 y65", "RPCS3:")

        this.GuiObj.SetFont("cBlack") ; Switch for Dropdown
        this.DropdownRpcs3 := this.GuiObj.Add("DropDownList", "x70 y60 w150 Choose1", allDevices)
        this.GuiObj.SetFont("cWhite") ; Switch back

        this.BtnAddTheme(" Set ", (*) => this.OnSetRpcs3(), "x225 y60 w55")

        this.BtnAddTheme(" Refresh Device List ↻ ", (*) => this.RefreshDeviceList(true), "x20 y90 w260")

        this.GuiObj.Add("Text", "x20 y120", "DuckSt:")

        this.GuiObj.SetFont("cBlack")
        this.DropdownDuck := this.GuiObj.Add("DropDownList", "x70 y115 w150 Choose1", allDevices)
        this.GuiObj.SetFont("cWhite")

        this.BtnAddTheme(" Set ", (*) => this.OnSetDuck(), "x225 y115 w55")

        ; ---- SECTION 2: HARDWARE OUTPUT MAPPING (y180 start) ----
        this.GuiObj.Add("GroupBox", "x10 y180 w380 h175 cWhite", "Hardware Output Mapping")

        ; A1 (Master)
        this.GuiObj.Add("Text", "x20 y205", "Out A1:")
        this.GuiObj.SetFont("cBlack")
        this.DropdownA1 := this.GuiObj.Add("DropDownList", "x70 y200 w130", hwDevices)
        this.GuiObj.SetFont("cWhite")
        this.BtnAddTheme(" Set ", (*) => this.SetHardwareOutput(0, this.DropdownA1.Text, "A1"), "x205 y200 w45")
        this.BtnAddTheme(" X ", (*) => this.ClearHardwareOutput(0, "A1"), "x255 y200 w25")

        ; A2
        this.GuiObj.Add("Text", "x20 y235", "Out A2:")
        this.GuiObj.SetFont("cBlack")
        this.DropdownA2 := this.GuiObj.Add("DropDownList", "x70 y230 w130", hwDevices)
        this.GuiObj.SetFont("cWhite")
        this.BtnAddTheme(" Set ", (*) => this.SetHardwareOutput(1, this.DropdownA2.Text, "A2"), "x205 y230 w45")
        this.BtnAddTheme(" X ", (*) => this.ClearHardwareOutput(1, "A2"), "x255 y230 w25")

        ; A3
        this.GuiObj.Add("Text", "x20 y265", "Out A3:")
        this.GuiObj.SetFont("cBlack")
        this.DropdownA3 := this.GuiObj.Add("DropDownList", "x70 y260 w130", hwDevices)
        this.GuiObj.SetFont("cWhite")
        this.BtnAddTheme(" Set ", (*) => this.SetHardwareOutput(2, this.DropdownA3.Text, "A3"), "x205 y260 w45")
        this.BtnAddTheme(" X ", (*) => this.ClearHardwareOutput(2, "A3"), "x255 y260 w25")

        ; Soft Reset
        this.BtnSoftReset := this.BtnAddTheme(" Soft Reset Engine (Fix Stutter) ", (*) => this.RestartEngineSoft(), "x20 y300 w360")

        ; Load Saved
        this.LoadSavedHardware(this.DropdownA1, "HardwareA1")
        this.LoadSavedHardware(this.DropdownA2, "HardwareA2")
        this.LoadSavedHardware(this.DropdownA3, "HardwareA3")

        ; ---- SECTION 3: ROUTING (Logical) (y365 start) ----
        this.GuiObj.Add("GroupBox", "x10 y365 w380 h70 cWhite", "Route Game Audio (Strip 3)")

        ; Using Text buttons, but slightly taller to match original look
        this.BtnAddTheme("Out A1", (*) => this.RouteToBus("A1"), "x20 y385 w60")
        this.BtnAddTheme("Out A2", (*) => this.RouteToBus("A2"), "x85 y385 w60")
        this.BtnAddTheme("Out A3", (*) => this.RouteToBus("A3"), "x150 y385 w60")
        this.BtnAddTheme("Mute", (*) => this.RouteToBus("NONE"), "x215 y385 w60")

        ; Hard Reset (Footer)
        this.BtnAddTheme(" Hard Reset (Relaunch VoiceMeeter App) ", (*) => this.RestartVoicemeeterApp(), "x10 y445 w380")

        this.GuiObj.Show("w400 h485")
    }

    static Destroy() {
        if (this.GuiObj) {
            this.GuiObj.Destroy()
            this.GuiObj := ""
        }
    }

    ; Helper for Flat Buttons
    static BtnAddTheme(label, callback, options) {
        btn := this.GuiObj.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; ---- HARDWARE LOGIC ----
    static SetHardwareOutput(busIndex, deviceName, label) {
        if !this.IsConnected && !this.Init()
            return

        IniWrite(deviceName, ConfigManager.IniPath, "AUDIO", "Hardware" label)
        cmd := Format('Bus[{1}].device.wdm="{2}"', busIndex, deviceName)
        this.SendScript(cmd)

        Sleep(250)
        this.RestartEngineSoft()
        Logger.Info("Audio Output " label " switched to: " deviceName)
    }

    static ClearHardwareOutput(busIndex, label) {
        if !this.IsConnected && !this.Init()
            return

        ; 1. Clear config
        IniWrite("", ConfigManager.IniPath, "AUDIO", "Hardware" label)

        ; 2. Detach device in VM
        cmd := Format('Bus[{1}].device.wdm=""', busIndex)
        this.SendScript(cmd)

        Sleep(250)
        this.RestartEngineSoft()

        DialogsGui.CustomTrayTip("Output " label " Cleared", 1)
        Logger.Info("Audio Output " label " disconnected.")
    }

    static LoadSavedHardware(dropdown, iniKey) {
        saved := IniRead(ConfigManager.IniPath, "AUDIO", iniKey, "")
        try {
            if (saved != "")
                dropdown.Choose(saved)
            else
                dropdown.Choose(1)
        } catch {
            dropdown.Choose(1)
        }
    }

    ; ---- DEVICE REFRESH LOGIC ----
    static RefreshDeviceList(updateUi := true) {
        this.DeviceListCache := []
        if IsSet(Rpcs3AudioTool)
            try this.DeviceListCache := Rpcs3AudioTool.GetAudioDevices()

        if (this.DeviceListCache.Length == 0)
            this.DeviceListCache := this.GetSystemPlaybackDevices()

        if (updateUi && this.GuiObj) {
            ; Update Emulators
            this.DropdownRpcs3.Delete()
            this.DropdownRpcs3.Add(this.DeviceListCache)
            this.DropdownRpcs3.Choose(1)
            this.DropdownDuck.Delete()
            this.DropdownDuck.Add(this.DeviceListCache)
            this.DropdownDuck.Choose(1)

            ; Filter HW list again
            hwDevices := []
            for dev in this.DeviceListCache {
                if (dev != "Default" && !InStr(dev, "Voicemeeter") && !InStr(dev, "CABLE"))
                    hwDevices.Push(dev)
            }
            if (hwDevices.Length == 0) hwDevices.Push("Speakers")
                ; Update A1, A2, A3
                this.DropdownA1.Delete()
            this.DropdownA1.Add(hwDevices)
            this.LoadSavedHardware(this.DropdownA1, "HardwareA1")

            this.DropdownA2.Delete()
            this.DropdownA2.Add(hwDevices)
            this.LoadSavedHardware(this.DropdownA2, "HardwareA2")

            this.DropdownA3.Delete()
            this.DropdownA3.Add(hwDevices)
            this.LoadSavedHardware(this.DropdownA3, "HardwareA3")

            DialogsGui.CustomTrayTip("Device List Refreshed", 1)
        }
    }

    ; ---- LOGIC HANDLERS ----
    static OnSetRpcs3() {
        if !IsSet(Rpcs3AudioTool) || this.DropdownRpcs3.Text == ""
            return
        if Rpcs3AudioTool.SetDevice(this.DropdownRpcs3.Text)
            DialogsGui.CustomTrayTip("RPCS3 Updated", 1)
    }

    static OnSetDuck() {
        if !IsSet(DuckStationAudioTool) || this.DropdownDuck.Text == ""
            return
        if DuckStationAudioTool.SetDevice(this.DropdownDuck.Text)
            DialogsGui.CustomTrayTip("DuckStation Updated", 1)
    }

    static RouteToBus(busName) {
        if !this.IsConnected && !this.Init()
            return

        this.SendScript("Strip[3].A1=0;Strip[3].A2=0;Strip[3].A3=0;")

        if (busName != "NONE") {
            this.SendScript("Strip[3]." . busName . "=1;")
            DialogsGui.CustomTrayTip("Routed to " busName, 1)
        } else {
            DialogsGui.CustomTrayTip("Audio Muted", 1)
        }
    }

    static RestartEngineSoft() {
        if !this.IsConnected && !this.Init()
            return

        if this.BtnSoftReset {
            this.BtnSoftReset.Text := "Resetting..."
            ; We cannot disable Text controls visually, so we just change the text
        }
        this.SendScript("Command.Restart=1;")
        SetTimer(() => this.FinishSoftReset(), -1500)
    }

    static FinishSoftReset() {
        if this.BtnSoftReset {
            try {
                this.BtnSoftReset.Text := " Soft Reset Engine (Fix Stutter) "
            }
        }
        SoundBeep(750, 150)
        DialogsGui.CustomTrayTip("Audio Engine Ready", 1)
    }

    static RestartVoicemeeterApp() {
        exeName := "voicemeeterpro.exe"
        if ProcessExist(exeName) {
            RunWait(A_ComSpec " /c taskkill /im " exeName " /f", , "Hide")
        }
        if FileExist(this.VmAppPath) {
            try {
                Run(this.VmAppPath)
                DialogsGui.CustomTrayTip("VoiceMeeter Restarted", 1)
                Sleep(2000)
                this.Init()
            } catch as err {
                Logger.Error("Failed to start VM: " err.Message)
            }
        }
    }

    static SendScript(cmd) {
        if this.IsConnected
            DllCall(this.VmDllPath "\VBVMR_SetParameters", "AStr", cmd, "Int")
    }

    static GetSystemPlaybackDevices() {
        devices := []
        Loop 60 {
            try {
                name := SoundGetName(A_Index)
                if (name)
                    devices.Push(name)
            }
        }
        if (devices.Length == 0)
            devices.Push("Speakers")
        return devices
    }
}