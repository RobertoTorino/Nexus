#Requires AutoHotkey v2.0
; ==============================================================================
; * @description image viewer - slide show
; * @class SnapshotGallery
; * @location lib/ui/SnapshotGallery.ahk
; * @author Philip
; * @date 2026/01/06
; * @version 1.0.03
; ==============================================================================

class SnapshotGallery {
    ; -- State --
    static ImageList := []
    static CurrentIndex := 1
    static CurrentFolder := ""
    static ActiveMonitor := 1
    static SlideshowTimer := ""
    static LastActionTime := 0
    static ConfirmResult := "" ; Stores result from custom dialog

    ; -- GUIs --
    static WinGui := ""
    static FullGui := ""
    static DialogGui := ""     ; New Custom Dialog

    ; -- Controls --
    static WinPic := "", WinInfo := ""
    static BtnPrev := "", BtnNext := "", BtnBrowse := "", BtnSlide := "", BtnDelete := ""

    ; Title Bar Controls
    static TitleText := "", BtnMin := "", BtnMax := "", BtnClose := ""

    ; WINDOWED MODE (Main Entry)
    static Show(startPath := "") {
        this.Close()
        ; 1. RESOLVE PATH
        if (startPath == "") {
            try {
                startPath := IniRead(ConfigManager.IniPath, "SETTINGS", "LastGalleryPath", "")
            }
        }
        this.CurrentFolder := (startPath != "") ? startPath : A_ScriptDir
        this.ImageList := []
        this.CurrentIndex := 1

        ; 2. CREATE GUI
        this.WinGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner +Border +MinSize600x500", "Nexus :: Image Viewer")
        this.WinGui.BackColor := "2A2A2A"
        this.WinGui.SetFont("s10 q5 cWhite", "Segoe UI")

        this.WinGui.OnEvent("Close", (*) => this.Close())
        this.WinGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnWinResize(minMax, w, h))
        this.WinGui.OnEvent("DropFiles", (guiObj, ctrl, fileArray, *) => this.LoadImages(fileArray[1]))

