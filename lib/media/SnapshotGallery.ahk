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

#Requires AutoHotkey v2.0

class SnapshotGallery {
    ; -- State --
    static ImageList := []
    static CurrentIndex := 1
    static CurrentFolder := ""
    static ActiveMonitor := 1
    static SlideshowTimer := ""
    static LastActionTime := 0

    ; -- GUIs --
    static WinGui := ""
    static FullGui := ""

    ; -- Controls --
    static WinPic := "", WinInfo := ""
    static BtnPrev := "", BtnNext := "", BtnBrowse := "", BtnSlide := "", BtnDelete := ""

    ; Title Bar
    static TitleText := ""
    static BtnLang := "", BtnMin := "", BtnMax := "", BtnClose := ""

    ; -- MAIN ENTRY --
    static Show(startPath := "") {
        this.Close()

        if (startPath == "") {
            try startPath := IniRead(ConfigManager.IniPath, "SETTINGS", "LastGalleryPath", "")
        }
        this.CurrentFolder := (startPath != "") ? startPath : A_ScriptDir
        this.ImageList := []
        this.CurrentIndex := 1

        ; CREATE GUI
        this.WinGui := Gui("-Caption +ToolWindow +AlwaysOnTop +Owner +Border +MinSize600x500", "NEXUS :: Gallery")
        this.WinGui.BackColor := "2A2A2A"
        this.WinGui.SetFont("s12 cSilver", "Segoe UI")

        this.WinGui.OnEvent("Close", (*) => this.Close())
        this.WinGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnWinResize(minMax, w, h))
        this.WinGui.OnEvent("DropFiles", (guiObj, ctrl, fileArray, *) => this.LoadImages(fileArray[1]))

        ; Initialize Snapping
        this.InitSnapping()

