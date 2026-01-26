#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Fast System Information Viewer. Features: Async GPU/Hz, Disk Space, Uptime, IP (WMI), Dark Mode.
; * @class SystemInfoTool
; * @location lib/tools/SystemInfoTool.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class SystemInfoTool {
    static MainGui := ""
    static ListCtrl := ""

    ; Controls
    static BtnCopy := "", BtnRefresh := ""

    ; OPEN TOOL
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        ; --- GUI SETUP ---
        ; Matches Main GUI: Fixed size, Borderless, Always on Top
        this.MainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus :: System Information")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")

        this.MainGui.OnEvent("Close", (*) => this.Close())

        ; --- CUSTOM TITLE BAR ---
        ; Title Text (Handles Dragging)
        this.MainGui.Add("Text", "x0 y0 w540 h30 +0x200 Background2A2A2A", "  Nexus :: System Information")
            .OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        ; Close Button (X)
        this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "✕")
            .OnEvent("Click", (*) => this.Close())

        ; --- LISTVIEW (Fixed Size) ---
        ; y30 = Below Title Bar
        ; h330 = Leaves 40px at bottom for buttons
        this.ListCtrl := this.MainGui.Add("ListView", "x5 y30 w560 h240 AltSubmit -Hdr -Multi Background2A2A2A cWhite", ["Property", "Value"])
        this.ListCtrl.ModifyCol(1, 140) ; Property Width
        this.ListCtrl.ModifyCol(2, 410) ; Value Width

        ; --- BUTTONS (Fixed Position) ---
        this.BtnCopy := this.BtnAddTheme("  Copy All  ", (*) => this.CopyToClipboard(), "x5 y280")
        this.BtnRefresh := this.BtnAddTheme("  Refresh  ", (*) => this.LoadInfo(), "x+5 yp")

        this.MainGui.Show("w570 h315")
        this.LoadInfo()
    }

    static Close() {
        if (this.MainGui) {
            this.MainGui.Destroy()
        }
        this.MainGui := ""
    }

    ; Helper for Flat Buttons
    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; DATA LOADING
    static LoadInfo() {
        this.ListCtrl.Delete()

        ; INSTANT INFO
        this.AddRow("Computer Name", A_ComputerName)
        this.AddRow("User Name", A_UserName)
        this.AddRow("OS Version", A_OSVersion . " (" . (A_Is64bitOS ? "64-bit" : "32-bit") . ")")

        ; Local IP
        try {
            for obj in ComObjGet("winmgmts:").ExecQuery("SELECT IPAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True") {
                if (obj.IPAddress) {
                    for ip in obj.IPAddress {
                        if (ip ~= "^\d+\.\d+\.\d+\.\d+$") {
                            this.AddRow("Local IP", ip)
                            break 2
                        }
                    }
                }
            }
        }

        ; Uptime
        uptime := Round((A_TickCount / 1000) / 3600, 1) " hours"
        this.AddRow("System Uptime", uptime)

        ; Disk Space (C:)
        try {
            freeSpace := DriveGetSpaceFree("C:\")
            freeGB := Round(freeSpace / 1024, 1)
            this.AddRow("Free Disk (C:)", freeGB " GB")
        }

        ; Resolution
        this.AddRow("Resolution", A_ScreenWidth " x " A_ScreenHeight)

        ; CPU
        try {
            cpuName := RegRead("HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0", "ProcessorNameString", "Unknown CPU")
            this.AddRow("CPU", cpuName)
        }

        ; RAM
        memStatus := Buffer(64, 0)
        NumPut("UInt", 64, memStatus)
        if DllCall("GlobalMemoryStatusEx", "Ptr", memStatus) {
            totalPhys := NumGet(memStatus, 8, "UInt64")
            totalGB := Round(totalPhys / 1024 ** 3, 1)
            this.AddRow("RAM", totalGB " GB Total")
        }

        ; ASYNC GPU
        this.AddRow("GPU", "Fetching info...")
        SetTimer(() => this.FetchGPU(), -50)
    }

    static FetchGPU() {
        if (!this.MainGui) {
            return
        }

        gpuInfo := ""
        try {
            wmi := ComObjGet("winmgmts:")
            query := wmi.ExecQuery("SELECT Name, CurrentRefreshRate FROM Win32_VideoController")

            for item in query {
                rate := item.CurrentRefreshRate
                hzStr := (rate && rate > 1) ? " (" rate " Hz)" : ""
                gpuInfo .= item.Name . hzStr . " / "
            }
            gpuInfo := RTrim(gpuInfo, " / ")
        } catch {
            gpuInfo := "Unknown GPU"
        }

        Loop this.ListCtrl.GetCount() {
            if (this.ListCtrl.GetText(A_Index, 1) == "GPU") {
                this.ListCtrl.Modify(A_Index, "", , gpuInfo)
                break
            }
        }
    }

    static AddRow(prop, val) {
        this.ListCtrl.Add(, prop, val)
    }

    static CopyToClipboard() {
        text := ""
        Loop this.ListCtrl.GetCount() {
            prop := this.ListCtrl.GetText(A_Index, 1)
            val := this.ListCtrl.GetText(A_Index, 2)
            text .= prop . ": " . val . "`n"
        }
        A_Clipboard := text

        this.BtnCopy.Text := "  Copied!  "
        SetTimer(() => this.ResetCopyBtn(), -1000)
    }

    static ResetCopyBtn() {
        if (this.MainGui) {
            this.BtnCopy.Text := "  Copy All  "
        }
    }
}