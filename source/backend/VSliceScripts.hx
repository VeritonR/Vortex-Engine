package backend;

#if HSCRIPT_ALLOWED
import funkin.data.song.SongData.SongEventData;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventType;
import funkin.modding.module.Module;
import funkin.data.song.SongData.SongNoteData;
import funkin.play.character.BaseCharacter;
import funkin.play.event.SongEvent;
import funkin.ui.credits.CreditsDataHandler;
import funkin.util.TimerUtil.SongSequence;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.notekind.NoteKind;
import funkin.play.song.Song as VSliceSongScript;
import funkin.play.stage.Stage;

import hxc.HxcInstance;
import hxc.HxcRuntime;

import objects.Character;
import objects.Note;

import psychlua.LuaUtils;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Runs the scripts (.hxc files) of V-Slice mods while one of their songs is being played, and their modules on some of the menus.
 *
 * `hxc.HxcRuntime` is what runs the script classes, and the `funkin` package has the classes they import and extend.
 * This is the part in the middle: it loads the scripts of the song's mod, makes the objects out of them
 * and turns what happens on Psych's PlayState into the events V-Slice scripts expect.
 *
 * What's supported: modules, song events, note kinds (with their note styles), song scripts, stage scripts and character scripts.
 * PlayState tells this about everything through `onCallback()`, with the same callbacks it sends to Psych's own scripts.
 *
 * Whatever goes wrong with a script is shown on the screen and written to "hxc_errors.txt", next to the game.
 */
@:access(states.PlayState)
class VSliceScripts
{
	/**
	 * If there are V-Slice scripts running.
	 */
	public static var active(default, null):Bool = false;

	static var game:states.PlayState = null;
	static var facade:funkin.play.PlayState = null;

	static var modules:Array<HxcInstance> = [];
	static var songEvents:Map<String, HxcInstance> = [];

	// The ones whose event is on the chart being played. Like on V-Slice, only those are told about what happens on the song:
	// a script made for an event the chart doesn't have has nothing to get ready for
	static var chartSongEvents:Array<HxcInstance> = [];
	static var noteKinds:Map<String, HxcInstance> = [];
	static var songScript:HxcInstance = null;
	static var stageScript:HxcInstance = null;
	static var characterScripts:Array<HxcInstance> = [];

	// The note being hit by the player, between PlayState's "pre" callback and the regular one
	static var pendingHit:{note:Note, event:HitNoteScriptEvent, score:Float} = null;

	// Mod each module is from while on a menu, where the ones of every mod run together
	static var moduleMods:haxe.ds.ObjectMap<HxcInstance, String> = new haxe.ds.ObjectMap();

	// Players the scripts that are loaded have something to say about, by their id (see funkin.ui.freeplay.charselect.PlayableCharacter)
	static var scriptedPlayers:Map<String, HxcInstance> = null;

	// Functions of an object that are being done by its script, see callOverride()
	static var overrideGuards:haxe.ds.ObjectMap<Dynamic, Array<String>> = new haxe.ds.ObjectMap();

	// Signals made for the animations of the sprites scripts asked them from, see getAnimationSignal()
	static var animationSignals:haxe.ds.ObjectMap<flixel.animation.FlxAnimationController, Map<String, Dynamic>> = new haxe.ds.ObjectMap();

	// Classes scripts reach by name, they wouldn't be part of the game if nothing mentioned them
	static var keep:Array<Dynamic> = [
		funkin.Conductor, funkin.Paths, funkin.Preferences, funkin.FunkinMemory, funkin.audio.FunkinSound, funkin.graphics.FunkinSprite,
		funkin.graphics.AtlasSpriteProxy, funkin.play.ResultState,
		funkin.Highscore, funkin.play.notes.NoteDirection,
		shaders.AdjustColorShader, shaders.RainShader,
		funkin.data.event.SongEventRegistry, funkin.data.song.SongData,
		funkin.modding.module.ModuleHandler, funkin.modding.module.ScriptedModule,
		funkin.play.Countdown, funkin.play.CountdownStep, funkin.play.PlayStatePlaylist,
		funkin.play.scoring.Scoring, funkin.play.scoring.Scoring.ScoringRank, funkin.modding.PolymodErrorHandler,
		funkin.data.stage.StageRegistry, funkin.modding.events.ScriptEventDispatcher, funkin.ui.AtlasText, funkin.ui.TextMenuItem,
		funkin.util.assets.FlxAnimationUtil, funkin.data.song.SongDataUtils, funkin.data.dialogue.ConversationRegistry,
		funkin.ui.transition.stickers.StickerPack, funkin.data.stickers.StickerRegistry, funkin.data.song.SongData.SongTimeChange,
		funkin.ui.AtlasMenuItem, funkin.ui.AtlasMenuItem.MenuListItem, funkin.util.FileUtil, funkin.ui.debug.DebugMenuSubState,
		funkin.ui.debug.results.ResultsDebugSubState,
		funkin.ui.Prompt, funkin.ui.ButtonStyle, funkin.ui.freeplay.AlbumRoll, funkin.util.InputUtil, funkin.util.plugins.NewgroundsMedalPlugin,
		funkin.PlayerSettings, funkin.util.SwipeUtil, funkin.graphics.FunkinCamera,
		funkin.play.notes.notestyle.NoteStyle, funkin.data.notestyle.NoteStyleRegistry, funkin.data.event.SongEventSchema,
		funkin.util.tools.StringTools, funkin.util.tools.ArrayTools, funkin.util.tools.MapTools, funkin.util.tools.IntTools,
		funkin.util.tools.FloatTools, funkin.util.tools.IteratorTools, funkin.util.BezierUtil, funkin.util.PlatformUtil,
		funkin.util.SerializerUtil, funkin.util.MouseUtil,
		funkin.play.character.CharacterType, funkin.play.event.ScriptedSongEvent,
		funkin.play.notes.Strumline, funkin.play.notes.notekind.NoteKindManager, funkin.play.notes.notekind.ScriptedNoteKind,
		funkin.play.song.ScriptedSong, funkin.play.stage.Stage.ScriptedStage,
		funkin.save.Save, funkin.util.Constants,
		funkin.ui.options.OptionsState, funkin.ui.options.OptionsState.PreferencesMenu, funkin.ui.options.OptionsState.ControlsMenu,
		funkin.ui.story.Level, funkin.ui.story.Level.ScriptedLevel,
		funkin.Assets, funkin.audio.VoicesGroup, funkin.data.character.CharacterDataParser, funkin.data.story.level.LevelRegistry,
		funkin.modding.ModStore, funkin.modding.PolymodHandler, funkin.play.character.NeneBaseCharacter,
		funkin.play.components.PopUpStuff, funkin.play.cutscene.CutsceneType,
		funkin.play.cutscene.dialogue.DialogueBox, funkin.play.cutscene.dialogue.DialogueBox.FunkinTypeText,
		funkin.ui.credits.CreditsDataHandler, funkin.util.AnsiUtil, funkin.util.FlxTweenUtil, funkin.util.HapticUtil, funkin.util.ReflectUtil,
		funkin.util.TimerUtil.Sequence, funkin.util.TimerUtil.SongSequence, shaders.DropShadowShader, thx.semver.Version,
		funkin.effects.FunkTrail, funkin.effects.RetroCameraFade, funkin.mobile.input.ControlsHandler,
		funkin.data.freeplay.player.PlayerRegistry, funkin.data.freeplay.player.PlayerData, funkin.data.freeplay.player.PlayerData.PlayerFreeplayDJData,
		funkin.audio.visualize.ABotVis, funkin.data.song.SongRegistry, shaders.SserafimShader,
		funkin.graphics.framebuffer.FixedBitmapData, funkin.graphics.framebuffer.FixedBitmapData.BitmapDataUtil,
		funkin.ui.freeplay.charselect.PlayableCharacter, funkin.ui.freeplay.charselect.PlayableCharacter.ScriptedPlayableCharacter,
		objects.freeplay.FreeplayDJ.FreeplayDJStates,
		funkin.play.GameOverSubState, funkin.play.PauseSubState, funkin.play.cutscene.VideoCutscene,
		funkin.play.cutscene.dialogue.Conversation, funkin.play.cutscene.dialogue.Conversation.ConversationState, funkin.play.stage.StageProp,
		funkin.ui.FullScreenScaleMode, funkin.util.BitmapUtil, funkin.util.MathUtil, funkin.util.EaseUtil, funkin.util.WindowUtil, funkin.util.DateUtil, funkin.util.SortUtil, funkin.util.TouchUtil,
		shaders.VSliceShaders.OverlayBlend, shaders.VSliceShaders.TextureSwap, shaders.FreeplayShaders.GaussianBlurShader,
		shaders.VSliceShaders.WiggleEffectRuntime, shaders.VSliceShaders.VSliceWiggleType,
		shaders.VSliceShaders.Grayscale, shaders.VSliceShaders.HSVShader, shaders.VSliceShaders.MosaicEffect, shaders.VSliceShaders.InverseDotsShader,
		shaders.VSliceShaders.PuddleShader, shaders.FreeplayShaders.PureColor, shaders.VSliceShaders.RuntimeCustomBlendShader,
		shaders.FreeplayShaders.AngleMask, shaders.FreeplayShaders.StrokeShader, shaders.FreeplayShaders.BlueFade, shaders.LeftMaskShader,
		funkin.input.Cursor, #if hxvlc funkin.graphics.video.FunkinVideoSprite, #end

		// from the libraries, only part of the game if something uses them
		flixel.addons.display.FlxBackdrop, flixel.addons.display.FlxTiledSprite, flixel.addons.display.FlxRuntimeShader,
		flixel.addons.text.FlxTypeText, flixel.addons.effects.FlxTrail, flixel.addons.effects.FlxSkewedSprite, flixel.effects.FlxFlicker,
		flixel.group.FlxSpriteGroup, flixel.math.FlxRect, flixel.math.FlxAngle, flixel.util.FlxGradient, flixel.util.FlxSort,
		openfl.filters.BlurFilter, openfl.filters.ShaderFilter, openfl.filters.ColorMatrixFilter, openfl.filters.GlowFilter, openfl.filters.DropShadowFilter
	];

	// What scripts use without importing: V-Slice's own scripts do it with these, and mods copy them
	static var noImport:Array<Dynamic> = [
		funkin.Assets, flixel.FlxG,
		funkin.Conductor, funkin.Paths, funkin.Preferences, funkin.audio.FunkinSound, funkin.graphics.FunkinSprite,
		funkin.modding.module.ModuleHandler, funkin.play.Countdown, funkin.play.PlayState, funkin.play.PlayStatePlaylist,
		funkin.save.Save, funkin.util.Constants
	];

	// ------------------------------------------------------------------------------------------
	// Error log
	// ------------------------------------------------------------------------------------------

	/**
	 * File the problems of the scripts of the song being played are written to, next to the game. It's made again for every song.
	 */
	public static inline var LOG_PATH:String = 'hxc_errors.txt';

	/**
	 * The same for the scripts that run on a menu, so going back to the menus doesn't take away what was written about the song.
	 */
	public static inline var MENU_LOG_PATH:String = 'hxc_errors_menu.txt';

	static var logPath:String = LOG_PATH;
	static var logHeader:String = '';
	static var logErrors:Array<String> = [];
	static var logWarnings:Array<String> = [];
	static var logMissing:Array<String> = [];
	static var logUnused:Array<String> = [];
	static var logAnnounced:Bool = false;

	static function resetLog(path:String):Void
	{
		logPath = path;
		logHeader = '';
		logErrors = [];
		logWarnings = [];
		logMissing = [];
		logUnused = [];
		logAnnounced = false;

		// what's there is about the song played before
		#if sys
		try
		{
			if(FileSystem.exists(logPath)) FileSystem.deleteFile(logPath);
		}
		catch(e:Dynamic) {}
		#end
	}

	static function onScriptError(message:String):Void
	{
		trace('[HXC] $message');
		if(states.PlayState.instance != null) states.PlayState.instance.addTextToDebug('[HXC] $message', FlxColor.RED);

		logErrors.push(message);
		writeLog();
	}

	/**
	 * Something a script asked for that the engine can't do, which isn't an error of the script.
	 */
	public static function warn(message:String, onlyOnFile:Bool = false):Void
	{
		if(logWarnings.contains(message)) return;

		trace('[HXC] $message');
		if(!onlyOnFile && states.PlayState.instance != null) states.PlayState.instance.addTextToDebug('[HXC] $message', FlxColor.YELLOW);

		logWarnings.push(message);
		writeLog();
	}

	static function writeLog():Void
	{
		#if sys
		var text:StringBuf = new StringBuf();
		text.add('Vortex Engine - problems with V-Slice scripts (.hxc)\n');
		text.add(logHeader);

		if(logErrors.length > 0)
		{
			text.add('\n[Errors]\n');
			for (num => message in logErrors)
				text.add('${num + 1}. $message\n');
		}
		if(logMissing.length > 0)
		{
			text.add('\n[Imports that are not supported]\n');
			for (line in logMissing)
				text.add('- $line\n');
		}
		if(logWarnings.length > 0)
		{
			text.add('\n[Warnings]\n');
			for (message in logWarnings)
				text.add('- $message\n');
		}
		if(logUnused.length > 0)
		{
			text.add('\n[Imports that are not supported, but the scripts never use]\n');
			text.add(logUnused.join(', ') + '\n');
		}

		try
		{
			File.saveContent(logPath, text.toString());
			// (not for what's only written down for whoever goes looking: the file has things that aren't about the song)
			if(!logAnnounced && (logErrors.length > 0 || logMissing.length > 0) && states.PlayState.instance != null)
			{
				logAnnounced = true;
				states.PlayState.instance.addTextToDebug('[HXC] The script problems of this song are saved to "$logPath", on the game\'s folder', FlxColor.WHITE);
			}
		}
		catch(e:Dynamic)
		{
			trace('[HXC] Could not write "$logPath": $e');
		}
		#end
	}

	// Path of a script inside its mod
	static function shortPath(path:String):String
	{
		path = path.replace('\\', '/');
		var position:Int = path.indexOf('/scripts/');
		return (position > -1) ? path.substr(position + 1) : path;
	}

	// ------------------------------------------------------------------------------------------
	// Loading
	// ------------------------------------------------------------------------------------------

	static var watchingFocus:Bool = false;

	static function tellFocus(type:String):Void
	{
		var event:FocusScriptEvent = new FocusScriptEvent(type);
		if(active) dispatch(event);
		else if(menuState != null && modules.length > 0) dispatchToModules(event);
	}

	/**
	 * The ones of these imports that scripts can't have here (classes of V-Slice the engine has nothing for).
	 */
	public static function unresolvedImports(paths:Array<String>):Array<String>
	{
		setupRuntime();
		return [for (path in paths) if(path != null && path.trim().length > 0 && HxcRuntime.resolveImport(path.trim()) == null) path.trim()];
	}

