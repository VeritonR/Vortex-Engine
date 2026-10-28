package backend;

#if sys
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.events.Event;
import options.OptionsState;
import sys.FileSystem;
import sys.io.File;

/**
 * Opens the game right on a song, to test one without going through the menus. It only does anything when the game is started with a song:
 *
 *   VortexEngine.exe --song=stress --mod=base --difficulty=hard --player=pico --botplay --shots=5,20 --quit=25
 *
 * --song=NAME          The song, by the name of its folder.
 * --difficulty=NAME    One of its difficulties ("hard", "erect"...), the default one if left out.
 * --mod=FOLDER         Folder of the mod it's from, or "base" for the V-Slice content that comes with the game. The first one that has it if left out.
 * --player=ID          Player of Character Select to play as ("pico"), which is what picks a song's Pico Mix.
 * --botplay            The notes are hit by themselves.
 * --practice           Practice mode: the player can't die, to get to the end of a song without the notes being hit for it.
 * --opponent           Plays the opponent's side ("Play as Opponent"). Without it that modifier is off for the run, whatever is saved.
 * --rate=2             How fast the song is played, like the option of the gameplay changers.
 * --time=SECONDS       Starts the song from that point.
 * --charting           Plays it the way the chart editor does to test a chart, which is how V-Slice scripts know to skip their cutscenes.
 * --story              Plays it as if it had been picked on Story Mode (a week of this one song), which is where some cutscenes are shown.
 * --volume=0.2         From 0 to 1.
 * --shots=5,12.5       Seconds after the song is opened at which a picture of the game is saved, as "directplay_(number).png"...
 * --shotdir=FOLDER     ...in this folder, the game's own if left out.
 * --quit=SECONDS       Closes the game that long after the song is opened.
 * --pref=NAME=VALUE    One of the game's options as this run should have it ("--pref=songCredits=false", more separated by commas).
 * --menu=options       Opens the options menu instead of a song (--select=NUMBER picks which of its entries is selected, from 0).
 * --menu=main          Opens another menu instead: "main", "story", "credits", "charselect", "charselecteditor" (and "freeplay", "boot", "options").
 * --menufirst=SECONDS  Opens the Freeplay menu first and the song from there after that long, like someone picking it: the mods' menu
 *                      scripts get to run, and the song is loaded over a menu instead of over the title screen.
 * --skipdialogue       Goes through a V-Slice dialogue by itself: skips it a second and a half after it shows up.
 * --menu=boot          Opens the game the usual way (the warnings, the title screen...), with the pictures and --quit counted from then.
 * --keys=3:13,6.5:40   Keys pressed by themselves: seconds, a colon and the key's code (13 is ENTER, 27 ESCAPE, 37 to 40 the arrows);
 *                      another colon and seconds holds it down for that long (5:16:2 is SHIFT held from 5 to 7 seconds).
 * --editorsave=DIR    What the editors save is written to that folder, without asking where.
 * --mouse=4:move:640:300,4.2:down,4.3:move:700:500:0.5,5:up
 *                      The mouse, used by itself: seconds, a colon and what it does. "move:X:Y" (on the game's 1280x720, and a
 *                      number of seconds to get there little by little), "down"/"up" (left button), "rdown"/"rup" (right),
 *                      "mdown"/"mup" (middle), "wheel:N" (up is positive). With "--song", "--menu=charteditor" opens the chart
 *                      editor with that song instead of playing it.
 * --savefolder=NAME    A save folder of its own for this run (options, scores, key binds): a new name is the game as someone who never opened it has it.
 * --log=FILE           Writes down what every character is doing on each frame of the song: the song's time, and for each one its
 *                      animation, the frame it's on, if it's over, if it can't be interrupted and if the character is visible.
 * --watch=NAME,NAME    Added to each line of the log: sprites of the stage by their name (alpha, color, blend mode and if they're hidden),
 *                      and variables of the V-Slice stage script, written as "stage.variable".
 *
 * Nothing it changes (player, botplay, volume) is saved by it.
 */
class DirectPlay
{
	static var options:Map<String, String> = null;
	static var started:Bool = false;

	static var songOpenedAt:Float = -1;
	static var shotTimes:Array<Float> = [];
	static var shotsTaken:Int = 0;
	static var quitAfter:Float = -1;

	static function read():Void
	{
		if(options != null) return;

		options = [];
		for (arg in Sys.args())
		{
			if(!arg.startsWith('--')) continue;

			var equals:Int = arg.indexOf('=');
			if(equals < 0) options.set(arg.substr(2).toLowerCase(), '');
			else options.set(arg.substring(2, equals).toLowerCase(), arg.substr(equals + 1));
		}
	}

	/**
	 * If the game was started for a test (with any of these options), not by someone playing it.
	 */
	public static var testRun(get, never):Bool;
	static function get_testRun():Bool
	{
		read();
		return options.keys().hasNext();
	}

	/**
	 * With "--editorsave=FOLDER", what an editor saves goes straight to that folder instead of asking where (to test what the editors save).
	 * True if it was written there.
	 */
	public static function editorSave(fileName:String, text:String):Bool
	{
		#if sys
		read();
		if(!options.exists('editorsave')) return false;
		var folder:String = options.get('editorsave');
		if(!sys.FileSystem.exists(folder)) sys.FileSystem.createDirectory(folder);
		sys.io.File.saveContent(haxe.io.Path.join([folder, fileName]), text);
		trace('Editor saved "$fileName" to $folder');
		return true;
		#else
		return false;
		#end
	}