        ; --- TITLE BAR ---
        this.TitleText := this.WinGui.Add("Text", "x0 y0 w600 h35 +0x200 Background2A2A2A", "  NEXUS :: " TranslationManager.T("Gallery"))
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.WinGui.Hwnd))

        this.WinGui.SetFont("s10 Norm")

        ; 1. LANGUAGE BUTTON (New)
        this.BtnLang  := this.AddTitleBtn(TranslationManager.GetCurrentCode(), (*) => this.CycleLanguage(), "w40")

        ; 2. Standard Buttons
        this.BtnMin   := this.AddTitleBtn("_", (*) => this.WinGui.Minimize())
        this.BtnMax   := this.AddTitleBtn("□", (*) => this.ToggleMaximize())
        this.BtnClose := this.AddTitleBtn("✕", (*) => this.Close(), "cRed")

        this.WinGui.SetFont("s12 cSilver")

        ; --- PICTURE ---
        this.WinPic := this.WinGui.Add("Picture", "x0 y35 w900 h400 +0x100 BackgroundBlack")
        this.WinPic.OnEvent("DoubleClick", (*) => this.StartFullscreen())

        ; --- BUTTONS ---
        this.BtnPrev   := this.BtnAddTheme(TranslationManager.T("Previous"),  (*) => this.ShowPrev())
        this.BtnNext   := this.BtnAddTheme(TranslationManager.T("Next"),      (*) => this.ShowNext())
        this.BtnSlide  := this.BtnAddTheme(TranslationManager.T("Slideshow"), (*) => this.StartSlideshow())
        this.BtnBrowse := this.BtnAddTheme(TranslationManager.T("Browse"),    (*) => this.BrowseFolder())
        this.BtnDelete := this.BtnAddTheme(TranslationManager.T("Delete"),    (*) => this.DeleteCurrentImage())

        ; --- INFO TEXT ---
        this.WinInfo := this.WinGui.Add("Text", "x10 y+10 w800 h135 Background2A2A2A cSilver Left", "")

        ; Hotkeys
        HotIfWinActive("ahk_id " this.WinGui.Hwnd)
        Hotkey("Left", (*) => this.ShowPrev(), "On")
        Hotkey("Right", (*) => this.ShowNext(), "On")
        Hotkey("Space", (*) => this.StartSlideshow(), "On")
        Hotkey("F11", (*) => this.StartFullscreen(), "On")
        Hotkey("Delete", (*) => this.DeleteCurrentImage(), "On")
        HotIf()

        this.WinGui.Show("w900 h750")
        this.LoadImages(this.CurrentFolder)
    }

    ; ---- RESIZE LOGIC ----
    static OnWinResize(minMax, w, h) {
        if (minMax == -1)
            return

        ; 1. Title Bar Layout (Adjusted for Language Button)
        try {
            ; Buttons take up roughly 145px (40+35+35+35)
            btnWidthTotal := 145
            this.TitleText.Move(0, 0, w - btnWidthTotal, 35)

            xPos := w - btnWidthTotal
            this.BtnLang.Move(xPos, 0)  ; Lang Button
            this.BtnMin.Move(xPos + 40, 0)
            this.BtnMax.Move(xPos + 75, 0)
            this.BtnClose.Move(xPos + 110, 0)
        }

        ; 2. Layout Calculations
        btnH := 36
        gap := 10
        textH := 150
        bottomPadding := 10
        bottomArea := gap + btnH + gap + textH + bottomPadding
        imgH := h - 35 - bottomArea
        if (imgH < 50)
            imgH := 50

        try this.WinPic.Move(0, 35, w, imgH)

        ; 3. Position Buttons (Left Aligned)
        btnY := 35 + imgH + gap
        currX := 15

        MoveBtn := (ctrl) => (
            ctrl.GetPos(,, &bw, &bh),
            ctrl.Move(currX, btnY, bw, btnH),
            currX += bw + gap
        )

        try {
            MoveBtn(this.BtnPrev)
            MoveBtn(this.BtnNext)
            MoveBtn(this.BtnSlide)
            MoveBtn(this.BtnBrowse)
            MoveBtn(this.BtnDelete)
        }

        ; 4. Text Area
        textY := btnY + btnH + gap
        try this.WinInfo.Move(15, textY, w - 30, textH)

        this.UpdateWindowedImage()
    }

    ; ---- LANGUAGE SWITCHING ----
    static CycleLanguage() {
        ; 1. Cycle the Global Manager
        TranslationManager.Cycle()

        ; 2. Update Title Bar
        this.BtnLang.Value := TranslationManager.GetCurrentCode()
        this.TitleText.Value := "  NEXUS :: " TranslationManager.T("Gallery")

        ; 3. Update Buttons
        this.BtnPrev.Value := TranslationManager.T("Previous")
        this.BtnNext.Value := TranslationManager.T("Next")
        this.BtnSlide.Value := TranslationManager.T("Slideshow")
        this.BtnBrowse.Value := TranslationManager.T("Browse")
        this.BtnDelete.Value := TranslationManager.T("Delete")

        ; 4. Update Info Text
        this.UpdateWindowedImage()

        ; 5. Trigger Resize to recalculate button widths for new text length
        this.WinGui.GetPos(,, &w, &h)
        this.OnWinResize(0, w, h)
    }

    ; ---- MAGNETIC SNAPPING (Restored) ----
    static InitSnapping() {
        ; Intercept WM_MOVING (0x0216)
        OnMessage(0x0216, this.OnWindowMove.Bind(this))
    }

    static OnWindowMove(wParam, lParam, msg, hwnd) {
        if (!this.WinGui || hwnd != this.WinGui.Hwnd)
            return

        ; We need the Main GUI to snap TO
        if (!IsSet(GuiBuilder) || !GuiBuilder.MainGui)
            return

        try {
            if (WinGetMinMax("ahk_id " GuiBuilder.MainGui.Hwnd) == -1)
                return
            WinGetPos(&mX, &mY, &mW, &mH, "ahk_id " GuiBuilder.MainGui.Hwnd)
        } catch {
            return
        }

        ; Extract RECT from LParam
        curX := NumGet(lParam, 0, "Int")
        curY := NumGet(lParam, 4, "Int")
        curR := NumGet(lParam, 8, "Int")
        curB := NumGet(lParam, 12, "Int")

        width := curR - curX
        height := curB - curY
        snapDist := 20

        ; Snap Horizontally
        if (Abs(curX - (mX + mW)) < snapDist)       ; Snap Left side to Right edge of Main
            curX := mX + mW
        else if (Abs((curX + width) - mX) < snapDist) ; Snap Right side to Left edge of Main
            curX := mX - width
        else if (Abs(curX - mX) < snapDist)         ; Snap Left side to Left edge of Main
            curX := mX

        ; Snap Vertically
        if (Abs(curY - (mY + mH)) < snapDist)       ; Snap Top to Bottom edge
            curY := mY + mH
        else if (Abs((curY + height) - mY) < snapDist) ; Snap Bottom to Top edge
            curY := mY - height
        else if (Abs(curY - mY) < snapDist)         ; Snap Top to Top edge
            curY := mY

        ; Write back to structure
        NumPut("Int", curX, lParam, 0)
        NumPut("Int", curY, lParam, 4)
        NumPut("Int", curX + width, lParam, 8)
        NumPut("Int", curY + height, lParam, 12)
    }

    ; ---- HELPERS ----
    static AddTitleBtn(text, callback, options := "w35") {
        btn := this.WinGui.Add("Text", "x+0 yp " options " h35 +0x200 +Center Background2A2A2A cSilver", text)
        btn.OnEvent("Click", callback)
        return btn
    }

