package backend;

import haxe.CallStack;
import haxe.CallStack.StackItem;
import openfl.Lib;
import openfl.events.UncaughtErrorEvent;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * What a crash was: the error, where in the code, and what the game was doing (the screen, the mod, the song...).
 */
typedef CrashInfo =
{
	var error:String;
	var stack:Array<String>;
	var context:Array<Array<String>>; //[label, value]
	var steps:Array<String>;
	var path:String; //where the report was saved, null if it couldn't be
	var fromSong:Bool;
	var storyMode:Bool;
}

/**
 * An error nothing caught no longer closes the game: it's written to a report in "crash/", with what the game was doing, and the crash
 * screen (states.CrashState) shows it with a way back to the menus. The game only closes when it can't go on: a crash on the crash
 * screen itself, or crashes one right after another.
 *
 * Based on the crash handler sqirra-rng made for Izzy Engine.
 */
class CrashHandler
{
	static var recovering:Bool = false; //(the crash screen was asked for and isn't open yet)
	static var recoveryCrashes:Int = 0;
	static var lastCrash:Float = -100;

	public static function init():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
	}

	/**
	 * The crash screen opened: crashes from now on are new ones.
	 */
	public static function recovered():Void
	{
		recovering = false;
		recoveryCrashes = 0;
	}

	static function onCrash(e:UncaughtErrorEvent):Void
	{
		var stack:Array<String> = stackLines(CallStack.exceptionStack(true));

		// the screen that crashed couldn't be closed: it's left behind (not destroyed) and the crash screen opens anyway
		if(recovering && !Std.isOfType(FlxG.state, states.CrashState))
		{
			recoveryCrashes++;
			if(recoveryCrashes <= 5)
			{
				Sys.println('Error while leaving the screen that crashed, it was skipped: ' + e.error);
				@:privateAccess FlxG.game._state = new flixel.FlxState();
				e.preventDefault();
				return;
			}
		}

		var info:CrashInfo = describe(e.error, stack);
		info.path = save(report(info));
		Sys.println(report(info));

		var now:Float = haxe.Timer.stamp();
		var onCrashScreen:Bool = Std.isOfType(FlxG.state, states.CrashState);
		if(onCrashScreen || recovering || now - lastCrash < 2)
		{
			closeGame(info);
			return;
		}

		lastCrash = now;
		recovering = true;
		e.preventDefault();
		cleanUp(info);

		flixel.addons.transition.FlxTransitionableState.skipNextTransIn = true;
		flixel.addons.transition.FlxTransitionableState.skipNextTransOut = true;
		FlxG.switchState(new states.CrashState(info));
	}

	static function stackLines(items:Array<StackItem>):Array<String>
	{
		var lines:Array<String> = [];
		for (item in items)
		{
			switch(item)
			{
				case FilePos(_, file, line, _): lines.push('$file (line $line)');
				default:
			}
		}
		return lines;
	}

	// What the game was doing. Each part on its own: one failing doesn't keep the others out
	static function describe(error:Dynamic, stack:Array<String>):CrashInfo
	{
		var context:Array<Array<String>> = [];
		inline function add(label:String, value:Dynamic):Void
			if(value != null && Std.string(value).length > 0) context.push([label, Std.string(value)]);

		var fromSong:Bool = false;
		var storyMode:Bool = false;

		try
		{
			var screens:Array<String> = [];
			var state:flixel.FlxState = FlxG.state;
			while(state != null)
			{
				screens.push(Type.getClassName(Type.getClass(state)));
				state = state.subState;
			}
			add('Screen', screens.join(' > '));
		}
		catch(e:Dynamic) {}

		#if MODS_ALLOWED
		try add('Mod', modName(Mods.currentModDirectory)) catch(e:Dynamic) {}
		#end

		try
		{
			var game:states.PlayState = states.PlayState.instance;
			fromSong = game != null && FlxG.state == game;
			if(fromSong && states.PlayState.SONG != null)
			{
				storyMode = states.PlayState.isStoryMode;
				add('Song', states.PlayState.SONG.song);
				add('Difficulty', Difficulty.getString());
				add('Time', flixel.util.FlxStringUtil.formatTime(Math.max(0, Conductor.songPosition) / 1000, true));
				add('Mode', storyMode ? 'Story Mode' : 'Freeplay');
				add('Stage', states.PlayState.curStage);
				add('Characters', states.PlayState.SONG.player1 + ', ' + states.PlayState.SONG.player2 + ', ' + states.PlayState.SONG.gfVersion);
				#if HSCRIPT_ALLOWED
				if(VSliceScripts.active && !VSliceScripts.modulesOnly) add('Chart', 'V-Slice');
				#end
			}
		}
		catch(e:Dynamic) {}

		try add('Version', 'Vortex Engine ' + states.MainMenuState.vortexEngineVersion + ' (' + Sys.systemName() + ')') catch(e:Dynamic) {}
		add('Date', Date.now().toString());

		return {
			error: Std.string(error),
			stack: stack,
			context: context,
			steps: StepLog.recent.copy(),
			path: null,
			fromSong: fromSong,
			storyMode: storyMode
		};
	}

	#if MODS_ALLOWED
	static function modName(folder:String):String
	{
		if(folder == null || folder.length < 1) return null;
		var name:String = folder;
		try
		{
			var pack:Dynamic = Mods.getPack(folder);
			if(pack != null && pack.name != null && Std.string(pack.name).length > 0 && Std.string(pack.name) != folder)
				name = Std.string(pack.name) + ' (' + folder + ')';
		}
		catch(e:Dynamic) {}
		return name;
	}
	#end

	static function report(info:CrashInfo):String
	{
		var text:String = 'Vortex Engine crash report\n\n';
		text += 'Error: ' + info.error + '\n\n';
		for (entry in info.context) text += entry[0] + ': ' + entry[1] + '\n';
		text += '\nCode:\n' + info.stack.join('\n') + '\n';
		if(info.steps.length > 0) text += '\nLast steps:\n' + info.steps.join('\n') + '\n';
		text += '\nCrash handler based on the one by sqirra-rng.\n';
		return text;
	}

	static function save(text:String):String
	{
		#if sys
		try
		{
			if(!FileSystem.exists('crash')) FileSystem.createDirectory('crash');
			var date:String = Date.now().toString().replace(' ', '_').replace(':', "'");
			var path:String = 'crash/VortexEngine_$date.txt';
			File.saveContent(path, text);
			return path;
		}
		catch(e:Dynamic) {}
		#end
		return null;
	}

	// What a song or a script left behind that the menus shouldn't keep
	static function cleanUp(info:CrashInfo):Void
	{
		try FlxG.timeScale = 1 catch(e:Dynamic) {}
		try
		{
			if(FlxG.sound.music != null) FlxG.sound.music.stop();
			for (sound in FlxG.sound.list.members) if(sound != null && sound.playing) sound.stop();
		}
		catch(e:Dynamic) {}
		try FlxG.mouse.unload() catch(e:Dynamic) {}
		try TouchControls.restoreDownScroll() catch(e:Dynamic) {}
		#if HSCRIPT_ALLOWED
		if(info.fromSong) try VSliceScripts.destroy() catch(e:Dynamic) {}
		#end
		#if DISCORD_ALLOWED
		try DiscordClient.resetClientID() catch(e:Dynamic) {}
		#end
	}

	// The old way: the error in a window, and the game closes
	static function closeGame(info:CrashInfo):Void
	{
		var text:String = info.error + '\n\n' + info.stack.slice(0, 8).join('\n');
		if(info.path != null) text += '\n\nReport: ' + haxe.io.Path.normalize(info.path);
		try lime.app.Application.current.window.alert(text, 'Error!') catch(e:Dynamic) {}
		#if DISCORD_ALLOWED
		try DiscordClient.shutdown() catch(e:Dynamic) {}
		#end
		AppExit.exit(1, false);
	}
}
