#Requires AutoHotkey v2.0

TM_Lang_JP() {
    return Map(
        ; --- EXISTING UI ---
        "Set Launch Path", "起動パス設定",
        "Profiles", "プロファイル",
        "Delete Game", "削除",
        "Emulators", "エミュレータ",
        "Clear Path", "パス消去",
        "Restore Path", "パス復元",
        "Window Manager", "ウィンドウ管理",
        "Focus", "フォーカス",
        "Music", "音楽",
        "Video", "ビデオ",
        "Gallery", "ギャラリー",
        "Database", "データベース",
        "Notes", "メモ",
        "Browser", "ブラウザ",
        "Rec Audio", "録音",
        "Rec Video", "録画",
        "Icon Manager", "アイコン",
        "Idle", "低",
        "Normal", "通常",
        "High", "高",
        "Realtime", "リアルタイム",
        "Clone Wizard", "クローン作成",
        "Patch Manager", "パッチ管理",
        "Purge Logs", "ログ消去",
        "Purge List", "リスト消去",
        "Wipe List", "リスト消去",
        "View Logs", "ログ表示",
        "Show Games Config", "ゲーム設定",
        "View System Config", "システム設定",
        "AT3 Convert", "AT3 変換",
        "RPCS3 Audio Fix", "RPCS3 音声修正",
        "Pad Test", "パッドテスト",
        "Hash Calc / Validator", "ハッシュ計算",
        "Wipe Full List", "リスト完全消去", ; <--- NEW
        "Hide Advanced", "詳細を隠す",
        "Show Advanced Utilities", "詳細ツールを表示",
        "Patch Game", "パッチ適用",

        ; --- NEW GALLERY KEYS ---
        "Previous", "前へ", "Next", "次へ", "Slideshow", "スライドショー", "Browse", "参照", "Delete", "削除",
        "Image", "画像", "Path", "パス", "Size", "サイズ",
        "GALLERY_HELP_1", "スペースキーでスライドショーを開始。",
        "GALLERY_HELP_2", "ダブルクリックで全画面表示。",
        "GALLERY_HELP_3", "全画面時に M でモニター切替。",
        "GALLERY_HELP_4", "DELETE キーで画像を削除。",

            "HELP_TEXT_GAMEPAD", "
            (
         軸の説明（Xbox 360 エミュレーション）

         X と Y：左スティック
         • X：水平（0=左、50=中央、100=右）
         • Y：垂直（0=上、50=中央、100=下）

         R：右スティック（垂直）
         • 通常は 50 で、0 または 100 に向かって動きます。

         Z：L2 / R2 トリガー
         • 両トリガーはこの 1 本の軸を共有します。
         • 50 = どちらも押していない（または同程度に押している）
         • 100 = 左トリガー（L2）を最大まで押下
         • 0 = 右トリガー（R2）を最大まで押下

         POV：D-Pad（POV ハット）
         • 角度を「度 × 100」で表示します。
         • -1 = 未入力
         • 0 = 上
         • 9000 = 右
         • 18000 = 下
         • 27000 = 左
            )",

        ; --- HELP TEXT ---
        "HELP_TEXT_MAIN", "
        (
1. ゲームパスの追加:
   - '起動パス設定' をクリックして実行ファイルを追加します。
   - TeknoParrot の場合は 'プロファイル' を選択してください。

2. エミュレータ:
   - 'エミュレータ' をクリックしてパスを設定します。

3. ゲームの実行:
   - .ISO/EBOOT.BIN を選択するとエミュレータを尋ねられます。
   - リストから選択して ▶️ をクリックします。

4. ゲーム中:
   - 'ウィンドウ管理' でウィンドウを操作します。
   - CPUボタンでラグを修正します。
   - バースト機能で連続スクリーンショットを撮影できます。

5. 録画・録音:
   - 音声のみ、または音声付きビデオを録画します。

6. ツール:
   - Atrac3 変換: 音声を WAV に変換。
   - ファイル検証: ISO のハッシュチェック。
   - データベース検索。

7. ホットキー:
   - Escape: ゲーム終了。
  - Escape+1: ハードリセット。
  - Control+L: ログ表示。
   - F8: 音声コマンドカタログを有効化。
  - Ctrl+Alt+F9: キャプチャモードで ffmpeg ターミナルを表示。
  - Ctrl+Alt+F10: ffmpeg ログを表示。
   - CTRL+SHIFT+A: オーディオマネージャーを開く。

8. クイック起動:
   - トレイアイコンを右クリック。
   - タイトルバーをダブルクリックでテキストモード切替。

9. マグネットウィンドウ:
   - Controlキーを押しながらドラッグで分離。

T. トラブルシューティング:
   - 再起動ボタンでリブート。
   - エラーはログを確認してください。
        )"
    )
}
