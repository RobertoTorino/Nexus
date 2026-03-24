#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Dictionary for UI Translation (EN, CN, JP, IT, ES, FR, RU).
; * @class TranslationManager
; * @location lib/config/TranslationManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include *i translations\CN.ahk
#Include *i translations\JP.ahk
#Include *i translations\IT.ahk
#Include *i translations\ES.ahk
#Include *i translations\FR.ahk
#Include *i translations\RU.ahk

class TranslationManager {
    static CurrentLang := "EN"
   static Languages := ["EN", "CN", "JP", "IT", "ES", "FR", "RU"]

    static Cycle() {
        currentIndex := 0
        for i, lang in this.Languages {
            if (lang == this.CurrentLang) {
                currentIndex := i
                break
            }
        }
        nextIndex := currentIndex + 1
        if (nextIndex > this.Languages.Length)
            nextIndex := 1
        this.CurrentLang := this.Languages[nextIndex]
        return this.CurrentLang
    }

    static GetCurrentCode() => this.CurrentLang

   static T(text) {
        ; 1. ENGLISH LOGIC
        if (this.CurrentLang == "EN") {
            ; Special Case: Long Blocks of Text or Special Keys
            if (text == "HELP_TEXT_MAIN")
                return this.GetEnglishHelp()
         if (text == "HELP_TEXT_GAMEPAD" || text == "HELP_TEXT_ControllerTester")
            return this.GetEnglishControllerTesterHelp()

            ; NEW: Handle Gallery Help Keys for English
            if (text == "GALLERY_HELP_1")
            return "Press Spacebar to start fullscreen slideshow."
            if (text == "GALLERY_HELP_2")
            return "Double click image for fullscreen."
            if (text == "GALLERY_HELP_3")
            return "Press M in fullscreen to switch monitors."
            if (text == "GALLERY_HELP_4")
            return "Press DELETE to recycle image."

            ; Otherwise, return the text as-is (e.g. "Previous", "Next")
            return text
        }

        ; 2. OTHER LANGUAGES (Dictionary Lookup)
      this.EnsureDictionary()
        clean := Trim(text)
      if (clean == "HELP_TEXT_GAMEPAD" || clean == "HELP_TEXT_ControllerTester") {
         if (this.Dictionary.Has(this.CurrentLang)) {
            langMap := this.Dictionary[this.CurrentLang]
            primaryKey := "HELP_TEXT_GAMEPAD"
            aliasKey := "HELP_TEXT_ControllerTester"
            if (langMap.Has(primaryKey))
               return langMap[primaryKey]
            if (langMap.Has(aliasKey))
               return langMap[aliasKey]
         }
         return this.GetEnglishControllerTesterHelp()
      }
        if (this.Dictionary.Has(this.CurrentLang) && this.Dictionary[this.CurrentLang].Has(clean)) {
            translation := this.Dictionary[this.CurrentLang][clean]
            return StrReplace(text, clean, translation)
        }
        return text
    }

    static GetEnglishHelp() {
        return "
        (
    1. ADDING GAME PATHS:
       - Click Set Launch Path to add the main game executable.
       - For TeknoParrot select a game profile in Profiles.

    2. EMULATORS:
       - Click Emulator to set the paths.

    3. RUNNING GAMES:
       - Selecting an .ISO/'EBOOT.BIN will ask you which emulator to use.
       - Or select a game from the list and click ▶️

    4. WHEN THE GAME IS ACTIVE:
       - Use Window Manager to manipulate the game window.
       - Use CPU buttons to fix lag/stutter.
       - Burst takes rapid screenshots (max. 99).

    5. RECORDING:
       - Record only the audio or record a video including sound.

    6. TOOLS:
       - Atrac3 Converter: Convert ATRAC3 audio format to WAV.
       - File Validator: Check MD5/SHA1 hashes of ISOs.
       - Game Search Database.

    7. HOTKEYS:
       - Escape button, exit the game.
       - Escape+1, hard reset.
       - Control+L opens live log trail.
       - F8 enables voice command catalog.
       - Ctrl+Alt+F9 in capture mode shows ffmpeg terminal.
       - Ctrl+Alt+F10 shows ffmpeg logs.
       - CTRL+SHIFT+A opens Audio Manager.

   8. QUICK LAUNCH:
       - Right click on the tray icon for quick launch.
       - Double click on the title bar to switch to text mode.

   9. MAGNETIC WINDOWS:
       - Hold Control on the Main UI to detach it.

    T. TROUBLESHOOTING:
       - To reboot a game use Restart Game.
       - Use View Logs to look for errors.
        )"
    }

      static GetEnglishControllerTesterHelp() {
            return "
            (
      AXIS EXPLANATIONS (Xbox 360 Emulation)

      X & Y: Left Thumbstick
      • X: Horizontal (0=Left, 50=Center, 100=Right)
      • Y: Vertical (0=Up, 50=Center, 100=Down)

      R: Right Thumbstick (Vertical)
      • Rests at 50, moves toward 0 or 100.

      Z: L2 / R2 Triggers
      • Both triggers share this single axis.
      • 50 = Neither pressed (or both pressed equally!)
      • 100 = Left Trigger (L2) fully pulled
      • 0 = Right Trigger (R2) fully pulled

      POV: D-Pad (Point of View Hat)
      • Shows angle in degrees x 100.
      • -1 = Nothing pressed
      • 0 = Up
      • 9000 = Right
      • 18000 = Down
      • 27000 = Left
        )"
    }

    static Dictionary := ""

    static EnsureDictionary() {
        if !IsObject(this.Dictionary)
            this.Dictionary := this.BuildDictionary()
    }

    static BuildDictionary() {
        return Map(
            "CN", TM_Lang_CN(),
            "JP", TM_Lang_JP(),
            "IT", TM_Lang_IT(),
            "ES", TM_Lang_ES(),
            "FR", TM_Lang_FR(),
            "RU", TM_Lang_RU()
        )
    }
}