        ; --- CUSTOM TITLE BAR ---
        this.TitleText := this.WinGui.Add("Text", "x0 y0 w800 h30 +0x200 Background2A2A2A", "  Nexus :: Image Viewer")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.WinGui.Hwnd))

        this.WinGui.SetFont("s10 Norm")
        this.BtnMin := this.WinGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "_")
        this.BtnMin.OnEvent("Click", (*) => this.WinGui.Minimize())

        this.BtnMax := this.WinGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "□")
        this.BtnMax.OnEvent("Click", (*) => this.ToggleMaximize())

        this.BtnClose := this.WinGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Close())
        this.WinGui.SetFont("s10 cWhite")

        ; --- PICTURE CONTROL ---
        this.WinPic := this.WinGui.Add("Picture", "x0 y30 w800 h400 +0x100 BackgroundBlack")
        this.WinPic.OnEvent("DoubleClick", (*) => this.StartFullscreen())

        ; --- FLAT BUTTONS ---
        this.BtnPrev := this.BtnAddTheme("Previous", (*) => this.ShowPrev(), "x10 y0 w70")
        this.BtnNext := this.BtnAddTheme("Next", (*) => this.ShowNext(), "x10 y0 w70")
        this.BtnSlide := this.BtnAddTheme("Slideshow", (*) => this.StartSlideshow(), "x10 y0 w70")
        this.BtnBrowse := this.BtnAddTheme("Browse", (*) => this.BrowseFolder(), "x10 y0 w70")
        this.BtnDelete := this.BtnAddTheme("Delete", (*) => this.DeleteCurrentImage(), "x10 y0 w70")

        this.WinInfo := this.WinGui.Add("Text", "x0 y0 w400 h140 Background2A2A2A cWhite", "Initializing...")

        ; Hotkeys
        HotIfWinActive("ahk_id " this.WinGui.Hwnd)
        Hotkey("Left", (*) => this.ShowPrev(), "On")
        Hotkey("Right", (*) => this.ShowNext(), "On")
        Hotkey("Space", (*) => this.StartSlideshow(), "On")
        Hotkey("F11", (*) => this.StartFullscreen(), "On")
        Hotkey("Delete", (*) => this.DeleteCurrentImage(), "On")
        HotIf()

        this.WinGui.Show("w900 h680")

        ; ---- LOAD ----
        this.LoadImages(this.CurrentFolder)
    }

    static Close() {
        this.StopSlideshow()
        if (this.WinGui) {
            try {
                HotIfWinActive("ahk_id " this.WinGui.Hwnd)
                Hotkey("Left", "Off")
                Hotkey("Right", "Off")
                Hotkey("Space", "Off")
                Hotkey("F11", "Off")
                Hotkey("Delete", "Off")
                HotIf()
            }
            this.WinGui.Destroy()
        }
        if (this.FullGui)
            this.FullGui.Destroy()
        if (this.DialogGui)
            this.DialogGui.Destroy()

        this.WinGui := ""
        this.FullGui := ""
        this.DialogGui := ""
        this.ImageList := []
    }

    ; Helper for Flat Buttons
    static BtnAddTheme(label, callback, options) {
        btn := this.WinGui.Add("Text", options " h30 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    static ToggleMaximize() {
        if !this.WinGui
            return
        state := WinGetMinMax(this.WinGui.Hwnd)
        if (state == 1)
            this.WinGui.Restore()
        else
            this.WinGui.Maximize()
    }

    ; ---- LAYOUT LOGIC ----
    static OnWinResize(minMax, w, h) {
        if (minMax == -1)
            return

        ; Resize Title Bar
        try {
            this.TitleText.Move(0, 0, w - 90, 30)
            xPos := w - 90
            this.BtnMin.Move(xPos, 0)
            this.BtnMax.Move(xPos + 30, 0)
            this.BtnClose.Move(xPos + 60, 0)
        }

        ; Calculate Image Height
        bottomSpace := 155
        imgH := h - 30 - bottomSpace
        if (imgH < 100)
            imgH := 100

        ; Resize Picture
        try this.WinPic.Move(0, 30, w, imgH)

        ; Button Placement
        btnX := 10
        btnW := 90
        btnH := 30
        gap := 5
        startY := 30 + imgH + 10

        try {
            this.BtnPrev.Move(btnX, startY, btnW, btnH)
            this.BtnNext.Move(btnX, startY + (btnH + gap), btnW, btnH)
            this.BtnSlide.Move(btnX, startY + (btnH + gap) * 2, btnW, btnH)

            yRow4 := startY + (btnH + gap) * 3
            this.BtnBrowse.Move(btnX, yRow4, btnW, btnH)
            this.BtnDelete.Move(btnX + btnW + gap, yRow4, btnW, btnH)

            textX := btnX + (btnW * 2) + (gap * 2) + 10
            textW := w - textX - 10
            totalBtnHeight := (btnH * 4) + (gap * 3)

            this.WinInfo.Move(textX, startY, textW, totalBtnHeight)
        }

        this.UpdateWindowedImage()
    }

    ; ---- CUSTOM DIALOG & SILENT DELETE ----
    static DeleteCurrentImage() {
        if (this.ImageList.Length == 0)
            return

        currentPath := this.ImageList[this.CurrentIndex]
        parentHwnd := (this.FullGui) ? this.FullGui.Hwnd : this.WinGui.Hwnd

        ; Show OUR Custom Dark Dialog
        response := this.ShowCustomConfirm(parentHwnd, "Delete Image?", "Are you sure you want to recycle:`n" currentPath)

        if (response != "Yes")
            return

        try {
            ; ---- SILENT RECYCLE (DllCall to bypass Windows Confirmation Popup) ----
            this.RecycleSilently(currentPath)

            ; Update UI
            this.ImageList.RemoveAt(this.CurrentIndex)

            if (this.ImageList.Length == 0) {
                this.CurrentIndex := 1
                this.WinInfo.Value := "No images found."
                this.WinPic.Value := ""
                return
            }

            if (this.CurrentIndex > this.ImageList.Length)
                this.CurrentIndex := this.ImageList.Length

            this.RefreshBoth()
        } catch as err {
            MsgBox("Could not delete file.`n" err.Message, "Error", "Iconx")
        }
    }

    ; Helper: Uses Windows API to recycle without Sound or "Are you sure?" popup
    static RecycleSilently(path) {
        ; Ensure path is double-null terminated (Required by SHFileOperation)
        ; UTF-16 strings use 2 bytes per char. We need extra nulls at the end.
        strBuf := Buffer(StrPut(path, "UTF-16") + 2, 0)
        StrPut(path, strBuf, "UTF-16")

        ; SHFILEOPSTRUCT Structure
        ; FO_DELETE (3) | FOF_ALLOWUNDO (0x40) | FOF_NOCONFIRMATION (0x10) | FOF_SILENT (0x04)
        ; Total Flags: 0x54

        if (A_PtrSize == 8) { ; 64-bit Structure
            shOp := Buffer(56, 0)
            NumPut("UInt", 3, shOp, 8)       ; wFunc = FO_DELETE
            NumPut("Ptr", strBuf.Ptr, shOp, 16) ; pFrom
            NumPut("UShort", 0x54, shOp, 32) ; fFlags
        } else { ; 32-bit Structure
            shOp := Buffer(32, 0)
            NumPut("UInt", 3, shOp, 4)       ; wFunc
            NumPut("Ptr", strBuf.Ptr, shOp, 8)  ; pFrom
            NumPut("UShort", 0x54, shOp, 16) ; fFlags
        }

        DllCall("shell32\SHFileOperation", "Ptr", shOp)
    }

    static ShowCustomConfirm(hOwner, title, msg) {
        this.ConfirmResult := "No"

        this.DialogGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner" hOwner, title)
        this.DialogGui.BackColor := "2A2A2A"
        this.DialogGui.SetFont("s10 cWhite", "Segoe UI")

        ; Border Frame
        this.DialogGui.Add("Text", "x0 y0 w400 h160 +Border BackgroundTrans")

        ; Title
        this.DialogGui.SetFont("s11 w700")
        this.DialogGui.Add("Text", "x20 y20 w360 h30 BackgroundTrans", title)

        ; Message
        this.DialogGui.SetFont("s10 w400")
        this.DialogGui.Add("Text", "x20 y60 w360 h50 BackgroundTrans", msg)

        ; Buttons
        btnYes := this.DialogGui.Add("Text", "x200 y120 w80 h30 +0x200 +Center +Border cWhite", "YES")
        btnYes.OnEvent("Click", (*) => (this.ConfirmResult := "Yes", this.DialogGui.Destroy()))

        btnNo := this.DialogGui.Add("Text", "x290 y120 w80 h30 +0x200 +Center +Border cWhite", "NO")
        btnNo.OnEvent("Click", (*) => (this.DialogGui.Destroy()))

        ; Center on Owner
        WinGetPos(&oX, &oY, &oW, &oH, "ahk_id " hOwner)
        dX := oX + (oW - 400) // 2
        dY := oY + (oH - 160) // 2

        this.DialogGui.Show("x" dX " y" dY " w400 h160")

        ; Disable parent window interaction (Modal behavior)
        WinSetEnabled(0, "ahk_id " hOwner)
        WinWaitClose("ahk_id " this.DialogGui.Hwnd)
        WinSetEnabled(1, "ahk_id " hOwner)
        WinActivate("ahk_id " hOwner)

        return this.ConfirmResult
    }

    ; ---- SLIDESHOW & FULLSCREEN ----
    static StartSlideshow() {
        if (this.ImageList.Length == 0)
            return
        this.StartFullscreen()
        this.SlideshowTimer := ObjBindMethod(this, "ShowNext")
        SetTimer(this.SlideshowTimer, 3000)
    }

    static StopSlideshow() {
        if IsObject(this.SlideshowTimer) {
            SetTimer(this.SlideshowTimer, 0)
            this.SlideshowTimer := ""
        }
    }

    static StartFullscreen() {
        if (this.ImageList.Length == 0)
            return
        this.ActiveMonitor := this.GetMonitorFromHwnd(this.WinGui.Hwnd)
        this.ShowFullscreenGUI()
    }

    static ShowFullscreenGUI() {
        if (this.FullGui)
            this.FullGui.Destroy()

        MonitorGet(this.ActiveMonitor, &L, &T, &R, &B)
        MonW := R - L
        MonH := B - T

        this.FullGui := Gui("-Caption -Border +AlwaysOnTop +ToolWindow +Owner" this.WinGui.Hwnd, "Fullscreen Viewer")
        this.FullGui.BackColor := "Black"
        this.FullGui.OnEvent("Escape", (*) => this.StopFullscreen())

        currentPath := this.ImageList[this.CurrentIndex]

        this.FullGui.Add("Picture", "x0 y0 w" MonW " h" MonH " BackgroundBlack +Center vFullPic", currentPath)

        info := "Image " this.CurrentIndex "/" this.ImageList.Length " | ESC: Close | M: Monitor | Space: Toggle Slideshow | DEL: Delete"
        this.FullGui.SetFont("s12 cWhite w700")
        this.FullGui.Add("Text", "x20 y20 w800 h40 BackgroundTrans", info)

        this.FullGui.Show("x" L " y" T " w" MonW " h" MonH " NoActivate")

        HotIfWinExist("ahk_id " this.FullGui.Hwnd)
        Hotkey("Escape", (*) => this.StopFullscreen(), "On")
        Hotkey("m", (*) => this.SwitchMonitor(), "On")
        Hotkey("Left", (*) => this.ShowPrev(), "On")
        Hotkey("Right", (*) => this.ShowNext(), "On")
        Hotkey("Space", (*) => this.ToggleTimerState(), "On")
        Hotkey("Delete", (*) => this.DeleteCurrentImage(), "On")
        HotIf()
    }

    static StopFullscreen() {
        this.StopSlideshow()
        if (this.FullGui) {
            try {
                HotIfWinExist("ahk_id " this.FullGui.Hwnd)
                Hotkey("Escape", "Off")
                Hotkey("m", "Off")
                Hotkey("Left", "Off")
                Hotkey("Right", "Off")
                Hotkey("Space", "Off")
                Hotkey("Delete", "Off")
                HotIf()
            }
            this.FullGui.Destroy()
        }
        this.FullGui := ""
        if (this.WinGui) {
            this.WinGui.Opt("-Disabled")
            WinActivate("ahk_id " this.WinGui.Hwnd)
        }
    }

    static SwitchMonitor() {
        count := MonitorGetCount()
        this.ActiveMonitor++
        if (this.ActiveMonitor > count)
            this.ActiveMonitor := 1
        this.ShowFullscreenGUI()
    }

    static ToggleTimerState() {
        if IsObject(this.SlideshowTimer)
            this.StopSlideshow()
        else {
            this.SlideshowTimer := ObjBindMethod(this, "ShowNext")
            SetTimer(this.SlideshowTimer, 3000)
            this.ShowNext()
        }
    }

    ; ---- SHARED NAVIGATION & PERSISTENCE ----
    static LoadImages(folderPath) {
        this.ImageList := []

        if (FileExist(folderPath) && !InStr(FileExist(folderPath), "D"))
            SplitPath(folderPath, , &folderPath)

        folderPath := RTrim(folderPath, "\")
        this.CurrentFolder := folderPath

        if !DirExist(folderPath) {
            this.WinInfo.Value := "Folder not found:`n" folderPath
            return
        }

        this.WinInfo.Value := "Scanning recursively...`n" folderPath
        Sleep(50)

        if (ConfigManager.IniPath != "") {
            try {
                IniWrite(folderPath, ConfigManager.IniPath, "SETTINGS", "LastGalleryPath")
            }
        }

        searchPattern := folderPath . "\*.*"
        Loop Files, searchPattern, "R" {
            if (A_LoopFileExt ~= "i)^(jpg|jpeg|png|gif|bmp)$")
                this.ImageList.Push(A_LoopFileFullPath)
        }

        this.CurrentIndex := 1
        this.UpdateWindowedImage()
    }

    static ShowNext() {
        if (this.ImageList.Length == 0)
            return
        if (A_TickCount - this.LastActionTime < 250)
            return
        this.LastActionTime := A_TickCount
        this.CurrentIndex++
        if (this.CurrentIndex > this.ImageList.Length)
            this.CurrentIndex := 1
        this.RefreshBoth()
    }

    static ShowPrev() {
        if (this.ImageList.Length == 0)
            return
        if (A_TickCount - this.LastActionTime < 250)
            return
        this.LastActionTime := A_TickCount
        this.CurrentIndex--
        if (this.CurrentIndex < 1)
            this.CurrentIndex := this.ImageList.Length
        this.RefreshBoth()
    }

    static RefreshBoth() {
        path := this.ImageList[this.CurrentIndex]
        if (this.WinGui)
            this.TransitionImage(this.WinPic, path, true)
        if (this.FullGui)
            this.TransitionImage(this.FullGui["FullPic"], path, false)
    }

    static TransitionImage(ctrl, path, isWindowed) {
        if !ctrl
            return

        if (isWindowed) {
            fileSize := 0
            try fileSize := FileGetSize(path)
            infoText := "Image: " this.CurrentIndex " / " this.ImageList.Length
            infoText .= "`nPath: " path
            infoText .= "`nSize: " fileSize " bytes"
            infoText .= "`nPress the spacebar to start a full screen slideshow."
            infoText .= "`nDouble click image for full screen."
            infoText .= "`nWhen in full screen press the M button to switch between Monitor 1 and Monitor 2."
            infoText .= "`nPress DELETE to recycle image."

            this.WinInfo.Value := infoText
        }

        try {
            ctrl.Visible := false
            if (isWindowed) {
                ctrl.GetPos(, , &w, &h)
                if (w > 0)
                    ctrl.Value := "*w" w " *h" h " " path
            } else {
                ctrl.Value := path
            }
            DllCall("AnimateWindow", "Ptr", ctrl.Hwnd, "Int", 200, "Int", 0xA0000)
            ctrl.Visible := true
        } catch {
            ctrl.Visible := true
        }
    }

    static UpdateWindowedImage() {
        if (this.ImageList.Length == 0) {
            this.WinInfo.Value := "No images found."
            this.WinPic.Value := ""
            return
        }
        path := this.ImageList[this.CurrentIndex]
        fileSize := 0
        try fileSize := FileGetSize(path)
        infoText := "Image: " this.CurrentIndex " / " this.ImageList.Length
        infoText .= "`nPath: " path
        infoText .= "`nSize: " fileSize " bytes"
        infoText .= "`nPress the spacebar to start a full screen slideshow."
        infoText .= "`nDouble click image for full screen."
        infoText .= "`nWhen in full screen press the M button to switch between Monitor 1 and Monitor 2."
        infoText .= "`nPress DELETE to recycle image."

        this.WinInfo.Value := infoText

        this.WinPic.GetPos(, , &w, &h)
        if (w > 0)
            this.WinPic.Value := "*w" w " *h" h " " path
    }

    static BrowseFolder() {
        sel := DirSelect("*" this.CurrentFolder, 3, "Select Folder (Recursive)")
        if (sel != "") {
            this.LoadImages(sel)
        }
    }

    static GetMonitorFromHwnd(hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        centerX := x + (w // 2)
        centerY := y + (h // 2)
        loop MonitorGetCount() {
            MonitorGet(A_Index, &L, &T, &R, &B)
            if (centerX >= L && centerX < R && centerY >= T && centerY < B)
                return A_Index
        }
        return 1
    }
}