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
        "AT3 Convert", "AT3 转换",
        "RPCS3 Audio Fix", "RPCS3 音频修复",
        "Pad Test", "测试手柄",
        "Hash Calc / Validator", "哈希校验",
        "Wipe Full List", "清空完整列表", ; <--- NEW
        "Hide Advanced", "隐藏高级",
        "Show Advanced Utilities", "显示高级工具",
        "Patch Game", "应用补丁",

        ; --- NEW GALLERY KEYS ---
        "Previous", "上一张", "Next", "下一张", "Slideshow", "幻灯片", "Browse", "浏览", "Delete", "删除",
        "Image", "图片", "Path", "路径", "Size", "大小",
        "GALLERY_HELP_1", "按空格键开始全屏幻灯片。",
        "GALLERY_HELP_2", "双击图片进入全屏模式。",
        "GALLERY_HELP_3", "全屏时按 M 键切换显示器。",
        "GALLERY_HELP_4", "按 DELETE 键删除图片。",

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