	static function setupRuntime():Void
	{
		HxcRuntime.customImports.set('flixel.util.FlxColor', psychlua.HScript.CustomFlxColor);
		HxcRuntime.customImports.set('flixel.effects.FlxFlicker', funkin.effects.ScriptFlicker); //(flixel's own crashes the way the base game uses it)
		HxcRuntime.customImports.set('flixel.ui.FlxBar', funkin.ui.ScriptBar); //(flixel's own can't follow a variable of a script)
		HxcRuntime.customImports.set('openfl.display.BlendMode', hxc.ScriptBlendMode); //(an abstract: its values)

		// V-Slice's classes to make script classes through: `ScriptedFlxSprite.init('MyClass', ...)`
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxBasic', funkin.modding.base.ScriptedClasses.ScriptedFlxBasic);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxObject', funkin.modding.base.ScriptedClasses.ScriptedFlxObject);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxSprite', funkin.modding.base.ScriptedClasses.ScriptedFlxSprite);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxSpriteGroup', funkin.modding.base.ScriptedClasses.ScriptedFlxSpriteGroup);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxTypedGroup', funkin.modding.base.ScriptedClasses.ScriptedFlxTypedGroup);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxState', funkin.modding.base.ScriptedClasses.ScriptedFlxState);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxTransitionableState', funkin.modding.base.ScriptedClasses.ScriptedFlxState);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxSubState', funkin.modding.base.ScriptedClasses.ScriptedFlxSubState);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxRuntimeShader', funkin.modding.base.ScriptedClasses.ScriptedFlxRuntimeShader);
		HxcRuntime.customImports.set('funkin.graphics.ScriptedFunkinSprite', funkin.modding.base.ScriptedClasses.ScriptedFunkinSprite);
		HxcRuntime.customImports.set('funkin.group.ScriptedFunkinSpriteGroup', funkin.modding.base.ScriptedClasses.ScriptedFlxSpriteGroup);
		HxcRuntime.customImports.set('funkin.group.ScriptedFunkinGroup', funkin.modding.base.ScriptedClasses.ScriptedFlxTypedGroup);
		HxcRuntime.customImports.set('funkin.ui.ScriptedMusicBeatState', funkin.modding.base.ScriptedClasses.ScriptedMusicBeatState);
		HxcRuntime.customImports.set('funkin.ui.ScriptedMusicBeatSubState', funkin.modding.base.ScriptedClasses.ScriptedMusicBeatSubState);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedMusicBeatState', funkin.modding.base.ScriptedClasses.ScriptedMusicBeatState);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedMusicBeatSubState', funkin.modding.base.ScriptedClasses.ScriptedMusicBeatSubState);

		// and what a script class that extends one of those (`class MyMenu extends ScriptedMusicBeatSubState`) is
		for (pair in ([
			[funkin.modding.base.ScriptedClasses.ScriptedFlxBasic, flixel.FlxBasic],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxObject, flixel.FlxObject],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxSprite, flixel.FlxSprite],
			[funkin.modding.base.ScriptedClasses.ScriptedFunkinSprite, funkin.graphics.FunkinSprite],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxSpriteGroup, flixel.group.FlxSpriteGroup],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxTypedGroup, flixel.group.FlxGroup],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxState, flixel.FlxState],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxSubState, flixel.FlxSubState],
			[funkin.modding.base.ScriptedClasses.ScriptedMusicBeatState, backend.MusicBeatState],
			[funkin.modding.base.ScriptedClasses.ScriptedMusicBeatSubState, backend.MusicBeatSubstate],
			[funkin.modding.base.ScriptedClasses.ScriptedFlxRuntimeShader, flixel.addons.display.FlxRuntimeShader]
		]:Array<Array<Dynamic>>))
			HxcRuntime.extendedThrough.set(Type.getClassName(pair[0]), pair[1]);

		funkin.util.WindowUtil.initWindowEvents();

		// the game's window being left and come back to: every script on a song, the modules on the menus
		if(!watchingFocus)
		{
			watchingFocus = true;
			FlxG.signals.focusLost.add(function() tellFocus(ScriptEventType.FOCUS_LOST));
			FlxG.signals.focusGained.add(function() tellFocus(ScriptEventType.FOCUS_GAINED));
		}

		// V-Slice's shaders are the engine's own. They can't be on a "funkin.graphics.shaders" package:
		// C++ takes the engine's "shaders" package for that one when a class in there extends something of it
		HxcRuntime.customImports.set('funkin.graphics.shaders.AdjustColorShader', shaders.AdjustColorShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.RuntimeRainShader', shaders.VSliceShaders.RuntimeRainShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.RuntimePostEffectShader', shaders.VSliceShaders.RuntimePostEffectShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.DropShadowShader', shaders.DropShadowShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.SserafimShader', shaders.SserafimShader);
		HxcRuntime.customImports.set('funkin.input.Controls', backend.Controls);
		HxcRuntime.customImports.set('funkin.graphics.shaders.OverlayBlend', shaders.VSliceShaders.OverlayBlend);
		HxcRuntime.customImports.set('funkin.graphics.shaders.TextureSwap', shaders.VSliceShaders.TextureSwap);
		HxcRuntime.customImports.set('funkin.graphics.shaders.GaussianBlurShader', shaders.FreeplayShaders.GaussianBlurShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.WiggleEffectRuntime', shaders.VSliceShaders.WiggleEffectRuntime);
		HxcRuntime.customImports.set('funkin.graphics.shaders.WiggleEffectType', shaders.VSliceShaders.VSliceWiggleType);
		HxcRuntime.customImports.set('funkin.graphics.shaders.Grayscale', shaders.VSliceShaders.Grayscale);
		HxcRuntime.customImports.set('funkin.graphics.shaders.HSVShader', shaders.VSliceShaders.HSVShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.MosaicEffect', shaders.VSliceShaders.MosaicEffect);
		HxcRuntime.customImports.set('funkin.graphics.shaders.InverseDotsShader', shaders.VSliceShaders.InverseDotsShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.PuddleShader', shaders.VSliceShaders.PuddleShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.PureColor', shaders.FreeplayShaders.PureColor);
		HxcRuntime.customImports.set('funkin.graphics.shaders.AngleMask', shaders.FreeplayShaders.AngleMask);
		HxcRuntime.customImports.set('funkin.graphics.shaders.StrokeShader', shaders.FreeplayShaders.StrokeShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.BlueFade', shaders.FreeplayShaders.BlueFade);
		HxcRuntime.customImports.set('funkin.graphics.shaders.LeftMaskShader', shaders.LeftMaskShader);
		HxcRuntime.customImports.set('funkin.graphics.shaders.RuntimeCustomBlendShader', shaders.VSliceShaders.RuntimeCustomBlendShader);

		// What scripts ask of these that they don't have is asked of the engine's own (see `HxcRuntime.standIns`)
		HxcRuntime.standIns.set('funkin.play.PlayState', function(stand:Dynamic):Dynamic return (stand != null) ? stand.game : null);
		var playStateNames:Map<String, Bool> = [for (name in funkin.play.PlayState.VSLICE_MEMBERS) name => true];
		for (name in Type.getInstanceFields(flixel.FlxSubState)) playStateNames.set(name, true);
		HxcRuntime.standInNames.set('funkin.play.PlayState', playStateNames);

		// the size of the game, which V-Slice's scripts change for a song (with `FlxG.resizeGame()` and the window's size after it)
		HxcRuntime.staticSetters.set('flixel.FlxG', [
			'width' => function(value:Dynamic):Void @:privateAccess FlxG.width = Std.int(value),
			'height' => function(value:Dynamic):Void @:privateAccess FlxG.height = Std.int(value)
		]);
		HxcRuntime.standIns.set('funkin.play.GameOverSubState', function(stand:Dynamic):Dynamic return substates.GameOverSubstate.instance);
		HxcRuntime.standIns.set('funkin.play.notes.NoteSprite', function(stand:Dynamic):Dynamic return (stand != null) ? stand.note : null);
		HxcRuntime.standInTypes.set('funkin.play.PlayState', states.PlayState);
		HxcRuntime.standInTypes.set('funkin.play.GameOverSubState', substates.GameOverSubstate);

		HxcRuntime.resolveMissing = function(object:Dynamic, name:String):Dynamic
		{
			// On V-Slice the values a shader takes are variables of the shader itself ("shader.thing.value"), here they're inside of its "data"
			if(Std.isOfType(object, openfl.display.Shader))
			{
				var data:Dynamic = cast(object, openfl.display.Shader).data;
				return (data != null) ? Reflect.field(data, name) : null;
			}

			// The animations of newer versions of the library tell about their frames and their end with signals: "sprite.animation.onFrameChange.add(...)"
			if(Std.isOfType(object, flixel.animation.FlxAnimationController)) return getAnimationSignal(cast object, name);

			// and so do V-Slice's texture atlases, for the ones scripts make: "sprite.anim.onFrameChange.add(...)"
			if(Std.isOfType(object, flxanimate.animate.FlxAnim))
			{
				var parent:FlxSprite = null;
				@:privateAccess parent = cast(object, flxanimate.animate.FlxAnim)._parent;

				var atlas:objects.AtlasSprite = Std.downcast(parent, objects.AtlasSprite);
				if(atlas == null) return null;
				return switch(name)
				{
					case 'onFrameChange': atlas.player.onFrameChange;
					case 'onFinish', 'onComplete': atlas.player.onFinish;
					case 'onFrameLabel': atlas.player.onFrameLabel;
					default: null;
				}
			}
			return null;
		};

		// the menus V-Slice mods ask about are the engine's own
		// Classes V-Slice moved or merged into others: it still answers by their old names, for the mods made before that
		HxcRuntime.customImports.set('funkin.play.character.CharacterDataParser', funkin.data.character.CharacterDataParser);
		HxcRuntime.customImports.set('funkin.play.character.CharacterData.CharacterDataParser', funkin.data.character.CharacterDataParser);
		HxcRuntime.customImports.set('funkin.data.character.CharacterData.CharacterDataParser', funkin.data.character.CharacterDataParser);
		HxcRuntime.customImports.set('funkin.graphics.adobeanimate.FlxAtlasSprite', funkin.graphics.FunkinSprite);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFlxAtlasSprite', funkin.modding.base.ScriptedClasses.ScriptedFunkinSprite);
		HxcRuntime.customImports.set('funkin.modding.base.ScriptedFunkinSprite', funkin.modding.base.ScriptedClasses.ScriptedFunkinSprite);
		// what V-Slice has under other names, that's the engine's own here
		HxcRuntime.customImports.set('flixel.group.FlxGroup', flixel.group.FlxGroup.FlxTypedGroup);
		HxcRuntime.customImports.set('flixel.tweens.FlxTweenType', funkin.util.ScriptTweenType);
		HxcRuntime.customImports.set('flixel.tweens.FlxTween.FlxTweenType', funkin.util.ScriptTweenType);
		HxcRuntime.customImports.set('funkin.ui.debug.charting.ChartEditorState', states.editors.ChartingState);
		HxcRuntime.customImports.set('funkin.play.cutscene.dialogue.Speaker', cutscenes.VSliceConversation.VSliceSpeaker);
		HxcRuntime.customImports.set('funkin.play.cutscene.dialogue.ScriptedSpeaker', cutscenes.VSliceConversation.VSliceSpeaker);
		HxcRuntime.customImports.set('funkin.play.notes.NoteHoldCover', objects.HoldCover);
		HxcRuntime.customImports.set('funkin.play.notes.NoteSplash', objects.NoteSplash);
		HxcRuntime.customImports.set('funkin.play.notes.StrumlineNote', objects.StrumNote);
		// (made the way V-Slice makes one, `new StrumlineNote(noteStyle, isPlayer, direction)`, it's a receptor of that note style)
		HxcRuntime.constructors.set('objects.StrumNote', function(args:Array<Dynamic>):Dynamic
		{
			if(args.length < 3 || !Std.isOfType(args[0], funkin.play.notes.notestyle.NoteStyle)) return null;
			return new funkin.play.notes.StrumlineNote(args[0], args[1] == true, Std.int(args[2]));
		});
		// (scripts put flixel's back to center the game again after changing the window, "FlxG.scaleMode = new RatioScaleMode()":
		// the game's own one is that too, and it doesn't put the game's size back on its own, what other mods count on)
		HxcRuntime.constructors.set('flixel.system.scaleModes.RatioScaleMode', function(args:Array<Dynamic>):Dynamic
		{
			if(args.length > 0 && args[0] == true) return null;
			return new backend.GameScaleMode();
		});
		HxcRuntime.customImports.set('funkin.play.notes.SustainTrail', funkin.play.notes.SustainTrail);
		HxcRuntime.customImports.set('funkin.group.FunkinGroup', funkin.modding.base.ScriptedClasses.ScriptedFlxTypedGroup);
		HxcRuntime.customImports.set('funkin.graphics.FunkinAnimationController', flixel.animation.FlxAnimationController);

		var tweenReplacements:Map<String, Dynamic> = [];
		tweenReplacements.set('flixel.tweens.FlxTween', safeTween);
		HxcRuntime.staticReplacements.set('tween', tweenReplacements);

		// (scripts check what their objects are with these too, and the classes they made are only known to the runtime)
		var typeCheck:Dynamic = function(std:Dynamic, value:Dynamic, type:Dynamic):Bool return HxcRuntime.isOfType(value, type);
		HxcRuntime.staticReplacements.set('isOfType', ['Std' => typeCheck]);
		HxcRuntime.staticReplacements.set('is', ['Std' => typeCheck]);
		HxcRuntime.customImports.set('polymod.hscript.HScriptedClass', hxc.HScriptedClass);
		HxcRuntime.customImports.set('funkin.data.song.SongTimeChange', funkin.data.song.SongData.SongTimeChange);
		HxcRuntime.customImports.set('StringTools', hxc.ScriptStringTools);
		HxcRuntime.customImports.set('funkin.graphics.video.FlxVideo', funkin.graphics.video.FunkinVideoSprite);
		HxcRuntime.globals.set('HScriptedClass', hxc.HScriptedClass);

		HxcRuntime.customImports.set('funkin.ui.mainmenu.MainMenuState', states.MainMenuState);
		HxcRuntime.customImports.set('funkin.ui.title.TitleState', states.TitleState);
		HxcRuntime.customImports.set('funkin.ui.story.StoryMenuState', states.StoryMenuState);
		HxcRuntime.customImports.set('funkin.ui.transition.LoadingState', states.LoadingState);
		HxcRuntime.customImports.set('funkin.ui.MusicBeatState', backend.MusicBeatState);
		HxcRuntime.customImports.set('funkin.ui.MusicBeatSubState', backend.MusicBeatSubstate);

		// (a prop of a stage that dances by itself: the same class here)
		HxcRuntime.customImports.set('funkin.play.stage.Bopper', funkin.play.stage.StageProp);
		HxcRuntime.customImports.set('funkin.play.stage.ScriptedBopper', funkin.play.stage.StageProp);
		HxcRuntime.customImports.set('funkin.play.stage.ScriptedStageProp', funkin.play.stage.StageProp);
		HxcRuntime.customImports.set('funkin.play.components.HealthIcon', objects.HealthIcon);
		HxcRuntime.customImports.set('funkin.ui.credits.CreditsState', states.CreditsState);
		HxcRuntime.customImports.set('funkin.ui.freeplay.FreeplayState', states.FreeplayStateVslice);

		// and so are the parts of the Freeplay menu their scripts extend
		HxcRuntime.customImports.set('funkin.ui.freeplay.backcards.BackingCard', objects.freeplay.FreeplayBackingCard);
		HxcRuntime.customImports.set('funkin.ui.freeplay.backcards.ScriptedBackingCard', objects.freeplay.FreeplayBackingCard);
		HxcRuntime.customImports.set('funkin.ui.freeplay.BGScrollingText', objects.freeplay.FreeplayBackingCard.BGScrollingText);
		HxcRuntime.customImports.set('funkin.ui.freeplay.dj.FreeplayDJState', objects.freeplay.FreeplayDJ.FreeplayDJStates);
		for (name in ['BaseFreeplayDJ', 'AnimateAtlasFreeplayDJ', 'SparrowFreeplayDJ', 'MultiSparrowFreeplayDJ', 'PackerFreeplayDJ'])
		{
			HxcRuntime.customImports.set('funkin.ui.freeplay.dj.$name', objects.freeplay.FreeplayDJ);
			HxcRuntime.customImports.set('funkin.ui.freeplay.dj.Scripted$name', objects.freeplay.FreeplayDJ);
		}

		// V-Slice gives its own `Assets` to the scripts that import the libraries' ones, which don't know about the files of the mods
		for (path in ['openfl.utils.Assets', 'openfl.Assets', 'lime.utils.Assets'])
			HxcRuntime.customImports.set(path, funkin.Assets);

		// Things newer versions of the libraries have
		var timerExtras:Map<String, Dynamic> = [];
		timerExtras.set('wait', function(time:Float, callback:Dynamic):FlxTimer
		{
			return new FlxTimer().start(time, function(_) callback());
		});
		timerExtras.set('loop', function(time:Float, callback:Dynamic, loops:Int):FlxTimer
		{
			return new FlxTimer().start(time, function(timer:FlxTimer) callback(timer.elapsedLoops), loops);
		});
		HxcRuntime.staticExtras.set('flixel.util.FlxTimer', timerExtras);

		var flickerExtras:Map<String, Dynamic> = [];
		flickerExtras.set('pause', function(flicker:flixel.effects.FlxFlicker):Void
		{
			if(flicker.timer != null) flicker.timer.active = false;
		});
		flickerExtras.set('resume', function(flicker:flixel.effects.FlxFlicker):Void
		{
			if(flicker.timer != null) flicker.timer.active = true;
		});
		HxcRuntime.memberExtras.set('flixel.effects.FlxFlicker', flickerExtras);

		// what V-Slice's flixel has on its cameras and this one's doesn't: stopping one of their effects, not all of them (`stopFX()`)
		var cameraExtras:Map<String, Dynamic> = [];
		cameraExtras.set('stopFade', function(camera:FlxCamera):Void
		{
			@:privateAccess
			{
				camera._fxFadeAlpha = 0;
				camera._fxFadeDuration = 0;
				camera._fxFadeComplete = null;
			}
		});
		cameraExtras.set('stopFlash', function(camera:FlxCamera):Void
		{
			@:privateAccess
			{
				camera._fxFlashAlpha = 0;
				camera._fxFlashComplete = null;
			}
		});
		cameraExtras.set('stopShake', function(camera:FlxCamera):Void
		{
			@:privateAccess
			{
				camera._fxShakeDuration = 0;
				camera._fxShakeComplete = null;
				camera.updateFlashSpritePosition();
			}
		});
		HxcRuntime.memberExtras.set('flixel.FlxCamera', cameraExtras);

		// The props of V-Slice stages that are sprite sheets are Psych's sprites here, with V-Slice's names for their animations
		var propExtras:Map<String, Dynamic> = [];
		// (called with as many arguments as the script gives: name, restart, ignoreOther, reversed)
		propExtras.set('playAnimation', Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			var prop:psychlua.ModchartSprite = args[0];
			var name:String = (args.length > 1 && args[1] != null) ? Std.string(args[1]) : null;
			var restart:Bool = args.length > 2 && args[2] == true;
			var reversed:Bool = args.length > 4 && args[4] == true;
			if(prop == null || name == null) return null;

			// (like V-Slice's `Bopper`: "idle-alt" plays "idle" when there's no "idle-alt")
			var found:String = name;
			while(found != null && !prop.animation.exists(found))
			{
				var dash:Int = found.lastIndexOf('-');
				found = (dash > 0) ? found.substr(0, dash) : null;
			}
			if(found != null) prop.playAnim(found, restart, reversed);
			return null;
		}));
		propExtras.set('loadTexture', function(prop:psychlua.ModchartSprite, key:String):Dynamic
		{
			// (V-Slice's `FunkinSprite.loadTexture()`: a picture of "images", the frames it had are gone)
			var graphic = funkin.Paths.image(key);
			if(graphic != null) prop.loadGraphic(graphic);
			return prop;
		});
		propExtras.set('hasAnimation', function(prop:psychlua.ModchartSprite, name:String):Bool return prop.animation.exists(name));
		propExtras.set('getCurrentAnimation', function(prop:psychlua.ModchartSprite):String return (prop.animation.curAnim != null) ? prop.animation.curAnim.name : '');
		propExtras.set('isAnimationFinished', function(prop:psychlua.ModchartSprite):Bool return prop.animation.curAnim == null || prop.animation.curAnim.finished);
		HxcRuntime.memberExtras.set('psychlua.ModchartSprite', propExtras);

		// A sound the game keeps track of can't be destroyed just like that, see FunkinSound.dispose()
		// A sprite that loaded a texture atlas has its animations played by the atlas (see funkin.graphics.FunkinSprite.loadTextureAtlas()),
		// that's what its `animation` is to scripts. The same goes for the ones made with `FunkinSprite.createTextureAtlas()`
		var atlasAnimation:Map<String, Dynamic> = [];
		atlasAnimation.set('funkin.graphics.FunkinSprite', function(sprite:funkin.graphics.FunkinSprite):Dynamic
			return (sprite.atlas != null) ? sprite.atlas.player : null);
		atlasAnimation.set('objects.AtlasSprite', function(sprite:objects.AtlasSprite):Dynamic return sprite.player);
		// (a character's: see funkin.play.character.AtlasCharacterAnimation)
		atlasAnimation.set('objects.Character', function(char:objects.Character):Dynamic
			return (char.isAnimateAtlas && char.atlas != null) ? new funkin.play.character.AtlasCharacterAnimation(char) : null);
		HxcRuntime.memberGetters.set('animation', atlasAnimation);

		// V-Slice's texture atlas library can draw a sprite inside of an atlas' frames, the one used here can't
		HxcRuntime.customImports.set('animate.internal.elements.FlxSpriteElement', funkin.graphics.SpriteElement);

		var soundDestroy:Map<String, Dynamic> = [];
		soundDestroy.set('flixel.sound.FlxSound', function(sound:FlxSound):Void funkin.audio.FunkinSound.dispose(sound));
		HxcRuntime.memberReplacements.set('destroy', soundDestroy);

		// The texture atlases scripts make (`FunkinSprite.createTextureAtlas()`) are played the way V-Slice's are:
		// "sprite.anim.play('label')" for a frame label of the main timeline, or with no name for the whole thing
		for (name in ['play', 'pause', 'resume'])
		{
			var atlasAnim:Map<String, Dynamic> = [];
			atlasAnim.set('flxanimate.animate.FlxAnim', Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
			{
				var anim:flxanimate.animate.FlxAnim = args[0];
				var parent:FlxSprite = null;
				@:privateAccess parent = anim._parent;

				var atlas:objects.AtlasSprite = Std.downcast(parent, objects.AtlasSprite);
				switch(name)
				{
					case 'play':
						if(atlas != null) atlas.player.play((args[1] != null) ? args[1] : '', args[2] == true, args[3] == true, (args[4] != null) ? args[4] : 0);
						else anim.play(args[1], args[2], args[3], args[4]);
					case 'pause':
						if(atlas != null) atlas.player.pause();
						else anim.pause();
					default:
						if(atlas != null) atlas.player.resume();
						else anim.resume();
				}
				return null;
			}));
			HxcRuntime.memberReplacements.set(name, atlasAnim);
		}

		// `using StringTools;`: the library's own goes to Haxe's, where the inline functions (`contains()`...) can't be called
		var usingEntries = crowplexus.iris.Iris.registeredUsingEntries;
		for (entry in usingEntries.copy())
			if(entry.name == 'StringTools')
				usingEntries.remove(entry);
		usingEntries.unshift(new crowplexus.iris.utils.UsingEntry('StringTools', function(object:Dynamic, func:String, args:Array<Dynamic>):Dynamic
		{
			if(func == 'isEof') return null; //(not one of its "using" ones)
			if(Std.isOfType(object, Int) && func == 'hex') return StringTools.hex(object, args[0]);
			if(!Std.isOfType(object, String)) return null;

			var field:Dynamic = Reflect.field(hxc.ScriptStringTools, func);
			return Reflect.isFunction(field) ? Reflect.callMethod(hxc.ScriptStringTools, field, [object].concat(args)) : null;
		}));

		// `using funkin.util.AnsiUtil;`: colors for the texts scripts write to the console, which the engine's doesn't do
		var ansiPath:String = 'funkin.util.AnsiUtil';
		var registered:Bool = false;
		for (entry in crowplexus.iris.Iris.registeredUsingEntries)
			if(entry.name == ansiPath)
				registered = true;

		if(!registered)
		{
			crowplexus.iris.Iris.registerUsingGlobal(ansiPath, function(object:Dynamic, func:String, args:Array<Dynamic>):Dynamic
			{
				return (Std.isOfType(object, String) && funkin.util.AnsiUtil.NAMES.contains(func)) ? object : null;
			});
		}

		for (name => path in [
			'Module' => 'funkin.modding.module.Module',
			'ScriptedModule' => 'funkin.modding.module.ScriptedModule',
			'NoteKind' => 'funkin.play.notes.notekind.NoteKind',
			'ScriptedNoteKind' => 'funkin.play.notes.notekind.ScriptedNoteKind',
			'SongEvent' => 'funkin.play.event.SongEvent',
			'ScriptedSongEvent' => 'funkin.play.event.ScriptedSongEvent',
			'Song' => 'funkin.play.song.Song',
			'ScriptedSong' => 'funkin.play.song.ScriptedSong',
			'Stage' => 'funkin.play.stage.Stage',
			'ScriptedStage' => 'funkin.play.stage.ScriptedStage',
			'FunkinSprite' => 'funkin.graphics.FunkinSprite',
			'FlxSprite' => 'flixel.FlxSprite'
		]) HxcRuntime.defaultBases.set(name, path);

		for (cls in noImport)
		{
			var path:String = Type.getClassName(cls);
			HxcRuntime.fallbacks.set(path.substr(path.lastIndexOf('.') + 1), cls);
		}

		HxcRuntime.onError = onScriptError;
	}

	/**
	 * Loads the scripts of the mod the song is from and tells them the song was created.
	 * Called by PlayState when everything of the song exists (stage, characters, notes) and right before it starts the countdown:
	 * its own "onCreatePost" only comes after the countdown started, which scripts would miss.
	 */
	public static function create():Void
	{
		firstUpdate = true;
		refreshOnSongStart = false;
		load();
		if(!active) return;
		creating = true;

		// Each thing is told it was made in the order V-Slice makes them: the stage first, then the characters, which the stage
		// is given one by one (`addCharacter()`, what stage scripts replace to do things to them), and the song last.
		// Scripts count on it: a stage gives its characters what it made on its own `onCreate()`, and asks them for what they made on theirs
		dispatchToModules(new ScriptEvent(ScriptEventType.CREATE));
		callEvent(stageScript, new ScriptEvent(ScriptEventType.CREATE));
		for (character in characterScripts.copy())
			if(!createdCharacters.contains(character))
				callEvent(character, new ScriptEvent(ScriptEventType.CREATE));
		facade.currentStage.setupCharacters();

		// (on V-Slice the strumlines are made between the stage and the song, the song's script is told with them there)
		game.makeStrumsEarly();

		var created:ScriptEvent = new ScriptEvent(ScriptEventType.CREATE);
		callEvent(songScript, created);
		for (songEvent in chartSongEvents)
			callEvent(songEvent, created);
		for (kind in noteKinds)
			callEvent(kind, created);

		// The song starts over by making everything again, scripts expect to be told so they don't show their cutscenes twice.
		// Psych keeps track of that the same way for its own
		// The modules aren't told: on V-Slice they're the same ones that set things up for the song the first time, which they undo
		// or start over from there ("Restart Song" doesn't make anything again). Here they were made again along with everything
		// else and haven't set anything up yet, and doing what they do on a retry broke on what isn't there
		// What they do on a retry is undoing what they set up, and these haven't set anything up yet: a script that resets something it
		// makes at the countdown fails on it not being there (SKYREBORN's Sky). That's not an error of the mod, it isn't reported
		if(states.PlayState.seenCutscene)
		{
			hxc.HxcRuntime.quietErrors = true;
			try
			{
				dispatch(new SongRetryEvent(facade.currentDifficulty), false);
			}
			catch(e:Dynamic) {}
			hxc.HxcRuntime.quietErrors = false;
		}

		// The chart, as it was loaded. On V-Slice scripts can change it from here, that part isn't done: they only get to read it
		var notes:Array<SongNoteData> = [for (note in game.unspawnNotes) if(!note.isSustainNote) NoteSprite.get(note).noteData];
		var events:Array<SongEventData> = [for (event in game.eventNotes) makeEventData(event.event, event.value1, event.value2, event.strumTime)];
		facade.songEvents = events;
		dispatch(new SongLoadScriptEvent(facade.currentSong.id, facade.currentDifficulty, notes, events));

		// V-Slice tells its modules when a state is done opening, which is when some of them set their things up. Its modules were
		// updated many times before that (they last from the start of the game), and some only read their settings when they are:
		// these were just made, they get an update first. As on V-Slice, that's an update from before the song's PlayState is there
		// for them: a module that keeps the song's characters when it sees them on an update (the "Change Character" handler of
		// Schwiftying) and destroys what it kept when the state is done opening would destroy the song's own characters
		var playState:funkin.play.PlayState = funkin.play.PlayState.instance;
		funkin.play.PlayState.instance = null;
		dispatchToModules(new UpdateScriptEvent(0));
		funkin.play.PlayState.instance = playState;
		dispatchToModules(new StateChangeScriptEvent(ScriptEventType.STATE_CHANGE_END, facade));
		StepLog.add('Scripts started');
	}

	// The mod whose song is being played, and its script classes ahead of the base game's: when both have something for the same
	// song, stage, character or note, the mod's is the one that's used
	static var songMod:String = null;

	static function modFirst(list:Array<HxcClass>):Array<HxcClass>
	{
		var own:Array<HxcClass> = [];
		var others:Array<HxcClass> = [];
		for (cls in list)
			((getScriptMod(cls) == songMod) ? own : others).push(cls);
		return own.concat(others);
	}

	static function load():Void
	{
		clear();
		menuState = null;

		game = states.PlayState.instance;
		#if MODS_ALLOWED
		var mod:String = Mods.currentModDirectory;
		if(game == null || !PolymodCompat.isPolymod(mod)) return;

		setupRuntime();
		HxcRuntime.clear();
		funkin.data.notestyle.NoteStyleRegistry.instance.clearCache(); //(read again for each song)
		resetLog(LOG_PATH);

		var songData:Dynamic = (states.PlayState.SONG != null) ? states.PlayState.SONG.vslice : null;
		logHeader = 'Mod: ' + PolymodCompat.getDisplayName(mod) + '\n'
			+ 'Song: ' + ((states.PlayState.SONG != null) ? states.PlayState.SONG.song : '?')
			+ ' (difficulty: ' + Difficulty.getString(null, false) + ', variation: ' + ((songData != null && songData.variation != null) ? songData.variation : 'default') + ')\n'
			+ 'Stage: ' + states.PlayState.curStage + '\n'
			+ 'Characters: ' + [for (char in [game.boyfriend, game.dad, game.gf]) if(char != null) char.curCharacter].join(', ') + '\n'
			+ 'Story Mode: ' + states.PlayState.isStoryMode + '\n'
			+ 'Date: ' + Date.now().toString() + '\n';

		StepLog.add('Loading the scripts of "$mod" for the song "' + ((states.PlayState.SONG != null) ? states.PlayState.SONG.song : '?') + '" (stage: ' + states.PlayState.curStage + ', story mode: ' + states.PlayState.isStoryMode + ')');
		// A V-Slice mod is made on top of the base game, and uses its stages, characters, note kinds and events: their scripts are
		// loaded for the mod's songs too (the V-Slice content that comes with the engine), and the mod's own take the place of the ones
		// that have the same name. A mod with no scripts at all still has V-Slice's own song events to be run by this.
		songMod = mod;
		if(mod != PolymodCompat.BASE_MOD) HxcRuntime.loadFolder(Paths.mods(PolymodCompat.BASE_MOD + '/scripts'));
		HxcRuntime.quietReplace = true;
		HxcRuntime.loadFolder(Paths.mods('$mod/scripts'));
		HxcRuntime.quietReplace = false;

		facade = new funkin.play.PlayState(game);
		funkin.play.PlayState.instance = facade;
		active = true;

		// things a script imports that don't exist here will fail when it uses them, better to say which ones up front
		var missing:Array<String> = [];
		var seenModules:Array<HxcModule> = [];
		for (cls in HxcRuntime.classes)
		{
			if(seenModules.contains(cls.module)) continue;
			seenModules.push(cls.module);

			// (a script class of the mod, imported by its name from another file of the mod, is there: it's not the engine's to have)
			for (path in cls.module.missingImports)
			{
				if(HxcRuntime.classes.exists(path.split('.').pop())) continue;
				if(!missing.contains(path)) missing.push(path);
				logMissing.push(path + '  (' + shortPath(cls.module.path) + ')');
			}
			for (path in cls.module.unusedImports)
				if(!logUnused.contains(path) && !HxcRuntime.classes.exists(path.split('.').pop()))
					logUnused.push(path);
		}
		logMissing.sort(Reflect.compare);
		logUnused.sort(Reflect.compare);

		if(missing.length > 0)
		{
			trace('[HXC] Imports that are not supported: ' + missing.join(', '));
			game.addTextToDebug('[HXC] Not supported: ' + missing.join(', '), FlxColor.YELLOW);
			writeLog();
		}

		var credits:Array<Dynamic> = CreditsDataHandler.snapshot();
		for (cls in HxcRuntime.listSubclasses(Module))
		{
			var module:HxcInstance = HxcRuntime.instantiate(cls, [cls.name]);
			if(module == null || module.base == null) continue;

			recallModule(module);
			modules.push(module);
		}
		modules.sort((a, b) -> cast(a.base, Module).priority - cast(b.base, Module).priority);
		CreditsDataHandler.collect(mod, credits);

		// (the base game's own are the boxes the engine already makes the way those scripts would: nothing to tell about them)
		for (cls in HxcRuntime.listSubclasses(funkin.play.cutscene.dialogue.DialogueBox))
			if(getScriptMod(cls) != PolymodCompat.BASE_MOD)
				warn('The dialogue box script "${cls.name}" is not run: the boxes are made by the engine out of their data files', true);

		for (cls in modFirst(HxcRuntime.listSubclasses(SongEvent)))
		{
			var event:HxcInstance = HxcRuntime.instantiate(cls, ['UKNOWN']);
			if(event != null && event.base != null && !songEvents.exists(cast(event.base, SongEvent).id)) songEvents.set(cast(event.base, SongEvent).id, event);
		}

		var eventKinds:Array<String> = (songData != null && Std.isOfType(songData.eventKinds, Array)) ? cast(songData.eventKinds, Array<Dynamic>).map(kind -> Std.string(kind)) : [];
		for (event in game.eventNotes)
		{
			// (the ones that were added to the converted chart, on the chart editor)
			var kind:String = makeEventData(event.event, event.value1, event.value2, event.strumTime).eventKind;
			if(!eventKinds.contains(kind)) eventKinds.push(kind);
		}
		eventKinds.sort(Reflect.compare);
		for (kind in eventKinds)
			if(songEvents.exists(kind))
				chartSongEvents.push(songEvents.get(kind));

		for (cls in modFirst(HxcRuntime.listSubclasses(NoteKind)))
		{
			var kind:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
			if(kind != null && kind.base != null && !noteKinds.exists(cast(kind.base, NoteKind).noteKind)) noteKinds.set(cast(kind.base, NoteKind).noteKind, kind);
		}

		loadSongScript();
		findCharacterScripts(); //(before the stage is built: stage scripts make characters of their own there, which get their scripts too)
		loadStageScript();
		loadCharacterScripts();
		applyNoteKinds();

		// the look of the song's note style, for each side (its notes are all made by now, the receptors may not be yet)
		facade.opponentStrumline.applyNoteStyle();
		facade.playerStrumline.applyNoteStyle();
		#end
	}

	// The script made for the song, the one for the variation being played if there's one
	static function loadSongScript():Void
	{
		var data:Dynamic = (states.PlayState.SONG != null) ? states.PlayState.SONG.vslice : null;
		var songKey:String = (data != null) ? data.key : Paths.formatToSongPath(Song.loadedSongName);
		var variation:String = (data != null && data.variation != null) ? data.variation : 'default';
		facade.currentVariation = variation;

		var fallback:HxcInstance = null;
		for (cls in modFirst(HxcRuntime.listSubclasses(VSliceSongScript)))
		{
			var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
			if(script == null || script.base == null) continue;

			var song:VSliceSongScript = cast script.base;
			if(Paths.formatToSongPath(song.id) != songKey) continue;

			if(song.variation == variation)
			{
				songScript = script;
				break;
			}
			if(song.variation == 'default' && fallback == null) fallback = script;
		}
		if(songScript == null) songScript = fallback;

		var song:VSliceSongScript = (songScript != null) ? cast songScript.base : new VSliceSongScript(songKey, {variation: variation});
		if(states.PlayState.SONG != null) song.songName = states.PlayState.SONG.song;
		if(data != null)
		{
			song.songArtist = data.artist;
			song.charter = data.charter;
		}
		facade.currentSong = song;

		var chart:backend.Song.SwagSong = states.PlayState.SONG;
		var characters:Dynamic = (data != null && data.characters != null) ? data.characters : {};
		facade.currentChart = {
			song: song,
			songName: song.songName,
			songArtist: song.songArtist,
			charter: song.charter,
			album: (data != null && data.album != null) ? data.album : 'volume1',
			variation: variation,
			difficulty: (data != null && data.difficulty != null) ? data.difficulty : facade.currentDifficulty,
			stage: states.PlayState.curStage,
			noteStyle: (data != null && data.noteStyle != null) ? data.noteStyle : 'funkin',
			scrollSpeed: (chart != null) ? chart.speed : 1,
			characters: {
				player: (characters.player != null) ? characters.player : ((chart != null) ? chart.player1 : 'bf'),
				opponent: (characters.opponent != null) ? characters.opponent : ((chart != null) ? chart.player2 : 'dad'),
				girlfriend: (characters.girlfriend != null) ? characters.girlfriend : ((chart != null) ? chart.gfVersion : 'gf'),
				instrumental: (characters.instrumental != null) ? characters.instrumental : '',
				altInstrumentals: (characters.altInstrumentals != null) ? characters.altInstrumentals : []
			}
		};
	}

	static function loadStageScript():Void
	{
		var stageId:String = states.PlayState.curStage;
		for (cls in modFirst(HxcRuntime.listSubclasses(Stage)))
		{
			var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
			if(script == null || script.base == null || cast(script.base, Stage).id != stageId) continue;

			stageScript = script;
			break;
		}
		facade.currentStage = (stageScript != null) ? cast stageScript.base : new Stage(stageId);
		facade.currentStage.madeForSong = true;

		// where stage scripts add their own things to the stage
		if(stageScript != null)
		{
			StepLog.add(stageScript.cls.name + ': buildStage');
			stageScript.call('buildStage');
		}
	}

	static inline final UNKNOWN_CHARACTER:String = 'UNKNOWN';

	// The script class made for each character, by the character's id
	static var characterClasses:Map<String, HxcClass> = null;

	// The scripts that were already told their character was made: the ones of the characters other scripts make are told right away
	static var createdCharacters:Array<HxcInstance> = [];

	// Nene (and the characters made from her script) raises her knife at Boyfriend when his health is low. With Play as Opponent
	// Boyfriend is the computer's: that's only a threat to him when Health Drain is on too, otherwise she stays calm (her threshold
	// is put where the health never gets). Without Play as Opponent nothing changes
	static function calmLowHealthThreat(script:HxcInstance):Void
	{
		if(game == null || !game.playAsOpponent || game.healthDrain > 0) return;
		if(script.hasMember('VULTURE_THRESHOLD'))
		{
			script.setField('VULTURE_THRESHOLD', -1);
			StepLog.add('Play as Opponent: ' + script.cls.name + ' keeps her knife down');
		}
	}

	static function loadCharacterScripts():Void
	{
		for (char in [game.boyfriend, game.dad, game.gf])
			attachCharacterScript(char);
	}

	// Character scripts say who they're for when they're made, the ones for a character of the song are made again attached to it
	static function findCharacterScripts():Void
	{
		characterClasses = [];
		createdCharacters = [];
		for (cls in modFirst(HxcRuntime.listSubclasses(BaseCharacter)))
		{
			// V-Slice makes each one with this id to find out which character it's really for: most give their own to `super()`,
			// and the ones other scripts extend (which take an id instead) turn this one into their own
			var probe:HxcInstance = HxcRuntime.instantiate(cls, [UNKNOWN_CHARACTER]);
			if(probe == null || !Std.isOfType(probe.base, BaseCharacter)) continue;

			var id:String = cast(probe.base, BaseCharacter).characterId;
			if(id != null && id != UNKNOWN_CHARACTER && !characterClasses.exists(id)) characterClasses.set(id, cls);
		}
	}

	/**
	 * Gives a character the script made for it, if the mod has one and it doesn't have it yet. Returns the script.
	 * The characters of the song get theirs by themselves, this is for the ones scripts make (`CharacterDataParser.fetchCharacter()`).
	 *
	 * @param created 	If the script is told right away that the character was made: V-Slice does it as soon as it makes one.
	 */
	public static function attachCharacterScript(char:Character, created:Bool = false):HxcInstance
	{
		if(!active || char == null || characterClasses == null) return null;

		var existing:HxcInstance = HxcRuntime.getInstance(char);
		if(existing != null) return existing;

		var cls:HxcClass = characterClasses.get(char.curCharacter);
		if(cls == null) return null;

		// (along with an object of the class the script extends, for what Psych's characters don't have: see BaseCharacter)
		var script:HxcInstance = HxcRuntime.instantiate(cls, [char.curCharacter], char, true);
		if(script == null) return null;

		characterScripts.push(script);
		watchAnimations(char, script);
		applyAtlasSettings(char, script);
		calmLowHealthThreat(script);

		// what the script does its own way, for the character to send there
		var overrides:Array<String> = [for (name in CHARACTER_OVERRIDES) if(script.hasMethod(name)) name];
		char.scriptOverrides = (overrides.length > 0) ? overrides : null;

		if(created)
		{
			createdCharacters.push(script);
			callEvent(script, new ScriptEvent(ScriptEventType.CREATE));
		}
		return script;
	}

	/**
	 * Called by the stage when a character is put on it, which the character's script is told about.
	 */
	/**
	 * A character that's gone from the song (another one took its place): its script isn't told about anything anymore.
	 */
	/**
	 * Set while the countdown is being started without asking the scripts, see `funkin.play.PlayState.startSong()`.
	 */
	public static var countdownForced:Bool = false;

	/**
	 * The song's PlayState is being made. V-Slice's `PlayState.create()` ends by putting everything in the order of its layers
	 * (`refresh()`), so what scripts added while it was made goes in its layer without them asking: a health bar's frame added
	 * without one (0) ends up under the icons (850). A script that skips the countdown starts the song in the middle of that, so
	 * what it adds when the song starts is put in order too (the MCM mod's Dehydrated).
	 */
	public static var creating(default, null):Bool = false;
	static var refreshOnSongStart:Bool = false;

	public static function songStartedWhileCreating():Void
	{
		if(creating) refreshOnSongStart = true;
	}

	/**
	 * Called by the PlayState when it's done being made.
	 */
	public static function createDone():Void
	{
		if(!creating) return;
		creating = false;
		if(active && facade != null) facade.refresh();
	}

	public static function characterRemoved(char:Character):Void
	{
		if(char == null) return;
		var script:HxcInstance = HxcRuntime.getInstance(char);
		if(script != null) characterScripts.remove(script);
	}

	/**
	 * A script put another stage in the place of the song's: its script is the stage's one from now on.
	 */
	public static function stageChanged(stage:Stage):Void
	{
		if(!active || stage == null) return;
		var script:HxcInstance = HxcRuntime.getInstance(stage);
		if(script == stageScript) return;

		stageScript = script;
		if(script != null) StepLog.add(script.cls.name + ': the stage now');
	}

	/**
	 * The stage made by a script for that stage, for `StageRegistry.fetchEntry()`. Null if no script has one.
	 */
	public static function makeStageScript(id:String):Stage
	{
		if(!active) return null;
		for (cls in modFirst(HxcRuntime.listSubclasses(Stage)))
		{
			var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
			if(script != null && script.base != null && cast(script.base, Stage).id == id) return cast script.base;
		}
		return null;
	}

	/**
	 * The sticker pack made by a script for that id (a script's pack says which one it is on its constructor). Null if no script has one.
	 */
	public static function makeStickerPackScript(id:String):funkin.ui.transition.stickers.StickerPack
	{
		for (cls in modFirst(HxcRuntime.listSubclasses(funkin.ui.transition.stickers.StickerPack)))
		{
			var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
			if(script != null && script.base != null && cast(script.base, funkin.ui.transition.stickers.StickerPack).id == id) return cast script.base;
		}
		return null;
	}

	/**
	 * Calls a function of an object, the version its script has if it has one (engine code calling the object itself gets the engine's).
	 */
	public static function callScripted(object:Dynamic, name:String, args:Array<Dynamic>):Dynamic
	{
		var script:HxcInstance = HxcRuntime.getInstance(object);
		if(script != null && script.findMethod(name) != null) return script.call(name, args);
		return Reflect.callMethod(object, Reflect.field(object, name), args);
	}

	/**
	 * Sends an event to one object's script (`ScriptEventDispatcher.callEvent()`).
	 */
	public static function sendEvent(target:Dynamic, event:ScriptEvent):Void
	{
		var script:HxcInstance = HxcRuntime.getInstance(target);
		if(script != null) callEvent(script, event);
	}

	public static function characterAdded(char:Character):Void
	{
		if(!active || char == null) return;

		var script:HxcInstance = HxcRuntime.getInstance(char);
		if(script != null && characterScripts.contains(script)) callEvent(script, new ScriptEvent(ScriptEventType.ADDED));
	}

	// On V-Slice a character's script can say how its texture atlas is loaded (`getAtlasSettings()`). Here the atlas is already there
	// when the script is made, so what can still be done is: the function that's given each symbol of the atlas, to change them
	static function applyAtlasSettings(char:Character, script:HxcInstance):Void
	{
		#if flxanimate
		if(!char.isAnimateAtlas || !script.hasMethod('getAtlasSettings')) return;

		var settings:Dynamic = script.call('getAtlasSettings');
		if(settings != null && Reflect.field(settings, 'useRenderTexture') == true) char.useRenderTexture = true;
		var onSymbol:Dynamic = (settings != null) ? Reflect.field(settings, 'onSymbolCreate') : null;
		if(onSymbol == null || !Reflect.isFunction(onSymbol)) return;

		var oldWidth:Float = char.width;
		var oldHeight:Float = char.height;
		for (atlas in char.getAtlases())
			atlas.forEachSymbol(onSymbol);

		// The character was put on its place by the size it had (V-Slice's are put by their feet): it stays on its feet
		if(char.cornerPosition)
		{
			char.updateHitbox();
			char.x += (oldWidth - char.width) / 2;
			char.y += oldHeight - char.height;
		}
		#end
	}

	/**
	 * The sound a V-Slice character's script has for when it dies, null if it has none.
	 */
	public static function getDeathQuote(char:Character):openfl.media.Sound
	{
		if(!active || char == null) return null;

		var script:HxcInstance = HxcRuntime.getInstance(char);
		if(script == null || !script.hasMethod('getDeathQuote')) return null;

		var quote:Dynamic = script.call('getDeathQuote');
		if(quote == null) return null;

		@:privateAccess
		return funkin.audio.FunkinSound.resolve(quote);
	}

	// Functions of Psych's characters that go to the script's version, when it has one
	static final CHARACTER_OVERRIDES:Array<String> = ['update', 'dance', 'playAnimation', 'set_alpha', 'set_visible', 'set_x', 'set_y', 'set_angle', 'set_color'];

	// V-Slice's characters are told about each frame of their animations and when they end
	static function watchAnimations(char:Character, script:HxcInstance):Void
	{
		if(char.isAnimateAtlas)
		{
			// texture atlases have their own animations
			#if flxanimate
			if(char.atlas == null) return;

			// (each of its atlases, when its animations are on more than one: only the one being shown plays)
			for (atlas in char.getAtlases())
			{
				if(script.hasMethod('onAnimationFrame'))
				{
					atlas.anim.onFrame.add(function(frame:Int)
					{
						if(active && char.atlas == atlas) script.call('onAnimationFrame', [char.getAnimationName(), frame, frame]);
					});
				}
				if(script.hasMethod('onAnimationFinished'))
				{
					atlas.anim.onComplete.add(function()
					{
						// (the ones that loop tell about it every time around, which isn't ending)
						if(active && char.atlas == atlas && atlas.anim != null && atlas.anim.finished) script.call('onAnimationFinished', [char.getAnimationName()]);
					});
				}
			}
			#end
			return;
		}

		if(script.hasMethod('onAnimationFrame'))
		{
			char.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
			{
				if(active) script.call('onAnimationFrame', [name, frameNumber, frameIndex]);
			};
		}
		if(script.hasMethod('onAnimationFinished'))
		{
			char.animation.finishCallback = function(name:String)
			{
				if(active) script.call('onAnimationFinished', [name]);
			};
		}
	}

	// Notes of a kind that has a note style have its look (on V-Slice the kind's style is the one of the note itself, its hold and the rest
	// are the strumline's)
	static function applyNoteKinds():Void
	{
		kindStyles = [];
		for (name => kind in noteKinds)
		{
			var styleId:String = cast(kind.base, NoteKind).noteStyleId;
			if(styleId == null) continue;

			var style:funkin.play.notes.notestyle.NoteStyle = null;
			try
			{
				style = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry(styleId);
			}
			catch(e:Dynamic)
			{
				trace('[HXC] Could not read the note style "$styleId": $e');
			}
			if(style != null) kindStyles.set(name, style);
		}

		for (note in game.unspawnNotes)
		{
			var kind:HxcInstance = (note.noteType != null) ? noteKinds.get(note.noteType) : null;
			if(kind == null)
			{
				if(note.noteType == 'noanim') note.noAnimation = true; //a kind of the base game: notes nobody sings
				continue;
			}

			if(cast(kind.base, NoteKind).noanim) note.noAnimation = true;

			var style:funkin.play.notes.notestyle.NoteStyle = kindStyles.get(note.noteType);
			if(style != null && !note.isSustainNote) style.applyToNote(note);
		}
	}

	// The note styles of the note kinds that have one, by the kind
	static var kindStyles:Map<String, funkin.play.notes.notestyle.NoteStyle> = [];

	/**
	 * If a note is of a kind that has a note style of its own, which it keeps when the style of its side changes.
	 */
	public static function hasKindStyle(note:Note):Bool
	{
		return note != null && !note.isSustainNote && note.noteType != null && kindStyles.exists(note.noteType);
	}

	// On V-Slice a module lives for as long as the game is open, and mods count on what it remembers ("the intro video was
	// already shown", so it isn't shown every time the title screen comes back). Here the modules are made again for each menu
	// and each song: the plain values their variables had (numbers, texts, true or false) are kept and given back to the new ones
	static var moduleMemory:Map<String, Map<String, Dynamic>> = [];

	static function memoryKey(module:HxcInstance):String
	{
		return module.cls.module.path + '#' + module.cls.name;
	}

	// (only what the modules of the menus leave: a song is made again from the start when it's restarted, and modules of a song
	// that remember having set something up for it, without what they set up, break there. Theirs start over with the song)
	static var modulesOfMenu:Bool = false;

	static function rememberModules():Void
	{
		if(!modulesOfMenu) return;

		for (module in modules)
		{
			if(module == null || module.cls == null) continue;
			moduleMemory.set(memoryKey(module), module.plainFields());
			// (and its class': on V-Slice it's never loaded again either, a module that keeps a setting in both has them agree)
			moduleMemory.set(memoryKey(module) + '#statics', module.cls.plainStatics());
		}
	}

	static function recallModule(module:HxcInstance):Void
	{
		var keptStatics:Map<String, Dynamic> = moduleMemory.get(memoryKey(module) + '#statics');
		if(keptStatics != null) module.cls.restoreStatics(keptStatics);

		var kept:Map<String, Dynamic> = moduleMemory.get(memoryKey(module));
		if(kept != null) module.restoreFields(kept);
	}

	// A tween of something that isn't there closes the game on flixel ("The object does not have the property..."), from inside
	// of its own update, where nothing of a script can be caught. Scripts ask for those when the engine's version of something
	// doesn't have what V-Slice's has (or doesn't have the thing at all): what can't be tweened is left out, and told on the log
	static function safeTween(_:Dynamic, object:Dynamic, values:Dynamic, ?duration:Dynamic, ?options:Dynamic):FlxTween
	{
		var time:Float = (duration != null && Std.isOfType(duration, Float)) ? duration : 1;
		var kept:Dynamic = {};
		var count:Int = 0;

		if(values != null && Reflect.isObject(values))
		{
			for (path in Reflect.fields(values))
			{
				var target:Dynamic = object;
				var parts:Array<String> = path.split('.');
				var field:String = parts.pop();
				for (part in parts)
				{
					target = (target != null) ? Reflect.getProperty(target, part) : null;
					if(target == null || !Reflect.isObject(target))
					{
						target = null;
						break;
					}
				}

				var current:Dynamic = (target != null) ? Reflect.getProperty(target, field) : null;
				if(current != null && Std.isOfType(current, Float) && !Math.isNaN(current))
				{
					Reflect.setField(kept, path, Reflect.field(values, path));
					count++;
				}
				else
				{
					var what:String = (object == null) ? 'something that does not exist here' : Type.getClassName(Type.getClass(object));
					if(what == null) what = Std.string(object);
					warn('A tween of "$path" was asked for $what, which has none: that part of it was left out', true);
				}
			}
		}

		// (what the script does when it's over still has to happen)
		if(count < 1) return FlxTween.num(0, 1, time, options);
		return FlxTween.tween(object, kept, time, options);
	}

	/**
	 * The mod a script's object is from, null if it's from none (the engine's own content).
	 */
	public static function modOf(script:HxcInstance):String
	{
		return (script != null && script.cls != null) ? getScriptMod(script.cls) : null;
	}

	static function clear():Void
	{
		kindStyles = [];
		rememberModules();
		modulesOfMenu = false;
		active = false;
		modules = [];
		songEvents = [];
		chartSongEvents = [];
		noteKinds = [];
		songScript = null;
		stageScript = null;
		characterScripts = [];
		characterClasses = null;
		pendingHit = null;
		facade = null;
		funkin.play.PlayState.instance = null;
		moduleMods = new haxe.ds.ObjectMap();
		scriptedPlayers = null;
		overrideGuards = new haxe.ds.ObjectMap();
		animationSignals = new haxe.ds.ObjectMap();
		SongSequence.clearAll();
		skipSongEnd = false;

		// what scripts leave on the classes that aren't made again with them
		funkin.play.GameOverSubState.reset();
		funkin.play.PauseSubState.reset();
		funkin.play.cutscene.VideoCutscene.reset();
		funkin.Conductor.reset();
	}

	/**
	 * Set when something ends the song for good (`endSong(true)`, the end of a video that plays after it):
	 * scripts already had their say about it, they aren't asked again.
	 */
	public static var skipSongEnd:Bool = false;

	/**
	 * Called when PlayState is destroyed.
	 */
	public static function destroy():Void
	{
		if(active) dispatch(new ScriptEvent(ScriptEventType.DESTROY));

		// (V-Slice kills the stage as the song is left, stage scripts clean up after themselves there)
		if(active && stageScript != null && stageScript.hasMethod('kill')) stageScript.call('kill');

		clear();
		game = null;
		HxcRuntime.clear();
	}

	// ------------------------------------------------------------------------------------------
	// Events
	// ------------------------------------------------------------------------------------------

	/**
	 * Sends an event to every script, in the order V-Slice does: modules, song, song events, note kinds, stage and characters.
	 * Events about a note only go to the note kind of that note.
	 */
	public static function dispatch(event:ScriptEvent, toModules:Bool = true):Void
	{
		if(!active || event == null) return;

		if(toModules) dispatchToModules(event);
		callEvent(songScript, event);

		for (songEvent in chartSongEvents)
			callEvent(songEvent, event);

		if(Std.isOfType(event, NoteScriptEvent))
		{
			var note:NoteSprite = cast(event, NoteScriptEvent).note;
			if(note != null && note.kind != null) callEvent(noteKinds.get(note.kind), event);
		}
		else
		{
			for (kind in noteKinds)
				callEvent(kind, event);
		}

		callEvent(stageScript, event);
		for (character in characterScripts)
			callEvent(character, event);
	}

	public static function dispatchToModules(event:ScriptEvent):Void
	{
		for (module in modules)
		{
			var base:Module = cast module.base;
			if(base.active && wantsState(base)) callEvent(module, event);
		}
	}

	// Modules can ask to only be told about what happens on one state, by its class
	static function wantsState(module:Module):Bool
	{
		var wanted:Dynamic = module.state;
		if(wanted == null || !Std.isOfType(wanted, Class)) return true;

		if(menuState != null) return Std.isOfType(menuState, wanted);
		return facade != null && Std.isOfType(facade, wanted);
	}

	// The events that happen a few times per song are written down before each script gets them:
	// if one of them makes the game stop answering, the last line of "last_steps.txt" says which
	static var firstUpdate:Bool = true;
	static var stepEvents:Array<String> = ['CREATE', 'DESTROY', 'COUNTDOWN_START', 'COUNTDOWN_END', 'SONG_START', 'SONG_END', 'SONG_RETRY', 'SONG_LOADED', 'GAME_OVER',
		'STATE_CHANGE_BEGIN', 'STATE_CHANGE_END'];

	static function callEvent(target:HxcInstance, event:ScriptEvent):Void
	{
		if(target == null) return;

		if(stepEvents.contains(event.type)) StepLog.add(target.cls.name + ': ' + event.type);

		// on the menus each module finds the files of its own mod
		#if MODS_ALLOWED
		var owner:String = (menuState != null) ? moduleMods.get(target) : null;
		var oldMod:String = Mods.currentModDirectory;
		if(owner != null) Mods.currentModDirectory = owner;
		#end

		target.call('onScriptEvent', [event]);
		if(event.shouldPropagate)
		{
			var callback:String = ScriptEventType.callbacks.get(event.type);
			if(callback != null) target.call(callback, [event]);
		}

		#if MODS_ALLOWED
		if(owner != null) Mods.currentModDirectory = oldMod;
		#end
	}

	/**
	 * Tells the scripts about something PlayState is telling to Psych's own scripts.
	 * Returns true if a script cancelled it, for the callbacks that can stop what's about to happen.
	 */
	public static function onCallback(name:String, args:Array<Dynamic>):Bool
	{
		if(!active) return false;
		if(args == null) args = [];

		switch(name)
		{
			case 'onUpdate':
				if(firstUpdate) StepLog.add('First update of the song');
				SongSequence.updateAll();
				// (online, what scripts take while the other player holds a long note is their "health drain" for a computer
				// opponent, on top of what each of that player's hits already costs: given back, see PlayState.opponentNoteHit())
				var healthBefore:Float = game.health;
				dispatch(new UpdateScriptEvent(args[0]));
				if(game.otherSideHolding() && game.health < healthBefore) game.health = healthBefore;
				sectionFocusEvents();
				if(firstUpdate)
				{
					firstUpdate = false;
					StepLog.add('First update done');
				}

			case 'onCreatePost':
				StepLog.add('The song was created');
				dispatchToModules(new ScriptEvent(ScriptEventType.STATE_CREATE));

			case 'onStepHit':
				funkin.Conductor.dispatchSongStep();
				dispatch(new SongTimeScriptEvent(ScriptEventType.SONG_STEP_HIT, game.curBeat, game.curStep));

			case 'onSectionHit':
				funkin.Conductor.dispatchSongMeasure();

			case 'onBeatHit':
				bopCamera();
				danceExtras(game.curBeat);
				funkin.Conductor.dispatchSongBeat();
				dispatch(new SongTimeScriptEvent(ScriptEventType.SONG_BEAT_HIT, game.curBeat, game.curStep));

			case 'onStartCountdown':
				// (started by `PlayState.startSong()` because a script cancelled it: it's not asked about again)
				if(countdownForced) return false;
				return cancelable(new CountdownScriptEvent(ScriptEventType.COUNTDOWN_START, 'BEFORE'));

			case 'onCountdownStarted':
				// the receptors exist now
				facade.playerStrumline.apply();
				facade.opponentStrumline.apply();

				// V-Slice shows the HUD when the countdown starts: its cutscenes hide it and count on this to bring it back
				if(game.camHUD != null) game.camHUD.visible = true;

			case 'onCountdownTick':
				var counter:Int = args[1];
				if(counter >= 4) dispatch(new CountdownScriptEvent(ScriptEventType.COUNTDOWN_END, 'AFTER', false));
				else dispatch(new CountdownScriptEvent(ScriptEventType.COUNTDOWN_STEP, ['THREE', 'TWO', 'ONE', 'GO'][counter], false));

			case 'onSongStart':
				dispatch(new ScriptEvent(ScriptEventType.SONG_START));
				if(refreshOnSongStart)
				{
					refreshOnSongStart = false;
					if(facade != null) facade.refresh();
				}

			case 'onEndSong':
				if(skipSongEnd)
				{
					skipSongEnd = false;
					return false;
				}
				return cancelable(new ScriptEvent(ScriptEventType.SONG_END, true));

			case 'onPause':
				return cancelable(new PauseScriptEvent(false));

			case 'onResume':
				dispatch(new ScriptEvent(ScriptEventType.RESUME));

			case 'onGameOver':
				if(cancelable(new ScriptEvent(ScriptEventType.GAME_OVER, true))) return true;
				facade.cancelAllCameraTweens(); //the camera is the game over's from here on

			case 'onSpawnNote':
				var note:Note = Std.downcast(args[0], Note);
				if(note == null) return false;

				// notes of a side that was hidden don't show up either, and the ones of a faded group come in as faded as it is
				(note.mustPress ? facade.chartPlayerStrumline : facade.chartOpponentStrumline).noteSpawned(note);
				if(!note.isSustainNote)
				{
					dispatch(new NoteScriptEvent(ScriptEventType.NOTE_INCOMING, NoteSprite.get(note), 0, 0, false));
					if(facade != null) (note.mustPress ? facade.chartPlayerStrumline : facade.chartOpponentStrumline).onNoteIncoming.dispatch(NoteSprite.get(note));
				}

			case 'goodNoteHitPre', 'opponentNoteHitPre':
				return onNoteHitPre(name, Std.downcast(args[0], Note));

			case 'goodNoteHit', 'opponentNoteHit':
				onNoteHitPost(Std.downcast(args[0], Note));

			case 'noteMissPress':
				dispatch(new GhostMissNoteScriptEvent(args[0], false, -game.pressMissDamage, -10));
		}
		return false;
	}

	static function cancelable(event:ScriptEvent):Bool
	{
		dispatch(event);
		return event.eventCanceled;
	}

	// The camera's zoom on the beat, for the rates Psych doesn't do: it only zooms on the first beat of each section (every 4 beats).
	// Songs that ask for every beat or every other one (the "SetCameraBop" event) get the ones in between here
	static function bopCamera():Void
	{
		var rate:Int = facade.cameraZoomRate;
		if((rate != 1 && rate != 2) || game.curBeat % 4 == 0 || (game.curBeat + facade.cameraZoomRateOffset) % rate != 0) return;

		if(ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35)
		{
			FlxG.camera.zoom += 0.015 * game.camZoomingMult;
			game.camHUD.zoom += 0.03 * game.camZoomingMult;
		}
	}

	// ------------------------------------------------------------------------------------------
	// Notes
	// ------------------------------------------------------------------------------------------

	// Before PlayState does anything about a note being hit. Scripts can change what the hit is worth, or cancel it
	static function onNoteHitPre(callback:String, note:Note):Bool
	{
		if(note == null) return false;

		// The character PlayState gives the note to, and the side of the song it's on (the player's or the opponent's)
		var playerSide:Bool = note.mustPress;
		var psychChar:Character = note.gfNote ? game.gf : (playerSide ? game.boyfriend : game.dad);

		// holds aren't a hit of their own on V-Slice: they go with their note, if a script cancelled its hit nothing holds it either
		if(note.isSustainNote)
		{
			if(note.parent != null && note.parent.extraData.exists('vsliceCancelled')) return true;

			// (the others that are singing it keep at it, PlayState only knows about its own: and not even that one when the note
			// was sung by its script instead, which is what `noAnimation` means on a note that came through here)
			for (other in stageCharacters())
			{
				var held:Bool = (other == psychChar) ? note.noAnimation : singsSide(other, playerSide);
				if(held && other.getAnimationName() != null && other.getAnimationName().startsWith('sing'))
					other.holdTimer = 0;
			}
			return false;
		}

		// (with "Play as Opponent" the one playing is hitting the opponent's notes)
		var byPlayer:Bool = note.playable;
		var sprite:NoteSprite = NoteSprite.get(note);

		var event:HitNoteScriptEvent;
		var score:Float = 0;
		if(byPlayer)
		{
			var hitDiff:Float = note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset;
			var rating:Rating = Conductor.judgeNote(game.ratingsData, Math.abs(hitDiff) / game.playbackRate);
			score = rating.score;
			event = new HitNoteScriptEvent(sprite, note.hitHealth, score, rating.name, false, game.combo + 1, hitDiff, rating.noteSplash && !note.noteSplashData.disabled);
		}
		else event = new HitNoteScriptEvent(sprite, 0, 0, 'perfect', false, 0);

		// Note kinds can have their own singing animations: "singLEFT-(suffix)"
		var char:Character = psychChar;
		var kind:HxcInstance = (note.noteType != null) ? noteKinds.get(note.noteType) : null;
		if(kind != null)
		{
			var suffix:String = cast(kind.base, NoteKind).suffix;
			if(suffix != null && suffix.length > 0 && char != null && char.hasAnimation(game.singAnimations[note.noteData % game.singAnimations.length] + '-$suffix'))
				note.animSuffix = '-$suffix';
		}

		// On V-Slice the characters sing on their own `onNoteHit()`, which their scripts replace to do something else with some notes.
		// Here it's PlayState that makes them sing, so it has to know if the script of who's singing let it happen
		var everyone:Array<Character> = stageCharacters();
		for (other in everyone)
		{
			var base:BaseCharacter = scriptBase(other);
			if(base != null) base.sang = false;
		}

		dispatch(event);
		if(event.eventCanceled)
		{
			note.extraData.set('vsliceCancelled', true);
			return true;
		}
		note.extraData.remove('vsliceCancelled');

		// On V-Slice a note is sung by every character that's on its side at the moment ("bf" for the player's notes, "dad" for the
		// opponent's), whoever they are: songs with more than two singers pass the notes around by changing who's what.
		// PlayState only knows the song's own player and opponent, so it's told to leave the note alone when it isn't theirs to sing,
		// and the others are made to sing here
		if(char != null && (!letToSing(char, 'onNoteHit', true) || (!note.gfNote && !singsSide(char, playerSide))))
		{
			note.noAnimation = true;
			for (piece in note.tail)
				piece.noAnimation = true;
		}

		for (other in everyone)
		{
			if(other == char || !singsSide(other, playerSide) || !letToSing(other, 'onNoteHit', true)) continue;

			other.playSingAnimation(note.noteData % game.singAnimations.length, false, note.animSuffix);
			other.holdTimer = 0;
		}

		if(byPlayer)
		{
			if(event.healthChange != note.hitHealth) note.hitHealth = event.healthChange;
			if(!event.doesNotesplash) note.noteSplashData.disabled = true;
			pendingHit = {note: note, event: event, score: score};
		}
		return false;
	}

	// After PlayState gave the hit its score and combo, what the scripts changed about those is applied on top
	static function onNoteHitPost(note:Note):Void
	{
		if(pendingHit == null || pendingHit.note != note) return;

		var event:HitNoteScriptEvent = pendingHit.event;
		var changed:Bool = false;
		if(event.score != pendingHit.score)
		{
			game.songScore += Std.int(event.score - pendingHit.score);
			changed = true;
		}
		if(event.isComboBreak && game.combo != 0)
		{
			game.combo = 0;
			changed = true;
		}
		if(changed) game.updateScore(false, false);
		pendingHit = null;
	}

	/**
	 * Called by PlayState before a note counts as missed, returns true if a script cancelled the miss.
	 */
	public static function onNoteMiss(note:Note):Bool
	{
		if(!active || note == null) return false;

		// A piece of a hold that got away: the hold was let go of. Scripts are told once for each hold
		if(note.isSustainNote)
		{
			var head:Note = (note.parent != null) ? note.parent : note;
			if(head.wasGoodHit && !head.extraData.exists('vsliceDropped')) //(a hold whose first note was missed was never held)
			{
				head.extraData.set('vsliceDropped', true);
				dispatch(new HoldNoteScriptEvent(ScriptEventType.NOTE_HOLD_DROP, NoteSprite.get(head), -note.missHealth, 0, true, game.combo));
			}
			return false;
		}

		for (other in stageCharacters())
		{
			var base:BaseCharacter = scriptBase(other);
			if(base != null) base.missed = false;
		}

		var event:NoteScriptEvent = new NoteScriptEvent(ScriptEventType.NOTE_MISS, NoteSprite.get(note), -note.missHealth, game.combo, true);
		dispatch(event);
		if(event.eventCanceled) return true;

		if(event.healthChange != -note.missHealth) note.missHealth = -event.healthChange;
		return false;
	}

	// ------------------------------------------------------------------------------------------
	// Who sings
	// ------------------------------------------------------------------------------------------

	/**
	 * Every character on the stage: the three of the song and the ones scripts put there.
	 */
	public static function stageCharacters():Array<Character>
	{
		var list:Array<Character> = [];
		if(game == null) return list;

		for (char in [game.boyfriend, game.dad, game.gf])
			if(char != null && !list.contains(char)) list.push(char);

		if(facade != null && facade.currentStage != null)
			for (char in facade.currentStage.extraCharacters)
				if(char != null && char.exists && !list.contains(char)) list.push(char);
		return list;
	}

	// The side of the song a character is on: "bf" sings the player's notes and "dad" the opponent's.
	// (the song's own player and opponent are that until a script says otherwise: a character swapped in the middle of a song starts as nothing)
	static function singsSide(char:Character, playerSide:Bool):Bool
	{
		if(char == null) return false;

		var type:String = char.characterType;
		if(type == null || type == 'other')
		{
			if(char == game.boyfriend) type = 'bf';
			else if(char == game.dad) type = 'dad';
		}
		return playerSide ? (type == 'bf') : (type == 'dad');
	}

	static function scriptBase(char:Character):BaseCharacter
	{
		var script:HxcInstance = (char != null) ? HxcRuntime.getInstance(char) : null;
		return (script != null) ? Std.downcast(script.mixin, BaseCharacter) : null;
	}

	// If the character's script left the note to be sung (or missed) the usual way: the ones with their own `onNoteHit()` do it
	// by calling `super.onNoteHit(event)`, and skip that when they play something of their own
	static function letToSing(char:Character, method:String, hit:Bool):Bool
	{
		var script:HxcInstance = (char != null) ? HxcRuntime.getInstance(char) : null;
		var base:BaseCharacter = (script != null) ? Std.downcast(script.mixin, BaseCharacter) : null;
		if(base == null || !script.hasMethod(method)) return true;
		return hit ? base.sang : base.missed;
	}

	/**
	 * Called by PlayState when the player misses (a note, or a key pressed with nothing to hit), with the character it would play the
	 * animation of. Returns that character, or null if it isn't the one missing: on V-Slice it's whoever is singing the player's side.
	 * The side being played: the opponent's with "Play as Opponent" on, or online for the one playing the opponent (who sang the
	 * missed note is whoever sings its side of the chart, the miss animation is theirs).
	 */
	public static function missCharacters(char:Character, direction:Int, note:Note):Character
	{
		if(!active || game == null) return char;

		var playerSide:Bool = (note != null) ? note.mustPress : !game.playAsOpponent;

		var method:String = (note != null) ? 'onNoteMiss' : 'onNoteGhostMiss';
		var suffix:String = (note != null && note.animSuffix != null) ? note.animSuffix : '';
		var gfNote:Bool = (note != null && note.gfNote) || char == game.gf;

		for (other in stageCharacters())
		{
			if(other == char || !singsSide(other, playerSide)) continue;
			if(note != null && !letToSing(other, method, false)) continue;

			other.playSingAnimation(direction, true, suffix);
		}

		if(char == null) return null;
		if(note != null && !letToSing(char, method, false)) return null;
		return (gfNote || singsSide(char, playerSide)) ? char : null;
	}

	// The characters scripts added dance to the beat like the others, PlayState only makes its own do it
	static function danceExtras(beat:Int):Void
	{
		if(facade == null || facade.currentStage == null) return;

		for (char in facade.currentStage.extraCharacters)
		{
			if(char == null || !char.exists || !char.active || char.skipDance || char.danceEveryNumBeats < 1) continue;
			if(beat % char.danceEveryNumBeats != 0 || char.stunned) continue;

			// (V-Slice's rule: not over the singing, and not over something else that's still playing)
			var current:String = char.getCurrentAnimation();
			if(current.startsWith('sing')) continue;
			if(!current.startsWith('dance') && !current.startsWith('idle') && current.length > 0 && !char.isAnimationNull() && !char.isAnimationFinished()) continue;

			char.dance();
		}
	}

	// ------------------------------------------------------------------------------------------
	// Song events
	// ------------------------------------------------------------------------------------------

	// An event of a converted chart as V-Slice scripts know it. The ones Psych has no version of keep their values as JSON on the first value
	// The values the events of the song being played have on its V-Slice chart, by the kind of event (see `PolymodCompat.getChart()`)
	static var chartEventValues:Map<String, Array<{t:Float, v:Dynamic}>> = null;
	static var chartEventsSong:Dynamic = null;

	// The value an event has on the chart, as it's written there: the event at that time of that kind (Psych's has the note offset)
	static function chartEventValue(name:String, time:Float, value1:String, value2:String):{value:Dynamic}
	{
		var song:backend.Song.SwagSong = states.PlayState.SONG;
		if(song == null || song.vslice == null || song.vslice.eventValues == null) return null;

		if(chartEventsSong != song.vslice)
		{
			chartEventsSong = song.vslice;
			chartEventValues = [];
			var list:Array<Dynamic> = song.vslice.eventValues;
			for (event in list)
			{
				if(event == null || event.e == null) continue;
				var kind:String = Std.string(event.e);
				if(!chartEventValues.exists(kind)) chartEventValues.set(kind, []);
				chartEventValues.get(kind).push({t: (event.t != null) ? event.t : 0, v: event.v});
			}
		}

		var found:Array<{t:Float, v:Dynamic}> = chartEventValues.get(name);
		if(found == null) return null;

		// the ones at that time (more than one of a kind can be at the same time: a "change character" for each side), the one whose
		// values are the ones Psych's event got from it when there's more than one (see `VSliceConvert.convertEvent()`)
		var atTime:Array<{t:Float, v:Dynamic}> = [];
		for (offset in [ClientPrefs.data.noteOffset, 0])
		{
			for (event in found)
				if(Math.abs(event.t - (time - offset)) < 2)
					atTime.push(event);
			if(atTime.length > 0) break;
		}
		if(atTime.length < 1) return null;
		if(atTime.length == 1) return {value: atTime[0].v};

		for (event in atTime)
			if(sameEventValues(event.v, value1, value2))
				return {value: event.v};
		return {value: atTime[0].v};
	}

	// If a value of the chart is the one an event of Psych has as its two texts
	static function sameEventValues(value:Dynamic, value1:String, value2:String):Bool
	{
		if(value1 == null) value1 = '';
		if(value2 == null) value2 = '';
		if(value == null) return value1.length < 1 && value2.length < 1;
		if(Std.isOfType(value, String)) return value == value1;

		// Psych's own events kept on the chart: their two values
		var fields:Array<String> = Reflect.isObject(value) ? Reflect.fields(value) : [];
		if(fields.contains('value1') && fields.length <= 2)
			return Std.string(value.value1) == value1 && Std.string((value.value2 != null) ? value.value2 : '') == value2;

		// the ones converted to Psych's own ("Play Animation" has the animation first, "Change Scroll Speed" the speed)
		if(fields.contains('anim') && fields.contains('target')) return Std.string(value.anim) == value1;
		if(fields.contains('scroll')) return Std.parseFloat(Std.string(value.scroll)) == Std.parseFloat(value1);

		// the rest: written whole on the first text
		try
		{
			return haxe.Json.stringify(value) == value1 || haxe.Json.stringify(value) == haxe.Json.stringify(haxe.Json.parse(value1));
		}
		catch(e:Dynamic) {}
		return false;
	}

	static function makeEventData(name:String, value1:String, value2:String, time:Float):SongEventData
	{
		// the event as it is on the chart, when it's one of the chart's (by V-Slice's name for the ones Psych has under another)
		var kind:String = switch(name)
		{
			case 'Play Animation': 'PlayAnimation';
			case 'Change Scroll Speed': 'ScrollSpeed';
			default: name;
		}
		var original:{value:Dynamic} = chartEventValue(kind, time, value1, value2);
		if(original != null) return new SongEventData(time, kind, original.value);

		// (what `VSliceConvert.convertEvent()` turns into an event of Psych)
		if(name == 'Play Animation')
			return new SongEventData(time, 'PlayAnimation', {target: (value2 != null && value2.length > 0) ? value2 : 'dad', anim: value1, force: true});

		var value:Dynamic = null;
		if(value1 != null && value1.length > 0)
		{
			try
			{
				value = Json.parse(value1);
			}
			catch(e:Dynamic)
			{
				value = value1;
			}
		}
		return new SongEventData(time, name, value);
	}

	/**
	 * Called by PlayState with an event of the chart, before it does anything about it. Returns true if a script cancelled the event.
	 */
	public static function onChartEvent(name:String, value1:String, value2:String, time:Float):Bool
	{
		ownChartEvent = false;
		if(!active || name == null || states.PlayState.SONG == null || states.PlayState.SONG.vslice == null) return false;

		var data:SongEventData = makeEventData(name, value1, value2, time);
		var event:SongEventScriptEvent = new SongEventScriptEvent(data);
		dispatch(event);
		if(event.eventCanceled) return true;

		// (the others are Psych's own to do: the ones it has, and the ones V-Slice's are turned into when the chart is loaded)
		if(data.eventKind == name)
		{
			var handled:Bool = (songEvents.get(data.eventKind) != null || OWN_EVENTS.contains(data.eventKind));
			handleSongEvent(data);
			ownChartEvent = handled;
		}
		return false;
	}

	// (the arguments V-Slice gives to each kind of script class when it makes one, which their constructors can ask for:
	// the class' name to a module, "unknown" to the others. Scripts that ignore them have them left out)

	// The events of V-Slice the engine does by itself, when no script of the mod does (see `handleSongEvent()`)
	static final OWN_EVENTS:Array<String> = ['FocusCamera', 'ZoomCamera', 'SetCameraBop', 'SetTargetBopSpeed', 'SetHealthIcon', 'PlayAnimation'];

	/**
	 * If the event `onChartEvent()` was last called with was done as an event of V-Slice: by a script of the mod, or as one of
	 * the base game's. Psych has events of its own with the same names as some of the mods' ("Change Character") which expect
	 * other things to come with them, and doing its own on top changed the player into a character with no name.
	 */
	public static var ownChartEvent(default, null):Bool = false;

	/**
	 * Does what a song event is supposed to do: runs the script made for it, or one of the events of the base game the engine knows.
	 */
	public static function handleSongEvent(data:SongEventData):Void
	{
		if(!active || data == null) return;

		data.activated = true;

		var scripted:HxcInstance = songEvents.get(data.eventKind);
		if(scripted != null)
		{
			scripted.call('handleEvent', [data]);
			return;
		}

		switch(data.eventKind)
		{
			case 'FocusCamera': focusCamera(data);
			case 'ZoomCamera': zoomCamera(data);
			case 'SetCameraBop':
				var rate:Null<Int> = data.getInt('rate');
				var intensity:Null<Float> = data.getFloat('intensity');
				if(rate != null) facade.cameraZoomRate = rate;
				if(intensity != null) facade.cameraBopIntensity = 1 + 0.015 * intensity;

			case 'SetTargetBopSpeed':
				// how often a character or a sprite of the stage dances, in beats
				var rate:Null<Float> = data.getFloat('rate');
				if(rate == null) rate = 1;

				var target:String = data.getString('target');
				switch((target != null) ? target : 'boyfriend')
				{
					case 'boyfriend', 'bf', 'player': if(game.boyfriend != null) game.boyfriend.danceEvery = rate;
					case 'dad', 'opponent': if(game.dad != null) game.dad.danceEvery = rate;
					case 'girlfriend', 'gf': if(game.gf != null) game.gf.danceEvery = rate;
					default:
						var prop:Dynamic = (facade != null && facade.currentStage != null) ? facade.currentStage.getNamedProp(target) : null;
						if(Std.isOfType(prop, Character)) cast(prop, Character).danceEvery = rate;
						else if(Std.isOfType(prop, FlxSprite)) game.setPropDanceRate(prop, rate);
				}

			case 'SetHealthIcon':
				// (0 is the player's, 1 the opponent's)
				var icon:objects.HealthIcon = (data.getInt('char') == 1) ? game.iconP2 : game.iconP1;
				var id:String = data.getString('id');
				if(icon != null && id != null && id.length > 0)
				{
					icon.changeIcon(id);
					icon.flipX = (data.getBool('flipX') == true);
					if(data.getBool('isPixel') == true) icon.antialiasing = false;

					var scale:Null<Float> = data.getFloat('scale');
					if(scale != null && scale > 0 && scale != 1)
					{
						icon.scale.set(scale, scale);
						icon.updateHitbox();
					}
				}

			case 'PlayAnimation':
				// The ones of the characters are Psych's "Play Animation" since the chart was loaded, these are of the stage's
				// sprites (by their name on the stage's file), same as V-Slice's own `PlayAnimationSongEvent`
				var anim:String = data.getString('anim');
				if(anim == null) anim = 'idle';
				var force:Null<Bool> = data.getBool('force');
				if(force == null) force = false;

				var targetName:String = data.getString('target');
				var target:Dynamic = switch((targetName != null) ? targetName : 'boyfriend')
				{
					case 'boyfriend', 'bf', 'player': game.boyfriend;
					case 'dad', 'opponent': game.dad;
					case 'girlfriend', 'gf': game.gf;
					default: (facade != null && facade.currentStage != null) ? facade.currentStage.getNamedProp(targetName) : null;
				}

				var character:Character = Std.downcast(target, Character);
				if(character != null) character.playAnimation(anim, force, force);
				else if(Std.isOfType(target, psychlua.ModchartSprite)) cast(target, psychlua.ModchartSprite).playAnim(anim, force); //(with its offsets)
				else if(target != null && Reflect.isFunction(Reflect.getProperty(target, 'playAnimation'))) Reflect.callMethod(target, Reflect.getProperty(target, 'playAnimation'), [anim, force]);
				else if(target != null && Std.isOfType(target, FlxSprite) && cast(target, FlxSprite).animation != null) cast(target, FlxSprite).animation.play(anim, force);
		}
	}

	static function getEase(data:SongEventData):Float->Float
	{
		var ease:String = data.getString('ease');
		if(ease == null || ease == 'CLASSIC' || ease == 'INSTANT') return FlxEase.linear;

		var direction:String = data.getString('easeDir');
		return LuaUtils.getTweenEaseByString((ease == 'linear') ? ease : ease + ((direction != null) ? direction : 'In'));
	}

	// Seconds an event takes, they're written in steps
	static function getDuration(data:SongEventData):Float
	{
		if(data.getString('ease') == 'INSTANT') return 0;

		var steps:Null<Float> = data.getFloat('duration');
		return ((steps != null) ? steps : 4) * Conductor.stepCrochet / 1000;
	}

	// Points the camera at a character (0 is the player, 1 the opponent, 2 the girlfriend) or at a position (-1), with an offset.
	// From the first one on the camera only moves with these events, the song's sections stop moving it
	// The chart's "FocusCamera" events that only say who to look at are made into the sections' camera, and Psych's sections don't
	// move it once a script put it somewhere (`isCameraOnForcedPos`). On V-Slice the next of these events always moves it: when one
	// is reached with the camera held like that, it's let go and taken to who the event says
	static var plainFocusTimes:Array<Float> = null;
	static var plainFocusChars:Array<Int> = null;
	static var nextPlainFocus:Int = 0;
	static var plainFocusSong:Dynamic = null;

	static function sectionFocusEvents():Void
	{
		if(game == null || states.PlayState.SONG == null) return;

		var song:Dynamic = states.PlayState.SONG;
		if(plainFocusSong != song)
		{
			plainFocusSong = song;
			plainFocusTimes = [];
			plainFocusChars = [];
			nextPlainFocus = 0;

			var list:Array<Dynamic> = (song.vslice != null) ? song.vslice.eventValues : null;
			if(list == null) return;
			var focuses:Array<Dynamic> = [for (event in list) if(event != null && event.e == 'FocusCamera') event];
			for (event in focuses)
				if(!plainFocus(event)) return; //(then all of them are events of their own, done as they are)

			focuses.sort((a, b) -> Reflect.compare(a.t, b.t));
			for (event in focuses)
			{
				plainFocusTimes.push(event.t);
				plainFocusChars.push(Std.int(Std.isOfType(event.v, Float) ? event.v : event.v.char));
			}
		}

		var position:Float = Conductor.songPosition;
		if(nextPlainFocus > 0 && nextPlainFocus <= plainFocusTimes.length && position < plainFocusTimes[nextPlainFocus - 1])
			nextPlainFocus = 0; //(gone back: a restart, or the song was moved)

		var reached:Int = -1;
		while(nextPlainFocus < plainFocusTimes.length && plainFocusTimes[nextPlainFocus] <= position)
			reached = nextPlainFocus++;
		if(reached < 0 || !game.isCameraOnForcedPos) return;

		if(facade != null) facade.cancelCameraFollowTween();
		game.isCameraOnForcedPos = false;
		switch(plainFocusChars[reached])
		{
			case 1: game.moveCamera(true);
			case 2: if(game.gf != null) game.moveCameraToGirlfriend();
			default: game.moveCamera(false);
		}
	}

	static function plainFocus(event:Dynamic):Bool
	{
		var value:Dynamic = event.v;
		if(Std.isOfType(value, Float)) return value >= 0 && value <= 2;
		if(value == null || !Std.isOfType(value.char, Float) || value.char < 0 || value.char > 2) return false;

		var ease:Dynamic = value.ease;
		var x:Dynamic = value.x;
		var y:Dynamic = value.y;
		return (x == null || x == 0) && (y == null || y == 0) && (ease == null || ease == 'CLASSIC' || ease == '');
	}

	static function focusCamera(data:SongEventData):Void
	{
		var char:Null<Int> = data.getInt('char');
		if(char == null) char = (data.value != null && Std.isOfType(data.value, Float)) ? Std.int(data.value) : 0;

		var offsetX:Null<Float> = data.getFloat('x');
		var offsetY:Null<Float> = data.getFloat('y');
		if(offsetX == null) offsetX = 0;
		if(offsetY == null) offsetY = 0;

		facade.cancelCameraFollowTween();

		// Psych's own functions say where each character's camera goes
		var follow:flixel.FlxObject = game.camFollow;
		var startX:Float = follow.x;
		var startY:Float = follow.y;
		switch(char)
		{
			case 0: game.moveCamera(false);
			case 1: game.moveCamera(true);
			case 2:
				if(game.gf == null) return; //(no girlfriend to look at: V-Slice leaves the camera alone)
				game.moveCameraToGirlfriend();
			default: follow.setPosition(0, 0); //(-1 is a position, and V-Slice takes the ones it doesn't know as one too)
		}
		var targetX:Float = follow.x + offsetX;
		var targetY:Float = follow.y + offsetY;
		game.isCameraOnForcedPos = true;

		var ease:String = data.getString('ease');
		if(ease == 'INSTANT')
		{
			follow.setPosition(targetX, targetY);
			FlxG.camera.snapToTarget();
		}
		else if(ease == null || ease == 'CLASSIC') follow.setPosition(targetX, targetY); //the camera goes there at its usual speed
		else
		{
			follow.setPosition(startX, startY);
			facade.tweenCameraToPosition(targetX, targetY, getDuration(data), getEase(data));
		}
	}

	static function zoomCamera(data:SongEventData):Void
	{
		var zoom:Null<Float> = data.getFloat('zoom');
		var mode:String = data.getString('mode');
		facade.tweenCameraZoom((zoom != null) ? zoom : 1, getDuration(data), mode == null || mode == 'direct', getEase(data));
	}

	// ------------------------------------------------------------------------------------------
	// Menus
	// ------------------------------------------------------------------------------------------

	// The menu whose scripts are running, outside of a song. Only the modules run there
	static var menuState:Dynamic = null;
	static var menuIsState:Bool = false;
	static var scriptedSprites:Array<HxcInstance> = [];

	/**
	 * Loads the modules of V-Slice mods for a menu they change, before the menu makes its things.
	 * They're told the menu is being opened, the way V-Slice tells them about a state or a substate.
	 *
	 * @param everyMod 	If the modules of every V-Slice mod that's turned on run, instead of only the ones of the current mod.
	 * @param asState 	If the menu is a state on V-Slice (the main menu, the credits), instead of a substate (the results screen).
	 */
	public static function startMenu(state:Dynamic, everyMod:Bool = false, asState:Bool = false):Void
	{
		// (a song on its way: see `LoadingState.isBusy()`. The menu is about to be left anyway)
		if(states.LoadingState.isBusy()) return;

		clear();
		menuState = state;
		menuIsState = asState;
		scriptedSprites = [];

		#if MODS_ALLOWED
		var mods:Array<String> = [];
		if(everyMod)
		{
			for (mod in Mods.parseList().enabled)
				if(PolymodCompat.isPolymod(mod))
					mods.push(mod);
		}
		else if(PolymodCompat.isPolymod(Mods.currentModDirectory)) mods.push(Mods.currentModDirectory);
		if(mods.length < 1) return;

		var stateName:String = Type.getClassName(Type.getClass(state));
		setupRuntime();
		HxcRuntime.clear();
		resetLog(MENU_LOG_PATH);
		logHeader = 'Mods: ' + mods.join(', ') + '\n' + 'Menu: $stateName\n' + 'Date: ' + Date.now().toString() + '\n';

		StepLog.add('Loading the scripts of ' + mods.join(', ') + ' for a menu: $stateName');

		var oldMod:String = Mods.currentModDirectory;
		for (mod in mods)
		{
			var known:Array<String> = [for (name in HxcRuntime.classes.keys()) name];

			// (the scripts of all the mods are loaded together for the menus, and mods that were made apart share names of classes
			// all the time: "ChangeCharacterEvent", copied from the same place. That's not a problem of any of them, and on V-Slice
			// the last mod's one is the one that's used just the same)
			Mods.currentModDirectory = mod;
			HxcRuntime.quietReplace = true;
			var loaded:Int = HxcRuntime.loadFolder(Paths.mods('$mod/scripts'));
			HxcRuntime.quietReplace = false;
			if(loaded < 1) continue;

			var credits:Array<Dynamic> = CreditsDataHandler.snapshot();
			for (cls in HxcRuntime.listSubclasses(Module))
			{
				if(known.contains(cls.name)) continue;

				var module:HxcInstance = HxcRuntime.instantiate(cls, [cls.name]);
				if(module == null || module.base == null) continue;

				recallModule(module);
				modules.push(module);
				moduleMods.set(module, mod);
			}
			CreditsDataHandler.collect(mod, credits);
		}
		Mods.currentModDirectory = oldMod;
		modules.sort((a, b) -> cast(a.base, Module).priority - cast(b.base, Module).priority);
		modulesOfMenu = true;

		if(everyMod) applyScriptedPlayers();

		if(asState) dispatchToModules(new StateChangeScriptEvent(ScriptEventType.STATE_CHANGE_BEGIN, state, true));
		else dispatchToModules(new SubStateScriptEvent(ScriptEventType.SUBSTATE_OPEN_BEGIN, state, true));
		#end
	}

	/**
	 * The menu finished making its things.
	 */
	public static function menuOpened(state:Dynamic):Void
	{
		if(menuState != state || modules.length < 1) return;

		dispatchToModules(new ScriptEvent(ScriptEventType.CREATE));
		if(menuIsState) dispatchToModules(new ScriptEvent(ScriptEventType.STATE_CREATE));
		if(menuIsState) dispatchToModules(new StateChangeScriptEvent(ScriptEventType.STATE_CHANGE_END, state));
		else dispatchToModules(new SubStateScriptEvent(ScriptEventType.SUBSTATE_OPEN_END, state));
		StepLog.add('Menu scripts started');
	}

	// The song scripts of the menu's mods, by song and variation, to ask them things about their songs
	static var menuSongScripts:Map<String, HxcInstance> = null;

	/**
	 * If a song's script says it's new, for the "NEW" of Freeplay's capsules (`Song.isSongNew()`: false unless the script says
	 * otherwise, the base game's Spaghetti is new until it's beaten). Only while a menu has the mods' scripts loaded.
	 */
	public static function isSongNew(songId:String, difficulty:String, variation:String):Bool
	{
		if(menuState == null || songId == null) return false;

		if(menuSongScripts == null)
		{
			menuSongScripts = [];

			// (the base game's songs have their scripts in the engine's own V-Slice content, which menus don't load: only its songs')
			#if MODS_ALLOWED
			var baseSongs:String = Paths.mods(PolymodCompat.BASE_MOD + '/scripts/songs');
			if(FileSystem.exists(baseSongs))
			{
				HxcRuntime.quietReplace = true;
				try
				{
					HxcRuntime.loadFolder(baseSongs);
				}
				catch(e:Dynamic) {}
				HxcRuntime.quietReplace = false;
			}
			#end

			for (cls in HxcRuntime.listSubclasses(VSliceSongScript))
			{
				var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
				if(script == null || script.base == null) continue;

				var song:VSliceSongScript = cast script.base;
				var key:String = Paths.formatToSongPath(song.id) + '|' + ((song.variation != null) ? song.variation : 'default');
				if(!menuSongScripts.exists(key)) menuSongScripts.set(key, script);
			}
		}

		var id:String = Paths.formatToSongPath(songId);
		if(variation == null || variation.length < 1) variation = 'default';
		var script:HxcInstance = menuSongScripts.get('$id|$variation');
		if(script == null) script = menuSongScripts.get('$id|default');
		if(script == null || script.findMethod('isSongNew') == null) return false;

		try
		{
			return script.call('isSongNew', [difficulty, variation]) == true;
		}
		catch(e:Dynamic)
		{
			warn('isSongNew of the song "$songId": $e');
			return false;
		}
	}

	public static function menuUpdate(elapsed:Float):Void
	{
		if(states.LoadingState.isBusy()) return; //(see `startMenu()`)
		if(menuState != null && modules.length > 0) dispatchToModules(new UpdateScriptEvent(elapsed));
	}

	/**
	 * The menu is being left.
	 */
	public static function endMenu(state:Dynamic):Void
	{
		if(menuState == null || menuState != state) return;

		// (no "onDestroy": V-Slice's modules last from one state to the next, it's only said when a song is left or the scripts are
		// loaded again. Mods do things for good there, like putting the window back to its size)
		if(modules.length > 0 && !menuIsState)
		{
			dispatchToModules(new SubStateScriptEvent(ScriptEventType.SUBSTATE_CLOSE_BEGIN, state, true));
			dispatchToModules(new SubStateScriptEvent(ScriptEventType.SUBSTATE_CLOSE_END, state));
		}

		// A state of one of the mods' own scripts may be next (a menu of the mod, like SKYREBORN's gallery from the main menu): on
		// V-Slice the modules last from one state to the next, and a mod's menus count on them for what they share. Which state comes
		// is only known right before it's made: the modules wait for it
		if(menuIsState && FlxG.state == state && modules.length > 0)
		{
			handingOver = state;
			FlxG.signals.preStateCreate.addOnce(takeOverMenu);
			return;
		}
		finishMenu();
	}

	static var handingOver:Dynamic = null;

	static function takeOverMenu(next:flixel.FlxState):Void
	{
		var from:Dynamic = handingOver;
		handingOver = null;
		if(from == null || menuState != from) return; //(another menu started in between)

		var nextState:MusicBeatState = Std.downcast(next, MusicBeatState);
		if(nextState != null && HxcRuntime.getInstance(nextState) != null)
		{
			menuState = nextState;
			menuIsState = true;
			nextState.takeMenuScripts();
			StepLog.add('The modules go on in a state of a script: ' + HxcRuntime.getInstance(nextState).cls.name);
			dispatchToModules(new StateChangeScriptEvent(ScriptEventType.STATE_CHANGE_BEGIN, nextState, true));
			return;
		}
		finishMenu();
	}

	static function finishMenu():Void
	{
		menuState = null;
		menuSongScripts = null;
		scriptedSprites = [];
		clear();
		HxcRuntime.clear();
	}

	/**
	 * Sends an event of a menu to its modules and to the scripts of the given things (the Freeplay menu's card and DJ).
	 */
	public static function dispatchToMenu(event:ScriptEvent, ?others:Array<Dynamic>):Void
	{
		if(menuState == null || event == null) return;

		dispatchToModules(event);
		if(others == null) return;

		for (object in others)
		{
			var script:HxcInstance = HxcRuntime.getInstance(object);
			if(script == null) continue;

			inScriptMod(script, function() callEvent(script, event));
		}
	}

	// What scripts get for `animation.onFrameChange`, `animation.onFinish` and `animation.onLoop`, which this version of the library doesn't have:
	// signals made on the spot, dispatched by the two callbacks it does have. They're given the same values as the library's own
	// (name of the animation, and for the frames their number and their position on the image).
	public static function getAnimationSignal(controller:flixel.animation.FlxAnimationController, name:String):Dynamic
	{
		if(name != 'onFrameChange' && name != 'onFinish' && name != 'onLoop') return null;

		// the Freeplay menu's DJ is a texture atlas, its frames don't go through here
		var sprite:FlxSprite = null;
		@:privateAccess sprite = controller._sprite;
		if(Std.isOfType(sprite, objects.freeplay.FreeplayDJ)) return (name == 'onFrameChange') ? cast(sprite, objects.freeplay.FreeplayDJ).frameChanged : null;

		var signals:Map<String, Dynamic> = animationSignals.get(controller);
		if(signals == null)
		{
			signals = [];
			animationSignals.set(controller, signals);
		}
		if(signals.exists(name)) return signals.get(name);

		// characters that are texture atlases don't play anything with this, their atlas is what tells
		#if flxanimate
		var char:Character = Std.downcast(sprite, Character);
		if(char != null && char.isAnimateAtlas && char.atlas != null)
		{
			var frameChange = new flixel.util.FlxSignal.FlxTypedSignal<String->Int->Int->Void>();
			var finish = new flixel.util.FlxSignal.FlxTypedSignal<String->Void>();
			var loop = new flixel.util.FlxSignal.FlxTypedSignal<String->Void>();
			for (atlas in char.getAtlases())
			{
				atlas.anim.onFrame.add(function(frame:Int)
				{
					if(char.atlas == atlas) frameChange.dispatch(char.getAnimationName(), frame, frame);
				});
				atlas.anim.onComplete.add(function()
				{
					if(char.atlas != atlas || atlas.anim == null) return;
					if(atlas.anim.finished) finish.dispatch(char.getAnimationName());
					else loop.dispatch(char.getAnimationName());
				});
			}
			signals.set('onFrameChange', frameChange);
			signals.set('onFinish', finish);
			signals.set('onLoop', loop);
			return signals.get(name);
		}
		#end

		if(name == 'onFrameChange')
		{
			var signal = new flixel.util.FlxSignal.FlxTypedSignal<String->Int->Int->Void>();
			var previous = controller.callback;
			controller.callback = function(animName:String, frameNumber:Int, frameIndex:Int)
			{
				if(previous != null) previous(animName, frameNumber, frameIndex);
				signal.dispatch(animName, frameNumber, frameIndex);
			};
			signals.set(name, signal);
			return signal;
		}

		// a looped animation never "finishes" for the library, so both come from the same place
		var finish = new flixel.util.FlxSignal.FlxTypedSignal<String->Void>();
		var loop = new flixel.util.FlxSignal.FlxTypedSignal<String->Void>();
		var previous = controller.finishCallback;
		controller.finishCallback = function(animName:String)
		{
			if(previous != null) previous(animName);
			finish.dispatch(animName);
		};
		signals.set('onFinish', finish);
		signals.set('onLoop', loop);
		return signals.get(name);
	}

	// ------------------------------------------------------------------------------------------
	// Engine objects with a script
	// ------------------------------------------------------------------------------------------

	// The mod folder a script is from, null if it can't be told
	static function getScriptMod(cls:HxcClass):String
	{
		#if MODS_ALLOWED
		var path:String = cls.module.path.replace('\\', '/');
		if(path.startsWith(PolymodCompat.BASE_FOLDER + '/')) return PolymodCompat.BASE_MOD;

		var root:String = Paths.mods().replace('\\', '/');
		if(!path.startsWith(root)) return null;

		path = path.substr(root.length);
		var end:Int = path.indexOf('/');
		return (end > 0) ? path.substr(0, end) : null;
		#else
		return null;
		#end
	}

	// Runs something with the mod of a script as the current one, so the files it asks for are found
	static function inScriptMod<T>(script:HxcInstance, func:Void->T):T
	{
		#if MODS_ALLOWED
		var owner:String = getScriptMod(script.cls);
		var oldMod:String = Mods.currentModDirectory;
		if(owner != null) Mods.currentModDirectory = owner;

		var result:T = func();
		Mods.currentModDirectory = oldMod;
		return result;
		#else
		return func();
		#end
	}

	/**
	 * What the script's version of the last function done by `callOverride()` returned.
	 */
	public static var overrideResult:Dynamic = null;

	/**
	 * For the engine's classes V-Slice scripts extend (the Freeplay menu's card and DJ): called by a function of the object before doing anything,
	 * returns true if the object has a script with its own version of the function, after running it.
	 * The script's version can still ask for the object's own (`super.thing()`), this returns false on that second time around.
	 */
	public static function callOverride(object:Dynamic, name:String, ?args:Array<Dynamic>):Bool
	{
		var script:HxcInstance = HxcRuntime.getInstance(object);
		if(script == null || !script.hasMethod(name)) return false;
		if(script.inSuperCall(name)) return false; //the script's own is what asked for this (`super.thing()`), wherever it was called from

		var running:Array<String> = overrideGuards.get(object);
		if(running == null)
		{
			running = [];
			overrideGuards.set(object, running);
		}
		if(running.contains(name)) return false;

		running.push(name);
		overrideResult = inScriptMod(script, function() return script.call(name, args));
		running.remove(name);
		return true;
	}

	/**
	 * Makes the Freeplay menu's card a script of the mods has for a player, null if none of them has one.
	 * Like on V-Slice, each script says who it's for when it's made (`super('bf')`).
	 */
	public static function makeBackingCard(playerId:String):objects.freeplay.FreeplayBackingCard
	{
		for (cls in HxcRuntime.listSubclasses(objects.freeplay.FreeplayBackingCard))
		{
			#if MODS_ALLOWED
			var oldMod:String = Mods.currentModDirectory;
			var owner:String = getScriptMod(cls);
			if(owner != null) Mods.currentModDirectory = owner;
			#end

			var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);

			#if MODS_ALLOWED
			Mods.currentModDirectory = oldMod;
			#end

			var card:objects.freeplay.FreeplayBackingCard = (script != null) ? Std.downcast(script.base, objects.freeplay.FreeplayBackingCard) : null;
			if(card == null) continue;
			if(card.currentCharacter == playerId) return card;

			card.destroy();
		}
		return null;
	}

	/**
	 * Makes the Freeplay menu's DJ out of the script class a player's file asks for ("scriptClass"), null if there's no such class.
	 */
	public static function makeFreeplayDJ(className:String, playerId:String):objects.freeplay.FreeplayDJ
	{
		var cls:HxcClass = (className != null) ? HxcRuntime.classes.get(className) : null;
		if(cls == null || !cls.isSubclassOf(objects.freeplay.FreeplayDJ)) return null;

		#if MODS_ALLOWED
		var oldMod:String = Mods.currentModDirectory;
		var owner:String = getScriptMod(cls);
		if(owner != null) Mods.currentModDirectory = owner;
		#end

		var script:HxcInstance = HxcRuntime.instantiate(cls, [0, 0, playerId]);

		#if MODS_ALLOWED
		Mods.currentModDirectory = oldMod;
		#end
		return (script != null) ? Std.downcast(script.base, objects.freeplay.FreeplayDJ) : null;
	}

	// The players the loaded scripts have a class for
	static function listScriptedPlayers():Map<String, HxcInstance>
	{
		if(scriptedPlayers != null) return scriptedPlayers;

		scriptedPlayers = [];
		for (cls in HxcRuntime.listSubclasses(funkin.ui.freeplay.charselect.PlayableCharacter))
		{
			var script:HxcInstance = HxcRuntime.instantiate(cls, ['unknown']);
			var player:funkin.ui.freeplay.charselect.PlayableCharacter = (script != null) ? Std.downcast(script.base, funkin.ui.freeplay.charselect.PlayableCharacter) : null;
			if(player != null && player.id != null) scriptedPlayers.set(player.id, script);
		}
		return scriptedPlayers;
	}

	/**
	 * The player a script of the mods made for an id, null if there's none.
	 */
	public static function getScriptedPlayer(id:String):funkin.ui.freeplay.charselect.PlayableCharacter
	{
		var script:HxcInstance = listScriptedPlayers().get(id);
		return (script != null) ? cast script.base : null;
	}

	// What player scripts say about their players is put on the engine's own, which is what the menus look at.
	// Done every time the scripts of every mod are loaded for a menu, the save could have changed since the last time
	static function applyScriptedPlayers():Void
	{
		for (id => script in listScriptedPlayers())
		{
			var player = PlayableCharacters.get(id);
			if(player == null) continue;

			var unlocked:Dynamic = inScriptMod(script, function() return script.call('isUnlocked'));
			if(Std.isOfType(unlocked, Bool)) player.unlocked = unlocked;
		}
	}

	/**
	 * Makes a texture atlas out of a script class of the mod (one that extends `FunkinSprite` and loads an atlas), null if there's no such class.
	 * The mod's scripts have to be loaded: it's for menus, between `startMenu()` and `endMenu()`.
	 */
	public static function makeAtlasSprite(className:String, x:Float, y:Float):objects.AtlasSprite
	{
		var cls:HxcClass = HxcRuntime.classes.get(className);
		if(cls == null) return null;

		var proxy:funkin.graphics.AtlasSpriteProxy = new funkin.graphics.AtlasSpriteProxy(x, y);
		var script:HxcInstance = HxcRuntime.instantiate(cls, [x, y], proxy);
		if(script == null) return null;

		scriptedSprites.push(script);
		return proxy.sprite;
	}

	// ------------------------------------------------------------------------------------------
	// For the classes scripts use to reach each other
	// ------------------------------------------------------------------------------------------

	public static function getModule(id:String):Module
	{
		for (module in modules)
			if(cast(module.base, Module).moduleId == id)
				return cast module.base;
		return null;
	}

	public static function getNoteKind(kind:String):NoteKind
	{
		var found:HxcInstance = noteKinds.get(kind);
		return (found != null) ? cast found.base : null;
	}

	public static function getSongEvent(id:String):SongEvent
	{
		var found:HxcInstance = songEvents.get(id);
		return (found != null) ? cast found.base : null;
	}

	public static function listSongEvents():Array<String>
	{
		return [for (id in songEvents.keys()) id].concat(['FocusCamera', 'ZoomCamera', 'SetCameraBop', 'SetHealthIcon', 'SetTargetBopSpeed']);
	}
}
#end
