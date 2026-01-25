# Adding a New Emulator

### Step 1: Create the Launcher Class
Create a new file in lib/emulator/types/.
* Naming Convention: [Name]Launcher.ahk (e.g., RetroArchLauncher.ahk).
* Inheritance: Must extend EmulatorBase.
````
#Requires AutoHotkey v2.0
#Include ..\EmulatorBase.ahk
#Include ..\..\window\WindowManager.ahk

class RetroArchLauncher extends EmulatorBase {
    
    Launch(gameObj) {
        this.GameId := gameObj.Id

        ; 1. Get Path from Config (You will define this key in Step 4)
        emuPath := this.GetEmulatorPath("RETROARCH_PATH", "RetroArchPath")
        if !emuPath
            return false

        SplitPath(emuPath, &exeName, &emuDir)

        ; 2. Kill existing instances
        this.KillProcess(exeName)

        ; 3. Build Command
        ; Example: retroarch.exe -L "core_path" "game_path"
        ; You might need to hardcode a core or read it from gameObj
        runCmd := Format('"{1}" -f -L "cores\snes9x_libretro.dll" "{2}"', emuPath, gameObj.EbootIsoPath)

        try {
            Run(runCmd, emuDir, "UseErrorLevel", &pid)
            if (pid > 0) {
                this.UpdateLastPlayed(emuPath, pid)
                
                ; Force Monitor 1
                if WinWait("ahk_pid " pid, , 5)
                    WindowManager.SetGameContext("ahk_pid " pid, 1)
                
                return true
            }
        } catch as err {
            DialogsGui.CustomMsgBox("Error", "Launch failed: " err.Message)
        }
        return false
    }
}
````

### Step 2: Register in Factory
Open lib/emulator/LauncherFactory.ahk.
1. Add #Include types/RetroArchLauncher.ahk at the top.
2. Add a case to the switch statement.

````
static GetLauncher(launcherType) {
        switch launcherType, 0 {
            ; ... existing cases ...
            case "RETROARCH": return RetroArchLauncher()
            ; ...
        }
    }
````

### Step 3: Update File Recognition
Open lib/config/GameRegistrarManager.ahk. This tells the "Add Game" button to recognize the new file extensions (e.g., .sfc, .smc).

#### 1.Update AddGame Filter:
````
path := FileSelect(3, , "Select Game", "All (*.exe; ... *.sfc; *.smc)")
````
#### 2.Update Logic: Add a check for the new extension in the main if/else block.
````
else if (ext ~= "i)^(sfc|smc)$") {
    config.Launcher := "RETROARCH" ; <--- This matches the Factory Key in Step 2
    return this.FinalizeRegistration(config)
}
````
### Step 4: Add Configuration UI (Optional)
Open lib/ui/EmulatorConfigGui.ahk. This allows you to set the path to retroarch.exe inside the app.

#### 1.Add Input Field: Inside Create() or Show():
````
this.AddPathRow(gui, "RetroArch:", "RETROARCH_PATH", "RetroArchPath")
````

### Step 5: Test It
1. Reload the App.
2. Go to Configure Emulators -> Set the path to your new emulator.
3. Click Set Game Path -> Select a ROM file (e.g., Mario.sfc).
4. Launch!

### Summary Checklist
[ ] Created [Name]Launcher.ahk in lib/emulator/types/.
[ ] Added #Include and case in LauncherFactory.ahk.
[ ] Added file extensions to GameRegistrarManager.ahk.
[ ] Added path setting row in EmulatorConfigGui.ahk.