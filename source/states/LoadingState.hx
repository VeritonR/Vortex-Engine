package states;

import lime.app.Future;
import sys.thread.FixedThreadPool;
import haxe.Json;
import lime.utils.Assets;
import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;
import flixel.FlxState;

import flash.media.Sound;

import backend.Song;
import backend.WeekData;
import backend.Highscore;
import backend.StageData;
import objects.Character;

import sys.thread.Thread;
import sys.thread.Mutex;

import objects.Note;
import objects.NoteSplash;

#if HSCRIPT_ALLOWED
import psychlua.HScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

#if cpp
@:headerCode('
#include <iostream>
#include <thread>
')
#end
class LoadingState extends MusicBeatState
{
	public static var loaded:Int = 0;
	public static var loadMax:Int = 0;

	/*
	 * The loading threads only read the files: turning them into images and sounds is done by the game's own thread (`checkLoaded()`).
	 * Lime's code that does it isn't safe on more than one thread at a time: it holds a lock of its own while it makes Haxe objects,
	 * and if the memory is cleaned up right then, a thread waiting for that lock keeps the cleanup from ever starting and every thread
	 * of the game waits forever (it froze the game on the way to a song every few times, more often the more images it had).
	 */
	static var readFiles:Array<ReadFile> = [];
	// how many of the things to load the threads are done with (read, or found not to exist)
	static var filesRead:Int = 0;
	// set when the threads took too long: what wasn't loaded is loaded by the song itself
	static var givenUp:Bool = false;
	// seconds the game's thread spent making the images and the sounds of this loading
	static var imageSeconds:Float = 0;
	static var soundSeconds:Float = 0;
	// One for the whole game: replacing it while a loading thread held the old one could leave the others waiting forever
	static var mutex:Mutex = new Mutex();
	static var threadPool:FixedThreadPool = null;

	/**
	 * Seconds the game waits for the loading threads without any of them finishing something when there's no loading screen
	 * (between the songs of a week). After that it goes on anyway: whatever wasn't loaded is loaded by the song itself.
	 */
	public static var waitTimeout:Float = 20;

	function new(target:FlxState, stopMusic:Bool)
	{
		this.target = target;
		this.stopMusic = stopMusic;
		
		super();
	}

	inline static public function loadAndSwitchState(target:FlxState, stopMusic = false, intrusive:Bool = true)
		MusicBeatState.switchState(getNextState(target, stopMusic, intrusive));
	
	var target:FlxState = null;
	var stopMusic:Bool = false;
	var dontUpdate:Bool = false;

	var barGroup:FlxSpriteGroup;
	var bar:FlxSprite;
	var barWidth:Int = 0;
	var intendedPercent:Float = 0;
	var curPercent:Float = 0;
	var stateChangeDelay:Float = 0;

	#if PSYCH_WATERMARKS
	var logo:FlxSprite;
	var pessy:FlxSprite;
	var loadingText:FlxText;

	var timePassed:Float;
	var shakeFl:Float;
	var shakeMult:Float = 0;
	
	var isSpinning:Bool = false;
	var spawnedPessy:Bool = false;
	var pressedTimes:Int = 0;
	#else
	var funkay:FlxSprite;
	#end

	#if HSCRIPT_ALLOWED
	var hscript:HScript;
	#end
	override function create()
	{
		backend.StepLog.add('Loading screen: opened');
		persistentUpdate = true;
		barGroup = new FlxSpriteGroup();
		add(barGroup);

		var barBack:FlxSprite = new FlxSprite(0, 660).makeGraphic(1, 1, FlxColor.BLACK);
		barBack.scale.set(FlxG.width - 300, 25);
		barBack.updateHitbox();
		barBack.screenCenter(X);
		barGroup.add(barBack);

		bar = new FlxSprite(barBack.x + 5, barBack.y + 5).makeGraphic(1, 1, FlxColor.WHITE);
		bar.scale.set(0, 15);
		bar.updateHitbox();
		barGroup.add(bar);
		barWidth = Std.int(barBack.width - 10);

		#if HSCRIPT_ALLOWED
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.trim().length > 0)
		{
			var scriptPath:String = 'mods/${Mods.currentModDirectory}/data/LoadingScreen.hx'; //mods/My-Mod/data/LoadingScreen.hx
			if(FileSystem.exists(scriptPath))
			{
				try
				{
					hscript = new HScript(null, scriptPath);
					hscript.set('getLoaded', function() return loaded);
					hscript.set('getLoadMax', function() return loadMax);
					hscript.set('barBack', barBack);
					hscript.set('bar', bar);
	
					if(hscript.exists('onCreate'))
					{
						hscript.call('onCreate');
						trace('initialized hscript interp successfully: $scriptPath');
						return super.create();
					}
					else
					{
						trace('"$scriptPath" contains no \"onCreate" function, stopping script.');
					}
				}
				catch(e:IrisError)
				{
					var pos:HScriptInfos = cast {fileName: scriptPath, showLine: false};
					Iris.error(Printer.errorToString(e, false), pos);
					var hscript:HScript = cast (Iris.instances.get(scriptPath), HScript);
				}
				if(hscript != null) hscript.destroy();
				hscript = null;
			}
		}
		#end

		#if PSYCH_WATERMARKS // PSYCH LOADING SCREEN
		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		defaultBg = bg;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(FlxG.width));
		bg.color = 0xFFD16FFF;
		bg.updateHitbox();
		addBehindBar(bg);
	
		loadingText = new FlxText(520, 600, 400, Language.getPhrase('now_loading', 'Now Loading', ['...']), 32);
		loadingText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		loadingText.borderSize = 2;
		addBehindBar(loadingText);
	
		logo = new FlxSprite(0, 0).loadGraphic(Paths.image('loading_screen/icon'));
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.scale.set(0.75, 0.75);
		logo.updateHitbox();
		logo.screenCenter();
		logo.x -= 50;
		logo.y -= 40;
		addBehindBar(logo);

		#else // BASE GAME LOADING SCREEN
		var bg = new FlxSprite().makeGraphic(1, 1, 0xFFCAFF4D);
		defaultBg = bg;
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		addBehindBar(bg);

		funkay = new FlxSprite(0, 0).loadGraphic(Paths.image('funkay'));
		funkay.antialiasing = ClientPrefs.data.antialiasing;
		funkay.setGraphicSize(0, FlxG.height);
		funkay.updateHitbox();
		addBehindBar(funkay);
		#end
		super.create();

		if (stateChangeDelay <= 0 && checkLoaded())
		{
			dontUpdate = true;
			onLoad();
		}
	}

	function addBehindBar(obj:flixel.FlxBasic)
	{
		insert(members.indexOf(barGroup), obj);
	}

	var transitioning:Bool = false;
	var lastToldLoaded:Int = -1;
	// How much was loaded the last time it moved forward, and when that was
	var stuckLoaded:Int = -1;
	var stuckSince:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (dontUpdate) return;

		if (!transitioning)
		{
			if (!finishedLoading && checkLoaded())
			{
				if(stateChangeDelay <= 0)
				{
					transitioning = true;
					onLoad();
					return;
				}
				else stateChangeDelay = Math.max(0, stateChangeDelay - elapsed);
			}
			else if(!finishedLoading)
			{
				// This screen can't be left waiting forever either (see getNextState()): if the threads stop answering,
				// the song goes on without what they were loading, which is then loaded when it's first used
				var now:Float = Sys.time();
				if(loaded != stuckLoaded || stuckSince == 0)
				{
					stuckLoaded = loaded;
					stuckSince = now;
				}
				else if(now - stuckSince > waitTimeout)
				{
					var report:String = 'The loading threads stopped answering: $loaded of $loadMax things loaded, song prepared: $initialThreadCompleted. Going on without them'
						+ '\nimages: $imagesToPrepare\nsounds: $soundsToPrepare\nmusic: $musicToPrepare\nsongs: $songsToPrepare';
					trace(report);
					backend.StepLog.add(report);

					stuckSince = now;
					initialThreadCompleted = true;
					givenUp = true;
				}
			}
			intendedPercent = loaded / loadMax;
			if(loaded != lastToldLoaded)
			{
				lastToldLoaded = loaded;
				psychlua.StateScripts.call('onLoadingProgress', [loaded, loadMax, (loadMax > 0) ? loaded / loadMax : 1]);
			}
		}

		if (curPercent != intendedPercent)
		{
			if (Math.abs(curPercent - intendedPercent) < 0.001) curPercent = intendedPercent;
			else curPercent = FlxMath.lerp(intendedPercent, curPercent, Math.exp(-elapsed * 15));

			bar.scale.x = barWidth * curPercent;
			bar.updateHitbox();
		}
		
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			if(hscript.exists('onUpdate')) hscript.call('onUpdate', [elapsed]);
			return;
		}
		#end

		#if PSYCH_WATERMARKS // PSYCH LOADING SCREEN
		timePassed += elapsed;
		shakeFl += elapsed * 3000;
		var dots:String = '';
		switch(Math.floor(timePassed % 1 * 3))
		{
			case 0:
				dots = '.';
			case 1:
				dots = '..';
			case 2:
				dots = '...';
		}
		loadingText.text = Language.getPhrase('now_loading', 'Now Loading{1}', [dots]);

		if(!spawnedPessy)
		{
			if(!transitioning && controls.ACCEPT)
			{
				shakeMult = 1;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				pressedTimes++;
			}
			shakeMult = Math.max(0, shakeMult - elapsed * 5);
			logo.offset.x = Math.sin(shakeFl * Math.PI / 180) * shakeMult * 100;

			if(pressedTimes >= 5)
			{
				FlxG.camera.fade(0xAAFFFFFF, 0.5, true);
				logo.visible = false;
				spawnedPessy = true;
				stateChangeDelay = 5;
				FlxG.sound.play(Paths.sound('secret'));

				pessy = new FlxSprite(700, 140);
				pessy.frames = Paths.getSparrowAtlas('loading_screen/pessy');
				pessy.animation.addByPrefix('run', 'run', 24, true);
				pessy.animation.addByPrefix('spin', 'spin', 24, true);
				pessy.antialiasing = ClientPrefs.data.antialiasing;
				pessy.flipX = (logo.offset.x > 0);
				pessy.visible = false;

				new FlxTimer().start(0.01, function(tmr:FlxTimer) {
					pessy.x = FlxG.width + 200;
					pessy.velocity.x = -1100;
					if(pessy.flipX)
					{
						pessy.x = -pessy.width - 200;
						pessy.velocity.x *= -1;
					}
		
					pessy.visible = true;
					pessy.animation.play('run', true);
					#if ACHIEVEMENTS_ALLOWED Achievements.unlock('pessy_easter_egg'); #end
					
					insert(members.indexOf(loadingText), pessy);
				});
			}
		}
		else if(!isSpinning && (pessy.flipX && pessy.x > FlxG.width) || (!pessy.flipX && pessy.x < -pessy.width))
		{
			isSpinning = true;
			pessy.animation.play('spin', true);
			pessy.flipX = false;
			pessy.x = 500;
			pessy.y = FlxG.height + 500;
			pessy.velocity.x = 0;
			FlxTween.tween(pessy, {y: 10}, 0.65, {ease: FlxEase.quadOut});
		}
		#end
	}

	#if HSCRIPT_ALLOWED
	override function destroy()
	{
		if(hscript != null)
		{
			if(hscript.exists('onDestroy')) hscript.call('onDestroy');
			hscript.destroy();
		}
		hscript = null;
		super.destroy();
	}
	#end
	
	var finishedLoading:Bool = false;
	var scriptAllowedFinish:Bool = false;
	var waitingForScript:Bool = false;
	function onLoad()
	{
		// (a state script can keep the loading screen on, after it's done: see psychlua.StateScripts)
		if(!scriptAllowedFinish && psychlua.StateScripts.call('onFinishedLoading') == psychlua.LuaUtils.Function_Stop)
		{
			waitingForScript = true;
			transitioning = true;
			intendedPercent = curPercent = 1;
			bar.scale.x = barWidth;
			bar.updateHitbox();
			backend.StepLog.add('Loading screen: everything loaded, a script keeps it on');
			return;
		}
		backend.StepLog.add('Loading screen: everything loaded, going on');
		_loaded();

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.camera.visible = false;
		MusicBeatState.switchState(target);
		backend.StepLog.add('Loading screen: asked for ' + Type.getClassName(Type.getClass(target)));
		transitioning = true;
		finishedLoading = true;
	}

	/**
	 * For state scripts that kept the loading screen on (returning Function_Stop on onFinishedLoading): goes on to the song.
	 */
	public function finishLoading():Void
	{
		if(!waitingForScript) return;
		waitingForScript = false;
		scriptAllowedFinish = true;
		onLoad();
	}

	/**
	 * Hides the loading screen's own picture (and the bar too, if asked), for a state script to show its own.
	 */
	public function hideDefaultScreen(hideBar:Bool = false):Void
	{
		#if PSYCH_WATERMARKS
		var things:Array<FlxSprite> = [logo, loadingText];
		#else
		var things:Array<FlxSprite> = [funkay];
		#end
		for (thing in things)
			if(thing != null) thing.visible = false;
		if(defaultBg != null) defaultBg.visible = false;
		if(hideBar) barGroup.visible = false;
	}
	var defaultBg:FlxSprite;

	static function _loaded()
	{
		loaded = 0;
		loadMax = 0;
		initialThreadCompleted = true;
		isIntrusive = false;
		givenUp = false;
		mutex.acquire();
		readFiles = [];
		mutex.release();

		FlxTransitionableState.skipNextTransIn = true;
		if (threadPool != null) threadPool.shutdown(); // kill all workers safely
		threadPool = null;
		backend.StepLog.add('Loading screen: loading threads let go (images made in ' + FlxMath.roundDecimal(imageSeconds, 2)
			+ 's, sounds in ' + FlxMath.roundDecimal(soundSeconds, 2) + 's)');
	}

	/**
	 * If a song is being loaded right now: its threads are looking for files by the mod that's set.
	 * Nothing else should change which mod that is until they're done (the scripts of the menus do it, each for its own mod).
	 */
	public static function isBusy():Bool
	{
		return !initialThreadCompleted || loaded < loadMax;
	}

	/**
	 * Turns what the loading threads read into images and sounds, for up to `budget` seconds (0 for all of it: when nothing is
	 * being shown), and says if everything is loaded.
	 */
	public static function checkLoaded(budget:Float = 0.03):Bool
	{
		if(givenUp)
		{
			mutex.acquire();
			readFiles = [];
			mutex.release();
			return true;
		}

		var start:Float = Sys.time();
		while(true)
		{
			mutex.acquire();
			var item:ReadFile = readFiles.shift();
			mutex.release();
			if(item == null) break;

			var itemStart:Float = Sys.time();
			try
			{
				if(item.isSound) finishSound(item);
				else finishImage(item);
			}
			catch(e:Dynamic)
			{
				trace('ERROR! fail on preloading ${item.file}: $e');
			}
			if(item.isSound) soundSeconds += Sys.time() - itemStart;
			else imageSeconds += Sys.time() - itemStart;
			if(budget > 0 && Sys.time() - start > budget) break;
		}

		mutex.acquire();
		loaded = filesRead - readFiles.length;
		mutex.release();
		return (loaded >= loadMax && initialThreadCompleted);
	}

	static function finishImage(item:ReadFile):Void
	{
		if(Paths.currentTrackedAssets.exists(item.key)) return;

		var bitmap:BitmapData = null;
		if(item.png != null) bitmap = backend.PngDecoder.toBitmapData(item.png);
		else if(item.bytes != null) bitmap = BitmapData.fromBytes(item.bytes);
		else bitmap = OpenFlAssets.getBitmapData(item.file, false);
		if (bitmap == null || Paths.cacheBitmap(item.key, bitmap) == null)
			trace('failed to cache image ${item.file}');
	}

	static function finishSound(item:ReadFile):Void
	{
		if(!Paths.currentTrackedSounds.exists(item.file))
		{
			var sound:Sound = null;
			if(item.bytes != null && !backend.SoundLoader.validBytes(item.bytes))
			{
				trace('The sound "${item.file}" is empty or is not one that can be played: it was left out');
				return;
			}
			if(item.bytes != null)
			{
				var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromBytes(item.bytes);
				if(buffer != null) sound = Sound.fromAudioBuffer(buffer);
			}
			else sound = OpenFlAssets.getSound(item.file, false);

			if(sound == null)
			{
				trace('failed to load sound ${item.file}');
				return;
			}
			Paths.currentTrackedSounds.set(item.file, sound);
		}
		Paths.localTrackedAssets.push(item.file);
	}

	public static function loadNextDirectory()
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);
	}

	static var isIntrusive:Bool = false;
	static function getNextState(target:FlxState, stopMusic = false, intrusive:Bool = true):FlxState
	{
		#if !SHOW_LOADING_SCREEN
		intrusive = false;
		#end

		LoadingState.isIntrusive = intrusive;
		_startPool();
		loadNextDirectory();
		backend.StepLog.add('Loading: the folder of the files is set');

		if(intrusive)
		{
			var state:LoadingState = new LoadingState(target, stopMusic);
			backend.StepLog.add('Loading: the loading screen was made');
			return state;
		}
		
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// The window doesn't answer to anything during this, so it can't be allowed to last forever
		var waitStart:Float = Sys.time();
		var lastProgress:Float = waitStart;
		var lastLoaded:Int = -1;
		backend.StepLog.add('Loading without a loading screen: waiting for the loading threads');
		while(true)
		{
			if(checkLoaded(0))
			{
				_loaded();
				backend.StepLog.add('Loading threads finished in ' + FlxMath.roundDecimal(Sys.time() - waitStart, 2) + 's');
				break;
			}

			if(loaded != lastLoaded)
			{
				lastLoaded = loaded;
				lastProgress = Sys.time();
			}
			else if(Sys.time() - lastProgress > waitTimeout)
			{
				var report:String = 'The loading threads stopped answering: $loaded of $loadMax things loaded, song prepared: $initialThreadCompleted. Going on without them'
					+ '\nimages: $imagesToPrepare\nsounds: $soundsToPrepare\nmusic: $musicToPrepare\nsongs: $songsToPrepare';
				trace(report);
				backend.StepLog.add(report);
				_loaded();
				break;
			}
			Sys.sleep(0.001);
		}
		return target;
	}

	static var imagesToPrepare:Array<String> = [];
	static var soundsToPrepare:Array<String> = [];
	static var musicToPrepare:Array<String> = [];
	static var songsToPrepare:Array<String> = [];
	public static function prepare(images:Array<String> = null, sounds:Array<String> = null, music:Array<String> = null)
	{
		if (images != null) imagesToPrepare = imagesToPrepare.concat(images);
		if (sounds != null) soundsToPrepare = soundsToPrepare.concat(sounds);
		if (music != null) musicToPrepare = musicToPrepare.concat(music);
	}

	static var initialThreadCompleted:Bool = true;
	static var dontPreloadDefaultVoices:Bool = false;
	static function _startPool()
	{
		// One for each time something is loaded: this is called from every place that might be the first to need it,
		// and each call made another one. The ones before the last were left with their threads waiting forever
		// (only the last is told to stop when the loading ends), a dozen more threads for every song played
		if(threadPool != null) return;

		#if MULTITHREADED_LOADING
		// Due to the Main thread and Discord thread, we decrease it by 2.
		var threadCount:Int = Std.int(Math.max(1, getCPUThreadsCount() - #if DISCORD_ALLOWED 2 #else 1 #end));
		#else
		var threadCount:Int = 1;
		#end
		threadPool = new FixedThreadPool(threadCount);
	}

	/**
	 * V-Slice's way of opening a song, for the scripts of its mods: `LoadingState.loadPlayState({targetSong: song, targetDifficulty: 'hard'})`,
	 * with the song (or its id), and optionally `practiceMode`, `startTimestamp` (in milliseconds) and `playbackRate`. The song is found
	 * like Freeplay finds it, on the weeks of the mod being played first; its variation is the one for the character picked on Character Select.
	 */
	public static function loadPlayState(params:Dynamic, shouldStopMusic:Bool = false, asSubState:Bool = false, ?onConstruct:Dynamic):Void
	{
		var target:Dynamic = (params != null) ? params.targetSong : null;
		var id:String = Std.isOfType(target, String) ? target : ((target != null && target.id != null) ? Std.string(target.id) : null);
		if(id == null)
		{
			trace('loadPlayState: no song to open');
			return;
		}
		var key:String = Paths.formatToSongPath(id);

		// the week that has it: the current mod's first
		var week:WeekData = null;
		var weekIndex:Int = -1;
		WeekData.reloadWeekFiles(false);
		for (pass in 0...2)
		{
			for (index => weekName in WeekData.weeksList)
			{
				var candidate:WeekData = WeekData.weeksLoaded.get(weekName);
				if(candidate == null || (pass == 0 && candidate.folder != Mods.currentModDirectory)) continue;

				for (entry in candidate.songs)
					if(Paths.formatToSongPath(Std.string(entry[0])) == key)
					{
						week = candidate;
						weekIndex = index;
						break;
					}
				if(week != null) break;
			}
			if(week != null) break;
		}
		if(week == null)
		{
			trace('loadPlayState: no week has the song "$id"');
			return;
		}

		WeekData.setDirectoryFromWeek(week);
		PlayState.storyWeek = weekIndex;
		Difficulty.loadFromWeek();

		var wanted:String = (params.targetDifficulty != null) ? Paths.formatToSongPath(Std.string(params.targetDifficulty)) : Paths.formatToSongPath(Difficulty.getDefault());
		var difficulty:Int = -1;
		for (index => name in Difficulty.list)
			if(Paths.formatToSongPath(name) == wanted)
				difficulty = index;
		if(difficulty < 0) difficulty = Std.int(Math.max(0, Difficulty.list.indexOf(Difficulty.getDefault())));

		try
		{
			Song.loadFromJson(Highscore.formatSong(key, difficulty), key);
		}
		catch(e:Dynamic)
		{
			trace('loadPlayState: the chart of "$id" could not be loaded: $e');
			return;
		}
		if(PlayState.SONG == null) return;

		PlayState.storyDifficulty = difficulty;
		if(params.practiceMode != null) ClientPrefs.data.gameplaySettings.set('practice', params.practiceMode == true);
		if(params.playbackRate != null) ClientPrefs.data.gameplaySettings.set('songspeed', FlxMath.bound(params.playbackRate, 0.5, 3));
		if(params.startTimestamp != null) PlayState.startOnTime = Math.max(0, params.startTimestamp);
		if(!PlayState.isStoryMode) PlayState.storyPlaylist = [key];

		if(shouldStopMusic && FlxG.sound.music != null) FlxG.sound.music.stop();

		@:privateAccess
		if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory) Paths.freeGraphicsFromMemory();

		prepareToSong();
		loadAndSwitchState(new PlayState(), shouldStopMusic);
	}

	public static function prepareToSong()
	{
		if(PlayState.SONG == null)
		{
			imagesToPrepare = [];
			soundsToPrepare = [];
			musicToPrepare = [];
			songsToPrepare = [];
			loaded = 0;
			loadMax = 0;
			initialThreadCompleted = true;
			isIntrusive = false;
			return;
		}

		_startPool();
		imagesToPrepare = [];
		soundsToPrepare = [];
		musicToPrepare = [];
		songsToPrepare = [];

		initialThreadCompleted = false;
		givenUp = false;
		var threadsCompleted:Int = 0;
		var threadsMax:Int = 0;
		var startedLoading:Bool = false;

		// Starts loading what was found, once. Whatever happens the song counts as prepared, or the game would wait forever
		function finishPreparing()
		{
			mutex.acquire();
			var first:Bool = !startedLoading;
			startedLoading = true;
			mutex.release();
			if(!first) return;

			backend.StepLog.add('Loading thread: the files to load are known, the ones that don\'t exist are taken out');
			try
			{
				clearInvalids();
				startThreads();
			}
			catch(e:Dynamic)
			{
				trace('ERROR! while starting to load the song: $e');
			}
			initialThreadCompleted = true;
			backend.StepLog.add('Loading thread: $loadMax files are being loaded');
		}

		function completedThread()
		{
			mutex.acquire();
			threadsCompleted++;
			var done:Bool = (threadsCompleted >= threadsMax);
			mutex.release();

			if(done) finishPreparing();
		}

		var song:SwagSong = PlayState.SONG;
		var folder:String = Paths.formatToSongPath(Song.loadedSongName);
		backend.StepLog.add('Preparing the song: the notes\' images and the preload file');
		new Future<Bool>(() -> {
			// LOAD NOTE IMAGE
			var noteSkin:String = Note.defaultNoteSkin;
			if(PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) noteSkin = PlayState.SONG.arrowSkin;
	
			var customSkin:String = noteSkin + Note.getNoteSkinPostfix();
			if(Paths.fileExists('images/$customSkin.png', IMAGE)) noteSkin = customSkin;
			imagesToPrepare.push(noteSkin);
			//

			// LOAD NOTE SPLASH IMAGE
			var noteSplash:String = NoteSplash.defaultNoteSplash;
			if(PlayState.SONG.splashSkin != null && PlayState.SONG.splashSkin.length > 0) noteSplash = PlayState.SONG.splashSkin;
			else noteSplash += NoteSplash.getSplashSkinPostfix();
			imagesToPrepare.push(noteSplash);

			try
			{
				var path:String = Paths.json('$folder/preload');
				var json:Dynamic = null;

				#if MODS_ALLOWED
				var moddyFile:String = Paths.modsJson('$folder/preload');
				if (FileSystem.exists(moddyFile)) json = Json.parse(File.getContent(moddyFile));
				else json = Json.parse(File.getContent(path));
				#else
				json = Json.parse(Assets.getText(path));
				#end

				if(json != null)
				{
					var imgs:Array<String> = [];
					var snds:Array<String> = [];
					var mscs:Array<String> = [];
					for (asset in Reflect.fields(json))
					{
						var filters:Int = Reflect.field(json, asset);
						var asset:String = asset.trim();

						if(filters < 0 || StageData.validateVisibility(filters))
						{
							if(asset.startsWith('images/'))
								imgs.push(asset.substr('images/'.length));
							else if(asset.startsWith('sounds/'))
								snds.push(asset.substr('sounds/'.length));
							else if(asset.startsWith('music/'))
								mscs.push(asset.substr('music/'.length));
						}
					}
					prepare(imgs, snds, mscs);
				}
			}
			catch(e:Dynamic) {}
			return true;
		}, isIntrusive)
		.then((_) -> new Future<Bool>(() -> {
			backend.StepLog.add('Preparing the song: the stage, the tracks and the player');
			if (song.stage == null || song.stage.length < 1)
				song.stage = StageData.vanillaSongStage(folder);

			var stageData:StageFile = StageData.getStageFile(song.stage);
			if (stageData != null)
			{
				var imgs:Array<String> = [];
				var snds:Array<String> = [];
				var mscs:Array<String> = [];
				if(stageData.preload != null)
				{
					for (asset in Reflect.fields(stageData.preload))
					{
						var filters:Int = Reflect.field(stageData.preload, asset);
						var asset:String = asset.trim();

						if(filters < 0 || StageData.validateVisibility(filters))
						{
							if(asset.startsWith('images/'))
								imgs.push(asset.substr('images/'.length));
							else if(asset.startsWith('sounds/'))
								snds.push(asset.substr('sounds/'.length));
							else if(asset.startsWith('music/'))
								mscs.push(asset.substr('music/'.length));
						}
					}
				}
				
				if (stageData.objects != null)
				{
					for (sprite in stageData.objects)
					{
						if(sprite.type == 'sprite' || sprite.type == 'animatedSprite')
							if((sprite.filters < 0 || StageData.validateVisibility(sprite.filters)) && !imgs.contains(sprite.image))
								imgs.push(sprite.image);
					}
				}
				prepare(imgs, snds, mscs);
			}
			// (and the ones it changes to while it plays, with the characters)
			prepare(StageData.laterStageImages(song));
			for (character in StageData.laterCharacters(song))
				prepare(characterImages(character));

			// V-Slice songs have other file names (Inst-erect, Voices-bf...), already found by the chart loader
			var vsliceAudio:Dynamic = song.vslice;
			if (vsliceAudio != null)
			{
				var tracks:Array<String> = [vsliceAudio.inst, vsliceAudio.playerVoices, vsliceAudio.opponentVoices, vsliceAudio.voices];
				for (track in tracks)
					if (track != null) songsToPrepare.push(track);
			}
			else songsToPrepare.push('$folder/Inst');

			var player1:String = song.player1;
			var player2:String = song.player2;
			var gfVersion:String = song.gfVersion;
			var prefixVocals:String = (song.needsVoices && vsliceAudio == null) ? '$folder/Voices' : null;
			if (gfVersion == null) gfVersion = 'gf';

			dontPreloadDefaultVoices = false;
			preloadCharacter(player1, prefixVocals);
			if (!dontPreloadDefaultVoices && prefixVocals != null)
			{
				if(Paths.fileExists('$prefixVocals-Player.${Paths.SOUND_EXT}', SOUND, false, 'songs') && Paths.fileExists('$prefixVocals-Opponent.${Paths.SOUND_EXT}', SOUND, false, 'songs'))
				{
					songsToPrepare.push('$prefixVocals-Player');
					songsToPrepare.push('$prefixVocals-Opponent');
				}
				else if(Paths.fileExists('$prefixVocals.${Paths.SOUND_EXT}', SOUND, false, 'songs'))
					songsToPrepare.push(prefixVocals);
			}

			// how many there are is known before the first one starts, or a quick one could finish thinking it was the last
			var loadOpponent:Bool = (player2 != player1);
			var loadGirlfriend:Bool = ((stageData == null || !stageData.hide_girlfriend) && gfVersion != player2 && gfVersion != player1);
			threadsMax = (loadOpponent ? 1 : 0) + (loadGirlfriend ? 1 : 0);

			if (loadOpponent)
			{
				threadPool.run(() -> {
					backend.StepLog.add('Loading thread: reading the opponent $player2');
					try { preloadCharacter(player2, prefixVocals); } catch (e:Dynamic) {}
					backend.StepLog.add('Loading thread: the opponent was read');
					completedThread();
				});
			}
			if (loadGirlfriend)
			{
				threadPool.run(() -> {
					backend.StepLog.add('Loading thread: reading the girlfriend $gfVersion');
					try { preloadCharacter(gfVersion); } catch (e:Dynamic) {}
					backend.StepLog.add('Loading thread: the girlfriend was read');
					completedThread();
				});
			}

			backend.StepLog.add('Preparing the song: $threadsMax characters are being read by the loading threads');
			if(threadsMax < 1) finishPreparing();
			return true;
		}, isIntrusive))
		.onError((err:Dynamic) -> {
			trace('ERROR! while preparing song: $err');
			finishPreparing();
		});
	}

	public static function clearInvalids()
	{
		clearInvalidFrom(imagesToPrepare, 'images', '.png', IMAGE);
		clearInvalidFrom(soundsToPrepare, 'sounds', '.${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(musicToPrepare, 'music',' .${Paths.SOUND_EXT}', SOUND);
		clearInvalidFrom(songsToPrepare, 'songs', '.${Paths.SOUND_EXT}', SOUND, 'songs');

		for (arr in [imagesToPrepare, soundsToPrepare, musicToPrepare, songsToPrepare])
			while (arr.contains(null))
				arr.remove(null);
	}

	static function clearInvalidFrom(arr:Array<String>, prefix:String, ext:String, type:AssetType, ?parentFolder:String = null)
	{
		for (folder in arr.copy())
		{
			var nam:String = folder.trim();
			if(nam.endsWith('/'))
			{
				for (subfolder in Mods.directoriesWithFile(Paths.getSharedPath(), '$prefix/$nam'))
				{
					for (file in FileSystem.readDirectory(subfolder))
					{
						if(file.endsWith(ext))
						{
							var toAdd:String = nam + haxe.io.Path.withoutExtension(file);
							if(!arr.contains(toAdd)) arr.push(toAdd);
						}
					}
				}

				//trace('Folder detected! ' + folder);
			}
		}

		var i:Int = 0;
		while(i < arr.length)
		{

			var member:String = arr[i];
			var myKey = '$prefix/$member$ext';
			if(parentFolder == 'songs') myKey = '$member$ext';

			//trace('attempting on $prefix: $myKey');
			var doTrace:Bool = false;
			if(member.endsWith('/') || (!Paths.fileExists(myKey, type, false, parentFolder) && (doTrace = true)))
			{
				arr.remove(member);
				if(doTrace) trace('Removed invalid $prefix: $member');
			}
			else i++;
		}
	}

	public static function startThreads()
	{
		loadMax = imagesToPrepare.length + soundsToPrepare.length + musicToPrepare.length + songsToPrepare.length;
		loaded = 0;
		givenUp = false;
		imageSeconds = 0;
		soundSeconds = 0;
		mutex.acquire();
		filesRead = 0;
		readFiles = [];
		mutex.release();

		//then start threads
		_threadFunc();
	}

	static function _threadFunc()
	{
		_startPool();
		for (sound in soundsToPrepare) initThread(() -> preloadSound('sounds/$sound'), 'sound $sound');
		for (music in musicToPrepare) initThread(() -> preloadSound('music/$music'), 'music $music');
		for (song in songsToPrepare) initThread(() -> preloadSound(song, 'songs', true, false), 'song $song');

		// for images, they get to have their own thread
		for (image in imagesToPrepare) initThread(() -> preloadGraphic(image), 'image $image');
	}

	static function initThread(func:Void->Dynamic, traceData:String)
	{
		// trace('scheduled $func in threadPool');
		#if debug
		var threadSchedule = Sys.time();
		#end
		threadPool.run(() -> {
			#if debug
			var threadStart = Sys.time();
			trace('$traceData took ${threadStart - threadSchedule}s to start preloading');
			#end

			try {
				if (func() != null) {
					#if debug
					var diff = Sys.time() - threadStart;
					trace('finished preloading $traceData in ${diff}s');
					#end
				} else trace('ERROR! fail on preloading $traceData ');
			}
			catch(e:Dynamic) {
				trace('ERROR! fail on preloading $traceData: $e');
			}
			// two threads counting at the same time could count one, and the game would wait for the other forever
			mutex.acquire();
			filesRead++;
			mutex.release();
		});
	}

	/**
	 * The images of a character, as they're asked for (its spritesheets, or the first spritemap of its texture atlas).
	 */
	public static function characterImages(char:String):Array<String>
	{
		var images:Array<String> = [];
		if(char == null || char.length < 1) return images;
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = PolymodCompat.getCharacterFile(char, false);
			if(character == null && !FileSystem.exists(path)) character = PolymodCompat.getBaseCharacterFile(char, false);
			if(character == null) character = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end

			var img:String = Std.string(character.image).trim();
			#if flxanimate
			var animToFind:String = Paths.getPath('images/$img/Animation.json', TEXT);
			if(#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			{
				for (i in 0...10)
				{
					var spritemap:String = '$img/spritemap' + ((i == 0) ? '' : '$i');
					if(Paths.fileExists('images/$spritemap.png', IMAGE))
					{
						images.push(spritemap);
						break;
					}
				}
				return images;
			}
			#end
			for (file in img.split(','))
				images.push(file.trim());
		}
		catch(e:Dynamic) {}
		return images;
	}

	inline private static function preloadCharacter(char:String, ?prefixVocals:String)
	{
		if(char == null || char.length < 1) return; //(a song without that character)
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			// characters of V-Slice mods have their file somewhere else, without this their images were left for the song itself to load
			var character:Dynamic = PolymodCompat.getCharacterFile(char, false);
			if(character == null && !FileSystem.exists(path)) character = PolymodCompat.getBaseCharacterFile(char, false);
			if(character == null) character = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end

			var isAnimateAtlas:Bool = false;
			var img:String = character.image;
			img = img.trim();
			#if flxanimate
			var animToFind:String = Paths.getPath('images/$img/Animation.json', TEXT);
			if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
				isAnimateAtlas = true;
			#end

			if(!isAnimateAtlas)
			{
				var split:Array<String> = img.split(',');
				// the other characters are being read by other threads at the same time
				mutex.acquire();
				for (file in split)
				{
					imagesToPrepare.push(file.trim());
				}
				mutex.release();
			}
			#if flxanimate
			else
			{
				for (i in 0...10)
				{
					var st:String = '$i';
					if(i == 0) st = '';
	
					if(Paths.fileExists('images/$img/spritemap$st.png', IMAGE))
					{
						//trace('found Sprite PNG');
						mutex.acquire();
						imagesToPrepare.push('$img/spritemap$st');
						mutex.release();
						break;
					}
				}
			}
			#end
	
			if (prefixVocals != null && character.vocals_file != null && character.vocals_file.length > 0
				&& Paths.fileExists(prefixVocals + '-' + character.vocals_file + '.' + Paths.SOUND_EXT, SOUND, false, 'songs')) //(a song without it uses the usual tracks)
			{
				mutex.acquire();
				songsToPrepare.push(prefixVocals + "-" + character.vocals_file);
				mutex.release();
				if(char == PlayState.SONG.player1) dontPreloadDefaultVoices = true;
			}
		}
		catch(e:haxe.Exception)
		{
			trace(e.details());
		}
	}

	// On a loading thread: reads a sound's file, the game's thread makes the sound out of it (see `readFiles`)
	static function preloadSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true):Dynamic
	{
		var file:String = Paths.getPath(Language.getFileTranslation(key) + '.${Paths.SOUND_EXT}', SOUND, path, modsAllowed);

		//trace('precaching sound: $file');
		if(!Paths.currentTrackedSounds.exists(file))
		{
			#if sys
			if (FileSystem.exists(file))
			{
				addReadFile({file: file, key: file, bytes: sys.io.File.getBytes(file), isSound: true});
				return true;
			}
			#end
			if (OpenFlAssets.exists(file, SOUND))
			{
				addReadFile({file: file, key: file, bytes: null, isSound: true});
				return true;
			}
			if (beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				return null;
			}
			return true;
		}
		addReadFile({file: file, key: file, bytes: null, isSound: true}); //(already loaded: only kept for this song)
		return true;
	}

	static function addReadFile(item:ReadFile):Void
	{
		mutex.acquire();
		readFiles.push(item);
		mutex.release();
	}

	// On a loading thread: reads an image's file, the game's thread makes the image out of it (see `readFiles`)
	static function preloadGraphic(key:String):Dynamic
	{
		try {
			var requestKey:String = 'images/$key';
			#if TRANSLATIONS_ALLOWED requestKey = Language.getFileTranslation(requestKey); #end
			if(requestKey.lastIndexOf('.') < 0) requestKey += '.png';

			if (!Paths.currentTrackedAssets.exists(requestKey))
			{
				var file:String = Paths.getPath(requestKey, IMAGE);
				#if sys
				if (FileSystem.exists(file))
				{
					// read here into pixels when possible: it's most of the time an image takes, and lime can't do it on this thread
					var bytes:haxe.io.Bytes = sys.io.File.getBytes(file);
					var png:backend.PngDecoder.PngPixels = backend.PngDecoder.decode(bytes);
					addReadFile({file: file, key: requestKey, bytes: (png == null) ? bytes : null, png: png, isSound: false});
					return true;
				}
				#end
				if (OpenFlAssets.exists(file, IMAGE))
				{
					addReadFile({file: file, key: requestKey, bytes: null, png: null, isSound: false});
					return true;
				}
				trace('no such image $key exists');
				return null;
			}
			return true;
		}
		catch(e:haxe.Exception)
		{
			trace('ERROR! fail on preloading image $key');
		}

		return null;
	}
	
	#if cpp
	@:functionCode('
		return std::thread::hardware_concurrency();
    	')
	@:noCompletion
    	public static function getCPUThreadsCount():Int
    	{
        	return -1;
    	}
    	#end
}

// A file a loading thread read, for the game's thread to turn into an image or a sound (`bytes` is null for the game's own assets)
typedef ReadFile = {file:String, key:String, bytes:haxe.io.Bytes, ?png:backend.PngDecoder.PngPixels, isSound:Bool};
