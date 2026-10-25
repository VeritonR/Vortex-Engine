package states;

import backend.FreeplayData.FreeplayRank;
import backend.PlayableCharacters;
import flixel.FlxBasic;
import flixel.addons.display.FlxBackdrop;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.math.FlxRect;
import flixel.text.FlxBitmapText;
import flixel.util.FlxGradient;
import flixel.util.FlxSort;
import objects.AtlasSprite;
import objects.results.ResultsDisplays;
import shaders.LeftMaskShader;

typedef ResultsTallies =
{
	var sick:Int;
	var good:Int;
	var bad:Int;
	var shit:Int;
	var missed:Int;
	var combo:Int;
	var maxCombo:Int;
	var totalNotesHit:Int;
	var totalNotes:Int;
}

typedef ResultsScoreData =
{
	var score:Int;
	var tallies:ResultsTallies;

	/**
	 * Psych's accuracy from 0 to 1. The screen doesn't use it: the rank and the "clear" percentage come from the tallies, like on V-Slice.
	 */
	@:optional var accuracy:Null<Float>;
}

typedef ResultsParams =
{
	/**
	 * If this is about a whole week instead of a single song.
	 */
	var storyMode:Bool;

	/**
	 * What's written on the top: the song's name, or the week's.
	 */
	var title:String;

	var songId:String;

	/**
	 * Character the song was played with, the screen shows the animations of the player that owns it.
	 */
	@:optional var characterId:String;

	@:optional var isNewHighscore:Bool;
	@:optional var isPracticeMode:Bool;
	@:optional var isBotPlayMode:Bool;
	@:optional var difficultyId:String;
	@:optional var variationId:String;

	var scoreData:ResultsScoreData;
}

/**
 * V-Slice's results screen: the score and the tallies of what was just played counting up, the rank it's worth
 * and the player character reacting to it. It comes after a song played on Freeplay and after the last song of a week.
 *
 * What the character does comes from the "results" of the player's file ("data/players"), with the same format as V-Slice:
 * a list of animations for each rank (texture atlases or regular spritesheets) and the music that goes with each one.
 * The names of the things here are the ones V-Slice gives them, for the scripts of its mods.
 */
class ResultsState extends MusicBeatState
{
	public var params(default, null):ResultsParams;
	public var rank(default, null):FreeplayRank;

	/**
	 * Percentage shown as "clear", from 0 to 100.
	 */
	public var clearPercentTarget(default, null):Int = 100;

	public var songName:FlxBitmapText;
	public var difficulty:FlxSprite;
	public var clearPercentSmall:ClearPercentCounter;

	public var resultsAnim:FlxSprite;
	public var ratingsPopin:FlxSprite;
	public var scorePopin:FlxSprite;
	public var bgFlash:FlxSprite;
	public var highscoreNew:FlxSprite;
	public var score:ResultScore;
	public var rankBg:FlxSprite;
	public var blackTopBar:FlxSprite;

	public var cameraBG:FlxCamera;
	public var cameraScroll:FlxCamera;
	public var cameraEverything:FlxCamera;

	/**
	 * The character's animations that are texture atlases, shown when the tallies are done counting.
	 */
	public var characterAtlasAnimations:Array<{sprite:AtlasSprite, delay:Float, forceLoop:Bool, startFrameLabel:String, sound:String}> = [];

	/**
	 * The ones that are regular spritesheets.
	 */
	public var characterSparrowAnimations:Array<{sprite:FlxSprite, delay:Float}> = [];

	public var playerCharacterId:String = null;
	public var playerCharacter:PlayableCharacter = null;

	var maskShaderSongName:LeftMaskShader = new LeftMaskShader();
	var maskShaderDifficulty:LeftMaskShader = new LeftMaskShader();

	var introMusicAudio:FlxSound = null;
	var layers:Map<FlxBasic, Int> = [];
	var leaving:Bool = false;
	var clearPercentLerp:Int = 0;

	var movingSongStuff:Bool = false;
	var speedOfTween:FlxPoint = FlxPoint.get(-1, 1);

