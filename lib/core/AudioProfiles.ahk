#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Audio profiles
; * @class AudioProfiles
; * @location lib/core/AudioProfiles.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include Logger.ahk

class AudioProfiles {
    static SvvExe := "core\SoundVolumeView.exe"
    static NormalProfile := "core\audio_normal.vol"
    static RecordingProfile := "core\audio_voicemeeter.vol"

    static _Load(profilePath, label) {
        exe := A_ScriptDir "\" this.SvvExe
        prof := A_ScriptDir "\" profilePath

        if !FileExist(exe) {
            Logger.Error("SoundVolumeView missing: " exe, "AudioProfiles")
            return false
        }
        if !FileExist(prof) {
            Logger.Error("Audio profile missing: " prof, "AudioProfiles")
            return false
        }

        try {
            RunWait('"' exe '" /LoadProfile "' prof '"', , "Hide")
            Logger.Info("Loaded audio profile: " label, "AudioProfiles")
            return true
        } catch as err {
            Logger.Error("LoadProfile failed (" label "): " err.Message, "AudioProfiles")
            return false
        }
    }

    static ApplyNormal()    => this._Load(this.NormalProfile, "NORMAL")
    static ApplyRecording() => this._Load(this.RecordingProfile, "RECORDING (VOICEMEETER)")
}
