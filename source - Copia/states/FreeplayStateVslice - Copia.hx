package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;

import haxe.Json;
import states.FreeplayState.SongMetadata;

import flixel.group.FlxSpriteGroup;
import openfl.filters.GlowFilter;
import openfl.filters.BitmapFilterQuality;
import flixel.math.FlxPoint;
import flxanimate.FlxAnimate;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import flixel.system.FlxSound;

class FreeplayStateVslice extends MusicBeatState
{
	public static var checkPlayedSong:Bool = false;
	public static var checkScoreBefore:Int = 0;
	public static var checkDiffBefore:Int = 0;
	public static var checkSongBefore:String = "";
	public static var playerDied:Bool = false; 
	
	public var songs:Array<SongMetadata> = [];

	public var selector:FlxText;
	//public var curSelected:Int = 0;
	public static var curSelected:Int = 0;
	public var lerpSelected:Float = 0;
	public var curDifficulty:Int = -1;
	public static var lastDifficultyName:String = Difficulty.getDefault();

	public var scoreBG:FlxSprite;
	public var scoreText:FlxText;
	public var diffText:FlxText;
	public var lerpScore:Int = 0;
	public var lerpRating:Float = 0;
	public var intendedScore:Int = 0;
	public var intendedRating:Float = 0;

	public var grpSongs:FlxTypedGroup<VSliceSongText>;
	
	public var curPlaying:Bool = false;
	public var isTransitioning:Bool = false;
	public var customFade:FlxSprite;
	public var afkTimer:Float = 0;

	public var iconArray:Array<HealthIcon> = [];

	public var bg:FlxSprite;
	public var pinkBack:FlxSprite;
	public var cardGlow:FlxSprite;
	public var leftArrowSprite:FlxSprite;
	public var rightArrowSprite:FlxSprite;
	public var diffSprite:FlxSprite;
	public var diffTextGroup:FlxSpriteGroup;
	public var bfSelect:PsychFlxAnimate;
	public var backtext:FlxAnimate;
	public var bfAnimState:String = 'idle';
	public var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	// NOVAS VARIÁVEIS PARA A MÚSICA INSTRUMENTAL OTIMIZADA
	var instTimer:FlxTimer;
	var curPlayingInst:String = "";
	var inRankAnimation:Bool = false;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the FreePlay", null);
		#end

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

		addSong("Random", 1, "face", FlxColor.fromRGB(146, 113, 253));
		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		var targetX:Float = (1280 * 0.44) + -320;