	static function number(name:String, fallback:Float):Float
	{
		var value:Float = options.exists(name) ? Std.parseFloat(options.get(name)) : Math.NaN;
		return Math.isNaN(value) ? fallback : value;
	}

	/**
	 * Called by the title screen once the game is set up, the first time it opens.
	 * Returns true if the game was started with a song, which is then being opened in the title screen's place.
	 */
	public static function start():Bool
	{
		read();

		var songName:String = options.get('song');

		// (the title screen reads the options again each time it's made before the game is all set up, the Auto Pause one included:
		// a run that nobody is looking at would stop right there, waiting for its window to be clicked on)
		if(started) FlxG.autoPause = false;

		if(!started && options.get('menu') == 'boot')
		{
			started = true;
			applyPrefs();
			watch();
			songOpenedAt = haxe.Timer.stamp();
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);
			return false;
		}
		// (an online match against another copy of the game: "--online=host" or "--online=join:127.0.0.1", the host plays "--onlinesong")
		if(!started && options.exists('online'))
		{
			started = true;
			applyPrefs();
			watch();
			songOpenedAt = haxe.Timer.stamp();
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);
			if(FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

			NetworkManager.testLog = true;
			NetworkManager.testBotplay = options.exists('botplay');
			NetworkManager.testDelay = number('onlinedelay', 0);
			NetworkManager.testJitter = number('onlinejitter', 0);
			var mode:String = options.get('online');
			if(mode == 'host') NetworkManager.hostServer();
			else if(mode.startsWith('join:')) NetworkManager.joinServer(mode.substr(5));
			states.MultiplayerMenuState.testSong = options.get('onlinesong');
			if(options.exists('onlinewin')) states.MultiplayerMenuState.testWinCondition = options.get('onlinewin');
			if(options.exists('time')) PlayState.startOnTime = Math.max(0, number('time', 0)) * 1000; //(both sides start the match there)
			states.MultiplayerMenuState.testDifficulty = options.get('difficulty');
			if(options.exists('onlinerole')) states.MultiplayerMenuState.testRole = options.get('onlinerole');
			states.MultiplayerMenuState.testRounds = Std.int(number('onlinerounds', 1));
			MusicBeatState.switchState(new states.MultiplayerMenuState());
			return true;
		}
		if(!started && options.get('menu') == 'freeplay')
		{
			started = true;
			applyPrefs();
			watch();
			songOpenedAt = haxe.Timer.stamp(); //(`--keys` count from now)
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);
			if(FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			if(options.exists('player')) PlayableCharacters.select(options.get('player'));
			FlxG.signals.postStateSwitch.add(function() FlxG.autoPause = false); //(the menus set it back to the option when they're made)

			if(ClientPrefs.data.freeplayStyle == 'V-Slice') MusicBeatState.switchState(new states.FreeplayStateVslice());
			else MusicBeatState.switchState(new states.FreeplayState());
			return true;
		}
		// (one of the other menus, to see what the mods' scripts do on it: "main", "story", "credits", "charselect")
		var otherMenu:Void->flixel.FlxState = switch(options.get('menu'))
		{
			case 'main': () -> new states.MainMenuState();
			case 'story': () -> new states.StoryMenuState();
			case 'credits': () -> new states.CreditsState();
			case 'charselect': () -> new states.CharacterSelectState();
			case 'charselecteditor': () -> new states.editors.CharSelectEditorState();
			case 'editors': () -> new states.editors.MasterEditorMenu();
			case 'gallery': () -> new states.GalleryState();
			case 'mods': () -> new states.ModsMenuState(options.get('mod')); //("--mod" picks the one selected)
			#if ACHIEVEMENTS_ALLOWED
			case 'achievements': () -> new states.AchievementsMenuState();
			#end
			case 'multiplayer': () -> new states.MultiplayerMenuState();
			case 'stageeditor': () -> new states.editors.StageEditorState();
			case 'chareditor': () -> new states.editors.CharacterEditorState(objects.Character.DEFAULT_CHARACTER, false);
			case 'portraiteditor': () -> new states.editors.DialogueCharacterEditorState();
			case 'menucharactereditor': () -> new states.editors.MenuCharacterEditorState();
			case 'weekeditor': () -> new states.editors.WeekEditorState();
			case 'dialogueeditor': () -> new states.editors.DialogueEditorState();
			case 'splasheditor': () -> new states.editors.NoteSplashEditorState();
			default: null;
		}
		if(!started && otherMenu != null)
		{
			started = true;
			applyPrefs();
			watch();
			songOpenedAt = haxe.Timer.stamp(); //(`--keys` count from now)
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);
			if(FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			if(options.exists('player')) PlayableCharacters.select(options.get('player'));
			FlxG.signals.postStateSwitch.add(function() FlxG.autoPause = false);
			MusicBeatState.switchState(otherMenu());
			return true;
		}
		if(!started && options.get('menu') == 'options')
		{
			started = true;
			applyPrefs();
			watch();
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);
			if(FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

			@:privateAccess OptionsState.curSelected = Std.int(Math.max(0, number('select', 0)));
			MusicBeatState.switchState(new OptionsState());
			return true;
		}
		#if HSCRIPT_ALLOWED
		// (a list of imports, one per line, and where to write the ones scripts can't have)
		if(!started && options.exists('checkimports'))
		{
			started = true;
			var files:Array<String> = options.get('checkimports').split(',');
			try
			{
				var missing:Array<String> = VSliceScripts.unresolvedImports(File.getContent(files[0]).replace('
', '').split('
'));
				File.saveContent(files[1], missing.join('
'));
				trace('Imports checked: ' + missing.length + ' missing');
			}
			catch(e:Dynamic) trace('Could not check the imports: $e');
			Sys.exit(0);
			return true;
		}
		#end
		// (folders to read every PNG of, with lime and with `PngDecoder`, and where to write how they compare)
		if(!started && options.exists('checkpng'))
		{
			started = true;
			var parts:Array<String> = options.get('checkpng').split(',');
			comparePngs(parts.slice(0, parts.length - 1), parts[parts.length - 1]);
			return true;
		}
		if(started || songName == null || songName.length < 1) return false;
		started = true;

		if(options.exists('menufirst') && !menuShown)
		{
			menuShown = true;
			menuOpenedAt = haxe.Timer.stamp();
			FlxG.autoPause = false;
			FlxG.signals.postStateSwitch.add(function() FlxG.autoPause = false); //(the menus set it back to the option when they're left)
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);
			if(FlxG.sound.music == null) FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

			if(ClientPrefs.data.freeplayStyle == 'V-Slice') MusicBeatState.switchState(new states.FreeplayStateVslice());
			else MusicBeatState.switchState(new states.FreeplayState());
			FlxG.stage.addEventListener(Event.ENTER_FRAME, onMenuFrame);
			return true;
		}

		try
		{
			applyPrefs();
			if(options.exists('player')) PlayableCharacters.select(options.get('player'));
			if(options.exists('botplay')) ClientPrefs.data.gameplaySettings.set('botplay', true);
			ClientPrefs.data.gameplaySettings.set('practice', options.exists('practice'));
			ClientPrefs.data.gameplaySettings.set('playasopponent', options.exists('opponent'));
			if(options.exists('rate')) ClientPrefs.data.gameplaySettings.set('songspeed', FlxMath.bound(number('rate', 1), 0.5, 4));
			if(options.exists('volume')) FlxG.sound.volume = FlxMath.bound(number('volume', 1), 0, 1);

			var wantedMod:String = options.get('mod');
			#if MODS_ALLOWED
			if(wantedMod == 'base') wantedMod = PolymodCompat.BASE_MOD;
			#end

			// the week that has it, like Freeplay finds its songs
			var key:String = Paths.formatToSongPath(songName);
			var week:WeekData = null;
			var weekIndex:Int = -1;
			WeekData.reloadWeekFiles(false);
			for (index => weekName in WeekData.weeksList)
			{
				var candidate:WeekData = WeekData.weeksLoaded.get(weekName);
				if(candidate == null || (wantedMod != null && candidate.folder != wantedMod)) continue;

				for (entry in candidate.songs)
				{
					if(Paths.formatToSongPath(Std.string(entry[0])) == key)
					{
						week = candidate;
						weekIndex = index;
						break;
					}
				}
				if(week != null) break;
			}
			if(week == null) throw 'no week has the song "$songName"' + ((wantedMod != null) ? ' on "$wantedMod"' : '');

			WeekData.setDirectoryFromWeek(week);
			PlayState.storyWeek = weekIndex;
			Difficulty.loadFromWeek();

			var wantedDifficulty:String = Paths.formatToSongPath(options.exists('difficulty') ? options.get('difficulty') : Difficulty.getDefault());
			var difficulty:Int = -1;
			for (index => name in Difficulty.list)
				if(Paths.formatToSongPath(name) == wantedDifficulty)
					difficulty = index;
			if(difficulty < 0 && !options.exists('difficulty') && Difficulty.list.length > 0) difficulty = 0; //(a song without the default one)
			if(difficulty < 0) throw 'the song has no difficulty "$wantedDifficulty", only: ' + Difficulty.list.join(', ');

			Song.loadFromJson(Highscore.formatSong(key, difficulty), key);
			if(PlayState.SONG == null) throw 'the chart could not be loaded';

			PlayState.isStoryMode = options.exists('story');
			PlayState.storyDifficulty = difficulty;
			if(PlayState.isStoryMode)
			{
				PlayState.storyPlaylist = [key];
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
			}
			if(options.exists('time')) PlayState.startOnTime = Math.max(0, number('time', 0)) * 1000;
			if(options.exists('charting')) PlayState.chartingMode = true;

			watch();

			// the menus leave their music behind (stopped) when a song is opened, and parts of the game count on there being one
			if(FlxG.sound.music == null)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxG.sound.music.stop();
			}

			// (what the Freeplay menus do before loading a song of another mod)
			@:privateAccess
			if(menuShown && PlayState._lastLoadedModDirectory != Mods.currentModDirectory) Paths.freeGraphicsFromMemory();

			if(options.get('menu') == 'charteditor')
			{
				trace('Opening "$songName" on the chart editor');
				LoadingState.loadAndSwitchState(new states.editors.ChartingState(), false);
				return true;
			}

			trace('Opening "$songName" (${Difficulty.list[difficulty]}) right away');
			backend.StepLog.add('Opening the song "$songName" (${Difficulty.list[difficulty]}) right away, as asked on the command line');
			LoadingState.prepareToSong();
			backend.StepLog.add('Direct song: its files are being looked for');
			var song:PlayState = new PlayState();
			backend.StepLog.add('Direct song: the song was made, asking for the loading screen');
			LoadingState.loadAndSwitchState(song);
			backend.StepLog.add('Direct song: waiting for the title screen to be left');
			return true;
		}
		catch(e:Dynamic)
		{
			trace('Could not open the song the game was started with: $e');
		}
		return false;
	}

	// Every PNG under some folders, read by lime and by `PngDecoder`: how many came out different, and how long each took.
	// A few files a frame: the window has to keep answering, or Windows closes the game
	static function comparePngs(folders:Array<String>, output:String):Void
	{
		var files:Array<String> = [];
		function walk(folder:String)
		{
			if(!sys.FileSystem.exists(folder)) return;
			for (name in sys.FileSystem.readDirectory(folder))
			{
				var path:String = folder + '/' + name;
				if(sys.FileSystem.isDirectory(path)) walk(path);
				else if(name.toLowerCase().endsWith('.png')) files.push(path);
			}
		}
		for (folder in folders) walk(folder);

		var lines:Array<String> = [];
		var same:Int = 0;
		var different:Int = 0;
		var leftToLime:Int = 0;
		var limeFailed:Int = 0;
		var limeTime:Float = 0;
		var ownTime:Float = 0;

		function compareOne(path:String)
		{
			var bytes:haxe.io.Bytes = sys.io.File.getBytes(path);

			var start:Float = Sys.time();
			var png:PngDecoder.PngPixels = PngDecoder.decode(bytes);
			ownTime += Sys.time() - start;

			start = Sys.time();
			var bitmap:openfl.display.BitmapData = null;
			try bitmap = openfl.display.BitmapData.fromBytes(openfl.utils.ByteArray.fromBytes(bytes)) catch(e:Dynamic) {}
			limeTime += Sys.time() - start;

			if(bitmap == null || bitmap.image == null)
			{
				limeFailed++;
				lines.push('lime could not read: $path' + (png != null ? ' (PngDecoder could)' : ''));
				return;
			}
			if(png == null)
			{
				leftToLime++;
				lines.push('left to lime: $path');
				bitmap.dispose();
				return;
			}

			var theirs:haxe.io.Bytes = bitmap.image.data.toBytes();
			var count:Int = 0;
			var first:String = null;
			var biggest:Int = 0;
			if(png.width != bitmap.width || png.height != bitmap.height || theirs.length != png.pixels.length)
				first = 'size ${png.width}x${png.height} instead of ${bitmap.width}x${bitmap.height}';
			else
			{
				for (i in 0...theirs.length)
				{
					var difference:Int = theirs.get(i) - png.pixels.get(i);
					if(difference < 0) difference = -difference;
					if(difference == 0) continue;
					count++;
					if(difference > biggest) biggest = difference;
					if(first == null) first = 'byte $i: lime ${theirs.get(i)}, PngDecoder ${png.pixels.get(i)}';
				}
			}
			bitmap.dispose();

			if(first == null) same++;
			else
			{
				different++;
				lines.push('DIFFERENT ($count bytes, by up to $biggest; $first): $path');
			}
		}

		var next:Int = 0;
		function onFrame(_)
		{
			var start:Float = Sys.time();
			while(next < files.length && Sys.time() - start < 0.1)
			{
				var path:String = files[next++];
				try compareOne(path) catch(e:Dynamic) lines.push('ERROR ($e): $path');
			}
			// written every frame: what was compared isn't lost if the game is closed before the end
			var round = (time:Float) -> FlxMath.roundDecimal(time, 2);
			var summary:String = '$next of ${files.length} images: $same the same, $different different, $leftToLime left to lime, $limeFailed lime could not read.'
				+ ' lime took ${round(limeTime)}s, PngDecoder ${round(ownTime)}s (inflating ${round(PngDecoder.inflateTime)}s, filters ${round(PngDecoder.unfilterTime)}s,'
				+ ' pixels ${round(PngDecoder.pixelsTime)}s)';
			File.saveContent(output, [summary].concat(lines).join('\n'));
			if(next >= files.length) Sys.exit(0);
		}
		FlxG.stage.addEventListener(Event.ENTER_FRAME, onFrame);
	}

	static var menuShown:Bool = false;
	static var menuOpenedAt:Float = 0;

	static function onMenuFrame(_):Void
	{
		if(haxe.Timer.stamp() - menuOpenedAt < number('menufirst', 3)) return;

		FlxG.stage.removeEventListener(Event.ENTER_FRAME, onMenuFrame);
		started = false;
		if(!start()) return;

		// The standard Freeplay goes back to the song it's stopped on whenever something that was over it closes, the fade to the
		// loading screen included: it has to be on the song that was asked for, like it is when someone picks it there
		var menu:states.FreeplayState = Std.downcast(FlxG.state, states.FreeplayState);
		if(menu == null) return;

		var key:String = Paths.formatToSongPath(options.get('song'));
		for (index => song in menu.songs)
		{
			if(Paths.formatToSongPath(song.songName) != key || song.folder != Mods.currentModDirectory) continue;

			states.FreeplayState.curSelected = index;
			break;
		}
	}

	// The pictures and the closing of the game, counted from when what was asked for is on the screen
	static function watch():Void
	{
		if(options.exists('shots'))
		{
			shotTimes = [for (text in options.get('shots').split(',')) Std.parseFloat(text)].filter((time) -> !Math.isNaN(time));
			shotTimes.sort(Reflect.compare);
		}
		quitAfter = number('quit', -1);
		if(options.exists('keys'))
		{
			for (pair in options.get('keys').split(','))
			{
				var parts:Array<String> = pair.split(':');
				var hold:Float = (parts.length > 2) ? Std.parseFloat(parts[2]) : 0;
				if(parts.length >= 2 && !Math.isNaN(Std.parseFloat(parts[0])) && Std.parseInt(parts[1]) != null)
					keyPresses.push({time: Std.parseFloat(parts[0]), code: Std.parseInt(parts[1]), down: false, done: false, held: 0, hold: Math.isNaN(hold) ? 0 : hold});
			}
		}
		if(options.exists('mouse'))
		{
			for (entry in options.get('mouse').split(','))
			{
				var parts:Array<String> = entry.split(':');
				var time:Float = Std.parseFloat(parts[0]);
				if(parts.length < 2 || Math.isNaN(time)) continue;
				mouseActions.push({time: time, action: parts[1], values: [for (i in 2...parts.length) Std.parseFloat(parts[i])]});
			}
			mouseActions.sort((a, b) -> Reflect.compare(a.time, b.time));
		}
		if(shotTimes.length > 0 || quitAfter >= 0 || keyPresses.length > 0 || mouseActions.length > 0 || options.exists('freezeatlas') || options.exists('members') || options.exists('fullscreenat')) FlxG.stage.addEventListener(Event.ENTER_FRAME, onFrame);

		// what the current state is doing, once a second (a menu that stopped updating, a substate over it...)
		if(options.exists('stateinfo'))
		{
			var lastInfo:Float = 0;
			FlxG.stage.addEventListener(Event.ENTER_FRAME, function(_)
			{
				var now:Float = haxe.Timer.stamp();
				if(now - lastInfo < 1) return;
				lastInfo = now;
				var state:flixel.FlxState = FlxG.state;
				var sub:flixel.FlxState = (state != null) ? state.subState : null;
				@:privateAccess
				Sys.println('STATE ' + Type.getClassName(Type.getClass(state)) + ' active=' + state.active + ' exists=' + state.exists
					+ ' persistentUpdate=' + state.persistentUpdate + ' sub=' + (sub != null ? Type.getClassName(Type.getClass(sub)) + ' (active=' + sub.active + ')' : 'none')
					+ ' requested=' + (FlxG.game._nextState != null) + ' paused=' + FlxG.game._lostFocus
					+ ' fullscreen=' + FlxG.fullscreen + ' window=' + FlxG.stage.window.width + 'x' + FlxG.stage.window.height);
			});
		}

		// every frame that took long (the game froze for it), on the game's output
		if(options.exists('hitches'))
		{
			var limit:Float = number('hitches', 0.05);
			if(limit <= 0) limit = 0.05;
			var last:Float = -1;
			var began:Float = haxe.Timer.stamp();
			FlxG.stage.addEventListener(Event.ENTER_FRAME, function(_)
			{
				var now:Float = haxe.Timer.stamp();
				if(last >= 0 && now - last > limit)
					Sys.println('HITCH ' + Std.int((now - last) * 1000) + ' ms at ' + FlxMath.roundDecimal(now - began, 2) + 's on ' + Type.getClassName(Type.getClass(FlxG.state)));
				last = now;
			});
		}

		// The game pauses itself while its window isn't the one being used (an option of the game). Nobody is there to click on it
		// when it's opened like this, and whatever else is going on in the computer can leave it waiting on the title screen forever
		// (the menus set it back to the option, a song a script leaves for one of them would stop there)
		FlxG.autoPause = false;
		FlxG.signals.postStateSwitch.add(function() FlxG.autoPause = false);
	}

	// Options of the game given for this run, each as the kind of value it already is
	static function applyPrefs():Void
	{
		if(!options.exists('pref')) return;

		for (pair in options.get('pref').split(','))
		{
			var equals:Int = pair.indexOf('=');
			if(equals < 1) continue;

			var name:String = pair.substr(0, equals).trim();
			var text:String = pair.substr(equals + 1).trim();
			if(!Type.getInstanceFields(Type.getClass(ClientPrefs.data)).contains(name))
			{
				trace('There is no option called "$name"');
				continue;
			}

			var current:Dynamic = Reflect.field(ClientPrefs.data, name);
			var value:Dynamic = text;
			if(Std.isOfType(current, Bool)) value = (text.toLowerCase() == 'true' || text == '1');
			else if(Std.isOfType(current, Int)) value = Std.parseInt(text);
			else if(Std.isOfType(current, Float)) value = Std.parseFloat(text);
			Reflect.setField(ClientPrefs.data, name, value);

			// (the game goes at that speed right away, like when it's changed on the options)
			if(name == 'framerate')
			{
				var fps:Int = Std.int(FlxMath.bound(value, 30, 1000));
				if(fps > FlxG.drawFramerate)
				{
					FlxG.updateFramerate = fps;
					FlxG.drawFramerate = fps;
				}
				else
				{
					FlxG.drawFramerate = fps;
					FlxG.updateFramerate = fps;
				}
			}
		}
	}

	static function onFrame(_):Void
	{
		if(songOpenedAt < 0)
		{
			// (the loading screen counts as the song: one a script keeps on waits for keys, see psychlua.StateScripts)
			if(PlayState.instance == null && !Std.isOfType(FlxG.state, OptionsState) && !Std.isOfType(FlxG.state, states.editors.ChartingState)
				&& !Std.isOfType(FlxG.state, states.LoadingState)) return;
			songOpenedAt = haxe.Timer.stamp();
		}

		var elapsed:Float = haxe.Timer.stamp() - songOpenedAt;
		for (press in keyPresses)
		{
			if(press.done || elapsed < press.time) continue;

			// (held for a few frames, like a quick tap: let go on the very next one and the game may never see it pressed)
			if(!press.down)
			{
				press.down = true;
				press.held = 0;
				FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_DOWN, true, false, charCodeOf(press.code), press.code));
			}
			else if(++press.held >= 6 && elapsed >= press.time + press.hold)
			{
				press.done = true;
				FlxG.stage.dispatchEvent(new openfl.events.KeyboardEvent(openfl.events.KeyboardEvent.KEY_UP, true, false, charCodeOf(press.code), press.code));
			}
		}
		runMouse(elapsed);
		// "--members=SECONDS": what's on the state at that time, in its order (what covers what)
		if(options.exists('members') && !membersListed && elapsed >= number('members', 0))
		{
			membersListed = true;
			var lines:Array<String> = [];
			for (index => member in FlxG.state.members)
			{
				if(member == null) { lines.push('$index: null'); continue; }
				var line:String = '$index: ' + Type.getClassName(Type.getClass(member)) + (member.visible ? '' : ' hidden') + (member.exists ? '' : ' gone');
				var sprite:FlxSprite = Std.downcast(member, FlxSprite);
				if(sprite != null) line += ' a=' + FlxMath.roundDecimal(sprite.alpha, 2) + ' c=' + StringTools.hex(sprite.color & 0xFFFFFF, 6) + ' size ' + Math.round(sprite.width) + 'x' + Math.round(sprite.height) + ' at ' + Math.round(sprite.x) + ',' + Math.round(sprite.y);
				var cams:Array<String> = [for (camera in member.cameras) (FlxG.cameras.list.indexOf(camera) + '')];
				line += ' cams=' + cams.join('/');
				lines.push(line);
			}
			trace('MEMBERS at ' + elapsed + 's (cameras: ' + [for (i => c in FlxG.cameras.list) '$i a=' + c.alpha + (c.visible ? '' : ' hidden')].join(', ') + ')
' + lines.join('
'));
		}
		// "--fullscreenat=SECONDS": the window goes fullscreen then, like with ALT+ENTER (not through the game's option)
		if(options.exists('fullscreenat') && !wentFullscreen && elapsed >= number('fullscreenat', 0))
		{
			wentFullscreen = true;
			FlxG.stage.window.fullscreen = true;
			Sys.println('DIRECTPLAY: the window went fullscreen');
		}

		// "--freezeatlas=SECONDS": every texture atlas on the screen stops on the first frame of what it's playing then
		// (to compare one with V-Slice on the very same frame)
		if(options.exists('freezeatlas') && !atlasesFrozen && elapsed >= number('freezeatlas', 0))
		{
			atlasesFrozen = true;
			freezeAtlases(FlxG.state);
		}
		if(options.exists('log')) logCharacters(elapsed);
		if(options.exists('skipdialogue') && PlayState.instance != null)
		{
			@:privateAccess
			var talk = PlayState.instance.conversation;
			if(talk == null) dialogueSeenAt = -1;
			else if(dialogueSeenAt < 0) dialogueSeenAt = elapsed;
			else if(elapsed - dialogueSeenAt > 1.5)
			{
				dialogueSeenAt = elapsed + 1000; //(once)
				talk.skip();
			}
		}
		while(shotsTaken < shotTimes.length && elapsed >= shotTimes[shotsTaken])
		{
			shotsTaken++;
			takeShot(shotsTaken);
		}

		if(quitAfter >= 0 && elapsed >= quitAfter && shotsTaken >= shotTimes.length)
		{
			FlxG.stage.removeEventListener(Event.ENTER_FRAME, onFrame);
			// (what was playing: a run can't be listened to)
			var music:flixel.sound.FlxSound = FlxG.sound.music;
			if(music != null)
				Sys.println('Music when closed: ' + (music.playing ? 'playing' : 'not playing') + ' at ' + Std.int(music.time) + ' of ' + Std.int(music.length)
					+ ' ms, volume ' + FlxMath.roundDecimal(music.volume, 2));
			Sys.exit(0);
		}
	}

