#Requires AutoHotkey v2.0
; ==============================================================================
; * @description App Navigation via Controller.
; * @class ControllerManager
; * @location lib/input/ControllerManager.ahk
; * @author Philip
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class ControllerManager {
    static ActiveID := 1
    static TimerObj := ""
    static LastPress := 0
    static ExitHoldStart := 0
    static TargetHwnd := 0

    ; --- CONFIGURATION ---
    static Btn_Snap     := 9   ; Share
    static Btn_Burst    := 13  ; PS Button
    static Btn_Exit1    := 9   ; Share
    static Btn_Exit2    := 10  ; Options

    static Init(hwnd := 0) {
        this.TargetHwnd := hwnd

        ; Auto-detect controller
        Loop 8 {
            if (GetKeyState(A_Index "JoyName")) {
                this.ActiveID := A_Index
                break
            }
        }

        ; CRITICAL FIX: Only turn off if it's actually an object
        if (IsObject(this.TimerObj))
            SetTimer(this.TimerObj, 0)

        this.TimerObj := ObjBindMethod(this, "Tick")
        SetTimer(this.TimerObj, 20)
    }

    static Tick() {
        id := this.ActiveID "Joy"

        ; 1. CHECK IF GAME IS RUNNING
        gameRunning := false
        try {
            if (IsSet(ProcessManager) && ProcessManager.ActivePid > 0)
                gameRunning := true
        }

        if (!gameRunning) {
            if (WinActive("ahk_id " . this.TargetHwnd))
                this.HandleMenu(id)
            return
        }

        ; --- READ BUTTONS ---
        bExit1 := GetKeyState(id . this.Btn_Exit1) ; Share
        bExit2 := GetKeyState(id . this.Btn_Exit2) ; Options
        bBurst := GetKeyState(id . this.Btn_Burst) ; PS Button

        ; --- EXIT COMBO (Share + Options) ---
        if (bExit1 && bExit2) {
            if (this.ExitHoldStart == 0) {
                this.ExitHoldStart := A_TickCount
                SoundBeep(1000, 50)
            }

            elapsed := A_TickCount - this.ExitHoldStart

            if (elapsed < 1500) {
                ToolTip("EXITING IN: " . Round((1500 - elapsed) / 1000, 1) . "s")
            } else {
                ToolTip()
                SoundBeep(500, 500)
                ProcessManager.CloseActiveGame()
                this.ExitHoldStart := 0
                this.LastPress := A_TickCount + 3000
            }
            return
        }

        if (this.ExitHoldStart > 0) {
            ToolTip()
            this.ExitHoldStart := 0
            this.LastPress := A_TickCount + 200
        }

        ; --- SNAPSHOTS (Cooldown 500ms) ---
        if (A_TickCount - this.LastPress > 500) {
            ; Single Snapshot: Share (9) ONLY if Options (10) is NOT pressed
            if (bExit1 && !bExit2) {
                if IsSet(CaptureManager) {
                    CaptureManager.TakeSnapshot(false)
                    this.LastPress := A_TickCount
                }
            }
            ; Burst Snapshot: PS Button (13)
            else if (bBurst) {
                if IsSet(GuiBuilder) && GuiBuilder.HasMethod("OnBurstSnap") {
                    GuiBuilder.OnBurstSnap()
                    this.LastPress := A_TickCount
                }
            }
        }
    }

    ; --- MENU NAVIGATION ---
    static HandleMenu(id) {
        if (A_TickCount - this.LastPress < 150)
            return

        pov := GetKeyState(id "POV")
        if (pov != -1) {
            if (pov == 0) {
                Send("{Up}")
                this.LastPress := A_TickCount
            }
            else if (pov == 18000) {
                Send("{Down}")
                this.LastPress := A_TickCount
            }
        }

        if GetKeyState(id "2") {
            Send("{Enter}")
            this.LastPress := A_TickCount + 300
        }
    }
}