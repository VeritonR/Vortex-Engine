package states;

import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;

import states.StoryMenuState;
import states.FreeplayState;
import states.FreeplayStateVslice;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;

#if !flash
	import openfl.filters.ShaderFilter;
#end
	import shaders.WiggleEffect;
	import shaders.WiggleEffect.WiggleEffectType;

import shaders.ErrorHandledShader;

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript.HScriptInfos;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

/**
 * This is where all the Gameplay stuff happens and is managed
 *
 * here's some useful tips if you are making a mod in source:
 *
 * If you want to add your stage to the game, copy states/stages/Template.hx,
 * and put your stage code there, then, on PlayState, search for
 * "switch (curStage)", and add your stage to that list.
 *
 * If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:
 *
 * "function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
 * "function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
 * "function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
 * "function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for
**/
class PlayState extends MusicBeatState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	//event variables
	private var isCameraOnForcedPos:Bool = false;

	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	public var gfMap:Map<String, Character> = new Map<String, Character>();

	#if HSCRIPT_ALLOWED
	public var hscriptArray:Array<HScript> = [];
	#end

	public var isVSliceStage:Bool = false; //Stage converted from a V-Slice (Polymod) mod
	var vsliceBoppers:Array<{sprite:FlxSprite, every:Int}> = [];

	// What a V-Slice stage gives to the characters on each of its places: scale, alpha, angle and how much they move with the camera
	var vsliceStagePlaces:Dynamic = null;

	public var BF_X:Float = 770;
	public var BF_Y:Float = 100;
	public var DAD_X:Float = 100;
	public var DAD_Y:Float = 100;
	public var GF_X:Float = 400;
	public var GF_Y:Float = 130;

	public var songSpeedTween:FlxTween;
	public var songSpeed(default, set):Float = 1;
	public var songSpeedType:String = "multiplicative";
	public var noteKillOffset:Float = 350;

	public var playbackRate(default, set):Float = 1;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;
	public static var curStage:String = '';
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal")
		{
			uiPrefix = value.split("-pixel")[0].trim();
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");

	public static var SONG:SwagSong = null;
	public static var isStoryMode:Bool = false;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var storyDifficulty:Int = 1;

	public var spawnTime:Float = 2000;

	public var inst:FlxSound;
	public var vocals:FlxSound;
	public var opponentVocals:FlxSound;

	public var dad:Character = null;
	public var gf:Character = null;
	public var boyfriend:Character = null;

	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	public var camFollow:FlxObject;
	private static var prevCamFollow:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote> = new objects.StrumGroup();
	public var opponentStrums:FlxTypedGroup<StrumNote> = new objects.StrumGroup();
	public var playerStrums:FlxTypedGroup<StrumNote> = new objects.StrumGroup();
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	public var grpHoldCovers:objects.HoldCover.HoldCoverGroup = null; //the sparks on the receptors while a long note is held

	public var camZooming:Bool = false;
	public var camZoomingMult:Float = 1;
	public var camZoomingDecay:Float = 1;
	private var curSong:String = "";

	public var gfSpeed:Int = 1;
	public var health(default, set):Float = 1;
	var visualHealth:Float = 1.0;
	public var combo:Int = 0;

	public var healthBar:Bar;
	public var timeBar:Bar;
	var songPercent:Float = 0;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	private var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	private var updateTime:Bool = true;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;

	//Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var healthDrain:Float = 0;
	public var ghostNotes:Bool = false;
    public var speedMiss:Bool = false;
    private var _previousMisses:Int = 0;
	/**
	 * "Play as Opponent": the one playing hits the opponent's notes, and the player's side plays by itself.
	 *
	 * Nothing of the song changes sides for it. The opponent's notes are still the opponent's (`mustPress` false, on `opponentStrums`,
	 * sung by `dad`, told to scripts as "opponentNoteHit") and the icons and the health bar are where they always are, so everything
	 * a mod's script reads or changes means what it meant when the script was written. What changes is who each side is played by:
	 * see `Note.playable`, `playableStrums` and `playableCharacter`.
	 */
	public var playAsOpponent:Bool = false;

	/**
	 * The receptors of the side that's being played, and the ones of the side that plays by itself.
	 */
	public var playableStrums(get, never):FlxTypedGroup<StrumNote>;
	inline function get_playableStrums():FlxTypedGroup<StrumNote> return playAsOpponent ? opponentStrums : playerStrums;

	public var otherStrums(get, never):FlxTypedGroup<StrumNote>;
	inline function get_otherStrums():FlxTypedGroup<StrumNote> return playAsOpponent ? playerStrums : opponentStrums;

	/**
	 * The character that's being played, and the one that sings by itself.
	 */
	public var playableCharacter(get, never):Character;
	inline function get_playableCharacter():Character return playAsOpponent ? dad : boyfriend;

	public var otherCharacter(get, never):Character;
	inline function get_otherCharacter():Character return playAsOpponent ? boyfriend : dad;

	// The receptor a note goes to, by the side of the song it's on
	inline function strumOf(note:Note):StrumNote
		return (note.mustPress ? playerStrums : opponentStrums).members[Std.int(Math.abs(note.noteData))];

	// The voice track of whoever is being played, which is the one that goes quiet on a miss
	function playableVoice():FlxSound
		return (playAsOpponent && opponentVocals != null && opponentVocals.length > 0) ? opponentVocals : vocals;

	public var showLaneUnderlay:Bool = false;
	public var laneUnderlays:FlxTypedGroup<FlxSprite>;
	/**
	 * How dark the lanes of "Lane Underlay" are, from 0 to 1 (they also fade with the receptors).
	 */
	public var laneUnderlayAlpha:Float = 0.5;

	public var guitarHeroSustains:Bool = false;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;
	public var pressMissDamage:Float = 0.05;

	public var botplaySine:Float = 0;
	public var botplayTxt:FlxText;

	// Textos Flutuantes do Nickname
	public var myNameTxt:FlxText;
	public var oppNameTxt:FlxText;

	// ---> VARIÁVEIS DE SINCRONIZAÇÃO MULTIPLAYER <---
	public var multiplayerSynced:Bool = false;
	public var iAmReady:Bool = false;
	public var opponentReady:Bool = false;
	public var syncWaitText:FlxText;
	// set while the pause menu is closed because the other player resumed (it isn't told back)
	public var resumedByNetwork:Bool = false;
	// the last health the host told the other player about, and the step it did
	var lastSentHealth:Float = -1;
	var lastHealthStep:Int = -100;
	// if this song is being played online (to know when the connection is lost in the middle of it)
	var playedOnline:Bool = false;
	var onlineNotice:FlxText;

	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var cameraSpeed:Float = 1;
	public var camSus:FlxCamera;
	public var camLanes:FlxCamera; //(under the long notes: the lanes of "Lane Underlay", only when they're on)
    public var susWiggle:WiggleEffect;
	var susWiggleFilter:ShaderFilter;
	var susWiggleFilterOn:Bool = false;
	public var restCountdownTxt:FlxText;
	public var restTimerBar:FlxSprite;
	public var restportrait:FlxSprite;
    public var maxRestTime:Float = 0;
    public var isResting:Bool = false;
	public var showBreakTimer:Bool = true;

	public var songScore:Int = 0;
	public var songHits:Int = 0;
	public var songMisses:Int = 0;
	public var scoreTxt:FlxText;
	var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	public static var campaignScore:Int = 0;
	public static var campaignMisses:Int = 0;
	public static var seenCutscene:Bool = false;
	public static var deathCounter:Int = 0;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	public var inCutscene:Bool = false;
	public var skipCountdown:Bool = false;
	var songLength:Float = 0;

	public var boyfriendCameraOffset:Array<Float> = null;
	public var opponentCameraOffset:Array<Float> = null;
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	var keysPressed:Array<Int> = [];
	var boyfriendIdleTime:Float = 0.0;
	var boyfriendIdled:Bool = false;

	// Lua shit
	public static var instance:PlayState;
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	private var luaDebugGroup:FlxTypedGroup<psychlua.DebugLuaText>;
	#end
	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;
	public var songName:String;

	// Callbacks for stages
	public var startCallback:Void->Void = null;
	public var endCallback:Void->Void = null;

	private static var _lastLoadedModDirectory:String = '';
	public static var nextReloadAll:Bool = false;

	var lastPlayerHitTime:Float = -9999;
	var lastPlayerNoteData:Int = -1;
	var lastPlayerSinger:Character = null;

	var lastOpponentHitTime:Float = -9999;
	var lastOpponentNoteData:Int = -1;
	var lastOpponentSinger:Character = null;
	public var scoreCamera:String = '';

	public var iconBop:Bool = true;
	private var _wasIconBop:Bool = true;
	public var sustainWiggle:Bool = true;
	public var hiddennotes:Bool = false;

	override public function create()
	{
		backend.StepLog.add('Song: being made, mod "' + Mods.currentModDirectory + '"');
		scoreCamera = ClientPrefs.data.scoreCamera;
		iconBop = ClientPrefs.data.iconBop;
		_wasIconBop = iconBop;
		sustainWiggle = ClientPrefs.data.sustainWiggle;
		ghostNotes = ClientPrefs.data.ghostNotes;
		showLaneUnderlay = ClientPrefs.data.laneUnderlay;
		if (ClientPrefs.data.gameplaySettings.exists('healthdrain')) {
            healthDrain = ClientPrefs.data.gameplaySettings.get('healthdrain');
        }
		if (ClientPrefs.data.gameplaySettings.exists('hiddennotes')) {
            hiddennotes = ClientPrefs.data.gameplaySettings.get('hiddennotes');
        }
        if (ClientPrefs.data.gameplaySettings.exists('speedmiss')) {
            speedMiss = ClientPrefs.data.gameplaySettings.get('speedmiss');
        }
		if (ClientPrefs.data.gameplaySettings.exists('playasopponent')) {
            playAsOpponent = ClientPrefs.data.gameplaySettings.get('playasopponent');
        }
		Note.opponentPlay = playAsOpponent; //(before the notes are made: what they are for depends on it)
		
		
		//trace('Playback Rate: ' + playbackRate);
		_lastLoadedModDirectory = Mods.currentModDirectory;
		Paths.clearStoredMemory();
		if(nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;
		backend.StepLog.add('Song: what the last screen loaded was let go');
		visualHealth = health;
		startCallback = startCountdown;
		endCallback = endSong;

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = [
			'note_left',
			'note_down',
			'note_up',
			'note_right'
		];

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

        if (showLaneUnderlay) makeLaneCamera();

        camSus = new FlxCamera();
        camSus.bgColor.alpha = 0;
        FlxG.cameras.add(camSus, false);

        susWiggle = new WiggleEffect();
        susWiggle.waveAmplitude = 0.07;
		susWiggle.effectType = WiggleEffectType.DREAMY;
        susWiggle.waveFrequency = 0;
        susWiggle.waveSpeed = 0.8;
        
        susWiggleFilter = new ShaderFilter(susWiggle.shader);
        setSusWiggleFilter(ClientPrefs.data.shaders);
        
        FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);

		persistentUpdate = true;
		persistentDraw = true;

		backend.StepLog.add('Song: cameras made');
		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		curStage = SONG.stage;

		backend.StepLog.add('Song: reading the stage "$curStage"');
		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage == true) //Backward compatibility
			stageUI = "pixel";

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		// A converted V-Slice stage is built only from its own data, even if it's named like one of these
		isVSliceStage = (stageData.vslice != null);
		if(isVSliceStage && stageData.vslice.characters != null)
		{
			// how much they move with the camera (the girlfriend's is given below, where Psych gives her its own)
			var places:Dynamic = stageData.vslice.characters;
			vsliceStagePlaces = places;
			boyfriendGroup.scrollFactor.set(places.bf.scroll[0], places.bf.scroll[1]);
			dadGroup.scrollFactor.set(places.dad.scroll[0], places.dad.scroll[1]);
		}
		if(!isVSliceStage)
		switch (curStage)
		{
			case 'stage': new StageWeek1(); 			//Week 1
			case 'spooky': new Spooky();				//Week 2
			case 'philly': new Philly();				//Week 3
			case 'limo': new Limo();					//Week 4
			case 'mall': new Mall();					//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();			//Week 5 - Winter Horrorland
			case 'school': new School();				//Week 6 - Senpai, Roses
			case 'schoolEvil': new SchoolEvil();		//Week 6 - Thorns
			case 'tank': new Tank();					//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 	//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();	//Weekend 1 - Blazin
		}
		if(isPixelStage) introSoundsSuffix = '-pixel';

		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		luaDebugGroup = new FlxTypedGroup<psychlua.DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);
		#end

		if (!stageData.hide_girlfriend)
		{
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			// A V-Slice song whose girlfriend doesn't exist just has none (mods name one that isn't there to have it that way)
			if(SONG.vslice != null && gf.missingCharacter) gf.visible = false;
			startCharacterPos(gf);
			if(isVSliceStage) gfGroup.scrollFactor.set(stageData.vslice.gfScroll[0], stageData.vslice.gfScroll[1]);
			else gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		// The player picked on Character Select replaces the chart's one on songs that weren't made for it
		var playerOverride:backend.PlayableCharacters.PlayerOverride = backend.PlayableCharacters.getOverride(SONG);
		var isCustomSkin:Bool = (playerOverride != null);
		var player1ToUse:String = isCustomSkin ? playerOverride.character : SONG.player1;

		var oldModDir_CS = backend.Mods.currentModDirectory;
		if (isCustomSkin && playerOverride.mod != null) backend.Mods.currentModDirectory = playerOverride.mod;

		boyfriend = new Character(0, 0, player1ToUse, true);

		backend.Mods.currentModDirectory = oldModDir_CS;

		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		
		if(stageData.objects != null && stageData.objects.length > 0)
		{
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup, boyfriendGroup, this);
			for (key => spr in list)
				if(!StageData.reservedNames.contains(key))
					variables.set(key, spr);

			if(isVSliceStage) setupVSliceProps(stageData.objects, list);
		}
		else
		{
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// "SCRIPTS FOLDER" SCRIPTS
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		#end
			
		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
		
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		// STAGE SCRIPTS
		#if LUA_ALLOWED startLuasNamed('stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('stages/' + curStage + '.hx'); #end

		// CHARACTER SCRIPTS
		if(gf != null) startCharacterScripts(gf.curCharacter);
		startCharacterScripts(dad.curCharacter);
		startCharacterScripts(boyfriend.curCharacter);
		#end

		uiGroup = new FlxSpriteGroup();
		comboGroup = new FlxSpriteGroup();
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(comboGroup);
		add(uiGroup);
		add(noteGroup);

		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 2;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.data.downScroll) timeTxt.y = FlxG.height - 44;
		if(ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = SONG.song;

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 4), 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		noteGroup.add(strumLineNotes);

		if(ClientPrefs.data.timeBarType == 'Song Name')
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}

		generateSong();

		noteGroup.add(grpNoteSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		//healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return playAsOpponent ? 2 - visualHealth : visualHealth, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		var oldModDir_Icon = backend.Mods.currentModDirectory;
		if (isCustomSkin && playerOverride.mod != null) backend.Mods.currentModDirectory = playerOverride.mod;

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		backend.Mods.currentModDirectory = oldModDir_Icon;
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		uiGroup.add(scoreTxt);

		var startY:Float = ClientPrefs.data.downScroll ? FlxG.height - 250 : 200;
        var playerX:Float = ClientPrefs.data.middleScroll ? FlxG.width / 2 : (playAsOpponent ? FlxG.width * 0.25 : FlxG.width * 0.75); 

        restTimerBar = new FlxSprite(0, startY).makeGraphic(250, 8, FlxColor.WHITE);
        restTimerBar.x = playerX - (restTimerBar.width / 2);
        restTimerBar.cameras = [camHUD];
        restTimerBar.alpha = 0;
        uiGroup.add(restTimerBar);

        restCountdownTxt = new FlxText(0, startY + 20, 400, "", 48);
        restCountdownTxt.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        restCountdownTxt.x = playerX - (restCountdownTxt.width / 2);
        restCountdownTxt.scrollFactor.set();
        restCountdownTxt.borderSize = 2;
        restCountdownTxt.cameras = [camHUD];
        restCountdownTxt.alpha = 0;
		uiGroup.add(restCountdownTxt);

		restportrait = new FlxSprite(0, startY - 32).loadGraphic(Paths.image('InGameSprites/restBar'));
		restportrait.antialiasing = ClientPrefs.data.antialiasing;
		restportrait.scrollFactor.set(0, 0);
        restportrait.x = playerX - 178;
		restportrait.cameras = [camHUD];
        restportrait.alpha = 0;
		uiGroup.add(restportrait); //(with the rest of the timer: on the HUD, hidden with it)

		showBreakTimer = ClientPrefs.data.breakTimer;

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, Language.getPhrase("AI Gameplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);
		if(ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;

		uiGroup.cameras = [camHUD];
		noteGroup.cameras = [camHUD];

		scoreCamera = ClientPrefs.data.scoreCamera;
				
				if (scoreCamera == 'Game') {
					comboGroup.cameras = [camGame];
				} else {
					comboGroup.cameras = [camHUD];
				}

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('custom_notetypes/' + notetype + '.lua');
		for (event in eventsPushed)
			startLuasNamed('custom_events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('custom_notetypes/' + notetype + '.hx');
		for (event in eventsPushed)
			startHScriptsNamed('custom_events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		// SONG SPECIFIC SCRIPTS
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/$songName/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua'))
					new FunkinLua(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(file.toLowerCase().endsWith('.hx'))
					initHScript(folder + file);
				#end
			}
		#end

		if(eventNotes.length > 0)
		{
			for (event in eventNotes) event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}

		#if HSCRIPT_ALLOWED
		// Before the countdown, which is one of the things V-Slice scripts wait for
		backend.VSliceScripts.create();
		#end

		startCallback();
		RecalculateRating(false, false);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		//PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		if(ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');
		if(!ClientPrefs.data.ghostTapping) for (i in 1...4) Paths.sound('missnote$i');
		Paths.image('alphabet');

		if (PauseSubState.songName != null)
			Paths.music(PauseSubState.songName);
		else if(Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic));

		resetRPC();

		stagesFunc(function(stage:BaseStage) stage.createPost());
		callOnScripts('onCreatePost');
		
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.000001; //cant make it invisible or it won't allow precaching

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.createDone();
		#end

		super.create();
		// the images of the stages and characters the song changes to later: loaded now (or kept, the loading screen already did), not in the middle of it
		for (image in StageData.laterStageImages(SONG))
			Paths.image(image);
		for (character in StageData.laterCharacters(SONG))
			for (image in LoadingState.characterImages(character))
				Paths.image(image);
		Paths.clearUnusedMemory();

		cacheCountdown();
		cachePopUpScore();
		for (i in 1...4) Paths.image('credit_bg$i'); // used by startSongCredits(), avoids a stutter when the song starts

		if(eventNotes.length < 1) checkEventNote();

		// ===============================================
		// MULTIPLAYER: RENDERIZAR OS NICKNAMES
		// ===============================================
		if (backend.NetworkManager.connected) {
			myNameTxt = new FlxText(0, 0, 0, backend.NetworkManager.myNickname, 28);
			myNameTxt.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(myNameTxt);

			oppNameTxt = new FlxText(0, 0, 0, backend.NetworkManager.opponentNickname, 28);
			oppNameTxt.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(oppNameTxt);
		}
	}

	function set_songSpeed(value:Float):Float
	{
		if(generatedMusic)
		{
			var ratio:Float = value / songSpeed; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			vocals.pitch = value;
			opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;

			var ratio:Float = playbackRate / value; //funny word huh
			if(ratio != 1)
			{
				for (note in notes.members) note.resizeByRatio(ratio);
				for (note in unspawnNotes) note.resizeByRatio(ratio);
			}
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.offset = Reflect.hasField(PlayState.SONG, 'offset') ? (PlayState.SONG.offset / value) : 0;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if VIDEOS_ALLOWED
		if(videoCutscene != null && videoCutscene.videoSprite != null) videoCutscene.videoSprite.bitmap.rate = value;
		#end
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
	public function addTextToDebug(text:String, color:FlxColor) {
		var newText:psychlua.DebugLuaText = luaDebugGroup.recycle(psychlua.DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);

		luaDebugGroup.forEachAlive(function(spr:psychlua.DebugLuaText) {
			spr.y += newText.height + 2;
		});
		luaDebugGroup.add(newText);

		Sys.println(text);
	}
	#end

	public function reloadHealthBarColors() 
    {
        // same colors in both modes: playing as opponent only flips the fill direction (healthBar.leftToRight)
        if (healthBar != null && !healthBar.colorsFromScript) {
            healthBar.setColors(
                FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
                FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2])
            );
        }
    }

	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend.curCharacter);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad.curCharacter);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf.curCharacter);
				}
		}
	}

	function startCharacterScripts(name:String)
	{
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'characters/$name.lua';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(replacePath))
		{
			luaFile = replacePath;
			doPush = true;
		}
		else
		{
			luaFile = Paths.getSharedPath(luaFile);
			if(FileSystem.exists(luaFile))
				doPush = true;
		}
		#else
		luaFile = Paths.getSharedPath(luaFile);
		if(Assets.exists(luaFile)) doPush = true;
		#end

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile)
				{
					doPush = false;
					break;
				}
			}
			if(doPush) new FunkinLua(luaFile);
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = 'characters/' + name + '.hx';
		#if MODS_ALLOWED
		var replacePath:String = Paths.modFolders(scriptFile);
		if(FileSystem.exists(replacePath))
		{
			scriptFile = replacePath;
			doPush = true;
		}
		else
		#end
		{
			scriptFile = Paths.getSharedPath(scriptFile);
			if(FileSystem.exists(scriptFile))
				doPush = true;
		}

		if(doPush)
		{
			if(Iris.instances.exists(scriptFile))
				doPush = false;

			if(doPush) initHScript(scriptFile);
		}
		#end
	}

	public function getLuaObject(tag:String):Dynamic
		return variables.get(tag);

	function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(isVSliceStage || char.isVSlice)
		{
			positionCharacterByFeet(char);
			return;
		}

		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	// V-Slice places characters by the bottom center of their idle pose instead of their top left corner.
	// Everything here is relative, as the character might already be inside its group
	function positionCharacterByFeet(char:Character)
	{
		var startX:Float = char.x;
		var startY:Float = char.y;
		var boxHeight:Float = char.frameHeight * char.scale.y;

		var feetX:Float = 0;
		var feetY:Float = 0;
		if(!isVSliceStage)
		{
			// V-Slice character on a Psych stage, which only says where a top left corner goes:
			// use the spot where the feet of the default characters end up at
			if(char == gf || gfMap.get(char.curCharacter) == char)
			{
				feetX = 350;
				feetY = 655;
			}
			else
			{
				feetX = char.isPlayer ? 220 : 235;
				feetY = 785;
			}
		}

		// V-Slice's characters, the same way its own code does it (`Stage.addCharacter()` and `BaseCharacter.setScale()` there):
		// the bottom center of their box goes on the stage's spot. For a texture atlas that's the area of the whole timeline its idle is on
		// and not the feet of its pose, which can be far from there: a stage of another format has nothing made for that, so there
		// the atlases are still placed by their pose, below. See `Character.cornerPosition`
		if(char.cornerPosition && (isVSliceStage || !char.isAnimateAtlas))
		{
			// what the stage gives to who's on that place
			var given:Dynamic = null;
			if(isVSliceStage && vsliceStagePlaces != null)
			{
				var places:Dynamic = vsliceStagePlaces;
				if(char == gf || gfMap.get(char.curCharacter) == char) given = places.gf;
				else given = char.isPlayer ? places.bf : places.dad;
			}
			if(given != null && given.scale != null && given.scale != 1)
			{
				char.setScale(char.getBaseScale() * given.scale);
				char.setPosition(startX, startY);
			}

			char.updateHitbox();
			char.x += feetX - char.width / 2 + char.positionArray[0];
			char.y += feetY - char.height + char.positionArray[1];

			if(given != null)
			{
				if(given.alpha != null && given.alpha != 1) char.alpha = given.alpha;
				if(given.angle != null && given.angle != 0) char.angle = given.angle;
			}

			// (the camera looks at the middle of the box)
			if(char.focusOffset == null) char.focusOffset = FlxPoint.get();
			char.focusOffset.set(char.width / 2, char.height / 2);
			return;
		}

		// texture atlases aren't drawn from their top left corner, so the area their idle pose takes is used instead
		var atlasBounds:flixel.math.FlxRect = #if flxanimate char.getAtlasBounds() #else null #end;
		if(atlasBounds != null)
		{
			char.x += feetX - (atlasBounds.x + atlasBounds.width / 2);
			char.y += feetY - (atlasBounds.y + atlasBounds.height);
			boxHeight = atlasBounds.height;
			atlasBounds.put();

			// that area already had the idle animation's offset in it, which has the part of the character's own offsets
			// V-Slice uses when drawing (see VSliceConvert). Lining the feet up took it away, so it's put back
			if(char.isVSlice)
			{
				char.x += char.positionArray[0] * char.scale.x;
				char.y += char.positionArray[1] * char.scale.y;
			}
		}
		else
		{
			// a scaled sprite grows from the center of its frame, hence the scale on the Y
			char.x += feetX - char.frameWidth / 2;
			char.y += feetY - char.frameHeight * (1 + char.scale.y) / 2;
		}

		if(char.isVSlice) //the character's own offsets, Psych characters have a top left corner position there instead
		{
			// (V-Slice uses them a second time when drawing the character, that part is on its animation offsets: see VSliceConvert)
			char.x += char.positionArray[0];
			char.y += char.positionArray[1];

			// Where the camera looks at when it's on the character: the middle of its box, which goes up from the feet
			// and is moved by those offsets as well. Kept from the character's position, so it goes along if something moves it
			var centerX:Float = startX + feetX + char.positionArray[0];
			var centerY:Float = startY + feetY + char.positionArray[1] - boxHeight / 2;
			if(char.focusOffset == null) char.focusOffset = FlxPoint.get();
			char.focusOffset.set(centerX - char.x, centerY - char.y);
		}
		else if(char.focusOffset != null)
		{
			char.focusOffset.put();
			char.focusOffset = null;
		}
	}

	// Things the stage's object list doesn't cover: blend modes and props that dance to the beat
	function setupVSliceProps(objects:Array<Dynamic>, sprites:Map<String, FlxSprite>)
	{
		for (data in objects)
		{
			if(data.name == null || !sprites.exists(data.name)) continue;

			// (regular sprites, or the props that are texture atlases)
			var sprite:FlxSprite = sprites.get(data.name);
			var prop:funkin.play.stage.StageProp = Std.downcast(sprite, funkin.play.stage.StageProp);
			if(prop == null && !Std.isOfType(sprite, psychlua.ModchartSprite)) continue;

			if(data.blend != null) sprite.blend = LuaUtils.blendModeFromString(data.blend);
			if(data.danceEvery != null && data.danceEvery > 0)
			{
				if(prop != null) prop.danceEvery = data.danceEvery;
				vsliceBoppers.push({sprite: sprite, every: Std.int(Math.max(1, Math.round(data.danceEvery)))});
			}
		}
	}

	/**
	 * Changes how often a sprite of a V-Slice stage dances, in beats: 0 for never.
	 */
	public function setPropDanceRate(sprite:FlxSprite, rate:Float):Void
	{
		var prop:funkin.play.stage.StageProp = Std.downcast(sprite, funkin.play.stage.StageProp);
		if(prop != null) prop.danceEvery = rate;

		var every:Int = Std.int(Math.max(1, Math.round(rate)));
		for (bopper in vsliceBoppers)
		{
			if(bopper.sprite != sprite) continue;

			if(rate > 0) bopper.every = every;
			else vsliceBoppers.remove(bopper);
			return;
		}
		if(rate > 0) vsliceBoppers.push({sprite: sprite, every: every});
	}

	function vslicePropsBop(beat:Int)
	{
		for (bopper in vsliceBoppers)
		{
			if(beat % bopper.every != 0) continue;

			var prop:funkin.play.stage.StageProp = Std.downcast(bopper.sprite, funkin.play.stage.StageProp);
			if(prop != null)
			{
				if(prop.shouldBop && prop.danceEvery > 0) prop.dance(true);
				continue;
			}

			var sprite:psychlua.ModchartSprite = cast bopper.sprite;

			// scripts change what a prop dances with by giving it a suffix: "idle-alt"
			var suffix:String = '';
			#if HSCRIPT_ALLOWED
			var given:Dynamic = hxc.HxcRuntime.getExtra(sprite, 'idleSuffix');
			if(given != null) suffix = Std.string(given);
			#end

			var anim:String = 'idle' + suffix;
			if(sprite.animation.exists('danceLeft' + suffix) && sprite.animation.exists('danceRight' + suffix))
				anim = ((Math.floor(beat / bopper.every) % 2 == 0) ? 'danceLeft' : 'danceRight') + suffix;

			if(sprite.animation.exists(anim)) sprite.playAnim(anim, true);
		}
	}

	public var videoCutscene:VideoSprite = null;
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			if(forMidSong) videoCutscene.videoSprite.bitmap.rate = playbackRate;

			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead && generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
			}
			if (GameOverSubstate.instance != null && isDead) GameOverSubstate.instance.add(videoCutscene);
			else add(videoCutscene);

			if (playOnLoad)
				videoCutscene.play();
			return videoCutscene;
		}
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
		else addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	function startAndEnd()
	{
		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd();
		}
	}

	// ------------------------------------------------------------------------------------------
	// V-Slice dialogues
	// ------------------------------------------------------------------------------------------

	/**
	 * The V-Slice dialogue being shown, if there's one.
	 */
	public var conversation:cutscenes.VSliceConversation = null;
	var conversationCouldPause:Bool = true;

	/**
	 * Starts a V-Slice dialogue, one of the mod's "data/dialogue/conversations" (see `cutscenes.VSliceConversation`).
	 * Any mod can have them: scripts start one with `startConversation('name')`.
	 *
	 * @param id 			Name of the conversation's file.
	 * @param onComplete 	What to do when it ends. By default the song starts, or ends if the dialogue was started when it was ending,
	 * 						like with Psych's own dialogues.
	 * @return If the conversation exists and was started. If it doesn't nothing else is done.
	 */
	public function startConversation(id:String, ?onComplete:Void->Void):Bool
	{
		var next:cutscenes.VSliceConversation = null;
		try
		{
			next = cutscenes.VSliceConversation.load(id);
		}
		catch(e:Dynamic)
		{
			trace('Could not make the dialogue "$id": $e');
		}
		if(next == null) return false;

		if(conversation != null) removeConversation();
		conversation = next;
		inCutscene = true;

		// the key that goes through the dialogue is one of the keys that pause the game
		conversationCouldPause = canPause;
		canPause = false;

		next.completeCallback = function()
		{
			removeConversation();
			inCutscene = false;
			callOnScripts('onConversationEnd', [id]);

			if(onComplete != null) onComplete();
			else startAndEnd();
		};
		next.cameras = [camOther];
		add(next);
		next.start();
		return true;
	}

	function removeConversation():Void
	{
		if(conversation == null) return;

		var old:cutscenes.VSliceConversation = conversation;
		conversation = null;
		old.completeCallback = null;
		remove(old, true);
		old.destroy();
		canPause = conversationCouldPause;
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	public var countdownReady:FlxSprite;
	public var countdownSet:FlxSprite;
	public var countdownGo:FlxSprite;
	public static var startOnTime:Float = 0;

	function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = switch(stageUI) {
			case "pixel": ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
			case "normal": ["ready", "set" ,"go"];
			default: ['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
		}
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts) Paths.image(asset);

		Paths.sound('intro3' + introSoundsSuffix);
		Paths.sound('intro2' + introSoundsSuffix);
		Paths.sound('intro1' + introSoundsSuffix);
		Paths.sound('introGo' + introSoundsSuffix);
	}

	public function startCountdown()
	{
		if(startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}

		// =======================================================
		// MULTIPLAYER: SISTEMA DE SINCRONIZAÇÃO DE LOADING
		// =======================================================
		if (backend.NetworkManager.connected && !multiplayerSynced) {
			iAmReady = true;
			backend.NetworkManager.send("PLAYER_READY");
			
			if (syncWaitText == null) {
				syncWaitText = new FlxText(0, FlxG.height / 2 - 50, FlxG.width, "Aguardando o Oponente Carregar...", 48);
				syncWaitText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				syncWaitText.cameras = [camOther];
				add(syncWaitText);
			}

			// Prende o jogador na tela preta de loading
			inCutscene = true; 
			canPause = false;

			// Verifica se já podemos começar (caso o oponente tenha carregado antes de você)
			checkMultiplayerSync();
			
			return false; // Interrompe o início do jogo!
		}
		
		// O jogo foi liberado! Apaga o texto.
		if (syncWaitText != null) {
			syncWaitText.destroy();
			syncWaitText = null;
		}
		// =======================================================

		seenCutscene = true;
		inCutscene = false;
		//startSongCredits();

		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if(ret != LuaUtils.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			canPause = true;
			if(strumsMadeEarly) showStaticArrows();
			else
			{
				generateStaticArrows(0);
				generateStaticArrows(1);
			}

			rememberPlayableStrums();

			if (showLaneUnderlay) makeLaneUnderlays(!skipArrowStartTween);

			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 350);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();

			startTimer = new FlxTimer().start(Conductor.crochet / 1000 / playbackRate, function(tmr:FlxTimer)
			{
				characterBopper(tmr.loopsLeft);

				var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
				var introImagesArray:Array<String> = switch(stageUI) {
					case "pixel": ['pixelUI/ready-pixel', 'pixelUI/set-pixel', 'pixelUI/date-pixel'];
					case "normal": ["ready", "set" ,"go"];
					default: ['${uiPrefix}UI/ready${uiPostfix}', '${uiPrefix}UI/set${uiPostfix}', '${uiPrefix}UI/go${uiPostfix}'];
				}
				introAssets.set(stageUI, introImagesArray);

				var introAlts:Array<String> = introAssets.get(stageUI);
				var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
				var tick:Countdown = THREE;

				switch (swagCounter)
				{
					case 0:
						FlxG.sound.play(Paths.sound('intro3' + introSoundsSuffix), 0.6);
						tick = THREE;
					case 1:
						countdownReady = createCountdownSprite(introAlts[0], antialias);
						FlxG.sound.play(Paths.sound('intro2' + introSoundsSuffix), 0.6);
						tick = TWO;
					case 2:
						countdownSet = createCountdownSprite(introAlts[1], antialias);
						FlxG.sound.play(Paths.sound('intro1' + introSoundsSuffix), 0.6);
						tick = ONE;
					case 3:
						countdownGo = createCountdownSprite(introAlts[2], antialias);
						FlxG.sound.play(Paths.sound('introGo' + introSoundsSuffix), 0.6);
						tick = GO;
					case 4:
						tick = START;
				}

				if(!skipArrowStartTween)
				{
					notes.forEachAlive(function(note:Note) {
						if(ClientPrefs.data.opponentStrums || note.playable)
						{
							note.copyAlpha = false;
							note.alpha = note.multAlpha;
							if(ClientPrefs.data.middleScroll && !note.playable)
								note.alpha *= 0.35;
						}
					});
				}

				stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, swagCounter));
				callOnLuas('onCountdownTick', [swagCounter]);
				callOnHScript('onCountdownTick', [tick, swagCounter]);

				swagCounter += 1;
			}, 5);
		}
		return true;
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	public dynamic function updateScore(miss:Bool = false, scoreBop:Bool = true)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == LuaUtils.Function_Stop)
			return;

		updateScoreText();
		if (!miss && !cpuControlled && scoreBop)
			doScoreBop();

		callOnScripts('onUpdateScore', [miss]);
	}

	public dynamic function updateScoreText()
	{
		var str:String = Language.getPhrase('rating_$ratingName', ratingName);
		if(totalPlayed != 0)
		{
			var percent:Float = CoolUtil.floorDecimal(ratingPercent * 100, 2);
			str += ' (${percent}%) - ' + Language.getPhrase(ratingFC);
		}

		var tempScore:String;
		if(!instakillOnMiss) tempScore = Language.getPhrase('score_text', 'Score: {1} | Misses: {2} | Rating: {3}', [songScore, songMisses, str]);
		else tempScore = Language.getPhrase('score_text_instakill', 'Score: {1} | Rating: {2}', [songScore, str]);
		scoreTxt.text = tempScore;
	}

	public dynamic function fullComboFunction()
	{
		var sicks:Int = ratingsData[0].hits;
		var goods:Int = ratingsData[1].hits;
		var bads:Int = ratingsData[2].hits;
		var shits:Int = ratingsData[3].hits;

		ratingFC = "";
		if(songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
		}
		else {
			if (songMisses < 10) ratingFC = 'SDCB';
			else ratingFC = 'Clear';
		}
	}

	public function doScoreBop():Void {
		if(!ClientPrefs.data.scoreZoom)
			return;

		if(scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxt.scale.x = 1.075;
		scoreTxt.scale.y = 1.075;
		scoreTxtTween = FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2, {
			onComplete: function(twn:FlxTween) {
				scoreTxtTween = null;
			}
		});
	}

	public function setSongTime(time:Float)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();

		FlxG.sound.music.time = time - Conductor.offset;
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.play();

		if (Conductor.songPosition < vocals.length)
		{
			vocals.time = time - Conductor.offset;
			#if FLX_PITCH vocals.pitch = playbackRate; #end
			vocals.play();
		}
		else vocals.pause();

		if (Conductor.songPosition < opponentVocals.length)
		{
			opponentVocals.time = time - Conductor.offset;
			#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
			opponentVocals.play();
		}
		else opponentVocals.pause();
		Conductor.songPosition = time;
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;

		if (songName != 'tutorial' && playAsOpponent) {
			camZooming = true;
		}

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();

		setSongTime(Math.max(0, startOnTime - 500) + Conductor.offset);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if(autoUpdateRPC) DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart');

		startSongCredits();
	}

	private var noteTypes:Array<String> = [];
	private var eventsPushed:Array<String> = [];
	private var totalColumns: Int = 4;

	private function generateSong():Void
	{
		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.characterVoices(songData.song, boyfriend.vocalsFile, false);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));
				
				var oppVocals = Paths.characterVoices(songData.song, dad.vocalsFile, true);
				if(oppVocals != null && oppVocals.length > 0) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = playbackRate;
		opponentVocals.pitch = playbackRate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		// over the notes
		grpHoldCovers = new objects.HoldCover.HoldCoverGroup();
		noteGroup.add(grpHoldCovers);

		try
		{
			var eventsChart:SwagSong = Song.getChart('events', songName);
			if(eventsChart != null)
				for (event in eventsChart.events) //Event Notes
					for (i in 0...event[1].length)
						makeEvent(event, i);
		}
		catch(e:Dynamic) {}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;
	
		for (section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i in 0...section.sectionNotes.length)
			{
				final songNotes: Array<Dynamic> = section.sectionNotes[i];
				var spawnTime: Float = songNotes[0];
				var noteColumn: Int = Std.int(songNotes[1] % totalColumns);
				var holdLength: Float = songNotes[2];
				var noteType: String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var gottaHitNote:Bool = (songNotes[1] < totalColumns);

				if (i != 0) {
					// CLEAR ANY POSSIBLE GHOST NOTES
					for (evilNote in unspawnNotes) {
						var matches: Bool = (noteColumn == evilNote.noteData && gottaHitNote == evilNote.mustPress && evilNote.noteType == noteType);
						if (matches && Math.abs(spawnTime - evilNote.strumTime) < flixel.math.FlxMath.EPSILON) {
							if (evilNote.tail.length > 0)
								for (tail in evilNote.tail)
								{
									tail.destroy();
									unspawnNotes.remove(tail);
								}
							evilNote.destroy();
							unspawnNotes.remove(evilNote);
							ghostNotesCaught++;
							//continue;
						}
					}
				}

				var swagNote:Note = new Note(spawnTime, noteColumn, oldNote);
				var isAlt: Bool = section.altAnim && !gottaHitNote;
				// (on charts converted from V-Slice a "GF section" only says where the camera goes, nobody sings for anyone else there)
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection && SONG.vslice == null);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = holdLength;
				swagNote.noteType = noteType;
				if(songNotes.length > 4 && songNotes[4] != null) swagNote.extraData.set('vsliceParams', songNotes[4]); //see funkin.play.notes.NoteSprite

				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);

				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if(roundSus > 0)
				{
					for (susNote in 0...roundSus)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(spawnTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.noteType = swagNote.noteType;
						sustainNote.scrollFactor.set();
						sustainNote.parent = swagNote;
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);

						sustainNote.correctionOffset = swagNote.height / 2;
						if(!PlayState.isPixelStage)
						{
							if(oldNote.isSustainNote)
							{
								oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
								oldNote.scale.y /= playbackRate;
								oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
							}

							if(ClientPrefs.data.downScroll)
								sustainNote.correctionOffset = 0;
						}
						else if(oldNote.isSustainNote)
						{
							oldNote.scale.y /= playbackRate;
							oldNote.resizeByRatio(curStepCrochet / Conductor.stepCrochet);
						}

						if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
						else if(ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if(noteColumn > 1) //Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if(noteColumn > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}
				if(!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				oldNote = swagNote;
			}
		}
		trace('["${SONG.song.toUpperCase()}" CHART INFO]: Ghost Notes Cleared: $ghostNotesCaught');
		for (event in songData.events) //Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	function eventPushed(event:EventNote) {
		eventPushedUnique(event);
		if(eventsPushed.contains(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	function eventPushedUnique(event:EventNote) {
		// ("Change Character" with no character to change to is not Psych's event: mods of V-Slice have one of their own
		// with this name, and loading a character with no name for it left the player as one)
		// A character that doesn't exist isn't changed to either: charts of V-Slice mods made from Psych ports still have
		// some of these, for characters that the port doesn't have (on V-Slice the mod's own script ignores them)
		var notPsychs:Bool = (event.event == 'Change Character' && !Character.characterExists(event.value2));
		switch(notPsychs ? '' : event.event) {
			case "Change Character":
				var charType:Int = 0;
				switch(event.value1.toLowerCase()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						var val1:Int = Std.parseInt(event.value1);
						if(Math.isNaN(val1)) val1 = 0;
						charType = val1;
				}

				var newCharacter:String = event.value2;
				addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); //Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	function eventEarlyTrigger(event:EventNote):Float {
		var returnedValue:Null<Float> = callOnScripts('eventEarlyTrigger', [event.event, event.value1, event.value2, event.strumTime], true);
		if(returnedValue != null && returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	public static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: event[1][i][0],
			value1: event[1][i][1],
			value2: event[1][i][2]
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', [subEvent.event, subEvent.value1 != null ? subEvent.value1 : '', subEvent.value2 != null ? subEvent.value2 : '', subEvent.strumTime]);
	}

	public var skipArrowStartTween:Bool = false; //for lua

	// If the receptors were made before the countdown (see `makeStrumsEarly()`)
	var strumsMadeEarly:Bool = false;

	/**
	 * Makes the receptors right away, hidden, instead of when the countdown starts. On V-Slice they're there when the song's
	 * scripts are told the song was made, and those move them around then (to make room for a lane of their own...).
	 * They show up with the countdown, like always.
	 */
	public function makeStrumsEarly():Void
	{
		if(strumsMadeEarly || playerStrums.length > 0) return;

		generateStaticArrows(0, true);
		generateStaticArrows(1, true);
		strumsMadeEarly = true;
	}

	// The receptors made by `makeStrumsEarly()` showing up, the way they do when they're made with the countdown
	function showStaticArrows():Void
	{
		for (player in 0...2)
		{
			var group:FlxTypedGroup<StrumNote> = (player == 1) ? playerStrums : opponentStrums;
			for (i in 0...group.length)
			{
				var babyArrow:StrumNote = group.members[i];
				if(babyArrow == null) continue;

				var targetAlpha:Float = strumAlphaFor(player);
				if (!isStoryMode && !skipArrowStartTween)
				{
					babyArrow.alpha = 0;
					FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
				}
				else babyArrow.alpha = targetAlpha;
			}
		}
	}

	// How visible one side's receptors are meant to be
	public function strumAlphaFor(player:Int):Float
	{
		var played:Bool = (player == 1) != playAsOpponent;
		if (!played)
		{
			if(!ClientPrefs.data.opponentStrums) return 0;
			if(ClientPrefs.data.middleScroll) return 0.35;
		}
		return 1;
	}

	private function generateStaticArrows(player:Int, hidden:Bool = false):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
		StrumNote.vsliceHitbox = vsliceStrumSize();
		StrumNote.songRoom = StrumNote.vsliceHitbox;
		for (i in 0...4)
		{
			// FlxG.log.add(i);
			var targetAlpha:Float = 1;
			var played:Bool = (player == 1) != playAsOpponent;
			if (!played)
			{
				if(!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.data.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			if (hidden) babyArrow.alpha = 0;
			else if (!isStoryMode && !skipArrowStartTween)
			{
				//babyArrow.y -= 10;
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {/*y: babyArrow.y + 10,*/ alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else babyArrow.alpha = targetAlpha;

			if (player == 1)
				playerStrums.add(babyArrow);
			else
				opponentStrums.add(babyArrow);

			if(ClientPrefs.data.middleScroll && !played)
			{
				babyArrow.x += 310;
				if(i > 1) { //Up and Right
					babyArrow.x += FlxG.width / 2 + 25;
				}
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();

			// (playerPosition() puts the player's half a screen to the right, which with Middlescroll is the middle:
			// when the opponent is the one being played, that's the line that goes there)
			if(ClientPrefs.data.middleScroll && playAsOpponent) babyArrow.x += played ? FlxG.width / 2 : -FlxG.width / 2;
		}
		StrumNote.vsliceHitbox = null;

		// the look of the note style of the side, on the songs of V-Slice mods
		#if HSCRIPT_ALLOWED
		if(backend.VSliceScripts.active && funkin.play.PlayState.instance != null)
			(player == 1 ? funkin.play.PlayState.instance.playerStrumline : funkin.play.PlayState.instance.opponentStrumline).styleReceptors();
		#end
	}

	// The room a receptor of the song's note style takes on V-Slice, for the songs of its mods (see `StrumNote.vsliceHitbox`)
	function vsliceStrumSize():FlxPoint
	{
		if(SONG == null || SONG.vslice == null) return null;
		var styleId:String = (SONG.vslice.noteStyle != null) ? Std.string(SONG.vslice.noteStyle) : 'funkin';
		try
		{
			var style:funkin.play.notes.notestyle.NoteStyle = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry(styleId);
			if(style == null) style = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry('funkin');
			return (style != null) ? style.getStrumlineSize() : null;
		}
		catch(e:Dynamic)
		{
			trace('Could not read the receptors of the note style "$styleId": $e');
		}
		return null;
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		if (paused)
		{
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.pause();
				vocals.pause();
				opponentVocals.pause();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		super.closeSubState();
		
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			// ---> AVISA O OUTRO PC PARA DESPAUSAR <---
			if (backend.NetworkManager.connected && !resumedByNetwork && !isDead && !endingSong) {
				backend.NetworkManager.send("UNPAUSE_GAME");
			}
			if (backend.NetworkManager.connected) backend.NetworkManager.log('resumed' + (resumedByNetwork ? ' (by the other player)' : '') + ' at ' + Math.round(Conductor.songPosition));
			resumedByNetwork = false;
			// -----------------------------------------

			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = true);

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}
	}

	#if DISCORD_ALLOWED
	override public function onFocus():Void
	{
		super.onFocus();
		if (!paused && health > 0)
		{
			resetRPC(Conductor.songPosition > 0.0);
		}
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();

		// (not on test runs: their windows are kept out of the way, and lose the focus all the time)
		if (backend.NetworkManager.connected && !backend.NetworkManager.testLog && !paused && canPause && startedCountdown && !isDead) {
			openPauseMenu();
		}

		if (!paused && health > 0 && autoUpdateRPC)
		{
			DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		}
	}
	#end

	// Updating Discord Rich Presence.
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	function resetRPC(?showTime:Bool = false)
	{
		#if DISCORD_ALLOWED
		if(!autoUpdateRPC) return;

		if (showTime)
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		else
			DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else voc.pause();
		}
	}

	public var paused:Bool = false;
	public var canReset:Bool = true;
	var startedCountdown:Bool = false;
	var canPause:Bool = true;
	var freezeCamera:Bool = false;
	var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		if (ClientPrefs.data.smoothHealthBar)
		{
			// O fator '14 * elapsed' determina a velocidade do deslize. 
			// Quanto maior o número (ex: 14 ou 16), mais rápido e fluido será o movimento.
			visualHealth = FlxMath.lerp(visualHealth, health, FlxMath.bound(elapsed * 14, 0, 1));
		}
		else
		{
			visualHealth = health;
		}
		
		if (healthBar != null && healthBar.enabled)
		{
			var shownHealth:Float = playAsOpponent ? (healthBar.bounds.min + healthBar.bounds.max) - visualHealth : visualHealth; //(the opponent's part of the bar is the one that grows)
			var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(shownHealth, healthBar.bounds.min, healthBar.bounds.max), healthBar.bounds.min, healthBar.bounds.max, 0, 100);
			healthBar.percent = (newPercent != null ? newPercent : 0);
			
			if (iconsAnimations && iconP1 != null && iconP2 != null)
			{
				if(iconP1.autoUpdate) iconP1.updateIconAnim(healthBar.percent);
				if(iconP2.autoUpdate) iconP2.updateIconAnim(100 - healthBar.percent);
			}
		}
		
		guardPlayableStrums();

		if (laneUnderlays != null)
        {
            for (i in 0...4)
            {
                var strum:StrumNote = playableStrums.members[i];
                var lane:FlxSprite = laneUnderlays.members[i];

                if (strum != null && lane != null)
                {
                    lane.x = strum.x + (strum.width - lane.width) / 2;
                    lane.visible = showLaneUnderlay && strum.visible;
                    lane.alpha = strum.alpha * laneUnderlayAlpha;
                }
            }
        }

		if(!inCutscene && !paused && !freezeCamera) {
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			var idleAnim:Bool = (boyfriend.getAnimationName().startsWith('idle') || boyfriend.getAnimationName().startsWith('danceLeft') || boyfriend.getAnimationName().startsWith('danceRight'));
			if(!startingSong && !endingSong && idleAnim) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}
		else FlxG.camera.followLerp = 0;
		callOnScripts('onUpdate', [elapsed]);

		super.update(elapsed);

		// ===============================================
		// MULTIPLAYER: LENDO SINAIS NA GAMEPLAY
		// ===============================================
		if (backend.NetworkManager.connected) playedOnline = true;
		else if (playedOnline) onlineConnectionLost();
		if (backend.NetworkManager.connected && !paused && !isDead) updateOnlineTime(elapsed);

		if (backend.NetworkManager.connected && !paused && !isDead) {
			var msgs = backend.NetworkManager.getNewMessages();
			for (msg in msgs) {
				var data = msg.split("|");

				if (data[0] == "PLAYER_DIED") {
					backend.NetworkManager.log('the other player died: victory');
					persistentUpdate = false;
					persistentDraw = true;
					paused = true;
					openSubState(new states.VictorySubstate());
				}
				else if (data[0] == "HIT") {
					var nData:Null<Int> = backend.NetworkManager.readInt(data[1]);
					if (nData != null) networkOpponentHit(nData, (data[2] == "1"));
				}
				else if (data[0] == "MISS") {
					var nData:Null<Int> = backend.NetworkManager.readInt(data[1]);
					if (nData != null) networkOpponentMiss(nData, false, (data[2] == "1"));
				}
				else if (data[0] == "MISSPRESS") {
					var nData:Null<Int> = backend.NetworkManager.readInt(data[1]);
					if (nData != null) networkOpponentMiss(nData, true);
				}
				else if (data[0] == "SYNC_HEALTH") {
					// ---> O CLIENT OBEDECE A VIDA ABSOLUTA DO HOST! <---
					if (!backend.NetworkManager.isHost) {
						var hostHealth = Std.parseFloat(data[1]);
						// O Client inverte o valor para bater com a visão dele
						if (!Math.isNaN(hostHealth)) health = 2.0 - hostHealth;
					}
				}
				else if (data[0] == "LOAD_FAILED") {
					// O outro PC não conseguiu abrir a música: volta todo mundo pro lobby
					onlineBackToLobby("O oponente nao conseguiu abrir a musica.");
				}
				else if (data[0] == "RETURN_TO_LOBBY") {
					onlineBackToLobby("O oponente voltou para o lobby.");
				}
				// ===================================================
				// ---> NOVOS COMANDOS: VISUALIZANDO AS TECLAS <---
				// ===================================================
				else if (data[0] == "KEY_PRESS") {
					var nData:Null<Int> = backend.NetworkManager.readInt(data[1]);
					if (nData == null) continue;
					var spr:StrumNote = otherStrums.members[nData];

					// 1. Faz a setinha do inimigo brilhar (Pressed)
					if (spr != null && (spr.animation.curAnim == null || spr.animation.curAnim.name != 'confirm')) {
						spr.playAnim('pressed');
						spr.resetAnim = 0;
					}
					
					// 2. Faz o personagem inimigo fazer a pose (Ghost Tapping)
					// (Apenas se o jogo não estiver tocando a animação de Miss)
					var char:Character = otherCharacter;
					var charAnim:String = (char != null) ? char.getAnimationName() : null;
					if (char != null && (charAnim == null || !charAnim.endsWith('miss'))) {
						char.playAnim(singAnimations[nData], true);
						char.holdTimer = 0;
					}
				}
				else if (data[0] == "KEY_RELEASE") {
					var nData:Null<Int> = backend.NetworkManager.readInt(data[1]);
					if (nData == null) continue;
					var spr:StrumNote = otherStrums.members[nData];

					// Apaga a setinha do inimigo (Static) assim que ele solta o dedo
					if (spr != null && (spr.animation.curAnim == null || spr.animation.curAnim.name != 'confirm')) {
						spr.playAnim('static');
						spr.resetAnim = 0;
					}
				}
				// ===================================================
				// ---> NOVOS COMANDOS: SINCRONIZAÇÃO DE TELA <---
				// ===================================================
				else if (data[0] == "PLAYER_READY") {
					opponentReady = true;
					checkMultiplayerSync();
				}
				else if (data[0] == "SYNC_START") {
					// O Host liberou a largada!
					multiplayerSynced = true;
					backend.NetworkManager.log('starting the countdown');
					startCountdown();
				}
				// ---> NOVOS SINAIS: SISTEMA DE PAUSE GLOBAL <---
				else if (data[0] == "PAUSE_GAME") {
					if (!paused && canPause && startedCountdown) {
						openPauseMenu(true); // Pausa o jogo sem reenviar o sinal!
						// Os dois voltam do mesmo ponto da música: o de quem pausou
						var pausedAt:Float = Std.parseFloat(data[1]);
						if (!Math.isNaN(pausedAt) && !startingSong && pausedAt >= 0) seekWhilePaused(pausedAt);
					}
				}
				else if (data[0] == "UNPAUSE_GAME") {
					if (paused) {
						closeSubState(); // Fecha o menu de Pause na marra
					}
				}
				// ===================================================
			}
		}
		// ===============================================

		setOnScripts('curDecStep', curDecStep);
		setOnScripts('curDecBeat', curDecBeat);

		if(botplayTxt != null && botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if(ret != LuaUtils.Function_Stop) {
				openPauseMenu();
			}
		}

		if(!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
				openChartEditor();
			else if (controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		updateIconsScale(elapsed);
		updateIconsPosition();

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			if (Conductor.songPosition >= Conductor.offset)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition - ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if(ClientPrefs.data.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if(secondsTotal < 0) secondsTotal = 0;

			if(ClientPrefs.data.timeBarType != 'Song Name')
				timeTxt.text = FlxStringUtil.formatTime(secondsTotal, false);
		}

		if (camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
			camHUD.zoom = FlxMath.lerp(1, camHUD.zoom, Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate));
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();

		if (unspawnNotes[0] != null)
		{
			var time:Float = spawnTime * playbackRate;
			if(songSpeed < 1) time /= songSpeed;
			if(unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				if (dunceNote.isSustainNote) {
					dunceNote.cameras = [camSus];
				} else {
					dunceNote.cameras = [camHUD];
				}
				if (hiddennotes) {
					dunceNote.visible = false; 
				}

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled)
					keysCheck();
				else
					playerDance();

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						var fakeCrochet:Float = (60 / SONG.bpm) * 1000;
						var i:Int = 0;
						while(i < notes.length)
						{
							var daNote:Note = notes.members[i];
							if(daNote == null) continue;

							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if(!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							if(strum == null)
							{
								// a note for a receptor that isn't there (taken out by a script, or a direction the chart shouldn't have)
								i++;
								continue;
							}
							if(playAsOpponent && daNote.playable) guardPlayableNote(daNote, strum);
							daNote.followStrumNote(strum, fakeCrochet, songSpeed / playbackRate);

							if(daNote.playable)
							{
								if(cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							}
							else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
							{
								// Em multiplayer, espera o oponente real avisar que acertou a nota!
								if (!backend.NetworkManager.connected) {
									opponentNoteHit(daNote);
								}
							}

							if(daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
							{
								if (daNote.playable && !cpuControlled && !daNote.ignoreNote && !endingSong && (daNote.tooLate || !daNote.wasGoodHit))
									noteMiss(daNote);

								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}
							if(daNote.exists) i++;
						}
					}
					else
					{
						notes.forEachAlive(function(daNote:Note)
						{
							daNote.canBeHit = false;
							daNote.wasGoodHit = false;
						});
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end

		setOnScripts('botPlay', cpuControlled);
		callOnScripts('onUpdatePost', [elapsed]);
		guardPlayableStrums(); //(what scripts did on this frame is seen before it's drawn)
        
        if (susWiggle != null) 
        {
            // framerate independent decay, same speed the old per-frame lerp had at 75 FPS
            var decay:Float = FlxMath.bound(elapsed * (sustainWiggle ? 2.625 : 9), 0, 1);
            susWiggle.waveAmplitude = FlxMath.lerp(susWiggle.waveAmplitude, 0, decay);
            susWiggle.waveFrequency = FlxMath.lerp(susWiggle.waveFrequency, 0, decay);
            susWiggle.update(elapsed);

            // the filter is an extra render pass for camSus, drop it once the wiggle is turned off and has faded out
            setSusWiggleFilter(ClientPrefs.data.shaders && (sustainWiggle || susWiggle.waveAmplitude > 0.0005));
        }

        if (camHUD != null) {
            if (camSus != null) copyHudCamera(camSus);
            if (camLanes != null) copyHudCamera(camLanes);
        }

        //notes.forEachAlive(function(note:Note) {
           // if (note.isSustainNote) {
             //   note.cameras = [camSus];
            //} else {
              //  note.cameras = [camHUD]; 
            //}
			//if (hiddennotes) {
             //   note.visible = false; 
            //}
        //});

        updateBreakTimer(elapsed);

		if (iconBop != _wasIconBop) 
        {
            if (!iconBop) 
            {
                FlxTween.cancelTweensOf(iconP1, ['angle']);
                FlxTween.cancelTweensOf(iconP2, ['angle']);
                
                FlxTween.tween(iconP1, {angle: 0}, 0.25, {ease: FlxEase.circOut});
                FlxTween.tween(iconP2, {angle: 0}, 0.25, {ease: FlxEase.circOut});
            }
            _wasIconBop = iconBop;
        }
		if (speedMiss && songMisses > _previousMisses)
        {
            // the playbackRate setter already updates the pitch of the music and vocals
            if (playbackRate < 2.0)
                playbackRate = Math.min(2.0, playbackRate + 0.05 * (songMisses - _previousMisses));

            _previousMisses = songMisses;
        }

		// ===============================================
		// MULTIPLAYER: FAZER OS NICKNAMES SEGUIREM OS PERSONAGENS
		// ===============================================
		if (backend.NetworkManager.connected && myNameTxt != null && oppNameTxt != null) {
			var myChar:Character = playableCharacter; // Se "Play as Opponent" for True, myChar vira o Dad automaticamente
			var oppChar:Character = otherCharacter;

			if (myChar != null) {
				myNameTxt.x = myChar.getGraphicMidpoint().x - (myNameTxt.width / 2);
				myNameTxt.y = myChar.y - 60; // Flutua 60 pixels acima da cabeça
			}
			if (oppChar != null) {
				oppNameTxt.x = oppChar.getGraphicMidpoint().x - (oppNameTxt.width / 2);
				oppNameTxt.y = oppChar.y - 60;
			}
		}
	}

	function setSusWiggleFilter(enable:Bool)
	{
		susWiggleFilterOn = enable;
		if (camSus == null) return;

		// the HUD's own (shaders scripts put on it) go on the long notes too, they're part of it
		var filters:Array<openfl.filters.BitmapFilter> = [];
		if (enable) filters.push(susWiggleFilter);
		if (camHUD != null && camHUD.filters != null)
			for (filter in camHUD.filters)
				if (filter != null) filters.push(filter);
		if (!sameFilters(camSus.filters, filters)) camSus.setFilters(filters);
	}

	static function sameFilters(a:Array<openfl.filters.BitmapFilter>, b:Array<openfl.filters.BitmapFilter>):Bool
	{
		var lengthA:Int = (a != null) ? a.length : 0;
		var lengthB:Int = (b != null) ? b.length : 0;
		if (lengthA != lengthB) return false;
		for (i in 0...lengthA)
			if (a[i] != b[i]) return false;
		return true;
	}

	// The long notes (and the lanes under them) are on cameras of their own, under the HUD's: they're made to look at the same place
	function copyHudCamera(camera:FlxCamera)
	{
		camera.zoom = camHUD.zoom;
		camera.visible = camHUD.visible;
		camera.x = camHUD.x;
		camera.y = camHUD.y;
		camera.alpha = camHUD.alpha;
		camera.angle = camHUD.angle;
		camera.color = camHUD.color;
		camera.scroll.copyFrom(camHUD.scroll);
		camera.flashSprite.scaleX = camHUD.flashSprite.scaleX;
		camera.flashSprite.scaleY = camHUD.flashSprite.scaleY;
		if (camera != camSus && !sameFilters(camera.filters, camHUD.filters)) camera.setFilters((camHUD.filters != null) ? camHUD.filters.copy() : []);
	}

	function updateBreakTimer(elapsed:Float)
	{
		var wasResting:Bool = isResting;
		computeBreak(elapsed);

		// scripts are told when a break starts ("onBreakStart", with how long it is in seconds) and ends ("onBreakEnd")
		if (isResting != wasResting)
		{
			if (isResting) callOnScripts('onBreakStart', [maxRestTime]);
			else callOnScripts('onBreakEnd', []);
		}
	}

	function computeBreak(elapsed:Float)
	{
		// (the notes that have to be hit: not the ones that are there to be avoided)
		var songPos:Float = Conductor.songPosition;
		var nextNoteTime:Float = -1;
		for (note in notes.members)
		{
			if (note != null && note.alive && note.playable && !note.ignoreNote && !note.hitCausesMiss && note.strumTime > songPos && (nextNoteTime == -1 || note.strumTime < nextNoteTime))
				nextNoteTime = note.strumTime;
		}

		if (nextNoteTime == -1)
		{
			for (note in unspawnNotes)
			{
				if (note.playable && !note.ignoreNote && !note.hitCausesMiss && note.strumTime > songPos)
				{
					nextNoteTime = note.strumTime;
					break;
				}
			}
		}

		// in real seconds: the song's own ones go faster or slower with the playback rate
		var timeLeft:Float = (nextNoteTime != -1) ? (nextNoteTime - songPos) / 1000 / playbackRate : 0;
		var fadeIn:Bool = false;
		if (timeLeft > 0)
		{
			if (timeLeft >= 3.0 && (!isResting || timeLeft > maxRestTime))
			{
				isResting = true;
				maxRestTime = timeLeft;
			}
			else if (timeLeft < 0.1) isResting = false;

			restCountdownTxt.text = Math.ceil(timeLeft) + "s";
			if (maxRestTime > 0) restTimerBar.scale.x = FlxMath.bound(timeLeft / maxRestTime, 0, 1);

			fadeIn = (isResting && timeLeft > 1.5 && maxRestTime >= 3.0);
		}
		else isResting = false;

		if (!showBreakTimer) fadeIn = false;
		var newAlpha:Float = FlxMath.bound(restCountdownTxt.alpha + (fadeIn ? elapsed : -elapsed) / 1.5, 0, 1);
		restCountdownTxt.alpha = restTimerBar.alpha = restportrait.alpha = newAlpha;
	}

	public dynamic function updateIconsScale(elapsed:Float)
	{
		if(iconP1.autoUpdate)
		{
			var mult:Float = FlxMath.lerp(iconP1.baseScale, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
			iconP1.scale.set(mult, mult);
			iconP1.updateHitbox();
		}

		if(iconP2.autoUpdate)
		{
			var mult:Float = FlxMath.lerp(iconP2.baseScale, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
			iconP2.scale.set(mult, mult);
			iconP2.updateHitbox();
		}
	}

	public dynamic function updateIconsPosition()
    {
        var iconOffset:Int = 26;
        
        // (the bop's size, the same for an animated icon scaled down to fit)
        var bopP1:Float = iconP1.scale.x / iconP1.baseScale;
        var bopP2:Float = iconP2.scale.x / iconP2.baseScale;
        if(iconP1.autoUpdate) iconP1.x = healthBar.barCenter + (150 * bopP1 - 150) / 2 - iconOffset;
        if(iconP2.autoUpdate) iconP2.x = healthBar.barCenter - (150 * bopP2) / 2 - iconOffset * 2;
    }

	var iconsAnimations:Bool = true;
	function set_health(value:Float):Float 
	{
		health = FlxMath.roundDecimal(value, 5);
		return health;
	}

	function openPauseMenu(fromNetwork:Bool = false)
	{
		if (backend.NetworkManager.connected && !fromNetwork) {
			backend.NetworkManager.send("PAUSE_GAME|" + Conductor.songPosition);
		}
		if (backend.NetworkManager.connected) backend.NetworkManager.log('paused at ' + Math.round(Conductor.songPosition) + (fromNetwork ? ' (by the other player)' : ''));
		// ---------------------------------------------

		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;

		if(FlxG.sound.music != null) {
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}
		if(!cpuControlled)
		{
			for (note in playableStrums)
				if(note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		chartingMode = true;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	public var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null)
		{
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if(ret != LuaUtils.Function_Stop)
			{

				// ---> AVISA O OUTRO PC DA SUA MORTE <---
				if (backend.NetworkManager.connected) {
					backend.NetworkManager.log('died');
					backend.NetworkManager.sendDeath();
				}
				// ---------------------------------------

				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				playableCharacter.stunned = true; //(the opponent, on "Play as Opponent")
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;
				#if VIDEOS_ALLOWED
				if(videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.setFilters([]);

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	public function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime);
			eventNotes.shift();
		}
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float) {
		#if HSCRIPT_ALLOWED
		// V-Slice scripts get the events of the chart before they happen, and can cancel them
		if(backend.VSliceScripts.onChartEvent(eventName, value1, value2, strumTime)) return;
		var vsliceEvent:Bool = backend.VSliceScripts.ownChartEvent;
		#else
		var vsliceEvent:Bool = false;
		#end

		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;

		// (an event of a V-Slice chart that was already done by its own rules is not one of these, even with the name of one.
		// Nor is a "Change Character" with no character: see `eventPushedUnique()`)
		if(eventName == 'Change Character' && (value2 == null || value2.trim().length < 1)) vsliceEvent = true;
		switch(vsliceEvent ? '' : eventName) {
			case 'Hey!':
				var value:Int = 2;
				switch(value1.toLowerCase().trim()) {
					case 'bf' | 'boyfriend' | '0':
						value = 0;
					case 'gf' | 'girlfriend' | '1':
						value = 1;
				}

				if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if(flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if(ClientPrefs.data.camZooms && FlxG.camera.zoom < 1.35) {
					if(flValue1 == null) flValue1 = 0.015;
					if(flValue2 == null) flValue2 = 0.03;

					FlxG.camera.zoom += flValue1;
					camHUD.zoom += flValue2;
				}

			case 'Play Animation':
				//trace('Anim to play: ' + value1);
				var char:Character = dad;
				switch(value2.toLowerCase().trim()) {
					case 'bf' | 'boyfriend':
						char = boyfriend;
					case 'gf' | 'girlfriend':
						char = gf;
					default:
						if(flValue2 == null) flValue2 = 0;
						switch(Math.round(flValue2)) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.playAnim(value1, true);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					isCameraOnForcedPos = false;
					if(flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if(flValue1 == null) flValue1 = 0;
						if(flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Alt Idle Animation':
				var char:Character = dad;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						char = gf;
					case 'boyfriend' | 'bf':
						char = boyfriend;
					default:
						var val:Int = Std.parseInt(value1);
						if(Math.isNaN(val)) val = 0;

						switch(val) {
							case 1: char = boyfriend;
							case 2: char = gf;
						}
				}

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character' if(Character.characterExists(value2)):
				var charType:Int = 0;
				switch(value1.toLowerCase().trim()) {
					case 'gf' | 'girlfriend':
						charType = 2;
					case 'dad' | 'opponent':
						charType = 1;
					default:
						charType = Std.parseInt(value1);
						if(Math.isNaN(charType)) charType = 0;
				}

				switch(charType) {
					case 0:
						// --- CÓDIGO DO CHARACTER SELECTOR GLOBAL ---
						var isCustomSkinActive = (backend.PlayableCharacters.getOverride(SONG) != null);
						
						// Só permite a mudança de personagem se NÃO estiver usando uma skin customizada!
						if (!isCustomSkinActive) {
							if(boyfriend.curCharacter != value2) {
								if(!boyfriendMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = boyfriend.alpha;
								boyfriend.alpha = 0.00001;
								boyfriend = boyfriendMap.get(value2);
								boyfriend.alpha = lastAlpha;
								iconP1.changeIcon(boyfriend.healthIcon);
							}
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);
						// ---------------------------------------------

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							dad.alpha = 0.00001;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf') {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								gf.alpha = 0.00001;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
				}
				reloadHealthBarColors();

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					if(flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {ease: FlxEase.linear, onComplete:
							function (twn:FlxTween)
							{
								songSpeedTween = null;
							}
						});
				}

			case 'Set Property':
				try
				{
					var trueValue:Dynamic = value2.trim();
					if (trueValue == 'true' || trueValue == 'false') trueValue = trueValue == 'true';
					else if (flValue2 != null) trueValue = flValue2;
					else trueValue = value2;

					var split:Array<String> = value1.split('.');
					if(split.length > 1) {
						LuaUtils.setVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1], trueValue);
					} else {
						LuaUtils.setVarInArray(this, value1, trueValue);
					}
				}
				catch(e:Dynamic)
				{
					var len:Int = e.message.indexOf('\n') + 1;
					if(len <= 0) len = e.message.length;
					#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
					addTextToDebug('ERROR ("Set Property" Event) - ' + e.message.substr(0, len), FlxColor.RED);
					#else
					FlxG.log.warn('ERROR ("Set Property" Event) - ' + e.message.substr(0, len));
					#end
				}

			case 'Play Sound':
				if(flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', [eventName, value1, value2, strumTime]);
	}

	public function moveCameraSection(?sec:Null<Int>):Void {
		if(sec == null) sec = curSection;
		if(sec < 0) sec = 0;

		if(SONG.notes[sec] == null) return;

		if (gf != null && SONG.notes[sec].gfSection)
		{
			moveCameraToGirlfriend();
			callOnScripts('onMoveCamera', ['gf']);
			return;
		}

		var isDad:Bool = (SONG.notes[sec].mustHitSection != true);
		moveCamera(isDad);
		if (isDad)
			callOnScripts('onMoveCamera', ['dad']);
		else
			callOnScripts('onMoveCamera', ['boyfriend']);
	}
	
	public function moveCameraToGirlfriend()
	{
		camFollow.setPosition(gf.getCameraCenter().x, gf.getCameraCenter().y);
		camFollow.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
		camFollow.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];
		tweenCamIn();
	}

	var cameraTwn:FlxTween;
	public function moveCamera(isDad:Bool)
	{
		if(isDad)
		{
			if(dad == null) return;
			camFollow.setPosition(dad.getCameraCenter().x + 150, dad.getCameraCenter().y - 100);
			camFollow.x += dad.cameraPosition[0] + opponentCameraOffset[0];
			camFollow.y += dad.cameraPosition[1] + opponentCameraOffset[1];
			tweenCamIn();
		}
		else
		{
			if(boyfriend == null) return;
			camFollow.setPosition(boyfriend.getCameraCenter().x - 100, boyfriend.getCameraCenter().y - 100);
			camFollow.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
			camFollow.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1)
			{
				cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
					function (twn:FlxTween)
					{
						cameraTwn = null;
					}
				});
			}
		}
	}

	public function tweenCamIn() {
		if (songName == 'tutorial' && cameraTwn == null && FlxG.camera.zoom != 1.3) {
			cameraTwn = FlxTween.tween(FlxG.camera, {zoom: 1.3}, (Conductor.stepCrochet * 4 / 1000), {ease: FlxEase.elasticInOut, onComplete:
				function (twn:FlxTween) {
					cameraTwn = null;
				}
			});
		}
	}

	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		opponentVocals.volume = 0;
		opponentVocals.pause();

		if(ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset) {
			endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endCallback();
			});
		}
	}


	public var transitioning = false;
	public function endSong()
	{
		//Should kill you if you tried to cheat
		if(!startingSong)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			});
			for (daNote in unspawnNotes)
			{
				if(daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			}

			if(doDeathCheck()) {
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie' #if BASE_GAME_FILES, 'debugger' #end]);
		#end

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if(ret != LuaUtils.Function_Stop && !transitioning)
		{
			var isNewHighscore:Bool = false;
			#if !switch
			var percent:Float = ratingPercent;
			if(Math.isNaN(percent)) percent = 0;
			// (each mix of a V-Slice song keeps its own scores)
			var scoreSong:String = Highscore.scoreName(Song.loadedSongName, (SONG != null && SONG.vslice != null) ? SONG.vslice.variation : null);
			isNewHighscore = (!cpuControlled && !practiceMode && songScore > Highscore.getScore(scoreSong, storyDifficulty));
			Highscore.saveScore(scoreSong, songScore, storyDifficulty, percent);

			// V-Slice's rank, which is what the Freeplay menu shows by the song
			if(!cpuControlled && !practiceMode && !chartingMode)
			{
				var tallies = getTallies();
				var rank:Null<backend.FreeplayData.FreeplayRank> = backend.FreeplayData.FreeplayRank.fromTallies(tallies.sick, tallies.good, tallies.missed, tallies.totalNotes);
				if(rank != null)
				{
					var clear:Int = Math.floor(backend.FreeplayData.FreeplayRank.getCompletion(tallies.sick, tallies.good, tallies.missed, tallies.totalNotes) * 100);
					Highscore.saveRank(scoreSong, storyDifficulty, rank, clear);
				}
			}
			#end
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;
				addToCampaignTallies();

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					// the results screen of the week comes first if it's on, and goes to the menu by itself
					if(!openResults(false))
					{
						backend.StickerTransition.prepare();
						Mods.loadTopMod();
						FlxG.sound.playMusic(Paths.music('freakyMenu'));
						#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

						canResync = false;
						backend.StickerTransition.switchState(new StoryMenuState());
					}

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay')) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);

						FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
						FlxG.save.flush();
					}
					changedDifficulty = false;
				}
				else
				{
					var difficulty:String = Difficulty.getFilePath();

					trace('LOADING NEXT SONG');
					trace(Paths.formatToSongPath(PlayState.storyPlaylist[0]) + difficulty);
					backend.StepLog.add('Song ended, loading the next one of the week: ' + PlayState.storyPlaylist[0] + difficulty);

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					Song.loadFromJson(PlayState.storyPlaylist[0] + difficulty, PlayState.storyPlaylist[0]);
					FlxG.sound.music.stop();
					backend.StepLog.add('Chart loaded, preparing what the song needs');

					canResync = false;
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState(), false, false);
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				
				// ---> CORREÇÃO: REDIRECIONAR PARA O LOBBY AO TERMINAR A MÚSICA <---
				var isMultiplayer:Bool = (backend.NetworkManager.socket != null && backend.NetworkManager.connected);
				
				// Se for Multiplayer, pula a tela de resultados e vai pro Lobby
				if(isMultiplayer || !openResults(isNewHighscore))
				{
					backend.StickerTransition.prepare();
					Mods.loadTopMod();
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					canResync = false;
					
					if (isMultiplayer) {
						// Volta pro Lobby com a conexão aberta: o Host já pode escolher a próxima música
						backend.StickerTransition.switchState(new states.MultiplayerMenuState());
					}
					else if (ClientPrefs.data.freeplayStyle == 'V-Slice') {
						backend.StickerTransition.switchState(new FreeplayStateVslice());
					} else {
						backend.StickerTransition.switchState(new FreeplayState());
					}
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				changedDifficulty = false;
			}
			transitioning = true;
		}
		return true;
	}

	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	public var totalPlayed:Int = 0;
	public var totalNotesHit:Float = 0.0;

	// ------------------------------------------------------------------------------------------
	// Results screen
	// ------------------------------------------------------------------------------------------

	/**
	 * Biggest combo of the song.
	 */
	public var maxCombo:Int = 0;

	// What was done on the songs of the week being played, for the results screen at its end
	public static var campaignTallies:states.ResultsState.ResultsTallies = null;
	static var campaignNotesHit:Float = 0;
	static var campaignPlayed:Int = 0;

	public static function resetCampaignTallies():Void
	{
		campaignTallies = {sick: 0, good: 0, bad: 0, shit: 0, missed: 0, combo: 0, maxCombo: 0, totalNotesHit: 0, totalNotes: 0};
		campaignNotesHit = 0;
		campaignPlayed = 0;
	}

	// ------------------------------------------------------------------------------------------
	// For scripts: the engine's options of the song, changed while it's being played

	// (under the long notes, which are on a camera under the HUD's: on the HUD's they'd darken them)
	function makeLaneCamera():Void
	{
		if (camLanes != null) return;
		camLanes = new FlxCamera();
		camLanes.bgColor.alpha = 0;
		var under:Int = (camSus != null) ? FlxG.cameras.list.indexOf(camSus) : -1;
		if (under < 0)
		{
			FlxG.cameras.add(camLanes, false);
			return;
		}
		// (flixel has no way to put a camera between others: the ones from there on are taken out and put back after it)
		var after:Array<FlxCamera> = FlxG.cameras.list.slice(under);
		@:privateAccess var drawTargets:Array<Bool> = [for (camera in after) FlxG.cameras.defaults.contains(camera)];
		for (camera in after) FlxG.cameras.remove(camera, false);
		FlxG.cameras.add(camLanes, false);
		for (i => camera in after) FlxG.cameras.add(camera, drawTargets[i]);
	}

	function makeLaneUnderlays(fadeIn:Bool):Void
	{
		if (laneUnderlays != null || playableStrums.length < 4) return;
		makeLaneCamera();

		laneUnderlays = new FlxTypedGroup<FlxSprite>();
		for (i in 0...4)
		{
			var lane:FlxSprite = new FlxSprite(playableStrums.members[i].x, -FlxG.height).makeGraphic(1, 1, FlxColor.BLACK);
			lane.scale.set(112, FlxG.height * 3);
			lane.updateHitbox();
			lane.alpha = fadeIn ? 0 : laneUnderlayAlpha;
			lane.cameras = [camLanes];
			laneUnderlays.add(lane);
			if (fadeIn) FlxTween.tween(lane, {alpha: laneUnderlayAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
		}
		insert(members.indexOf(uiGroup), laneUnderlays);
	}

	/**
	 * Turns "Lane Underlay" (the dark lanes under the notes being played) on or off, whatever the option says.
	 * @param alpha How dark they are, from 0 to 1 (0.5 if not given).
	 */
	public function setLaneUnderlay(show:Bool, ?alpha:Float):Void
	{
		showLaneUnderlay = show;
		if (alpha != null) laneUnderlayAlpha = FlxMath.bound(alpha, 0, 1);
		if (show && playableStrums.length >= 4) makeLaneUnderlays(false);
		else if (show) makeLaneCamera(); //(the lanes are made with the receptors)
	}

	/**
	 * Where the ratings, combo numbers and "Combo" go: "game" (in the scene, moving with it) or "hud" (on the screen).
	 */
	public function setScoreCamera(where:String):Void
	{
		scoreCamera = (where != null && where.toLowerCase() == 'game') ? 'Game' : 'HUD';
		if (comboGroup != null) comboGroup.cameras = [scoreCamera == 'Game' ? camGame : camHUD];
	}

	/**
	 * Hides the notes (the "Hidden Notes" gameplay changer), the ones already coming too, or shows them again.
	 */
	public function setHiddenNotes(hide:Bool):Void
	{
		hiddennotes = hide;
		for (note in notes.members)
			if (note != null && note.alive)
				note.visible = !hide;
	}

	/**
	 * How many notes got each judgement on this song.
	 */
	public function getTallies():states.ResultsState.ResultsTallies
	{
		var tallies:states.ResultsState.ResultsTallies = {sick: 0, good: 0, bad: 0, shit: 0, missed: songMisses, combo: combo, maxCombo: maxCombo, totalNotesHit: 0, totalNotes: 0};
		for (rating in ratingsData)
		{
			switch(rating.name)
			{
				case 'sick': tallies.sick += rating.hits;
				case 'good': tallies.good += rating.hits;
				case 'bad': tallies.bad += rating.hits;
				case 'shit': tallies.shit += rating.hits;
			}
			tallies.totalNotesHit += rating.hits;
		}
		tallies.totalNotes = tallies.totalNotesHit + tallies.missed;
		return tallies;
	}

	// Adds this song to what the week has so far
	function addToCampaignTallies():Void
	{
		if(campaignTallies == null) resetCampaignTallies();

		var tallies = getTallies();
		campaignTallies.sick += tallies.sick;
		campaignTallies.good += tallies.good;
		campaignTallies.bad += tallies.bad;
		campaignTallies.shit += tallies.shit;
		campaignTallies.missed += tallies.missed;
		campaignTallies.totalNotesHit += tallies.totalNotesHit;
		campaignTallies.totalNotes += tallies.totalNotes;
		campaignTallies.combo = tallies.combo;
		if(tallies.maxCombo > campaignTallies.maxCombo) campaignTallies.maxCombo = tallies.maxCombo;

		campaignNotesHit += totalNotesHit;
		campaignPlayed += totalPlayed;
	}

	/**
	 * Goes to V-Slice's results screen, about the song that just ended or about the whole week if it was its last song.
	 * Returns false if the screen is turned off, and nothing is done.
	 */
	function openResults(isNewHighscore:Bool):Bool
	{
		if(!ClientPrefs.data.resultsScreen) return false;

		var tallies:states.ResultsState.ResultsTallies = getTallies();
		var accuracy:Float = ratingPercent;
		var title:String = SONG.song;

		var songData:Dynamic = SONG.vslice;
		if(songData != null && songData.artist != null && songData.artist != 'Unknown') title += ' by ' + songData.artist;

		if(isStoryMode)
		{
			if(campaignTallies != null) tallies = campaignTallies;
			accuracy = (campaignPlayed > 0) ? campaignNotesHit / campaignPlayed : 0;

			var week:WeekData = WeekData.getCurrentWeek();
			title = (week != null && week.storyName != null && week.storyName.length > 0) ? week.storyName : WeekData.getWeekFileName();
		}
		if(Math.isNaN(accuracy)) accuracy = 0;

		// The results are of the player that was picked, who is the chart's player whichever side was played:
		// with Play as Opponent on it'd be the opponent, who has no results of its own and would be shown as Boyfriend
		var player:Character = boyfriend;
		canResync = false;

		MusicBeatState.switchState(new funkin.play.ResultState({
			storyMode: isStoryMode,
			title: title,
			songId: Paths.formatToSongPath(Song.loadedSongName),
			characterId: (player != null) ? player.curCharacter : SONG.player1,
			isNewHighscore: isNewHighscore,
			isPracticeMode: practiceMode,
			isBotPlayMode: cpuControlled,
			difficultyId: Paths.formatToSongPath(Difficulty.getString(null, false)),
			variationId: (songData != null && songData.variation != null) ? songData.variation : 'default',
			scoreData: {
				score: isStoryMode ? campaignScore : songScore,
				tallies: tallies,
				accuracy: accuracy
			}
		}));
		return true;
	}

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	public var noteGroup:FlxTypedGroup<FlxBasic>;

	private function cachePopUpScore()
	{
		var uiFolder:String = "";
		if (stageUI != "normal")
			uiFolder = uiPrefix + "UI/";

		for (rating in ratingsData)
			Paths.image(uiFolder + rating.image + uiPostfix);
		for (i in 0...10)
			Paths.image(uiFolder + 'num' + i + uiPostfix);
	}

	// The note style the ratings and the combo numbers are drawn with on the songs of V-Slice mods: the song's, or the one a script
	// gave them (`PlayState.instance.comboPopUps.noteStyle`)
	function popUpStyle():funkin.play.notes.notestyle.NoteStyle
	{
		#if HSCRIPT_ALLOWED
		var facade:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(!backend.VSliceScripts.active || facade == null) return null;
		var style:funkin.play.notes.notestyle.NoteStyle = (facade.comboPopUps != null) ? facade.comboPopUps.noteStyle : null;
		return (style != null) ? style : facade.noteStyle;
		#else
		return null;
		#end
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		vocals.volume = 1;

		if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
		{
			for (spr in comboGroup)
			{
				if(spr == null) continue;

				comboGroup.remove(spr);
				spr.destroy();
			}
		}

		var placement:Float = FlxG.width * 0.35;
		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if(daRating.noteSplash && !note.noteSplashData.disabled)
			spawnNoteSplashOnNote(note);

		if(!cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var uiFolder:String = "";
		var antialias:Bool = ClientPrefs.data.antialiasing;
		if (stageUI != "normal")
		{
			uiFolder = uiPrefix + "UI/";
			antialias = !isPixelStage;
		}

		var style:funkin.play.notes.notestyle.NoteStyle = popUpStyle();
		var ratingLook = (style != null) ? style.getPopUpLook('judgement' + daRating.name.charAt(0).toUpperCase() + daRating.name.substr(1)) : null;
		rating.loadGraphic(Paths.image((ratingLook != null) ? ratingLook.path : uiFolder + daRating.image + uiPostfix));
		rating.screenCenter();
		rating.x = placement - 40;
		rating.y -= 60;
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
		rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
		rating.visible = (!ClientPrefs.data.hideHud && showRating);
		rating.x += ClientPrefs.data.comboOffset[0];
		rating.y -= ClientPrefs.data.comboOffset[1];
		if (scoreCamera == 'Game')
        {
            var scoreChar:Character = playableCharacter;
            var offset:Float = playAsOpponent ? (scoreChar.width + 50) : -250; 
            
            rating.x = scoreChar.x + offset;
            rating.y = scoreChar.y + 50; 
        }
		rating.antialiasing = antialias;

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(uiFolder + 'combo' + uiPostfix));
		comboSpr.screenCenter();
		comboSpr.x = placement;
		comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
		comboSpr.x += ClientPrefs.data.comboOffset[0];
		comboSpr.y -= ClientPrefs.data.comboOffset[1];
		comboSpr.antialiasing = antialias;
		comboSpr.y += 60;
		comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;



		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
		}
		if (ratingLook != null)
		{
			rating.scale.set(ratingLook.scale, ratingLook.scale);
			rating.antialiasing = !ratingLook.pixel && ClientPrefs.data.antialiasing;
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();

		var daLoop:Int = 0;
		var xThing:Float = 0;

		if (!cpuControlled)
		{
			comboGroup.add(rating);
			if (showCombo)
				comboGroup.add(comboSpr);
		}

		var separatedScore:String = Std.string(combo).lpad('0', 3);
		for (i in 0...separatedScore.length)
		{
			var digit:Int = Std.parseInt(separatedScore.charAt(i));
			var digitLook = (style != null) ? style.getPopUpLook('comboNumber$digit') : null;
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image((digitLook != null) ? digitLook.path : uiFolder + 'num' + digit + uiPostfix));
			numScore.screenCenter();
			numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
			numScore.y += 80 - ClientPrefs.data.comboOffset[3];
			if (scoreCamera == 'Game')
            {
                var scoreChar:Character = playableCharacter;
                var offset:Float = playAsOpponent ? (scoreChar.width + 60) : -240;
                
                numScore.x = scoreChar.x + offset + (43 * i);
                numScore.y = scoreChar.y + 160; 
            }

			if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			else numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			if (digitLook != null) numScore.scale.set(digitLook.scale, digitLook.scale);
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
			numScore.visible = !ClientPrefs.data.hideHud;
			numScore.antialiasing = (digitLook != null) ? (!digitLook.pixel && ClientPrefs.data.antialiasing) : antialias;

			//if (combo >= 10 || combo == 0)
			if(showComboNum && !cpuControlled)
				comboGroup.add(numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});

			daLoop++;
			if(numScore.x > xThing) xThing = numScore.x;
		}
		comboSpr.x = xThing + 50;
		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
			startDelay: Conductor.crochet * 0.001 / playbackRate
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
			onComplete: function(tween:FlxTween)
			{
				comboSpr.destroy();
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.002 / playbackRate
		});
	}

	public var strumsBlocked:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{

		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			//Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
			#end

			if(FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if(cpuControlled || paused || inCutscene || key < 0 || key >= playableStrums.length || !generatedMusic || endingSong || playableCharacter.stunned) return;

		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if(Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		// obtain notes that the player can hit
		var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note):Bool {
			var canHit:Bool = n != null && !strumsBlocked[n.noteData] && n.canBeHit && n.playable && !n.tooLate && !n.wasGoodHit && !n.blockHit;
			return canHit && !n.isSustainNote && n.noteData == key;
		});
		plrInputNotes.sort(sortHitNotes);

		if (plrInputNotes.length != 0) { // slightly faster than doing `> 0` lol
			var funnyNote:Note = plrInputNotes[0]; // front note

			if (plrInputNotes.length > 1) {
				var doubleNote:Note = plrInputNotes[1];

				if (doubleNote.noteData == funnyNote.noteData) {
					// if the note has a 0ms distance (is on top of the current note), kill it
					if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0)
						invalidateNote(doubleNote);
					else if (doubleNote.strumTime < funnyNote.strumTime)
					{
						// replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
						funnyNote = doubleNote;
					}
				}
			}
			goodNoteHit(funnyNote);
		}
		else
		{
			if (ClientPrefs.data.ghostTapping)
				callOnScripts('onGhostTap', [key]);
			else
				noteMissPress(key);
		}

		// Needed for the  "Just the Two of Us" achievement.
		//									- Shadow Mario
		if(!keysPressed.contains(key)) keysPressed.push(key);

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;

		var spr:StrumNote = playableStrums.members[key];
		if(strumsBlocked[key] != true && spr != null && (spr.animation.curAnim == null || spr.animation.curAnim.name != 'confirm'))
		{
			spr.playAnim('pressed');
			spr.resetAnim = 0;
		}

		// ---> ADICIONADO AQUI: Envia que a tecla foi pressionada! <---
		if (backend.NetworkManager.connected) {
			backend.NetworkManager.send("KEY_PRESS|" + key);
		}

		callOnScripts('onKeyPress', [key]);
	}

	public static function sortHitNotes(a:Note, b:Note):Int
	{
		if (a.lowPriority && !b.lowPriority)
			return 1;
		else if (!a.lowPriority && b.lowPriority)
			return -1;

		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if(cpuControlled || !startedCountdown || paused || key < 0 || key >= playableStrums.length) return;

		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		var spr:StrumNote = playableStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}

		// ---> ADICIONADO AQUI: Envia que a tecla foi solta! <---
		if (backend.NetworkManager.connected) {
			backend.NetworkManager.send("KEY_RELEASE|" + key);
		}

		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if(key == noteKey)
						return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i] && strumsBlocked[i] != true)
					keyPressed(i);

		if (startedCountdown && !inCutscene && !playableCharacter.stunned && generatedMusic)
		{
			if (notes.length > 0) {
				for (n in notes) { // I can't do a filter here, that's kinda awesome
					var canHit:Bool = (n != null && !strumsBlocked[n.noteData] && n.canBeHit
						&& n.playable && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote) {
						var released:Bool = !holdArray[n.noteData];

						if (!released)
							goodNoteHit(n);
					}
				}
			}

			if (!holdArray.contains(true) || endingSong || playAsOpponent)
				playerDance();

			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if((controls.controllerMode || strumsBlocked.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i] || strumsBlocked[i] == true)
					keyReleased(i);
	}

	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		#if HSCRIPT_ALLOWED
		if(backend.VSliceScripts.onNoteMiss(daNote)) return; //a V-Slice script dealt with it, like the notes that aren't supposed to be hit
		#end

		// a long note that was let go, or not hit at all
		if(grpHoldCovers != null && (daNote.isSustainNote || daNote.tail.length > 0)) grpHoldCovers.drop(strumOf(daNote));

		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress == note.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});

		noteMissCommon(daNote.noteData, daNote);

		if (backend.NetworkManager.connected && daNote.playable) {
			backend.NetworkManager.send("MISS|" + daNote.noteData + "|" + (daNote.isSustainNote ? "1" : "0"));
		}

		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	function noteMissPress(direction:Int = 1):Void //You pressed a key when there was no notes to press for this key
	{
		if(ClientPrefs.data.ghostTapping) return; //fuck it

		noteMissCommon(direction);

		if (backend.NetworkManager.connected) {
			backend.NetworkManager.send("MISSPRESS|" + direction);
		}

		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, note:Note = null)
	{
		// score and data
		var subtract:Float = pressMissDamage;
		if(note != null) subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null) {
			if(note.tail.length > 0) {
				note.alpha = 0.35;
				for(childNote in note.tail) {
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				//subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -[REDACTED]
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote) {
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != note) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		if(instakillOnMiss)
		{
			vocals.volume = 0;
			opponentVocals.volume = 0;
			doDeathCheck(true);
		}

		var lastCombo:Int = combo;
		combo = 0;

		health -= subtract * healthLoss;
		songScore -= 10;
		if(!endingSong) songMisses++;
		totalPlayed++;
		RecalculateRating(true);

		// play character anims
		var char:Character = playableCharacter;
		if((note != null && note.gfNote) || (SONG.notes[curSection] != null && SONG.notes[curSection].gfSection)) char = gf;

		#if HSCRIPT_ALLOWED
		// (on V-Slice's songs the ones that miss are whoever is singing the player's side: see backend.VSliceScripts)
		char = backend.VSliceScripts.missCharacters(char, direction, note);
		#end

		if(char != null && (note == null || !note.noMissAnimation) && char.hasMissAnimations)
		{
			var postfix:String = '';
			if(note != null) postfix = note.animSuffix;

			var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, direction)))] + 'miss' + postfix;
			char.playAnim(animToPlay, true);

			if(char != gf && lastCombo > 5 && gf != null && gf.hasAnimation('sad'))
			{
				gf.playAnim('sad');
				gf.specialAnim = true;
			}
		}
		//playableVoice().volume = 0;
	}

	function opponentNoteHit(note:Note):Void
	{
		if (healthDrain > 0)
        {
            var balancedDrain:Float = healthDrain * 0.1;

            if (note.isSustainNote) {
                health -= balancedDrain * 0.02; 
            } else {
                health -= balancedDrain;
            }
            if (health < 0.01) {
                health = 0.01;
            }
        }

        // (only notes that are sung count: the ghost is the pose of the last one, so it has to be the same character's)
        if (!note.isSustainNote && !note.noAnimation && !note.hitCausesMiss)
        {
            var singer:Character = (note.gfNote || note.noteType == 'GF Sing') ? gf : otherCharacter;
            var timeDiff = Math.abs(note.strumTime - lastOpponentHitTime);
            
            if (timeDiff <= 35 && ghostNotes && singer == lastOpponentSinger)
                spawnGhost(singer, lastOpponentNoteData);
            
            lastOpponentHitTime = note.strumTime;
            lastOpponentNoteData = note.noteData;
            lastOpponentSinger = singer;
        }

		//var result:Dynamic = callOnLuas('opponentNoteHitPre', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		// (scripts are told by the side of the song the note is on: the player's notes are "goodNoteHit" whoever hits them)
		var luaPre = note.mustPress ? 'goodNoteHitPre' : 'opponentNoteHitPre';
		var result:Dynamic = callOnLuas(luaPre, [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript(luaPre, [note]);

		if(result == LuaUtils.Function_Stop) return;

		if (songName != 'tutorial')
			camZooming = true;

        var botChar:Character = note.mustPress ? boyfriend : dad;

        if(note.noteType == 'Hey!' && botChar.hasAnimation('hey'))
        {
            botChar.playAnim('hey', true);
            botChar.specialAnim = true;
            botChar.heyTimer = 0.6;
        }
        else if(!note.noAnimation)
        {
            var char:Character = botChar;
            var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
            if(note.gfNote) char = gf;

            if(char != null)
            {
                var canPlay:Bool = true;
                if(note.isSustainNote)
                {
                    var holdAnim:String = animToPlay + '-hold';
                    if(char.animation.exists(holdAnim)) animToPlay = holdAnim;
                    if(char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
                    // (a long note keeps the singing going, it doesn't cut what an event or a script made the character do)
                    if(char.specialAnim) canPlay = false;
                    if(!char.canRestartForHold()) canPlay = false;
                }

                if(canPlay) char.playAnim(animToPlay, true);
                char.holdTimer = 0;
            }
        }

        if(playAsOpponent || opponentVocals.length <= 0) vocals.volume = 1;
        strumPlayAnim(!note.mustPress, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
        note.hitByOpponent = true;
        if(grpHoldCovers != null) grpHoldCovers.noteHit(note, strumOf(note), false);
        
        if(note.mustPress) stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
        else stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		var luaEvent = note.mustPress ? 'goodNoteHit' : 'opponentNoteHit';
        var result:Dynamic = callOnLuas(luaEvent, [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
        if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript(luaEvent, [note]);

        if (!note.isSustainNote) invalidateNote(note);

        if (note.isSustainNote)
        {
            if (note.gfNote || note.noteType == 'GF Sing')
            {
                if (gf != null) gf.holdTimer = 0;
            }
            else
            {
                botChar.holdTimer = 0;
            }
        }
	}

	public function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;

        if (!note.isSustainNote && !note.noAnimation && !note.hitCausesMiss)
        {
            var singer:Character = (note.gfNote || note.noteType == 'GF Sing') ? gf : playableCharacter;
            var timeDiff = Math.abs(note.strumTime - lastPlayerHitTime);
            
            if (timeDiff <= 35 && ghostNotes && singer == lastPlayerSinger)
                spawnGhost(singer, lastPlayerNoteData);
            
            lastPlayerHitTime = note.strumTime;
            lastPlayerNoteData = note.noteData;
            lastPlayerSinger = singer;
        }

		if(cpuControlled && note.ignoreNote) return;

		var isSus:Bool = note.isSustainNote;
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		//var result:Dynamic = callOnLuas('goodNoteHitPre', [notes.members.indexOf(note), leData, leType, isSus]);
		// Songs that take health away whenever the opponent sings do it on these callbacks, to be hard on the player.
		// With the opponent being the one played, these are the notes that were just hit right: they don't cost health
		var healthBefore:Float = health;
		var luaPre = note.mustPress ? 'goodNoteHitPre' : 'opponentNoteHitPre';
		var result:Dynamic = callOnLuas(luaPre, [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript(luaPre, [note]);
		if(playAsOpponent && health < healthBefore) health = healthBefore;

		if(result == LuaUtils.Function_Stop) return;

		note.wasGoodHit = true;

		if (backend.NetworkManager.connected && note.playable) {
			var isSus:String = note.isSustainNote ? "1" : "0";
			backend.NetworkManager.send("HIT|" + note.noteData + "|" + isSus);
		}

		if (note.hitsoundVolume > 0 && !note.hitsoundDisabled)
			FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);

		var playerChar:Character = note.mustPress ? boyfriend : dad;

		if(!note.hitCausesMiss)
		{
			if(!note.noAnimation)
			{
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;

				var char:Character = playerChar;
				var animCheck:String = 'hey';
				if(note.gfNote)
				{
					char = gf;
					animCheck = 'cheer';
				}

				if(char != null)
				{
					var canPlay:Bool = true;
					if(note.isSustainNote)
					{
						var holdAnim:String = animToPlay + '-hold';
						if(char.animation.exists(holdAnim)) animToPlay = holdAnim;
						if(char.getAnimationName() == holdAnim || char.getAnimationName() == holdAnim + '-loop') canPlay = false;
						// (a long note keeps the singing going, it doesn't cut what an event or a script made the character do)
						if(char.specialAnim) canPlay = false;
						if(!char.canRestartForHold()) canPlay = false;
					}
	
					if(canPlay) char.playAnim(animToPlay, true);
					char.holdTimer = 0;

					if(note.noteType == 'Hey!')
					{
						if(char.hasAnimation(animCheck))
						{
							char.playAnim(animCheck, true);
							char.specialAnim = true;
							char.heyTimer = 0.6;
						}
					}
				}
			}

			if(!cpuControlled)
			{
				var spr = strumOf(note);
				if(spr != null) spr.playAnim('confirm', true);
			}
			else strumPlayAnim(!note.mustPress, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			playableVoice().volume = 1;
			if(grpHoldCovers != null) grpHoldCovers.noteHit(note, strumOf(note), true);

			if (!note.isSustainNote)
			{
				combo++;
				if(combo > 9999) combo = 9999;
				if(combo > maxCombo) maxCombo = combo;
				popUpScore(note);
			}
			var gainHealth:Bool = true;
			if (guitarHeroSustains && note.isSustainNote) gainHealth = false;
			
			if (gainHealth) {
				health += note.hitHealth * healthGain;
				
				// ---> LIMITE SEGURO DE ACERTOS <---
				// Se estiver no multiplayer, seus acertos só enchem a vida até 1.75.
				// Isso impede que você mate o oponente apenas "jogando bem".
				if (backend.NetworkManager.connected && health > 1.75) {
					health = 1.75;
				}
			}

		}
		else
		{
			if(!note.noMissAnimation)
			{
				switch(note.noteType)
				{
					case 'Hurt Note':
						if(playerChar.hasAnimation('hurt'))
						{
							playerChar.playAnim('hurt', true);
							playerChar.specialAnim = true;
						}
				}
			}

			noteMiss(note);
			if(!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);
		}

		if(note.mustPress) stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
		else stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		healthBefore = health;
		var luaEvent = note.mustPress ? 'goodNoteHit' : 'opponentNoteHit';
		var result:Dynamic = callOnLuas(luaEvent, [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript(luaEvent, [note]);
		if(playAsOpponent && health < healthBefore) health = healthBefore;

		if(!note.isSustainNote) invalidateNote(note);

        if (note.isSustainNote)
        {
            if (note.gfNote || note.noteType == 'GF Sing')
            {
                if (gf != null) gf.holdTimer = 0;
            }
            else
            {
                playerChar.holdTimer = 0;
            }
        }
	}

	public function invalidateNote(note:Note):Void {
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	public function spawnNoteSplashOnNote(note:Note) {
		if(note != null) {
			var strum:StrumNote = strumOf(note);
			if(strum != null)
				spawnNoteSplash(strum.psychX, strum.psychY, note.noteData, note, strum);
		}
	}

	public function spawnNoteSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote, ?texture:String) {
		if (cpuControlled) return;
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note, true, texture);
		grpNoteSplashes.add(splash);
	}

	override function destroy() {
		Note.opponentPlay = false;

		if (psychlua.CustomSubstate.instance != null)
		{
			closeSubState();
			resetSubState();
		}

		#if LUA_ALLOWED
		for (lua in luaArray)
		{
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = null;
		FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			if(script != null)
			{
				if(script.exists('onDestroy')) script.call('onDestroy');
				script.destroy();
			}

		hscriptArray = null;
		backend.VSliceScripts.destroy();
		#end
		stagesFunc(function(stage:BaseStage) stage.destroy());

		#if VIDEOS_ALLOWED
		if(videoCutscene != null)
		{
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.setFilters([]);

		#if FLX_PITCH FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		NoteSplash.configs.clear();
		instance = null;
		super.destroy();
	}

	var lastStepHit:Int = -1;
	override function stepHit()
	{
		super.stepHit();

		if(curStep == lastStepHit) {
			return;
		}

		// ===================================
		// MULTIPLAYER: HOST DITA A VIDA GLOBAL
		if (backend.NetworkManager.connected && backend.NetworkManager.isHost) {
			// a vida só vai quando mudou (ou de vez em quando, para garantir)
			if (Math.abs(health - lastSentHealth) > 0.0005 || curStep - lastHealthStep >= 16) {
				backend.NetworkManager.send("SYNC_HEALTH|" + health);
				lastSentHealth = health;
				lastHealthStep = curStep;
			}
		}
		// ===================================

		lastStepHit = curStep;
		setOnScripts('curStep', curStep);
		callOnScripts('onStepHit');
	}

	var lastBeatHit:Int = -1;

	override function beatHit()
	{
		if(lastBeatHit >= curBeat) {
			//trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
			return;
		}

		if (generatedMusic)
			notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);

		iconP1.scale.set(1.2 * iconP1.baseScale, 1.2 * iconP1.baseScale);
		iconP2.scale.set(1.2 * iconP2.baseScale, 1.2 * iconP2.baseScale);

		iconP1.updateHitbox();
		iconP2.updateHitbox();

		characterBopper(curBeat);
		vslicePropsBop(curBeat);

		super.beatHit();
		lastBeatHit = curBeat;

		setOnScripts('curBeat', curBeat);
		callOnScripts('onBeatHit');

		if (iconBop) 
        {
			var turnvalue:Float = (curBeat % 2 == 0) ? -20 : 20;

			iconP1.angle = turnvalue;
			iconP2.angle = -turnvalue;

			FlxTween.cancelTweensOf(iconP1, ['angle']);
			FlxTween.cancelTweensOf(iconP2, ['angle']);

			FlxTween.tween(iconP1, {angle: 0}, Conductor.crochet / 1000, {ease: FlxEase.circOut});
			FlxTween.tween(iconP2, {angle: 0}, Conductor.crochet / 1000, {ease: FlxEase.circOut});
		}

		if (susWiggle != null && curBeat % 2 == 0 && sustainWiggle) 
        {
            susWiggle.waveAmplitude = 0.035;
            susWiggle.waveFrequency = 10;
        }
	}

	public function characterBopper(beat:Int):Void
	{
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
			gf.dance();
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
			boyfriend.dance();
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
			dad.dance();
	}

	public function playerDance():Void
	{
		var anim:String = boyfriend.getAnimationName();
		if(boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
			boyfriend.dance();
	}

	override function sectionHit()
	{
		if (SONG.notes[curSection] != null)
		{
			if (generatedMusic && !endingSong && !isCameraOnForcedPos)
				moveCameraSection();

			if (camZooming && FlxG.camera.zoom < 1.35 && ClientPrefs.data.camZooms)
			{
				FlxG.camera.zoom += 0.015 * camZoomingMult;
				camHUD.zoom += 0.03 * camZoomingMult;
			}

			if (SONG.notes[curSection].changeBPM)
			{
				Conductor.bpm = SONG.notes[curSection].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('mustHitSection', SONG.notes[curSection].mustHitSection);
			setOnScripts('altAnim', SONG.notes[curSection].altAnim);
			setOnScripts('gfSection', SONG.notes[curSection].gfSection);
		}
		super.sectionHit();

		setOnScripts('curSection', curSection);
		callOnScripts('onSectionHit');
	}

	#if LUA_ALLOWED
	public function startLuasNamed(luaFile:String)
	{
		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getSharedPath(luaFile);

		if(FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getSharedPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if(script.scriptName == luaToLoad) return false;

			new FunkinLua(luaToLoad);
			return true;
		}
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public function startHScriptsNamed(scriptFile:String)
	{
		#if MODS_ALLOWED
		var scriptToLoad:String = Paths.modFolders(scriptFile);
		if(!FileSystem.exists(scriptToLoad))
			scriptToLoad = Paths.getSharedPath(scriptFile);
		#else
		var scriptToLoad:String = Paths.getSharedPath(scriptFile);
		#end

		if(FileSystem.exists(scriptToLoad))
		{
			if (Iris.instances.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}

	public function initHScript(file:String)
	{
		var newScript:HScript = null;
		try
		{
			newScript = new HScript(null, file);
			if (newScript.exists('onCreate')) newScript.call('onCreate');
			trace('initialized hscript interp successfully: $file');
			hscriptArray.push(newScript);
		}
		catch(e:IrisError)
		{
			var pos:HScriptInfos = cast {fileName: file, showLine: false};
			Iris.error(Printer.errorToString(e, false), pos);
			var newScript:HScript = cast (Iris.instances.get(file), HScript);
			if(newScript != null)
				newScript.destroy();
		}
	}
	#end

	public function callOnScripts(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var result:Dynamic = callOnLuas(funcToCall, args, ignoreStops, exclusions, excludeValues);
		if(result == null || excludeValues.contains(result)) result = callOnHScript(funcToCall, args, ignoreStops, exclusions, excludeValues);
		return result;
	}

	public function callOnLuas(funcToCall:String, args:Array<Dynamic> = null, ignoreStops = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if(args == null) args = [];
		if(exclusions == null) exclusions = [];
		if(excludeValues == null) excludeValues = [LuaUtils.Function_Continue];

		var arr:Array<FunkinLua> = [];
		for (script in luaArray)
		{
			if(script.closed)
			{
				arr.push(script);
				continue;
			}

			if(exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(funcToCall, args);
			if((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
			{
				returnVal = myValue;
				break;
			}

			if(myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if(script.closed) arr.push(script);
		}

		if(arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}

	public function callOnHScript(funcToCall:String, args:Array<Dynamic> = null, ?ignoreStops:Bool = false, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		// Scripts of V-Slice mods (.hxc) hear about everything through here too, and can stop the same things
		if(backend.VSliceScripts.onCallback(funcToCall, args)) returnVal = LuaUtils.Function_Stop;

		if(exclusions == null) exclusions = new Array();
		if(excludeValues == null) excludeValues = new Array();
		excludeValues.push(LuaUtils.Function_Continue);

		var len:Int = hscriptArray.length;
		if (len < 1)
			return returnVal;

		for(script in hscriptArray)
		{
			@:privateAccess
			if(script == null || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if(callValue != null)
			{
				var myValue:Dynamic = callValue.returnValue;

				if((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops)
				{
					returnVal = myValue;
					break;
				}

				if(myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}

	public function setOnScripts(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		if(exclusions == null) exclusions = [];
		setOnLuas(variable, arg, exclusions);
		setOnHScript(variable, arg, exclusions);
	}

	public function setOnLuas(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if LUA_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	public function setOnHScript(variable:String, arg:Dynamic, exclusions:Array<String> = null) {
		#if HSCRIPT_ALLOWED
		if(exclusions == null) exclusions = [];
		for (script in hscriptArray) {
			if(exclusions.contains(script.origin))
				continue;

			script.set(variable, arg);
		}
		#end
	}

	// ------------------------------------------------------------------------------------------
	// Play as Opponent: keeping what has to be hit where it can be seen
	// ------------------------------------------------------------------------------------------

	// Songs are made with the opponent's notes as something to look at, not to play: mods hide them, shrink them, send them off the
	// screen or put the player's on top of them, and none of that was meant for someone who has to hit those notes. Mods are left to
	// do what they want with them (their modcharts play like they would on the player's side) up to the point where the notes
	// can't be played anymore: that's what this is for, and only while there are notes coming.

	static inline final GUARD_MARGIN:Float = 30; //how close to the edges of the screen the middle of a receptor can get
	static inline final GUARD_ALPHA:Float = 0.8; //the least a receptor can be seen
	static inline final GUARD_NOTE_ALPHA:Float = 0.3;

	// Where the receptors being played were put when the song started, and how big they were
	var guardHome:Array<{x:Float, y:Float, scaleX:Float, scaleY:Float}> = [];

	function rememberPlayableStrums():Void
	{
		guardHome = [];
		if(!playAsOpponent) return;

		for (strum in playableStrums.members)
			if(strum != null)
				guardHome.push({x: strum.x, y: strum.y, scaleX: strum.scale.x, scaleY: strum.scale.y});
	}

	// If the one playing has something to hit soon: a note that's already on its way, or one about to show up
	function playableNotesAhead():Bool
	{
		for (note in notes.members)
			if(note != null && note.alive && note.playable && !note.wasGoodHit)
				return true;

		var limit:Float = Conductor.songPosition + 1500 * playbackRate;
		for (note in unspawnNotes)
		{
			if(note.strumTime > limit) break;
			if(note.playable) return true;
		}
		return false;
	}

	function guardPlayableStrums():Void
	{
		if(!playAsOpponent || !generatedMusic || endingSong || guardHome.length < 1) return;
		if(startingSong && Conductor.songPosition < -Conductor.crochet) return; //(they're still showing up)
		if(!playableNotesAhead()) return;

		var strums:Array<StrumNote> = playableStrums.members;
		var reach:Float = Note.swagWidth * 0.35;

		// One of them gone (off the screen, shrunk to nothing, or on top of another one) and the whole line goes back to where
		// it started: four receptors in a row are easier to play than three where the song left them and one somewhere else
		var lost:Bool = false;
		for (i => strum in strums)
		{
			if(strum == null || i >= guardHome.length) continue;

			var home = guardHome[i];
			var middleX:Float = strum.x + strum.width / 2;
			var middleY:Float = strum.y + strum.height / 2;
			if(middleX < GUARD_MARGIN || middleX > FlxG.width - GUARD_MARGIN || middleY < GUARD_MARGIN || middleY > FlxG.height - GUARD_MARGIN) lost = true;
			else if(Math.abs(strum.scale.x) < Math.abs(home.scaleX) * 0.4 || Math.abs(strum.scale.y) < Math.abs(home.scaleY) * 0.4) lost = true;
			else
			{
				for (j in 0...i)
				{
					var other:StrumNote = strums[j];
					if(other != null && Math.abs(other.x - strum.x) < reach && Math.abs(other.y - strum.y) < reach) lost = true;
				}
			}
			if(lost) break;
		}

		for (i => strum in strums)
		{
			if(strum == null || i >= guardHome.length) continue;

			if(lost)
			{
				var home = guardHome[i];
				strum.x = home.x;
				strum.y = home.y;
				strum.scale.set(home.scaleX, home.scaleY);
				strum.angle = 0;
				strum.direction = 90;
			}

			if(!strum.visible) strum.visible = true;
			if(strum.alpha < GUARD_ALPHA) strum.alpha = GUARD_ALPHA;

			// (moved to a camera that isn't being shown)
			@:privateAccess
			var own:Array<FlxCamera> = strum._cameras;
			if(own != null && own.length > 0 && (own[0] == null || !own[0].visible || own[0].alpha <= 0 || !FlxG.cameras.list.contains(own[0])))
				strum.cameras = [camHUD];
		}

		// The other side's receptors on top of these (songs that put the player's in the middle of the screen do it): they're
		// still there, see-through, and so are their notes
		for (other in otherStrums.members)
		{
			if(other == null || !other.visible || other.alpha <= 0.3) continue;

			for (strum in strums)
			{
				if(strum != null && Math.abs(other.x - strum.x) < Note.swagWidth * 0.9 && Math.abs(other.y - strum.y) < Note.swagWidth * 0.9)
				{
					other.alpha = 0.3;
					break;
				}
			}
		}
	}

	// A note the one playing has to hit, before it's put on its place for this frame
	function guardPlayableNote(note:Note, strum:StrumNote):Void
	{
		if(note.wasGoodHit || note.tooLate || note.missed) return;

		if(!note.visible && !hiddennotes) note.visible = true;
		if(note.multAlpha < GUARD_NOTE_ALPHA) note.multAlpha = note.isSustainNote ? 0.6 : 1;
		if(!note.copyAlpha && note.alpha < GUARD_NOTE_ALPHA) note.copyAlpha = true;

		// (somewhere else than over its receptor, or not coming at all)
		if(Math.abs(note.offsetX) > Note.swagWidth * 1.5) note.offsetX = note.isSustainNote ? (strum.width - strum.hitboxShift.x * 2 - note.width) / 2 : 0;
		if(!note.copyX && Math.abs(note.x - (strum.psychX + note.offsetX)) > Note.swagWidth) note.copyX = true;
		if(!note.copyY) note.copyY = true;

		@:privateAccess
		var own:Array<FlxCamera> = note._cameras;
		if(own != null && own.length > 0 && own[0] != camHUD && own[0] != camSus && (own[0] == null || !own[0].visible || own[0].alpha <= 0 || !FlxG.cameras.list.contains(own[0])))
			note.cameras = [note.isSustainNote ? camSus : camHUD];
	}

	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public var ratingName:String = '?';
	public var ratingPercent:Float;
	public var ratingFC:String;
	public function RecalculateRating(badHit:Bool = false, scoreBop:Bool = true) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if(ret != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if(totalPlayed != 0) //Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if(ratingPercent < 1)
					for (i in 0...ratingStuff.length-1)
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit, scoreBop); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if(chartingMode) return;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));
		if(cpuControlled) return;

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !practiceMode);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					#if BASE_GAME_FILES
					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
					#end
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader
	{
		#if (!flash && sys)
		if(!ClientPrefs.data.shaders) return new ErrorHandledRuntimeShader(shaderName);

		if(!runtimeShaders.exists(shaderName) && !initLuaShader(shaderName))
		{
			FlxG.log.warn('Shader $shaderName is missing!');
			return new ErrorHandledRuntimeShader(shaderName);
		}

		var arr:Array<String> = runtimeShaders.get(shaderName);
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders/'))
		{
			var frag:String = folder + name + '.frag';
			var vert:String = folder + name + '.vert';
			var found:Bool = false;
			if(FileSystem.exists(frag))
			{
				frag = File.getContent(frag);
				found = true;
			}
			else frag = null;

			if(FileSystem.exists(vert))
			{
				vert = File.getContent(vert);
				found = true;
			}
			else vert = null;

			if(found)
			{
				runtimeShaders.set(name, [frag, vert]);
				//trace('Found shader $name!');
				return true;
			}
		}
			#if (LUA_ALLOWED || HSCRIPT_ALLOWED)
			addTextToDebug('Missing shader $name .frag AND .vert files!', FlxColor.RED);
			#else
			FlxG.log.warn('Missing shader $name .frag AND .vert files!');
			#end
		#else
		FlxG.log.warn('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}

	function startSongCredits()
	{
		if(!ClientPrefs.data.songCredits) return;

		var songName:String = PlayState.SONG.song;
		var composer:String = "Unknown";
		var charter:String = "Unknown";
		
		var parsedPath = Paths.formatToSongPath(songName);
		var txtData = Paths.getTextFromFile('data/' + parsedPath + '/credits.txt');
		
		if (txtData != null && txtData.length > 0) {
			var lines = txtData.split('\n');
			if (lines.length > 0) composer = lines[0].trim();
			if (lines.length > 1) charter = lines[1].trim();
		}
		else
		{
			// V-Slice songs have all of it on their own data
			var known:Array<Dynamic> = [for (field in ['displayName', 'artist', 'charter']) Reflect.field(PlayState.SONG, field)];
			if(known[0] != null && Std.string(known[0]).trim().length > 0) songName = Std.string(known[0]).trim();
			if(known[1] != null && Std.string(known[1]).trim().length > 0) composer = Std.string(known[1]).trim();
			if(known[2] != null && Std.string(known[2]).trim().length > 0) charter = Std.string(known[2]).trim();
		}

		var bg1 = new FlxSprite(-600, 200).loadGraphic(Paths.image('credit_bg1')); 
		bg1.cameras = [camOther];
		bg1.scale.set(0.5, 0.5);
		bg1.updateHitbox();
		add(bg1);

		var text1 = new FlxText(-600, bg1.y + 60, bg1.width, songName, 32);
		text1.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.BLACK, CENTER);
		text1.cameras = [camOther];
		add(text1);

		var bg2 = new FlxSprite(-600, bg1.y + bg1.height + 10).loadGraphic(Paths.image('credit_bg2'));
		bg2.cameras = [camOther];
		bg2.scale.set(0.65, 0.65);
		bg2.updateHitbox();
		add(bg2);

		var text2 = new FlxText(-600, bg2.y + 25, bg2.width, "COMPOSED BY: " + composer, 24);
		text2.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		text2.cameras = [camOther];
		add(text2);

		var bg3 = new FlxSprite(-600, bg2.y + bg2.height + 10).loadGraphic(Paths.image('credit_bg3'));
		bg3.cameras = [camOther];
		bg3.scale.set(0.65, 0.65);
		bg3.updateHitbox();
		add(bg3);

		var text3 = new FlxText(-600, bg3.y + 25, bg3.width, "CHARTED BY: " + charter, 24);
		text3.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, CENTER);
		text3.cameras = [camOther];
		add(text3);

		var animTime:Float = 0.5;
		var targetX:Float = -10;

		FlxTween.tween(bg1, {x: targetX - 25}, animTime, {ease: FlxEase.circOut});
		FlxTween.tween(text1, {x: targetX - 25}, animTime, {ease: FlxEase.circOut});
		
		FlxTween.tween(bg2, {x: targetX}, animTime, {ease: FlxEase.circOut, startDelay: 0.15});
		FlxTween.tween(text2, {x: targetX}, animTime, {ease: FlxEase.circOut, startDelay: 0.15});
		
		FlxTween.tween(bg3, {x: targetX}, animTime, {ease: FlxEase.circOut, startDelay: 0.3});
		FlxTween.tween(text3, {x: targetX}, animTime, {ease: FlxEase.circOut, startDelay: 0.3});

		new FlxTimer().start(5, function(tmr:FlxTimer) {
			
			FlxTween.tween(bg1, {x: -600}, animTime, {ease: FlxEase.circIn});
			FlxTween.tween(text1, {x: -600}, animTime, {ease: FlxEase.circIn, onComplete: function(twn:FlxTween) { 
				bg1.destroy(); text1.destroy();
			}});
			
			FlxTween.tween(bg2, {x: -600}, animTime, {ease: FlxEase.circIn, startDelay: 0.15});
			FlxTween.tween(text2, {x: -600}, animTime, {ease: FlxEase.circIn, startDelay: 0.15, onComplete: function(twn:FlxTween) { 
				bg2.destroy(); text2.destroy(); 
			}});
			
			FlxTween.tween(bg3, {x: -600}, animTime, {ease: FlxEase.circIn, startDelay: 0.3});
			FlxTween.tween(text3, {x: -600}, animTime, {ease: FlxEase.circIn, startDelay: 0.3, onComplete: function(twn:FlxTween) { 
				bg3.destroy(); text3.destroy(); 
			}});
		});
	}

    function spawnGhost(char:Character, noteDirection:Int)
    {
        // texture atlas characters have no sparrow frames to copy, the ghost would render as the default flixel logo
        if (char == null || char.isAnimateAtlas || char.frames == null || char.frame == null) return;

        var ghost:FlxSprite = new FlxSprite(char.x, char.y);
        ghost.frames = char.frames;
        ghost.frame = char.frame; 
        ghost.offset.set(char.offset.x, char.offset.y);
        ghost.scrollFactor.set(char.scrollFactor.x, char.scrollFactor.y);
        ghost.flipX = char.flipX;
        ghost.flipY = char.flipY;
        ghost.angle = char.angle;
        ghost.color = char.color;
        ghost.scale.set(char.scale.x, char.scale.y);
        ghost.antialiasing = char.antialiasing;
        
        ghost.alpha = 0.75;

        var groupIndex = members.indexOf(char);
        if (groupIndex == -1) {
            if (char == boyfriend) groupIndex = members.indexOf(boyfriendGroup);
            else if (char == dad) groupIndex = members.indexOf(dadGroup);
            else if (char == gf) groupIndex = members.indexOf(gfGroup);
        }
        
        if (groupIndex != -1) insert(groupIndex, ghost);
        else add(ghost);

        var slideDist:Float = 0;
        var targetX:Float = ghost.x;
        var targetY:Float = ghost.y;

        switch(noteDirection)
        {
            case 0: targetX -= slideDist;
            case 1: targetY += slideDist;
            case 2: targetY -= slideDist;
            case 3: targetX += slideDist;
        }

        var timeThing:Float = 0.4; 
        
        FlxTween.tween(ghost, {x: targetX, y: targetY, alpha: 0}, timeThing, {
            ease: FlxEase.linear, 
            onComplete: function(twn:FlxTween) {
                // (out of the state's list too, or every ghost of the song would stay in it)
                remove(ghost, true);
                ghost.destroy();
            }
        });
    }
	
	// ===============================================
	// MULTIPLAYER RECEIVERS (CABO DE GUERRA)
	// ===============================================
	public function networkOpponentHit(noteData:Int, isSustain:Bool) {
		var noteToHit:Note = null;
		// Encontra a nota exata na sua tela para sumir com ela
		for (note in notes.members) {
			if (note != null && !note.playable && !note.hitByOpponent && !note.ignoreNote && note.noteData == noteData && note.isSustainNote == isSustain) {
				if (noteToHit == null || note.strumTime < noteToHit.strumTime) {
					noteToHit = note;
				}
			}
		}

		if (noteToHit != null) {
			opponentNoteHit(noteToHit); 
		} else {
			// Se der lag e a nota não for encontrada, toca a animação mesmo assim
			var char:Character = otherCharacter;
			var animToPlay:String = singAnimations[Std.int(Math.abs(noteData))];
			if (char != null) {
				char.playAnim(animToPlay, true);
				char.holdTimer = 0;
			}
			strumPlayAnim(true, noteData, Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			if (opponentVocals != null) opponentVocals.volume = 1;
		}

		// CABO DE GUERRA: Se o oponente acertou, ele causa dano em você!
		health -= 0.023 * healthLoss;

		// ---> LIMITE SEGURO DE DANO <---
		// A sua vida não pode cair pra menos de 0.25 só porque o oponente acertou as notas dele.
		if (health < 0.25) {
			health = 0.25;
		}
	}

	public function networkOpponentMiss(noteData:Int, isPress:Bool = false, isSustain:Bool = false) {
		var char:Character = otherCharacter;
		if (char != null && char.hasMissAnimations) {
			var animToPlay:String = singAnimations[Std.int(Math.abs(noteData))] + 'miss';
			char.playAnim(animToPlay, true);
		}
		//if (opponentVocals != null) opponentVocals.volume = 0;

		// CABO DE GUERRA: Se o oponente errou, VOCÊ ganha vida!
		health += 0.0475 * healthGain;

		// Apaga a nota visualmente se foi um miss genuíno (não ghost tap): a mais antiga dessa direção
		if (!isPress) {
			var missed:Note = null;
			for (note in notes.members) {
				if (note != null && note.alive && !note.playable && note.noteData == noteData && note.isSustainNote == isSustain && !note.ignoreNote && !note.hitByOpponent) {
					if (missed == null || note.strumTime < missed.strumTime) missed = note;
				}
			}
			if (missed != null) {
				missed.active = missed.visible = false;
				missed.ignoreNote = true;
				invalidateNote(missed);
			}
		}
	}

	// ===============================================
	// MULTIPLAYER: A MÚSICA DOS DOIS NO MESMO PONTO
	// ===============================================
	// The host tells where its song is once a second; the client works out where the host's song is right now (what it said,
	// plus how long that took to get here and to be read) and compares it with its own. A message can take longer than another,
	// so one alone doesn't move anything: only when the middle one of the last few says the songs are apart (and not too often),
	// the client's song is put where the host's is. Both play the same song at the same speed: once they start together that's rare.
	var hostTimeSent:Float = 0;
	var timeOffsets:Array<Float> = [];
	var lastTimeFix:Float = 0;
	static inline var TIME_FIX_LIMIT:Float = 60; // ms apart before it's fixed
	static inline var TIME_FIX_SAMPLES:Int = 5;
	static inline var TIME_FIX_COOLDOWN:Float = 8; // seconds between two fixes

	// Moves the song while it's paused, and leaves it paused (`setSongTime()` plays it: it went on playing during the pause)
	function seekWhilePaused(time:Float) {
		setSongTime(time);
		if (FlxG.sound.music != null) FlxG.sound.music.pause();
		if (vocals != null) vocals.pause();
		if (opponentVocals != null) opponentVocals.pause();
	}

	function updateOnlineTime(elapsed:Float) {
		var music:FlxSound = FlxG.sound.music;
		var playing:Bool = !startingSong && !endingSong && music != null && music.playing;
		var now:Float = haxe.Timer.stamp();

		if (backend.NetworkManager.isHost) {
			// (the audio's own position: the song's moves a frame at a time)
			if (playing && now - hostTimeSent >= 1) {
				hostTimeSent = now;
				backend.NetworkManager.send("SYNC_TIME|" + music.time);
			}
			return;
		}

		var samples = backend.NetworkManager.takeTimeSamples();
		if (!playing) {
			timeOffsets = [];
			return;
		}
		for (sample in samples) {
			// (one that waited, while this game was paused or busy, says nothing about now)
			if (now - sample.arrival > 1.5) continue;
			var hostNow:Float = sample.time + (backend.NetworkManager.latency + (now - sample.arrival) * 1000) * playbackRate;
			timeOffsets.push(music.time - hostNow);
			if (timeOffsets.length > 9) timeOffsets.shift();
		}
		if (samples.length < 1 || timeOffsets.length < TIME_FIX_SAMPLES) return;

		var sorted:Array<Float> = timeOffsets.copy();
		sorted.sort(Reflect.compare);
		var middle:Float = sorted[Std.int(sorted.length / 2)];
		backend.NetworkManager.log('time: ' + Math.round(middle) + 'ms from the host (ping ' + Math.round(backend.NetworkManager.latency * 2) + 'ms)');

		if (Math.abs(middle) > TIME_FIX_LIMIT && now - lastTimeFix > TIME_FIX_COOLDOWN) {
			lastTimeFix = now;
			timeOffsets = [];
			backend.NetworkManager.log('time: fixed by ' + Math.round(-middle) + 'ms');
			setSongTime(Conductor.songPosition - middle);
		}
	}

	// The other player is gone in the middle of the song: it goes on without them (their notes are sung by the game again)
	function onlineConnectionLost() {
		playedOnline = false;
		if (syncWaitText != null) {
			// still waiting for them to start: it starts now
			multiplayerSynced = true;
			startCountdown();
		}
		showOnlineNotice(backend.NetworkManager.statusString + " A musica continua sem o oponente.");
	}

	function showOnlineNotice(text:String) {
		if (onlineNotice == null) {
			onlineNotice = new FlxText(0, FlxG.height * 0.2, FlxG.width, "", 28);
			onlineNotice.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			onlineNotice.cameras = [camOther];
			add(onlineNotice);
		}
		onlineNotice.text = text;
		onlineNotice.alpha = 1;
		FlxTween.cancelTweensOf(onlineNotice);
		FlxTween.tween(onlineNotice, {alpha: 0}, 1, {startDelay: 4});
	}

	/**
	 * Both players go back to the lobby, still connected (the other one left the song, or couldn't open it).
	 */
	public function onlineBackToLobby(?reason:String) {
		if (endingSong) return;
		endingSong = true;
		canPause = false;
		if (reason != null) backend.NetworkManager.statusString = reason;

		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (vocals != null) vocals.stop();
		if (opponentVocals != null) opponentVocals.stop();
		Mods.loadTopMod();
		backend.StickerTransition.prepare();
		backend.StickerTransition.switchState(new states.MultiplayerMenuState());
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}

	// ===============================================
	// MULTIPLAYER: CHECADOR DE SINCRONIA
	// ===============================================
	function checkMultiplayerSync() {
		if (iAmReady && opponentReady && !multiplayerSynced) {
			if (backend.NetworkManager.isHost) {
				multiplayerSynced = true;
				// Espera 1.5 segundos para dar tempo do PC lento terminar a transição de tela preta
				new flixel.util.FlxTimer().start(1.5, function(tmr:flixel.util.FlxTimer) {
					backend.NetworkManager.send("SYNC_START");
					// O Client só recebe o sinal um pouco depois (o tempo da rede): o Host espera esse tempo também,
					// e os dois começam juntos
					var delay:Float = backend.NetworkManager.latency / 1000;
					backend.NetworkManager.log('starting the countdown in ' + Math.round(delay * 1000) + 'ms');
					if (delay > 0.005) new flixel.util.FlxTimer().start(Math.min(delay, 0.5), function(_) startCountdown());
					else startCountdown();
				});
			}
		}
	}
}
