#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Game Search Database. Features: SQLite Backend, Dark Mode, Central Logging.
; * @class GameDatabaseTool
; * @location lib/tools/GameDatabaseTool.ahk
; * @author Philip
; * @date 2026/01/08
; * @version 1.12.0 (Fixed: Context Menu Crash, Restored Maximize Btn)
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class GameDatabaseTool {
    static MainGui := ""
    static DB := ""

    ; Data Stores
    static TablesWithLinks := []
    static Regions := ["All"]
    static TableOptions := ["All"]

    ; Paths
    static DBPath := A_ScriptDir . "\nexus.db"
    static DLLPath := A_ScriptDir . "\sqlite3.dll"

    ; Controls
    static TitleText := "", BtnMin := "", BtnMax := "", BtnClose := ""
    static EdtSearch := "", DdlTable := "", DdlRegion := ""
    static BtnSearch := "", BtnRandom := "", BtnLink := "", BtnMissing := ""
    static LvResults := ""

    ; Context Menu
    static CtxGui := ""
    static CtxTimer := "" ; Timer to check focus

    ; Window State
    static GuiWidth := 1000
    static GuiHeight := 600

    ; INITIALIZATION & SHOW
    static Show() {
        if (this.MainGui) {
            this.MainGui.Show()
            this.MainGui.Restore()
            return
        }

        Logger.Info("[GameDB] Initializing Search Tool...")

        ; CHECKS
        if !FileExist(this.DLLPath) {
            Logger.Info("[GameDB] Critical Error: sqlite3.dll missing.")
            DialogsGui.CustomMsgBox("Error", "Critical component missing:`n" this.DLLPath)
            return
        }
        if !FileExist(this.DBPath) {
            Logger.Info("[GameDB] Error: Database file missing.")
            DialogsGui.CustomMsgBox("Error", "Database missing:`n" this.DBPath)
            return
        }

        ; CONNECT
        this.DB := SQLiteDB_Simple()
        if !this.DB.OpenDB(this.DBPath) {
            Logger.Info("[GameDB] Connection Failed: " this.DB.ErrorMsg)
            DialogsGui.CustomMsgBox("DB Error", "Failed to open DB:`n" this.DB.ErrorMsg)
            return
        }
        Logger.Info("[GameDB] Database connected.")

        ; LOAD DATA
        this.LoadMetadata()

        ; BUILD GUI
        this.BuildGui()
        Logger.Info("[GameDB] GUI Created and Shown.")
    }

    static LoadMetadata() {
        this.TablesWithLinks := []
        this.Regions := ["All"]
        this.TableOptions := ["All"]

        requiredCols := ["GameId", "GameTitle", "Link", "Region"]

        try {
            allTables := this.DB.GetTable("SELECT name FROM sqlite_master WHERE type='table';")
            for row in allTables {
                tableName := row[1]
                colsInfo := this.DB.GetTable("PRAGMA table_info(" tableName ");")
                foundCols := 0
                for colRow in colsInfo {
                    for req in requiredCols {
                        if (colRow[2] = req)
                            foundCols++
                    }
                }
                if (foundCols >= requiredCols.Length)
                    this.TablesWithLinks.Push(tableName)
            }
        } catch as e {
            Logger.Info("[GameDB] Metadata Error: " e.Message)
            DialogsGui.CustomMsgBox("Error", "Error reading DB structure:`n" e.Message)
            return
        }

        uniqueRegions := Map()
        for tbl in this.TablesWithLinks {
            try {
                q := Format("SELECT DISTINCT Region FROM [{}] WHERE Region IS NOT NULL AND Region != '';", tbl)
                rs := this.DB.GetTable(q)
                for r in rs
                    uniqueRegions[String(r[1])] := true
            }
        }
        for regionName in uniqueRegions
            this.Regions.Push(regionName)

        this.TableOptions.Push(this.TablesWithLinks*)
        Logger.Info("[GameDB] Metadata Loaded. Tables: " this.TablesWithLinks.Length ", Regions: " this.Regions.Length)
    }

    static BuildGui() {
        ; Removed +Resize to keep borders clean, but we handle Maximize manually
        this.MainGui := Gui("-Caption +Border +ToolWindow", "Game Finder")
        this.MainGui.BackColor := "2A2A2A"
        this.MainGui.SetFont("s10 cWhite", "Segoe UI")

        ; Force Dark Mode (DWM)
        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.MainGui.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.MainGui.Hwnd, "Int", 33, "Int*", 1, "Int", 4)
        }

        this.MainGui.OnEvent("Close", (*) => this.Hide())
        this.MainGui.OnEvent("Size", (guiObj, minMax, w, h) => this.OnResize(minMax, w, h))

        ; --- CUSTOM TITLE BAR ---
        this.TitleText := this.MainGui.Add("Text", "x0 y0 w" (this.GuiWidth - 90) " h30 +0x200 Background2A2A2A", "  Nexus :: Game Search Database")
        this.TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2, 0, this.MainGui.Hwnd))

        this.MainGui.SetFont("s10 Norm")
        ; Window Buttons (Min, Max, Close)
        this.BtnMin := this.AddWinBtn("_", (*) => this.MainGui.Minimize())
        this.BtnMax := this.AddWinBtn("□", (*) => this.ToggleMaximize()) ; RESTORED
        this.BtnClose := this.AddWinBtn("✕", (*) => this.Hide())
        this.MainGui.SetFont("s10 cWhite")

        ; --- TOOLBAR ---
        yTools := 40
        this.MainGui.Add("Text", "x10 y" yTools " h26 +0x200 Background2A2A2A", "Title or ID:")
        this.EdtSearch := this.MainGui.Add("Edit", "x+5 yp w200 h26 cWhite Background2A2A2A")
        this.EdtSearch.OnEvent("Change", (*) => 0)

        this.MainGui.Add("Text", "x+10 yp h26 +0x200 Background2A2A2A", "Table:")
        this.DdlTable := this.MainGui.Add("DropDownList", "x+5 yp w120 Choose1 cBlack", this.TableOptions)

        this.MainGui.Add("Text", "x+10 yp h26 +0x200 Background2A2A2A", "Region:")
        this.DdlRegion := this.MainGui.Add("DropDownList", "x+5 yp w100 Choose1 cBlack", this.Regions)

        ; Buttons
        this.BtnSearch := this.BtnAddTheme("  Search  ", (*) => this.OnSearch(), "x+15 yp")
        this.BtnRandom := this.BtnAddTheme("  Show Random  ", (*) => this.OnRandom(), "x+0 yp")
        this.BtnMissing := this.BtnAddTheme("  Show Missing  ", (*) => this.OnShowMissing(), "x+0 yp")
        this.BtnLink := this.BtnAddTheme("  Open URL  ", (*) => this.OnOpenLink(), "x+0 yp")
        this.BtnAddTheme("  ?  ", (*) => this.ShowHelp(), "x+15")

        ; --- RESULTS LIST ---
        this.LvResults := this.MainGui.Add("ListView", "x0 y80 w" this.GuiWidth " h" (this.GuiHeight - 80) " -Multi +LV0x4000 Background2A2A2A cWhite", ["Table", "GameId", "Game Title", "Link", "Region"])

        this.LvResults.ModifyCol(1, 120)
        this.LvResults.ModifyCol(2, 90)
        this.LvResults.ModifyCol(3, 350)
        this.LvResults.ModifyCol(4, 350)
        this.LvResults.ModifyCol(5, 70)

        this.LvResults.OnEvent("DoubleClick", (*) => this.OnOpenLink())
        this.LvResults.OnEvent("ContextMenu", (ctrl, item, *) => this.ShowContext(item))

        this.MainGui.Show("w" this.GuiWidth " h" this.GuiHeight)
        this.OnResize(0, this.GuiWidth, this.GuiHeight) ; Initial layout update
    }

    static Hide() {
        this.CloseContextMenu() ; Ensure context menu is gone
        if (this.MainGui) {
            this.MainGui.Destroy()
        }
        this.MainGui := ""
        if (this.DB) {
            this.DB.CloseDB()
            this.DB := ""
        }
    }

    ; RESIZE & MAXIMIZE LOGIC
    static ToggleMaximize() {
        if (!this.MainGui)
            return

        ; Check if maximized (1) or normal (0)
        state := WinGetMinMax(this.MainGui.Hwnd)
        if (state == 1)
            this.MainGui.Restore()
        else
            this.MainGui.Maximize()
    }

    static OnResize(minMax, w, h) {
        if (minMax == -1) ; Minimized
            return

        ; Move Title Bar Buttons
        try {
            ; Title text takes up width minus the 3 buttons (30px each)
            this.TitleText.Move(0, 0, w - 90, 30)

            xBtn := w - 90
            this.BtnMin.Move(xBtn, 0)
            this.BtnMax.Move(xBtn + 30, 0)
            this.BtnClose.Move(xBtn + 60, 0)
        }

        ; Resize ListView
        try {
            lvH := h - 80
            if (lvH < 100)
                lvH := 100
            this.LvResults.Move(0, 80, w, lvH)
        }
    }

    ; LOGIC
    static OnSearch() {
        query := Trim(this.EdtSearch.Value)

        if (query = "") {
            DialogsGui.CustomMsgBox("Info", "Please enter a search term.")
            return
        }

        Logger.Info("[GameDB] Searching for: '" query "'")

        tblFilter := this.DdlTable.Text
        regFilter := this.DdlRegion.Text
        searchTables := (tblFilter = "All") ? this.TablesWithLinks : [tblFilter]

        this.LvResults.Delete()
        this.LvResults.Opt("-Redraw")

        counter := 0
        for tbl in searchTables {
            sql := ""
            params := []

            ; Using (Title OR ID) logic
            baseSQL := Format("SELECT '{}', GameId, GameTitle, Link, Region FROM [{}] WHERE (GameTitle LIKE ? COLLATE NOCASE OR GameId LIKE ? COLLATE NOCASE)", tbl, tbl)

            if (regFilter != "All") {
                sql := baseSQL . " AND Region = ?;"
                params := ["%" query "%", "%" query "%", regFilter]
            } else {
                sql := baseSQL . ";"
                params := ["%" query "%", "%" query "%"]
            }

            try {
                results := this.DB.GetTable(sql, params)
                for row in results {
                    row[4] := (row[4] = "") ? "<null>" : row[4]
                    row[5] := (row[5] = "") ? "<null>" : row[5]
                    this.LvResults.Add(, row*)
                    counter++
                }
            } catch as e {
                Logger.Info("[GameDB] SQL Error on table " tbl ": " e.Message)
            }
        }
        this.LvResults.Opt("+Redraw")

        Logger.Info("[GameDB] Search complete. Results: " counter)

        if (counter = 0)
            DialogsGui.CustomMsgBox("No Results", "No matching games found.")
    }

    static OnRandom() {
        Logger.Info("[GameDB] Random browse initiated.")
        tblFilter := this.DdlTable.Text
        targetTable := ""

        if (tblFilter == "All") {
            if (this.TablesWithLinks.Length > 0)
                targetTable := this.TablesWithLinks[Random(1, this.TablesWithLinks.Length)]
            else
                return
        } else {
            targetTable := tblFilter
        }

        this.LvResults.Delete()
        this.LvResults.Opt("-Redraw")

        sql := Format("SELECT '{}', GameId, GameTitle, Link, Region FROM [{}] ORDER BY RANDOM() LIMIT 20;", targetTable, targetTable)

        try {
            results := this.DB.GetTable(sql)
            for row in results {
                row[4] := (row[4] = "") ? "<null>" : row[4]
                row[5] := (row[5] = "") ? "<null>" : row[5]
                this.LvResults.Add(, row*)
            }
            Logger.Info("[GameDB] Loaded 20 random items from " targetTable)
        } catch as e {
            Logger.Info("[GameDB] Random Query Error: " e.Message)
        }
        this.LvResults.Opt("+Redraw")
    }

    static OnShowMissing() {
        Logger.Info("[GameDB] Show Missing Links initiated.")
        tblFilter := this.DdlTable.Text
        searchTables := (tblFilter = "All") ? this.TablesWithLinks : [tblFilter]

        this.LvResults.Delete()
        this.LvResults.Opt("-Redraw")

        counter := 0
        for tbl in searchTables {
            sql := Format("SELECT '{}', GameId, GameTitle, Link, Region FROM [{}] WHERE (Link IS NULL OR Link = '' OR Link = 'MISSING');", tbl, tbl)
            try {
                results := this.DB.GetTable(sql)
                for row in results {
                    row[4] := (row[4] = "") ? "<null>" : row[4]
                    row[5] := (row[5] = "") ? "<null>" : row[5]
                    this.LvResults.Add(, row*)
                    counter++
                }
            } catch as e {
                Logger.Info("[GameDB] Missing Query Error on " tbl ": " e.Message)
            }
        }
        this.LvResults.Opt("+Redraw")
        Logger.Info("[GameDB] Found " counter " missing links.")
        if (counter == 0)
            DialogsGui.CustomMsgBox("Info", "No missing links found in current selection.")
    }

    ; CUSTOM GUI CONTEXT MENU
    static ShowContext(item) {
        if (item == 0)
            return

        this.CloseContextMenu()

        MouseGetPos(&mx, &my)

        this.CtxGui := Gui("-Caption +AlwaysOnTop +Border +Owner" this.MainGui.Hwnd, "Context")
        this.CtxGui.BackColor := "2A2A2A"
        this.CtxGui.SetFont("s10 cWhite", "Segoe UI")

        this.CtxGui.OnEvent("Escape", (*) => this.CloseContextMenu())

        this.AddMenuBtn("  Copy Game ID  ", (*) => (this.CopyCell(2), this.CloseContextMenu()))
        this.AddMenuBtn("  Copy Title  ", (*) => (this.CopyCell(3), this.CloseContextMenu()))
        this.AddMenuBtn("  Copy Link  ", (*) => (this.CopyCell(4), this.CloseContextMenu()))

        ; FIX: Removed "NoActivate" so the window takes focus.
        this.CtxGui.Show("x" mx " y" my)

        this.CtxTimer := ObjBindMethod(this, "CheckContextFocus")
        SetTimer(this.CtxTimer, 100)
    }

    static CheckContextFocus() {
        if (!this.CtxGui) {
            this.CloseContextMenu()
            return
        }
        ; If the Context Menu GUI is not the active window, close it.
        if (!WinActive(this.CtxGui.Hwnd)) {
            this.CloseContextMenu()
        }
    }

    static CloseContextMenu() {
        if (this.CtxTimer) {
            SetTimer(this.CtxTimer, 0)
            this.CtxTimer := ""
        }
        if (this.CtxGui) {
            this.CtxGui.Destroy()
            this.CtxGui := ""
        }
    }

    static AddMenuBtn(text, callback) {
        btn := this.CtxGui.Add("Text", "x0 y+0 w150 h30 +0x200 +Center Background2A2A2A cWhite", text)
        btn.OnEvent("Click", callback)
    }

    static CopyCell(colIndex) {
        row := this.LvResults.GetNext()
        if (row == 0)
            return

        text := this.LvResults.GetText(row, colIndex)
        if (text == "<null>")
            text := ""

        A_Clipboard := text
        Logger.Info("[GameDB] Copied to clipboard: " text)
    }

    static OnOpenLink() {
        row := this.LvResults.GetNext()
        if (row = 0)
            return

        link := this.LvResults.GetText(row, 4)
        if (link == "<null>" || link == "") {
            DialogsGui.CustomMsgBox("Info", "No link available for this game.")
            return
        }
        Logger.Info("[GameDB] Opening Link: " link)
        try Run(link)
    }

    ; UI HELPERS
    static AddWinBtn(text, callback) {
        btn := this.MainGui.Add("Text", "x+0 yp w30 h30 +0x200 +Center Background2A2A2A cWhite", text)
        btn.OnEvent("Click", callback)
        return btn
    }

    static BtnAddTheme(text, callback, options) {
        align := (InStr(options, "Left") || InStr(options, "Right")) ? "" : "+Center"
        btn := this.MainGui.Add("Text", options " h26 +0x200 +Border Background2A2A2A cWhite " align, text)
        btn.OnEvent("Click", callback)
        return btn
    }

    ; HELP MENU
    static ShowHelp() {
        helpText := "
                (
            1. USING THE SEARCH ENGINE:
               - Search for title or game id by typing in (part of) id or title.
               - Search all tables or a selected table from the table selector.
               - For region search, select the region from the region selector.
               - Click show random if you just want to see some results.
               - Right click on a row to see the options.
               - Double-click on the link starts the download.
               - Open URL let's you choose a download location.

            X. TROUBLESHOOTING:
               - Use 'View Logs' from the main UI to look for errors.
            )"
        DialogsGui.ShowTextViewer("Nexus :: Help", helpText, 450, 300)
    }
}

