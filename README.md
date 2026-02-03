# Nexus (Nexus)
![NEXUS-rounded-corners.png](media/nexus/NEXUS-rounded-corners.png)

#### The app was created to get a perfect fitting full screen when running a game and to make it easy switching a game window between monitor 1 and monitor 2.                    


## Summary of the NEXUS logic:
* Boot: Nexus.ahk calls ConfigManager.Init().
* Memory: nexus.json is parsed into a high-speed Map in RAM.
* UI: GuiBuilder asks ConfigManager for the list and displays it instantly.
* Launch: When you click Start, StartGame() gets the full game object from RAM (including IsPatchable: true).
* Patch: If patchable, the PatchService handles this.


**In Windows:**                 
* Display settings for both monitors should be at 100%.                      
* Resolution should be set to 1920x1080.                     
* Make sure the refresh rate on both monitors is equal, for instance 60Hz.            

**Game settings:**              
If in-game display settings are available use borderless (preferred). See examples in the media folder.                     

_Note: some games launch differently they have their own dedicated screen manager app._

**Statistics**
Number of games, play time, total played time and top3 played data are collected to be able to show them in the main UI. Basic system info is collected. Personal data is never collected. Data is only stored locally within the users app environment.

### Nexus Main Gui
![NEXUS-main-ui.png](media/nexus/NEXUS-main-ui.png)

#### Basic instructions:
Place Nexus in a central location.

## Game window features:
* Window management.
* True borderless fullscreen window.
* Reposition the game window.
* Easy move window between monitors.

Game Features:
* Run all games, .iso. .cso, pbp, eboot.bin, .bat, .xml, .exe.
* Run RPCS3 games direct in fullscreen mode skipping the frontend.
* Run PCSX2 games direct in fullscreen mode skipping the frontend.
* Run PPSSPP games direct in fullscreen mode skipping the frontend.
* Run DuckStation games direct in fullscreen mode skipping the frontend.
* Run games that only run through a .bat file.
* Autodetect TeknoParrot game profiles and run the game in fullscreen.
* Manage emulator profiles.
* Patch EBOOT.BIN and clone game.
* Run Arcade games that need special versions of RPCS3.
* Save games for quick re-run.

Process:
* Change CPU process priority.
* RAM usage overview, system, app and game.
* GPU overclock with Afterburner

Media:
* Take snapshots + burst snapshots (max. 99).
* Audio recording.
* Music player (uses legacy Windows Media Player).
* Video capture.
* Video player (loads external player).
* Image viewer.
* And more...


**Phantom windows, JConfig, Settings**                    
With the combination of positioning and resizing you can achieve a perfect full screen window.                                                  
Check the settings folder for some of the (JConfig) screen settings that gave me the basis for a perfect screen.                                           
Some games have phantom windows (sometimes more than one, good examples are Dead or Alive 5 and Tekken 7).
"Manage All Windows" shows an overview of windows which can be managed.  

Other sizes available for test purposes, examples:                    

| #   | Name                    | Screen Resolution | Browser Viewport     | 
|-----|-------------------------|-------------------|----------------------|
| 1️⃣ | **Full HD (FHD)**       | **1920 × 1080**   | **≈ 1536 × 754 px**  | 
| 2️⃣ | **Quad HD (QHD / 2K)**  | **2560 × 1440**   | **≈ 2304 × 1216 px** | 
| 3️⃣ | **4K Ultra HD (UHD)**   | **3840 × 2160**   | **≈ 3200 × 1728 px** | 
| 4️⃣ | **5K**                  | **5120 × 2880**   | **≈ 4480 × 2592 px** | 
| 5️⃣ | **6K**                  | **6016 × 3384**   | **≈ 5376 × 3096 px** | 
| 6️⃣ | **8K Ultra HD (UHD-2)** | **7680 × 4320**   | **≈ 7040 × 4032 px** | 


## Common Window Modes (High-Level, User-Facing)

| #   | Mode           | Description                                                                        | Notes                                  |
|-----|----------------|------------------------------------------------------------------------------------|----------------------------------------|
| 1️⃣ | **Fullscreen** | **Covers the entire screen, often exclusive mode for games.**                      | **Usually removes borders/title bar.** |
| 2️⃣ | **Windowed**   | **Standard resizable window with title bar and borders.**                          | **Can be moved, resized.**             |
| 3️⃣ | **Borderless** | **Windowed Fullscreen	Looks fullscreen but technically a window without borders.** | **Easier alt-tabbing.**                |
| 4️⃣ | **Hidden**     | **Window exists but is invisible.**                                                | **Uses SW_HIDE.**                      |


## Window States (WinAPI / How Windows Manages Visibility)