		bg = new FlxSprite().loadGraphic(Paths.image('VsliceFreeplay/freeplayBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scale.set(1.5, 1.5);
		bg.updateHitbox();
		add(bg);
		bg.x = targetX + 150;
		bg.y = bg.y - 35;

		cardGlow = new FlxSprite().loadGraphic(Paths.image('VsliceFreeplay/cardGlow'));
		cardGlow.antialiasing = ClientPrefs.data.antialiasing;
		cardGlow.x = targetX - 250;
		add(cardGlow);

		pinkBack = new FlxSprite().loadGraphic(Paths.image('VsliceFreeplay/pinkBack'));
		pinkBack.antialiasing = ClientPrefs.data.antialiasing;
		pinkBack.x = targetX - 250;
		pinkBack.color = 0xFEF8A5;
		add(pinkBack);

		backtext = new FlxAnimate(targetX, 120, Paths.getPath('images/VsliceFreeplay/backing-text-yeah'));
		backtext.anim.play(''); 
		backtext.antialiasing = ClientPrefs.data.antialiasing;
		add(backtext);

		bfSelect = new PsychFlxAnimate(0, 0, Paths.getPath('images/VsliceFreeplay/freeplayboyfriend'));
		bfSelect.anim.play(''); 
		bfSelect.anim.curFrame = 0; 
		bfAnimState = 'intro_wait';
		bfSelect.antialiasing = ClientPrefs.data.antialiasing;
		add(bfSelect);

		leftArrowSprite = new FlxSprite(25, 50);
		leftArrowSprite.frames = Paths.getSparrowAtlas('VsliceFreeplay/freeplaySelector');
		leftArrowSprite.animation.addByPrefix('idle', 'arrow pointer loop', 24, true);
		leftArrowSprite.animation.play('idle');
		leftArrowSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(leftArrowSprite); 

		rightArrowSprite = new FlxSprite(150, 50);
		rightArrowSprite.frames = Paths.getSparrowAtlas('VsliceFreeplay/freeplaySelector');
		rightArrowSprite.animation.addByPrefix('idle', 'arrow pointer loop', 24, true);
		rightArrowSprite.animation.play('idle');
		rightArrowSprite.antialiasing = ClientPrefs.data.antialiasing;
		rightArrowSprite.flipX = true;
		add(rightArrowSprite);
		
		diffSprite = new FlxSprite(0, 0);
		diffSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(diffSprite);

		diffTextGroup = new FlxSpriteGroup(0, 0);
		add(diffTextGroup);

		// ===========================================================================
		// SISTEMA DE RANKS, ANIMAÇÃO E MÚSICA MUTADA COM PITCH BAIXO
		// ===========================================================================
		if (checkPlayedSong || playerDied) {
			
			// 1. Procura na lista e força a selecionar a música que você acabou de jogar
			for (i in 0...songs.length) {
				if (songs[i].songName == checkSongBefore) {
					curSelected = i;
					lerpSelected = curSelected;
					break;
				}
			}

			// 2. Trava e cala qualquer FreakyMenu que o jogo tentou carregar na transição
			if (FlxG.sound.music != null) FlxG.sound.music.stop();

			inRankAnimation = true;
			var newScore:Int = Highscore.getScore(checkSongBefore, checkDiffBefore);
			
			if (!playerDied && newScore > checkScoreBefore) { 
				bfAnimState = 'fist_pump';
				bfSelect.anim.curFrame = 59;
			} else { 
				bfAnimState = 'fist_pump_loss';
				bfSelect.anim.curFrame = 101;
			}
			
			bfSelect.pauseAnimation();

			// Prepara a música atual (Instrumental), deixando o Pitch em 0.1 e Volume em 0
			var songPath = Paths.formatToSongPath(songs[curSelected].songName);
			if (songPath != "random") {
				curPlayingInst = songPath;
				
				// AVISA O JOGO DE QUAL PASTA DE MOD PUXAR A MÚSICA
				Mods.currentModDirectory = songs[curSelected].folder;
				
				lastPreviewInst = Paths.inst(songPath);
				FlxG.sound.playMusic(lastPreviewInst, 0);
				if(FlxG.sound.music != null) FlxG.sound.music.pitch = 0.1;
			}

			// Delay para os Sons Iniciais
			new FlxTimer().start(0.3, function(tmr:FlxTimer) {
				var rankIntroSnd = FlxG.sound.play(Paths.sound('ranks/rankinnormal'));
				
				if (rankIntroSnd != null) {
					rankIntroSnd.onComplete = function() {
						if (bfSelect != null) bfSelect.resumeAnimation();
						
						var endSnd:FlxSound = null;
						if (bfAnimState == 'fist_pump') {
							endSnd = FlxG.sound.play(Paths.sound('ranks/perfect'));
						} else {
							endSnd = FlxG.sound.play(Paths.sound('ranks/loss'));
						}

						// QUANDO O SOM FINAL (PERFECT OU LOSS) ACABAR...
						if (endSnd != null) endSnd.onComplete = endRankAnimation;
						else endRankAnimation();
					};
				} else {
					if (bfSelect != null) bfSelect.resumeAnimation();
					endRankAnimation();
				}
			});
			
			checkPlayedSong = false;
			playerDied = false;
		} 
		else {
			// INÍCIO NORMAL DO MENU
			bfSelect.anim.curFrame = 0;
			bfAnimState = 'intro_wait';
			
			new FlxTimer().start(0.5, function(tmr:FlxTimer) {
				if (bfSelect != null) {
					bfAnimState = 'intro';
					bfSelect.anim.curFrame = 0;
				}
			});
		}
		// ===========================================================================


		var topBar:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		topBar.alpha = 0.7;
		add(topBar);

		var topTextLeft:FlxText = new FlxText(10, 8, 0, "FREEPLAY", 24);
		topTextLeft.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
		add(topTextLeft);

		var topTextRight:FlxText = new FlxText(0, 8, FlxG.width - 10, "NOT OFFICIAL OST", 24);
		topTextRight.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, RIGHT);
		add(topTextRight);

		grpSongs = new FlxTypedGroup<VSliceSongText>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:VSliceSongText = new VSliceSongText(350, 300, songs[i].songName);
			songText.targetY = i;
			songText.scrollFactor.set(1, 1);
			grpSongs.add(songText);

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);

