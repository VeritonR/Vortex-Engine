package funkin.play;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.tweens.FlxEase.EaseFunction;
import funkin.modding.events.ScriptEvent;
import funkin.play.notes.Strumline;
import funkin.play.song.Song;
import funkin.play.stage.Stage;
import objects.HealthIcon;

/**
 * Psych's PlayState with the names V-Slice gives to things, this is what `PlayState.instance` is for V-Slice scripts.
 * It only exists while a song of a V-Slice mod is being played.
 *
 * The cameras work differently on both: on V-Slice the zoom is `currentCameraZoom * cameraBopMultiplier`, with the multiplier
 * jumping on the beat and going back to 1. Here those two are Psych's `defaultCamZoom` and how far the camera is from it.
 */
@:access(states.PlayState)
class PlayState
{
	public static var instance:PlayState = null;

	/**
	 * The names V-Slice's PlayState has, with the ones of MusicBeatSubState it extends (taken from V-Slice 0.8.7, the ones of flixel's
	 * FlxSubState are added to them by `backend.VSliceScripts`). What scripts ask of `PlayState.instance` that this class doesn't have
	 * is asked of Psych's PlayState, but only by one of these names: Psych's has things V-Slice's doesn't (`strumLineNotes`, `camFollow`,
	 * `scoreTxt`...), that scripts made for both kinds of engines look for to do what they only do on the other kind.
	 */
	public static final VSLICE_MEMBERS:Array<String> = [
		'BACKGROUND_COLOR', 'CONDUCTOR_DRIFT_THRESHOLD', 'MUSIC_EASE_RATIO', 'RESYNC_THRESHOLD', '_conductorInUse', 'addBackButton',
		'addHitbox', 'applyScore', 'assertChartExists', 'backButton', 'beatHit', 'buildDiscordRPCDetails', 'buildDiscordRPCState',
		'camControls', 'camCutouts', 'camCutscene', 'camGame', 'camHUD', 'camPause', 'camSubtitles', 'camTransition',
		'cameraBopIntensity', 'cameraBopMultiplier', 'cameraFollowPoint', 'cameraFollowTween', 'cameraTweensPausedBySubState',
		'cameraZoomRate', 'cameraZoomRateOffset', 'cameraZoomTween', 'cancelAllCameraTweens', 'cancelCameraFollowTween',
		'cancelCameraZoomTween', 'cancelScrollSpeedTweens', 'changeSection', 'close', 'closeSubState', 'comboPopUps', 'conductorInUse',
		'controls', 'create', 'createWatermarkText', 'criticalFailure', 'currentCameraZoom', 'currentChart', 'currentConversation',
		'currentDifficulty', 'currentInstrumental', 'currentSong', 'currentSongLengthMs', 'currentStage', 'currentStageId',
		'currentVariation', 'deathCounter', 'debugKeyShit', 'debugUnbindCameraZoom', 'defaultHUDCameraZoom', 'destroy', 'disableKeys',
		'discordRPCAlbum', 'discordRPCIcon', 'dispatchEvent', 'endSong', 'forEachPausedSound', 'generateSong', 'generatedMusic',
		'ghostNoteMiss', 'goodNoteHit', 'handleCutsceneKeys', 'handleSkippedNotes', 'health', 'healthBar', 'healthBarBG', 'healthLerp',
		'hitbox', 'hudCameraZoomIntensity', 'iconP1', 'iconP2', 'initCallbacks', 'initCameras', 'initCharacters', 'initConsoleHelpers',
		'initDiscord', 'initHealthBar', 'initMinimalMode', 'initNoteHitbox', 'initPauseSprites', 'initPopups', 'initPreciseInputs',
		'initStage', 'initStrumlines', 'initialized', 'inputPressQueue', 'inputReleaseQueue', 'instance', 'instrumentalVolume',
		'isBotPlayMode', 'isChartingMode', 'isExitingViaPauseMenu', 'isGameOverState', 'isGamePaused', 'isInCountdown', 'isInCutscene',
		'isMinimalMode', 'isPlayerDying', 'isPlaytestResults', 'isPracticeMode', 'isSongEnd', 'isSubState', 'justUnpaused', 'lastParams',
		'leftWatermarkText', 'loadStage', 'mayPauseGame', 'mirrorSongData', 'moveToGameOver', 'moveToResultsScreen',
		'musicPausedBySubState', 'needsReset', 'new', 'noteStyle', 'onCloseSubStateComplete', 'onConversationComplete', 'onFocus',
		'onFocusLost', 'onKeyPress', 'onKeyRelease', 'onNoteMiss', 'onOpenSubStateComplete', 'onStrumlineNoteIncoming',
		'openPauseSubState', 'openSubState', 'opponentStrumline', 'opponentVocalsVolume', 'overrideMusic', 'pause', 'pauseButton',
		'pauseCircle', 'pauseMusic', 'performCleanup', 'playbackRate', 'playerStrumline', 'playerVocalsVolume', 'popUpScore',
		'preparePauseUI', 'prevScrollTargets', 'previousCameraFollowPoint', 'previousDifficulty', 'processInputQueue', 'processNotes',
		'processSongEvents', 'refresh', 'regenNoteData', 'reloadAssets', 'resetCamera', 'resetCameraZoom', 'resyncVocals',
		'rightWatermarkText', 'scoreText', 'scrollSpeedTweens', 'shouldSubstatePause', 'skipEndingTransition', 'skipHeldTimer',
		'skipVideoCutscene', 'songEvents', 'songScore', 'soundsPausedBySubState', 'stageZoom', 'startConversation', 'startCountdown',
		'startOutro', 'startSong', 'startTimestamp', 'startingSong', 'stepHit', 'subtitles', 'switchSubState', 'togglePauseButton',
		'tweenCameraToFollowPoint', 'tweenCameraToPosition', 'tweenCameraZoom', 'tweenPauseButtonIn', 'tweenScrollSpeed', 'update',
		'updateHealthBar', 'updateScoreText', 'vocals', 'vwooshTimer', 'zoomIntoResultsScreen'
	];

