#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Handles Snapshots, Audio (WAV), and Video (MP4) recording.
; * @class CaptureManager
; * @location lib/capture/CaptureManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00 (robustness patch)

; Uses absolute ffmpeg path (no “working dir” surprises).
; Runs ffmpeg directly for audio (no cmd /k, PID is real ffmpeg.exe).
; Uses /T /F on taskkill + try/finally cleanup.
; Guards against double-start.
; Adds INI-driven Voicemeeter optional selection (AudioDeviceNormal vs AudioDeviceVoicemeeter).
; Kills active ffmpeg on script exit (prevents stuck recordings).
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\core\Logger.ahk
#Include ..\config\ConfigManager.ahk
#Include ..\window\WindowManager.ahk
#Include ..\ui\DialogsGui.ahk

class CaptureManager {
    static FfmpegPath := "core\ffmpeg.exe"
    static IsRecordingVideo := false
    static IsRecordingAudio := false
    static VideoPid := 0
    static AudioPid := 0
    static StartTimeAudio := 0
    static StartTimeVideo := 0
    static LastSaveDir := ""
    static LastFfmpegLog := ""
    static pToken := 0
    static _SessionForceVM := false

    ; Ensure cleanup on exit (prevents stuck ffmpeg)
    static __New() {
        OnExit(ObjBindMethod(this, "_OnExit"))
    }

    static _OnExit(ExitReason := "", ExitCode := 0) {
        try {
            if (this.VideoPid)
                this._KillPid(this.VideoPid)
            if (this.AudioPid)
                this._KillPid(this.AudioPid)
        } catch {
            ; don't block exit
        }
    }

    static SetSessionForceVoicemeeter(on := true) {
        this._SessionForceVM := !!on
        Logger.Info("Capture session force Voicemeeter=" (on ? "ON" : "OFF"), "CaptureManager")
    }

    static GetUseVoicemeeterForThisSession() {
        if (this._SessionForceVM)
            return true
        return this._ShouldUseVoicemeeterProfiles()
    }

    ; ---- SNAPSHOTS (Limit 99) ----
    static TakeSnapshot(isBurst := false, burstCount := 1) {
        ; 1. IDENTIFY TARGET WINDOW ROBUSTLY
        targetPid := 0
        targetHwnd := 0

        ; Priority: Active Game Session
        if (IsSet(ProcessManager) && ProcessManager.ActivePid > 0) {
            targetPid := ProcessManager.ActivePid
            targetHwnd := WinExist("ahk_pid " targetPid)
        }

        ; Fallback: Active Window (For Menu/Desktop captures)
        if (!targetHwnd) {
            targetHwnd := WinExist("A")
        }

        if (!targetHwnd) {
            Logger.Warn("CaptureManager: No window found to capture.", "CaptureManager")
            return
        }

        ; 2. SETUP GDI+
        if (this.pToken == 0)
            this.pToken := this.Gdip_Startup()

        saveDir := this.GetSaveDir("snapshots")

        ; 3. CAPTURE LOOP
        burstCount := Integer(burstCount)
        if (burstCount > 99)
            burstCount := 99

        Loop burstCount {
            this.DoCapture(targetHwnd, saveDir)

            if (burstCount > 1)
                Sleep(350) ; Delay for burst mode stability
        }

        if (!isBurst || burstCount == 1) {
            DialogsGui.CustomTrayTip("Snapshot Saved", 1)
        } else {
            DialogsGui.CustomTrayTip("Burst Capture (" burstCount ") Done", 1)
        }
    }

