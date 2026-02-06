#Requires AutoHotkey v2.0
; ==============================================================================
; * @description App Navigation via Controller.
; * @class ControllerManager
; * @location lib/input/ControllerManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---

class ControllerManager {
    static ActiveID := 1
    static LastPress := 0
    static RepeatDelay := 150
    static TargetHwnd := 0
    static TimerObj := ""

    ; Face Button Mappings (Standard XInput / Generic USB)
    static BindEnter := 1 ; Cross / A
    static BindBack  := 2 ; Circle / B

    static Init(hwnd := 0) {
        this.TargetHwnd := hwnd

        ; Stop existing timer if re-initializing
        if (this.TimerObj)
            SetTimer(this.TimerObj, 0)

        ; Bind method correctly to preserve 'this' context
        this.TimerObj := ObjBindMethod(this, "HandleControllerInput")
        SetTimer(this.TimerObj, 50)
    }

    static HandleControllerInput() {
        ; 1. Focus Check (Zero Impact if app is in background)
        if (this.TargetHwnd != 0) {
            if !WinActive("ahk_id " this.TargetHwnd) && !WinActive("NexusGameListPopup")
                return
        }

        ; 2. Input Throttling
        if (A_TickCount - this.LastPress < this.RepeatDelay)
            return

        ; 3. Read Controller
        ; If no controller connected, GetKeyState returns 0 immediately, minimal impact.
        idPrefix := this.ActiveID "Joy"
        pov := GetKeyState(idPrefix "POV")

        action := ""

        ; Navigation (D-Pad)
        if (pov == 0)
            action := "{Up}"
        else if (pov == 18000)
            action := "{Down}"
        else if (pov == 27000)
            action := "{Left}"
        else if (pov == 9000)
            action := "{Right}"
        ; Action Buttons
        else if GetKeyState(idPrefix . this.BindEnter)
            action := "{Enter}", this.RepeatDelay := 400 ; Longer delay for confirm
        else if GetKeyState(idPrefix . this.BindBack)
            action := "{Esc}", this.RepeatDelay := 400

        ; Execute
        if (action != "") {
            Send(action)
            this.LastPress := A_TickCount
        } else {
            ; Reset delay to fast scroll when button released
            this.RepeatDelay := 150
        }
    }
}