	/**
	 * What the song being played was opened with, like V-Slice's (`PlayState.lastParams.targetDifficulty`...).
	 */
	public static var lastParams(get, never):Dynamic;
	static function get_lastParams():Dynamic
	{
		if(instance == null) return null;
		return {
			targetSong: instance.currentSong,
			targetDifficulty: instance.currentDifficulty,
			targetVariation: instance.currentVariation,
			targetInstrumental: instance.currentInstrumental,
			practiceMode: instance.isPracticeMode,
			botPlayMode: instance.isBotPlayMode,
			playtestResults: false,
			minimalMode: false,
			startTimestamp: states.PlayState.startOnTime,
			playbackRate: instance.playbackRate,
			overrideMusic: false,
			cameraFollowPoint: null,
			mirrored: false
		};
	}

	/**
	 * Psych's PlayState, for whatever isn't here.
	 */
	public var game(default, null):states.PlayState;

	/**
	 * The stage. Scripts can put another one in its place in the middle of the song (`currentStage = StageRegistry.instance.fetchEntry(id)`),
	 * its script is the one that gets the events of the song from then on.
	 */
	public var currentStage(default, set):Stage;
	function set_currentStage(value:Stage):Stage
	{
		currentStage = value;
		#if HSCRIPT_ALLOWED
		if(value != null && instance == this) backend.VSliceScripts.stageChanged(value);
		#end
		return value;
	}
	public var currentSong:Song;
	/**
	 * The receptors of each side of the chart: Boyfriend's (the notes that are `mustPress`) and the opponent's.
	 */
	public var chartPlayerStrumline(default, null):Strumline;
	public var chartOpponentStrumline(default, null):Strumline;

	/**
	 * What scripts know as the player's and the opponent's receptors: with Play as Opponent, the player's are the ones being played
	 * (the opponent's side of the chart). Mods hide or fade "the opponent's notes" and move "the player's" around for whoever plays
	 * the song, which on V-Slice is always Boyfriend: without this their mechanics hide the notes being played.
	 */
	public var playerStrumline(get, never):Strumline;
	function get_playerStrumline():Strumline
		return (game != null && game.playAsOpponent) ? chartOpponentStrumline : chartPlayerStrumline;

	public var opponentStrumline(get, never):Strumline;
	function get_opponentStrumline():Strumline
		return (game != null && game.playAsOpponent) ? chartPlayerStrumline : chartOpponentStrumline;