    static DoCapture(hwnd, saveDir) {
        ; Capture the specific window using Screen Coordinates
        pBitmap := this.CaptureWindow(hwnd)

        if (!pBitmap) {
            Logger.Error("CaptureManager: Failed to create bitmap.", "CaptureManager")
            return
        }

        ; Generate Filename
        timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss_fff")
        exeName := "Window"
        try {
            pid := WinGetPID("ahk_id " hwnd)
            exeName := ProcessGetName(pid)
            exeName := StrReplace(exeName, ".exe", "")
        }

        filename := saveDir "\" exeName "_" timestamp ".png"

        ; Collision Check
        if FileExist(filename) {
            loop {
                filename := saveDir "\" exeName "_" timestamp "_" A_Index ".png"
                if !FileExist(filename)
                    break
            }
        }

        ; Save & Cleanup
        this.Gdip_SaveBitmapToFile(pBitmap, filename)
        this.Gdip_DisposeImage(pBitmap)
        Logger.Info("Snapshot saved: " filename, "CaptureManager")
    }

    ; ---- GDI+ CORE CAPTURE LOGIC (THE MONITOR FIX) ----
    static CaptureWindow(hwnd) {
        ; Get the EXACT position of the window on the virtual screen (supports multi-monitor negative coords)
        try {
            WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        } catch {
            return 0
        }

        ; Skip invisible/minimized windows
        if (w <= 0 || h <= 0)
            return 0

        ; 1. Create a Device Context (DC) for the ENTIRE Virtual Screen (0)
        hDC_Screen := DllCall("GetDC", "ptr", 0, "ptr")

        ; 2. Create a Memory DC to hold our image
        hDC_Mem := DllCall("CreateCompatibleDC", "ptr", hDC_Screen, "ptr")

        ; 3. Create a Bitmap compatible with the Screen
        hBM := DllCall("CreateCompatibleBitmap", "ptr", hDC_Screen, "int", w, "int", h, "ptr")

        ; 4. Select the Bitmap into the Memory DC
        hOld := DllCall("SelectObject", "ptr", hDC_Mem, "ptr", hBM)

        ; 5. COPY PIXELS (BitBlt)
        DllCall("BitBlt", "ptr", hDC_Mem, "int", 0, "int", 0, "int", w, "int", h, "ptr", hDC_Screen, "int", x, "int", y, "int", 0x00CC0020)

        ; 6. Convert to GDI+ Bitmap
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBM, "ptr", 0, "ptr*", &pBitmap)

        ; 7. Cleanup GDI Objects
        DllCall("SelectObject", "ptr", hDC_Mem, "ptr", hOld)
        DllCall("DeleteObject", "ptr", hBM)
        DllCall("DeleteDC", "ptr", hDC_Mem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hDC_Screen)