| #   | State                 | WinAPI constant                             | Description                                         |
|-----|-----------------------|---------------------------------------------|-----------------------------------------------------|
| 1️⃣ | **Normal / Restored** | **SW_SHOWNORMAL / SW_RESTORE**              | **Standard window size, not minimized/maximized.**  |
| 2️⃣ | **Minimized**         | **SW_MINIMIZE**                             | **Shrunk to taskbar; can still receive messages.**  |
| 3️⃣ | **Maximized**         | **SW_SHOWMAXIMIZED**                        | **Easier alt-tabbing.**                             |
| 4️⃣ | **Hidden**            | **SW_HIDE**                                 | **Window exists but invisible.**                    |
| 5️⃣ | **Shown / Activated** | **SW_SHOW / SW_SHOWNA / SW_SHOWNOACTIVATE** | **Fills the screen but retains borders/title bar.** | 


## Window Styles (Fine-Grained Appearance / Behavior)

| #   | Style                          | Description                                                           |
|-----|--------------------------------|-----------------------------------------------------------------------|
| 1️⃣ | **WS_OVERLAPPEDWINDOW**        | **Typical app window: border, title bar, minimize/maximize buttons.** |
| 2️⃣ | **WS_POPUP**                   | **Borderless window, often used for fullscreen.**                     |
| 3️⃣ | **WS_BORDER**                  | **Thin border around the window.**                                    |
| 4️⃣ | **WS_CAPTION**                 | **Adds title bar.**                                                   |
| 5️⃣ | **WS_SYSMENU**                 | **Adds system menu (icon, close button).**                            |
| 6️⃣ | **WS_MINIMIZEBOX**             | **Adds minimize/maximize buttons.**                                   |
| 7️⃣ | **WS_SIZEBOX / WS_THICKFRAME** | **Allows resizing by dragging edges.**                                |
| 8️⃣ | **WS_DISABLED**                | **Window cannot receive input.**                                      |
| 9️⃣ | **WS_VISIBLE**                 | **Initially visible.**                                                |

These styles can be combined to achieve modes like “borderless windowed” or “fullscreen windowed.”


## Extended Window Styles (Extra Options)

| #   | Style                | Description                                                   | 
|-----|----------------------|---------------------------------------------------------------|
| 1️⃣ | **WS_EX_TOPMOST**    | **Covers the entire screen, often exclusive mode for games.** |
| 2️⃣ | **WS_EX_TOOLWINDOW** | **Small title bar, often used for floating tool windows.**    | 
| 3️⃣ | **WS_EX_APPWINDOW**  | **Forces a window to appear in the taskbar.**                 |
| 4️⃣ | **WS_EX_NOACTIVATE** | **Window shows without stealing focus.**                      |
| 5️⃣ | **WS_EX_LAYERED**    | **Allows transparency and alpha blending.**                   |


---

## Capture audio