	public var currentVariation:String = 'default';

	/**
	 * What the chart being played says about itself: `album`, `difficulty`, `variation`, `stage`, `noteStyle`, `scrollSpeed`, `songName`...
	 * and `characters` with `player`, `opponent` and `girlfriend`.
	 */
	public var currentChart:Dynamic = null;

	/**
	 * The events of the chart, all of them: scripts go through it to know what the song is going to ask for (the characters it
	 * changes to, to have them loaded beforehand).
	 */
	public var songEvents:Array<funkin.data.song.SongData.SongEventData> = [];

	// Images scripts pick for Discord, the engine shows its own
	public var discordRPCAlbum:String = '';
	public var discordRPCIcon:String = '';

	// scripts that take over the end of a dialogue (their own "completeCallback") remove it themselves: "currentConversation = null"
	public var currentConversation(get, set):cutscenes.VSliceConversation;
	function get_currentConversation():cutscenes.VSliceConversation return game.conversation;
	function set_currentConversation(value:cutscenes.VSliceConversation):cutscenes.VSliceConversation
	{
		if(value == null) @:privateAccess game.removeConversation();
		else game.conversation = value;
		return value;
	}
	public var stageZoom:Float = 1;
	public var defaultHUDCameraZoom:Float = 1;
	public var isMinimalMode:Bool = false;
	public var subtitles:Dynamic = null;
	public var pauseButton:Dynamic = null;

	/**
	 * The ratings and combo numbers that pop up.
	 */
	public var comboPopUps(default, null):funkin.play.components.PopUpStuff;

	/**
	 * The voices of the song, both sides as one thing.
	 */
	public var vocals(default, null):funkin.audio.VoicesGroup;

	// Beats the camera's zooms are moved by, Psych's are always on the first beat of four
	public var cameraZoomRateOffset:Int = 0;

	// Set by scripts that pause and resume things themselves, so the game doesn't take the next frame for a pause
	public var justUnpaused:Bool = false;

	// The button phones have to pause the game, there's none here
	public function togglePauseButton(visible:Bool = false):Void {}

	public var cameraZoomTween:FlxTween = null;
	public var cameraFollowTween:FlxTween = null;

	public function new(game:states.PlayState)
	{
		this.game = game;
		chartPlayerStrumline = new Strumline(true);
		chartOpponentStrumline = new Strumline(false);
		comboPopUps = new funkin.play.components.PopUpStuff(game);
		vocals = new funkin.audio.VoicesGroup(game);
		stageZoom = game.defaultCamZoom;
	}

	// ------------------------------------------------------------------------------------------
	// Things with another name
	// ------------------------------------------------------------------------------------------

	public var camGame(get, never):FlxCamera;
	function get_camGame():FlxCamera return game.camGame;

	public var camHUD(get, never):FlxCamera;
	function get_camHUD():FlxCamera return game.camHUD;

	public var camCutscene(get, never):FlxCamera;
	function get_camCutscene():FlxCamera return game.camOther;

	public var iconP1(get, never):HealthIcon;
	function get_iconP1():HealthIcon return game.iconP1;

	public var iconP2(get, never):HealthIcon;
	function get_iconP2():HealthIcon return game.iconP2;

	public var healthBar(get, never):Dynamic;
	function get_healthBar():Dynamic return game.healthBar;

	public var healthBarBG(get, never):FlxSprite;
	function get_healthBarBG():FlxSprite return (game.healthBar != null) ? game.healthBar.bg : null;

	public var scoreText(get, never):FlxText;
	function get_scoreText():FlxText return game.scoreTxt;

	public var playerVocalsVolume(get, set):Float;
	function get_playerVocalsVolume():Float return vocals.playerVolume;
	function set_playerVocalsVolume(value:Float):Float return vocals.playerVolume = value;

	public var opponentVocalsVolume(get, set):Float;
	function get_opponentVocalsVolume():Float return vocals.opponentVolume;
	function set_opponentVocalsVolume(value:Float):Float return vocals.opponentVolume = value;

	public var conductorInUse(get, never):funkin.Conductor;
	function get_conductorInUse():funkin.Conductor return funkin.Conductor.instance;

	public var controls(get, never):Controls;
	function get_controls():Controls return Controls.instance;

