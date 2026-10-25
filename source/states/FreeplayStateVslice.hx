package states;

import backend.FreeplayData;
import backend.Highscore;
import backend.PlayableCharacters;
import backend.Song;
import backend.SoundLoader;
import backend.VSliceConvert;
import backend.WeekData;

import flixel.tweens.FlxEase.EaseFunction;
import flixel.util.FlxDestroyUtil;

import objects.MusicPlayer;
import objects.freeplay.ExitMovers;
import objects.freeplay.FreeplayAlbumRoll;
import objects.freeplay.FreeplayBackingCard;
import objects.freeplay.FreeplayCapsule;
import objects.freeplay.FreeplayDJ;
import objects.freeplay.FreeplayDisplays;
import objects.freeplay.FreeplayLetterSort;
import objects.freeplay.FreeplaySong;

import openfl.display.BlendMode;
import openfl.filters.ShaderFilter;

import options.GameplayChangersSubstate;

import shaders.FreeplayShaders;

import substates.ResetScoreSubState;

import haxe.Json;

enum FreeplayUIState
{
	Entering; //Everything is still sliding in
	Idle;
	Interacting; //Something that can't be interrupted is playing
	Exiting;
}

/**
 * Freeplay menu made after the V-Slice one.
 *
 * - Only the songs of the player picked on Character Select (TAB) are listed, see `FreeplaySong` for which ones those are.
 * - The difficulty is the same for the whole list (left and right), only the songs that have it are shown.
 * - Q and E go through the letters to only show the songs starting with them, the favorite ones (F) or all of them.
 * - Who's on the turntable, the card behind it and the look of the menu come from the player's file, see `FreeplayDJ` and `FreeplayData`.
 */
class FreeplayStateVslice extends MusicBeatState
{
	/**
	 * Set by the game over screen, the DJ reacts to it.
	 */
	public static var playerDied:Bool = false;

	/**
	 * Set by Character Select when coming back from it, so the menu comes down from above instead of doing its intro.
	 */
	public static var fromCharSelect:Bool = false;

	/**
	 * The player picked on Character Select (V-Slice remembers it here, for the menus that open Freeplay with it).
	 */
	public static var rememberedCharacterId(get, set):String;
	static function get_rememberedCharacterId():String
	{
		var player = backend.PlayableCharacters.getCurrent();
		return (player != null) ? player.id : 'bf';
	}
	static function set_rememberedCharacterId(value:String):String
	{
		backend.PlayableCharacters.select(value);
		return value;
	}

	// Values V-Slice scripts place their things by. They're about screens wider than the game's (phones), which the engine never has
	public static var CUTOUT_WIDTH:Float = 0;
	public static var DJ_POS_MULTI:Float = 0.44;

	// What the menu was on the last time it was open
	static var rememberedSong:String = null; //null for "Random"
	static var rememberedDifficulty:String = null;

	// The song that was started from here, to know if its rank got better when coming back
	static var playedSong:String = null;
	static var playedDifficulty:String = null;
	static var playedRank:Null<FreeplayRank> = null;

	// Capsules kept above and below the selected song, anything further is off screen
	static inline final WINDOW_BEFORE:Int = 3;
	static inline final WINDOW_AFTER:Int = 7;

	static inline final PREVIEW_DELAY:Float = 0.4;
	static inline final PREVIEW_VOLUME:Float = 0.7;

	var uiState:FreeplayUIState = Entering;

	var curPlayer:PlayableCharacter;
	var style:FreeplayStyle;

	var songs:Array<FreeplaySong> = []; //Every song of the player
	var filteredSongs:Array<FreeplaySong> = []; //The ones being listed, the first is always null: "Random"
	var curSelected:Int = 0;
	var currentFilter:String = 'ALL';

	var allDifficulties:Array<String> = [];
	var difficultyNames:Map<String, String> = [];
	var difficultyMods:Map<String, String> = [];
	var currentDifficulty:String = 'normal';
	var difficultyBusy:Bool = false;

	var intendedScore:Int = 0;
	var lerpScore:Float = 0;
	var intendedCompletion:Float = 0;
	var lerpCompletion:Float = 0;

	// Interface, from back to front
	var backingCard:FreeplayBackingCard;
	var dj:FreeplayDJ = null;
	var blackOverlay:FlxSprite;
	var grpDifficulties:FlxTypedGroup<DifficultySprite>;
	var difficultyDots:FlxTypedGroup<DifficultyDot>;
	var backingImage:FlxSprite;
	var angleMaskShader:AngleMask = null;
	var rankBg:FlxSprite;
	var grpCapsules:FlxTypedGroup<FreeplayCapsule>;
	var capsules:Map<Int, FreeplayCapsule> = []; //By their position on the list
	var albumRoll:FreeplayAlbumRoll;
	var fnfHighscoreSpr:FlxSprite;
	var fpScoreDisplay:FreeplayScore;
	var clearBoxSprite:FlxSprite;
	var txtCompletion:FreeplayClearText;
	var letterSort:FreeplayLetterSort;
	var diffSelLeft:DifficultySelector;
	var diffSelRight:DifficultySelector;
	var overhangStuff:FlxSprite;
	var freeplayTxtBg:FlxSprite;
	var topLeftCornerText:FlxText;
	var ostName:FlxText;
	var charSelectHint:FlxText = null;
	var rankVignette:FlxSprite;
	var sparks:FlxSprite = null;
	var sparksADD:FlxSprite = null;

	var bottomBG:FlxSprite;
	var bottomText:FlxText;
	var bottomString:String;
	var missingTextBG:FlxSprite;
	var missingText:FlxText;
	var player:MusicPlayer;

	var rankCamera:FlxCamera;
	var fadeShader:BlueFade = null;
	var blurShader:GaussianBlurShader;
	var strokeShader:StrokeShader = null;

	var exitMovers:ExitMoverData = new Map();
	var exitMoversCharSel:ExitMoverData = new Map();

	var introDone:Bool = false;
	var enteredFromCharSelect:Bool = false;
	var prepForNewRank:Bool = false;
	var newRank:Null<FreeplayRank> = null;
	var diedOnSong:Bool = false;
	var stopMusicPlay:Bool = false;
	var instPlaying:Int = -1;

	var previewTimer:FlxTimer = new FlxTimer();
	var curPreview:String = null;
	var lastPreviewInst:openfl.media.Sound = null;

	// The instrumental of the song the menu stopped on is read by another thread (see backend.SoundLoader), starting a bit before it's time to play it
	static inline final PRELOAD_DELAY:Float = 0.15;
	var preloadTimer:FlxTimer = new FlxTimer();
	var loadingPreview:String = null; //the preview that was asked for, it may be there already
	var loadingPreviewId:Int = 0;
	var loadedPreview:openfl.media.Sound = null;
	var previewLoaded:Bool = false;
	var playWhenLoaded:Bool = false;

	// what the song player is waiting for
	var playerLoads:Array<Int> = null;

	var currentSong(get, never):FreeplaySong;
	inline function get_currentSong():FreeplaySong
		return filteredSongs[curSelected];

	var currentCapsule(get, never):FreeplayCapsule;
	inline function get_currentCapsule():FreeplayCapsule
		return capsules.get(curSelected);

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		// done here instead of on super.create(), which would replace the cameras after the sprites were given theirs
		initPsychCamera();