I used some additional tools for this:                 
* Voicemeeter Banana: [voicemeeter](https://vb-audio.com/Voicemeeter/potato.htm)
* Vgmstream: [vgmstream](https://vgmstream.org/)
* Ffmpeg: [ffmpeg](https://www.gyan.dev/ffmpeg/builds/ffmpeg-git-full.7z")

### Other tools used
* SoundVolumeView: [SoundVolumeView](https://www.nirsoft.net/utils/sound_volume_view.html)

Voicemeeter makes it possible to reroute your audio streams so you can listen to the audio that is being recorded.   
In Voicemeeter Basic, FFmpeg must record a B-bus (B1/B2/B3), and audio only reaches that bus if you explicitly enable it on the Virtual Input strip.
That's why I prefer Voicemeeter Banana.
My settings for Voicemeeter Banana:

#### Hardware Out
* A1: Mi TV -2 (Intel(R) Display Audio) - This is sound from my 2nd monitor (a TV) connected with my laptop through HDMI.
* A2: Speakers (Realtek High Definition Audio) - Laptop sound.
* A3: Headset Microphone (3- Wireless Controller)

#### Virtual Input
* Voicemeeter Input (left column): A1 - B1 
* Here you control your output by selecting A1, A2 or A3. A1 is TV, A2 is Speakers and A3 is Headset.
* Voicemeeter AUX (right column): A1 - B1

#### Windows Sound Settings
In Windows Go to Settings/System/Sound and set this:              
* Output: Voicemeeter Input
* Input: Voicemeeter Out B1

#### Example of My Audio devices
* Mi TV -2 (Intel(R) Display Audio)
* Microphone (Realtek High Definition Audio)
* Speakers (Realtek High Definition Audio)
* Headset Microphone (Wireless Controller)
* Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO) = Default Input.   
* Voicemeeter Out B2 (VB-Audio Voicemeeter VAIO)
* Voicemeeter Out B3 (VB-Audio Voicemeeter VAIO)
* Voicemeeter Out A3 (VB-Audio Voicemeeter VAIO)
* Voicemeeter Out A4 (VB-Audio Voicemeeter VAIO)
* Voicemeeter Out A2 (VB-Audio Voicemeeter VAIO)
* Voicemeeter Out A5 (VB-Audio Voicemeeter VAIO)
* Voicemeeter Out A1 (VB-Audio Voicemeeter VAIO)


### List all audio devices
```powershell
./ffmpeg -list_devices true -f dshow -i dummy
```

## Overclock GPU
For use in this app, MSI Afterburner is used: [MSI Afterburner](https://www.msi.com/Landing/afterburner/graphics-cards)      

## Game ID's

| Game         | Year          | Namco System       | Compatible with RPCS3 (MD5)          | Firmware           | Location         | Original ID   | Custom ID     | 
|--------------|---------------|:-------------------|:-------------------------------------|:-------------------|:-----------------|---------------|---------------|
| **All**      | **2007-2012** | **System 357/369** | **18d4b31ada27856388c7ee9afd1172db** |                    |                  | **SCEEXE001** |               |
| **Tekken 6** | **2007**      | **System 357**     | **18d4b31ada27856388c7ee9afd1172db** | **Arcade FW 2.51** | `dev_hdd0\game\` | **SCEEXE001** | **SCEEXE001** |
| **Tekken 6** | **2007**      | **System 357**     | **18d4b31ada27856388c7ee9afd1172db** |                    | `dev_hdd0\game\` | **SCEEXE001** | **SCEEXE001** | 



3.1. SYSTEM 357
Tekken 6 (2007)
Tekken 6 BR (2008)
Time Crisis: Raging Storm (2009)
Deadstorm Pirates (2010)
Mobile Suit Gundam EXTREME VS ~ Mobile Suit Gundam EXTREME VS MAXI BOOST ON
Ancient Master Shin Moo -in ~ Blue (2011)
Dark Escape (2012)
3.2. SYSTEM 369
Tekken Tag Tournament 2 (2011)
Tekken Tag Tournament 2 Unlimited (2012)


## Custom Firmware
CEX (Customer/Retail Firmware): This is the standard, official firmware type for consumer PS3s, focused on regular game playing and features.
DEX (Developer Firmware): The firmware used on actual PlayStation 3 development kits, containing extra debugging tools and features.
PEX (PS3 Exploitable/Hybrid): PEX is a CEX firmware that includes developer modules (DEX kernel) and tools directly in the XMB, letting retail users access DEX features without fully converting.
D-PEX: The DEX equivalent of PEX, for systems already on DEX firmware.

For most users PEX is ideal as it gives you a retail (CEX) base with powerful DEX features built-in via the toolbox.
If you're already on a DEX system: D-PEX.
If you only want the pure, unmodified retail experience: CEX.



SCEEXE000=SCEEXE000
SCEEXE001=TEKKEN_6_2007
SCEEXE002=TEKKEN_6_BR_CN
SCEEXE003=TEKKEN_6_BR_JP
SCEEXE004=TEKKEN_TAG_TOURNAMENT_2
SCEEXE005=TEKKEN_TAG_TOURNAMENT_2_UNLIMITED
SCEEXE006=DRAGON_BALL_ZENKAI_BATTLE_ROYALE
SCEEXE007=TEKKEN_6_BR_CN_II


---
dev_hdd0\game\SCEEXE001
![Gamemanager.png](media/nexus.png)

![github.png](media/gh.png)                
**RobertoTorino**      

![qrcode_gh.png](media/qrcode-gh.png)

ToDo
These values represent the Virtual Desktop Coordinates of your screens. Windows treats all your monitors as one giant, continuous canvas.Here is the breakdown of your specific layout:Monitor 1 (Primary)L=0, T=0: This is the anchor point. Windows almost always defines the top-left corner of your Main Display as 0,0.W=1920, H=1080: This is a standard 1080p resolution screen.Monitor 2 (Secondary)L=-296: The left edge starts at X coordinate -296.T=-1440: The top edge starts at Y coordinate -1440.Meaning: This monitor is physically or logically positioned Above and slightly to the Left of your main monitor in Windows Display Settings.W=1707, H=960: This is an unusual resolution.Diagnosis: This is almost certainly a 1440p monitor (2560x1440) that has 150% Scaling enabled in Windows settings.Math: $2560 / 1.5 = 1706.66$ (rounded to 1707) and $1440 / 1.5 = 960$.Visualizing Your LayoutIn Windows, your screens are arranged roughly like this:Why this matters for your code:If you try to move a window to Monitor 2 using standard coordinates (like 0,0), it will land on Monitor 1. To move a window to Monitor 2, you must send it to x: -296, y: -1440.





---

The Layout: Vertical Stack
Your monitors are now perfectly aligned effectively "on top" of each other.

Monitor 1 (Bottom/Primary): Starts at 0, 0.

Monitor 2 (Top): Starts at 0, -1080.

Because its height is 1080, its bottom edge (-1080 + 1080 = 0) touches the top edge of Monitor 1 perfectly.

Why this is better
No Scaling Weirdness: Both monitors report exactly 1920 x 1080. This means either your Windows Scaling is set to 100%, or our DPI Awareness code from earlier is working perfectly. This ensures your GUI won't look blurry or sized incorrectly.

Perfect Alignment: Both Left values are 0. This makes calculating window positions incredibly easy math-wise.
These values represent the Virtual Desktop Coordinates of your screens. Windows treats all your monitors as one giant, continuous canvas.

Here is the breakdown of your specific layout:

Monitor 1 (Primary)
L=0, T=0: This is the anchor point. Windows almost always defines the top-left corner of your Main Display as 0,0.

W=1920, H=1080: This is a standard 1080p resolution screen.

Monitor 2 (Secondary)
L=-296: The left edge starts at X coordinate -296.

T=-1440: The top edge starts at Y coordinate -1440.

Meaning: This monitor is physically or logically positioned Above and slightly to the Left of your main monitor in Windows Display Settings.

W=1707, H=960: This is an unusual resolution.

Diagnosis: This is almost certainly a 1440p monitor (2560x1440) that has 150% Scaling enabled in Windows settings.

Math: 2560/1.5=1706.66 (rounded to 1707) and 1440/1.5=960.

Visualizing Your Layout
In Windows, your screens are arranged roughly like this:

Why this matters for your code: If you try to move a window to Monitor 2 using standard coordinates (like 0,0), it will land on Monitor 1. To move a window to Monitor 2, you must send it to x: -296, y: -1440.
How to target Monitor 2 now
If you want to send a window (like a game or the emulator config) to the top monitor, you simply move it to negative Y coordinates.

Move to Monitor 1: x: 0, y: 0

Move to Monitor 2: x: 0, y: -1080

If you ever need to "hardcode" a position for the top screen in your scripts, use:

AutoHotkey
; Example: Move active window to Top Monitor
WinMove(0, -1080, 1920, 1080, "A")


Example overscan"

That result is mathematically perfect based on how your screen geometry and the overscan logic work. Here is the breakdown of those numbers, assuming you are on a 1920x1080 monitor:1. The Width and X-Axis (Horizontal)When you applied 200px of Horizontal Overscan:WinW (2120): This is $1920 \text{ (Monitor Width)} + 200 \text{ (Overscan)}$.WinX (-100): To keep the image centered, the script pushes the window left by half of the overscan. $0 - (200 / 2) = -100$. This hides 100 pixels off the left edge and 100 pixels off the right edge.2. The Height and Y-Axis (Vertical)This is where your manual "Down" nudge and the Vertical Overscan combined:WinH (1280): This is $1080 \text{ (Monitor Height)} + 200 \text{ (Overscan)}$.WinY (-80): * Initially, applying 200px Vertical Overscan moves the Y to -100 ($0 - (200 / 2)$) to center it.You then nudged the window Down by 20px.$-100 \text{ (Initial Y)} + 20 \text{ (Nudge)} = -80$.

---

Property,Base (1080p),Overscan (+200),Nudge (+20),Final JSON
Width,1920,+200,0,2120
Height,1080,+200,0,1280
X Pos,0,-100 (centered),0,-100
Y Pos,0,-100 (centered),+20 (down),-80


----


1. Will the Patch Logic work?
   Yes, absolutely.

Based on the PatchServiceTool.ahk code you provided earlier, the logic is designed exactly for your Tekken 6 use case.
It detects the game: It looks for EBOOT.BIN (or the folder structure).
It checks the current state: It calculates the CRC32 (Hash) of the VER.206 file currently in the game folder to see if you are in "Test Mode", "Normal Mode", or "Unknown".
It swaps the file: When you click the button in the popup, it copies the specific VER.206 from your patches/t6br folder and overwrites the one in the game folder.
Launch: When you click Run/Play on the main UI, the emulator (RPCS3) launches the game. Since the file is already physically swapped on the disk, the game loads into the mode you selected.
You do not need a separate launcher. The "Patch" button acts as your mode switcher.