static BtnAddTheme(label, callback) {
        ; [FIX] Increased multiplier from 11 to 12 and added +15 padding
        ; This prevents text overlap in longer words like "Slideshow"
        tLen := StrLen(label) * 12
        w := (tLen < 85) ? 85 : tLen + 5 ; Minimum width 85, plus 5 buffer

        btn := this.WinGui.Add("Text", "x0 y0 w" w " h36 +0x200 +Center +Border Background333333 cWhite", label)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; ---- LOGIC ----
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

        this.WinInfo.Value := "Scanning..."
        if (ConfigManager.IniPath != "")
            try IniWrite(folderPath, ConfigManager.IniPath, "SETTINGS", "LastGalleryPath")

        Loop Files, folderPath . "\*.*", "R" {
            if (A_LoopFileExt ~= "i)^(jpg|jpeg|png|gif|bmp)$")
                this.ImageList.Push(A_LoopFileFullPath)
        }

        this.CurrentIndex := 1
        this.UpdateWindowedImage()
    }

    static UpdateInfoText(path, isWindowed) {
        if !isWindowed
            return ""
        fileSize := 0
        try fileSize := FileGetSize(path)

        txt := TranslationManager.T("Image") ": " this.CurrentIndex " / " this.ImageList.Length
        txt .= "`n" TranslationManager.T("Path") ": " path
        txt .= "`n" TranslationManager.T("Size") ": " fileSize " bytes"

        txt .= "`n" TranslationManager.T("GALLERY_HELP_1")
        txt .= "`n" TranslationManager.T("GALLERY_HELP_2")
        txt .= "`n" TranslationManager.T("GALLERY_HELP_3")
        txt .= "`n" TranslationManager.T("GALLERY_HELP_4")
        return txt
    }

    static UpdateWindowedImage() {
        if (this.ImageList.Length == 0) {
            this.WinInfo.Value := TranslationManager.T("No images found.")
            this.WinPic.Value := ""
            return
        }
        path := this.ImageList[this.CurrentIndex]
        this.WinInfo.Value := this.UpdateInfoText(path, true)

        this.WinPic.GetPos(, , &w, &h)
        if (w > 0)
            this.WinPic.Value := "*w" w " *h" h " " path
    }

    static TransitionImage(ctrl, path, isWindowed) {
        if !ctrl
            return
        if (isWindowed)
            this.WinInfo.Value := this.UpdateInfoText(path, true)
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

    static ShowNext() {
        if (this.ImageList.Length == 0)
            return
        this.CurrentIndex++
        if (this.CurrentIndex > this.ImageList.Length)
            this.CurrentIndex := 1
        this.RefreshBoth()
    }

    static ShowPrev() {
        if (this.ImageList.Length == 0)
            return
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

; ---- SLIDESHOW & FULLSCREEN ----

    ; 1. StartFullscreen now accepts a flag "autoDetect"
    static StartFullscreen(autoDetect := true) {
        if (this.ImageList.Length == 0)
            return

        ; ONLY detect monitor if we are just starting fresh.
        ; If switching monitors (M button), we skip this to keep the new selection.
        if (autoDetect)
            this.ActiveMonitor := this.GetMonitorFromHwnd(this.WinGui.Hwnd)

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

        info := TranslationManager.T("Image") " " this.CurrentIndex "/" this.ImageList.Length " | ESC: Close | M: Monitor | Space: Slide | DEL: Delete"
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
        if (this.FullGui)
            this.FullGui.Destroy()
        this.FullGui := ""
        if (this.WinGui)
            WinActivate("ahk_id " this.WinGui.Hwnd)
    }

    static SwitchMonitor() {
        count := MonitorGetCount()
        this.ActiveMonitor++
        if (this.ActiveMonitor > count)
            this.ActiveMonitor := 1

        ; CALL WITH FALSE so it doesn't reset back to the main window's screen
        this.StartFullscreen(false)
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

    static DeleteCurrentImage() {
        if (this.ImageList.Length == 0)
            return
        path := this.ImageList[this.CurrentIndex]
        if (DialogsGui.CustomMsgBox("Delete?", TranslationManager.T("Delete") "?`n" path, 0, 4) == "Yes") {
            try {
                this.RecycleSilently(path)
                this.ImageList.RemoveAt(this.CurrentIndex)
                if (this.ImageList.Length == 0) {
                    this.CurrentIndex := 1
                    this.UpdateWindowedImage()
                    if (this.FullGui)
                        this.StopFullscreen()
                    return
                }
                if (this.CurrentIndex > this.ImageList.Length)
                    this.CurrentIndex := this.ImageList.Length
                this.RefreshBoth()
            }
        }
    }

    static RecycleSilently(path) {
        strBuf := Buffer(StrPut(path, "UTF-16") + 2, 0)
        StrPut(path, strBuf, "UTF-16")
        shOp := Buffer((A_PtrSize=8?56:32), 0)
        NumPut("UInt", 3, shOp, (A_PtrSize=8?8:4))
        NumPut("Ptr", strBuf.Ptr, shOp, (A_PtrSize=8?16:8))
        NumPut("UShort", 0x54, shOp, (A_PtrSize=8?32:16))
        DllCall("shell32\SHFileOperation", "Ptr", shOp)
    }

    static BrowseFolder() {
        sel := DirSelect("*" this.CurrentFolder, 3, TranslationManager.T("Browse"))
        if (sel != "")
            this.LoadImages(sel)
    }

    static Close() {
        this.StopSlideshow()
        if (this.WinGui)
            this.WinGui.Destroy()
        this.WinGui := ""
        this.FullGui := ""
        this.ImageList := []
    }

    static ToggleMaximize() {
        if this.WinGui
            (WinGetMinMax(this.WinGui.Hwnd) == 1) ? this.WinGui.Restore() : this.WinGui.Maximize()
    }
    static GetMonitorFromHwnd(hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        cX := x + (w//2), cY := y + (h//2)
        loop MonitorGetCount() {
            MonitorGet(A_Index, &L, &T, &R, &B)
            if (cX >= L && cX < R && cY >= T && cY < B)
                return A_Index
        }
        return 1
    }
}