; INTERNAL CLASS: LIGHTWEIGHT SQLITE WRAPPER
class SQLiteDB_Simple {
    hModule := 0
    dbHandle := 0
    ErrorMsg := ""

    __New() {
        if !this.hModule := DllCall("LoadLibrary", "Str", "sqlite3.dll", "Ptr")
            this.ErrorMsg := "Could not load sqlite3.dll"
    }

    OpenDB(dbPath) {
        this.ErrorMsg := ""
        if !this.hModule {
            this.ErrorMsg := "DLL not loaded."
            return false
        }
        res := DllCall("sqlite3.dll\sqlite3_open16", "Str", dbPath, "Ptr*", &hDb := 0, "Cdecl Int")
        if (res != 0) {
            this.ErrorMsg := "SQLite Error Code: " res
            return false
        }
        this.dbHandle := hDb
        return true
    }

    GetTable(sql, params := []) {
        if !this.dbHandle {
            throw Error("Database not open")
        }
        stmt := 0
        resultRows := []
        res := DllCall("sqlite3.dll\sqlite3_prepare16_v2", "Ptr", this.dbHandle, "Str", sql, "Int", -1, "Ptr*", &stmt := 0, "Ptr", 0, "Cdecl Int")
        if (res != 0) {
            errMsg := StrGet(DllCall("sqlite3.dll\sqlite3_errmsg16", "Ptr", this.dbHandle, "Ptr"))
            throw Error("SQL Prepare Error: " errMsg)
        }

        for i, val in params
            DllCall("sqlite3.dll\sqlite3_bind_text16", "Ptr", stmt, "Int", i, "Str", String(val), "Int", -1, "Ptr", 0, "Cdecl Int")

        loop {
            res := DllCall("sqlite3.dll\sqlite3_step", "Ptr", stmt, "Cdecl Int")
            if (res = 100) { ; ROW
                colCount := DllCall("sqlite3.dll\sqlite3_column_count", "Ptr", stmt, "Cdecl Int")
                row := []
                loop colCount {
                    pText := DllCall("sqlite3.dll\sqlite3_column_text16", "Ptr", stmt, "Int", A_Index - 1, "Ptr")
                    row.Push((pText) ? StrGet(pText) : "")
                }
                resultRows.Push(row)
            } else if (res = 101) { ; DONE
                break
            } else {
                DllCall("sqlite3.dll\sqlite3_finalize", "Ptr", stmt, "Cdecl Int")
                throw Error("SQL Step Error: " res)
            }
        }
        DllCall("sqlite3.dll\sqlite3_finalize", "Ptr", stmt, "Cdecl Int")
        return resultRows
    }

    CloseDB() {
        if (this.dbHandle) {
            DllCall("sqlite3.dll\sqlite3_close", "Ptr", this.dbHandle, "Cdecl Int")
            this.dbHandle := 0
        }
    }
    __Delete() {
        this.CloseDB()
        if (this.hModule) {
            DllCall("FreeLibrary", "Ptr", this.hModule)
            this.hModule := 0
        }
    }
}