	static var atlasesFrozen:Bool = false;
	static var membersListed:Bool = false;
	static function freezeAtlases(group:flixel.group.FlxGroup.FlxTypedGroup<flixel.FlxBasic>):Void
	{
		if(group == null) return;
		for (member in group.members)
		{
			var atlas:flxanimate.FlxAnimate = Std.downcast(member, flxanimate.FlxAnimate);
			if(atlas != null && atlas.anim != null)
			{
				atlas.anim.curFrame = Std.int(number('freezeframe', 0)); //(--freezeframe=N: that frame of it instead of the first)
				atlas.anim.pause();
				continue;
			}
			var inner:flixel.group.FlxGroup.FlxTypedGroup<flixel.FlxBasic> = Std.downcast(member, flixel.group.FlxGroup.FlxTypedGroup);
			if(inner != null) freezeAtlases(inner);
			else if(Std.isOfType(member, flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup))
			{
				var spriteGroup:Dynamic = member;
				freezeAtlases(cast spriteGroup.group);
			}
		}
	}

	static var wentFullscreen:Bool = false;
	static var mouseActions:Array<{time:Float, action:String, values:Array<Float>}> = [];
	static var mouseX:Float = 640;
	static var mouseY:Float = 360;
	static var mouseMove:{fromX:Float, fromY:Float, toX:Float, toY:Float, start:Float, length:Float} = null;

