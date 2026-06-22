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
#Include ..\config\TranslationManager.ahk
#Include ..\core\JSON.ahk
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
    static DropdownCaptureBackend := ""
    static BtnSoftReset := ""
    static TxtCaptureStatus := ""

    static HelperPinnedVersion := "v2.0.0"
    static HelperPinnedUrl := "https://github.com/huxinhai/audio-capture/releases/download/v2.0.0/audio_capture-windows-x64.exe"
    static FfmpegReleaseVerUrl := "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z.ver"
    static FfmpegReleaseDownloadUrl := "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-full.7z"
    static NexusReleasesUrl := "https://github.com/RobertoTorino/Nexus/releases"

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
        this.GuiObj := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus :: " this.T("Sound Manager"))
        this.GuiObj.BackColor := "2A2A2A"
        this.GuiObj.SetFont("s9 cWhite", "Segoe UI")

        ; ---- CUSTOM TITLE BAR ----
        this.GuiObj.Add("Text", "x0 y0 w340 h30 +0x200 Background2A2A2A", "   Nexus :: " this.T("Sound Manager"))
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.GuiObj.Hwnd)) ; Drag

        this.BtnAddTheme(" ? ", (*) => this.ShowHelp(), "x+0 yp w30 h30 -Border")

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
        this.GuiObj.Add("GroupBox", "x10 y40 w380 h130 cWhite", this.T("Emulator Audio Config"))

        this.GuiObj.Add("Text", "x20 y65", "RPCS3:")

        this.GuiObj.SetFont("cBlack") ; Switch for Dropdown
        this.DropdownRpcs3 := this.GuiObj.Add("DropDownList", "x70 y60 w150 Choose1", allDevices)
        this.GuiObj.SetFont("cWhite") ; Switch back

        this.BtnAddTheme(this.T("Save"), (*) => this.OnSetRpcs3(), "x225 y60 w55")

        this.BtnAddTheme(this.T("Refresh Device List ↻"), (*) => this.RefreshDeviceList(true), "x20 y90 w260")

        this.GuiObj.Add("Text", "x20 y120", "DuckSt:")

        this.GuiObj.SetFont("cBlack")
        this.DropdownDuck := this.GuiObj.Add("DropDownList", "x70 y115 w150 Choose1", allDevices)
        this.GuiObj.SetFont("cWhite")

        this.BtnAddTheme(this.T("Save"), (*) => this.OnSetDuck(), "x225 y115 w55")

        ; ---- SECTION 2: HARDWARE OUTPUT MAPPING (y180 start) ----
        this.GuiObj.Add("GroupBox", "x10 y180 w380 h175 cWhite", this.T("Hardware Output Mapping"))

        ; A1 (Master)
        this.GuiObj.Add("Text", "x20 y205", "Out A1:")
        this.GuiObj.SetFont("cBlack")
        this.DropdownA1 := this.GuiObj.Add("DropDownList", "x70 y200 w130", hwDevices)
        this.GuiObj.SetFont("cWhite")
        this.BtnAddTheme(this.T("Save"), (*) => this.SetHardwareOutput(0, this.DropdownA1.Text, "A1"), "x205 y200 w45")
        this.BtnAddTheme(this.T("Clear"), (*) => this.ClearHardwareOutput(0, "A1"), "x255 y200 w25")

        ; A2
        this.GuiObj.Add("Text", "x20 y235", "Out A2:")
        this.GuiObj.SetFont("cBlack")
        this.DropdownA2 := this.GuiObj.Add("DropDownList", "x70 y230 w130", hwDevices)
        this.GuiObj.SetFont("cWhite")
        this.BtnAddTheme(this.T("Save"), (*) => this.SetHardwareOutput(1, this.DropdownA2.Text, "A2"), "x205 y230 w45")
        this.BtnAddTheme(this.T("Clear"), (*) => this.ClearHardwareOutput(1, "A2"), "x255 y230 w25")

        ; A3
        this.GuiObj.Add("Text", "x20 y265", "Out A3:")
        this.GuiObj.SetFont("cBlack")
        this.DropdownA3 := this.GuiObj.Add("DropDownList", "x70 y260 w130", hwDevices)
        this.GuiObj.SetFont("cWhite")
        this.BtnAddTheme(this.T("Save"), (*) => this.SetHardwareOutput(2, this.DropdownA3.Text, "A3"), "x205 y260 w45")
        this.BtnAddTheme(this.T("Clear"), (*) => this.ClearHardwareOutput(2, "A3"), "x255 y260 w25")

        ; Soft Reset
        this.BtnSoftReset := this.BtnAddTheme(this.T("Soft Reset Engine (Fix Stutter)"), (*) => this.RestartEngineSoft(), "x20 y300 w360")

        ; Load Saved
        this.LoadSavedHardware(this.DropdownA1, "HardwareA1")
        this.LoadSavedHardware(this.DropdownA2, "HardwareA2")
        this.LoadSavedHardware(this.DropdownA3, "HardwareA3")

        ; ---- SECTION 3: ROUTING (Logical) (y365 start) ----
        this.GuiObj.Add("GroupBox", "x10 y365 w380 h70 cWhite", this.T("Route Game Audio (Strip 3)"))

        ; Using Text buttons, but slightly taller to match original look
        this.BtnAddTheme(this.T("Out A1"), (*) => this.RouteToBus("A1"), "x20 y385 w60")
        this.BtnAddTheme(this.T("Out A2"), (*) => this.RouteToBus("A2"), "x85 y385 w60")
        this.BtnAddTheme(this.T("Out A3"), (*) => this.RouteToBus("A3"), "x150 y385 w60")
        this.BtnAddTheme(this.T("Mute"), (*) => this.RouteToBus("NONE"), "x215 y385 w60")

        ; Hard Reset (Footer)
        this.BtnAddTheme(this.T("Hard Reset (Relaunch VoiceMeeter App)"), (*) => this.RestartVoicemeeterApp(), "x10 y445 w380")

        ; ---- SECTION 4: CAPTURE BACKEND (y480 start) ----
        this.GuiObj.Add("GroupBox", "x10 y480 w380 h155 cWhite", this.T("Capture Backend"))

        this.GuiObj.Add("Text", "x20 y505", this.T("Backend:"))
        this.GuiObj.SetFont("cBlack")
        this.DropdownCaptureBackend := this.GuiObj.Add("DropDownList", "x95 y500 w120", ["auto", "loopback", "dshow", "voicemeeter"])
        this.GuiObj.SetFont("cWhite")
        this.LoadCaptureBackendDropdown()

        this.BtnAddTheme(this.T("Save"), (*) => this.SaveCaptureBackend(), "x225 y500 w55")
        this.BtnAddTheme(this.T("Install Loopback Helper"), (*) => this.InstallLoopbackHelper(true), "x20 y530 w175")
        this.BtnAddTheme(this.T("Test Loopback 3s"), (*) => this.TestLoopbackCapture3s(), "x205 y530 w175")

        this.TxtCaptureStatus := this.GuiObj.Add("Text", "x20 y562 w360 h58 cSilver Background2A2A2A", this.T("Status: Ready"))

        this.GuiObj.Show("w400 h640")
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

    static T(key) {
        return TranslationManager.T(key)
    }

    ; ---- CAPTURE BACKEND UI ----
    static LoadCaptureBackendDropdown() {
        if !IsObject(this.DropdownCaptureBackend)
            return

        backend := this.NormalizeCaptureBackend(IniRead(ConfigManager.IniPath, "CAPTURE", "AudioBackend", "auto"))
        try this.DropdownCaptureBackend.Choose(backend)
    }

    static NormalizeCaptureBackend(raw) {
        v := StrLower(Trim(raw))
        if (v = "loopback" || v = "helper" || v = "audiocapture" || v = "audio-capture")
            return "loopback"
        if (v = "dshow" || v = "normal")
            return "dshow"
        if (v = "voicemeeter")
            return "voicemeeter"
        return "auto"
    }

    static SaveCaptureBackend() {
        if !IsObject(this.DropdownCaptureBackend)
            return

        backend := this.NormalizeCaptureBackend(this.DropdownCaptureBackend.Text)
        IniWrite(backend, ConfigManager.IniPath, "CAPTURE", "AudioBackend")

        if (backend = "voicemeeter")
            IniWrite("1", ConfigManager.IniPath, "CAPTURE", "UseVoicemeeterProfiles")
        else if (backend = "loopback")
            IniWrite("0", ConfigManager.IniPath, "CAPTURE", "UseVoicemeeterProfiles")

        this.SetCaptureStatus(this.T("Saved backend:") " " backend, "05FBE4")
        DialogsGui.CustomTrayTip(this.T("Capture backend saved:") " " backend, 1)
    }

    static SetCaptureStatus(msg, color := "Silver") {
        if IsObject(this.TxtCaptureStatus) {
            try this.TxtCaptureStatus.SetFont("c" color)
            this.TxtCaptureStatus.Text := this.T("Status:") " " msg
        }
    }

    static InstallLoopbackHelper(showToast := true) {
        dst := A_ScriptDir "\core\audio_capture.exe"
        tmp := A_Temp "\nexus_audio_capture.exe"

        try {
            Download(this.HelperPinnedUrl, tmp)
            DirCreate(A_ScriptDir "\core")
            FileMove(tmp, dst, 1)
            IniWrite(this.HelperPinnedVersion, ConfigManager.IniPath, "CAPTURE", "LoopbackHelperPinnedVersion")
            this.SetCaptureStatus(this.T("Loopback helper installed") " (" this.HelperPinnedVersion ")", "05FBE4")
            if (showToast)
                DialogsGui.CustomTrayTip(this.T("Loopback helper installed"), 1)
            return true
        } catch as err {
            this.SetCaptureStatus(this.T("Loopback install failed"), "FF6666")
            Logger.Warn("Loopback helper install failed: " err.Message, "AudioManager")
            if (showToast)
                DialogsGui.CustomMsgBox(this.T("Install Error"), this.T("Could not install loopback helper.") "`n" err.Message)
            try {
                if FileExist(tmp)
                    FileDelete(tmp)
            }
            return false
        }
    }

    static TestLoopbackCapture3s() {
        helperExe := A_ScriptDir "\core\audio_capture.exe"
        ffmpegExe := A_ScriptDir "\core\ffmpeg.exe"

        if !FileExist(ffmpegExe) {
            this.SetCaptureStatus(this.T("FFmpeg missing"), "FF6666")
            DialogsGui.CustomMsgBox(this.T("Capture Test"), this.T("FFmpeg missing:") " " ffmpegExe)
            return
        }

        if !FileExist(helperExe) {
            if !this.InstallLoopbackHelper(false) {
                this.SetCaptureStatus(this.T("Loopback helper missing"), "FF6666")
                DialogsGui.CustomMsgBox(this.T("Capture Test"), this.T("Loopback helper is missing and could not be installed."))
                return
            }
        }

        outDir := A_ScriptDir "\media\recordings\Generic"
        if !DirExist(outDir)
            DirCreate(outDir)

        outFile := outDir "\LoopbackTest_" FormatTime(, "yyyyMMdd_HHmmss") ".wav"

        inner := '"' helperExe '" --sample-rate 48000 --channels 2 --bit-depth 16 2>nul'
        inner .= ' | "' ffmpegExe '" -f s16le -ar 48000 -ac 2 -i pipe:0 -t 3 -acodec pcm_s16le -ar 48000 -ac 2 -y "' outFile '"'
        cmd := A_ComSpec ' /d /c "' inner '"'

        this.SetCaptureStatus(this.T("Running 3s loopback test..."), "E6C200")
        try RunWait(cmd, , "Hide")

        if (FileExist(outFile) && FileGetSize(outFile) > 1024) {
            this.SetCaptureStatus(this.T("Loopback test saved:") " " outFile, "05FBE4")
            DialogsGui.CustomTrayTip(this.T("Loopback test capture saved"), 1)
            return
        }

        this.SetCaptureStatus(this.T("Loopback test failed"), "FF6666")
        DialogsGui.CustomMsgBox(this.T("Capture Test"), this.T("Loopback test failed. No valid output file was generated."))
    }

    static CheckCaptureToolUpdates() {
        localHelper := IniRead(ConfigManager.IniPath, "CAPTURE", "LoopbackHelperPinnedVersion", this.HelperPinnedVersion)
        localFfmpeg := this.GetLocalFfmpegVersion()
        localNexus := this.GetLocalNexusVersion()

        latestHelperTag := this.GetGitHubLatestTag("huxinhai/audio-capture")
        latestFfmpeg := this.GetRemoteTextVersion(this.FfmpegReleaseVerUrl)
        stableNexus := this.GetGitHubLatestReleaseByChannel("RobertoTorino/Nexus", ".zip", "stable")
        nightlyNexus := this.GetGitHubLatestReleaseByChannel("RobertoTorino/Nexus", ".zip", "nightly")
        latestNexus := (stableNexus["tag"] != "") ? stableNexus : nightlyNexus
        latestNexusTag := latestNexus["tag"]
        latestNexusAsset := latestNexus["asset"]
        latestNexusPage := latestNexus["page"] != "" ? latestNexus["page"] : this.NexusReleasesUrl
        stableNexusLabel := stableNexus["tag"] != "" ? stableNexus["tag"] : this.T("None")
        nightlyNexusLabel := nightlyNexus["tag"] != "" ? nightlyNexus["tag"] : this.T("None")
        selectedChannel := stableNexus["tag"] != "" ? this.T("Stable") : (nightlyNexus["tag"] != "" ? this.T("Nightly") : this.T("None"))
        selectedRelease := latestNexusTag != "" ? selectedChannel " (" latestNexusTag ")" : this.T("None")

        helperUpdate := (latestHelperTag != "" && latestHelperTag != localHelper)
        ffmpegUpdate := (latestFfmpeg != "" && !InStr(localFfmpeg, latestFfmpeg))
        nexusUpdate := (latestNexusTag != "" && !InStr(latestNexusTag, localNexus) && !InStr(localNexus, latestNexusTag))
        updateCount := (helperUpdate ? 1 : 0) + (ffmpegUpdate ? 1 : 0) + (nexusUpdate ? 1 : 0)

        report := this.T("Helper local") ": " localHelper " | " this.T("Latest") ": " (latestHelperTag != "" ? latestHelperTag : this.T("None")) "`n"
        report .= this.T("FFmpeg local") ": " localFfmpeg " | " this.T("Latest") ": " (latestFfmpeg != "" ? latestFfmpeg : this.T("None")) "`n"
        report .= this.T("Nexus local") ": " localNexus "`n"
        report .= this.T("Stable") ": " stableNexusLabel "`n"
        report .= this.T("Nightly") ": " nightlyNexusLabel "`n"
        report .= this.T("Selected release") ": " selectedRelease

        this.SetCaptureStatus(this.T("Update check finished"), "05FBE4")

        if (helperUpdate || ffmpegUpdate || nexusUpdate) {
            actions := []
            if (updateCount > 1)
                actions.Push(this.T("Apply All Updates"))
            if (helperUpdate)
                actions.Push(this.T("Install Helper"))
            if (ffmpegUpdate)
                actions.Push(this.T("Download FFmpeg"))
            if (nexusUpdate)
                actions.Push(this.T("Download Nexus"))
            actions.Push(this.T("Skip"))

            choice := DialogsGui.AskForChoice("Nexus :: " this.T("Update Decision"), report, actions)
            if (choice = "" || choice = this.T("Skip"))
                return

            if (choice = this.T("Apply All Updates")) {
                if (helperUpdate)
                    this.InstallLoopbackHelper(true)
                if (ffmpegUpdate)
                    Run(this.FfmpegReleaseDownloadUrl)
                if (nexusUpdate)
                    Run(latestNexusAsset != "" ? latestNexusAsset : latestNexusPage)
                return
            }

            if (choice = this.T("Install Helper")) {
                this.InstallLoopbackHelper(true)
                return
            }

            if (choice = this.T("Download FFmpeg")) {
                Run(this.FfmpegReleaseDownloadUrl)
                return
            }

            if (choice = this.T("Download Nexus")) {
                Run(latestNexusAsset != "" ? latestNexusAsset : latestNexusPage)
                return
            }
        } else {
            DialogsGui.CustomMsgBox("Nexus :: " this.T("Update Decision"), report)
        }
    }

    ; ---- UPDATE HELPERS ----
    static GetLocalNexusVersion() {
        path := A_ScriptDir "\Nexus.ahk"
        if !FileExist(path)
            return "unknown"
        try txt := FileRead(path)
        catch
            return "unknown"
        if RegExMatch(txt, "@version\s+([0-9.]+)", &m)
            return m[1]
        return "unknown"
    }

    static GetLocalFfmpegVersion() {
        ffmpeg := A_ScriptDir "\core\ffmpeg.exe"
        if !FileExist(ffmpeg)
            return "missing"
        try {
            sh := ComObject("WScript.Shell")
            exec := sh.Exec('"' ffmpeg '" -version')
            out := exec.StdOut.ReadAll()
            first := Trim(StrSplit(out, "`n", "`r")[1])
            if RegExMatch(first, "i)ffmpeg version\s+([^\s]+)", &m)
                return m[1]
            return first
        } catch {
            return "unknown"
        }
    }

    static GetRemoteTextVersion(url) {
        tmp := A_Temp "\nexus_remote_version.txt"
        try {
            Download(url, tmp)
            v := Trim(FileRead(tmp))
            try {
                if FileExist(tmp)
                    FileDelete(tmp)
            }
            return v
        } catch {
            try {
                if FileExist(tmp)
                    FileDelete(tmp)
            }
            return ""
        }
    }

    static _HttpGet(url) {
        try {
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.Open("GET", url, false)
            req.SetRequestHeader("User-Agent", "Nexus-AHK")
            req.Send()
            if (req.Status != 200)
                return ""
            return req.ResponseText
        } catch {
            return ""
        }
    }

    static GetGitHubLatestTag(repo) {
        json := this._HttpGet("https://api.github.com/repos/" repo "/releases/latest")
        if (json = "")
            return ""
        if RegExMatch(json, '"tag_name"\s*:\s*"([^"]+)"', &m)
            return m[1]
        return ""
    }

    static GetGitHubLatestAssetUrl(repo, fileHint := "") {
        json := this._HttpGet("https://api.github.com/repos/" repo "/releases/latest")
        if (json = "")
            return ""

        firstUrl := ""
        pos := 1
        while RegExMatch(json, '"browser_download_url"\s*:\s*"([^"]+)"', &m, pos) {
            url := StrReplace(m[1], "\\/", "/")
            if (firstUrl = "")
                firstUrl := url
            if (fileHint = "" || InStr(StrLower(url), StrLower(fileHint)))
                return url
            pos := m.Pos(0) + m.Len(0)
        }
        return firstUrl
    }

    static GetGitHubPreferredRelease(repo, fileHint := "") {
        json := this._HttpGet("https://api.github.com/repos/" repo "/releases")
        empty := Map("tag", "", "asset", "", "page", "", "name", "", "prerelease", false)
        if (json = "")
            return empty

        try releases := JSON.parse(json)
        catch
            return empty

        fallback := ""
        preferred := ""
        for _, release in releases {
            if (release.Has("draft") && release["draft"])
                continue
            if !IsObject(fallback)
                fallback := release
            if !(release.Has("prerelease") && release["prerelease"]) {
                preferred := release
                break
            }
        }

        chosen := IsObject(preferred) ? preferred : fallback
        if !IsObject(chosen)
            return empty

        assetUrl := ""
        if (chosen.Has("assets") && Type(chosen["assets"]) = "Array") {
            for _, asset in chosen["assets"] {
                if !asset.Has("browser_download_url")
                    continue
                url := StrReplace(asset["browser_download_url"], "\\/", "/")
                if (assetUrl = "")
                    assetUrl := url
                if (fileHint = "" || InStr(StrLower(url), StrLower(fileHint))) {
                    assetUrl := url
                    break
                }
            }
        }

        return Map(
            "tag", chosen.Has("tag_name") ? chosen["tag_name"] : "",
            "asset", assetUrl,
            "page", chosen.Has("html_url") ? chosen["html_url"] : "",
            "name", chosen.Has("name") ? chosen["name"] : "",
            "prerelease", chosen.Has("prerelease") ? !!chosen["prerelease"] : false
        )
    }

    static GetGitHubLatestReleaseByChannel(repo, fileHint := "", channel := "stable") {
        json := this._HttpGet("https://api.github.com/repos/" repo "/releases")
        empty := Map("tag", "", "asset", "", "page", "", "name", "", "prerelease", false)
        if (json = "")
            return empty

        try releases := JSON.parse(json)
        catch
            return empty

        for _, release in releases {
            if (release.Has("draft") && release["draft"])
                continue

            isPrerelease := release.Has("prerelease") && release["prerelease"]
            if (channel = "stable" && isPrerelease)
                continue
            if (channel = "nightly" && !isPrerelease)
                continue

            return this.BuildGitHubReleaseInfo(release, fileHint)
        }

        return empty
    }

    static BuildGitHubReleaseInfo(release, fileHint := "") {
        assetUrl := ""
        if (release.Has("assets") && Type(release["assets"]) = "Array") {
            for _, asset in release["assets"] {
                if !asset.Has("browser_download_url")
                    continue
                url := StrReplace(asset["browser_download_url"], "\\/", "/")
                if (assetUrl = "")
                    assetUrl := url
                if (fileHint = "" || InStr(StrLower(url), StrLower(fileHint))) {
                    assetUrl := url
                    break
                }
            }
        }

        return Map(
            "tag", release.Has("tag_name") ? release["tag_name"] : "",
            "asset", assetUrl,
            "page", release.Has("html_url") ? release["html_url"] : "",
            "name", release.Has("name") ? release["name"] : "",
            "prerelease", release.Has("prerelease") ? !!release["prerelease"] : false
        )
    }

    static ShowHelp() {
        DialogsGui.ShowTextViewer("Nexus :: " this.T("Sound Manager"), this.T("HELP_TEXT_SOUND_MANAGER"), 620, 520)
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