        return pBitmap
    }

    ; ---- VIDEO RECORDING ----
    static ToggleVideoRecording() {
        if (this.IsRecordingVideo)
            this.StopVideo()
        else
            this.StartVideo()
    }

    static StartVideo() {
        if (this.IsRecordingVideo)
            return

        exe := this.GetFfmpegExe()
        if !FileExist(exe) {
            DialogsGui.CustomMsgBox("Error", "FFmpeg missing: " exe)
            return
        }

        useVM := this.GetUseVoicemeeterForThisSession()
        if !this._EnsureVideoAudioReady(useVM, &audioDevice) {
            this._ResetSessionOverrides()
            return
        }

        Logger.Info("Recording mode: " (useVM ? "VOICEMEETER" : "NORMAL"), "CaptureManager")
        DialogsGui.CustomTrayTip(useVM ? "Using Voicemeeter" : "Using Direct Mic", 1)

        saveDir := this.GetSaveDir("captures")
        this.LastSaveDir := saveDir
        outFile := saveDir "\Video_" FormatTime(, "yyyyMMdd_HHmmss") ".mp4"

        ; Record full virtual screen or primary? Usually A_ScreenWidth/Height is primary.
        ; For multi-monitor video, FFmpeg args need tweaking, but we stick to primary for now.
        fps := 30
        w := A_ScreenWidth
        h := A_ScreenHeight

        args := ' -f gdigrab -framerate ' fps ' -offset_x 0 -offset_y 0 -video_size ' w 'x' h ' -i desktop'
        args .= ' -f dshow -audio_buffer_size 50 -i audio="' audioDevice '"'
        args .= ' -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p'
        args .= ' -c:a aac -b:a 192k'
        args .= ' -movflags +faststart+frag_keyframe+empty_moov+default_base_moof "' outFile '"'

        pid := 0
        showMode := (IniRead(ConfigManager.IniPath, "CAPTURE", "ShowFFmpegConsole", "0") = "1") ? "" : "Hide"

        if this._RunFfmpeg(args, &pid, showMode) {
            this.VideoPid := pid
            this.IsRecordingVideo := true
            this.StartTimeVideo := A_TickCount
            DialogsGui.CustomTrayTip("Video Recording STARTED", 2)
            if IsSet(GuiBuilder)
                GuiBuilder.SetRecordingStatus(true, "Video")
        } else {
            DialogsGui.CustomMsgBox("Capture Error", "Video recording could not be started. Check audio input and FFmpeg setup.")
            this._ResetSessionOverrides()
        }
    }

    static StopVideo() {
        if (!this.VideoPid)
            return

        try {
            this._KillPid(this.VideoPid)
        } finally {
            this.VideoPid := 0
            this.IsRecordingVideo := false
            this.StartTimeVideo := 0
            this._SessionForceVM := false
            this._ResetSessionOverrides()
        }

        DialogsGui.CustomTrayTip("Video Saved", 2)
        if IsSet(GuiBuilder)
            GuiBuilder.SetRecordingStatus(false, "Video")
        if (this.LastSaveDir != "" && DirExist(this.LastSaveDir))
            Run(this.LastSaveDir)
    }

    ; ---- AUDIO RECORDING ----
    static ToggleAudioRecording() {
        if (this.IsRecordingAudio)
            this.StopAudio()
        else
            this.StartAudio()
    }

    static StartAudio() {
        if (this.IsRecordingAudio)
            return

        exe := this.GetFfmpegExe()
        if !FileExist(exe) {
            DialogsGui.CustomMsgBox("Error", "FFmpeg missing: " exe)
            return
        }

        useVM := this.GetUseVoicemeeterForThisSession()
        audioDevice := this.GetAudioDeviceName(useVM)
        if (audioDevice = "") {
            this._ResetSessionOverrides()
            return
        }

        Logger.Info("Recording mode: " (useVM ? "VOICEMEETER" : "NORMAL"), "CaptureManager")
        DialogsGui.CustomTrayTip(useVM ? "Using Voicemeeter" : "Using Direct Mic", 1)

        saveDir := this.GetSaveDir("recordings")
        this.LastSaveDir := saveDir
        outFile := saveDir "\Audio_" FormatTime(, "yyyyMMdd_HHmmss") ".wav"

        args := ' -f dshow -i audio="' audioDevice '" -acodec pcm_s16le -ar 48000 -ac 2 -y "' outFile '"'
        pid := 0
        showMode := (IniRead(ConfigManager.IniPath, "CAPTURE", "ShowFFmpegConsole", "0") = "1") ? "" : "Hide"

        if this._RunFfmpeg(args, &pid, showMode) {
            this.AudioPid := pid
            this.IsRecordingAudio := true
            this.StartTimeAudio := A_TickCount
            DialogsGui.CustomTrayTip("Audio Recording STARTED", 2)
            if IsSet(GuiBuilder)
                GuiBuilder.SetRecordingStatus(true, "Audio")
        } else {
            DialogsGui.CustomMsgBox("Capture Error", "Audio recording could not be started. Check input device and FFmpeg setup.")
            this._ResetSessionOverrides()
        }
    }

    static StopAudio() {
        if (!this.AudioPid)
            return

        try {
            this._KillPid(this.AudioPid)
        } finally {
            this.AudioPid := 0
            this.IsRecordingAudio := false
            this.StartTimeAudio := 0
            this._SessionForceVM := false
            this._ResetSessionOverrides()
        }

        DialogsGui.CustomTrayTip("Audio Saved", 2)
        if IsSet(GuiBuilder)
            GuiBuilder.SetRecordingStatus(false, "Audio")
        if (this.LastSaveDir != "" && DirExist(this.LastSaveDir))
            Run(this.LastSaveDir)
    }

    ; ---- HELPERS ----
    static GetFfmpegExe() => A_ScriptDir "\" this.FfmpegPath

    static _RunFfmpeg(args, &pid, show := "Hide") {
        exe := this.GetFfmpegExe()
        cmd := '"' exe '"' args
        Logger.Info("FFmpeg cmd: " cmd, "CaptureManager")

        try {
            Run(cmd, , show, &pid)
            if (pid <= 0) {
                Logger.Error("FFmpeg failed to start (pid<=0).", "CaptureManager")
                return false
            }
            Sleep(250)
            if !ProcessExist(pid) {
                Logger.Error("FFmpeg exited immediately after launch (pid=" pid ").", "CaptureManager")
                pid := 0
                return false
            }
            return true
        } catch as err {
            Logger.Error("FFmpeg Run error: " err.Message, "CaptureManager")
            pid := 0
            return false
        }
    }

    static _KillPid(pid) {
        if (!pid)
            return
        ; /T = kill child processes, /F = force
        try RunWait(A_ComSpec ' /c taskkill /PID ' pid ' /T /F', , "Hide")
        catch as err
            Logger.Warn("taskkill failed pid=" pid ": " err.Message, "CaptureManager")
    }

    static _ShouldUseVoicemeeterProfiles() {
        ; This flag simply selects which device name FFmpeg uses.
        ; (You can later extend it to also switch Windows defaults if you add audio profiles.)
        v := IniRead(ConfigManager.IniPath, "CAPTURE", "UseVoicemeeterProfiles", "1")
        return (v = "1")
    }

    static _RequireVoicemeeterForVideo() {
        v := IniRead(ConfigManager.IniPath, "CAPTURE", "RequireVoicemeeterForVideo", "1")
        return (v = "1")
    }

    static _IsVoicemeeterProcessRunning() {
        return !!(ProcessExist("voicemeeter.exe")
            || ProcessExist("voicemeeter8.exe")
            || ProcessExist("voicemeeterpro.exe")
            || ProcessExist("voicemeeterpro_x64.exe")
            || ProcessExist("voicemeeterbanana.exe")
            || ProcessExist("voicemeeter8x64.exe")
            || (IsSet(AudioManager) && AudioManager.IsConnected))
    }

    static _EnsureVideoAudioReady(useVM, &audioDevice) {
        audioDevice := this.GetAudioDeviceName(useVM)
        requireVM := this._RequireVoicemeeterForVideo()

        if (requireVM && !useVM) {
            DialogsGui.CustomMsgBox("Capture Blocked", "Video recording is configured to require Voicemeeter.`nEnable Voicemeeter mode or set CAPTURE.RequireVoicemeeterForVideo=0.")
            Logger.Warn("Video recording blocked: Voicemeeter required but current session is NORMAL.", "CaptureManager")
            return false
        }

        if (audioDevice = "") {
            DialogsGui.CustomMsgBox("Capture Blocked", "No audio input device configured for video recording.")
            Logger.Warn("Video recording blocked: audio input device is empty.", "CaptureManager")
            return false
        }

        if (useVM) {
            if !this._IsVoicemeeterProcessRunning() {
                DialogsGui.CustomMsgBox("Capture Blocked", "Voicemeeter mode is selected, but Voicemeeter is not running.")
                Logger.Warn("Video recording blocked: Voicemeeter mode selected but process not running.", "CaptureManager")
                return false
            }
            if !InStr(StrLower(audioDevice), "voicemeeter") {
                DialogsGui.CustomMsgBox("Capture Blocked", "Voicemeeter mode is selected, but AudioDeviceVoicemeeter is not a Voicemeeter input.")
                Logger.Warn("Video recording blocked: Voicemeeter mode selected with non-Voicemeeter device '" audioDevice "'.", "CaptureManager")
                return false
            }
        }

        return true
    }