	// The mouse, as if it was the real one: through the window, the way the system's events get to the game
	static function runMouse(elapsed:Float):Void
	{
		#if lime
		var window = FlxG.stage.window;
		if(window == null) return;

		if(mouseMove != null)
		{
			var progress:Float = (mouseMove.length > 0) ? Math.min(1, (elapsed - mouseMove.start) / mouseMove.length) : 1;
			mouseX = FlxMath.lerp(mouseMove.fromX, mouseMove.toX, progress);
			mouseY = FlxMath.lerp(mouseMove.fromY, mouseMove.toY, progress);
			window.onMouseMove.dispatch(windowX(mouseX), windowY(mouseY));
			if(progress >= 1) mouseMove = null;
		}

		// (one at a time: a press and a release on the same frame would be seen as neither)
		if(mouseActions.length < 1 || elapsed < mouseActions[0].time) return;
		var next = mouseActions.shift();
		var x:Float = windowX(mouseX), y:Float = windowY(mouseY);
		switch(next.action)
		{
			case 'move':
				var length:Float = (next.values.length > 2 && !Math.isNaN(next.values[2])) ? next.values[2] : 0;
				mouseMove = {fromX: mouseX, fromY: mouseY, toX: next.values[0], toY: next.values[1], start: elapsed, length: length};
				if(length <= 0)
				{
					mouseX = next.values[0];
					mouseY = next.values[1];
					mouseMove = null;
					window.onMouseMove.dispatch(windowX(mouseX), windowY(mouseY));
				}
			case 'down': window.onMouseDown.dispatch(x, y, lime.ui.MouseButton.LEFT);
			case 'up': window.onMouseUp.dispatch(x, y, lime.ui.MouseButton.LEFT);
			case 'rdown': window.onMouseDown.dispatch(x, y, lime.ui.MouseButton.RIGHT);
			case 'rup': window.onMouseUp.dispatch(x, y, lime.ui.MouseButton.RIGHT);
			case 'mdown': window.onMouseDown.dispatch(x, y, lime.ui.MouseButton.MIDDLE);
			case 'mup': window.onMouseUp.dispatch(x, y, lime.ui.MouseButton.MIDDLE);
			case 'wheel': window.onMouseWheel.dispatch(0, next.values[0], lime.ui.MouseWheelMode.LINES);
			default: trace('Unknown mouse action "${next.action}"');
		}
		#end
	}

