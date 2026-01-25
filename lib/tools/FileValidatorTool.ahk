#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Calculates MD5/SHA1/CRC32 hashes to verify ROMs/ISOs.
; * @class FileValidatorTool
; * @location lib/tools/FileValidatorTool.ahk
; * @author Philip
; * @date 2026/01/18
; * @version 1.0.02 (Dark Theme Update)
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
#Include ..\ui\DialogsGui.ahk

class FileValidatorTool {
    static MainGui := ""
    static ListCtrl := ""
    static EditExpected := ""
    static StatusText := ""
    static BtnBrowse := ""

    ; State
    static Files := []      ; Array of file paths
    static IsBatch := false ; Mode flag
    static TempOut := A_Temp . "\hash_result.txt"
    static TimerCheck := ""
    static Pid := 0
    static CurrentAlgo := "" ; Track which algo we are running in batch

    ; Controls
    static BtnMD5 := "", BtnSHA1 := "", BtnSHA256 := "", BtnCRC32 := "", BtnClear := ""
    static TitleText := "", BtnMin := "", BtnClose := ""

    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            return
        }

        ; --- GUI SETUP ---
        guiW := 560
        guiH := 350

        this.MainGui := Gui("-Caption +Border +AlwaysOnTop +ToolWindow", "Nexus :: File Validator")

        ; ---- Snap Gui ----
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")

        this.MainGui.OnEvent("Close", (*) => this.Close())
        this.MainGui.OnEvent("DropFiles", (guiObj, ctrl, files, *) => this.OnDropFiles(files))

        ; --- TITLE BAR ---
        this.TitleText := this.MainGui.Add("Text", "x0 y0 w" (guiW - 60) " h30 +0x200 Background2A2A2A", "   Nexus :: File Validator")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))
        WindowManagerGui.RegisterForSnapping(this.MainGui.Hwnd)

        this.MainGui.SetFont("s10 Norm")
        this.BtnMin := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", "_")
        this.BtnMin.OnEvent("Click", (*) => this.MainGui.Minimize())

        this.BtnClose := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cRed", "✕")
        this.BtnClose.OnEvent("Click", (*) => this.Close())
        this.MainGui.SetFont("s10 cWhite")

        ; --- COMPARISON BAR ---
        this.MainGui.SetFont("s9 cWhite")
        this.MainGui.Add("Text", "x10 y40 w100 h20 Background2A2A2A", "Expected Hash:")
        this.EditExpected := this.MainGui.Add("Edit", "x100 y38 w345 h24 Background222222 Border cWhite -E0x200")
        this.EditExpected.OnEvent("Change", (*) => this.OnCompare())

        this.BtnBrowse := this.MainGui.Add("Button", "x+10 yp-1 h26 Background222222", "Select Files...")
        this.BtnBrowse.OnEvent("Click", (*) => this.BrowseFiles())

        ; --- LISTVIEW ---
        ; Columns adjust based on mode (Inspector vs Batch)
        this.ListCtrl := this.MainGui.Add("ListView", "x-2 y70 w" (guiW + 4) " h235 AltSubmit -Grid Background2A2A2A cWhite", ["Item", "Hash Value", "Match?"])
        this.ListCtrl.ModifyCol(1, 120) ; Name/Algo
        this.ListCtrl.ModifyCol(2, 340) ; Hash
        this.ListCtrl.ModifyCol(3, 80)  ; Match
        this.ListCtrl.OnEvent("DoubleClick", (*) => this.CopyToClipboard())

        ; --- BUTTONS ---
        yBtn := 315
        this.BtnMD5 := this.BtnAddTheme("  MD5  ", (*) => this.StartCalc("MD5"), "x10 y" yBtn)
        this.BtnSHA1 := this.BtnAddTheme("  SHA1  ", (*) => this.StartCalc("SHA1"), "x+0 yp")
        this.BtnSHA256 := this.BtnAddTheme("  SHA256  ", (*) => this.StartCalc("SHA256"), "x+0 yp")
        this.BtnCRC32 := this.BtnAddTheme("  CRC32  ", (*) => this.StartCalc("CRC32"), "x+0 yp")
        this.BtnClear := this.BtnAddTheme("  Clear  ", (*) => this.Clear(), "x+0 yp")

        this.StatusText := this.MainGui.Add("Text", "x+10 yp+3 w150 h20 Right cSilver Background2A2A2A", "Ready")

        this.MainGui.Show("w" guiW " h" guiH)
        this.TimerCheck := ObjBindMethod(this, "CheckCertUtilResult")
    }

    ; --- FILE LOADING ---
    static BrowseFiles() {
        ; "M" option enables multi-select
        files := FileSelect("M3", , "Select Files to Verify", "All Files (*.*)")
        if (files != "") {
            this.LoadFiles(files)
        }
    }

    static OnDropFiles(files) {
        this.LoadFiles(files)
    }

    static LoadFiles(filesInput) {
        this.Files := []

        ; Convert input (Array or FileSelect Object) to standard array
        if IsObject(filesInput) {
            for f in filesInput
                this.Files.Push(f)
        } else {
            this.Files.Push(filesInput) ; Single string
        }

        if (this.Files.Length == 0)
            return

        this.ListCtrl.Delete()
        this.EditExpected.Value := ""
        this.EditExpected.Opt("cWhite")

        if (this.Files.Length == 1) {
            ; --- INSPECTOR MODE (1 File) ---
            this.IsBatch := false
            SplitPath(this.Files[1], &fn)
            this.ListCtrl.ModifyCol(1, , "Algorithm") ; Column Header
            this.AddRow("File", fn, "")
            this.StatusText.Text := "Single File Mode"
            DialogsGui.CustomTrayTip("Loaded: " . fn, 1)
        }
        else {
            ; --- BATCH MODE (Multiple Files) ---
            this.IsBatch := true
            this.ListCtrl.ModifyCol(1, , "Filename") ; Column Header
            for f in this.Files {
                SplitPath(f, &fn)
                this.AddRow(fn, "Ready", "")
            }
            this.StatusText.Text := "Batch Mode: " . this.Files.Length . " files"
            DialogsGui.CustomTrayTip("Loaded " . this.Files.Length . " files", 1)
        }
    }

    ; --- CALCULATION DISPATCHER ---
    static StartCalc(algo) {
        if (this.Files.Length == 0) {
            DialogsGui.CustomTrayTip("No files loaded", 2)
            return
        }

        this.CurrentAlgo := algo
        this.StatusText.Text := "Calculating " . algo . "..."

        ; Disable UI (simple check)
        if (this.Pid > 0) {
            this.StatusText.Text := "Busy..."
            return
        }

        if (this.IsBatch) {
            ; Process ALL files sequentially
            this.ProcessBatch(algo)
        } else {
            ; Process SINGLE file (Add row if missing, or update)
            this.ProcessSingle(algo)
        }
    }

    ; --- SINGLE MODE LOGIC ---
    static ProcessSingle(algo) {
        ; Add row for this algo if it doesn't exist
        foundRow := 0
        Loop this.ListCtrl.GetCount() {
            if (this.ListCtrl.GetText(A_Index, 1) == algo) {
                foundRow := A_Index
                break
            }
        }
        if (foundRow == 0) {
            this.AddRow(algo, "Computing...", "...")
            foundRow := this.ListCtrl.GetCount()
        } else {
            this.ListCtrl.Modify(foundRow, "", , "Computing...", "...")
        }

        ; Dispatch
        filePath := this.Files[1]
        if (algo == "CRC32")
            this.RunInternalCRC32(filePath, foundRow)
        else
            this.RunCertUtil(filePath, algo, foundRow)
    }

    ; --- BATCH MODE LOGIC ---
    static ProcessBatch(algo) {
        ; Loop through all rows/files
        Loop this.Files.Length {
            row := A_Index
            filePath := this.Files[row]

            this.ListCtrl.Modify(row, "Vis", , "Computing...", "...")

            ; Allow UI redraw
            Sleep(10)

            result := ""
            if (algo == "CRC32") {
                result := this.CalcCRC32_Internal(filePath)
            } else {
                result := this.CalcCertUtil_Sync(filePath, algo)
            }

            this.ListCtrl.Modify(row, "", , result)
        }
        this.StatusText.Text := "Batch Complete."
        this.OnCompare()
    }

    ; --- CORE CALCULATIONS ---

    ; 1. CRC32 (Internal / Fast)
    static RunInternalCRC32(filePath, targetRow) {
        res := this.CalcCRC32_Internal(filePath)
        this.UpdateRow(targetRow, res)
        this.StatusText.Text := "Done."
        this.OnCompare()
    }

    static CalcCRC32_Internal(filePath) {
        try {
            f := FileOpen(filePath, "r")
            crc := 0
            chunkSize := 1024 * 1024
            data := Buffer(chunkSize)

            while (!f.AtEOF) {
                bytesRead := f.RawRead(data, chunkSize)
                crc := DllCall("ntdll\RtlComputeCrc32", "UInt", crc, "Ptr", data, "UInt", bytesRead, "UInt")
            }
            f.Close()
            ; ADDING 0x PREFIX HERE
            return Format("0x{:08X}", crc)
        } catch {
            return "Read Error"
        }
    }

    ; 2. CertUtil (External / Robust) - Async for Single File
    static RunCertUtil(filePath, algo, targetRow) {
        this.CurrentTargetRow := targetRow
        cmd := Format('cmd /c certutil -hashfile "{1}" {2} > "{3}"', filePath, algo, this.TempOut)

        try {
            if FileExist(this.TempOut)
                FileDelete(this.TempOut)

            Run(cmd, , "Hide", &pid)
            this.Pid := pid
            SetTimer(this.TimerCheck, 100)
        } catch {
            this.StatusText.Text := "Error launching calc"
        }
    }

    ; 3. CertUtil - Sync for Batch (Simpler loop logic)
    static CalcCertUtil_Sync(filePath, algo) {
        cmd := Format('cmd /c certutil -hashfile "{1}" {2}', filePath, algo)
        try {
            shell := ComObject("WScript.Shell")
            exec := shell.Exec(cmd)
            out := exec.StdOut.ReadAll()
            return this.ParseHashString(out)
        } catch {
            return "Error"
        }
    }

    ; --- RESULT PARSING ---
    static CheckCertUtilResult() {
        if (this.Pid == 0 || !ProcessExist(this.Pid)) {
            SetTimer(this.TimerCheck, 0)
            this.Pid := 0

            if FileExist(this.TempOut) {
                res := this.ParseHashString(FileRead(this.TempOut))
                this.UpdateRow(this.CurrentTargetRow, res)
                this.StatusText.Text := "Done."
                this.OnCompare()
            }
        }
    }

    static ParseHashString(rawOutput) {
        lines := StrSplit(rawOutput, "`n", "`r")
        for line in lines {
            clean := Trim(line)
            if (clean != "" && !InStr(clean, ":") && !InStr(clean, "CertUtil")) {
                ; Remove spaces
                val := StrReplace(clean, " ", "")
                ; Optional: Add 0x to others? Usually only CRC uses it.
                return val
            }
        }
        return "Error"
    }

    ; --- GUI HELPERS ---
    static UpdateRow(row, val) {
        if (row > 0 && row <= this.ListCtrl.GetCount())
            this.ListCtrl.Modify(row, "", , val)
    }

    static AddRow(c1, c2, c3) {
        this.ListCtrl.Add(, c1, c2, c3)
    }

    static OnCompare() {
        expected := Trim(this.EditExpected.Value)
        if (expected == "") {
            this.EditExpected.Opt("cWhite")
            return
        }

        Loop this.ListCtrl.GetCount() {
            row := A_Index

            ; In Single mode, skip row 1 (Filename)
            if (!this.IsBatch && this.ListCtrl.GetText(row, 1) == "File")
                continue

            hashVal := this.ListCtrl.GetText(row, 2)
            if (hashVal == "Computing..." || hashVal == "Ready" || hashVal == "Error")
                continue

            if (StrCompare(hashVal, expected, false) == 0) {
                this.ListCtrl.Modify(row, "", , , "MATCH")
                this.EditExpected.Opt("cLime")
            } else {
                this.ListCtrl.Modify(row, "", , , "NO")
                if (this.EditExpected.Opt("c") != "cLime")
                    this.EditExpected.Opt("cRed")
            }
        }
    }

    static CopyToClipboard() {
        row := this.ListCtrl.GetNext()
        if (row > 0) {
            val := this.ListCtrl.GetText(row, 2)
            if (val != "" && val != "Ready") {
                A_Clipboard := val
                DialogsGui.CustomTrayTip("Copied: " SubStr(val, 1, 10) "...", 1)
            }
        }
    }

    static Clear() {
        this.ListCtrl.Delete()
        this.Files := []
        this.StatusText.Text := "Ready"
        this.EditExpected.Value := ""
        this.EditExpected.Opt("cWhite")
    }

    static Close() {
        if (this.Pid > 0)
            ProcessClose(this.Pid)
        if (this.MainGui)
            this.MainGui.Destroy()
        this.MainGui := ""
    }

    static BtnAddTheme(label, callback, options) {
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Center +Border", label)
        btn.OnEvent("Click", callback)
        return btn
    }
}