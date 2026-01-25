#Requires AutoHotkey v2.0
; ======================================================================
; * @description Monitor Helper Module (v2) - Multi-monitor detection and geometry utilities.
; * @class MonitorHelper
; * @location lib/window/MonitorHelper.ahk
; * @author Philip
; * @date 2026/01/05
; * @version 1.0.02 (Fixed Timers)
; ======================================================================

; --- DEPENDENCY IMPORTS ---
; None

class MonitorHelper {

    ; GetMonitorCount()
    ; Returns the number of connected monitors
    static GetMonitorCount() {
        return MonitorGetCount()
    }

    ; GetMonitorGeometry(index)
    ; Gets physical dimensions of a specific monitor
    ; Returns: Object {Left, Top, Right, Bottom, Width, Height} or false
    static GetMonitorGeometry(index) {
        try {
            ; v2: MonitorGet(N, &Left, &Top, &Right, &Bottom)
            MonitorGet(index, &L, &T, &R, &B)

            width := R - L
            height := B - T

            if (width <= 0 || height <= 0)
                return false

            return { Left: L, Top: T, Right: R, Bottom: B, Width: width, Height: height }
        }
        catch {
            return false
        }
    }

    ; GetMonitorIndexFromPoint(x, y)
    ; Determines which monitor contains the given point
    static GetMonitorIndexFromPoint(x, y) {
        count := this.GetMonitorCount()

        Loop count {
            try {
                MonitorGet(A_Index, &L, &T, &R, &B)
                if (x >= L && x < R && y >= T && y < B)
                    return A_Index
            }
        }
        return 1 ; Fallback to primary
    }

    ; GetMonitorIndexFromWindow(hwnd)
    ; Determines which monitor a window is primarily on (using center point)
    static GetMonitorIndexFromWindow(hwnd) {
        try {
            ; Check if minimized (-1)
            if (WinGetMinMax(hwnd) == -1) {
                ; If minimized, we can't trust WinGetPos.
                ; We should rely on where it WAS, or default to Primary.
                ; Optional: You could store the "LastMonitor" in WindowManager and read it here.
                return MonitorGetPrimary()
            }

            WinGetPos(&x, &y, &w, &h, hwnd)

            ; Calculate center
            centerX := x + (w // 2)
            centerY := y + (h // 2)

            return this.GetMonitorIndexFromPoint(centerX, centerY)
        }
        catch {
            return MonitorGetPrimary() ; Safer fallback
        }
    }

    ; GetPrimaryMonitorGeometry()
    ; Gets geometry of the primary monitor (Index 1 in AHK)
    static GetPrimaryMonitorGeometry() {
        return this.GetMonitorGeometry(MonitorGetPrimary())
    }

    ; CalculateMonitorCenterPoint(monitorIndex)
    ; Calculates the center coordinates of a monitor
    static CalculateMonitorCenterPoint(monitorIndex) {
        mon := this.GetMonitorGeometry(monitorIndex)
        if (!mon)
            return false

        return { x: mon.Left + (mon.Width // 2), y: mon.Top + (mon.Height // 2) }
    }

    ; IsPointOnMonitor(x, y, monitorIndex)
    ; Checks if a point is within a specific monitor's boundaries
    static IsPointOnMonitor(x, y, monitorIndex) {
        mon := this.GetMonitorGeometry(monitorIndex)
        if (!mon)
            return false

        return (x >= mon.Left && x < mon.Right && y >= mon.Top && y < mon.Bottom)
    }

    ; GetMonitorWorkArea(monitorIndex)
    ; Gets the usable work area (excluding taskbars)
    static GetMonitorWorkArea(monitorIndex) {
        try {
            MonitorGetWorkArea(monitorIndex, &L, &T, &R, &B)

            return {
                Left: L, Top: T, Right: R, Bottom: B,
                Width: R - L, Height: B - T
            }
        }
        catch {
            return false
        }
    }

    ; DebugPrintAllMonitors()
    ; Prints geometry of all monitors to Logger
    static DebugPrintAllMonitors() {
        count := this.GetMonitorCount()
        Logger.Debug("=== Monitor Configuration ===")
        Logger.Debug("Total monitors: " . count)

        Loop count {
            mon := this.GetMonitorGeometry(A_Index)
            workArea := this.GetMonitorWorkArea(A_Index)

            if (mon) {
                Logger.Debug("Monitor " . A_Index . ":")
                Logger.Debug("  Geometry: " . mon.Width . "x" . mon.Height . " at (" . mon.Left . "," . mon.Top . ")")
            }
            if (workArea) {
                Logger.Debug("  Work Area: " . workArea.Width . "x" . workArea.Height . " at (" . workArea.Left . "," . workArea.Top . ")")
            }
        }
    }
}