	static inline function windowX(gameX:Float):Float
		return FlxG.game.x + gameX * FlxG.scaleMode.scale.x;
	static inline function windowY(gameY:Float):Float
		return FlxG.game.y + gameY * FlxG.scaleMode.scale.y;

	static var dialogueSeenAt:Float = -1;
	static var keyPresses:Array<{time:Float, code:Int, down:Bool, done:Bool, held:Int, hold:Float}> = [];
	static var logLines:Array<String> = [];
	static var logWritten:Float = 0;

	// (flixel reads the letters and numbers of the native keyboard by their character too: without it "E" is no key at all, "Q" is F2)
	static function charCodeOf(keyCode:Int):Int
	{
		if(keyCode >= 65 && keyCode <= 90) return keyCode + 32;
		if(keyCode >= 48 && keyCode <= 57) return keyCode;
		return 0;
	}

	static function logCharacters(elapsed:Float):Void
	{
		var game:PlayState = PlayState.instance;
		if(game == null || game.boyfriend == null) return;

		var line:String = Std.string(Math.round(elapsed * 100) / 100) + 's song ' + Math.round(Conductor.songPosition) + ':';
		if(logLines.length < 1 && game.vocals != null && game.opponentVocals != null)
			line += ' | voices: player ' + Math.round(game.vocals.length) + ' ms, opponent ' + Math.round(game.opponentVocals.length) + ' ms';
		// what plays and what the player sees: the vocal tracks (P = player's, O = opponent's), the HUD, and how many of the receptors
		// and notes being played are showing
		if(game.vocals != null && game.opponentVocals != null)
			line += ' | vox ' + (game.vocals.playing ? 'P' : '-') + (game.opponentVocals.playing ? 'O' : '-');
		if(game.camHUD != null)
			line += ' | hud ' + (game.camHUD.visible ? Std.string(Math.round(game.camHUD.alpha * 100) / 100) : 'hidden')
				+ (@:privateAccess game.hudGuard > 0 ? ' shown ' + Std.string(Math.round(@:privateAccess game.hudGuard * 100) / 100) : '');
		if(game.playableStrums != null)
		{
			var shown:Int = 0;
			for (strum in game.playableStrums.members)
				if(strum != null && strum.visible && strum.alpha > 0.05) shown++;
			var notes:Int = 0, notesShown:Int = 0;
			if(game.notes != null)
				for (note in game.notes.members)
					if(note != null && note.alive && note.playable && !note.isSustainNote && note.y > -100 && note.y < FlxG.height + 100)
					{
						notes++;
						if(note.visible && note.alpha > 0.05) notesShown++;
					}
			// (and how many of them are lit up: pressed or hit)
			var lit:Int = 0;
			for (strum in game.playableStrums.members)
				if(strum != null && strum.animation.curAnim != null && strum.animation.curAnim.name != 'static') lit++;
			line += ' | played receptors ' + shown + '/' + game.playableStrums.length + ' notes ' + notesShown + '/' + notes + ' lit ' + lit;
		}
		var everyone:Array<objects.Character> = [game.boyfriend, game.dad, game.gf];
		#if HSCRIPT_ALLOWED
		everyone = backend.VSliceScripts.stageCharacters();
		#end
		for (char in everyone)
		{
			if(char == null) continue;

			var frame:Int = -1;
			try
			{
				frame = char.isAnimateAtlas ? char.atlas.anim.curFrame : ((char.animation.curAnim != null) ? char.animation.curAnim.curFrame : -1);
			}
			catch(e:Dynamic) {}
			line += ' | ' + char.curCharacter + ' ' + char.getAnimationName() + '#' + frame
				+ (char.isAnimationFinished() ? ' over' : '') + (char.specialAnim ? ' special' : '') + (char.visible ? '' : ' hidden');
			if(options.exists('places'))
				line += ' at ' + Math.round(char.x) + ',' + Math.round(char.y) + ' size ' + Math.round(char.width) + 'x' + Math.round(char.height) + ' a=' + char.alpha
					+ ' scale=' + char.scale.x + ' order=' + drawOrder(game, char) + ' image=' + ((char.graphic != null) ? Std.string(char.graphic.key) : 'none');
		}
		if(options.exists('places'))
			line += ' | camera ' + Math.round(FlxG.camera.scroll.x) + ',' + Math.round(FlxG.camera.scroll.y) + ' zoom ' + (Math.round(FlxG.camera.zoom * 100) / 100);
		if(options.exists('watch'))
		{
			for (name in options.get('watch').split(','))
			{
				name = name.trim();
				if(name.length < 1) continue;

				#if HSCRIPT_ALLOWED
				if(name.startsWith('stage.'))
				{
					@:privateAccess
					var stage = backend.VSliceScripts.stageScript;
					line += ' | $name=' + ((stage != null) ? Std.string(stage.getField(name.substr(6))) : 'no stage script');
					continue;
				}
				#end

				var sprite:FlxSprite = Std.downcast(game.variables.get(name), FlxSprite);
				if(sprite == null) line += ' | $name missing';
				else line += ' | $name a=' + (Math.round(sprite.alpha * 100) / 100) + ' c=' + StringTools.hex(sprite.color & 0xFFFFFF, 6) + ' b=' + Std.string(sprite.blend)
					+ (sprite.visible ? '' : ' hidden') + ((sprite.shader != null) ? ' shader' : '')
					+ (options.exists('places') ? ' at ' + Math.round(sprite.x) + ',' + Math.round(sprite.y) + ' size ' + Math.round(sprite.width) + 'x' + Math.round(sprite.height)
						+ ' order=' + drawOrder(game, sprite) + ' image=' + ((sprite.graphic != null) ? Std.string(sprite.graphic.key) : 'none') : '');
			}
		}
		logLines.push(line);

		// (written every second, the game can be closed from outside at any time)
		if(elapsed - logWritten >= 1)
		{
			logWritten = elapsed;
			try
			{
				File.saveContent(options.get('log'), logLines.join('\n') + '\n');
			}
			catch(e:Dynamic) {}
		}
	}

