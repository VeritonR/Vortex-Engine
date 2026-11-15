# Changelog

## v1.4

### Highlights

- Extra keys: 1 to 9 arrows per side.
- Tutorials on the menus and editors.
- Online: automatic port opening (UPnP), chat, the other player's preferences, and sending a missing mod.
- New options menu with tabs and a Mods tab.
- Screenshots (`F3`) and a new Gallery.
- New gameplay changers.
- Android support with touch controls.
- V-Slice subtitles and many V-Slice mod fixes.
- Better Discord Rich Presence.

### Codename Engine charts

- Codename charts are read like Psych ones: strumlines, `meta.json`, `events.json` and their events.
- Chart editor: **File > Open Codename Engine Chart...** converts a Codename chart; saving makes a Psych chart without replacing the original.
- Extra characters can have their own receptors.
- "Camera Target" takes a duration, ease, snap, offset and position. "Set Camera Zoom" can zoom the HUD and takes `*value` (times the stage's zoom).
- Continuous BPM changes.
- Notes can be sung by the girlfriend (`"gf"` singer) or by a hidden character (`"hidden"` singer).
- "Play Animation" accepts an extra character's tag.

### V-Slice mods

- Mods made for every song (HUDs, scoring systems) also run on base game and Psych songs.
- Scripts find their own mod's files on any song.
- Script loops that never end are stopped after 5 seconds and reported in `hxc_errors.txt`.
- `onNoteGhostMiss` is called before a ghost press counts, and can cancel it.
- Killing a note from a script no longer freezes the game.
- V-Slice scripts use V-Slice's own fonts.
- Texture atlas signals (`animation.onFinish.dispatch('end')`) take their values directly from scripts, like V-Slice's.
- Added for scripts: `comboPopUps.displayRating()`, settable `isPracticeMode` and `isBotPlayMode`, `holdNoteSprite`, `Assets.cache`, options menu pages, `TextMenuList`, `MenuTypedList`, `SongNoteDataRaw`, `GRhythmUtil`, `thx.Objects`, `HealthIcon.configure()`.
- V-Slice compile flags (`desktop`, `hxvlc`, `FEATURE_*`) are defined for scripts' `#if`.
- `!value is Type` is parsed like Haxe does.
- Freeplay and Character Select are found at `FlxG.state.subState`, like on V-Slice.
- Characters are looked up in V-Slice's order: the mod's, the base game's V-Slice version, then other enabled mods'.
- A song can use another mod's character, with its images and script.
- When several scripts target the same character, stage, song or event, the last one loaded wins, like on V-Slice.
- Freeplay lists a V-Slice mod's songs in the order of its levels.
- Stage layers are sorted after the characters are added.
- Stage props from the stage file have their layer before the stage script runs.
- Props added twice are only sorted once.
- Named props belong to their own stage.
- `.hxc` files are loaded from anywhere in the mod, not only `scripts/`.
- Dialogue box scripts (`extends DialogueBox`) work, with their fonts, sounds and animations.
- Script functions with no return value return null.
- Scripts keep finding their mod's classes when another mod's song is played.
- Characters sing through their script's `playSingAnimation()`.
- `Countdown.skipCountdown()`, `stopCountdown()`, `pauseCountdown()`, `resumeCountdown()` and `resetCountdown()` work.
- The stage's `pause()` and `resume()` work.
- The stage's `update()` runs every frame.
- The stage has `forEach()`, `forEachAlive()`, `forEachExists()`, `forEachDead()` and `forEachOfType()`.
- `Save.instance` score, favorite and unlock functions return real values; `charactersSeen` and `addCharacterSeen()` added.
- Mod settings (`Save.instance.modOptions`) are saved.
- Script errors are reported with their line.
- Atlas characters: `animation.play()` skips the script's `playAnimation()`; `stamp()` accepts them; `applyStageMatrix` can be enabled after creation.
- Results screen and Freeplay DJ animations are placed like on V-Slice 0.8.
- Characters with a sing time of 0 return to dancing only after singing.
- Spritesheet frames with no size are empty.
- "Mix and match" characters (spritesheet characters with texture atlas animations) are supported.
- Ghost notes copy the character that is visible and its shader.
- Subtitles: `songs/<song>/subtitles/song-lyrics.srt` is shown during the song, and scripts can assign subtitles to cutscenes. Can be turned off with the Subtitles option.
- Chart events with the same name as an engine event are left to the mod's scripts.
- Chart events only made by another enabled mod's scripts use that mod's script.
- Play as Opponent: mod health bars and health drains follow the played side; notes another character sings still count as hits.
- Note styles made by scripts (`ScriptedNoteStyle`) are supported: their own ratings (`buildJudgementSprite()`, like QT Rewired's "dodged") pop up during the song.
- Enums declared by a script (base game Nene's `NeneState` and `PupilState`) can be imported by other scripts, whatever order the files are loaded in. A file with an enum keeps its `package`.
- Added for scripts: `FlxAssets.FlxShader`, `SubtitlesAlignment`, `PlayState.popUpScore("rating")`, the rating group's `add()`, `remove()` and `insert()`, an atlas sprite's `frameIndex` and `animation.finishCallback`, a character's `_data` with its file's animations, and a prop's `setAnimationOffsets()`.
- `FunkinSound.load()` accepts a whole file path (`sounds/.../name.ogg`).
- Scripts can import everything V-Slice's can: every class of flixel (with addons), openfl and lime is built in, like V-Slice does; every abstract gives its values and static functions (`FlxAxes.X`, `FlxTextAlign`, `FlxTweenType`...), and typedefs import as their class (`FlxSpriteGroup`) or as a type.
- Added V-Slice's enums (`Control`, `PauseMode`, `HealthIconState`, `AtlasFont`, `ScoringSystem`...), its scripted class interfaces, `FunkinGroup` (a sprite group, as on V-Slice, with the sprites' `localX`/`localY`...), `StickerSubState`, `FreeplayState.build()`, its built-in song events and note kinds as classes to extend, `DialogueBoxRegistry`, `SpeakerRegistry`, `DataAssets`, `IntervalShake`, its shaders and array tools, `FlxRadialGauge`, and the sandboxed Discord and Newgrounds clients.
- What a script imports comes before the engine's own version of a name: `import funkin.util.tools.StringTools;` gives V-Slice's, with `stripSuffix()` (IndieCross' HUD icons).
- Added for scripts: settable `PlayState.instance.startingSong`, the health bar's `updateFilledBar()`, V-Slice's sprite functions on any sprite (`getCurrentAnimation()`, `hasAnimation()`, `playAnimation()`, `loadTexture()`, `loadSparrow()`, `makeSolidColor()`...), V-Slice's controls (`ACCEPT_P`, `BACK_R`, `FREEPLAY_FAVORITE`, `VOLUME_UP`...), its scoring, song and file dialog constants.
- Shaders made by scripts have V-Slice's `setBitmapData()` and `getBitmapData()` (Vs Impostor's heat wave).
- Script classes that extend `ScriptedStrumline`, `ScriptedStickerPack`, `ScriptedFunkinVideoSprite`, `ScriptedFlxStrip` and the scripted characters extend the real thing.
- Texture atlases: `animation.addByPrefix()` and `addByIndices()` (by frame label or symbol), and V-Slice's names to go through their symbols (`library.getSymbol()`, `timeline.getLayer()`, `layer.forEachFrame()`, `frame.elements`, `frame.forEachElement()`), used to put a sprite in place of a symbol.
- V-Slice's libraries `json2object`, `thx.core` and `thx.semver` are built in, so scripts get the real ones; a mod's `apiVersion` and `modVersion` are versions (`toString()`, comparing), like on V-Slice (Spooky Mix and Hazier Hiver gave errors).
- A mod whose images are only `.astc` files (the phone version of a V-Slice mod) gets a warning in `hxc_errors.txt` saying those images only open on V-Slice for phones, and to use the computer version.
- Long notes of a strumline a script makes take their note's image and the song's scroll speed (Hypno's Lullaby's flipped strums gave an error on every note).
- `StageRegistry.instance.fetchEntry()` gives the stage the song is on when it's that one, and the same one each time otherwise, like V-Slice's registry: a new one was made every time, with none of what the stage on the screen had (IndieCross asks for its stage on every frame).
- A strumline a script makes for itself (`new Strumline(noteStyle, isPlayer)`) no longer moves and hides the song's own receptors of that side (IndieCross' Bonedoggle took one side off the screen). Strumlines have `hitNote()`, `applyNoteData()` and `setPosition()`, and `currentChart.notes` lists the chart's notes.
- Scripts can set `PlayState.instance.currentDifficulty`, and stage scripts read their own `health`, like V-Slice's stage (a sprite group).
- Weekend 1's streets no longer crash the game when the player is a texture atlas character (SKYREBORN's Sky on 2Hot): Pico's shooting fade copies only a spritesheet player.
- "Multi" texture atlas characters find an animation that doesn't say which of their atlases it's on in any of them, like V-Slice, which joins them into one (QT Rewired's Boyfriend went back to his idle, lower than he should, instead of dancing at the end of Blissful).
- A song whose script stops the countdown and sets `PlayState.instance.isInCountdown = true` starts on its own with no countdown, like on V-Slice: QT Rewired's Obliterated Erect stayed on its intro forever.
- `animation.curAnim` of a texture atlas character has `pause()`, `resume()`, `stop()` and `play()` (QT Rewired's robot holds its entrance until its cue).
- What a script puts on the stage (`currentStage.add()`) stays under all of the HUD, whatever its layer and camera, like V-Slice's stage (a group under the HUD): QT Rewired's videos at the end of Obliterated Erect covered the notes.
- A texture atlas sprite playing one of its symbols by itself is placed by that symbol's box, like V-Slice's library (it was placed by the main timeline's): QT Rewired's saw was lower than on V-Slice and hit Boyfriend's legs instead of his head.
- A texture atlas sprite asked by a script to play a name it has as no animation, frame label or symbol stays as it was, like on V-Slice (it played its whole timeline).
- The game over has V-Slice's `goBack()`, `isEnding`, `canInput`, `controls` and `blueballed` for scripts, and its camera point exists when the death animation starts, so a character's script can move it then (QT Rewired's Boyfriend gave errors on his saw death and when leaving it).
- A song a V-Slice script ends early (`endSong()`, for a cutscene) is no longer a game over: Psych's check for skipped notes isn't done then, as on V-Slice (SKYREBORN's Tutorial).
- A script class's function called with fewer values than it takes gets null for the rest, like on V-Slice (Twinsomnia's characters). Characters have `isHoldingNote()`, `justPressedNote()`, the combo animations and their death camera's settings, strumlines `isKeyHeld()`, and `FunkinSprite` older V-Slice's cache functions (`cacheTexture()`, `cacheSparrow()`...).

### Extra keys

- Charts can have `"keyCount"` from 1 to 9 (Psych Extra Keys' `"mania"` is also read).
- Default keys for every count, editable in **Options > More > Extra Keys**.
- Chart editor: **Arrows per side** in the Song tab.
- Arrows get smaller with more columns; the middle column sings up.

### Tutorials

- Tutorial button (and `F6`) on the main menu, Freeplay, options, online, mods menu, Gallery and editors.
- Can be hidden in **Options > Vortex Engine > Tutorial Button**.
- Mods can add their own in `data/tutorials/<ScreenName>.json`.

### Online

- UPnP opens port `8888` automatically; `C` copies the IP.
- Chat (`T`) in the lobby, during songs and on results.
- `CTRL+V` pastes the IP when joining.
- `P` shows the other player's preferences.
- Opponent's View option: see the other player's notes as they do.
- A song from a mod the other player doesn't have can be sent to them.

### Lua

- `makeLuaCamera`, `removeLuaCamera`.
- `addCameraShader`, `removeCameraShader`, `tweenShaderFloat`.
- Window functions: `setWindowTitle`, `setWindowPosition`, `setWindowSize`, their getters, screen size and `windowAlert`.
- `spawnNote`, `getKeyCount`.
- `addExtraCharacter`, `removeExtraCharacter`, `getExtraCharacters`.
- `setClipboard`, `getClipboard`.
- `keyJustPressed('space')`, `keyPressed('space')` and `keyReleased('space')` work again.
- 3D: `angleX`, `angleY` and `z` on sprites, receptors and notes; `setCamera3D`, `tweenCamera3D`, `setPerspective`; `.obj` models with `makeLuaModel`, `setModelMaterialColor`, `getModelMaterials`.
- Examples in sections 12 and 13 of `scripts.txt`.

### Mods for older Psych Engine (0.4 to 0.7.3)

- Classes by their old names (`PlayState`, `ClientPrefs`, `GameOverSubstate`, `Conductor`, `flixel.system.FlxSound`...) in `getPropertyFromClass`, `setPropertyFromClass`, `callMethodFromClass`, `createInstance`, `addHaxeLibrary` and HScript `import`s.
- Options read the old way (`ClientPrefs.downScroll`, `globalAntialiasing`, `hideTime`); options of a mod's own engine give nil instead of an error.
- `healthBarBG`, `timeBarBG` and `camFollowPos` (moving it moves the camera at once, like before).
- `modchartSprites`, `modchartTexts`, `modchartTweens`, `modchartTimers`, `modchartSounds` and `modchartSaves` (now all in `variables`), and `getControl`.
- `isPixelStage` can be set again.
- Notes: `noteSplashTexture`, `noteSplashDisabled`, `noteSplashHue/Sat/Brt` and `colorSwap` (on notes and receptors with their own colored skins).
- Health bar: `createGradientBar` and `numDivisions`.
- Rating counters `sicks`, `goods`, `bads` and `shits`.
- Note skins: a mod's `images/NOTE_assets.png` and `images/noteSplashes.png` (where 0.6 kept them) are used when it has no new ones, and skins colored already (one color per arrow, like all of them up to 0.6) aren't recolored by the RGB shader.
- `debugPrint` with several texts, `removeFromGroup(group, index, true)` ("don't destroy") and `setObjectOrder` with a third value work like before.
- A script destroying the song's voices or a character no longer crashes the game.
- Functions: `getScore`, `getMisses`, `getHits`, `getGlobalFromScript`, `setGlobalFromScript`, `changePresence`, `clearUnusedMemory`, `setRatingString`.
- Variables: `cameraX`, `cameraY`, `inChartEditor`, `ghostMisses`, `hideTime`.
- An error in an HScript function given to the game (an animation's, tween's or timer's end) is shown like other script errors instead of closing the game.

### Gameplay

- New gameplay changers: Only Sick, Random Chart, Random Scroll Invert, Fade In, Fade Out, Random Note Speed.
- Ghost notes play the character's current animation, including custom ones.
- Game over is loaded with the song.
- Change Stage event (Lua: `changeStage`, `onChangeStage`, `onChangeStagePost`).
- Leaving a song from a mod's pause menu goes to the chosen Freeplay style.

### Options

- New options menu with tabs; hold LEFT/RIGHT for faster changes, `R` resets a setting.
- Note skin and splash preview.
- Mods tab with V-Slice mods' settings and Psych mods' `data/settings.json`.
- Keystrokes display (WASD or DFJK).
- Click Between Frames (Windows).
- Keystrokes and Break Timer have their own camera.
- Supersampling.
- Texture Quality: Half draws big images (characters, stages) from textures of half their size, for weak phones and graphics cards.
- Widescreen: songs and menus fill ultrawide screens. The HUD is no longer cut at the 16:9 edges when it zooms in.
- Shaders option also disables V-Slice and script shaders.
- Subtitles option.
- Controls warns about keys used by two actions.
- New keys: Chat (`T`), Screenshot (`F3`), Tutorial (`F6`).

### Touch controls

- Mobile Options (Options > More): the touch controls' settings and Render Resolution in one place.
- Arrow Size: makes your arrows and their notes bigger (or smaller) in the Arrows mode; big arrows come closer together to fit the screen.
- Touch Upscroll: your arrows at the top and the notes going up (the pause button moves to the bottom in the Arrows mode).
- Modes: Arrows (touch your own arrows, V-Slice layout), Hitbox and Buttons, with a pause button and opacity setting. Extra keys supported.
- Menus: drag to scroll, tap to select, back button, and on-screen pad.
- Extra buttons for Freeplay and Story Mode (Gameplay Changers, Listen, Favorite).
- Dialogues and cutscenes: tap to continue, Skip button.
- Keys asked for by scripts (a dodge on SPACE) get an on-screen button while the script uses them.
- Mouse mechanics in songs (popups to click, buttons of a mod): every new touch is a click where it was, also while another finger holds the arrows. V-Slice's `TouchUtil` sees every finger.
- Quick taps that start and end between two frames (slow phones) are no longer lost, on the arrows and as clicks.
- Online: the phone's keyboard opens to type the IP and the nickname, the nickname is changed by tapping it, and a Chat button opens the chat out of songs.
- Touches land where the finger is with a Render Resolution below the screen's when the screen changes size after the game starts (the navigation bar hiding on a lot of phones): they landed to the right of the finger, the more the further right (a song's right arrow only answered when touched to its left).
- The menus' pad takes a finger that lands a little off its buttons (the nearest one), and a touch next to it is never a touch of the screen behind it: on Freeplay, pressing up opened Character Select (the DJ is under the pad).

### Android

- Builds for 32 and 64-bit Android 7 and newer, with mods, HScript, Lua and videos.
- Game folder: `Android/media/com.team.vortexengine/` on the phone's storage (mods in its `mods` folder), with no permissions needed.
- Game files are copied on first launch, after updates, and if deleted. V-Slice fonts and empty files are copied too (V-Slice scripts showed the engine's fonts on phones).
- Closing the game (the X on the main menu) no longer makes Android report a crash.
- Images bigger than the graphics card takes (4096 pixels on a lot of cheap phones, where some characters are 8192) are sent at the biggest size it takes instead of showing black or not at all.
- File names are case-insensitive.
- Freeplay: tap the DJ to open Character Select.
- Game images are hidden from the phone's gallery.
- FPS counter with logic and drawing times.
- Hits are judged with the estimated music time, fixing late judgements (also on PC).
- Render Resolution option (720p by default).
- 60 FPS by default.
- Delay setting up to 2500 ms.
- Computer-only options and features are hidden.

### Screenshots and Gallery

- `F3` takes a screenshot anywhere, saved to `mods/images/gallery`.
- New Gallery look; `S` saves a copy.

### Editors

- Character Select editor: spritesheet players (Player Sheet tab) and custom icons (Icon tab).
- Character Select finds icons like V-Slice.
- Tutorials in every editor.

### Performance

- V-Slice scripts run about 30% faster.
- Scripts' `return`, `break`, `continue` and `for` loops no longer go through exceptions, which on phones took up to a third of a second each: songs with V-Slice scripts (the base game's Boyfriend) and menus with mods installed ran at a few frames a second there.
- `i++` on a local variable works in HScript (it never changed the variable).
- Sprite data files are no longer read again for already loaded images.
- Note skins are no longer checked on disk per note.
- Mouse movement during songs no longer causes stutters.
- On phones, a script function (Lua, HScript or V-Slice) that fails every time it's called is stopped after 30 errors in a row, with a warning, since each error there takes a long time: one script error per frame left menus and songs at a few frames a second (Spooky Mix's main menu, some VsGorefieldV2 songs). Computers keep calling it, like Psych.
- The main menu's placeholder background sprites have an image, so mods that replace the menu and read them no longer error on every frame (Spooky Mix).
- Lua's `playAnim` on an object that doesn't exist gives a warning instead of an error.
- A script setting something an object has no variable for (`sprite.zIndex`) no longer throws an error inside the engine each time, which on phones made a stutter of a few hundred milliseconds (Vs Impostor's double note trails, on every double note).
- An atlas character drawn on a sprite by a script (`stamp()`) reuses the image of each pose instead of making a new one every time.

### Discord Rich Presence

- Songs show the song, difficulty, mod, score, accuracy, misses or full combo, and time left.
- Paused, Game Over, Botplay and online matches are shown.
- Menus show the selected song, week, results, achievements, enabled mods and online lobby.
- Engine logo, status icons and buttons to the site and Discord server.
- Mods that set their own presence keep it.
- Texts follow the game's language.

### Crash handling

- Errors no longer close the game: a crash screen shows the error and where it happened, with a way back to the menus.
- Crash reports in `crash/` include the mod, song, difficulty, song time, screen and the last steps.
- Also on Android.

### Fixes

- Widescreen: the stage's camera is moved by mods from where it rests (`camGame.x = 0`, sways on the beat), like without the option: the stage left a black bar on the left side when a mod moved it (Schwiftying's Rigamarole).
- Title screen: mods can change it again (`images/gfDanceTitle.json`, `logoBumpin`, the girlfriend), as in Psych Engine.
- Main menu: back to Psych Engine's layout (animated options in the middle, achievements and options in the bottom corners), with Online and Gallery in the same style and an X to close the game. Mods can change its sprites again.
- The options open and close right over the main menu, without sliding.
- V-Slice mods that add options (Vs Impostor) no longer report errors on the main menu after the options are opened.
- Options V-Slice mods add on their scripts' updates (Vs Impostor's BF skin and pet) show up in the Mods tab. A mod opening V-Slice's options menu gets the engine's.
- A screen asked for while another one is on its way (a mod's button leaving the main menu while ESC goes back to the title) is left out instead of both being opened, which broke the next screens or crashed. The main menu plays its music again if a mod stopped it.
- Freeplay froze on songs whose instrumental is an OGG video.
- Crash when changing screens after a script destroyed a sound.
- Android: every Lua script crashed the game (the video player's library has a Lua of its own, and parts of it were used instead of LuaJIT).
- V-Slice stages: self-mirrored animations were mirrored again.
- South (Pico Mix): duplicated A-BOT.
- Crash when a removed extra character danced.
- V-Slice "Change Character" events couldn't switch back to base game characters.
- V-Slice health bar frames were misplaced when moved apart from the bar.
- Christmas stage: Boyfriend's outfit switching and Girlfriend jumping.
- Pixel health icon positions.
- Break Timer now follows moved receptors.
- Options: Note Colors opened from the main menu crashed.
- Options: lists showed two colons.

### Translations

- Brazilian Portuguese for all new text.

Discord server: https://discord.gg/QKjMSpeHW