	public var cameraFollowPoint(get, never):FlxObject;
	function get_cameraFollowPoint():FlxObject return game.camFollow;

	public var health(get, set):Float;
	function get_health():Float return game.health;
	function set_health(value:Float):Float return game.health = value;

	public var songScore(get, set):Int;
	function get_songScore():Int return game.songScore;
	function set_songScore(value:Int):Int return game.songScore = value;

	public var isInCutscene(get, set):Bool;
	function get_isInCutscene():Bool return game.inCutscene;
	function set_isInCutscene(value:Bool):Bool return game.inCutscene = value;

	public var mayPauseGame(get, set):Bool;
	function get_mayPauseGame():Bool return game.canPause;
	function set_mayPauseGame(value:Bool):Bool return game.canPause = value;

	// Psych ignores the keys while the player's character is stunned
	public var disableKeys(get, set):Bool;
	function get_disableKeys():Bool return (game.boyfriend != null && game.boyfriend.stunned);
	function set_disableKeys(value:Bool):Bool
	{
		if(game.boyfriend != null) game.boyfriend.stunned = value;
		return value;
	}

	public var isBotPlayMode(get, never):Bool;
	function get_isBotPlayMode():Bool return game.cpuControlled;

	public var isPracticeMode(get, never):Bool;
	function get_isPracticeMode():Bool return game.practiceMode;

	public var startingSong(get, never):Bool;
	function get_startingSong():Bool return game.startingSong;

	// (a variable scripts set on V-Slice, after a countdown of their own: what they set is what they read from then on)
	public var isInCountdown(get, set):Bool;
	var countdownSetTo:Null<Bool> = null;
	function get_isInCountdown():Bool return (countdownSetTo != null) ? countdownSetTo : (game.startedCountdown && game.startingSong);
	function set_isInCountdown(value:Bool):Bool return countdownSetTo = value;

	public var isChartingMode(get, never):Bool;
	function get_isChartingMode():Bool return states.PlayState.chartingMode;

	public var isPlayerDying(get, never):Bool;
	function get_isPlayerDying():Bool return game.isDead;

	// If something is open over the song (the pause menu, a mod's own, the game over...): what scripts check to stop what they do
	// on every frame, like on V-Slice
	public var isGamePaused(get, never):Bool;
	function get_isGamePaused():Bool return game.subState != null;

	public var isGameOverState(get, never):Bool;
	function get_isGameOverState():Bool return Std.isOfType(game.subState, substates.GameOverSubstate);

	// scripts set it to keep the game from being paused while they show something at the end
	public var isSongEnd(get, set):Bool;
	var songEndSetTo:Null<Bool> = null;
	function get_isSongEnd():Bool return (songEndSetTo != null) ? songEndSetTo : game.endingSong;
	function set_isSongEnd(value:Bool):Bool return songEndSetTo = value;

	public var isPlaytestResults(get, never):Bool;
	function get_isPlaytestResults():Bool return false;

	public var initialized(get, never):Bool;
	function get_initialized():Bool return game.generatedMusic;

	public var currentSongLengthMs(get, never):Float;
	function get_currentSongLengthMs():Float return (FlxG.sound.music != null) ? FlxG.sound.music.length : game.songLength;

	public var instrumentalVolume(get, set):Float;
	function get_instrumentalVolume():Float return (FlxG.sound.music != null) ? FlxG.sound.music.volume : 1;
	function set_instrumentalVolume(value:Float):Float
	{
		if(FlxG.sound.music != null) FlxG.sound.music.volume = value;
		return value;
	}

	// (the health the bar shows, which goes after the real one on V-Slice; here the bar follows it by itself)
	public var healthLerp(get, set):Float;
	function get_healthLerp():Float return game.health;
	function set_healthLerp(value:Float):Float return value;

	public var previousDifficulty(get, never):String;
	function get_previousDifficulty():String return currentDifficulty;

	/**
	 * The note style of the song (`currentChart.noteStyle`), like V-Slice's.
	 */
	public var noteStyle(get, never):funkin.play.notes.notestyle.NoteStyle;
	var _noteStyle:funkin.play.notes.notestyle.NoteStyle = null;
	function get_noteStyle():funkin.play.notes.notestyle.NoteStyle
	{
		if(_noteStyle == null)
		{
			var id:String = (currentChart != null && currentChart.noteStyle != null) ? Std.string(currentChart.noteStyle) : 'funkin';
			_noteStyle = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry(id);
			if(_noteStyle == null) _noteStyle = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry('funkin');
		}
		return _noteStyle;
	}

