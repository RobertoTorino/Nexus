# Logic & Safety Review

Here is a 5-point checklist we followed to ensure it is safe and robust.

1. The "Space in Path" Vulnerability (Command Injection)
   The most common bug in launchers is when a file path contains spaces (e.g., C:\My Games\Silent Hill) and the command line treats it as two separate arguments.

- The Risk: The emulator might try to load C:\My instead of the game file, or worse, if someone places a malicious file named C:\My.exe, it could execute that.
- The Fix: Handle this by using Format() with quotes.
- Good: Run('"' emulatorPath '" "' gamePath '"') or using Format.
- Status: Launchers currently use Format('"{1}" ...'), so we are Safe here.


2. The "Infinite Loop" Trap (Logic Vulnerability)
   In AutoHotkey, if a loop (like a While loop waiting for a window) doesn't have a timeout or a Sleep, it can freeze the entire PC CPU to 100%.

- The Check: Look at every While or Loop in your code.
- The Rule: Every loop must have a Sleep() and a mechanism to Break (like a timeout counter).
- Status: TeknoParrotLauncher has a timeoutMs check, and StandardLauncher has a 15-second timer limit. We are Safe.


3. INI File Manipulation
   Your app trusts nexus.ini implicitly.

- The Risk: If you (or a script) accidentally edits nexus.ini and changes Pcsx2Path to C:\Windows\System32\cmd.exe /c del *.*, your launcher will happily execute it.
- The Mitigation: This is a local app, so we assume the user has control over their own PC. You don't need complex encryption, but you should ensure your DialogsGui don't crash if the INI contains garbage data.


4. Antivirus "False Positives"
   This is the biggest "vulnerability" for AHK developers.

- The Issue: AutoHotkey scripts that use Run, ProcessClose, and DllCall (for Window Manager) look very suspicious to Windows Defender and Avast.
- The Fix: Compile your script to .exe (using Ahk2Exe). For distribution, we might need to "Exclude" the folder in Windows Defender.
- Optional Fix: Code Signing: (Optional/Advanced) Signing the EXE with a certificate stops most antivirus warnings.

5. Variable Scope Leak
   In V2, global variables must be explicit.

- The Risk: If you reuse a variable name like pid inside a function without declaring it local (or relying on V2's default assume-local), you might accidentally overwrite a global PID, causing the wrong game to close.
- Status: It is  heavily used here. Pid (Class properties). This is the safest way to code. 
- We are Safe.