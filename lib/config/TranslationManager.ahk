#Requires AutoHotkey v2.0
; ==============================================================================
; * @description Dictionary for UI Translation (EN, CN, JP, IT, ES).
; * @class TranslationManager
; * @location lib/config/TranslationManager.ahk
; * @author Philip
; * @date 2026/01/25
; * @version 1.0.00
; ==============================================================================

; --- DEPENDENCY IMPORTS ---
; None

class TranslationManager {
    static CurrentLang := "EN"

    ; Cycle Order
    static Languages := ["EN", "CN", "JP", "IT", "ES"]

    static Cycle() {
        currentIndex := 0
        for i, lang in this.Languages {
            if (lang == this.CurrentLang) {
                currentIndex := i
                break
            }
        }

        nextIndex := currentIndex + 1
        if (nextIndex > this.Languages.Length)
            nextIndex := 1

        this.CurrentLang := this.Languages[nextIndex]
        return this.CurrentLang
    }

    ; Returns just the text code (EN, IT, etc.)
    static GetCurrentCode() {
        return this.CurrentLang
    }

    static T(text) {
        if (this.CurrentLang == "EN")
            return text

        clean := Trim(text)

        if (this.Dictionary.Has(this.CurrentLang) && this.Dictionary[this.CurrentLang].Has(clean)) {
            translation := this.Dictionary[this.CurrentLang][clean]
            return StrReplace(text, clean, translation)
        }
        return text
    }

    ; --- DICTIONARY ---
    static Dictionary := Map(
        "CN", Map("Set Launch Path", "设置启动路径", "Profiles", "配置文件", "Delete Game", "删除游戏", "Emulators", "模拟器", "Clear Path", "清除路径", "Restore Path", "恢复路径", "Window Manager", "窗口管理", "Focus", "聚焦窗口", "Music", "音乐", "Video", "视频", "Gallery", "画廊", "Database", "数据库", "Notes", "备注", "Browser", "浏览器", "Rec Audio", "录制音频", "Rec Video", "录制视频", "Icon Manager", "图标管理", "Idle", "空闲", "Normal", "正常", "High", "高优", "Realtime", "实时", "Clone Wizard", "克隆向导", "Patch Manager", "补丁管理", "Purge Logs", "清除日志", "Purge List", "清空列表", "View Logs", "查看日志", "Show Games Config", "游戏配置", "View System Config", "系统配置", "Hide Advanced", "隐藏高级", "Show Advanced Utilities", "显示高级工具"),
        "JP", Map("Set Launch Path", "起動パス設定", "Profiles", "プロファイル", "Delete Game", "削除", "Emulators", "エミュレータ", "Clear Path", "パス消去", "Restore Path", "パス復元", "Window Manager", "ウィンドウ管理", "Focus", "フォーカス", "Music", "音楽", "Video", "ビデオ", "Gallery", "ギャラリー", "Database", "データベース", "Notes", "メモ", "Browser", "ブラウザ", "Rec Audio", "録音", "Rec Video", "録画", "Icon Manager", "アイコン", "Idle", "低", "Normal", "通常", "High", "高", "Realtime", "リアルタイム", "Clone Wizard", "クローン作成", "Patch Manager", "パッチ管理", "Purge Logs", "ログ消去", "Purge List", "リスト消去", "View Logs", "ログ表示", "Show Games Config", "ゲーム設定", "View System Config", "システム設定", "Hide Advanced", "詳細を隠す", "Show Advanced Utilities", "詳細ツールを表示"),
        "IT", Map("Set Launch Path", "Imposta Percorso", "Profiles", "Profili", "Delete Game", "Elimina", "Emulators", "Emulatori", "Clear Path", "Pulisci", "Restore Path", "Ripristina", "Window Manager", "Gestione Finestre", "Focus", "Focus", "Music", "Musica", "Video", "Video", "Gallery", "Galleria", "Database", "Database", "Notes", "Note", "Browser", "Esplora", "Rec Audio", "Reg. Audio", "Rec Video", "Reg. Video", "Icon Manager", "Icone", "Idle", "Minimo", "Normal", "Normale", "High", "Alto", "Realtime", "Realtime", "Clone Wizard", "Clonazione", "Patch Manager", "Gestione Patch", "Purge Logs", "Pulisci Log", "Purge List", "Svuota Lista", "View Logs", "Vedi Log", "Show Games Config", "Config Giochi", "View System Config", "Config Sistema", "Hide Advanced", "Nascondi Avanzate", "Show Advanced Utilities", "Mostra Utilità"),
        "ES", Map("Set Launch Path", "Ruta de Juego", "Profiles", "Perfiles", "Delete Game", "Borrar", "Emulators", "Emuladores", "Clear Path", "Limpiar", "Restore Path", "Restaurar", "Window Manager", "Ventanas", "Focus", "Enfocar", "Music", "Música", "Video", "Video", "Gallery", "Galería", "Database", "Base de Datos", "Notes", "Notas", "Browser", "Explorador", "Rec Audio", "Grabar Audio", "Rec Video", "Grabar Video", "Icon Manager", "Iconos", "Idle", "Inactivo", "Normal", "Normal", "High", "Alto", "Realtime", "Tiempo Real", "Clone Wizard", "Clonar", "Patch Manager", "Parches", "Purge Logs", "Borrar Logs", "Purge List", "Borrar Lista", "View Logs", "Ver Logs", "Show Games Config", "Config Juegos", "View System Config", "Config Sistema", "Hide Advanced", "Ocultar Avanzado", "Show Advanced Utilities", "Mostrar Utilidades")
    )
}