	public var playbackRate(get, never):Float;
	function get_playbackRate():Float return game.playbackRate;

	public var currentStageId(get, never):String;
	function get_currentStageId():String return states.PlayState.curStage;

	public var currentDifficulty(get, never):String;
	function get_currentDifficulty():String return Paths.formatToSongPath(Difficulty.getString(null, false));

	// Cameras V-Slice has for what goes over the HUD, Psych has one for all of it
	public var camPause(get, never):FlxCamera;
	function get_camPause():FlxCamera return game.camOther;

	public var camSubtitles(get, never):FlxCamera;
	function get_camSubtitles():FlxCamera return game.camOther;

	public var camCutouts(get, never):FlxCamera;
	function get_camCutouts():FlxCamera return game.camOther;

	public var deathCounter(get, set):Int;
	function get_deathCounter():Int return states.PlayState.deathCounter;
	function set_deathCounter(value:Int):Int return states.PlayState.deathCounter = value;

	// Where the song starts from, in milliseconds
	public var startTimestamp(get, set):Float;
	function get_startTimestamp():Float return states.PlayState.startOnTime;
	function set_startTimestamp(value:Float):Float return states.PlayState.startOnTime = value;

	public var currentInstrumental:String = '';
	public var isSubState(get, never):Bool;
	function get_isSubState():Bool return false;

	/**
	 * Scripts set it to play the song again from the start.
	 */
	public var needsReset(get, set):Bool;
	var restarting:Bool = false;
	function get_needsReset():Bool return restarting;
	function set_needsReset(value:Bool):Bool
	{
		if(value && !restarting && instance == this && states.PlayState.instance == game)
		{
			restarting = true;
			substates.PauseSubState.restartSong(true);
		}
		return value;
	}

	// ------------------------------------------------------------------------------------------
	// Camera
	// ------------------------------------------------------------------------------------------

	public var currentCameraZoom(get, set):Float;
	function get_currentCameraZoom():Float return game.defaultCamZoom;
	function set_currentCameraZoom(value:Float):Float return game.defaultCamZoom = value;

	public var cameraBopMultiplier(get, set):Float;
	function get_cameraBopMultiplier():Float
		return (game.defaultCamZoom != 0) ? FlxG.camera.zoom / game.defaultCamZoom : 1;
	function set_cameraBopMultiplier(value:Float):Float
	{
		FlxG.camera.zoom = game.defaultCamZoom * value;
		return value;
	}

	// How much the camera zooms in on the beat: 1.015 on V-Slice is Psych's regular 0.015
	public var cameraBopIntensity(get, set):Float;
	function get_cameraBopIntensity():Float return 1 + 0.015 * game.camZoomingMult;
	function set_cameraBopIntensity(value:Float):Float
	{
		game.camZoomingMult = (value - 1) / 0.015;
		return value;
	}

	public var hudCameraZoomIntensity(get, set):Float;
	function get_hudCameraZoomIntensity():Float return 0.015 * 2 * game.camZoomingMult;
	function set_hudCameraZoomIntensity(value:Float):Float return value;

	// Beats between each zoom. Psych does it every 4 by itself (on each section) or not at all,
	// `backend.VSliceScripts` does the beats in between for the songs that ask for it every beat or every other one
	public var cameraZoomRate(get, set):Int;
	var zoomRate:Int = 4;
	function get_cameraZoomRate():Int return game.camZooming ? zoomRate : 0;
	function set_cameraZoomRate(value:Int):Int
	{
		game.camZooming = (value > 0);
		if(value > 0) zoomRate = value;
		return value;
	}

