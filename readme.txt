Nexus
I'm developing this massive helper tool called Nexus which assists in creating a smooth gaming experience.
The main focus is game window management with the goal to get a perfect fullscreen window on your monitor.
The second goal is to maintain specific emulator profiles and launcher profiles to make it very simple to run a game.
And all that without using the emulator gui, also make it smooth to run a game which uses for instance a .bat file to launch it.
Emulators used are among others PPSSPP, RPCS3, PCSX2, DuckStation, VITA3K, YUZU, Dolphin etc.
In the last few months I have completely refactored the app and migrated from AHKv1 to AHKv2.
AHKv2 is relatively new for me, so I need all the help I can get to make and keep! the app fast, robust, stable and safe.
I now try to maintain a strict architectural approach with logical grouped classes.
I also follow and try to maintain a strict very smooth Dark UX design, where all "ugly" default Window scrollbars,
borders, boxes, dropdown lists etc. are replaced, hidden or removed.
It also uses the snap and magnet logic to attach secondary windows to the main window.
It has a translation toggle and the main keywords are translated in Chinese, Japanese, Russian, French, Italian and Spanish.
It also makes use of voice commands where basic keywords can be used for example saying "start" to launch the current selected game.
The voice commands are also translated to the languages mentioned before.
It will be packed into an executable for distribution, I already started on the GitHub workflow for that.
Below you can find the structure of the app. The main app is Nexus.ahk and the main UI is GuiBuilder.ahk.
The first thing I want to look into is integrating the /lib/input/ControllerTester.ahk, it's half finished, it should mimic a DualShock 4 button layout.
If the controller is connected you can test the buttons, when pressing a button on the controller a quick flash appears
in the corresponding button in the UI, can you help me finish it and integrate it?
The second thing I want to fix is the video and audio recording which is broken now.
It is very important to always choose the most efficient and simple solution (KISS) with a minimal or preferable ZERO performance impact.
The GUI load time is around ~140ms now and I want to keep it that way.
Let me know what you need from me to get started.
