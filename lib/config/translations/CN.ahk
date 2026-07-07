#Requires AutoHotkey v2.0

TM_Lang_CN() {
    return Map(
        ; --- EXISTING UI ---
        "Set Launch Path", "设置启动路径",
        "Profiles", "配置文件",
        "Delete Game", "删除游戏",
        "Emulators", "模拟器",
        "Clear Path", "清除路径",
        "Restore Path", "恢复路径",
        "Window Manager", "窗口管理",
        "Focus", "聚焦窗口", "Music",
        "音乐", "Video", "视频",
        "Gallery", "画廊",
        "Database", "数据库",
        "Notes", "备注",
        "Browser", "浏览器",
        "Rec Audio", "录制音频",
        "Rec Video", "录制视频",
        "Icon Manager", "图标管理",
        "Idle", "空闲",
        "Normal", "正常",
        "High", "高优",
        "Realtime", "实时",
        "Clone Wizard", "克隆向导",
        "Patch Manager", "补丁管理",
        "Purge Logs", "清除日志",
        "Purge List", "清空列表",
        "Wipe List", "清空列表",
        "View Logs", "查看日志",
        "Show Games Config", "游戏配置",
        "View System Config", "系统配置",
      "Sound Manager", "声音管理器",
      "Emulator Audio Config", "模拟器音频配置",
      "Hardware Output Mapping", "硬件输出映射",
      "Route Game Audio (Strip 3)", "路由游戏音频（第3轨）",
      "Capture Backend", "采集后端",
      "Backend:", "后端：",
      "Save", "保存",
      "Refresh Device List ↻", "刷新设备列表 ↻",
      "Clear", "清除",
      "Mute", "静音",
      "Hard Reset (Relaunch VoiceMeeter App)", "硬重置（重启 VoiceMeeter）",
      "Out A1", "A1输出",
      "Out A2", "A2输出",
      "Out A3", "A3输出",
      "Install Loopback Helper", "安装回环助手",
      "Test Loopback 3s", "3秒回环测试",
      "Help", "帮助",
      "Check for Updates", "检查更新",
      "Choose an option", "请选择一个选项",
      "Status:", "状态：",
      "Ready", "就绪",
      "Saved backend:", "已保存后端：",
      "Capture backend saved:", "采集后端已保存：",
      "Loopback helper installed", "回环助手已安装",
      "Loopback install failed", "回环助手安装失败",
      "Install Error", "安装错误",
      "Could not install loopback helper.", "无法安装回环助手。",
      "FFmpeg missing", "未找到 FFmpeg",
      "Capture Test", "采集测试",
      "FFmpeg missing:", "缺少 FFmpeg：",
      "Loopback helper missing", "缺少回环助手",
      "Loopback helper is missing and could not be installed.", "缺少回环助手且无法自动安装。",
      "Running 3s loopback test...", "正在运行3秒回环测试...",
      "Loopback test saved:", "回环测试已保存：",
      "Loopback test capture saved", "回环测试录音已保存",
      "Loopback test failed", "回环测试失败",
      "Loopback test failed. No valid output file was generated.", "回环测试失败，未生成有效输出文件。",
      "Update check finished", "更新检查完成",
      "Update Check", "更新检查",
      "Update Decision", "更新选择",
      "Apply All Updates", "应用全部更新",
      "Install Helper", "安装助手",
      "Download FFmpeg", "下载 FFmpeg",
      "Download Nexus", "下载 Nexus",
      "Skip", "跳过",
      "Helper local", "助手本地版本",
      "FFmpeg local", "FFmpeg 本地版本",
      "Nexus local", "Nexus 本地版本",
      "Latest", "最新",
      "Stable", "稳定版",
      "Nightly", "夜间版",
      "Selected release", "选定版本",
      "None", "无",
      "AT3 Convert", "AT3 转换",
      "Sound Manager", "声音管理器",
        "Pad Test", "测试手柄",
        "Hash Calc / Validator", "哈希校验",
        "Wipe Full List", "清空完整列表", ; <--- NEW
        "Hide Advanced", "隐藏高级",
        "Show Advanced Utilities", "显示高级工具",
        "Patch Game", "应用补丁",
      "BUILD PS5 LINUX IMAGE", "构建 PS5 Linux 镜像",
      "Open Balena Etcher", "打开 Balena Etcher",
      "Open Build Guide", "打开构建指南",
      "Build PS5 Linux image subtitle", "先在 WSL 中构建 PS5 Linux 镜像，然后用 Balena Etcher 刷写 .img 文件。",

        ; --- NEW GALLERY KEYS ---
        "Previous", "上一张", "Next", "下一张", "Slideshow", "幻灯片", "Browse", "浏览", "Delete", "删除",
        "Image", "图片", "Path", "路径", "Size", "大小",
        "GALLERY_HELP_1", "按空格键开始全屏幻灯片。",
        "GALLERY_HELP_2", "双击图片进入全屏模式。",
        "GALLERY_HELP_3", "全屏时按 M 键切换显示器。",
        "GALLERY_HELP_4", "按 DELETE 键删除图片。",

        "HELP_TEXT_SOUND_MANAGER", "
        (
1. 声音模式：
   - Auto 会优先使用回环助手。
   - Loopback 会捕获当前 Windows 默认播放设备的音频。
   - DShow 使用你配置的直接输入设备。
   - Voicemeeter 保留旧的路由流程。

2. Windows 声音设置：
   - 将默认输出设备设为你想听到声音的扬声器或耳机。
   - 将麦克风保持为语音命令使用的输入设备。
   - 如果播放设备不是默认设备，请切换到 DShow 或 Voicemeeter。

3. 回环助手：
   - 如果内置助手缺失，点击“安装回环助手”。
   - 点击“3秒回环测试”确认系统音频正在被捕获。

4. 更新：
   - 使用更新检查按钮比较助手、FFmpeg 和 Nexus 本体。

5. 旧路由：
   - 对于仍需手动总线路由的用户，Voicemeeter 仍然可用。
        )",

      "HELP_TEXT_PS5_LINUX_IMAGE", "
      (
在 Windows 上自行构建镜像时，请先以管理员身份在 PowerShell 中执行以下命令安装 WSL：

   wsl --install

安装 Ubuntu。先查看可用发行版：

   wsl --list --online

然后安装：

   wsl --install Ubuntu-26.04

安装 Docker：

   sudo apt update
   sudo apt install docker.io -y
   sudo service docker start
   sudo usermod -aG docker $USER

接着克隆并构建：

   cd ~/
   git clone https://github.com/ps5-linux/ps5-linux-image
   cd ps5-linux-image
   chmod +x ./build_image.sh
   sudo bash ./build_image.sh --distro ubuntu2604

构建完成后的镜像位于：

   output/ps5-ubuntu2604.img

将镜像刷写到 USB：

- U 盘最低容量 64 GB，强烈建议使用外接 SSD。
- 下载 Balena Etcher（https://etcher.balena.io/），选择 .img 文件，
  选择你的 USB 设备，然后点击 Flash。
- 忽略系统弹出的格式化提示。
      )",

            "HELP_TEXT_GAMEPAD", "
            (
         轴说明（Xbox 360 模拟）

         X 与 Y：左摇杆
         • X：水平（0=左，50=中，100=右）
         • Y：垂直（0=上，50=中，100=下）

         R：右摇杆（垂直）
         • 静止时为 50，向 0 或 100 变化。

         Z：L2 / R2 扳机
         • 两个扳机共用这一条轴。
         • 50 = 都未按下（或两者按压程度相同）
         • 100 = 左扳机（L2）完全按下
         • 0 = 右扳机（R2）完全按下

         POV：方向键（POV Hat）
         • 显示角度值（度 × 100）。
         • -1 = 未按下
         • 0 = 上
         • 9000 = 右
         • 18000 = 下
         • 27000 = 左
            )",

        ; --- HELP TEXT ---
        "HELP_TEXT_MAIN", "
        (
1. 添加游戏路径:
   - 点击 '设置启动路径' 添加游戏主程序。
   - 对于 TeknoParrot，请在 '配置文件' 中选择游戏。

2. 模拟器:
   - 点击 '模拟器' 设置路径。

3. 运行游戏:
   - 选择 .ISO 或 EBOOT.BIN 时会询问使用哪个模拟器。
   - 或从列表中选择游戏并点击 ▶️。

4. 游戏运行时:
   - 使用 '窗口管理' 操作游戏窗口。
   - 使用 CPU 按钮修复卡顿。
   - '连拍' 可快速截图（最多99张）。

5. 录制:
   - 仅录制音频或录制带声音的视频。

6. 工具:
   - Atrac3 转换器：将 ATRAC3 音频转换为 WAV。
   - 文件验证器：检查 ISO 的 MD5/SHA1 哈希值。
   - 游戏搜索数据库。

7. 热键:
   - Escape 键：退出游戏。
  - Escape+1：硬重置。
  - Control+L：打开实时日志。
   - F8：启用语音命令目录。
  - Ctrl+Alt+F9：在捕获模式中显示 ffmpeg 终端。
  - Ctrl+Alt+F10：显示 ffmpeg 日志。
   - CTRL+SHIFT+A：打开音频管理器。

8. 快速启动:
   - 右键点击托盘图标进行快速启动。
   - 双击标题栏切换到文本模式。

9. 磁性窗口:
   - 按住 Control 键可将主界面分离。

T. 故障排除:
   - 要重启游戏，请使用 '重启游戏'。
   - 使用 '查看日志' 查找错误。
        )"
    )
}