	/**
	 * Moves the camera to a position, leaving it there until something else moves it.
	 */
	public function tweenCameraToPosition(?x:Float, ?y:Float, ?duration:Float, ?ease:EaseFunction):Void
	{
		cancelCameraFollowTween();

		var follow:FlxObject = game.camFollow;
		if(x == null) x = follow.x;
		if(y == null) y = follow.y;

		// the song's sections don't get to move it anymore
		game.isCameraOnForcedPos = true;

		follow.setPosition(x, y);
		if(duration == null || duration <= 0)
		{
			FlxG.camera.snapToTarget();
			return;
		}

		// It's the camera itself that gets moved, like on V-Slice: it stops following for as long as the tween lasts.
		// Moving what it follows instead would have the camera chasing it at its own speed, always behind where the song wants it
		var camera:FlxCamera = FlxG.camera;
		camera.target = null;

		var midpoint:FlxPoint = follow.getMidpoint();
		var scrollX:Float = midpoint.x - camera.width * 0.5 + camera.targetOffset.x;
		var scrollY:Float = midpoint.y - camera.height * 0.5 + camera.targetOffset.y;
		midpoint.put();

		cameraFollowTween = FlxTween.tween(camera.scroll, {x: scrollX, y: scrollY}, duration, {
			ease: (ease != null) ? ease : FlxEase.linear,
			onComplete: function(_)
			{
				cameraFollowTween = null;
				followAgain();
			}
		});
	}

	public function cancelCameraFollowTween():Void
	{
		if(cameraFollowTween != null) cameraFollowTween.cancel();
		cameraFollowTween = null;
		followAgain();
	}

	// The camera goes back to following its point, from where it is
	function followAgain():Void
	{
		if(FlxG.camera.target != null || instance != this || states.PlayState.instance != game || game.camFollow == null) return;
		FlxG.camera.follow(game.camFollow, LOCKON, 0);
	}

	/**
	 * Changes the zoom the camera rests on.
	 *
	 * @param direct 	If false, the zoom is relative to the stage's own instead of an exact value.
	 */
	public function tweenCameraZoom(?zoom:Float, ?duration:Float, ?direct:Bool, ?ease:EaseFunction):Void
	{
		cancelCameraZoomTween();

		if(zoom == null) zoom = 1;
		var target:Float = (direct == true) ? zoom : zoom * stageZoom;

		if(duration == null || duration <= 0)
		{
			game.defaultCamZoom = target;
			FlxG.camera.zoom = target;
			return;
		}
		cameraZoomTween = FlxTween.tween(game, {defaultCamZoom: target}, duration, {
			ease: (ease != null) ? ease : FlxEase.linear,
			onUpdate: function(_)
			{
				// The camera only goes after the zoom it rests on while the song has it bopping, which isn't before its first notes
				// nor once it's over: a cutscene that zooms after the song (Stress Pico Mix) would stay where the song left it
				if(!game.camZooming) FlxG.camera.zoom = game.defaultCamZoom;
			}
		});
	}

	public function cancelCameraZoomTween():Void
	{
		if(cameraZoomTween != null) cameraZoomTween.cancel();
		cameraZoomTween = null;
	}

	public function cancelAllCameraTweens():Void
	{
		cancelCameraFollowTween();
		cancelCameraZoomTween();
	}

	/**
	 * Puts the camera back on who the song says it should be on.
	 */
	public function resetCamera(resetZoom:Bool = true, cancelTweens:Bool = true, snap:Bool = true):Void
	{
		if(cancelTweens) cancelAllCameraTweens();
		if(resetZoom)
		{
			game.defaultCamZoom = stageZoom;
			FlxG.camera.zoom = stageZoom;
		}

		game.isCameraOnForcedPos = false;
		game.moveCameraSection();
		if(snap) FlxG.camera.snapToTarget();
	}

	/**
	 * Takes the camera to where its follow point is, over some time: for when a script moved the point itself.
	 */
	public function tweenCameraToFollowPoint(?duration:Float, ?ease:EaseFunction):Void
	{
		tweenCameraToPosition(game.camFollow.x, game.camFollow.y, duration, ease);
	}

	// The zoom of the stage, without the camera's jump on the beat
	public function resetCameraZoom():Void
	{
		if(isMinimalMode) return;

		game.defaultCamZoom = stageZoom;
		FlxG.camera.zoom = stageZoom;
	}

	// Where the camera was looking at when the player died, for the game over to start from
	public var previousCameraFollowPoint:FlxPoint = null;

	public var scrollSpeedTweens:Array<FlxTween> = [];

