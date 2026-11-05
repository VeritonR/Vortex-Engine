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

### 📄 Codename Engine charts

- A Codename Engine chart is read like a Psych one, in a song's folder or loaded in the chart editor: its strumlines become the opponent, the player, the girlfriend and extra characters, its `meta.json` (BPM, time signature) and `events.json` are read, and its events become the engine's ones that do the same (camera, zoom, flash, scroll speed, animations, alt animations). Others keep their name for scripts.
- **File > Open Codename Engine Chart...** in the chart editor converts a Codename chart into a Psych one. Its strumlines show up as fields of their own on the grid right away, like in Codename's editor, and "Save" suggests the Psych name (`<song>-hard.json` for Codename's `hard.json`).
- Saving it in the chart editor makes a Psych chart and asks where, so the Codename file isn't replaced.
- **Strumlines of their own:** an extra character can have receptors of its own (the Extras tab's "Receptors of its own", with where they go and if they're seen) instead of sharing its side's. The player hits the ones on their side with the same keys. Codename's visible strumlines get them where Codename puts them, and the main strumlines' places and visibility come along too.
- "Camera Target" takes how the camera gets there (seconds and an ease, "snap", and an offset) and a spot ("x, y"), like Codename's Camera Movement and Camera Position. "Set Camera Zoom" can zoom the HUD and keep it zoomed (", hud"). Continuous BPM changes go little by little. A song with no girlfriend strumline has no girlfriend, and a mod's own event with a Codename name is kept as the mod's.
- New for every chart: notes can be sung by the girlfriend while keeping their type (`"gf"` singer) or be hidden, sung in the background by a character nobody sees (`"hidden"` singer, Codename's invisible strumlines). "Play Animation" takes an extra character's tag, and "Set Camera Zoom" takes `*1.2` (times the stage's zoom).

### 🧩 V-Slice mods

- **Mods made for every song** (a scoring system, a HUD, no songs of their own) now also run on the songs that aren't V-Slice ones: the base game's and Psych mods'. On V-Slice their scripts run on every song.
- Their scripts find their own mod's files on any song (sounds, images), the way V-Slice has the files of every mod at once.
- A sound that isn't there no longer counts as there for V-Slice scripts (`Assets.exists(Paths.sound(...))`): a script that looked for numbered sounds until one was missing froze the game while loading the song.
- A loop of a V-Slice script that never ends is stopped after 5 seconds with an error in `hxc_errors.txt`, instead of freezing the game for good.
- A press with nothing to hit is told to V-Slice scripts before it counts (`onNoteGhostMiss`), with Ghost Tapping on too, and they can call it off or change what it costs.
- A note a script kills goes away with no hit and no miss, like on V-Slice (it froze the game).
- V-Slice scripts get V-Slice's own fonts (`vcr.ttf` is VCR OSD Mono for them; the engine's texts keep the engine's). The V-Slice content that comes with the engine has them now.
- More of V-Slice for scripts: `comboPopUps.displayRating()`, `isPracticeMode` and `isBotPlayMode` can be set, `holdNoteSprite` for every long note, `Assets.cache`, the options menu's pages (`optionsCodex.currentPage`, `items.resetItem()`), the names of enum settings with their values, Bot Play's hits told like V-Slice's, the modules in V-Slice's order, `TextMenuList` and `MenuTypedList` (the menus of texts mods make for themselves), `SongNoteDataRaw`.
- Their settings (`Save.instance.modOptions`) are saved with the engine's, so they're still there after the game is closed.
- **Play as Opponent with V-Slice mods:** a mod's own health bar looks like the engine's (the one playing on the left, their part growing from there), and its health drains go by the sides of the chart, long notes included. Notes a mod has another character sing (cancelling the computer's hit, like Schwiftying's Morty notes) are still hits for the one playing them: rating, health, the receptor's confirm and the long note.

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
  - `makeLuaModel` loads `.obj` models with a texture, shading and back-face culling, moved and turned like sprites. The colors of their parts come from their `.mtl` file, or from `setModelMaterialColor` (`getModelMaterials` lists them).
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
- **Change Stage event:** another stage in the middle of the song (the stage's name, and optionally `keep`, `snap`, `keepzoom`). The old stage's sprites and scripts go away, the new one is built where the characters are and they go to its places, with its camera. Its images load with the song, and a restart starts on the chart's stage. Lua: `changeStage(name, flags)`, `onChangeStage` and `onChangeStagePost`.
- Leaving a song through a mod's own pause menu (or Lua's `exitSong()`) goes to the Freeplay style chosen in the options, not always the Psych one.

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
- **Character Select editor, Icon tab:** the player's icon on the grid and in Freeplay can be changed: load a `.png` (with its `.xml` for an animated one, previewed with Idle / Confirm), or make one from the character's health icon. Saving puts it where V-Slice looks for it (`images/freeplay/icons/<player>pixel.png`), so it works there too.
- Character Select finds the icons like V-Slice does (a "bf-holiday" player uses "bfpixel" if it has no icon of its own), with the "confirm-hold" animation.
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