static _ResetSessionOverrides() {
    this._SessionForceVM := false
}

    static GetAudioDeviceName(useVoicemeeter := false) {
        section := "CAPTURE"

        if (useVoicemeeter) {
            devName := IniRead(ConfigManager.IniPath, section, "AudioDeviceVoicemeeter", "")
            if (devName = "")
                devName := IniRead(ConfigManager.IniPath, section, "AudioDevice", "") ; legacy fallback

            if (devName = "") {
                devName := DialogsGui.AskForString("Audio Setup"
                    , "Enter Audio Input Device Name for FFmpeg (Voicemeeter mode):"
                    , "Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)")
                if (devName != "") {
                    IniWrite(devName, ConfigManager.IniPath, section, "AudioDeviceVoicemeeter")
                    IniWrite(devName, ConfigManager.IniPath, section, "AudioDevice") ; keep legacy in sync
                }
            }
            return devName
        }

        devName := IniRead(ConfigManager.IniPath, section, "AudioDeviceNormal", "")
        if (devName = "") {
            devName := DialogsGui.AskForString("Audio Setup"
                , "Enter Audio Input Device Name for FFmpeg (Normal mode):"
                , "Microphone (Realtek High Definition Audio)")
            if (devName != "")
                IniWrite(devName, ConfigManager.IniPath, section, "AudioDeviceNormal")
        }
        return devName
    }

    
    static GetAudioDuration() {
        if (!this.IsRecordingAudio || this.StartTimeAudio <= 0)
            return "00:00:00"
        elapsedSec := Floor((A_TickCount - this.StartTimeAudio) / 1000)
        return this._FormatDuration(elapsedSec)
    }