	/**
	 * Changes how fast the notes go. V-Slice has a speed for each side (`strumlines` says which), Psych a single one for both.
	 */
	public function tweenScrollSpeed(?speed:Float, ?duration:Float, ?ease:EaseFunction, ?strumlines:Array<String>):Void
	{
		cancelScrollSpeedTweens();
		if(speed == null) return;

		if(duration == null || duration <= 0)
		{
			game.songSpeed = speed;
			return;
		}
		scrollSpeedTweens.push(FlxTween.tween(game, {songSpeed: speed}, duration / Math.max(game.playbackRate, 0.01), {ease: (ease != null) ? ease : FlxEase.linear}));
	}

	public function cancelScrollSpeedTweens():Void
	{
		for (tween in scrollSpeedTweens)
			if(tween != null) tween.cancel();
		scrollSpeedTweens = [];
	}

	// ------------------------------------------------------------------------------------------
	// Actions
	// ------------------------------------------------------------------------------------------

	// (a stage is one more thing on V-Slice's PlayState, here its sprites are: it's put on and taken off by building and killing it)
	public function add(object:Dynamic):Dynamic
	{
		if(Std.isOfType(object, Stage) || !Std.isOfType(object, FlxBasic)) return object;
		addedByScripts.set(object, true);
		return game.add(object);
	}

	// What scripts put here themselves: `refresh()` puts it in its layer whatever camera it's on (they give it one after adding it,
	// even after refreshing), like V-Slice sorts all of its things. The engine's things of the world are left where they are
	var addedByScripts:haxe.ds.ObjectMap<Dynamic, Bool> = new haxe.ds.ObjectMap();

	public function remove(object:Dynamic, splice:Bool = false):Dynamic
	{
		if(Std.isOfType(object, Stage) || !Std.isOfType(object, FlxBasic)) return object;
		return game.remove(object, splice);
	}

	public function insert(position:Int, object:Dynamic):Dynamic
	{
		if(Std.isOfType(object, Stage) || !Std.isOfType(object, FlxBasic)) return object;
		addedByScripts.set(object, true);

		// (a place in `members`, where the strumlines are things of their own: it goes before what's there)
		var list:Array<Dynamic> = get_members();
		if(position >= 0 && position < list.length)
		{
			var there:Dynamic = list[position];
			if(there == playerStrumline || there == opponentStrumline) there = game.noteGroup;
			var real:Int = game.members.indexOf(there);
			if(real > -1) return game.insert(real, object);
		}
		return game.insert(position, object);
	}

	/**
	 * What's on the screen, in its order. On V-Slice the strumlines are some of it, scripts put things right under them with
	 * `insert(members.indexOf(playerStrumline), thing)`: here both are where the group of the notes is.
	 */
	public var members(get, never):Array<Dynamic>;
	function get_members():Array<Dynamic>
	{
		var list:Array<Dynamic> = [];
		for (member in game.members)
		{
			if(member != null && member == game.noteGroup)
			{
				list.push(playerStrumline);
				list.push(opponentStrumline);
			}
			else list.push(member);
		}
		return list;
	}

	/**
	 * How much of the screen a wider phone leaves out on V-Slice, where the strumlines are moved for it. None here.
	 */
	public var cutoutSize:Float = 0;

	/**
	 * Hits a note the way the player does (scripts do it for notes of keys of their own).
	 */
	public function goodNoteHit(note:Dynamic, ?input:Dynamic):Void
	{
		var real:objects.Note = Std.isOfType(note, funkin.play.notes.NoteSprite) ? cast(note, funkin.play.notes.NoteSprite).note : Std.downcast(note, objects.Note);
		if(real != null) game.goodNoteHit(real);
	}
	/**
	 * Puts what's on the HUD in the order of its layers (`zIndex`), like V-Slice does with everything on its PlayState. Only what has a
	 * layer moves, and only to the places things with a layer take. The stage's own things are left to the stage (see `Stage.refresh()`).
	 *
	 * The icons are inside of the group of the HUD here: when a script gives them a layer they come out of it and are sorted like the rest,
	 * so they can go on top of a health bar of a mod's own.
	 */
	public function refresh():Void
	{
		for (icon in [game.iconP1, game.iconP2])
		{
			if(icon == null || layerOf(icon) == null || game.uiGroup == null || !game.uiGroup.members.contains(icon)) continue;

			game.uiGroup.remove(icon, true);
			icon.cameras = [game.camHUD];
			game.add(icon);
		}

		var places:Array<Int> = [];
		var sorted:Array<FlxBasic> = [];
		for (index => member in game.members)
		{
			if(member == null || hudLayerOf(member) == null || (member.cameras.contains(game.camGame) && !addedByScripts.exists(member))) continue;
			places.push(index);
			sorted.push(member);
		}

		// (stable: what's on the same layer keeps the order it had)
		var order:Map<FlxBasic, Int> = [for (index => member in sorted) member => index];
		sorted.sort(function(a, b)
		{
			var difference:Float = hudLayerOf(a) - hudLayerOf(b);
			if(difference != 0) return (difference < 0) ? -1 : 1;
			return order.get(a) - order.get(b);
		});
		for (index => place in places)
			game.members[place] = sorted[index];
	}