	public function new(params:ResultsParams)
	{
		super();
		this.params = params;

		var data:ResultsScoreData = params.scoreData;
		var tallies:ResultsTallies = data.tallies;

		clearPercentTarget = Math.floor(FreeplayRank.getCompletion(tallies.sick, tallies.good, tallies.missed, tallies.totalNotes) * 100);

		var found:Null<FreeplayRank> = FreeplayRank.fromTallies(tallies.sick, tallies.good, tallies.missed, tallies.totalNotes);
		rank = (found != null) ? found : FreeplayRank.LOSS;
	}

	// ------------------------------------------------------------------------------------------
	// What changes with the rank
	// ------------------------------------------------------------------------------------------

	// From the worst rank to the best one, in 24ths of a second
	static final MUSIC_DELAYS:Array<Float> = [2, 3, 5, 0, 95, 95];
	static final CHARACTER_DELAYS:Array<Float> = [95, 95, 95, 97, 95, 95];
	static final FLASH_DELAYS:Array<Float> = [186, 107, 109, 122, 129, 129];
	static final HIGHSCORE_DELAYS:Array<Float> = [207, 127, 129, 140, 140, 140];
	static final RANK_NAMES:Array<String> = ['LOSS', 'GOOD', 'GREAT', 'EXCELLENT', 'PERFECT', 'PERFECT'];
	public static final RANK_FIELDS:Array<String> = ['loss', 'good', 'great', 'excellent', 'perfect', 'perfectGold'];
	public static final MUSIC_FIELDS:Array<String> = ['SHIT', 'GOOD', 'GREAT', 'EXCELLENT', 'PERFECT', 'PERFECT_GOLD'];
	public static final DEFAULT_MUSIC:Array<String> = ['resultsSHIT', 'resultsNORMAL', 'resultsNORMAL', 'resultsEXCELLENT', 'resultsPERFECT', 'resultsPERFECT'];

	/**
	 * The animations the player's file has for the rank.
	 */
	public function getResultsAnimationDatas():Array<Dynamic>
	{
		var results:Dynamic = (playerCharacter != null) ? playerCharacter.results : null;
		if(results == null) return [];

		var list:Dynamic = Reflect.field(results, RANK_FIELDS[rank]);
		if(list == null && rank == FreeplayRank.PERFECT_GOLD) list = results.perfect;
		return Std.isOfType(list, Array) ? list : [];
	}

	/**
	 * Folder of the music for the rank, inside of the music one.
	 */
	public function getMusicPath():String
	{
		var results:Dynamic = (playerCharacter != null) ? playerCharacter.results : null;
		var music:Dynamic = (results != null) ? results.music : null;
		var path:String = (music != null) ? Reflect.field(music, MUSIC_FIELDS[rank]) : null;
		return (path != null && path.length > 0) ? path : DEFAULT_MUSIC[rank];
	}

	// ------------------------------------------------------------------------------------------
	// Layers
	// ------------------------------------------------------------------------------------------

	/**
	 * Adds something on a layer: the ones with a bigger number are drawn over the others.
	 */
	public function addLayered(object:FlxBasic, zIndex:Int):FlxBasic
	{
		layers.set(object, zIndex);
		add(object);
		return object;
	}

	/**
	 * Puts everything in the order of its layer again.
	 */
	public function refresh():Void
	{
		var order:Map<FlxBasic, Int> = [];
		for (num => member in members)
			if(member != null) order.set(member, num);

		members.sort(function(a:FlxBasic, b:FlxBasic):Int
		{
			if(a == null || b == null) return (a == null) ? ((b == null) ? 0 : 1) : -1;

			var layerA:Int = layers.exists(a) ? layers.get(a) : 0;
			var layerB:Int = layers.exists(b) ? layers.get(b) : 0;
			return (layerA != layerB) ? layerA - layerB : order.get(a) - order.get(b);
		});
	}

	public static function stripLibrary(path:String):String
	{
		if(path == null) return '';

		var colon:Int = path.indexOf(':');
		return (colon > -1) ? path.substr(colon + 1) : path;
	}

	static function makeSparrow(x:Float, y:Float, key:String):FlxSprite
	{
		var sprite:FlxSprite = new FlxSprite(x, y);
		sprite.frames = Paths.getSparrowAtlas(key);
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		return sprite;
	}

	// ------------------------------------------------------------------------------------------
	// Create
	// ------------------------------------------------------------------------------------------