;       helper for the GUI – return a human‑readable elapsed time for
;       whatever is being recorded.  audio/video share the same timer,
;       so the video implementation simply delegates to the audio
;       method; this keeps the behaviour in sync and avoids repeating
;       logic.  if the recording subsystem ever splits, adjust this
;       method accordingly.

    static GetVideoDuration() {
        if (!this.IsRecordingVideo || this.StartTimeVideo <= 0)
            return "00:00:00"
        elapsedSec := Floor((A_TickCount - this.StartTimeVideo) / 1000)
        return this._FormatDuration(elapsedSec)
    }

    static _FormatDuration(totalSeconds) {
        if (totalSeconds < 0)
            totalSeconds := 0
        hh := Floor(totalSeconds / 3600)
        mm := Floor(Mod(totalSeconds, 3600) / 60)
        ss := Mod(totalSeconds, 60)
        return Format("{:02}:{:02}:{:02}", hh, mm, ss)
    }

    static GetSaveDir(subFolder) {
        gameId := "Generic"
        try {
            if (IsSet(ConfigManager) && ConfigManager.CurrentGameId != "")
                gameId := ConfigManager.CurrentGameId
        }

        target := A_ScriptDir "\media\" subFolder "\" gameId
        if !DirExist(target)
            DirCreate(target)
        return target
    }

    static Gdip_Startup() {
        if !DllCall("GetModuleHandle", "str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "str", "gdiplus")
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
        return token
    }

    static Gdip_SaveBitmapToFile(pBitmap, sOutput) {
        try {
            DirCreate(SubStr(sOutput, 1, InStr(sOutput, "\", , -1)))
            Encoder := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
            GUID := Buffer(16, 0)
            DllCall("ole32\CLSIDFromString", "wstr", Encoder, "ptr", GUID)
            DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", sOutput, "ptr", GUID, "ptr", 0)
        } catch as err {
            Logger.Error("GDI+ Save Error: " err.Message, "CaptureManager")
        }
    }

    static Gdip_DisposeImage(pBitmap) {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    }

    static OpenLastFfmpegLog() {
        if (this.LastFfmpegLog && FileExist(this.LastFfmpegLog))
            Run this.LastFfmpegLog
        else
            MsgBox "No FFmpeg logs available."
    }
}