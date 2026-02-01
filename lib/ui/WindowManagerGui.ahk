#Requires AutoHotkey v2.0
; ======================================================================
; * @description Complete V1-Style Window Manager (Unfiltered Debug Mode)
; * @class WindowManagerGui
; * @location lib/ui/WindowManagerGui.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ======================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\window\WindowManager.ahk
#Include ..\ui\DialogsGui.ahk

class WindowManagerGui {
    static WinGui := ""
    static ListView := ""
    static NudgeStep := 1
    static GameHwnd := 0
    static OverscanVal := 0

    static RegisteredGuis := Map()
    static SnapThreshold := 20
    static LastMainPos := { x: 0, y: 0 }
    static IsMoveHookActive := false

    static EditW := ""
    static EditH := ""
    static EditStep := ""
    static BtnMon1 := ""
    static BtnMon2 := ""
    static EditOverscan := ""

    static Show() {
        if (this.HasProp("WinGui") && IsObject(this.WinGui) && this.WinGui) {
            this.WinGui.Show()
            this.RefreshList()
            return
        }

        winTitle := "  Nexus :: Window Manager | Positioning | Nudge Steps (px) | Custom Size | Predefined Sizes |"
        if (IsSet(WindowManager) && WindowManager.ActiveGameExe != "")
            winTitle .= " - [" . WindowManager.ActiveGameExe . "]"

        this.WinGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow +Owner", "Nexus :: Window Manager")
        this.WinGui.BackColor := "2A2A2A"
        this.WinGui.SetFont("s12 cSilver q5", "Segoe UI")
        this.WinGui.OnEvent("Close", (*) => this.Destroy())
        this.WinGui.OnEvent("Escape", (*) => this.Destroy())

        guiW := 805

        ; CUSTOM TITLE BAR
        titleCtrl := this.WinGui.Add("Text", "x0 y0 w" (guiW - 30) " h30 +0x200 Background2A2A2A", winTitle)
        titleCtrl.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.WinGui.Hwnd))

        BtnClose := this.WinGui.Add("Text", "x+0 w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
        BtnClose.OnEvent("Click", (*) => this.Destroy())

        ; WINDOW LIST
        this.ListView := this.WinGui.Add("ListView", "x5 y+5 w795 h150 -Multi Background2A2A2A cSilver", ["ID", "Title", "Class", "Status"])
        this.ListView.OnEvent("DoubleClick", (*) => this.OnListDoubleClick())

        this.ListView.ModifyCol(1, 95)
        this.ListView.ModifyCol(2, 275)
        this.ListView.ModifyCol(3, 325)
        this.ListView.ModifyCol(4, 65)

        ; WINDOW STATE BUTTONS
        yState := "y+10"
        this.BtnAddTheme("  Destroy  ", (*) => this.Action("Close"), "x6 " yState " w60 Background333333")
        this.BtnAddTheme("  Hidden  ", (*) => this.Action("Hide"), "x+5 Background333333")
        this.BtnAddTheme("  Show  ", (*) => this.Action("Show"), "x+5 Background333333")
        this.BtnAddTheme("  Minimized  ", (*) => this.Action("Minimize"), "x+5 Background333333")
        this.BtnAddTheme("  Maximized  ", (*) => this.Action("Maximize"), "x+5 Background333333")
        this.BtnAddTheme("  Windowed  ", (*) => this.Action("Windowed"), "x+5 Background333333")
        this.BtnAddTheme(" True Borderless Fullscreen  ", (*) => this.Action("Borderless"), "x+5 Background333333")

        this.BtnAddTheme("  Refresh List  ", (*) => this.RefreshList(), "x+5 Background333333")

        ; --- ROW 2: OVERSCAN LOGIC ---
        this.BtnAddTheme("  Restore  ", (*) => this.Action("Default"), "x5 y+10 Background333333")
        this.BtnAddTheme("  Fit Screen  ", (*) => this.Action("FitScreen"), "x+10 Background333333")

        this.BtnAddTheme("  Apply H-Overscan  ", (*) => WindowManager.ApplyHorizontalOverscan(this.OverscanVal), "x+10 Background006666")
        this.WinGui.SetFont("Bold s11 cBlack")
        this.EditOverscan := this.WinGui.Add("Edit", "x+10 h26 w35 Number Center", "0")
        this.EditOverscan.OnEvent("Change", (ctrl, *) => this.OverscanVal := ctrl.Value)
        this.WinGui.SetFont("Norm s12 cSilver")
        this.BtnAddTheme("  Apply V-Overscan  ", (*) => WindowManager.ApplyVerticalOverscan(this.OverscanVal), "x+10 Background006666")

        ; POSITION & MONITOR
        this.BtnAddTheme("Up", (*) => WindowManager.Nudge(0, -this.NudgeStep, 0, 0), "x6 y+10 w35 Background333333")
        this.BtnAddTheme("Down", (*) => WindowManager.Nudge(0, this.NudgeStep, 0, 0), "x+0 w50 Background333333")
        this.BtnAddTheme("Left", (*) => WindowManager.Nudge(-this.NudgeStep, 0, 0, 0), "x+0 w40 Background333333")
        this.BtnAddTheme("Right", (*) => WindowManager.Nudge(this.NudgeStep, 0, 0, 0), "x+0 w50 Background333333")

        this.WinGui.SetFont("Bold s11 cBlack")
        this.EditStep := this.WinGui.Add("Edit", "x+12 h26 w35 Number Center", "1")
        this.EditStep.OnEvent("Change", (ctrl, *) => this.NudgeStep := ctrl.Value)

        this.EditW := this.WinGui.Add("Edit", "x+14 h26 w55 Number Center", "1920")
        this.EditH := this.WinGui.Add("Edit", "x+0 h26 w55 Number Center", "1080")
        this.WinGui.SetFont("Norm s12 cSilver")

        this.BtnAddTheme("Set", (*) => this.ApplyCustomSize(), "x+0 w35 Background006666")

        ; Size Nudge Buttons
        ; [UPDATED] Symmetric Resize Nudge (Arg 5 = true)
        this.BtnAddTheme("W ++", (*) => WindowManager.Nudge(0, 0, this.NudgeStep, 0, true), "x+10 w50 Background333333")
        this.BtnAddTheme("H ++", (*) => WindowManager.Nudge(0, 0, 0, this.NudgeStep, true), "x+0 w50 Background333333")
        this.BtnAddTheme("W --", (*) => WindowManager.Nudge(0, 0, -this.NudgeStep, 0, true), "x+0 w50 Background333333")
        this.BtnAddTheme("H --", (*) => WindowManager.Nudge(0, 0, 0, -this.NudgeStep, true), "x+0 w50 Background333333")

        ; Save Button
        this.BtnAddTheme("  Save Changes  ", (*) => WindowManager.SaveCurrentPosition(), "x+10 Background006666")

        ; RESOLUTIONS
        this.BtnAddTheme("1920x1080", (*) => WindowManager.ApplyPreset("Size1920x1080"), "x5 y+10 w90 Background333333")
        this.BtnAddTheme("1920x1200", (*) => WindowManager.ApplyPreset("Size1920x1200"), "x+8 Background333333 w90")
        this.BtnAddTheme("1920x1440", (*) => WindowManager.ApplyPreset("Size1920x1440"), "x+8 Background333333 w90")
        this.BtnAddTheme("2048x1152", (*) => WindowManager.ApplyPreset("Size2048x1152"), "x+8 Background333333 w90")
        this.BtnAddTheme("2048x1536", (*) => WindowManager.ApplyPreset("Size2048x1536"), "x+8 Background333333 w90")
        this.BtnAddTheme("2560x1440", (*) => WindowManager.ApplyPreset("Size2560x1440"), "x+8 Background333333 w90")
        this.BtnAddTheme("2560x1600", (*) => WindowManager.ApplyPreset("Size2560x1600"), "x+8 Background333333 w90")
        this.BtnAddTheme("2880x1800", (*) => WindowManager.ApplyPreset("Size2880x1800"), "x+8 Background333333 w90")

        this.BtnAddTheme("3840x2160", (*) => WindowManager.ApplyPreset("Size3840x2160"), "x5 y+10 w90 Background333333")
        this.BtnAddTheme("4096x2160", (*) => WindowManager.ApplyPreset("Size4096x2160"), "x+8 Background333333 w90")
        this.BtnAddTheme("5120x2880", (*) => WindowManager.ApplyPreset("Size5120x2880"), "x+8 Background333333 w90")
        this.BtnAddTheme("6016x3384", (*) => WindowManager.ApplyPreset("Size6016x3384"), "x+8 Background333333 w90")
        this.BtnAddTheme("7680x4320", (*) => WindowManager.ApplyPreset("Size7680x4320"), "x+9 Background333333 w90")

        ; MONITOR SWITCH
        this.WinGui.SetFont("cSilver q5")
        this.BtnMon1 := this.BtnAddTheme("Monitor 1", (*) => this.SwitchMonitor(1), "x5 y+10 w90 Background333333")
        this.BtnMon2 := this.BtnAddTheme("Monitor 2", (*) => this.SwitchMonitor(2), "x+8 w90 Background333333")

        this.UpdateMonitorVisuals(1)

        this.WinGui.Show("w" guiW)

        if !this.HasProp("RegisteredGuis")
            this.RegisteredGuis := Map()

        if (this.WinGui)
            this.RegisterForSnapping(this.WinGui.Hwnd)

        this.RefreshList()
    }

    static Destroy() {
        if (this.WinGui) {
            this.WinGui.Destroy()
            this.WinGui := ""
        }
    }

    static SwitchMonitor(monitorIndex) {
        WindowManager.MoveToMonitor(monitorIndex)
        this.UpdateMonitorVisuals(monitorIndex)
    }

    static UpdateMonitorVisuals(activeIndex) {
        cActive := "Background006666"
        cInactive := "Background333333"

        if !this.HasProp("BtnMon1") || !this.HasProp("BtnMon2")
            return

        if (activeIndex == 1) {
            this.BtnMon1.Opt("+" cActive)
            this.BtnMon2.Opt("+" cInactive)
        } else {
            this.BtnMon1.Opt("+" cInactive)
            this.BtnMon2.Opt("+" cActive)
        }
        this.BtnMon1.Redraw()
        this.BtnMon2.Redraw()
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.WinGui.Add("Text", "h26 +0x200 +Center +Border " options, label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; [UPDATED] Unfiltered Refresh List
    static RefreshList() {
        if !this.WinGui
            return

        selectedHwnd := 0
        row := this.ListView.GetNext(0)
        if (row > 0)
            selectedHwnd := this.ListView.GetText(row, 1)

        this.ListView.Delete()

        targetPids := Map()

        ; --- [FIX START] ---
        ; 1. Check ConfigManager for the REAL active process (e.g. PPSSPPWindows64.exe)
        activeExe := ConfigManager.ActiveProcessName

        if (activeExe != "") {
            try {
                pid := ProcessExist(activeExe)
                if (pid)
                    targetPids[pid] := true
            }
        }

        ; 2. Fallback to WindowManager internal tracking
        if (IsSet(WindowManager) && WindowManager.ActiveGamePid > 0)
            targetPids[WindowManager.ActiveGamePid] := true
        ; --- [FIX END] ---

        if (targetPids.Count == 0) {
            this.ListView.Add("", "", "No active game tracked", "", "")
            return
        }

        prevDetect := A_DetectHiddenWindows
        DetectHiddenWindows(true)

        try {
            uniqueIds := Map()
            for pid, _ in targetPids {
                try {
                    ids := WinGetList("ahk_pid " pid)
                    for id in ids
                        uniqueIds[id] := true
                }
            }

            for this_id, _ in uniqueIds {
                title := WinGetTitle(this_id)
                cls := WinGetClass(this_id)
                style := WinGetStyle(this_id)
                status := (style & 0x10000000) ? "Visible" : "Hidden"
                this.ListView.Add("", this_id, title, cls, status)
            }
        } catch {
            this.ListView.Add("", "Error", "Could not list windows", "", "")
        }
        DetectHiddenWindows(prevDetect)
    }

    static Action(type) {
        row := this.ListView.GetNext(0)

        hwnd := 0
        if (row > 0)
            hwnd := Integer(this.ListView.GetText(row, 1))
        else
            hwnd := WindowManager.GetValidHwnd()

        if (!hwnd) {
            DialogsGui.CustomTrayTip("No window selected", 2)
            return
        }

        prevDetect := A_DetectHiddenWindows
        DetectHiddenWindows(true)

        try {
            if !WinExist("ahk_id " hwnd) {
                DialogsGui.CustomTrayTip("Window gone", 2)
                return
            }

            switch type {
                case "Close": WinClose("ahk_id " hwnd)
                case "Hide": WinHide("ahk_id " hwnd)
                case "Show": WinShow("ahk_id " hwnd)
                case "Minimize": WinMinimize("ahk_id " hwnd)
                case "Maximize":
                    WinShow("ahk_id " hwnd)
                    WinMaximize("ahk_id " hwnd)
                case "Borderless": WindowManager.ApplyMode(hwnd, "Borderless", 0, {})
                case "Windowed": WindowManager.ApplyMode(hwnd, "Windowed", 0, {})
                case "Default": WindowManager.ApplyMode(hwnd, "Restored", 0, {})
                case "FitScreen": WindowManager.ApplyPreset("SizeFitScreen")
                case "Center":
                    WinGetPos(, , &w, &h, "ahk_id " hwnd)
                    WindowManager.ApplyFakeFullscreen(hwnd, w, h, 0, {})
            }
            SetTimer(() => this.RefreshList(), -500)
        } catch {
            DialogsGui.CustomTrayTip("Action Failed", 3)
        } finally {
            DetectHiddenWindows(prevDetect)
        }
    }

    static ApplyCustomSize() {
        hwnd := 0
        row := this.ListView.GetNext(0)
        if (row > 0)
            hwnd := Integer(this.ListView.GetText(row, 1))

        if (!hwnd)
            hwnd := WindowManager.GetValidHwnd()

        if (!hwnd || !WinExist("ahk_id " hwnd))
            return

        try {
            w := Integer(this.EditW.Value)
            h := Integer(this.EditH.Value)

            if (w > 0 && h > 0) {
                WinMove(, , w, h, "ahk_id " hwnd)
                DialogsGui.CustomTrayTip("Resized to " w "x" h, 1)
            }
        } catch {
            DialogsGui.CustomStatusPop("Failed to resize window")
        }
    }

    static OnListDoubleClick() {
        this.RefreshList()
    }

    ; ---- SNAPPING LOGIC (Restored) ----
    static RegisterForSnapping(hwnd) {
        if (this.RegisteredGuis.Count == 0) {
            OnMessage(0x0216, (wp, lp, msg, h) => this.OnWindowMoving(wp, lp, h))
        }

        if (!this.IsMoveHookActive) {
            if IsSet(GuiBuilder) && GuiBuilder.MainGui {
                GuiBuilder.MainGui.GetPos(&mainX, &mainY)
                this.LastMainPos := { x: mainX, y: mainY }

                OnMessage(0x0003, (w, l, m, h) => WindowManagerGui.OnMainMove(w, l, m, h))
                this.IsMoveHookActive := true
            }
        }
        this.RegisteredGuis[hwnd] := true
    }

    static OnWindowMoving(wParam, lParam, hwnd) {
        if (!this.RegisteredGuis.Has(hwnd))
            return
        if !IsSet(GuiBuilder) || !GuiBuilder.MainGui
            return

        GuiBuilder.MainGui.GetPos(&mX, &mY, &mW, &mH)
        currL := NumGet(lParam, 0, "Int"), currT := NumGet(lParam, 4, "Int")
        currR := NumGet(lParam, 8, "Int"), currB := NumGet(lParam, 12, "Int")
        currW := currR - currL, currH := currB - currT

        snapX := "", snapY := ""

        if (Abs(currL - (mX + mW)) < this.SnapThreshold)
            snapX := mX + mW
        else if (Abs(currR - mX) < this.SnapThreshold)
            snapX := mX - currW
        else if (Abs(currL - mX) < this.SnapThreshold)
            snapX := mX
        else if (Abs(currR - (mX + mW)) < this.SnapThreshold)
            snapX := mX + mW - currW

        if (Abs(currT - mY) < this.SnapThreshold)
            snapY := mY
        else if (Abs(currB - (mY + mH)) < this.SnapThreshold)
            snapY := mY + mH
        else if (Abs(currB - mY) < this.SnapThreshold)
            snapY := mY - currH
        else if (Abs(currT - (mY + mH)) < this.SnapThreshold)
            snapY := mY + mH

        if (snapX !== "") {
            NumPut("Int", snapX, lParam, 0)
            NumPut("Int", snapX + currW, lParam, 8)
        }
        if (snapY !== "") {
            NumPut("Int", snapY, lParam, 4)
            NumPut("Int", snapY + currH, lParam, 12)
        }
    }

static OnMainMove(wParam, lParam, msg, hwnd) {
        ; 1. Safety check: Is the GuiBuilder even initialized?
        if !IsSet(GuiBuilder) || !HasProp(GuiBuilder, "MainGui")
            return

        ; 2. Safety check: Is MainGui an object and does it have a valid Hwnd?
        if !IsObject(GuiBuilder.MainGui) || !HasProp(GuiBuilder.MainGui, "Hwnd")
            return

        ; 3. Ignore messages that aren't for the MainGui
        if (hwnd != GuiBuilder.MainGui.Hwnd)
            return

        try {
            ; Get current position safely
            GuiBuilder.MainGui.GetPos(&nX, &nY)

            ; Initialize LastMainPos if it's missing to avoid "Unassigned Variable" errors
            if !WindowManagerGui.HasProp("LastMainPos") || !IsObject(WindowManagerGui.LastMainPos) {
                WindowManagerGui.LastMainPos := { x: nX, y: nY }
                return
            }

            dX := nX - WindowManagerGui.LastMainPos.x
            dY := nY - WindowManagerGui.LastMainPos.y

            ; If no movement, exit
            if (dX == 0 && dY == 0)
                return

            ; Hold Ctrl to move Main UI without moving attached windows
            if GetKeyState("Ctrl", "P") {
                WindowManagerGui.LastMainPos := { x: nX, y: nY }
                return
            }

            ; Move registered child GUIs (like the Window Manager itself)
            if WindowManagerGui.HasProp("RegisteredGuis") {
                for cHwnd, _ in WindowManagerGui.RegisteredGuis {
                    if WinExist("ahk_id " cHwnd) {
                        try {
                            WinGetPos(&cX, &cY, , , "ahk_id " cHwnd)
                            WinMove(cX + dX, cY + dY, , , "ahk_id " cHwnd)
                        }
                    }
                }
            }

            ; Update reference point for next move
            WindowManagerGui.LastMainPos := { x: nX, y: nY }
        }
    }
    }