package states;

import backend.WeekData;
import backend.Highscore;
import backend.PlayableCharacters;
import backend.Song;
import backend.SoundLoader;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	public var songs:Array<SongMetadata> = [];

	public var selector:FlxText;
	public static var curSelected:Int = 0; // static so the menu remembers the song when you come back
	public var lerpSelected:Float = 0;
	public var curDifficulty:Int = -1;
	public static var lastDifficultyName:String = Difficulty.getDefault();

	public var scoreBG:FlxSprite;
	public var scoreText:FlxText;
	public var diffText:FlxText;

	// Who the songs are played with, picked right here with Q and E: this menu has no Character Select
	public var charLabel:FlxText;
	public var charText:FlxText;
	var players:Array<PlayableCharacter> = [];
	var curPlayer:Int = 0;

	// the tracks of the song that's about to be listened to, while they're being loaded
	var audioLoads:Array<Int> = null;
	public var lerpScore:Int = 0;
	public var lerpRating:Float = 0;
	public var intendedScore:Int = 0;
	public var intendedRating:Float = 0;

	public var grpSongs:FlxTypedGroup<Alphabet>;
	public var curPlaying:Bool = false;

	public var iconArray:Array<HealthIcon> = [];

	public var bg:FlxSprite;
	public var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	override function create()
	{
		
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the FreePlay", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
			return;
		}

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

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			
			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 122, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		charLabel = new FlxText(scoreText.x, diffText.y + 32, 0, Language.getPhrase('freeplay_character', 'CHARACTER'), 16);
		charLabel.font = scoreText.font;
		add(charLabel);

		charText = new FlxText(scoreText.x, charLabel.y + 20, 0, "", 24);
		charText.font = scoreText.font;
		add(charText);

		for (playable in PlayableCharacters.list())
			if(playable.unlocked)
				players.push(playable);

		var picked:PlayableCharacter = PlayableCharacters.getCurrent();
		curPlayer = Math.round(Math.max(0, players.indexOf(picked)));

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

		var leText:String = Language.getPhrase("freeplay_tip_character", "SPACE: Listen to the Song / CTRL: Gameplay Changers / RESET: Reset Score and Accuracy / Q and E: Change Character");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		changeCharacter(0, false);
		changeSelection();
		updateTexts();
		super.create();
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
		if(WeekData.weeksList.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

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

			if(players.length > 1 && audioLoads == null)
			{
				if(FlxG.keys.justPressed.Q) changeCharacter(-1);
				else if(FlxG.keys.justPressed.E) changeCharacter(1);
			}
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

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE && audioLoads == null)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				Mods.currentModDirectory = songs[curSelected].folder;
				var songLowercase:String = songs[curSelected].songName.toLowerCase();
				var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
				try
				{
					Song.loadFromJson(poop, songLowercase);
					if(PlayState.SONG == null) throw 'Missing file: $songLowercase/$poop.json';
				}
				catch(e:Dynamic)
				{
					// a song without that chart, which used to close the game
					missingText.text = 'ERROR WHILE LOADING CHART:\n$e';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					updateTexts(elapsed);
					super.update(elapsed);
					return;
				}

				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				// The song's tracks are read by another thread (see backend.SoundLoader): the menu keeps going while they aren't ready,
				// instead of freezing for as long as it takes
				var songName:String = PlayState.SONG.song;
				var files:Array<String> = [SoundLoader.getFile(Paths.instKey(songName), 'songs'), null, null];
				if (PlayState.SONG.needsVoices)
				{
					var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
					files[1] = getVocalsFile(songName, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player', true);

					var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
					files[2] = getVocalsFile(songName, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent', false);
				}

				var selected:Int = curSelected;
				audioLoads = SoundLoader.loadAll(files, function(sounds:Array<openfl.media.Sound>)
				{
					audioLoads = null;
					if(curSelected != selected || player.playingMusic) return; //it was scrolled away from in the meantime
					if(sounds[0] == null)
					{
						missingText.text = 'ERROR WHILE LOADING THE SONG:\nMissing file: ' + files[0];
						missingText.screenCenter(Y);
						missingText.visible = true;
						missingTextBG.visible = true;
						FlxG.sound.play(Paths.sound('cancelMenu'));
						return;
					}

					vocals = makeVocals(sounds[1]);
					opponentVocals = makeVocals(sounds[2]);

					FlxG.sound.playMusic(sounds[0], 0.8);
					FlxG.sound.music.pause();
					instPlaying = curSelected;

					player.playingMusic = true;
					player.curTime = 0;
					player.switchPlayMusic();
					player.pauseOrResume(true);
				});
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			SoundLoader.cancelAll(audioLoads);
			audioLoads = null;

			persistentUpdate = false;
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
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
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
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(getScoreName(), curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
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

	/**
	 * The file of one of a song's vocal tracks, null if the song doesn't have it.
	 * The song's chart has to be the loaded one and its mod the current one.
	 *
	 * @param postfix 	"Player", "Opponent" or what a character's file has as its vocals.
	 * @param fallBack 	If the track everyone shares is to be used when there isn't one of its own.
	 */
	public static function getVocalsFile(songName:String, postfix:String, fallBack:Bool):String
	{
		// (a character's own track first, then the usual one of its side: see `Paths.characterVoices()`)
		var tries:Array<String> = [postfix];
		var usual:String = fallBack ? 'Player' : 'Opponent';
		if(postfix != usual) tries.push(usual);
		if(fallBack) tries.push(null);

		for (curPostfix in tries)
		{
			var key:String = Paths.voicesKey(songName, curPostfix);
			if(key == null) continue;

			var file:String = SoundLoader.getFile(key, 'songs');
			if(Paths.currentTrackedSounds.exists(file) #if sys || FileSystem.exists(file) #end) return file;
		}
		return null;
	}

	/**
	 * A vocal track ready to be played along with the song, null if there's nothing to play.
	 */
	public static function makeVocals(loaded:openfl.media.Sound):FlxSound
	{
		if(loaded == null || loaded.length <= 0) return null;

		var sound:FlxSound = new FlxSound();
		try
		{
			sound.loadEmbedded(loaded);
			FlxG.sound.list.add(sound);
			sound.persist = sound.looped = true;
			sound.volume = 0.8;
			sound.play();
			sound.pause();
			return sound;
		}
		catch(e:Dynamic) {}
		return FlxDestroyUtil.destroy(sound);
	}

	/**
	 * Goes to the next or the previous of the characters the songs can be played with.
	 * On songs from V-Slice mods that picks the chart made for that character, when there is one; on the others it takes Boyfriend's place.
	 */
	public function changeCharacter(change:Int = 0, playSound:Bool = true)
	{
		if(players.length < 1)
		{
			charText.text = '';
			return;
		}

		curPlayer = FlxMath.wrap(curPlayer + change, 0, players.length - 1);
		var picked:PlayableCharacter = players[curPlayer];

		if(change != 0)
		{
			PlayableCharacters.select(picked.id);
			ClientPrefs.saveSettings();
			if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

			// what was being listened to could be another character's version of the song
			instPlaying = -1;
		}

		var name:String = (picked.name != null && picked.name.length > 0) ? picked.name : picked.id;
		charText.text = (players.length > 1) ? '< ' + name.toUpperCase() + ' >' : name.toUpperCase();
		positionHighscore();
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	// The name the scores of the selected song are kept under: each mix of a V-Slice song has its own, see Highscore.scoreName()
	function getScoreName():String
	{
		var song = songs[curSelected];
		#if MODS_ALLOWED
		return Highscore.scoreName(song.songName, backend.PolymodCompat.getVariationId(song.folder, song.songName, Difficulty.getString(curDifficulty, false)));
		#else
		return song.songName;
		#end
	}

	public function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(getScoreName(), curDifficulty);
		intendedRating = Highscore.getRating(getScoreName(), curDifficulty);
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
	}

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
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
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

		if(charText != null)
		{
			charLabel.x = Std.int(scoreBG.x + (scoreBG.width / 2)) - charLabel.width / 2;
			charText.x = Std.int(scoreBG.x + (scoreBG.width / 2)) - charText.width / 2;
		}
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
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		SoundLoader.cancelAll(audioLoads);
		audioLoads = null;
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}