	// Where something is on the order the song draws its things (the higher the more on front), -1 if it isn't one of them
	static function drawOrder(game:PlayState, object:flixel.FlxBasic):Int
	{
		for (index => member in game.members)
		{
			if(member == object) return index;

			var group:flixel.group.FlxSpriteGroup = Std.downcast(member, flixel.group.FlxSpriteGroup);
			if(group != null && group.members.contains(cast object)) return index;
		}
		return -1;
	}

	static function takeShot(index:Int):Void
	{
		try
		{
			var folder:String = options.exists('shotdir') ? options.get('shotdir') : '';
			if(folder.length > 0)
			{
				folder = folder.replace('\\', '/');
				if(!folder.endsWith('/')) folder += '/';
				if(!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
			}

			// (the window's own picture: something drawn into an image off the screen can leave that image's framebuffer bound,
			// and the picture was of it, upside down)
			var bound:Dynamic = null;
			try
			{
				bound = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.FRAMEBUFFER_BINDING);
				lime.graphics.opengl.GL.bindFramebuffer(lime.graphics.opengl.GL.FRAMEBUFFER, null);
			}
			catch(e:Dynamic) {}
			var bitmap:BitmapData = BitmapData.fromImage(FlxG.stage.window.readPixels());
			if(bound != null) try { lime.graphics.opengl.GL.bindFramebuffer(lime.graphics.opengl.GL.FRAMEBUFFER, bound); } catch(e:Dynamic) {}
			if(bound != null) trace('Picture $index: a framebuffer other than the one of the window was bound');
			trace('Picture $index: on ' + Type.getClassName(Type.getClass(FlxG.state)) + ((FlxG.state.subState != null) ? ', under ' + Type.getClassName(Type.getClass(FlxG.state.subState)) : ''));
			File.saveBytes(folder + 'directplay_$index.png', bitmap.encode(bitmap.rect, new PNGEncoderOptions()));
			bitmap.dispose();
		}
		catch(e:Dynamic)
		{
			trace('Could not save the picture: $e');
		}
	}
}
#end
