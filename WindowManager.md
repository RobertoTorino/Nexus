# WindowManager

### The main buttons:

| #  | Button           | Description                                       |
|----|------------------|---------------------------------------------------|
| 1  | **Select**       | **Select the executable.**                        |
| 2  | **Launch**       | **Launch the selected executable.**               |
| 3  | **Scan**         | **Scan for windows or refresh the windows list.** |
| 4  | **Reset All**    | **Reset to default.**                             |
| 5  | **Monitor 1**    | **Switch to monitor 1.**                          |
| 6  | **Monitor 2**    | **Switch to monitor 2.**                          |
| 7  | **Stability**    | **Make sure the correct monitor is selected.**    |
| 8  | **Kill Process** | **Shutdown the executable**                       |
| 9  | **Focus**        | **Bring back focus to the exe when lost.**        |
| 10 | **Config**       | **Inspect the saved settings.**                   |

### The main windows screen:
Here all windows used by the executable are shown, after selecting a window actions can be performed on it.
The columns represent the window properties and status.

| #  | Button                 | Description                                              |
|----|------------------------|----------------------------------------------------------|
| 1  | **Destroy**            | **Destroys the selected window.**                        |
| 2  | **Hidden**             | **Hide the selected window.**                            |
| 3  | **Show**               | **Shows the selected window.**                           |
| 4  | **Minimized**          | **Minimizes the selected window.**                       |
| 5  | **Maximized**          | **Maximizes the selected window.**                       |
| 6  | **Windowed**           | **Show the selected window in windowed modus.**          |
| 7  | **True Borderless FS** | **Fullscreen without any borders.**                      |
| 8  | **Move App - Monitor** | **Switch between monitors with the app.**                |
| 9  | **Restore**            | **Restores the selected screen to it's original state.** |
| 10 | **Fit Screen**         | **Make sure the whole screen is used.**                  |
| 11 | **Topmost**            | **Bring the selected screen to the front.**              |


### Predefined sizes available in the app mainly for testing purposes:

| #   | Name                    | Screen Resolution | Browser Viewport     | 
|-----|-------------------------|-------------------|----------------------|
| 1️⃣ | **Full HD (FHD)**       | **1920 × 1080**   | **≈ 1536 × 754 px**  | 
| 2️⃣ | **Quad HD (QHD / 2K)**  | **2560 × 1440**   | **≈ 2304 × 1216 px** | 
| 3️⃣ | **4K Ultra HD (UHD)**   | **3840 × 2160**   | **≈ 3200 × 1728 px** | 
| 4️⃣ | **5K**                  | **5120 × 2880**   | **≈ 4480 × 2592 px** | 
| 5️⃣ | **6K**                  | **6016 × 3384**   | **≈ 5376 × 3096 px** | 
| 6️⃣ | **8K Ultra HD (UHD-2)** | **7680 × 4320**   | **≈ 7040 × 4032 px** | 


### Common Window Modes (High-Level, User-Facing)

| #   | Mode           | Description                                                                        | Notes                                  |
|-----|----------------|------------------------------------------------------------------------------------|----------------------------------------|
| 1️⃣ | **Fullscreen** | **Covers the entire screen, often exclusive mode for games.**                      | **Usually removes borders/title bar.** |
| 2️⃣ | **Windowed**   | **Standard resizable window with title bar and borders.**                          | **Can be moved, resized.**             |
| 3️⃣ | **Borderless** | **Windowed Fullscreen	Looks fullscreen but technically a window without borders.** | **Easier alt-tabbing.**                |
| 4️⃣ | **Hidden**     | **Window exists but is invisible.**                                                | **Uses SW_HIDE.**                      |


### Window States (WinAPI / How Windows Manages Visibility)

| #   | State                 | WinAPI constant                             | Description                                         |
|-----|-----------------------|---------------------------------------------|-----------------------------------------------------|
| 1️⃣ | **Normal / Restored** | **SW_SHOWNORMAL / SW_RESTORE**              | **Standard window size, not minimized/maximized.**  |
| 2️⃣ | **Minimized**         | **SW_MINIMIZE**                             | **Shrunk to taskbar; can still receive messages.**  |
| 3️⃣ | **Maximized**         | **SW_SHOWMAXIMIZED**                        | **Easier alt-tabbing.**                             |
| 4️⃣ | **Hidden**            | **SW_HIDE**                                 | **Window exists but invisible.**                    |
| 5️⃣ | **Shown / Activated** | **SW_SHOW / SW_SHOWNA / SW_SHOWNOACTIVATE** | **Fills the screen but retains borders/title bar.** | 


### Window Styles (Fine-Grained Appearance / Behavior)

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


### Extended Window Styles (Extra Options)

| #   | Style                | Description                                                   | 
|-----|----------------------|---------------------------------------------------------------|
| 1️⃣ | **WS_EX_TOPMOST**    | **Covers the entire screen, often exclusive mode for games.** |
| 2️⃣ | **WS_EX_TOOLWINDOW** | **Small title bar, often used for floating tool windows.**    | 
| 3️⃣ | **WS_EX_APPWINDOW**  | **Forces a window to appear in the taskbar.**                 |
| 4️⃣ | **WS_EX_NOACTIVATE** | **Window shows without stealing focus.**                      |
| 5️⃣ | **WS_EX_LAYERED**    | **Allows transparency and alpha blending.**                   |
