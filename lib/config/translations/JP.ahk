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
      "Sound Manager", "サウンド管理",
      "Emulator Audio Config", "エミュレータ音声設定",
      "Hardware Output Mapping", "ハードウェア出力割り当て",
      "Route Game Audio (Strip 3)", "ゲーム音声をルーティング (Strip 3)",
      "Capture Backend", "キャプチャバックエンド",
      "Backend:", "バックエンド：",
      "Save", "保存",
      "Refresh Device List ↻", "デバイス一覧を更新 ↻",
      "Clear", "クリア",
      "Mute", "ミュート",
      "Hard Reset (Relaunch VoiceMeeter App)", "ハードリセット（VoiceMeeter を再起動）",
      "Out A1", "A1 出力",
      "Out A2", "A2 出力",
      "Out A3", "A3 出力",
      "Install Loopback Helper", "ループバックヘルパーをインストール",
      "Test Loopback 3s", "3秒ループバックテスト",
      "Help", "ヘルプ",
      "Check for Updates", "更新を確認",
      "Choose an option", "項目を選択してください",
      "Status:", "状態：",
      "Ready", "準備完了",
      "Saved backend:", "保存したバックエンド：",
      "Capture backend saved:", "キャプチャバックエンドを保存しました：",
      "Loopback helper installed", "ループバックヘルパーをインストールしました",
      "Loopback install failed", "ループバックヘルパーのインストールに失敗しました",
      "Install Error", "インストールエラー",
      "Could not install loopback helper.", "ループバックヘルパーをインストールできませんでした。",
      "FFmpeg missing", "FFmpeg がありません",
      "Capture Test", "キャプチャテスト",
      "FFmpeg missing:", "FFmpeg がありません：",
      "Loopback helper missing", "ループバックヘルパーがありません",
      "Loopback helper is missing and could not be installed.", "ループバックヘルパーが見つからず、インストールできませんでした。",
      "Running 3s loopback test...", "3秒ループバックテストを実行中...",
      "Loopback test saved:", "ループバックテストを保存しました：",
      "Loopback test capture saved", "ループバックテストの保存に成功しました",
      "Loopback test failed", "ループバックテストに失敗しました",
      "Loopback test failed. No valid output file was generated.", "ループバックテストに失敗しました。有効な出力ファイルが生成されませんでした。",
      "Update check finished", "更新確認が完了しました",
      "Update Check", "更新確認",
      "Update Decision", "更新の選択",
      "Apply All Updates", "すべての更新を適用",
      "Install Helper", "ヘルパーをインストール",
      "Download FFmpeg", "FFmpeg をダウンロード",
      "Download Nexus", "Nexus をダウンロード",
      "Skip", "スキップ",
      "Helper local", "ヘルパーのローカル版",
      "FFmpeg local", "FFmpeg のローカル版",
      "Nexus local", "Nexus のローカル版",
      "Latest", "最新",
      "Stable", "安定版",
      "Nightly", "ナイトリー",
      "Selected release", "選択されたリリース",
      "None", "なし",
      "AT3 Convert", "AT3 変換",
        "Pad Test", "パッドテスト",
        "Hash Calc / Validator", "ハッシュ計算",
        "Wipe Full List", "リスト完全消去", ; <--- NEW
        "Hide Advanced", "詳細を隠す",
        "Show Advanced Utilities", "詳細ツールを表示",
      "Patch", "パッチ適用",
      "Wizard", "ウィザード",
      "Build PS5 Linux Image", "PS5 Linux イメージ作成",
      "Open Balena Etcher", "Balena Etcher を開く",
      "Open Build Guide", "ビルドガイドを開く",
      "Build PS5 Linux image subtitle", "WSL で PS5 Linux イメージをビルドし、Balena Etcher で .img を書き込みます。",

        ; --- NEW GALLERY KEYS ---
        "Previous", "前へ", "Next", "次へ", "Slideshow", "スライドショー", "Browse", "参照", "Delete", "削除",
        "Image", "画像", "Path", "パス", "Size", "サイズ",
        "GALLERY_HELP_1", "スペースキーでスライドショーを開始。",
        "GALLERY_HELP_2", "ダブルクリックで全画面表示。",
        "GALLERY_HELP_3", "全画面時に M でモニター切替。",
        "GALLERY_HELP_4", "DELETE キーで画像を削除。",

        "HELP_TEXT_SOUND_MANAGER", "
        (
1. オーディオモード:
   - Auto はまずループバックヘルパーを使います。
   - Loopback は現在の Windows 再生デバイスをキャプチャします。
   - DShow は設定した直接入力デバイスを使います。
   - Voicemeeter は従来のルーティングを維持します。

2. Windows のサウンド設定:
   - 既定の出力を、聞きたいスピーカーまたはヘッドセットに設定してください。
   - 音声コマンド用にマイクは入力のままにしてください。
   - 再生先が既定以外の場合は、DShow または Voicemeeter に切り替えてください。

3. ループバックヘルパー:
   - 内蔵ヘルパーがない場合は「ループバックヘルパーをインストール」をクリックします。
   - 「3秒ループバックテスト」でシステム音声がキャプチャされるか確認します。

4. 更新:
   - 更新確認ボタンでヘルパー、FFmpeg、Nexus を比較します。

5. レガシー配線:
   - 手動バスルーティングが必要な場合、Voicemeeter は引き続き利用できます。
        )",

      "HELP_TEXT_PS5_LINUX_IMAGE", "
      (
Windows で独自イメージを作成するには、まず管理者権限の PowerShell で次を実行して WSL をインストールします:

   wsl --install

Ubuntu をインストールします。まず利用可能なディストリビューションを確認:

   wsl --list --online

次にインストール:

   wsl --install Ubuntu-26.04

Docker をインストール:

   sudo apt update
   sudo apt install docker.io -y
   sudo service docker start
   sudo usermod -aG docker $USER

その後、クローンしてビルドします:

   cd ~/
   git clone https://github.com/ps5-linux/ps5-linux-image
   cd ps5-linux-image
   chmod +x ./build_image.sh
   sudo bash ./build_image.sh --distro ubuntu2604

完成したイメージは次に出力されます:

   output/ps5-ubuntu2604.img

USB にイメージを書き込み:

- 最小容量: 64 GB。外付け SSD を強く推奨します。
- Balena Etcher (https://etcher.balena.io/) をダウンロードし、.img ファイルを選択し、
  USB ドライブを選んで Flash をクリックします。
- フォーマットの警告メッセージは無視してください。
      )",

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