			icon.scrollFactor.set(1, 1);
			
			songText.visible = songText.active = false;
			icon.visible = icon.active = false;

			iconArray.push(icon);
			add(icon);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);


		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		customFade = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		customFade.scrollFactor.set();
		customFade.alpha = 0;
		add(customFade);
		
		changeSelection();
		updateTexts();
		super.create();
	}

	function endRankAnimation()
	{
		inRankAnimation = false;

		// the player scrolled to another song while the animation was playing, preview that one instead
		if (Paths.formatToSongPath(songs[curSelected].songName) != curPlayingInst) playSelectedInst();
		else if (FlxG.sound.music != null) // Volta o Pitch para 1.0 e sobe o Volume!
			FlxTween.tween(FlxG.sound.music, {pitch: 1.0, volume: 1.0}, 1.5, {ease: FlxEase.quadInOut});
	}

	var lastPreviewInst:openfl.media.Sound = null;
	function playSelectedInst()
	{
		var songPath:String = Paths.formatToSongPath(songs[curSelected].songName);
		if (curPlayingInst == songPath) return;
		curPlayingInst = songPath;

		var isRandom:Bool = (songPath == "random");
		var sound:openfl.media.Sound = isRandom ? Paths.music('freakyMenu') : Paths.inst(songPath);

		if (FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
		FlxG.sound.playMusic(sound, 0);
		FlxTween.cancelTweensOf(FlxG.sound.music);
		FlxTween.tween(FlxG.sound.music, {volume: 0.7}, 0.5);

		// a decoded instrumental takes tens of MBs of RAM, don't keep every previewed song cached while scrolling
		if (lastPreviewInst != null && lastPreviewInst != sound)
		{
			for (key => cached in Paths.currentTrackedSounds)
			{
				if (cached != lastPreviewInst) continue;

				if (!Paths.dumpExclusions.contains(key))
				{
					Paths.currentTrackedSounds.remove(key);
					Paths.localTrackedAssets.remove(key);
				}
				break;
			}
		}
		lastPreviewInst = isRandom ? null : sound;
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{

		if (bfSelect != null && bfSelect.anim != null) {
			if (bfAnimState == 'intro_wait') {
				bfSelect.anim.curFrame = 0;
			}
			else if (bfAnimState == 'intro') {
				if (bfSelect.anim.curFrame >= 16) {
					bfAnimState = 'idle';
					bfSelect.anim.curFrame = 17;
				}
			}
			else if (bfAnimState == 'idle') {
				if (bfSelect.anim.curFrame >= 31 || bfSelect.anim.curFrame < 17) {
					bfSelect.anim.curFrame = 17;
				}
			} 
			else if (bfAnimState == 'fist_pump') {
				if (bfSelect.anim.curFrame >= 100) {
					bfAnimState = 'idle';
					bfSelect.anim.curFrame = 17;
				}
			}
			else if (bfAnimState == 'fist_pump_loss') {
				if (bfSelect.anim.curFrame >= 268) {
					bfAnimState = 'idle';
					bfSelect.anim.curFrame = 17;
				}
			}
			else if (bfAnimState == 'afk') {
				if (bfSelect.anim.curFrame >= 407) {
					bfAnimState = 'idle';
					bfSelect.anim.curFrame = 17;
					afkTimer = 0; 
				}
			}
			else if (bfAnimState == 'tv') {
				if (bfSelect.anim.curFrame >= 573 || bfSelect.anim.curFrame < 408) {
					bfSelect.anim.curFrame = 468;
				}
			}
			else if (bfAnimState == 'confirm') {
				if (bfSelect.anim.curFrame >= 58) {
					bfSelect.anim.curFrame = 58;
					bfSelect.pauseAnimation();
				}
			}
			else if (bfAnimState == 'To Character Select') {
				if (bfSelect.anim.curFrame >= 616) {
					bfSelect.anim.curFrame = 574;
					bfSelect.pauseAnimation();
				}
			}
		}

		if(WeekData.weeksList.length < 1)
			return;

		if (!isTransitioning && !player.playingMusic) {
			afkTimer += elapsed;
			if (afkTimer >= 30 && bfAnimState == 'idle') {
				if (FlxG.random.bool(50)) {
					bfAnimState = 'afk';
					if (bfSelect != null) bfSelect.anim.curFrame = 269;
				} else {
					bfAnimState = 'tv';
					if (bfSelect != null) bfSelect.anim.curFrame = 408;
				}
			}
		}

		if (controls.UI_UP_P || controls.UI_DOWN_P || controls.UI_LEFT_P || controls.UI_RIGHT_P || controls.ACCEPT || controls.BACK || FlxG.mouse.wheel != 0 || FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END || FlxG.keys.justPressed.SPACE) {
			afkTimer = 0;
		}

		if (!inRankAnimation && FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) 
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) 
			ratingSplit[1] += '0';

		
		if (!isTransitioning) 
		{
			var shiftMult:Int = 1;
			if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (FlxG.keys.justPressed.TAB && !player.playingMusic) 
		{
			isTransitioning = true;
			
			if (bfSelect != null) {
				bfAnimState = 'To Character Select';
				bfSelect.anim.curFrame = 574;
				bfSelect.resumeAnimation();
			}
			
			// Tira a distorção do audio se caso você dar TAB rápido demais
			if (FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0; 

			FlxG.sound.play(Paths.sound('scrollMenu'));
			FlxTransitionableState.skipNextTransOut = true;
			FlxTween.tween(FlxG.camera.scroll, {y: FlxG.camera.scroll.y + 100}, 1.25, {ease: FlxEase.backIn});
			FlxTween.tween(customFade, {alpha: 1}, 1.0, {ease: FlxEase.linear});
			
			new FlxTimer().start(1.2, function(tmr:FlxTimer) {
				MusicBeatState.switchState(new CharacterSelectState()); 
			});
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				// Retorna o áudio da música para a Instrumental (já que fechou o player)
				var songPath = Paths.formatToSongPath(songs[curSelected].songName);
				if (songPath == "random") {
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				} else {
					FlxG.sound.playMusic(Paths.inst(songPath), 0);
				}
				FlxTween.tween(FlxG.sound.music, {volume: 0.7}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				
				// Limpa o Pitch de distorção caso ele tenha cancelado rápido
				if(FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			if (songs[curSelected].songName.toLowerCase() == "random") return;

			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				if (FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;
				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				isTransitioning = true;
				persistentUpdate = false;
				
				// Normaliza o áudio se ele não terminou de carregar da Rank Screen
				if (FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0;

				if (bfSelect != null) {
					bfAnimState = 'confirm';
					bfSelect.anim.curFrame = 31;
					bfSelect.resumeAnimation();
				}

				if (songs[curSelected].songName.toLowerCase() == "random" && songs.length > 1) {
					curSelected = FlxG.random.int(1, songs.length - 1);
					changeSelection(0, false); 
				}

					checkPlayedSong = true;
					checkSongBefore = songs[curSelected].songName;
					checkDiffBefore = curDifficulty;
					checkScoreBefore = Highscore.getScore(checkSongBefore, checkDiffBefore);
					
				new FlxTimer().start(1.0, function(tmr:FlxTimer) {
					
					var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
					var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

					try
					{
						Song.loadFromJson(poop, songLowercase);
						PlayState.isStoryMode = false;
						PlayState.storyDifficulty = curDifficulty;
						trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
					}
					catch(e:haxe.Exception)
					{
						trace('ERROR! ${e.message}');
						var errorStr:String = e.message;
						if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1);
						else errorStr += '\n\n' + e.stack;

						missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
						missingText.screenCenter(Y);
						missingText.visible = true;
						missingTextBG.visible = true;
						FlxG.sound.play(Paths.sound('cancelMenu'));
						
						// the song never started: give the controls back and don't play the rank animation next time
						isTransitioning = false;
						persistentUpdate = true;
						checkPlayedSong = false;
						if (bfSelect != null) {
							bfAnimState = 'idle';
							bfSelect.anim.curFrame = 17;
							bfSelect.resumeAnimation();
						}
						return;
					}

					@:privateAccess
					if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
					{
						Paths.freeGraphicsFromMemory();
					}
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState());
					#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
					stopMusicPlay = true;

					destroyFreeplayVocals();
					#if (MODS_ALLOWED && DISCORD_ALLOWED)
					DiscordClient.loadModRPC();
					#end
				});
			}
			else if(controls.RESET && !player.playingMusic)
			{
				if (songs[curSelected].songName.toLowerCase() == "random") return;

				persistentUpdate = false;
				openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	var _lastDiffKey:String = null;
	public function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;

		// ====================================================================
		// SISTEMA DE SPRITE DE DIFICULDADE (Customizado + Fallback para Letras)
		// ====================================================================
		
		diffText.visible = false;

		// Pega o nome formatado (ex: "insane", "hard")
		var diffName:String = Difficulty.getString(curDifficulty, false).toLowerCase();

		// changeSelection() calls this on every scroll step, only rebuild when the graphic can actually be different
		var diffKey:String = Mods.currentModDirectory + '/' + diffName;
		if (diffKey == _lastDiffKey) return;
		_lastDiffKey = diffKey;

		// 1. LIMPEZA DE MEMÓRIA: Destrói as letras antigas antes de criar novas
		while(diffTextGroup.members.length > 0) {
			var spr = diffTextGroup.members[0];
			spr.kill();
			diffTextGroup.remove(spr, true);
			spr.destroy();
		}

		var safeDiff:String = Paths.formatToSongPath(diffName); 
		var diffImage:String = 'VsliceFreeplay/freeplay' + safeDiff;

		// 2. CHECAGEM DE ARQUIVO FÍSICO
		var hasImage:Bool = false;
		var hasXml:Bool = false;
		
		#if sys
		var pngPath = Paths.getPath('images/' + diffImage + '.png', IMAGE);
		var xmlPath = Paths.getPath('images/' + diffImage + '.xml', TEXT);
		if (sys.FileSystem.exists(pngPath)) hasImage = true;
		if (sys.FileSystem.exists(xmlPath)) hasXml = true;
		#else
		if (Paths.fileExists('images/' + diffImage + '.png', IMAGE)) hasImage = true;
		if (Paths.fileExists('images/' + diffImage + '.xml', TEXT)) hasXml = true;
		#end

		// Variáveis para as setas saberem onde abraçar
		var contentX:Float = 0;
		var contentY:Float = 0;
		var contentWidth:Float = 0;
		var contentHeight:Float = 0;
		var bounceTarget:Dynamic = null;

		// 3. SE A IMAGEM CUSTOMIZADA EXISTIR:
		if (hasImage) {
			diffTextGroup.visible = false;
			diffSprite.visible = true;
			
			if (hasXml) {
				diffSprite.frames = Paths.getSparrowAtlas(diffImage);
				diffSprite.animation.addByPrefix('idle', 'idle', 24, true);
				diffSprite.animation.play('idle');
			} else {
				diffSprite.frames = null; 
				diffSprite.loadGraphic(Paths.image(diffImage));
			}

			diffSprite.updateHitbox();
			diffSprite.x = 200 - (diffSprite.width / 2);
			diffSprite.y = 75 - (diffSprite.height / 2); 

			contentX = diffSprite.x;
			contentY = diffSprite.y;
			contentWidth = diffSprite.width;
			contentHeight = diffSprite.height;
			bounceTarget = diffSprite.scale;
			
		} 
		// 4. SE A IMAGEM NÃO EXISTIR (Monta as letras automaticamente!):
		else {
			diffSprite.visible = false;
			diffTextGroup.visible = true;

			var currentX:Float = 0;
			var maxHeight:Float = 0;

			for (i in 0...diffName.length) {
				var char:String = diffName.charAt(i);
				
				if (char == ' ') {
					currentX += 15; // Espaçamento da barra de espaço
					continue;
				}

				var letter:FlxSprite = new FlxSprite(currentX, 0);
				letter.frames = Paths.getSparrowAtlas('VsliceFreeplay/letterStuff');
				// Constrói o nome da animação baseando-se no arquivo letterStuff.xml
				letter.animation.addByPrefix('idle', char + ' instance 10000', 24, true);
				letter.animation.play('idle');
				letter.updateHitbox();
				letter.antialiasing = ClientPrefs.data.antialiasing;
				
				diffTextGroup.add(letter);
				
				currentX += letter.width + 2; // +2 pixels de distância (kerning) entre as letras
				if (letter.height > maxHeight) maxHeight = letter.height;
			}

			// Centraliza o GRUPO INTEIRO de letras no mesmo eixo do sprite antigo
			diffTextGroup.x = 160 - (currentX / 2);
			diffTextGroup.y = 75 - (maxHeight / 2);

			contentX = diffTextGroup.x;
			contentY = diffTextGroup.y;
			contentWidth = currentX;
			contentHeight = maxHeight;
			bounceTarget = diffTextGroup.scale;
		}

		// 5. AS SETAS ABRAÇAM O CONTEÚDO (seja ele Imagem ou Texto)
		leftArrowSprite.x = contentX - leftArrowSprite.width - 15;
		leftArrowSprite.y = contentY + (contentHeight / 2) - (leftArrowSprite.height / 2);

		rightArrowSprite.x = contentX + contentWidth + 15;
		rightArrowSprite.y = leftArrowSprite.y;

		// Efeito Bounce quando troca de dificuldade
		if (bounceTarget != null) {
			bounceTarget.set(1.1, 1.1);
			FlxTween.cancelTweensOf(bounceTarget);
			FlxTween.tween(bounceTarget, {x: 1, y: 1}, 0.15, {ease: FlxEase.cubeOut});
		}
	}
		// ====================================================================

	public function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			item.capsule.animation.play('unselected'); 
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				item.capsule.animation.play('selected'); 
				icon.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
		
		// =========================================================================
		// OTIMIZAÇÃO: CARREGA O INSTRUMENTAL APENAS QUANDO VOCÊ PARA DE SCROLLAR
		// =========================================================================
		if (!inRankAnimation) {
			if (instTimer != null) instTimer.cancel();
			
			instTimer = new FlxTimer().start(0.4, function(tmr:FlxTimer) playSelectedInst());
		}
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	public function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:VSliceSongText = grpSongs.members[i];
			item.visible = item.active = true;
			
			var distance:Float = item.targetY - lerpSelected;

			item.x = item.startPosition.x - (distance * distance * 10); 
			item.y = item.startPosition.y + (distance * 160); 

			var icon:HealthIcon = iconArray[i];
			
			if (songs[i].songName.toLowerCase() == "random") {
				icon.visible = false;
				icon.active = false;
			} else {
				icon.visible = true;
				icon.active = true;
				icon.x = item.x - 30; 
				icon.y = item.y + 10;
				icon.scale.set(0.75, 0.75);
			}

			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		// Impede que a distorção passe para outros States!
		if(FlxG.sound.music != null) FlxG.sound.music.pitch = 1.0; 
		
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	
}

class VSliceSongText extends FlxSpriteGroup
{
	public var targetY:Float = 0;
	public var distancePerItem:FlxPoint = new FlxPoint(20, 160); 
	public var startPosition:FlxPoint = new FlxPoint(0, 0);

	public var capsule:FlxSprite;
	public var whiteText:FlxText;
	public var blurredText:FlxText;

	public function new(x:Float, y:Float, text:String)
	{
		super(x, y);
		startPosition.set(x, y);

		capsule = new FlxSprite(0, 0);
		capsule.frames = Paths.getSparrowAtlas('VsliceFreeplay/freeplayCapsule/capsule/freeplayCapsule');
		capsule.animation.addByPrefix('selected', 'mp3 capsule w backing0', 24, true);
		capsule.animation.addByPrefix('unselected', 'mp3 capsule w backing NOT SELECTED0', 24, true);
		capsule.animation.play('unselected');
		capsule.antialiasing = ClientPrefs.data.antialiasing;
		add(capsule); 

		var size:Int = 37;
		var glowColor:FlxColor = 0xFF00ccff; 

		var textOffsetX:Float = 120; 
		var textOffsetY:Float = 45; 

		blurredText = new FlxText(textOffsetX, textOffsetY, 0, text, size);
		blurredText.font = Paths.font("5by7.ttf");
		blurredText.color = glowColor;
		add(blurredText);

		whiteText = new FlxText(textOffsetX, textOffsetY, 0, text, size);
		whiteText.font = Paths.font("5by7.ttf");
		whiteText.color = 0xFFFFFFFF;
		whiteText.textField.filters = [
			new GlowFilter(glowColor, 1, 5, 5, 210, BitmapFilterQuality.MEDIUM)
		];
		add(whiteText);
	}
}