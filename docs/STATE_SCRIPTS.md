# State Scripts (Vortex Engine)

State scripts let a mod change the **game's screens** — the title screen, the main menu, Freeplay, the loading screen, the credits... — with HScript, without touching the engine's source code.

Each screen of the game is a *state*. Put an `.hx` file named after a state in a `states` folder of your mod and it runs while that screen is open.

> [!WARNING]
> State scripts only exist in Vortex Engine. Psych Engine and V-Slice ignore the `states` folder, so the screens just stay as they are there. The **CHECK MOD** button in the mods menu lists them as Vortex-only.

---

## Contents

1. [Quick start](#1-quick-start)
2. [Where the files go](#2-where-the-files-go)
3. [Screen names](#3-screen-names)
4. [Callbacks](#4-callbacks)
5. [Variables and functions](#5-variables-and-functions)
6. [Changing what a screen already has](#6-changing-what-a-screen-already-has)
7. [The loading screen](#7-the-loading-screen)
8. [Sharing data between screens and songs](#8-sharing-data-between-screens-and-songs)
9. [Errors and debugging](#9-errors-and-debugging)
10. [Examples](#10-examples)
11. [Limits and tips](#11-limits-and-tips)

---

## 1. Quick start

1. In your mod's folder, create a folder called `states`.
2. Inside it, create `MainMenuState.hx`:

```haxe
var hello:FlxText;

function onCreatePost()
{
	hello = new FlxText(20, FlxG.height - 70, 0, 'Hello from my mod!', 28);
	hello.scrollFactor.set();
	add(hello);
}

function onBeatHit()
{
	hello.scale.set(1.2, 1.2); // bounces with the menu music
}

function onUpdate(elapsed:Float)
{
	hello.scale.x = hello.scale.y = FlxMath.lerp(hello.scale.x, 1, elapsed * 8);
}
```

3. Make sure your mod is enabled and at the **top of the mods list** (or set `"runsGlobally": true` in its `pack.json`), then open the main menu. The text is there and bounces with the music.

---

## 2. Where the files go

```
mods/
├─ states/                      ← runs for every mod
│   └─ TitleState.hx
└─ My Mod/
    ├─ pack.json
    └─ states/                  ← runs for "My Mod"
        ├─ Global.hx            ← runs on EVERY screen
        ├─ MainMenuState.hx
        ├─ FreeplayState.hx
        └─ LoadingState.hx
```

A screen's scripts are looked for in these folders, in this order, and **all the ones found run** (they don't replace each other):

| Folder | When it's used |
|---|---|
| `assets/shared/states/` | always (the engine's own files) |
| `mods/<global mod>/states/` | mods with `"runsGlobally": true` in their `pack.json` |
| `mods/states/` | always |
| `mods/<current mod>/states/` | the mod being played |

On each screen, `Global.hx` runs before the screen's own file.

**Which mod is the "current mod"?**
* On menus, it's the mod at the **top of the mods list** (the game loads it when it gets to the main menu). To have your menu scripts always run, use `"runsGlobally": true`.
* On the **loading screen**, it's the mod of the song being loaded. So a `LoadingState.hx` in your mod only changes the loading of **your mod's songs**.

Only HScript (`.hx`) files are used. Lua isn't supported here, because Psych's Lua functions are made for songs.

---

## 3. Screen names

The file name is the state's class name. `stateName` tells you the screen you're on (see `Global.hx` in [the examples](#10-examples)).

| File | Screen |
|---|---|
| `TitleState.hx` | Title screen ("Press Enter to Begin") |
| `MainMenuState.hx` | Main menu |
| `StoryMenuState.hx` | Story Mode |
| `FreeplayState.hx` | Freeplay (classic style) |
| `FreeplayStateVslice.hx` | Freeplay (V-Slice style) |
| `CharacterSelectState.hx` | Character Select |
| `LoadingState.hx` | Loading screen (before a song) |
| `ResultsState.hx` | Results screen (after a song) |
| `CreditsState.hx` | Credits |
| `OptionsState.hx` | Options (when opened as a screen of its own) |
| `ModsMenuState.hx` | Mods menu |
| `AchievementsMenuState.hx` | Achievements |
| `GalleryState.hx` | Gallery |
| `MultiplayerMenuState.hx` | Online lobby |
| `LanguageSelectState.hx` | Language selection (first time the game is opened) |
| `Global.hx` | Every screen |

Songs (`PlayState`) are not part of this: they have their own scripts (`scripts/`, `data/<song>/`, `stages/`, `characters/`...), as in Psych Engine.

> [!TIP]
> Not sure of a screen's name? Put `debugPrint(stateName);` in `Global.hx` and open it.

---

## 4. Callbacks

Write any of these functions in your file; the ones you don't write are just not called.

| Callback | When |
|---|---|
| `onCreate()` | The screen was opened, **before** it makes its things. Good for reading files and setting up your variables. |
| `onCreatePost()` | **After** the screen made its things. Add, hide, move or replace things here. |
| `onUpdate(elapsed)` | Every frame, before the screen updates. `elapsed` is the time since the last frame, in seconds. |
| `onUpdatePost(elapsed)` | Every frame, after the screen updated. |
| `onStepHit()` | Each step of the music playing (`curStep`). |
| `onBeatHit()` | Each beat of the music playing (`curBeat`). |
| `onOpenSubState(name)` | A substate opened over the screen (`name` is its class: `"PauseSubState"`, `"OptionsMenu"`...). |
| `onCloseSubState()` | The substate was closed. |
| `onDestroy()` | The screen is being left. |
| `onLoadingProgress(loaded, total, percent)` | **Loading screen only.** Something more was loaded. `percent` goes from 0 to 1. |
| `onFinishedLoading()` | **Loading screen only.** Everything is loaded. Return `Function_Stop` to keep the screen on (see [section 7](#7-the-loading-screen)). |

Order on a screen: `onCreate` → the screen makes its things → `onCreatePost` → (`onUpdate` → screen updates → `onUpdatePost`, every frame) → `onDestroy`.

---

## 5. Variables and functions

### Variables

| Name | What it is |
|---|---|
| `game` / `state` | The screen itself (see [section 6](#6-changing-what-a-screen-already-has)). |
| `stateName` | The screen's name (`"MainMenuState"`). |
| `curStep`, `curBeat` | The music's step and beat (updated before `onStepHit` / `onBeatHit`). |
| `controls` | The player's controls: `controls.ACCEPT`, `controls.BACK`, `controls.UI_LEFT_P`... |
| `sharedData` | An object kept from one screen to the next (see [section 8](#8-sharing-data-between-screens-and-songs)). |
| `VortexEngine` | Always `true` on Vortex Engine. |
| `Function_Stop`, `Function_Continue` | Values to return from callbacks. |

Everything Psych's HScript has is there too: `FlxG`, `FlxSprite`, `FlxText`, `FlxTween`, `FlxEase`, `FlxTimer`, `FlxMath`, `FlxColor`, `FlxCamera`, `Paths`, `Conductor`, `ClientPrefs`, `PlayState`, `Character`, `Alphabet`, `StringTools`... and `import` works for other classes (`import flixel.addons.display.FlxBackdrop;`).

### Functions

| Function | What it does |
|---|---|
| `add(object)`, `insert(position, object)`, `remove(object)` | Adds/removes things to/from the screen (they're the screen's own functions). |
| `switchState(name)` | Goes to another screen by its name: `switchState('MainMenuState')`, `switchState('options.OptionsState')`. Returns `false` if there's no screen with that name. |
| `resetState()` | Opens the same screen again. |
| `debugPrint(text, ?color)` | Shows a line at the top of the screen for a few seconds. |
| `parseJson(text)` | Reads JSON text into an object (`null` if it can't). Use it instead of `haxe.Json`, which scripts can't import. |
| `setVar(name, value)`, `getVar(name)`, `removeVar(name)` | Variables kept on the screen (Psych's). |
| `keyboardJustPressed('SPACE')`, `keyboardPressed(...)`, `keyJustPressed('accept')`... | Keyboard and controls (Psych's). |
| `getModSetting(tag)` | One of your mod's settings (Psych's). |
| `finishLoading()` | **Loading screen only.** Goes on to the song after you kept the screen on. |
| `hideLoadingScreen(?hideBar)` | **Loading screen only.** Hides the default picture of the loading screen (and its bar, if `true`). |

---

## 6. Changing what a screen already has

The script runs *inside* the screen, so the screen's things are reached by their names, the same names they have in the engine's source code (`source/states/<ScreenName>.hx`):

```haxe
// MainMenuState.hx
function onCreatePost()
{
	optionsGear.visible = false;         // hides the options gear
	vortexVer.text = 'My Mod v2.0';      // changes the version text
	for (item in menuItems) item.color = 0xFFFFCCEE;
}
```

```haxe
// LoadingState.hx
function onCreatePost()
{
	bar.color = 0xFFFF66CC;              // the loading bar's color
}
```

Open the screen's file in `source/states/` to see the names of its things. Everything you `add()` is drawn on top of what's already there; use `insert(0, sprite)` to put something behind everything.

> [!NOTE]
> Prefer **hiding** the screen's own things (`visible = false`) over `remove()`-ing or destroying them: the screen keeps using them, and destroyed ones can crash it.

---

## 7. The loading screen

`LoadingState.hx` runs on the screen shown while a song is being loaded. Besides the usual callbacks, it has:

* `onLoadingProgress(loaded, total, percent)` – called each time something more is loaded.
* `onFinishedLoading()` – called when everything is loaded. Return `Function_Stop` and the screen **stays on** (the bar stays full) until you call `finishLoading()`. Use it for:
  * a minimum time on the screen, so your art can be seen even on fast loads;
  * a "Press ENTER to continue" screen;
  * an animation or a fade before the song.
* `hideLoadingScreen(?hideBar)` – hides the engine's default picture, so yours is the only one.

The loaded song is already in `PlayState.SONG` (`PlayState.SONG.song` is its name), so you can show a different picture for each song.

> [!TIP]
> The music that was playing (the menu's, or Freeplay's preview of the song) keeps playing on the loading screen. If your screen has a sound of its own, stop it in `onCreatePost()` with `FlxG.sound.music.stop();`.

> [!IMPORTANT]
> If the song is already loaded when the screen opens, `onFinishedLoading()` is called **right then, before `onCreatePost()`**. Decide things like "does this song have a loading screen of its own?" in `onCreate()`, not `onCreatePost()`.

### A loading screen that stays for at least 2 seconds

```haxe
// mods/My Mod/states/LoadingState.hx
var label:FlxText;
var timeOnScreen:Float = 0;
var waiting:Bool = false;

function onCreatePost()
{
	hideLoadingScreen(false); // keeps the bar

	var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF101030);
	insert(0, bg);

	label = new FlxText(0, FlxG.height / 2, FlxG.width, 'Loading...', 40);
	label.alignment = 'center';
	add(label);
}

function onLoadingProgress(loaded, total, percent)
{
	if (label != null) label.text = 'Loading ' + Math.floor(percent * 100) + '%';
}

function onFinishedLoading()
{
	if (timeOnScreen < 2)
	{
		waiting = true;
		return Function_Stop; // stays on: finishLoading() is called below
	}
	return Function_Continue;
}

function onUpdate(elapsed:Float)
{
	timeOnScreen += elapsed;
	if (waiting && timeOnScreen >= 2)
	{
		waiting = false;
		finishLoading();
	}
}
```

### "Press ENTER to continue", with a picture for each song

```haxe
// mods/My Mod/states/LoadingState.hx
// Reads data/<song>/loadingscreen.json: { "image": "loadingscreens/my-song" }
var data:Dynamic = null;
var ready:Bool = false;
var leaving:Bool = false;
var hint:FlxText;
var black:FlxSprite;

function onCreate()
{
	// (decided here: onFinishedLoading may come before onCreatePost)
	var path:String = 'data/' + Paths.formatToSongPath(PlayState.SONG.song) + '/loadingscreen.json';
	try {
		data = parseJson(Paths.getTextFromFile(path));
	} catch (e:Dynamic) {
		data = null;
	}
}

function onCreatePost()
{
	if (data == null) return; // songs with no json get the normal loading screen
	hideLoadingScreen(true);

	var art:FlxSprite = new FlxSprite().loadGraphic(Paths.image(data.image));
	art.setGraphicSize(FlxG.width, FlxG.height);
	art.updateHitbox();
	add(art);

	hint = new FlxText(0, FlxG.height - 60, FlxG.width, 'Loading...', 32);
	hint.alignment = 'center';
	add(hint);

	black = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
	black.alpha = 0;
	add(black);
}

function onFinishedLoading()
{
	if (data == null) return Function_Continue;
	ready = true;
	if (hint != null) hint.text = 'Press ENTER to continue';
	return Function_Stop;
}

function onUpdate(elapsed:Float)
{
	if (ready && !leaving && controls.ACCEPT)
	{
		leaving = true;
		FlxTween.tween(black, {alpha: 1}, 0.5, {onComplete: function(_) finishLoading()});
	}
}
```

> [!NOTE]
> Psych Engine's `data/LoadingScreen.hx` still works as well.

---

## 8. Sharing data between screens and songs

Every screen's scripts are thrown away when the screen is left. To keep something for the next screen — or for the song's own scripts — use `sharedData`:

```haxe
// mods/My Mod/states/LoadingState.hx
sharedData.cameFromMyLoadingScreen = true;
```

In the song's scripts:

```lua
-- Lua (scripts/, data/<song>/, ...)
function onCreatePost()
    if VortexEngine and getPropertyFromClass('psychlua.StateScripts', 'sharedData.cameFromMyLoadingScreen') then
        setPropertyFromClass('psychlua.StateScripts', 'sharedData.cameFromMyLoadingScreen', false)
        -- the loading screen already showed: start right away
    end
end
```

```haxe
// HScript (.hx) in a song
import psychlua.StateScripts;
function onCreatePost() {
	if (StateScripts.sharedData.cameFromMyLoadingScreen == true) { /* ... */ }
}
```

`sharedData` lasts until the game is closed (it isn't saved to disk).

---

## 9. Errors and debugging

* `debugPrint('text')` shows a line at the top of any screen (for a few seconds).
* Errors in state scripts are shown the same way, with the file, the function and the line:
  `ERROR: (onCreatePost) - mods/My Mod/states/TitleState.hx:2: Unknown variable: thisFunctionDoesNotExist`
* A script with an error doesn't stop the screen: the rest of the screen (and the other scripts) keep working.
* Everything is also written to the game's console/log.

---

## 10. Examples

### Global.hx – the screen's name, for finding the files to make

```haxe
// mods/My Mod/states/Global.hx
function onCreate()
{
	debugPrint('This screen is ' + stateName);
}
```

### A moving background behind the main menu

```haxe
// mods/My Mod/states/MainMenuState.hx
import flixel.addons.display.FlxBackdrop;

function onCreatePost()
{
	var pattern:FlxBackdrop = new FlxBackdrop(Paths.image('menuPattern'));
	pattern.velocity.set(40, 25);
	pattern.alpha = 0.3;
	insert(members.indexOf(menuItems), pattern); // right behind the menu's buttons
}
```

### A key that opens another screen

```haxe
// mods/My Mod/states/MainMenuState.hx
// F2 on the main menu opens the credits
function onUpdate(elapsed:Float)
{
	if (keyboardJustPressed('F2')) switchState('CreditsState');
}
```

### A template with every callback

A file with every callback and a short explanation of each is in [`docs/scripts/StateTemplate.hx`](scripts/StateTemplate.hx). Copy it to your `states` folder and rename it after the screen.

---

## 11. Limits and tips

* **HScript only.** Lua files in `states` aren't run.
* **Songs aren't included.** For songs, use Psych's script folders as always.
* **Menus use the mod at the top of the list.** For menu scripts that always run, set `"runsGlobally": true` in `pack.json`.
* **All matching files run.** If two mods have a `MainMenuState.hx`, both run on the main menu.
* **Hide, don't destroy** the screen's own things (see [section 6](#6-changing-what-a-screen-already-has)).
* **`onFinishedLoading` can come before `onCreatePost`** on the loading screen (see [section 7](#7-the-loading-screen)).
* **V-Slice mods** have their own way of changing menus (`.hxc` modules); state scripts work alongside them.
* **Other engines** don't have state scripts. If your mod should also work on Psych Engine, keep what's essential outside of them, in the song's own scripts.