	// The layer of something on the HUD. The engine's groups have the ones of what they are on V-Slice (the health bar and its icons,
	// the ratings, the strumlines with their notes), which mods' things go under or over: a video at 300 is under the notes there
	function hudLayerOf(object:FlxBasic):Null<Float>
	{
		var layer:Null<Float> = layerOf(object);
		if(layer != null) return layer;

		if(object == game.uiGroup) return 800;
		if(object == game.comboGroup) return 900;
		if(object == game.noteGroup) return 1000;
		// (V-Slice's flixel gives everything a layer, 0 when nobody set one: what scripts added without one goes under the HUD then,
		// like a health bar's frame under its icons)
		if(addedByScripts.exists(object)) return 0;
		return null;
	}

	static function layerOf(object:FlxBasic):Null<Float>
	{
		var value:Dynamic = null;
		#if HSCRIPT_ALLOWED
		value = hxc.HxcRuntime.getValue(object, 'zIndex');
		#else
		try
		{
			value = Reflect.getProperty(object, 'zIndex');
		}
		catch(e:Dynamic) {}
		#end
		return Std.isOfType(value, Float) ? value : null;
	}

	/**
	 * Starts the song right away, with no countdown: V-Slice scripts cancel the countdown and call this.
	 * Psych sets up what a song needs (its receptors, its clock) when the countdown starts, so the countdown is started here
	 * without its ticks, and the song begins on the next frame.
	 */
	public function startSong():Void
	{
		if(!game.startingSong || game.startedCountdown) return;

		game.skipCountdown = true;
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.songStartedWhileCreating();
		backend.VSliceScripts.countdownForced = true;
		#end
		game.startCountdown();
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.countdownForced = false;
		#end
	}

	public function startCountdown():Void
	{
		game.startCountdown();
	}

	/**
	 * @param rightGoddamnNow 	If the song ends without asking the scripts about it (they're the ones who can stop it to show something first).
	 */
	public function endSong(rightGoddamnNow:Bool = false):Void
	{
		#if HSCRIPT_ALLOWED
		if(rightGoddamnNow) backend.VSliceScripts.skipSongEnd = true;
		#end
		game.endSong();
	}

	/**
	 * Starts one of the mod's dialogues ("data/dialogue/conversations"), over everything else.
	 * When it ends the song starts, if it was waiting for it.
	 */
	public function startConversation(conversationId:String):Void
	{
		game.inCutscene = true;
		if(game.startConversation(conversationId, onConversationComplete)) return;

		// goes on as if it had been read to the end
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.warn('The dialogue "$conversationId" was not found or could not be read, it was skipped');
		#end
		new FlxTimer().start(0.1, function(_) onConversationComplete());
	}

	// On V-Slice the end of a dialogue only starts the song, a script that shows one when the song ends is the one that ends it
	function onConversationComplete():Void
	{
		if(instance != this || states.PlayState.instance != game) return;

		game.inCutscene = false;
		if(game.startingSong && !game.startedCountdown) game.startCountdown();
	}

	/**
	 * Sends an event to every script, like the game itself does.
	 */
	public function dispatchEvent(event:ScriptEvent):Void
	{
		backend.VSliceScripts.dispatch(event);
	}

	public function toString():String
	{
		return 'PlayState';
	}
}