	override function create():Void
	{
		Paths.clearStoredMemory();

		if(FlxG.sound.music != null) FlxG.sound.music.stop();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Results', null);
		#end

		// the states' own camera, which would take the place of the ones made here if it was only made later
		initPsychCamera();

		cameraBG = new FlxCamera();
		cameraScroll = new FlxCamera(0, 0, FlxG.width, Math.round(FlxG.height * 1.2));
		cameraEverything = new FlxCamera();

		// Black, not V-Slice's magenta: every camera made from here on starts with the color of the main one,
		// which would end up behind everything that doesn't cover the screen (like the game over)
		cameraBG.bgColor = FlxColor.BLACK;
		cameraScroll.bgColor = FlxColor.TRANSPARENT;
		cameraEverything.bgColor = FlxColor.TRANSPARENT;

		FlxG.cameras.reset(cameraBG);
		FlxG.cameras.add(cameraScroll, false);
		FlxG.cameras.add(cameraEverything, false);
		FlxG.cameras.setDefaultDrawTarget(cameraBG, false);
		FlxG.cameras.setDefaultDrawTarget(cameraEverything, true);
		cameraScroll.canvas.rotation = -3.8;

		// Background
		var bg:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFECC5C, 0xFFFDC05C], 90);
		bg.scrollFactor.set();
		bg.cameras = [cameraBG];
		addLayered(bg, 10);

		bgFlash = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFFF1A6, 0xFFFFF1BE], 90);
		bgFlash.scrollFactor.set();
		bgFlash.visible = false;
		addLayered(bgFlash, 20);

		var soundSystem:FlxSprite = makeSparrow(-15, -180, 'resultScreen/soundSystem');
		soundSystem.animation.addByPrefix('idle', 'sound system', 24, false);
		soundSystem.visible = false;
		new FlxTimer().start(8 / 24, function(_)
		{
			soundSystem.animation.play('idle');
			soundSystem.visible = true;
		});
		addLayered(soundSystem, 1100);

		// Who played
		var owner:PlayableCharacter = (params.characterId != null) ? PlayableCharacters.getOwner(params.characterId) : null;
		playerCharacter = (owner != null) ? owner : PlayableCharacters.get(PlayableCharacters.DEFAULT);
		playerCharacterId = (playerCharacter != null) ? playerCharacter.id : PlayableCharacters.DEFAULT;

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.startMenu(this);
		#end

		withPlayerMod(createCharacterAnimations);

		// Top bar
		var fontLetters:String = 'AaBbCcDdEeFfGgHhiIJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz:1234567890().-';
		songName = new FlxBitmapText(FlxBitmapFont.fromMonospace(Paths.image('resultScreen/tardlingSpritesheet'), fontLetters, FlxPoint.get(49, 61)));
		songName.text = (params.title != null) ? params.title : '';
		songName.letterSpacing = -15;
		songName.angle = -4.4;
		songName.antialiasing = ClientPrefs.data.antialiasing;
		songName.visible = false;

		difficulty = new FlxSprite(555);
		var difficultyImage:String = 'resultScreen/diff_' + Paths.formatToSongPath((params.difficultyId != null) ? params.difficultyId : 'normal');
		if(Paths.fileExists('images/$difficultyImage.png', IMAGE)) difficulty.loadGraphic(Paths.image(difficultyImage));
		else difficulty.makeGraphic(1, 1, FlxColor.TRANSPARENT); //a difficulty the screen has no image for
		difficulty.antialiasing = ClientPrefs.data.antialiasing;
		addLayered(difficulty, 1000);
		addLayered(songName, 1000);

		clearPercentSmall = new ClearPercentCounter(FlxG.width / 2 + 300, FlxG.height / 2 - 100, 100, true);
		clearPercentSmall.visible = false;

		blackTopBar = new FlxSprite().loadGraphic(Paths.image('resultScreen/topBarBlack'));
		blackTopBar.antialiasing = ClientPrefs.data.antialiasing;
		blackTopBar.y = -blackTopBar.height;
		FlxTween.tween(blackTopBar, {y: 0}, 7 / 24, {ease: FlxEase.quartOut, startDelay: 3 / 24, onComplete: function(_) songName.visible = true});
		addLayered(blackTopBar, 1010);

		var angleRad:Float = songName.angle * Math.PI / 180;
		speedOfTween.x = -1.0 * Math.cos(angleRad);
		speedOfTween.y = -1.0 * Math.sin(angleRad);

		timerThenSongName(1.0, false);

		songName.shader = maskShaderSongName;
		difficulty.shader = maskShaderDifficulty;
		maskShaderDifficulty.swagMaskX = difficulty.x - 30;

		// The things that pop in, one after the other
		resultsAnim = makeSparrow(FlxG.width - 1480, -10, 'resultScreen/results');
		resultsAnim.animation.addByPrefix('result', 'results instance 1', 24, false);
		resultsAnim.visible = false;
		addLayered(resultsAnim, 1200);
		new FlxTimer().start(6 / 24, function(_)
		{
			resultsAnim.visible = true;
			resultsAnim.animation.play('result');
		});

		ratingsPopin = makeSparrow(-135, 135, 'resultScreen/ratingsPopin');
		ratingsPopin.animation.addByPrefix('idle', 'Categories', 24, false);
		ratingsPopin.visible = false;
		addLayered(ratingsPopin, 1200);
		new FlxTimer().start(21 / 24, function(_)
		{
			ratingsPopin.visible = true;
			ratingsPopin.animation.play('idle');
		});

		scorePopin = makeSparrow(-180, 515, 'resultScreen/scorePopin');
		scorePopin.animation.addByPrefix('score', 'tally score', 24, false);
		scorePopin.visible = false;
		addLayered(scorePopin, 1200);
		new FlxTimer().start(36 / 24, function(_)
		{
			scorePopin.visible = true;
			scorePopin.animation.play('score');
		});

		score = new ResultScore(35, 305, 10, params.scoreData.score);
		score.visible = false;

		new FlxTimer().start(37 / 24, function(_)
		{
			score.visible = true;
			score.animateNumbers();
			startRankTallySequence();
		});

		new FlxTimer().start(CHARACTER_DELAYS[rank] / 24, function(_) afterRankTallySequence());
		new FlxTimer().start(FLASH_DELAYS[rank] / 24, function(_) displayRankText());

		highscoreNew = makeSparrow(44, 557, 'resultScreen/highscoreNew');
		highscoreNew.animation.addByPrefix('new', 'highscoreAnim0', 24, false);
		highscoreNew.visible = false;
		highscoreNew.updateHitbox();
		addLayered(highscoreNew, 1200);

		new FlxTimer().start(HIGHSCORE_DELAYS[rank] / 24, function(_)
		{
			if(params.isNewHighscore != true) return;

			highscoreNew.visible = true;
			highscoreNew.animation.play('new');
			highscoreNew.animation.finishCallback = function(_) highscoreNew.animation.play('new', true, false, 16);
		});

		// Tallies
		var tallies:ResultsTallies = params.scoreData.tallies;
		var hStuf:Int = 50;

		var ratingGrp:FlxTypedGroup<TallyCounter> = new FlxTypedGroup<TallyCounter>();
		addLayered(ratingGrp, 1200);

		var totalHit:TallyCounter = new TallyCounter(375, hStuf * 3, tallies.totalNotesHit);
		ratingGrp.add(totalHit);

		var maxCombo:TallyCounter = new TallyCounter(375, hStuf * 4, tallies.maxCombo);
		ratingGrp.add(maxCombo);

		if(tallies.totalNotesHit >= 1000)
		{
			totalHit.x -= 30;
			maxCombo.x -= 30;
		}

		hStuf += 4;
		var extraYOffset:Float = 7;

		ratingGrp.add(new TallyCounter(230, (hStuf * 5) + extraYOffset, tallies.sick, 0xFF89E59E));
		ratingGrp.add(new TallyCounter(210, (hStuf * 6) + extraYOffset, tallies.good, 0xFF89C9E5));
		ratingGrp.add(new TallyCounter(190, (hStuf * 7) + extraYOffset, tallies.bad, 0xFFE6CF8A));
		ratingGrp.add(new TallyCounter(220, (hStuf * 8) + extraYOffset, tallies.shit, 0xFFE68C8A));
		ratingGrp.add(new TallyCounter(260, (hStuf * 9) + extraYOffset, tallies.missed, 0xFFC68AE6));

		addLayered(score, 1200);

		for (ind => rating in ratingGrp.members)
		{
			rating.visible = false;
			new FlxTimer().start((0.3 * ind) + 1.20, function(_)
			{
				rating.visible = true;
				FlxTween.tween(rating, {curNumber: rating.neededNumber}, 0.5, {ease: FlxEase.quartOut});
			});
		}

		new FlxTimer().start(MUSIC_DELAYS[rank] / 24, function(_) withPlayerMod(startMusic));

		rankBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		rankBg.scale.set(FlxG.width, FlxG.height);
		rankBg.updateHitbox();
		rankBg.alpha = 0;
		addLayered(rankBg, 99999);

		refresh();

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.menuOpened(this);
		#end

		super.create();

		// what the song was using, now that what this screen needs is loaded
		Paths.clearUnusedMemory();
	}

	// The player can be from another mod than the song, its things are looked for there first
	function withPlayerMod(func:Void->Void):Void
	{
		var mod:String = (playerCharacter != null) ? playerCharacter.mod : null;
		if(mod == null || mod.length < 1 || mod == Mods.currentModDirectory)
		{
			func();
			return;
		}

		backend.FreeplayData.withMod(mod, function()
		{
			func();
			return null;
		});
	}

	// What the player does about the rank, hidden until the tallies are done
	function createCharacterAnimations():Void
	{
		for (animData in getResultsAnimationDatas())
		{
			if(animData == null) continue;

			var filter:String = (animData.filter != null) ? animData.filter : 'both';
			if(filter != 'both' && filter != (ClientPrefs.data.naughtyness ? 'naughty' : 'safe')) continue;

			var path:String = stripLibrary(animData.assetPath);
			var offsets:Array<Float> = (Std.isOfType(animData.offsets, Array) && animData.offsets.length > 1) ? animData.offsets : [0, 0];
			var zIndex:Int = (animData.zIndex != null) ? animData.zIndex : 500;
			var size:Float = (animData.scale != null) ? animData.scale : 1;
			var renderType:String = (animData.renderType != null) ? animData.renderType : 'animateatlas';

			switch(renderType)
			{
				case 'animateatlas':
					var sprite:AtlasSprite = null;
					if(animData.scriptClass != null) sprite = makeScriptedAtlas(animData.scriptClass, offsets[0], offsets[1]);
					else sprite = new AtlasSprite(offsets[0], offsets[1], path);
					backend.StepLog.add('Results animation ' + ((animData.scriptClass != null) ? 'of the class ' + animData.scriptClass : '"$path"') + ' at ' + offsets + ': ' + ((sprite != null) ? sprite.describe() : 'not made'));
					if(sprite == null || !sprite.loaded) continue;

					sprite.scale.set(size, size);
					setupAtlasLoop(sprite, animData);

					sprite.visible = false;
					characterAtlasAnimations.push({
						sprite: sprite,
						delay: (animData.delay != null) ? animData.delay : 0,
						forceLoop: (animData.loopFrame == 0),
						startFrameLabel: (animData.startFrameLabel != null) ? animData.startFrameLabel : '',
						sound: (animData.sound != null) ? animData.sound : ''
					});
					addLayered(sprite, zIndex);

				case 'sparrow':
					if(!Paths.fileExists('images/$path.png', IMAGE)) continue;

					var sprite:FlxSprite = makeSparrow(offsets[0], offsets[1], path);
					sprite.animation.addByPrefix('idle', '', 24, false);

					var loopFrame:Null<Int> = animData.loopFrame;
					if(loopFrame != null) sprite.animation.finishCallback = function(_) sprite.animation.play('idle', true, false, loopFrame);

					sprite.visible = false;
					characterSparrowAnimations.push({sprite: sprite, delay: (animData.delay != null) ? animData.delay : 0});
					addLayered(sprite, zIndex);

				default:
					trace('The results screen does not know how to show a "$renderType"');
			}
		}
	}

	// What an atlas does when it gets to its end: stops, or goes back to a label or to a frame
	public static function setupAtlasLoop(sprite:AtlasSprite, animData:Dynamic):Void
	{
		if(animData.looped == false)
		{
			sprite.player.onFinish.add(function(_) sprite.player.pause());
		}
		else if(animData.loopFrameLabel != null)
		{
			var label:String = animData.loopFrameLabel;
			sprite.player.onFinish.add(function(_)
			{
				sprite.player.play(label, true);
				sprite.player.looped = true;
			});
		}
		else if(animData.loopFrame != null)
		{
			var frame:Int = animData.loopFrame;
			sprite.player.onFinish.add(function(_) sprite.player.play('', true, false, frame));
		}
	}

	// An animation that's a class of a script, or one of the base game's (which are scripts on V-Slice) done by the engine itself
	public static function makeScriptedAtlas(className:String, x:Float, y:Float):AtlasSprite
	{
		#if HSCRIPT_ALLOWED
		var scripted:AtlasSprite = backend.VSliceScripts.makeAtlasSprite(className, x, y);
		if(scripted != null) return scripted;
		#end

		switch(className)
		{
			case 'BFBedPerfectResults': return new AtlasSprite(x, y, 'resultScreen/results-bf/resultsPERFECT/bed');
			case 'BFShitResults': return new AtlasSprite(x, y, 'resultScreen/results-bf/resultsSHIT');
			case 'PicoPerfectResults': return new AtlasSprite(x, y, 'resultScreen/results-pico/resultsPERFECT');

			case 'PicoGreatResults':
				var sprite:AtlasSprite = new AtlasSprite(x, y, 'resultScreen/results-pico/resultsGREAT');
				sprite.stretchSymbol('white');
				sprite.stretchSymbol('black');
				return sprite;

			case 'PicoGoodResults':
				var sprite:AtlasSprite = new AtlasSprite(x, y, 'resultScreen/results-pico/resultsGOOD');
				if(!sprite.loaded) return sprite;

				sprite.stretchSymbol('white small');
				sprite.stretchSymbol('blacksmall');

				// one of three intros, the rare ones having someone else getting shot at
				var mainName:String = null;
				sprite.player.onFrameChange.add(function(name:String, frame:Int)
				{
					if(mainName == null) mainName = name; //the first thing it's told to play is its whole timeline
					if(name != mainName || !sprite.visible) return;

					var intro:String = FlxG.random.bool(5) ? 'intro fat gf' : (FlxG.random.bool(20) ? 'intro cass' : 'intro');
					if(!sprite.player.exists(intro)) intro = 'intro';
					sprite.player.play(intro, true);
				});
				sprite.player.onFinish.add(function(name:String)
				{
					if(name == mainName || !sprite.player.exists('loop')) return;

					sprite.player.play('loop', true);
					sprite.player.looped = true;
				});
				return sprite;
		}

		trace('The results animation "$className" is a script class that was not found');
		return null;
	}

	// ------------------------------------------------------------------------------------------
	// The sequence
	// ------------------------------------------------------------------------------------------

	function startMusic():Void
	{
		if(leaving) return;

		var musicPath:String = getMusicPath();
		var mainKey:String = '$musicPath/$musicPath';
		if(!Paths.fileExists('music/$mainKey.${Paths.SOUND_EXT}', SOUND))
		{
			// one that's a file by itself instead of a folder
			if(Paths.fileExists('music/$musicPath.${Paths.SOUND_EXT}', SOUND)) mainKey = musicPath;
			else
			{
				trace('The results music "$musicPath" was not found');
				return;
			}
		}

		var introKey:String = '$musicPath/$musicPath-intro';
		if(Paths.fileExists('music/$introKey.${Paths.SOUND_EXT}', SOUND))
		{
			introMusicAudio = FlxG.sound.load(Paths.music(introKey), 1, false, null, true, true, null, function()
			{
				introMusicAudio = null;
				if(!leaving) FlxG.sound.playMusic(Paths.music(mainKey), 1, true);
			});
		}
		else FlxG.sound.playMusic(Paths.music(mainKey), 1, true);
	}

	function startRankTallySequence():Void
	{
		bgFlash.visible = true;
		FlxTween.tween(bgFlash, {alpha: 0}, 5 / 24);

		clearPercentLerp = Std.int(Math.max(0, clearPercentTarget - 36));

		var clearPercentCounter:ClearPercentCounter = new ClearPercentCounter(FlxG.width / 2 + 190, FlxG.height / 2 - 70, clearPercentLerp);
		FlxTween.tween(clearPercentCounter, {curNumber: clearPercentTarget}, 58 / 24, {
			ease: FlxEase.quartOut,
			onUpdate: function(_)
			{
				// Only click on whole numbers.
				if(clearPercentLerp != clearPercentCounter.curNumber)
				{
					clearPercentLerp = clearPercentCounter.curNumber;
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
			},
			onComplete: function(_)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				clearPercentCounter.curNumber = clearPercentTarget;
				clearPercentCounter.flash(true);
				new FlxTimer().start(0.4, function(_) clearPercentCounter.flash(false));

				new FlxTimer().start(0.25, function(_)
				{
					FlxTween.tween(clearPercentCounter, {alpha: 0}, 0.5, {
						startDelay: 0.5,
						ease: FlxEase.quartOut,
						onComplete: function(_) remove(clearPercentCounter)
					});
				});
			}
		});
		addLayered(clearPercentCounter, 450);
		refresh();
	}

	function displayRankText():Void
	{
		bgFlash.visible = true;
		bgFlash.alpha = 1;
		FlxTween.tween(bgFlash, {alpha: 0}, 14 / 24);

		var rankTextVert:FlxBackdrop = new FlxBackdrop(Paths.image('resultScreen/rankText/rankText' + RANK_NAMES[rank]), Y, 0, 30);
		rankTextVert.antialiasing = ClientPrefs.data.antialiasing;
		rankTextVert.x = FlxG.width - 44;
		rankTextVert.y = 100;
		addLayered(rankTextVert, 990);

		FlxFlicker.flicker(rankTextVert, 2 / 24 * 3, 2 / 24, true);

		// Scrolling.
		new FlxTimer().start(30 / 24, function(_) rankTextVert.velocity.y = -80);

		for (i in 0...12)
		{
			var rankTextBack:FlxBackdrop = new FlxBackdrop(Paths.image('resultScreen/rankText/rankScroll' + RANK_NAMES[rank]), X, 10, 0);
			rankTextBack.antialiasing = ClientPrefs.data.antialiasing;
			rankTextBack.x = FlxG.width / 2 - 320;
			rankTextBack.y = 50 + (135 * i / 2) + 10;
			rankTextBack.cameras = [cameraScroll];
			addLayered(rankTextBack, 100);

			// Scrolling.
			rankTextBack.velocity.x = (i % 2 == 0) ? -7.0 : 7.0;
		}

		refresh();
	}

	function afterRankTallySequence():Void
	{
		showSmallClearPercent();

		for (atlas in characterAtlasAnimations)
		{
			new FlxTimer().start(atlas.delay, function(_)
			{
				if(atlas.sprite == null || !atlas.sprite.exists) return;

				atlas.sprite.visible = true;
				atlas.sprite.player.play(atlas.startFrameLabel, true);

				if(atlas.sound != '')
				{
					var sound:String = stripLibrary(atlas.sound);
					withPlayerMod(function()
					{
						if(Paths.fileExists('sounds/$sound.${Paths.SOUND_EXT}', SOUND)) FlxG.sound.play(Paths.sound(sound));
					});
				}
			});
		}

		for (sparrow in characterSparrowAnimations)
		{
			new FlxTimer().start(sparrow.delay, function(_)
			{
				if(sparrow.sprite == null || !sparrow.sprite.exists) return;

				sparrow.sprite.visible = true;
				sparrow.sprite.animation.play('idle', true);
			});
		}
	}

	function timerThenSongName(timerLength:Float = 3.0, autoScroll:Bool = true):Void
	{
		movingSongStuff = false;

		difficulty.x = 555;

		var diffYTween:Float = 122;

		difficulty.y = -difficulty.height;
		FlxTween.tween(difficulty, {y: diffYTween}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.8});

		clearPercentSmall.x = (difficulty.x + difficulty.width) + 60;
		clearPercentSmall.y = -clearPercentSmall.height;
		FlxTween.tween(clearPercentSmall, {y: 122 - 5}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.85});

		songName.y = -songName.height;
		var fuckedupnumber:Float = -(songName.width * 0.5) * Math.sin(songName.angle * Math.PI / 180) - 10;
		FlxTween.tween(songName, {y: diffYTween - 25 - fuckedupnumber}, 0.5, {ease: FlxEase.expoOut, startDelay: 0.9});
		songName.x = clearPercentSmall.x + 94;

		new FlxTimer().start(timerLength, function(_)
		{
			var tempSpeed:FlxPoint = FlxPoint.get(speedOfTween.x, speedOfTween.y);

			speedOfTween.set(0, 0);
			FlxTween.tween(speedOfTween, {x: tempSpeed.x, y: tempSpeed.y}, 0.7, {ease: FlxEase.quadIn});

			movingSongStuff = autoScroll;
		});
	}

	function showSmallClearPercent():Void
	{
		addLayered(clearPercentSmall, 1000);
		clearPercentSmall.visible = true;
		clearPercentSmall.flash(true);
		new FlxTimer().start(0.4, function(_) clearPercentSmall.flash(false));

		clearPercentSmall.curNumber = clearPercentTarget;
		refresh();

		new FlxTimer().start(2.5, function(_) movingSongStuff = true);
	}

	// ------------------------------------------------------------------------------------------
	// Update
	// ------------------------------------------------------------------------------------------

	override function draw():Void
	{
		songName.clipRect = FlxRect.get(Math.max(0, 520 - songName.x), 0, FlxG.width, songName.height);

		// PROBABLY should fix clearPercentSmall, or change how it works
		clearPercentSmall.forEachAlive(function(spr:FlxSprite) spr.clipRect = FlxRect.get(Math.max(0, 520 - spr.x), 0, FlxG.width, spr.height));

		super.draw();
	}

	override function update(elapsed:Float):Void
	{
		maskShaderDifficulty.swagSprX = difficulty.x;

		if(movingSongStuff)
		{
			var speedX:Float = speedOfTween.x * 60 * elapsed;
			var speedY:Float = speedOfTween.y * 60 * elapsed;

			songName.x += speedX;
			difficulty.x += speedX;
			clearPercentSmall.x += speedX;
			songName.y += speedY;
			difficulty.y += speedY;
			clearPercentSmall.y += speedY;

			if(songName.x + songName.width < 100) timerThenSongName();
		}

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.menuUpdate(elapsed);
		#end

		if(!leaving && (controls.ACCEPT || controls.PAUSE || controls.BACK)) leave();

		super.update(elapsed);
	}

	// ------------------------------------------------------------------------------------------
	// Leaving
	// ------------------------------------------------------------------------------------------

	function leave():Void
	{
		leaving = true;

		// the music winds down like a record being stopped
		var fading:FlxSound = (introMusicAudio != null) ? introMusicAudio : FlxG.sound.music;
		if(introMusicAudio != null) introMusicAudio.onComplete = null;

		if(fading != null && fading.playing)
		{
			FlxTween.tween(fading, {volume: 0}, 0.8);
			FlxTween.tween(fading, {pitch: 3}, 0.1, {onComplete: function(_) FlxTween.tween(fading, {pitch: 0.5}, 0.4)});
		}

		// with the stickers the screen is covered while the music winds down, without them it's waited for
		if(ClientPrefs.data.stickerTransition) switchToMenu();
		else new FlxTimer().start(0.9, function(_) switchToMenu());
	}

	function switchToMenu():Void
	{
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.endMenu(this);
		#end

		backend.StickerTransition.prepare();
		Mods.loadTopMod();
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

		var target:flixel.FlxState;
		if(params.storyMode) target = new StoryMenuState();
		else if(ClientPrefs.data.freeplayStyle == 'V-Slice') target = new FreeplayStateVslice();
		else target = new FreeplayState();

		// the menu's music only starts when the menu is about to show up
		FlxG.signals.preStateSwitch.addOnce(startMenuMusic);
		backend.StickerTransition.switchState(target);
	}

	function startMenuMusic():Void
	{
		if(introMusicAudio != null)
		{
			FlxTween.cancelTweensOf(introMusicAudio);
			introMusicAudio.onComplete = null;
			introMusicAudio.stop();
			introMusicAudio = null;
		}
		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.stop();
			FlxG.sound.music.pitch = 1;
		}

		FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}

	override function destroy():Void
	{
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.endMenu(this);
		#end

		if(introMusicAudio != null)
		{
			introMusicAudio.onComplete = null;
			introMusicAudio.stop();
		}
		introMusicAudio = null;

		speedOfTween.put();
		super.destroy();
	}
}
