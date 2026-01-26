#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Handles Snapshots, Audio (WAV), and Video (MP4) recording.
; * @class CaptureManager
; * @location lib/capture/CaptureManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
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
    static CurrentProcessName := ""
    static pToken := 0

    ; ---- SNAPSHOTS (Limit 99) ----
    static TakeSnapshot(isBurst := false, burstCount := 1) {
        ; Force Integer type to avoid string loop issues
        burstCount := Integer(burstCount)
        if (burstCount > 99)
            burstCount := 99

        hwnd := WindowManager.GetValidHwnd()
        if !hwnd
            hwnd := WinExist("A")

        if !hwnd {
            DialogsGui.CustomTrayTip("No window to capture", 2)
            return
        }

        saveDir := this.GetSaveDir("snapshots")

        if (this.pToken == 0)
            this.pToken := this.Gdip_Startup()

        Loop burstCount {
            this.DoCapture(hwnd, saveDir)

            ; INCREASED DELAY: Games need time to handle the 'PrintWindow' message
            ; 150ms was too fast, causing 60% of requests to be dropped.
            if (burstCount > 1)
                Sleep(350)
        }

        if (!isBurst || burstCount == 1) {
            DialogsGui.CustomTrayTip("Snapshot Saved", 1)
            if DirExist(saveDir)
                Run(saveDir)
        } else {
            DialogsGui.CustomTrayTip("Burst Capture (" burstCount ") Done", 1)
        }
    }

    static DoCapture(hwnd, saveDir) {
        pBitmap := this.CaptureWindow(hwnd)
        if !pBitmap
            return

        timestamp := FormatTime(, "yyyy-MM-dd_HH-mm-ss_fff")

        exeName := "Window"
        try {
            pid := WinGetPID("ahk_id " hwnd)
            exeName := ProcessGetName(pid)
            exeName := StrReplace(exeName, ".exe", "")
        }

        filename := saveDir "\" exeName "_" timestamp ".png"

        ; ---- COLLISION PROTECTION ----
        ; If file exists (rare with ms, but possible), append a counter
        if FileExist(filename) {
            loop {
                filename := saveDir "\" exeName "_" timestamp "_" A_Index ".png"
                if !FileExist(filename)
                    break
            }
        }

        this.Gdip_SaveBitmapToFile(pBitmap, filename)
        this.Gdip_DisposeImage(pBitmap)
    }

    ; ---- VIDEO RECORDING ----
    static ToggleVideoRecording() {
        if (this.IsRecordingVideo)
            this.StopVideo()
        else
            this.StartVideo()
    }

    static StartVideo() {
        if !FileExist(this.FfmpegPath) {
            DialogsGui.CustomMsgBox("Error", "FFmpeg missing: " this.FfmpegPath)
            return
        }

        audioDevice := this.GetAudioDeviceName()
        if (audioDevice == "")
            return

        saveDir := this.GetSaveDir("captures")
        this.LastSaveDir := saveDir
        outFile := saveDir "\Video_" FormatTime(, "yyyyMMdd_HHmmss") ".mp4"

        fps := 30
        w := A_ScreenWidth
        h := A_ScreenHeight

        args := ' -f gdigrab -framerate ' fps ' -offset_x 0 -offset_y 0 -video_size ' w 'x' h ' -i desktop'
        args .= ' -f dshow -audio_buffer_size 50 -i audio="' audioDevice '"'
        args .= ' -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p'
        args .= ' -c:a aac -b:a 192k'
        args .= ' -movflags +faststart "' outFile '"'

        Logger.Info("Starting Video Rec: " args)

        try {
            Run(this.FfmpegPath . args, , "Min", &pid)
            if (pid > 0) {
                this.VideoPid := pid
                this.IsRecordingVideo := true
                this.StartTimeVideo := A_TickCount
                DialogsGui.CustomTrayTip("Video Recording STARTED", 2)
                if IsSet(GuiBuilder)
                    GuiBuilder.SetRecordingStatus(true, "Video")
            }
        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Failed to start recording.`nCheck logs.")
            Logger.Error("FFmpeg Error: " err.Message)
        }
    }

    static StopVideo() {
        if (this.VideoPid) {
            RunWait(A_ComSpec " /c taskkill /PID " this.VideoPid, , "Hide")
            this.VideoPid := 0
            this.IsRecordingVideo := false
            DialogsGui.CustomTrayTip("Video Saved", 2)

            if IsSet(GuiBuilder)
                GuiBuilder.SetRecordingStatus(false, "Video")

            if (this.LastSaveDir != "" && DirExist(this.LastSaveDir))
                Run(this.LastSaveDir)
        }
    }

    ; ----AUDIO RECORDING ----
    static ToggleAudioRecording() {
        if (this.IsRecordingAudio)
            this.StopAudio()
        else
            this.StartAudio()
    }

    static StartAudio() {
        if !FileExist(this.FfmpegPath) {
            DialogsGui.CustomMsgBox("Error", "FFmpeg missing.")
            return
        }

        audioDevice := this.GetAudioDeviceName()
        if (audioDevice == "")
            return

        saveDir := this.GetSaveDir("recordings")
        this.LastSaveDir := saveDir
        outFile := saveDir "\Audio_" FormatTime(, "yyyyMMdd_HHmmss") ".wav"

        args := ' -f dshow -i audio="' audioDevice '" -acodec pcm_s16le -ar 48000 -ac 2 -y "' outFile '"'

        Logger.Info("Starting Audio Rec: " args)

        try {
            Run(A_ComSpec ' /k ""' this.FfmpegPath '" ' args '"', , "Min", &pid)
            if (pid > 0) {
                this.AudioPid := pid
                this.IsRecordingAudio := true
                this.StartTimeAudio := A_TickCount
                DialogsGui.CustomTrayTip("Audio Recording STARTED", 2)
                if IsSet(GuiBuilder)
                    GuiBuilder.SetRecordingStatus(true, "Audio")
            }
        } catch as err {
            Logger.Error("FFmpeg Audio Error: " err.Message)
        }
    }

    static StopAudio() {
        if (this.AudioPid) {
            RunWait(A_ComSpec " /c taskkill /PID " this.AudioPid, , "Hide")
            this.AudioPid := 0
            this.IsRecordingAudio := false
            DialogsGui.CustomTrayTip("Audio Saved", 2)
            if IsSet(GuiBuilder)
                GuiBuilder.SetRecordingStatus(false, "Audio")
            if (this.LastSaveDir != "" && DirExist(this.LastSaveDir))
                Run(this.LastSaveDir)
        }
    }

    ; ---- HELPERS ----
    static GetAudioDeviceName() {
        devName := IniRead(ConfigManager.IniPath, "CAPTURE", "AudioDevice", "")
        if (devName == "") {
            devName := DialogsGui.AskForString("Audio Setup", "Enter Audio Input Device Name for FFmpeg:`n(e.g., Microphone, Stereo Mix, or Voicemeeter Out B1)", "Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)")
            if (devName != "")
                IniWrite(devName, ConfigManager.IniPath, "CAPTURE", "AudioDevice")
        }
        return devName
    }

    static GetSaveDir(subFolder) {
        game := ConfigManager.GetCurrentGame()
        folderName := "Generic"
        if (game != "" && game.HasOwnProp("SavedName"))
            folderName := game.SavedName
        else if (ConfigManager.CurrentGameId != "")
            folderName := ConfigManager.CurrentGameId

        target := A_ScriptDir "\" subFolder "\" folderName
        if !DirExist(target)
            DirCreate(target)
        return target
    }

    static GetDuration(type) {
        start := (type == "Audio") ? this.StartTimeAudio : this.StartTimeVideo
        if (start == 0)
            return "00:00:00"
        elapsed := (A_TickCount - start) // 1000
        return Format("{:02}:{:02}:{:02}", elapsed // 3600, Mod(elapsed, 3600) // 60, Mod(elapsed, 60))
    }

    ; ---- GDI+ HELPERS ----
    static Gdip_Startup() {
        if !DllCall("GetModuleHandle", "str", "gdiplus", "Ptr")
            DllCall("LoadLibrary", "str", "gdiplus")
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token, "ptr", si, "ptr", 0)
        return token
    }

    static CaptureWindow(hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w <= 0 || h <= 0)
            return 0
        hDC := DllCall("GetDC", "ptr", 0, "ptr")
        hBM := DllCall("CreateCompatibleBitmap", "ptr", hDC, "int", w, "int", h, "ptr")
        hMDC := DllCall("CreateCompatibleDC", "ptr", hDC, "ptr")
        hOld := DllCall("SelectObject", "ptr", hMDC, "ptr", hBM)

        ; Try PrintWindow first (better for background windows)
        res := DllCall("PrintWindow", "ptr", hwnd, "ptr", hMDC, "uint", 2)

        ; If PrintWindow fails (common in games), fallback to BitBlt (Screen scrape)
        if (!res) {
            hSrcDC := DllCall("GetDC", "ptr", hwnd, "ptr")
            DllCall("BitBlt", "ptr", hMDC, "int", 0, "int", 0, "int", w, "int", h, "ptr", hSrcDC, "int", 0, "int", 0, "int", 0x00CC0020)
            DllCall("ReleaseDC", "ptr", hwnd, "ptr", hSrcDC)
        }

        DllCall("SelectObject", "ptr", hMDC, "ptr", hOld)
        DllCall("DeleteDC", "ptr", hMDC)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)
        pBitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBM, "ptr", 0, "ptr*", &pBitmap)
        DllCall("DeleteObject", "ptr", hBM)
        return pBitmap
    }

    static Gdip_SaveBitmapToFile(pBitmap, sOutput) {
        DirCreate(SubStr(sOutput, 1, InStr(sOutput, "\", , -1)))
        Encoder := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
        GUID := Buffer(16, 0)
        DllCall("ole32\CLSIDFromString", "wstr", Encoder, "ptr", GUID)
        DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", sOutput, "ptr", GUID, "ptr", 0)
    }

    static Gdip_DisposeImage(pBitmap) {
        DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    }
}