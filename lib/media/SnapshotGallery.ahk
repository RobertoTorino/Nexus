#Requires AutoHotkey v2.0
; ==============================================================================
; * @description image viewer - slide show
; * @class SnapshotGallery
; * @location lib/ui/SnapshotGallery.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class SnapshotGallery {
    ; -- State --
    static ImageList := []
    static CurrentIndex := 1
    static CurrentFolder := ""
    static ActiveMonitor := 1
    static SlideshowTimer := ""
    static LastActionTime := 0
    static ConfirmResult := ""

    ; -- GUIs --
    static WinGui := ""
    static FullGui := ""
    static DialogGui := ""

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
        this.WinGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner +Border +MinSize600x500", "NEXUS :: Image Viewer")
        this.WinGui.BackColor := "2A2A2A"
        this.WinGui.SetFont("s12 cSilver", "Segoe UI")

        this.WinGui.OnEvent("Close", (*) => this.Close())
        this.WinGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnWinResize(minMax, w, h))
        this.WinGui.OnEvent("DropFiles", (guiObj, ctrl, fileArray, *) => this.LoadImages(fileArray[1]))

        ; Initialize Magnetic Snapping
        this.InitSnapping()

        ; --- CUSTOM TITLE BAR ---
        this.TitleText := this.WinGui.Add("Text", "x0 y0 w800 h30 +0x200 Background2A2A2A", "  NEXUS :: Image Viewer")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.WinGui.Hwnd))

        this.WinGui.SetFont("s10 Norm")
        this.BtnMin := this.WinGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cSilver", "_")
        this.BtnMin.OnEvent("Click", (*) => this.WinGui.Minimize())

        this.BtnMax := this.WinGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cSilver", "□")
        this.BtnMax.OnEvent("Click", (*) => this.ToggleMaximize())

        this.BtnClose := this.WinGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Close())
        this.WinGui.SetFont("s12 cSilver")

        ; --- PICTURE CONTROL ---
        this.WinPic := this.WinGui.Add("Picture", "x0 y30 w900 h400 +0x100 BackgroundBlack")
        this.WinPic.OnEvent("DoubleClick", (*) => this.StartFullscreen())

        ; --- BUTTONS (Positions managed by OnWinResize) ---
        ; Note: x/y/w/h are dummy values here, resized immediately by OnWinResize
        this.BtnPrev   := this.BtnAddTheme("Previous",  (*) => this.ShowPrev(), "x0 y0 w0")
        this.BtnNext   := this.BtnAddTheme("Next",      (*) => this.ShowNext(), "x0 y0 w0")
        this.BtnSlide  := this.BtnAddTheme("Slideshow", (*) => this.StartSlideshow(), "x0 y0 w0")
        this.BtnBrowse := this.BtnAddTheme("Browse",    (*) => this.BrowseFolder(), "x0 y0 w0")
        this.BtnDelete := this.BtnAddTheme("Delete",    (*) => this.DeleteCurrentImage(), "x0 y0 w0")

        ; --- INFO TEXT ---
        this.WinInfo := this.WinGui.Add("Text", "x10 y+10 w800 h120 Background2A2A2A cSilver Left", "")

        ; Hotkeys
        HotIfWinActive("ahk_id " this.WinGui.Hwnd)
        Hotkey("Left", (*) => this.ShowPrev(), "On")
        Hotkey("Right", (*) => this.ShowNext(), "On")
        Hotkey("Space", (*) => this.StartSlideshow(), "On")
        Hotkey("F11", (*) => this.StartFullscreen(), "On")
        Hotkey("Delete", (*) => this.DeleteCurrentImage(), "On")
        HotIf()

        ; [FIX] Increased height to 720 to prevent text cutoff
        this.WinGui.Show("w900 h720")

        ; ---- LOAD ----
        this.LoadImages(this.CurrentFolder)
    }

    ; ---- FULLY DYNAMIC LAYOUT LOGIC ----
    static OnWinResize(minMax, w, h) {
        if (minMax == -1)
            return

        ; 1. Title Bar
        try {
            this.TitleText.Move(0, 0, w - 90, 30)
            xPos := w - 90
            this.BtnMin.Move(xPos, 0)
            this.BtnMax.Move(xPos + 30, 0)
            this.BtnClose.Move(xPos + 60, 0)
        }

        ; --- DYNAMIC CALCULATIONS ---

        ; Height: Buttons are 5% of window height (Min 30px, Max 60px)
        btnH := h // 20
        if (btnH < 30)
            btnH := 30
        if (btnH > 60)
            btnH := 60

        ; Width: Available width divided by 5 buttons (accounting for gaps)
        gap := 10
        margin := 10
        totalGapSpace := (gap * 4) + (margin * 2)
        btnW := (w - totalGapSpace) // 5

        ; [FIX] Increased text height allocation for s12 font
        textH := 145

        ; Calculate Bottom Area Height
        bottomAreaH := gap + btnH + gap + textH + gap

        ; 2. Resize Picture (Takes remaining vertical space)
        imgH := h - 30 - bottomAreaH
        if (imgH < 50)
            imgH := 50

        try this.WinPic.Move(0, 30, w, imgH)

        ; 3. Position Buttons (Row 1)
        btnY := 30 + imgH + gap
        currX := margin

        try {
            this.BtnPrev.Move(currX, btnY, btnW, btnH)
            currX += btnW + gap

            this.BtnNext.Move(currX, btnY, btnW, btnH)
            currX += btnW + gap

            this.BtnSlide.Move(currX, btnY, btnW, btnH)
            currX += btnW + gap

            this.BtnBrowse.Move(currX, btnY, btnW, btnH)
            currX += btnW + gap

            this.BtnDelete.Move(currX, btnY, btnW, btnH)
        }

        ; 4. Position Text (Row 2)
        textY := btnY + btnH + gap
        try this.WinInfo.Move(margin, textY, w - (margin * 2), textH)

        this.UpdateWindowedImage()
    }

    ; --- MAGNETIC SNAPPING LOGIC ---
    static InitSnapping() {
        OnMessage(0x0216, this.OnWindowMove.Bind(this))
    }

    static OnWindowMove(wParam, lParam, msg, hwnd) {
        if (!this.WinGui || hwnd != this.WinGui.Hwnd)
            return
        if (!IsSet(GuiBuilder) || !GuiBuilder.MainGui)
            return

        try {
            if (WinGetMinMax("ahk_id " GuiBuilder.MainGui.Hwnd) == -1)
                return
            WinGetPos(&mX, &mY, &mW, &mH, "ahk_id " GuiBuilder.MainGui.Hwnd)
        } catch {
            return
        }

        curX := NumGet(lParam, 0, "Int")
        curY := NumGet(lParam, 4, "Int")
        curR := NumGet(lParam, 8, "Int")
        curB := NumGet(lParam, 12, "Int")

        width := curR - curX
        height := curB - curY
        snapDist := 20

        if (Abs(curX - (mX + mW)) < snapDist)
            curX := mX + mW
        else if (Abs((curX + width) - mX) < snapDist)
            curX := mX - width
        else if (Abs(curX - mX) < snapDist)
            curX := mX

        if (Abs(curY - (mY + mH)) < snapDist)
            curY := mY + mH
        else if (Abs((curY + height) - mY) < snapDist)
            curY := mY - height
        else if (Abs(curY - mY) < snapDist)
            curY := mY

        NumPut("Int", curX, lParam, 0)
        NumPut("Int", curY, lParam, 4)
        NumPut("Int", curX + width, lParam, 8)
        NumPut("Int", curY + height, lParam, 12)
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

    ; ---- CUSTOM DIALOG & SILENT DELETE ----
    static DeleteCurrentImage() {
        if (this.ImageList.Length == 0)
            return

        currentPath := this.ImageList[this.CurrentIndex]
        parentHwnd := (this.FullGui) ? this.FullGui.Hwnd : this.WinGui.Hwnd

        response := this.ShowCustomConfirm(parentHwnd, "Delete Image?", "Are you sure you want to recycle:`n" currentPath)

        if (response != "Yes")
            return

        try {
            this.RecycleSilently(currentPath)
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

    static RecycleSilently(path) {
        strBuf := Buffer(StrPut(path, "UTF-16") + 2, 0)
        StrPut(path, strBuf, "UTF-16")

        if (A_PtrSize == 8) {
            shOp := Buffer(56, 0)
            NumPut("UInt", 3, shOp, 8)
            NumPut("Ptr", strBuf.Ptr, shOp, 16)
            NumPut("UShort", 0x54, shOp, 32)
        } else {
            shOp := Buffer(32, 0)
            NumPut("UInt", 3, shOp, 4)
            NumPut("Ptr", strBuf.Ptr, shOp, 8)
            NumPut("UShort", 0x54, shOp, 16)
        }
        DllCall("shell32\SHFileOperation", "Ptr", shOp)
    }

    static ShowCustomConfirm(hOwner, title, msg) {
        this.ConfirmResult := "No"
        this.DialogGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner" hOwner, title)
        this.DialogGui.BackColor := "2A2A2A"
        this.DialogGui.SetFont("s10 cSilver", "Segoe UI")

        this.DialogGui.Add("Text", "x0 y0 w400 h160 +Border BackgroundTrans")
        this.DialogGui.SetFont("s11 w700")
        this.DialogGui.Add("Text", "x20 y20 w360 h30 BackgroundTrans", title)
        this.DialogGui.SetFont("s10 w400")
        this.DialogGui.Add("Text", "x20 y60 w360 h50 BackgroundTrans", msg)

        btnYes := this.DialogGui.Add("Text", "x200 y120 w80 h30 +0x200 +Center +Border cSilver", "YES")
        btnYes.OnEvent("Click", (*) => (this.ConfirmResult := "Yes", this.DialogGui.Destroy()))

        btnNo := this.DialogGui.Add("Text", "x290 y120 w80 h30 +0x200 +Center +Border cSilver", "NO")
        btnNo.OnEvent("Click", (*) => (this.DialogGui.Destroy()))

        WinGetPos(&oX, &oY, &oW, &oH, "ahk_id " hOwner)
        dX := oX + (oW - 400) // 2
        dY := oY + (oH - 160) // 2

        this.DialogGui.Show("x" dX " y" dY " w400 h160")
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
        this.FullGui.SetFont("s12 cSilver w700")
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

    ; ---- SHARED NAVIGATION ----
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
            try IniWrite(folderPath, ConfigManager.IniPath, "SETTINGS", "LastGalleryPath")
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