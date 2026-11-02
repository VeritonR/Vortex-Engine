# Changelog

## v1.4

### ✨ Highlights

- **Extra keys:** songs with 1 to 9 arrows per side, for mods like Shaggy's 6 and 9 key songs.
- **Tutorials:** a "Tutorial" button on the menus and editors. Boyfriend zooms into each part of the screen and explains it.
- **Online:** the port opens by itself (UPnP), there's a chat, you can see the other player's preferences, and a mod the other player doesn't have can be sent to them.
- **New options menu:** one panel with tabs, a preview of the note and splash skins, and a **Mods** tab with the settings that mods add.
- **Screenshots and the Gallery:** `F3` takes a screenshot anywhere, and the Gallery shows them.
- **New gameplay changers:** Only Sick, Random Chart, Random Scroll Invert, Fade In, Fade Out and Random Note Speed.

---

### 🎹 Extra keys (1 to 9 arrows)

- A chart can have `"keyCount": 6` (Psych Engine Extra Keys' `"mania"` is read too: its number plus one). The notes are `0` to `keyCount - 1` on one side and `keyCount` to `keyCount * 2 - 1` on the other.
- Each column uses one of the 4 arrows, or the middle one (the "space" key). A second arrow of the same direction gets its own color. The arrows get smaller the more there are.
- Default keys: 6 keys `S D F J K L`, 7 keys `S D F Space J K L`, 9 keys `A S D F Space H J K L` (and 1, 2, 3, 5 and 8 keys too).
- **Options → More → Extra Keys** changes the key of each arrow, for every number of arrows.
- Chart editor: **Arrows per side** in the Song tab. Changing it keeps each note on its side and in its column.
- Characters sing the animation of the arrow's direction; the middle one sings up.

### 🎓 Tutorials

- A **Tutorial** button (and the `F6` key) on the main menu, Freeplay (both styles), the options, Online, the mods menu, the Gallery, the editors menu, and the Chart, Character, Stage and Character Select editors.
- The screen zooms into each part, the rest gets darker, and Boyfriend explains it in a speech bubble. `ENTER` or a click goes on, `BACKSPACE` goes back, `ESC` leaves.
- The button can be hidden in Options → Vortex Engine → **Tutorial Button**.
- **Mods can make their own:** `data/tutorials/<ScreenName>.json`, with targets by name, zoom, tabs to open, poses and translations. See the README.

### 🌐 Online

- **UPnP:** hosting asks the router to open port `8888` by itself and shows the IP to send to your friend (`C` copies it). If the router can't (UPnP off, or an internet provider using CGNAT), the screen says so.
- **Chat:** `T` opens it in the lobby, during the song and on the results. Its key can be changed in Controls.
- **Paste the IP** with `CTRL+V` when joining.
- **The other player's preferences:** `P` in the lobby shows them (downscroll, middlescroll, lane underlay, ghost tapping, note skin, offset, FPS).
- **Opponent's View** (new option, on by default): you see the other player's notes the way they do, going down if they use Downscroll, with dark lanes if they use Lane Underlay.
- **Sending a mod:** if the host picks a song from a mod the other player doesn't have, they're asked if they want it, with its size and a warning that mods can have scripts. If they accept, the host sends it, it's installed and turned on, and the match starts. A mod that's there but turned off is only turned on.

### 📜 Lua

- **Cameras of your own:** `makeLuaCamera(tag, above)` and `removeLuaCamera`; sprites go on them with `setObjectCamera`.
- **Shaders on whole cameras:** `addCameraShader(camera, shader, tag)`, `removeCameraShader`, and `tweenShaderFloat` to change a shader's value smoothly.
- **The window:** `setWindowTitle`, `setWindowPosition`, `setWindowSize`, their getters, the screen's size and `windowAlert`. What a song changes is put back when it's left.
- **Notes during the song:** `spawnNote(time, column, mustPress, holdLength, noteType)` and `getKeyCount()`.
- **Extra characters during the song:** `addExtraCharacter`, `removeExtraCharacter` and `getExtraCharacters`.
- `setClipboard` / `getClipboard`.
- **3D:**
  - Lua sprites, receptors and notes have `angleX`, `angleY` and `z` (notes follow their receptor).
  - `setCamera3D` / `tweenCamera3D` turn a whole camera in perspective (the HUD with its long notes).
  - `makeLuaModel` loads `.obj` models with a texture, shading and back-face culling, moved and turned like sprites.
  - `setPerspective` changes how strong the perspective is.
- All of it with examples in sections 12 and 13 of `scripts.txt`.

### 🎮 Gameplay

- **New gameplay changers:**
  - **Only Sick:** anything worse than a Sick counts as a miss.
  - **Random Chart:** every note goes to a random column.
  - **Random Scroll Invert:** every 16 beats, the receptors may glide to the other side of the screen.
  - **Fade In / Fade Out:** the notes appear only near the receptors, or disappear before reaching them.
  - **Random Note Speed:** each note comes at its own speed.
- **Ghost Notes** play the animation the character was in, including custom ones.
- **Game over** loads with the song, so dying doesn't freeze the game for a moment.

### ⚙️ Options

- **New options menu:** one panel with tabs (Gameplay, Graphics, Visuals, V-Slice, Vortex Engine, Mods, More), with the keyboard or the mouse. Hold LEFT/RIGHT to change values faster, and `R` resets a setting.
- **Note skin and splash preview:** the arrows show up next to these settings, with the splashes playing.
- **Mods tab:**
  - V-Slice mods' own settings, added the way they do on V-Slice (`createPrefItemCheckbox`, `createPrefItemEnum`, `createPrefItemNumber`, `createPrefItemPercentage`).
  - Psych mods' `data/settings.json`.
- **Keystrokes:** the keys you press, shown during songs and lit while held (in the arrow's color), with keys per second. Off, **WASD** (like W A S D) or **DFJK** (in a row; songs that don't have 4 arrows always use it).
- **Click Between Frames** (Windows): like the Geometry Dash mod, each key press counts from the moment it was made, not from the start of the next frame. More precise hits, mostly at low framerates.
- The **keystrokes** and the **Break Timer** are on a camera of their own, over every other one: a song's HUD, score text or cutscene camera no longer covers them, and songs that hide the HUD don't hide them.
- **Supersampling:** the game is drawn bigger than the window and shrunk to it, for smoother edges (like DSR on NVIDIA cards).
- **Controls:** two actions on the same key that work during a song (a note key that's also the chat's, for example) get a warning.
- New keys in Controls: **Chat** (`T`), **Screenshot** (`F3`) and **Tutorial** (`F6`).

### 📸 Screenshots and the Gallery

- `F3` takes a screenshot anywhere, with a flash, a camera sound and a small preview in the corner (clicking it opens the folder). The pictures go to `mods/images/gallery`.
- The **Gallery** has a new look and switches images faster, and `S` (or its button) saves a copy anywhere.

### 🛠️ Editors

- **Character Select editor:** a playable character can be a spritesheet (`.png` + `.xml`) instead of a texture atlas, in the new **Player Sheet** tab (Vortex only: the official V-Slice needs the atlas).
- Every editor has a tutorial.

### ⚡ Performance

- V-Slice scripts run about 30% faster during songs: looking up a name made a list of every name of the script's base on each lookup.
- Sprites of an image that was already loaded no longer read its `.xml` / `.txt` / `.json` from the disk again (every note of a song did).
- Notes no longer check the disk for their skin one by one (thousands of times per song).
- Moving the mouse during a song no longer makes the game test it against everything the cameras drew (it could freeze the game for a moment on busy songs).

### 🐛 Fixes

- V-Slice stages: an animation mirrored on its own is mirrored again (the cars driving backwards on Darnell Erect).
- South (Pico Mix): a second, broken A-BOT.
- An extra character that was taken away while the song still had it no longer crashes the song when it dances.
- V-Slice mods' "Change Character" events could not change back to the base game's characters (You Can't Run: Boyfriend and Girlfriend stayed pixel after the pixel part).
- V-Slice mods that move the health bar and its frame apart (Sonic.exe's HUD) had the frame out of place: they are two separate things there, like on V-Slice.
- Christmas stage: Boyfriend's outfit switching on its own, and Girlfriend and her speakers jumping every few seconds.
- Pixel health icons and their glow are placed correctly.
- The Break Timer follows the receptors when scripts move them.
- Options: opening Note Colors with `S` from the main menu's options gave a black loading screen with "Null Object Reference".
- Options: the settings with a list of choices showed two colons ("Note Skins::").

### 🌎 Translations

- Brazilian Portuguese for everything above.

---

💬 **Join the Vortex Engine Discord server:** https://discord.gg/QKjMSpeHW