		// The menu has its own way of coming in
		FlxTransitionableState.skipNextTransOut = true;

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);
		FreeplayData.clearCache();

		#if HSCRIPT_ALLOWED
		// The scripts of V-Slice mods: their modules, and what they have for the players, the card and the DJ
		backend.VSliceScripts.startMenu(this, true, true);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the FreePlay", null);
		#end

		enteredFromCharSelect = fromCharSelect;
		fromCharSelect = false;
		diedOnSong = playerDied;
		playerDied = false;

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));

			if(FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
			return;
		}

		curPlayer = PlayableCharacters.getCurrent();
		style = FreeplayData.getStyle(curPlayer);

		loadSongs();
		checkPlayedSong();

		blurShader = new GaussianBlurShader(1);

		// A camera above the menu's own, for what has to stay still while the menu shakes and zooms
		rankCamera = new FlxCamera();
		rankCamera.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(rankCamera, false);

		createCard();
		createDifficulties();
		createSongArea();
		createTopBar();
		createOverlays();

		applyExitMovers();

		generateSongList(currentFilter, true, false, enteredFromCharSelect);

		if(prepForNewRank) rankCamera.fade(FlxColor.BLACK, 0.001, false, null, true);

		if(enteredFromCharSelect) enterFromCharSel();
		if(enteredFromCharSelect || dj == null) onDJIntroDone();
		else dj.onIntroDone.add(onDJIntroDone);

		super.create();

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.menuOpened(this);
		#end
	}

	// Tells the scripts of V-Slice mods about something that happened on the menu: the modules, and the ones of the card and the DJ
	function dispatchEvent(event:funkin.modding.events.ScriptEvent):Void
	{
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.dispatchToMenu(event, [backingCard, dj]);
		#end
	}

	inline function dispatchCapsuleEvent(type:String):Void
	{
		#if HSCRIPT_ALLOWED
		var song:FreeplaySong = currentSong;
		var variation:String = 'default';
		#if MODS_ALLOWED
		if(song != null && song.variation != null && song.variation.id != null) variation = song.variation.id;
		#end
		dispatchEvent(new funkin.modding.events.ScriptEvent.CapsuleScriptEvent(type, currentCapsule, currentDifficulty, variation));
		#end
	}

	// ------------------------------------------------------------------------------------------
	// Songs
	// ------------------------------------------------------------------------------------------

	function loadSongs():Void
	{
		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);
			for (weekSong in leWeek.songs)
			{
				var song:FreeplaySong = FreeplaySong.make(weekSong[0], weekSong[1], i, leWeek, curPlayer);
				if(song != null) songs.push(song);
			}
		}
		Mods.loadTopMod();

		// Every difficulty the songs have, the menu goes through all of them
		var found:Array<String> = [];
		for (song in songs)
		{
			for (i => id in song.getDifficultyIds())
			{
				if(found.contains(id)) continue;

				found.push(id);
				difficultyNames.set(id, song.difficulties[i]);
				difficultyMods.set(id, song.folder);
			}
		}

		if(found.length < 1)
		{
			for (diff in Difficulty.defaultList)
			{
				var id:String = Paths.formatToSongPath(diff);
				found.push(id);
				difficultyNames.set(id, diff);
			}
		}
		allDifficulties = VSliceConvert.sortDifficulties(found);

		var defaultId:String = Paths.formatToSongPath(Difficulty.getDefault());
		if(rememberedDifficulty != null && allDifficulties.contains(rememberedDifficulty)) currentDifficulty = rememberedDifficulty;
		else currentDifficulty = allDifficulties.contains(defaultId) ? defaultId : allDifficulties[0];
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	// Coming back from a song that was started here: a better rank than before gets celebrated
	function checkPlayedSong():Void
	{
		var song:String = playedSong;
		var difficulty:String = playedDifficulty;
		var rankBefore:Null<FreeplayRank> = playedRank;
		playedSong = null;
		playedDifficulty = null;
		playedRank = null;

		if(song == null || difficulty == null || diedOnSong) return;

		var played:FreeplaySong = null;
		for (curSong in songs)
		{
			if(curSong.favoriteKey != song) continue;

			played = curSong;
			break;
		}
		if(played == null || !played.hasDifficulty(difficulty) || !allDifficulties.contains(difficulty)) return;

		newRank = played.getRank(difficulty);
		if(newRank == null) return;
		if(rankBefore != null && (newRank : Int) <= (rankBefore : Int)) return;

		playedRank = rankBefore; //read again by the animation
		prepForNewRank = true;
		rememberedSong = song;
		currentDifficulty = rememberedDifficulty = difficulty;
	}

	/**
	 * Lists the songs again for the current filter and difficulty.
	 *
	 * @param force 			The names of the songs show up along with their capsules instead of a moment later.
	 * @param onlyIfChanged 	Leaves the list alone if it ends up with the same songs, only making them jump in again.
	 * @param noJumpIn 			The capsules go straight to their places.
	 */
	function generateSongList(filter:String, force:Bool = false, onlyIfChanged:Bool = true, noJumpIn:Bool = false):Void
	{
		var list:Array<FreeplaySong> = [null];
		for (song in filterSongs(filter))
			if(song.hasDifficulty(currentDifficulty))
				list.push(song);

		if(onlyIfChanged && isSameList(list, filteredSongs))
		{
			if(!noJumpIn)
			{
				for (capsule in capsules)
				{
					capsule.setPosition(FlxG.width, 0);
					capsule.initJumpIn(force);
				}
			}
			return;
		}

		currentFilter = filter;
		filteredSongs = list;

		// goes back to the song it was on, if it's still there
		curSelected = 0;
		if(rememberedSong != null)
		{
			for (i in 1...filteredSongs.length)
			{
				if(filteredSongs[i].favoriteKey != rememberedSong) continue;

				curSelected = i;
				break;
			}
		}

		for (capsule in capsules)
			capsule.kill();
		capsules.clear();

		var first:Int = Std.int(Math.max(0, curSelected - WINDOW_BEFORE));
		var last:Int = Std.int(Math.min(filteredSongs.length - 1, curSelected + WINDOW_AFTER));
		for (index in first...last + 1)
		{
			var capsule:FreeplayCapsule = spawnCapsule(index);
			var position:FlxPoint = getCapsulePosition(index + 1 - curSelected);
			capsule.targetPos.set(position.x, position.y);

			if(noJumpIn) capsule.forcePosition();
			else
			{
				capsule.setPosition(FlxG.width, position.y + 10);
				capsule.initJumpIn(force);
			}
		}

		changeSelection();
	}

	function filterSongs(filter:String):Array<FreeplaySong>
	{
		switch(filter)
		{
			case null, 'ALL':
				return songs;

			case 'fav':
				return songs.filter((song) -> song.isFavorite());

			default:
				// "A-C" turns into everything that starts with a letter from A to C
				var regex:EReg = new EReg('^[' + ((filter == '#') ? '0-9' : filter) + '].*', 'i');
				var found:Array<FreeplaySong> = songs.filter((song) -> regex.match(song.name));
				found.sort((a, b) -> compareNames(a.name, b.name));
				return found;
		}
	}

	static function compareNames(a:String, b:String):Int
	{
		a = a.toUpperCase();
		b = b.toUpperCase();
		return (a < b) ? -1 : ((a > b) ? 1 : 0);
	}

	static function isSameList(a:Array<FreeplaySong>, b:Array<FreeplaySong>):Bool
	{
		if(a.length != b.length) return false;

		for (song in a)
			if(!b.contains(song))
				return false;
		return true;
	}

	// ------------------------------------------------------------------------------------------
	// Capsules
	// ------------------------------------------------------------------------------------------

	function spawnCapsule(index:Int):FreeplayCapsule
	{
		var capsule:FreeplayCapsule = grpCapsules.getFirstDead();
		if(capsule != null) capsule.revive();
		else
		{
			capsule = FreeplayData.withMod(curPlayer.mod, () -> new FreeplayCapsule(style, ClientPrefs.data.shaders ? blurShader : null));
			grpCapsules.add(capsule);
		}

		var song:FreeplaySong = filteredSongs[index];
		if(song != null) song.refresh(currentDifficulty);

		capsule.cameras = [FlxG.camera];
		capsule.curSelected = curSelected;
		capsule.init(song, index, currentDifficulty);
		capsules.set(index, capsule);
		return capsule;
	}

	var _capsulePosition:FlxPoint = new FlxPoint();

	/**
	 * Where a capsule goes, by how far it is from the selected one (which is 1, the one right above the selected is 0).
	 * The point it returns is always the same one, it has to be used right away.
	 */
	function getCapsulePosition(relativeIndex:Float):FlxPoint
	{
		// the ones leaving through the top go a bit further, to be gone for sure
		var yOffset:Float = 0;
		if(relativeIndex < 0) yOffset = 150;
		else if(relativeIndex > 4) yOffset = -10;

		return _capsulePosition.set(FreeplayCapsule.intendedX(relativeIndex), (relativeIndex * ((132 * FreeplayCapsule.REAL_SCALE) + 10)) + 120 - yOffset);
	}

	function changeSelection(change:Int = 0):Void
	{
		var prevSelected:Int = curSelected;
		var total:Int = filteredSongs.length;

		curSelected += change;
		if(curSelected < 0) curSelected = total - 1;
		if(curSelected >= total) curSelected = 0;

		if(change != 0 && prepForNewRank) prepForNewRank = false;
		if(!prepForNewRank && curSelected != prevSelected) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var song:FreeplaySong = currentSong;
		rememberedSong = (song != null) ? song.favoriteKey : null;

		// Capsules that went too far give their place to the ones getting close
		var first:Int = Std.int(Math.max(0, curSelected - WINDOW_BEFORE));
		var last:Int = Std.int(Math.min(total - 1, curSelected + WINDOW_AFTER));
		for (index in [for (key in capsules.keys()) key])
		{
			if(index >= first && index <= last) continue;

			capsules.get(index).kill();
			capsules.remove(index);
		}

		for (index in first...last + 1)
		{
			if(capsules.exists(index)) continue;

			// starts from where it would have been before the list moved, right outside of the screen
			var capsule:FreeplayCapsule = spawnCapsule(index);
			var from:FlxPoint = getCapsulePosition(FlxMath.bound(index + 1 - prevSelected, 1 - WINDOW_BEFORE - 1, 1 + WINDOW_AFTER + 1));
			capsule.targetPos.set(from.x, from.y);
			capsule.forcePosition();
		}

		for (index => capsule in capsules)
		{
			capsule.curSelected = curSelected;
			capsule.selected = (index == curSelected);

			var position:FlxPoint = getCapsulePosition(index + 1 - curSelected);
			capsule.targetPos.set(position.x, position.y);
		}

		updateSelectionInfo();

		if(total > 0 && !prepForNewRank && uiState == Idle) queuePreview();
		if(curSelected != prevSelected) dispatchCapsuleEvent(funkin.modding.events.ScriptEventType.CAPSULE_SELECTED);
	}

	// Score, album, stars and dots of the selected song
	function updateSelectionInfo(skipAlbumIntro:Bool = true):Void
	{
		var song:FreeplaySong = currentSong;
		if(song != null)
		{
			song.refresh(currentDifficulty);
			intendedScore = song.getScore(currentDifficulty);
			intendedCompletion = song.getClear(currentDifficulty);
		}
		else
		{
			intendedScore = 0;
			intendedCompletion = 0;
		}

		if(introDone)
		{
			var newAlbum:String = (song != null) ? song.album : null;
			if(albumRoll.albumId != newAlbum || newAlbum == null)
			{
				FreeplayData.withMod((song != null) ? song.folder : null, function()
				{
					albumRoll.albumId = newAlbum;
					return null;
				});
				if(skipAlbumIntro) albumRoll.skipIntro();
			}
			albumRoll.setDifficultyStars((song != null) ? song.rating : 0);
			updateOSTName();
		}

		var index:Int = allDifficulties.indexOf(currentDifficulty);
		refreshDots(index, index);

		missingText.visible = false;
		missingTextBG.visible = false;
	}

	// ------------------------------------------------------------------------------------------
	// Interface
	// ------------------------------------------------------------------------------------------

	function createCard():Void
	{
		backingCard = FreeplayData.withMod(curPlayer.mod, () -> FreeplayBackingCard.make(curPlayer));
		backingCard.tintBacking = tintBacking;
		backingCard.instance = this;
		add(backingCard);
		backingCard.create();

		if(curPlayer.freeplayDJ != null)
		{
			#if HSCRIPT_ALLOWED
			// the DJ a script of the player's mod makes, when its file asks for one
			var scriptClass:String = VSliceConvert.str(curPlayer.freeplayDJ.scriptClass, '').trim();
			if(scriptClass.length > 0) dj = backend.VSliceScripts.makeFreeplayDJ(scriptClass, curPlayer.id);
			if(dj != null && !dj.loaded) dj = FlxDestroyUtil.destroy(dj);
			#end

			if(dj == null) dj = FreeplayData.withMod(curPlayer.mod, () -> new FreeplayDJ(curPlayer));
			if(dj != null && !dj.loaded) dj = FlxDestroyUtil.destroy(dj);
			if(dj != null) add(dj);
		}

		var bgAsset:String = FreeplayData.withMod(curPlayer.mod, () -> Paths.fileExists('images/${style.bgAsset}.png', IMAGE) ? style.bgAsset : 'freeplay/freeplayBGweek1-bf');
		backingImage = new FlxSprite(backingCard.pinkBack.width * 0.74, 0);
		backingImage.loadGraphic(FreeplayData.withMod(curPlayer.mod, () -> Paths.image(bgAsset)));
		backingImage.antialiasing = ClientPrefs.data.antialiasing;
		backingImage.visible = false;

		// hides what goes behind the image until it shows up
		blackOverlay = new FlxSprite(FlxG.width).makeGraphic(Std.int(backingImage.width), Std.int(backingImage.height), FlxColor.BLACK);
		add(blackOverlay);

		// same texture size on both, so the shader cuts them at the same angle
		backingImage.setGraphicSize(0, FlxG.height + 1);
		blackOverlay.setGraphicSize(0, FlxG.height + 1);
		backingImage.updateHitbox();
		blackOverlay.updateHitbox();

		// (made even with the shaders turned off: the cards scripts make give it the image's color without asking)
		angleMaskShader = new AngleMask();
		if(ClientPrefs.data.shaders)
		{
			backingImage.shader = angleMaskShader;
			blackOverlay.shader = angleMaskShader;
		}

		if(enteredFromCharSelect)
		{
			blackOverlay.visible = false;
			backingCard.skipIntroTween();
		}
		else FlxTween.tween(blackOverlay, {x: backingImage.x}, 0.7, {ease: FlxEase.quintOut});
	}

	function tintBacking(duration:Float, from:FlxColor, to:FlxColor, ?ease:EaseFunction):Void
	{
		FlxTween.color(backingImage, duration, from, to, {
			ease: ease,
			onUpdate: function(_)
			{
				if(angleMaskShader != null) angleMaskShader.extraColor = backingImage.color;
			}
		});
	}

	function createDifficulties():Void
	{
		grpDifficulties = new FlxTypedGroup<DifficultySprite>();
		add(grpDifficulties);

		difficultyDots = new FlxTypedGroup<DifficultyDot>();
		add(difficultyDots);

		for (id in allDifficulties)
		{
			var sprite:DifficultySprite = FreeplayData.withMod(difficultyMods.get(id), () -> new DifficultySprite(id, difficultyNames.get(id)));
			sprite.setPosition(-300, 80);
			sprite.visible = (id == currentDifficulty);
			grpDifficulties.add(sprite);

			difficultyDots.add(new DifficultyDot(id));
		}

		add(backingImage);
	}

	function createSongArea():Void
	{
		rankBg = new FlxSprite().makeGraphic(1, 1, 0xD3000000);
		rankBg.scale.set(FlxG.width, FlxG.height);
		rankBg.updateHitbox();
		rankBg.cameras = [rankCamera];
		rankBg.alpha = 0;
		add(rankBg);

		grpCapsules = new FlxTypedGroup<FreeplayCapsule>();
		add(grpCapsules);

		albumRoll = new FreeplayAlbumRoll();
		albumRoll.albumId = null;
		albumRoll.visible = false;
		add(albumRoll);
	}

	function createTopBar():Void
	{
		var antialias:Bool = ClientPrefs.data.antialiasing;

		fnfHighscoreSpr = new FlxSprite(FlxG.width - 420, 70);
		fnfHighscoreSpr.frames = Paths.getSparrowAtlas('freeplay/highscore');
		fnfHighscoreSpr.animation.addByPrefix('highscore', 'highscore small instance 1', 24, false);
		fnfHighscoreSpr.antialiasing = antialias;
		fnfHighscoreSpr.visible = false;
		add(fnfHighscoreSpr);

		// it shines every now and then
		new FlxTimer().start(FlxG.random.float(12, 50), function(timer:FlxTimer)
		{
			fnfHighscoreSpr.animation.play('highscore');
			timer.time = FlxG.random.float(20, 60);
		}, 0);

		fpScoreDisplay = FreeplayData.withMod(curPlayer.mod, () -> new FreeplayScore(FlxG.width - 353, 120, 7, style));
		fpScoreDisplay.visible = false;
		add(fpScoreDisplay);

		clearBoxSprite = new FlxSprite(FlxG.width - 115, 65).loadGraphic(Paths.image('freeplay/clearBox'));
		clearBoxSprite.antialiasing = antialias;
		clearBoxSprite.visible = false;
		add(clearBoxSprite);

		txtCompletion = new FreeplayClearText(FlxG.width - 95, 87);
		txtCompletion.visible = false;
		add(txtCompletion);

		letterSort = new FreeplayLetterSort(400, 75);
		letterSort.visible = false;
		letterSort.changeSelectionCallback = onLetterChanged;
		add(letterSort);

		diffSelLeft = FreeplayData.withMod(curPlayer.mod, () -> new DifficultySelector(20, 70, false, style));
		diffSelRight = FreeplayData.withMod(curPlayer.mod, () -> new DifficultySelector(325, 70, true, style));
		diffSelLeft.visible = false;
		diffSelRight.visible = false;
		add(diffSelLeft);
		add(diffSelRight);

		overhangStuff = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		overhangStuff.scale.set(FlxG.width, 164);
		overhangStuff.updateHitbox();
		overhangStuff.y = -164;
		add(overhangStuff);

		topLeftCornerText = new FlxText(8, 8, 0, 'FREEPLAY', 48);
		topLeftCornerText.font = Paths.font('vcr.ttf');
		topLeftCornerText.antialiasing = antialias;
		topLeftCornerText.visible = false;

		freeplayTxtBg = new FlxSprite().makeGraphic(Math.round(topLeftCornerText.width + 16), Math.round(topLeftCornerText.height + 16), FlxColor.BLACK);
		freeplayTxtBg.x = topLeftCornerText.x - 8;
		freeplayTxtBg.visible = false;
		add(freeplayTxtBg);
		add(topLeftCornerText);

		ostName = new FlxText(8, 8, FlxG.width - 16, 'OFFICIAL OST', 48);
		ostName.font = Paths.font('vcr.ttf');
		ostName.alignment = RIGHT;
		ostName.antialiasing = antialias;
		ostName.visible = false;
		add(ostName);

		// both texts flash with an outline when they show up
		if(ClientPrefs.data.shaders)
		{
			strokeShader = new StrokeShader(0xFFFFFFFF, 2, 2);
			topLeftCornerText.shader = strokeShader;
			ostName.shader = strokeShader;
		}

		if(PlayableCharacters.countUnlocked() > 1)
		{
			charSelectHint = new FlxText(-40, 18, FlxG.width - 16, Language.getPhrase('freeplay_char_select_hint', 'Press [ TAB ] to change characters'), 32);
			charSelectHint.font = Paths.font('5by7.ttf');
			charSelectHint.alignment = CENTER;
			charSelectHint.color = 0xFF5F5F5F;
			charSelectHint.antialiasing = antialias;
			add(charSelectHint);
		}

		if(enteredFromCharSelect) overhangStuff.y = -100;
		else
		{
			FlxTween.tween(overhangStuff, {y: -100}, 0.3, {ease: FlxEase.quartOut});
			if(charSelectHint != null)
			{
				charSelectHint.y -= 100;
				FlxTween.tween(charSelectHint, {y: charSelectHint.y + 100}, 0.8, {ease: FlxEase.quartOut});
			}
		}
	}

	function createOverlays():Void
	{
		rankVignette = new FlxSprite().loadGraphic(Paths.image('freeplay/rankVignette'));
		rankVignette.scale.set(2, 2);
		rankVignette.updateHitbox();
		rankVignette.blend = BlendMode.ADD;
		rankVignette.alpha = 0;
		add(rankVignette);

		// Things the V-Slice menu doesn't have: Psych's keys, the chart errors and the song player
		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		bottomString = Language.getPhrase('freeplay_vslice_tip', 'SPACE: Listen to the Song / CTRL: Gameplay Changers / RESET: Reset Score / Q and E: Sort by Letter / F: Favorite');
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, bottomString, 16);
		bottomText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		add(bottomText);

		if(!enteredFromCharSelect)
		{
			bottomBG.y += 30;
			bottomText.y += 30;
			FlxTween.tween(bottomBG, {y: bottomBG.y - 30}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.5});
			FlxTween.tween(bottomText, {y: bottomText.y - 30}, 0.5, {ease: FlxEase.quartOut, startDelay: 0.5});
		}

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.visible = false;
		add(missingText);

		player = new MusicPlayer(this);
		add(player);
	}

	function applyExitMovers():Void
	{
		backingCard.applyExitMovers(exitMovers, exitMoversCharSel);
		albumRoll.applyExitMovers(exitMovers, exitMoversCharSel);

		if(dj != null)
		{
			exitMovers.set([dj], {x: dj.x - 640, speed: 0.5});
			exitMoversCharSel.set([dj], {y: -175, speed: 0.8, wait: 0.1});
		}

		exitMovers.set([blackOverlay, backingImage], {x: FlxG.width * 1.5, speed: 0.4, wait: 0});
		exitMoversCharSel.set([blackOverlay, backingImage], {y: -100, speed: 0.8, wait: 0.1});

		var difficulties:Array<FlxSprite> = [for (sprite in grpDifficulties.members) (sprite : FlxSprite)];
		exitMovers.set(difficulties, {x: -300, speed: 0.25, wait: 0});
		exitMoversCharSel.set(difficulties, {y: -270, speed: 0.8, wait: 0.1});

		var topBar:Array<FlxSprite> = [overhangStuff, topLeftCornerText, ostName, freeplayTxtBg];
		if(charSelectHint != null) topBar.push(charSelectHint);
		exitMovers.set(topBar, {y: -164, speed: 0.2, wait: 0});
		exitMoversCharSel.set(topBar, {y: -300, speed: 0.8, wait: 0.1});

		exitMovers.set([letterSort], {y: -100, speed: 0.3});
		exitMoversCharSel.set([letterSort], {y: -270, speed: 0.8, wait: 0.1});

		// the score is a group that starts at 0, 0: this slides all of it out by the screen's width
		exitMovers.set([fpScoreDisplay], {x: FlxG.width, speed: 0.3});
		exitMovers.set([fnfHighscoreSpr, clearBoxSprite], {x: FlxG.width, speed: 0.3});
		exitMovers.set([txtCompletion], {x: FlxG.width * 1.05, speed: 0.315});
		exitMoversCharSel.set([fpScoreDisplay, txtCompletion, fnfHighscoreSpr, clearBoxSprite], {y: -270, speed: 0.8, wait: 0.1});

		exitMovers.set([diffSelLeft, diffSelRight], {x: -diffSelLeft.width * 2, speed: 0.26});
		exitMoversCharSel.set([diffSelLeft, diffSelRight], {y: -270, speed: 0.8, wait: 0.1});

		exitMovers.set([bottomBG, bottomText], {y: FlxG.height + 10, speed: 0.2});
	}

	// Everything else shows up when the DJ ends its intro
	function onDJIntroDone():Void
	{
		if(introDone) return;
		introDone = true;

		if(uiState == Entering && !enteredFromCharSelect) uiState = Idle;

		albumRoll.playIntro();

		if(!enteredFromCharSelect)
		{
			backingImage.color = FlxColor.BLACK;
			if(angleMaskShader != null) angleMaskShader.extraColor = FlxColor.BLACK;
			FlxTween.color(backingImage, 0.6, FlxColor.BLACK, FlxColor.WHITE, {
				ease: FlxEase.expoOut,
				onUpdate: function(_)
				{
					if(angleMaskShader != null) angleMaskShader.extraColor = backingImage.color;
				},
				onComplete: function(_) blackOverlay.visible = false
			});
		}
		backingImage.visible = true;

		for (sprite in grpDifficulties.members)
		{
			FlxTween.cancelTweensOf(sprite);
			FlxTween.tween(sprite, {x: 90}, 0.6, {ease: FlxEase.quartOut});
			sprite.y = 80;
			sprite.visible = (sprite.difficultyId == currentDifficulty);
		}

		diffSelLeft.visible = true;
		diffSelRight.visible = true;
		letterSort.visible = true;

		new FlxTimer().start(1 / 24, function(_)
		{
			fnfHighscoreSpr.visible = true;
			topLeftCornerText.visible = true;
			freeplayTxtBg.visible = true;
			ostName.visible = true;
			fpScoreDisplay.visible = true;
			clearBoxSprite.visible = true;
			txtCompletion.visible = true;
			if(player.playingMusic) setScoreVisible(false);

			lerpScore = 0;
			lerpCompletion = 0;

			new FlxTimer().start(1.5 / 24, function(_)
			{
				if(strokeShader != null) strokeShader.width = strokeShader.height = 0;
			});
		});

		backingCard.introDone();
		dispatchEvent(new funkin.modding.events.ScriptEvent.FreeplayScriptEvent(funkin.modding.events.ScriptEventType.FREEPLAY_INTRO));

		updateSelectionInfo(enteredFromCharSelect || prepForNewRank);

		if(prepForNewRank && currentCapsule != null && currentSong != null) rankAnimStart(currentCapsule);
		else
		{
			prepForNewRank = false;
			if(diedOnSong) playLossReaction();
			else if(!enteredFromCharSelect) queuePreview();
		}

		var index:Int = allDifficulties.indexOf(currentDifficulty);
		refreshDots(index, index);
		fadeDots(true);
	}

	function updateOSTName():Void
	{
		// songs from mods aren't from the game's soundtrack, unless they come with an album that says otherwise
		var song:FreeplaySong = currentSong;
		var newName:String = (song != null && song.folder.length > 0 && song.album == null) ? 'NOT OFFICIAL OST' : albumRoll.getOSTName();
		if(ostName.text == newName) return;

		ostName.text = newName;
		if(strokeShader == null) return;

		strokeShader.width = strokeShader.height = 2;
		new FlxTimer().start(1.5 / 24, function(_) strokeShader.width = strokeShader.height = 0);
	}

	function refreshDots(index:Int, prevIndex:Int):Void
	{
		var maxDotsPerRow:Int = 8;
		var distance:Float = 30;
		var count:Int = difficultyDots.length;

		// centered under the difficulty
		var startX:Float = 260 - 14.7 * (Math.min(count, maxDotsPerRow) - 1) - (distance * 5) / 2;
		var song:FreeplaySong = currentSong;

		for (i => dot in difficultyDots.members)
		{
			var type:DotType = (dot.difficultyId == 'erect' || dot.difficultyId == 'nightmare') ? ERECT : NORMAL;
			if(song != null && !song.hasDifficulty(dot.difficultyId)) type = INACTIVE;

			var state:DotState = (i == index) ? SELECTED : ((i == prevIndex) ? DESELECTING : DESELECTED);

			dot.setPosition(startX + distance * (i % maxDotsPerRow), 170 + distance * Math.floor(i / maxDotsPerRow));
			dot.updateState(type, state);
		}
	}

	function fadeDots(fadeIn:Bool):Void
	{
		for (dot in difficultyDots.members)
		{
			if(fadeIn) dot.fadeIn();
			else dot.fadeOut();
		}
	}

	/**
	 * Called by the song player, which shows its own things over the score.
	 */
	public function setScoreVisible(value:Bool):Void
	{
		if(!introDone) return;

		fnfHighscoreSpr.visible = value;
		fpScoreDisplay.visible = value;
		clearBoxSprite.visible = value;
		txtCompletion.visible = value;
		ostName.visible = value;
	}

	public function setTipText(?text:String):Void
	{
		bottomText.text = (text != null) ? text : bottomString;
	}

	public function getSelectedSongName():String
	{
		var song:FreeplaySong = currentSong;
		return (song != null) ? song.displayName : '';
	}

	// ------------------------------------------------------------------------------------------
	// Difficulty and letters
	// ------------------------------------------------------------------------------------------

	function changeDiff(change:Int):Void
	{
		if(change == 0 || allDifficulties.length < 2 || difficultyBusy) return;

		var prevIndex:Int = allDifficulties.indexOf(currentDifficulty);
		var newIndex:Int = FlxMath.wrap(prevIndex + change, 0, allDifficulties.length - 1);

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		(change > 0 ? diffSelRight : diffSelLeft).press();

		// The current one leaves through one side and the new one comes from the other
		difficultyBusy = true;
		var oldSprite:DifficultySprite = grpDifficulties.members[prevIndex];
		var newSprite:DifficultySprite = grpDifficulties.members[newIndex];

		FlxTween.cancelTweensOf(oldSprite);
		oldSprite.visible = true;
		FlxTween.tween(oldSprite, {x: (change > 0) ? -320 : 500}, 0.2, {
			ease: FlxEase.circInOut,
			onComplete: function(_)
			{
				difficultyBusy = false;
				oldSprite.x = 90;
				oldSprite.visible = false;
			}
		});

		FlxTween.cancelTweensOf(newSprite);
		newSprite.x = (change > 0) ? 500 : -320;
		newSprite.y = 85;
		newSprite.alpha = 0.5;
		FlxTween.tween(newSprite, {x: 90}, 0.2, {ease: FlxEase.circInOut});
		new FlxTimer().start(1 / 24, function(_)
		{
			newSprite.y = 80;
			newSprite.alpha = 1;
			newSprite.visible = true;
		});

		// The selected song might not have the new difficulty, the closest one that does gets selected instead
		var song:FreeplaySong = currentSong;
		currentDifficulty = allDifficulties[newIndex];
		rememberedDifficulty = currentDifficulty;
		dispatchCapsuleEvent(funkin.modding.events.ScriptEventType.DIFFICULTY_SWITCH);

		if(song != null && !song.hasDifficulty(currentDifficulty))
		{
			var closest:FreeplaySong = null;
			var closestDistance:Int = 0;
			for (i in 1...filteredSongs.length)
			{
				var distance:Int = Std.int(Math.abs(i - curSelected));
				if(!filteredSongs[i].hasDifficulty(currentDifficulty) || (closest != null && distance >= closestDistance)) continue;

				closest = filteredSongs[i];
				closestDistance = distance;
			}
			rememberedSong = (closest != null) ? closest.favoriteKey : null;
		}

		generateSongList(currentFilter, true, false);
		refreshDots(newIndex, prevIndex);
	}

	function onLetterChanged(filter:String):Void
	{
		if(grpCapsules == null) return;

		var song:FreeplaySong = currentSong;
		generateSongList(filter, true, false);

		// stays on the song it was on if it's still there, otherwise goes to the first one instead of to "Random"
		if(song != null && !filteredSongs.contains(song) && filteredSongs.length > 1)
		{
			curSelected = 1;
			changeSelection();
		}
	}

	// ------------------------------------------------------------------------------------------
	// Song preview
	// ------------------------------------------------------------------------------------------

	// The music only changes when the selection stays on a song for a moment, loading every song scrolled by would be too slow
	function queuePreview():Void
	{
		if(FlxG.sound.music != null && curPreview != getPreviewKey(currentSong))
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.pause();
		}
		previewTimer.start(PREVIEW_DELAY, function(_) playCurSongPreview());
		playWhenLoaded = false; //that was about another song, the timer above asks for it again

		// by the time it has to play it's usually loaded already
		preloadTimer.start(PRELOAD_DELAY, function(_)
		{
			if(!player.playingMusic && uiState != Exiting) requestPreview(currentSong);
		});
	}

	// Gives up on a preview that was being loaded
	function cancelPreviewLoad():Void
	{
		preloadTimer.cancel();
		SoundLoader.cancel(loadingPreviewId);

		// one that finished loading but never got to play isn't kept either
		if(loadedPreview != null && loadedPreview != lastPreviewInst) forgetSound(loadedPreview);

		loadingPreviewId = 0;
		loadingPreview = null;
		loadedPreview = null;
		previewLoaded = false;
		playWhenLoaded = false;
	}

	// Starts loading the audio of a song's preview, if that isn't what's being loaded (or what's already there)
	function requestPreview(song:FreeplaySong):Void
	{
		var key:String = getPreviewKey(song);
		if(key == loadingPreview) return;

		cancelPreviewLoad();
		loadingPreview = key;

		// the files are looked for now, with the song's mod, what comes later doesn't depend on it
		var file:String = null;
		if(song == null) file = SoundLoader.getFile('music/freeplayRandom');
		else file = FreeplayData.withMod(song.folder, () -> SoundLoader.getFile(getSongInstKey(song), 'songs'));

		loadingPreviewId = SoundLoader.load(file, function(sound:openfl.media.Sound)
		{
			if(key != loadingPreview) return;

			loadingPreviewId = 0;
			loadedPreview = sound;
			previewLoaded = true;
			if(playWhenLoaded) playCurSongPreview();
		}, true); //(played from its file: ready right away, a whole song isn't turned into audio for a few seconds of it)
	}

	function getPreviewKey(song:FreeplaySong):String
	{
		if(song == null) return 'random';

		#if MODS_ALLOWED
		if(song.vslice != null && song.variation != null) return song.favoriteKey + ':' + song.variation.id;
		#end
		return song.favoriteKey;
	}

	function playCurSongPreview():Void
	{
		if(player.playingMusic || uiState == Exiting) return;

		var song:FreeplaySong = currentSong;
		var volume:Float = PREVIEW_VOLUME * ((dj != null) ? dj.getMusicPreviewMult() : 1);

		var key:String = getPreviewKey(song);
		if(key == curPreview && FlxG.sound.music != null)
		{
			// still on the same song
			if(!FlxG.sound.music.playing) FlxG.sound.music.resume();
			FlxG.sound.music.fadeIn(1, FlxG.sound.music.volume, volume);
			return;
		}

		// Its audio is loaded without stopping the menu: if it isn't there yet this is called again when it is
		requestPreview(song);
		if(!previewLoaded)
		{
			playWhenLoaded = true;
			return;
		}
		playWhenLoaded = false;
		curPreview = key;

		var sound:openfl.media.Sound = loadedPreview;
		var startTime:Float = 0;
		var bpm:Float = 145;
		if(song != null)
		{
			startTime = song.previewStart;
			if(song.bpm > 0) bpm = song.bpm;
		}
		if(sound == null)
		{
			// no instrumental to play, at least the previous song doesn't stay there
			if(FlxG.sound.music != null) FlxG.sound.music.stop();
			return;
		}

		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.pitch = 1;
		}
		FlxG.sound.playMusic(sound, 0);
		if(startTime > 0 && startTime < FlxG.sound.music.length) FlxG.sound.music.time = startTime;
		FlxG.sound.music.fadeIn(2, 0, volume);

		// the card behind the DJ flashes to the song's beat
		Conductor.bpmChangeMap = [];
		Conductor.bpm = bpm;

		// a decoded instrumental takes tens of MBs of RAM, the ones that were scrolled by aren't kept
		if(lastPreviewInst != null && lastPreviewInst != sound) forgetSound(lastPreviewInst);
		lastPreviewInst = (song != null) ? sound : null;
	}

	// Takes a sound out of the ones the game keeps loaded, so its memory can be freed once nothing is playing it
	function forgetSound(sound:openfl.media.Sound):Void
	{
		for (cacheKey => cached in Paths.currentTrackedSounds)
		{
			if(cached != sound) continue;

			if(!Paths.dumpExclusions.contains(cacheKey))
			{
				Paths.currentTrackedSounds.remove(cacheKey);
				Paths.localTrackedAssets.remove(cacheKey);
			}
			break;
		}
	}

	// Where a song's instrumental is inside of the "songs" folder
	function getSongInstKey(song:FreeplaySong):String
	{
		#if MODS_ALLOWED
		// each variation of a V-Slice song can have its own instrumental
		if(song.vslice != null && song.variation != null)
			return PolymodCompat.getVariationInst(song.folder, song.vslice, song.variation);
		#end
		return '${Paths.formatToSongPath(song.name)}/Inst';
	}

	// ------------------------------------------------------------------------------------------
	// Input
	// ------------------------------------------------------------------------------------------

	var spamTimer:Float = 0;
	var spamming:Bool = false;
	var hintTimer:Float = 0;

	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1 || backingCard == null)
		{
			super.update(elapsed);
			return;
		}

		if(FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time;

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.menuUpdate(elapsed);
		#end

		lerpScoreDisplays(elapsed);

		if(charSelectHint != null)
		{
			hintTimer += elapsed * 2;
			charSelectHint.alpha = FlxMath.lerp(0.3, 0.9, (Math.sin(hintTimer) + 1) / 2);
		}

		if(player.playingMusic) handlePlayerInputs();
		else if(uiState == Idle) handleInputs(elapsed);

		super.update(elapsed);
	}

	function lerpScoreDisplays(elapsed:Float):Void
	{
		lerpScore = smoothLerp(lerpScore, intendedScore, elapsed, 0.2);
		if(Math.abs(lerpScore - intendedScore) <= 1) lerpScore = intendedScore;

		lerpCompletion = smoothLerp(lerpCompletion, intendedCompletion, elapsed, 0.5);
		if(Math.abs(lerpCompletion - intendedCompletion) <= 0.01) lerpCompletion = intendedCompletion;

		fpScoreDisplay.updateScore(Std.int(lerpScore));
		txtCompletion.setValue(Math.floor(lerpCompletion * 100));
	}

	// Gets within 1% of the target in `duration` seconds, no matter the framerate
	inline static function smoothLerp(base:Float, target:Float, elapsed:Float, duration:Float):Float
	{
		return (elapsed <= 0 || base == target) ? base : FlxMath.lerp(target, base, Math.pow(1 / 100, elapsed / duration));
	}

	function handleInputs(elapsed:Float):Void
	{
		if(FlxG.keys.justPressed.TAB)
		{
			tryOpenCharSelect();
			return;
		}

		if(FlxG.keys.justPressed.F) favoriteSong();
		if(uiState != Idle) return;

		if(FlxG.keys.justPressed.HOME) changeSelectionByPlayer(-curSelected);
		else if(FlxG.keys.justPressed.END) changeSelectionByPlayer(filteredSongs.length - curSelected - 1);

		// Holding a direction goes through the list, slowly at first
		var up:Bool = controls.UI_UP;
		var down:Bool = controls.UI_DOWN;
		if(up || down)
		{
			if(spamming)
			{
				if(spamTimer >= 0.07)
				{
					spamTimer = 0;
					changeSelection(up ? -1 : 1);
				}
			}
			else if(spamTimer >= 0.9) spamming = true;
			else if(spamTimer <= 0) changeSelection(up ? -1 : 1);

			spamTimer += elapsed;
			if(dj != null) dj.onPlayerAction();
		}
		else
		{
			spamming = false;
			spamTimer = 0;
		}

		if(FlxG.mouse.wheel != 0) changeSelectionByPlayer((FlxG.mouse.wheel > 0) ? -1 : 1);

		if(controls.UI_LEFT_P) changeDiffByPlayer(-1);
		else if(controls.UI_RIGHT_P) changeDiffByPlayer(1);

		if(FlxG.keys.justPressed.Q) changeLetterByPlayer(-1);
		else if(FlxG.keys.justPressed.E) changeLetterByPlayer(1);
		if(uiState != Idle) return;

		if(controls.BACK) goBack();
		else if(FlxG.keys.justPressed.CONTROL)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE) openSongPlayer(); //checked before ACCEPT, which has SPACE as one of its default keys
		else if(controls.ACCEPT) confirmSong();
		else if(controls.RESET && currentSong != null)
		{
			var song:FreeplaySong = currentSong;
			var difficulty:Int = prepareSong(song);
			if(difficulty < 0) return;

			persistentUpdate = false;
			openSubState(new ResetScoreSubState(song.getScoreName(currentDifficulty), difficulty, song.icon));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
	}

	inline function changeSelectionByPlayer(change:Int):Void
	{
		if(dj != null) dj.onPlayerAction();
		changeSelection(change);
	}

	inline function changeDiffByPlayer(change:Int):Void
	{
		if(dj != null) dj.onPlayerAction();
		changeDiff(change);
	}

	inline function changeLetterByPlayer(change:Int):Void
	{
		if(dj != null) dj.onPlayerAction();
		letterSort.changeSelection(change);
	}

	override function closeSubState()
	{
		persistentUpdate = true;
		super.closeSubState();

		// the score could have been reset
		if(backingCard == null) return;

		updateSelectionInfo();
		var capsule:FreeplayCapsule = currentCapsule;
		if(capsule != null) capsule.refreshDisplay(currentDifficulty);
	}

	override function beatHit()
	{
		super.beatHit();
		if(backingCard != null && introDone && uiState != Exiting) backingCard.beatHit(curBeat, Conductor.bpm);
	}

	function favoriteSong():Void
	{
		var capsule:FreeplayCapsule = currentCapsule;
		var song:FreeplaySong = currentSong;
		if(capsule == null || song == null) return;

		if(dj != null) dj.onPlayerAction();

		var isFavorite:Bool = FreeplayData.toggleFavorite(song.favoriteKey);
		var nudge:Float = isFavorite ? -5 : 5;
		if(isFavorite)
		{
			capsule.favIcon.visible = true;
			capsule.favIconBlurred.visible = true;
			capsule.favIcon.animation.play('fav', true);
			capsule.favIconBlurred.animation.play('fav', true);
			FlxG.sound.play(Paths.sound('fav'), 1);
			capsule.checkClip();
			capsule.updateSelected();
		}
		else
		{
			capsule.favIcon.animation.play('fav', true, true, 9);
			capsule.favIconBlurred.animation.play('fav', true, true, 9);
			FlxG.sound.play(Paths.sound('unfav'), 1);
			new FlxTimer().start(0.2, function(_)
			{
				if(capsule.song != song) return;

				capsule.favIcon.visible = false;
				capsule.favIconBlurred.visible = false;
				capsule.checkClip();
				capsule.updateSelected();
			});
		}

		// the capsule jumps a little
		uiState = Interacting;
		capsule.doLerp = false;
		FlxTween.tween(capsule, {y: capsule.y + nudge}, 0.1, {ease: FlxEase.expoOut});
		FlxTween.tween(capsule, {y: capsule.y}, 0.1, {
			ease: FlxEase.expoIn,
			startDelay: 0.1,
			onComplete: function(_)
			{
				capsule.doLerp = true;
				if(uiState == Interacting) uiState = Idle;
			}
		});
	}

	// ------------------------------------------------------------------------------------------
	// Starting a song
	// ------------------------------------------------------------------------------------------

	/**
	 * Makes a song's week and difficulties the current ones, like the rest of the engine expects them to be.
	 * Returns the position of the menu's difficulty on the song's own list, -1 if it doesn't have it.
	 */
	function prepareSong(song:FreeplaySong):Int
	{
		Mods.currentModDirectory = song.folder;
		PlayState.storyWeek = song.week;
		Difficulty.loadFromWeek();
		return song.getDifficultyIndex(currentDifficulty);
	}

	function showError(message:String):Void
	{
		missingText.text = message;
		missingText.screenCenter(Y);
		missingText.visible = true;
		missingTextBG.visible = true;
		FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function confirmSong():Void
	{
		if(dj != null) dj.onPlayerAction();

		if(currentSong == null)
		{
			// "Random" goes to any of the listed songs
			if(filteredSongs.length < 2)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				return;
			}
			changeSelection(FlxG.random.int(1, filteredSongs.length - 1) - curSelected);
		}

		var song:FreeplaySong = currentSong;
		var capsule:FreeplayCapsule = currentCapsule;
		var difficulty:Int = prepareSong(song);
		var songLowercase:String = Paths.formatToSongPath(song.name);

		// The chart is loaded before anything else, there's nothing to celebrate if it's broken
		try
		{
			if(difficulty < 0) throw 'The song doesn\'t have the difficulty "$currentDifficulty"';

			Song.loadFromJson(Highscore.formatSong(songLowercase, difficulty), songLowercase);
			if(PlayState.SONG == null) throw 'Missing file: $songLowercase/' + Highscore.formatSong(songLowercase, difficulty) + '.json';

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = difficulty;
			trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
		}
		catch(e:haxe.Exception)
		{
			trace('ERROR! ${e.message}');

			var errorStr:String = e.message;
			if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length - 1);
			else errorStr += '\n\n' + e.stack;

			showError('ERROR WHILE LOADING CHART:\n$errorStr');
			return;
		}

		uiState = Exiting;
		previewTimer.cancel();
		cancelPreviewLoad();

		playedSong = song.favoriteKey;
		playedDifficulty = currentDifficulty;
		playedRank = song.getRank(currentDifficulty);

		FlxG.sound.play(Paths.sound('confirmMenu'));
		if(dj != null) dj.onConfirm();
		if(capsule != null)
		{
			capsule.forcePosition();
			capsule.confirm();
		}
		dispatchCapsuleEvent(funkin.modding.events.ScriptEventType.SONG_SELECTED);
		backingCard.confirm();
		fadeDots(false);

		new FlxTimer().start(style.startDelay, function(_) startSong());
	}

	function startSong():Void
	{
		persistentUpdate = false;

		@:privateAccess
		if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			Paths.freeGraphicsFromMemory();

		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		#if !SHOW_LOADING_SCREEN
		if(FlxG.sound.music != null) FlxG.sound.music.stop();
		#end
		stopMusicPlay = true;

		FreeplayState.destroyFreeplayVocals();
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
	}

	// ------------------------------------------------------------------------------------------
	// Song player (SPACE)
	// ------------------------------------------------------------------------------------------

	function openSongPlayer():Void
	{
		var song:FreeplaySong = currentSong;
		if(song == null || instPlaying == curSelected) return;

		var difficulty:Int = prepareSong(song);
		var songLowercase:String = Paths.formatToSongPath(song.name);
		try
		{
			if(difficulty < 0) throw 'The song doesn\'t have the difficulty "$currentDifficulty"';

			Song.loadFromJson(Highscore.formatSong(songLowercase, difficulty), songLowercase);
			if(PlayState.SONG == null) throw 'Missing file: $songLowercase/' + Highscore.formatSong(songLowercase, difficulty) + '.json';
		}
		catch(e:haxe.Exception)
		{
			showError('ERROR WHILE LOADING CHART:\n${e.message}');
			return;
		}

		previewTimer.cancel();
		cancelPreviewLoad();
		FreeplayState.destroyFreeplayVocals();
		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.volume = 0;
		}

		// The song's tracks are loaded by another thread, the menu waits for them without freezing
		var songName:String = PlayState.SONG.song;
		var files:Array<String> = [SoundLoader.getFile(Paths.instKey(songName), 'songs'), null, null];
		if(PlayState.SONG.needsVoices)
		{
			var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
			files[1] = FreeplayState.getVocalsFile(songName, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player', true);

			var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
			files[2] = FreeplayState.getVocalsFile(songName, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent', false);
		}

		var selected:Int = curSelected;
		uiState = Interacting;
		playerLoads = SoundLoader.loadAll(files, function(sounds:Array<openfl.media.Sound>)
		{
			playerLoads = null;
			if(uiState == Interacting) uiState = Idle;
			if(uiState != Idle || curSelected != selected) return;

			if(sounds[0] == null)
			{
				showError('ERROR WHILE LOADING THE SONG:\nMissing file: ' + files[0]);
				return;
			}

			FreeplayState.vocals = FreeplayState.makeVocals(sounds[1]);
			FreeplayState.opponentVocals = FreeplayState.makeVocals(sounds[2]);

			if(FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
			FlxG.sound.playMusic(sounds[0], 0.8);
			FlxG.sound.music.pause();
			instPlaying = curSelected;
			curPreview = null;
			lastPreviewInst = null;

			player.playingMusic = true;
			player.curTime = 0;
			player.switchPlayMusic();
			player.pauseOrResume(true);
		});
	}


	function getVocalFromCharacter(char:String):String
	{
		try
		{
			var raw:String = Paths.getTextFromFile('characters/$char.json');
			if(raw != null) return Json.parse(raw).vocals_file;
		}
		catch(e:Dynamic) {}
		return null;
	}

	function handlePlayerInputs():Void
	{
		if(controls.BACK)
		{
			// back to the menu and to the song's preview
			FlxG.sound.music.stop();
			FreeplayState.destroyFreeplayVocals();
			FlxG.sound.music.volume = 0;
			instPlaying = -1;

			player.playingMusic = false;
			player.switchPlayMusic();

			curPreview = null;
			playCurSongPreview();
		}
		else if(FlxG.keys.justPressed.SPACE) player.pauseOrResume(!player.playing);
	}

	// ------------------------------------------------------------------------------------------
	// New rank animation
	// ------------------------------------------------------------------------------------------

	static final selectedCapsuleX:Float = FreeplayCapsule.intendedX(1);
	static inline final selectedCapsuleY:Float = 235.6;

	// The song's capsule goes to the middle of a dark screen to get its new rank, then slams back into the list
	function rankAnimStart(capsule:FreeplayCapsule):Void
	{
		uiState = Interacting;

		var rank:FreeplayRank = newRank;
		var oldRank:Null<FreeplayRank> = playedRank;
		playedRank = null;

		capsule.sparkle.alpha = 0;
		capsule.fakeRanking.visible = true;
		capsule.fakeRanking.alpha = 0;

		if(dj != null)
		{
			if(rank == FreeplayRank.LOSS) dj.fistPumpLossIntro();
			else dj.fistPumpIntro();
		}

		rankCamera.fade(FlxColor.BLACK, 0.5, true, null, true);
		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.volume = 0;
		}
		rankBg.alpha = 1;

		if(oldRank != null)
		{
			// the old rank is there until the new one lands on it
			capsule.fakeRanking.rank = oldRank;
			capsule.fakeBlurredRanking.rank = oldRank;
			capsule.fakeRanking.alpha = 1;

			sparks = new FlxSprite(517, 134);
			sparks.frames = Paths.getSparrowAtlas('freeplay/sparks');
			sparks.animation.addByPrefix('sparks', 'sparks', 24, false);
			sparks.blend = BlendMode.ADD;
			sparks.scale.set(0.5, 0.5);
			sparks.visible = false;
			sparks.cameras = [rankCamera];
			add(sparks);

			sparksADD = new FlxSprite(498, 116);
			sparksADD.frames = Paths.getSparrowAtlas('freeplay/sparksadd');
			sparksADD.animation.addByPrefix('sparks add', 'sparks add', 24, false);
			sparksADD.blend = BlendMode.ADD;
			sparksADD.scale.set(0.5, 0.5);
			sparksADD.color = oldRank.getColor();
			sparksADD.visible = false;
			sparksADD.cameras = [rankCamera];
			add(sparksADD);
		}
		else capsule.fakeBlurredRanking.visible = false;

		capsule.doLerp = false;
		capsule.ranking.visible = false;
		capsule.blurredRanking.visible = false;

		rankCamera.zoom = 1.85;
		FlxTween.tween(rankCamera, {zoom: 1.8}, 0.6, {ease: FlxEase.sineIn});

		FlxG.camera.zoom = 1.15;
		FlxTween.tween(FlxG.camera, {zoom: 1.1}, 0.6, {ease: FlxEase.sineIn});

		capsule.cameras = [rankCamera];
		capsule.setPosition((FlxG.width / 2) - (capsule.capsule.width / 2), (FlxG.height / 2) - (capsule.capsule.height / 2));

		new FlxTimer().start(0.5, function(_) rankDisplayNew(capsule, rank, oldRank != null));
	}

	function rankDisplayNew(capsule:FreeplayCapsule, rank:FreeplayRank, hadRank:Bool):Void
	{
		capsule.ranking.rank = rank;
		capsule.blurredRanking.rank = rank;
		capsule.ranking.scale.set(20, 20);
		capsule.blurredRanking.scale.set(20, 20);
		capsule.ranking.animation.play(rank.getAnimation(), true);
		capsule.blurredRanking.animation.play(rank.getAnimation(), true);

		FlxTween.tween(capsule.ranking.scale, {x: 0.9, y: 0.9}, 0.1);
		FlxTween.tween(capsule.blurredRanking.scale, {x: 0.9, y: 0.9}, 0.1);

		new FlxTimer().start(0.1, function(_)
		{
			capsule.fakeRanking.visible = false;
			capsule.fakeBlurredRanking.visible = false;

			if(hadRank && sparks != null)
			{
				sparks.visible = true;
				sparksADD.visible = true;
				sparks.animation.play('sparks', true);
				sparksADD.animation.play('sparks add', true);
				sparks.animation.finishCallback = function(_)
				{
					sparks.visible = false;
					sparksADD.visible = false;
				}
			}

			FlxG.sound.play(Paths.sound(switch(rank)
			{
				case FreeplayRank.LOSS: 'ranks/rankinbad';
				case FreeplayRank.PERFECT, FreeplayRank.PERFECT_GOLD: 'ranks/rankinperfect';
				default: 'ranks/rankinnormal';
			}));

			rankCamera.zoom = 1.3;
			FlxTween.tween(rankCamera, {zoom: 1.5}, 0.3, {ease: FlxEase.backInOut});

			capsule.x -= 10;
			capsule.y -= 20;

			FlxTween.tween(FlxG.camera, {zoom: 1.05}, 0.3, {ease: FlxEase.elasticOut});

			capsule.angle = -3;
			FlxTween.tween(capsule, {angle: 0}, 0.5, {ease: FlxEase.backOut});

			intervalShake(capsule, 0.3, 1 / 30, 0.1, FlxEase.quadOut);
		});

		new FlxTimer().start(0.4, function(_)
		{
			FlxTween.tween(FlxG.camera, {zoom: 1}, 0.8, {ease: FlxEase.sineIn});
			FlxTween.tween(rankCamera, {zoom: 1.2}, 0.8, {ease: FlxEase.backIn});
			FlxTween.tween(capsule, {x: selectedCapsuleX - 7, y: selectedCapsuleY - 80}, 0.8 + 0.5, {ease: FlxEase.quartIn});
		});

		new FlxTimer().start(0.6, function(_) rankAnimSlam(capsule, rank));
	}

	function rankAnimSlam(capsule:FreeplayCapsule, rank:FreeplayRank):Void
	{
		FlxTween.tween(rankBg, {alpha: 0}, 0.5, {ease: FlxEase.expoIn});

		FlxG.sound.play(Paths.sound(switch(rank)
		{
			case FreeplayRank.GOOD: 'ranks/good';
			case FreeplayRank.GREAT: 'ranks/great';
			case FreeplayRank.EXCELLENT: 'ranks/excellent';
			case FreeplayRank.PERFECT, FreeplayRank.PERFECT_GOLD: 'ranks/perfect';
			default: 'ranks/loss';
		}));

		new FlxTimer().start(0.5, function(_)
		{
			FlxG.camera.shake(0.0045, 0.35);

			if(dj != null)
			{
				if(rank == FreeplayRank.LOSS) dj.fistPumpLoss();
				else dj.fistPump();
			}

			rankCamera.zoom = 0.8;
			FlxG.camera.zoom = 0.8;
			FlxTween.tween(rankCamera, {zoom: 1}, 1, {ease: FlxEase.elasticOut});
			FlxTween.tween(FlxG.camera, {zoom: 1}, 0.8, {ease: FlxEase.elasticOut});

			// every capsule around shakes from the hit, the further the weaker
			for (index => other in capsules)
			{
				if(other == capsule)
				{
					FlxTween.cancelTweensOf(capsule);
					rankVignette.color = capsule.fadeAnim(rank);
					rankVignette.alpha = 1;
					FlxTween.tween(rankVignette, {alpha: 0}, 0.6, {ease: FlxEase.expoOut});

					capsule.doLerp = false;
					capsule.angle = 0;
					capsule.setPosition(selectedCapsuleX, selectedCapsuleY);
					capsule.targetPos.set(selectedCapsuleX, selectedCapsuleY);
					intervalShake(capsule, 0.6, 1 / 24, 0.12, FlxEase.quadOut, function()
					{
						capsule.doLerp = true;
						capsule.cameras = [FlxG.camera];

						// now the menu can be used
						prepForNewRank = false;
						if(uiState == Interacting) uiState = Idle;
						capsule.sparkle.alpha = 0.7;
						curPreview = null;
						playCurSongPreview();
					});
					continue;
				}

				var distance:Float = Math.abs(index - curSelected) - 1;
				if(distance >= 5) continue;

				new FlxTimer().start(distance / 20, function(_)
				{
					if(!other.alive) return;

					other.doLerp = false;
					other.angle = FlxG.random.float(-10 + (distance * 2), 10 - (distance * 2));
					FlxTween.tween(other, {angle: 0}, 0.5, {ease: FlxEase.backOut});

					intervalShake(other, 0.6, 1 / 24, 0.12 / (distance + 1), FlxEase.quadOut, function() other.doLerp = true);
				});
			}
		});
	}

	// Moves a sprite to random places around where it is, less and less until it stops
	function intervalShake(sprite:FlxSprite, duration:Float, interval:Float, intensity:Float, ease:EaseFunction, ?onComplete:Void->Void):Void
	{
		var startX:Float = sprite.x;
		var startY:Float = sprite.y;
		var size:Float = 612 * FreeplayCapsule.REAL_SCALE; //the shakes are relative to a capsule's width
		var passed:Float = 0;

		new FlxTimer().start(interval, function(timer:FlxTimer)
		{
			passed += interval;

			var curIntensity:Float = intensity * (1 - ease(Math.min(passed / duration, 1)));
			sprite.x = startX + FlxG.random.float(-curIntensity * size, curIntensity * size);
			sprite.y = startY + FlxG.random.float(-curIntensity * size, curIntensity * size);

			if(timer.loopsLeft > 0) return;

			sprite.setPosition(startX, startY);
			if(onComplete != null) onComplete();
		}, Std.int(Math.max(1, duration / interval)));
	}

	// Coming back from a game over, the DJ isn't happy about it
	function playLossReaction():Void
	{
		if(dj == null)
		{
			queuePreview();
			return;
		}

		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.volume = 0;
		}

		dj.fistPumpLossIntro();
		new FlxTimer().start(0.5, function(_) FlxG.sound.play(Paths.sound('ranks/rankinbad')));
		new FlxTimer().start(1.1, function(_) FlxG.sound.play(Paths.sound('ranks/loss')));
		new FlxTimer().start(1.6, function(_)
		{
			dj.fistPumpLoss();
			curPreview = null;
			if(uiState == Idle) queuePreview();
		});
	}

	// ------------------------------------------------------------------------------------------
	// Leaving
	// ------------------------------------------------------------------------------------------

	function tryOpenCharSelect():Void
	{
		if(PlayableCharacters.countUnlocked() <= 1)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		uiState = Exiting;
		previewTimer.cancel();
		cancelPreviewLoad();
		FlxG.sound.play(Paths.sound('confirmMenu'));

		if(dj != null) dj.toCharSelect();
		new FlxTimer().start((dj != null) ? dj.charSelectDelay : 0.25, function(_) transitionToCharSelect());
	}

	function makeTransitionGradient():FlxSprite
	{
		var transitionGradient:FlxSprite = new FlxSprite(0, 720).loadGraphic(Paths.image('freeplay/transitionGradient'));
		transitionGradient.scale.set(1280, 1);
		transitionGradient.updateHitbox();
		transitionGradient.cameras = [rankCamera];
		add(transitionGradient);
		return transitionGradient;
	}

	function setFadeShader(from:Float, to:Float, ?onComplete:Void->Void):Void
	{
		if(!ClientPrefs.data.shaders)
		{
			if(onComplete != null) new FlxTimer().start(0.8, function(_) onComplete());
			return;
		}

		if(fadeShader == null) fadeShader = new BlueFade();
		FlxG.camera.setFilters([new ShaderFilter(fadeShader)]);
		FlxG.camera.filtersEnabled = true;
		fadeShader.fade(from, to, 0.8, {
			ease: FlxEase.quadIn,
			onComplete: function(_)
			{
				if(onComplete != null) onComplete();
			}
		});
	}

	// Everything goes up and fades away
	function transitionToCharSelect():Void
	{
		exitMoversCharSel.set([makeTransitionGradient()], {y: -720, speed: 0.8, wait: 0.1});

		for (index => capsule in capsules)
		{
			if(Math.abs(index - curSelected) - 1 >= 5) continue;

			capsule.doLerp = false;
			exitMoversCharSel.set([capsule], {y: -250, speed: 0.8, wait: 0.1});
		}

		fadeDots(false);
		setFadeShader(1, 0);
		if(!ClientPrefs.data.shaders) FlxG.camera.fade(FlxColor.BLACK, 0.8, false);
		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.fadeOut(0.9, 0);
		}

		new FlxTimer().start(0.9, function(_)
		{
			if(FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
			stopMusicPlay = true;
			FlxTransitionableState.skipNextTransIn = true;
			MusicBeatState.switchState(new CharacterSelectState());
		});

		ExitMovers.fix(exitMoversCharSel); //(what scripts added)
		for (sprites => moveData in exitMoversCharSel)
		{
			for (sprite in sprites)
			{
				if(sprite == null) continue;
				FlxTween.tween(sprite, {y: sprite.y + ((moveData.y != null) ? moveData.y : 0)}, (moveData.speed != null) ? moveData.speed : 0.2, {ease: FlxEase.backIn});
			}
		}
		backingCard.enterCharSel();
	}

	// And comes back down the same way
	function enterFromCharSel():Void
	{
		uiState = Entering;

		exitMoversCharSel.set([makeTransitionGradient()], {y: -720, speed: 1.5, wait: 0.1});

		setFadeShader(0, 1, function() FlxG.camera.filtersEnabled = false);
		if(!ClientPrefs.data.shaders) FlxG.camera.fade(FlxColor.BLACK, 0.8, true);

		for (capsule in capsules)
		{
			capsule.doLerp = false;
			exitMoversCharSel.set([capsule], {y: -250, speed: 0.8, wait: 0.1});
		}

		var longest:Float = 0;
		ExitMovers.fix(exitMoversCharSel); //(what scripts added)
		for (sprites => moveData in exitMoversCharSel)
		{
			var moveY:Float = (moveData.y != null) ? moveData.y : 0;
			var speed:Float = ((moveData.speed != null) ? moveData.speed : 0.2) * 1.2;
			longest = Math.max(longest, speed);

			for (sprite in sprites)
			{
				if(sprite == null) continue;

				sprite.y += moveY;
				FlxTween.tween(sprite, {y: sprite.y - moveY}, speed, {ease: FlxEase.expoOut});
			}
		}

		new FlxTimer().start(0.8 * 1.2, function(_)
		{
			for (capsule in capsules)
				capsule.doLerp = true;

			if(uiState == Entering) uiState = Idle;
			queuePreview();
		});
	}

	function goBack():Void
	{
		uiState = Exiting;
		persistentUpdate = true;

		// nothing that was going on matters anymore
		FlxTween.globalManager.clear();
		FlxTimer.globalManager.clear();
		if(dj != null) dj.onIntroDone.removeAll();

		FlxG.sound.play(Paths.sound('cancelMenu'));

		dispatchEvent(new funkin.modding.events.ScriptEvent.FreeplayScriptEvent(funkin.modding.events.ScriptEventType.FREEPLAY_OUTRO));
		backingCard.disappear();
		fadeDots(false);

		var longestTimer:Float = 0;
		ExitMovers.fix(exitMovers); //(what scripts added)
		for (sprites => moveData in exitMovers)
		{
			var speed:Float = (moveData.speed != null) ? moveData.speed : 0.2;
			var wait:Float = (moveData.wait != null) ? moveData.wait : 0;
			longestTimer = Math.max(longestTimer, speed + wait);

			for (sprite in sprites)
			{
				if(sprite == null) continue;
				FlxTween.tween(sprite, {x: (moveData.x != null) ? moveData.x : sprite.x, y: (moveData.y != null) ? moveData.y : sprite.y}, speed, {ease: FlxEase.expoIn});
			}
		}

		for (capsule in capsules)
			capsule.jumpOut();

		if(FlxG.sound.music != null) FlxG.sound.music.fadeOut(longestTimer, 0);

		new FlxTimer().start(longestTimer, function(_)
		{
			if(FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			FlxG.sound.music.fadeIn(4, 0, 1);
			stopMusicPlay = true;

			dispatchEvent(new funkin.modding.events.ScriptEvent.FreeplayScriptEvent(funkin.modding.events.ScriptEventType.FREEPLAY_CLOSE));

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new MainMenuState());
		});
	}

	override function destroy():Void
	{
		previewTimer.cancel();
		cancelPreviewLoad();
		SoundLoader.cancelAll(playerLoads);
		playerLoads = null;
		super.destroy();

		#if HSCRIPT_ALLOWED
		// (after everything was destroyed, so the scripts of the card and of the DJ get to do their part of it)
		backend.VSliceScripts.endMenu(this);
		#end

		FlxG.autoPause = ClientPrefs.data.autoPause;

		// the song player can leave the music with another speed
		if(FlxG.sound.music != null)
		{
			FlxG.sound.music.pitch = 1.0;
			if(!FlxG.sound.music.playing && !stopMusicPlay) FlxG.sound.playMusic(Paths.music('freakyMenu'));
		}
	}
}
