package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.util.FlxStringUtil;

import states.StoryMenuState;
import states.FreeplayState;
import states.FreeplayStateVslice;
import options.OptionsState;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	public static var songName:String = null;

	override function create()
	{
		if(Difficulty.list.length < 2) menuItemsOG.remove('Change Difficulty'); //No need to change difficulty if there is only one!
		if(PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');
			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		} else if(PlayState.instance.practiceMode && !PlayState.instance.startingSong)
			menuItemsOG.insert(3, 'Skip Time');

		// Online, the song is the other player's too: it can only go on, or both go back to the lobby
		if(backend.NetworkManager.connected) menuItemsOG = ['Resume', 'Exit to Lobby'];
		menuItems = menuItemsOG;

		for (i in 0...Difficulty.list.length) {
			var diff:String = Difficulty.getString(i);
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		pauseMusic = new FlxSound();
		try
		{
			var pauseSong:String = getPauseSong();
			if(pauseSong != null) pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
		}
		catch(e:Dynamic) {}
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, Difficulty.getString().toUpperCase(), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(20, 15 + 64, 0, Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]), 32);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 32);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		practiceText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Practice Mode").toUpperCase(), 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.x = FlxG.width - (practiceText.width + 20);
		practiceText.updateHitbox();
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Charting Mode").toUpperCase(), 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), 32);
		chartingText.x = FlxG.width - (chartingText.width + 20);
		chartingText.y = FlxG.height - (chartingText.height + 20);
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		blueballedTxt.alpha = 0;
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		missingTextBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		missingTextBG.scale.set(FlxG.width, FlxG.height);
		missingTextBG.updateHitbox();
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		regenMenu();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}
	
	function getPauseSong()
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		if(formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none')) return null;

		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;

	// Online: resuming counts "3, 2, 1" on both screens first, so both players are ready. Seconds left, -1 when not counting
	var resumeCountdown:Float = -1;
	var countdownText:FlxText;
	var countdownShown:Int = -1;

	/**
	 * Starts counting down to resuming (online). `delay` is waited first: the one who resumed waits for the message to get to
	 * the other player, so both counts end together.
	 */
	public function startResumeCountdown(delay:Float = 0):Void
	{
		if(resumeCountdown >= 0) return;
		resumeCountdown = 3 + Math.max(0, delay);
		countdownShown = -1;

		grpMenuShit.visible = false;
		missingText.visible = false;
		missingTextBG.visible = false;
		pauseMusic.stop();

		countdownText = new FlxText(0, 0, FlxG.width, "", 160);
		countdownText.setFormat(Paths.font("vcr.ttf"), 160, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		countdownText.borderSize = 6;
		countdownText.screenCenter(Y);
		add(countdownText);
	}

	function updateResumeCountdown(elapsed:Float):Bool
	{
		if(resumeCountdown < 0) return false;

		resumeCountdown -= elapsed;
		if(resumeCountdown <= 0)
		{
			FlxG.sound.play(Paths.sound('introGo'), 0.6);
			// (both know already: closing doesn't tell the other one again)
			PlayState.instance.resumedByNetwork = true;
			close();
			return true;
		}

		var number:Int = Math.ceil(resumeCountdown);
		if(number <= 3 && number != countdownShown)
		{
			countdownShown = number;
			countdownText.text = Std.string(number);
			countdownText.alpha = 1;
			countdownText.scale.set(1.3, 1.3);
			FlxTween.cancelTweensOf(countdownText);
			FlxTween.tween(countdownText.scale, {x: 1, y: 1}, 0.3, {ease: FlxEase.backOut});
			FlxTween.tween(countdownText, {alpha: 0.25}, 0.9, {startDelay: 0.1});
			FlxG.sound.play(Paths.sound('intro' + number), 0.6);
		}
		return true;
	}

	// Resuming: online it's counted down on both screens first
	function resume():Void
	{
		if(backend.NetworkManager.connected)
		{
			if(resumeCountdown >= 0) return;
			backend.NetworkManager.send("UNPAUSE_GAME");
			startResumeCountdown(backend.NetworkManager.latency / 1000);
			return;
		}
		close();
	}
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		// Online: the other player resumed (both count down), or left the song
		if(backend.NetworkManager.connected)
		{
			for (msg in backend.NetworkManager.getNewMessages())
			{
				if(msg == "UNPAUSE_GAME") startResumeCountdown();
				if(msg == "RETURN_TO_LOBBY")
				{
					PlayState.instance.onlineBackToLobby(Language.getPhrase('online_other_left_song', "The other player went back to the lobby."));
					return;
				}
			}
		}
		if(updateResumeCountdown(elapsed)) return;

		if(controls.BACK)
		{
			resume();
			return;
		}

		if(FlxG.keys.justPressed.F5)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			PlayState.nextReloadAll = true;
			MusicBeatState.resetState();
		}

		updateSkipTextStuff();
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if(holdTime > 0.5)
					{
						curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					}

					if(curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
					else if(curTime < 0) curTime += FlxG.sound.music.length;
					updateSkipTimeText();
				}
		}

		if (controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				var songLowercase:String = Paths.formatToSongPath(PlayState.SONG.song);
				var poop:String = Highscore.formatSong(songLowercase, curSelected);
				try
				{
					if(menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
					{
						Song.loadFromJson(poop, songLowercase);
						PlayState.storyDifficulty = curSelected;
						MusicBeatState.resetState();
						FlxG.sound.music.volume = 0;
						PlayState.changedDifficulty = true;
						PlayState.chartingMode = false;
						return;
					}
				}
				catch(e:haxe.Exception)
				{
					trace('ERROR! ${e.message}');
	
					var errorStr:String = e.message;
					if(errorStr.startsWith('[lime.utils.Assets] ERROR:')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
					else errorStr += '\n\n' + e.stack;

					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					super.update(elapsed);
					return;
				}


				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					resume();
				case 'Exit to Lobby':
					backend.NetworkManager.send("RETURN_TO_LOBBY");
					PlayState.instance.onlineBackToLobby();
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();
				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;
				case "Restart Song":
					restartSong();
				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;
				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}
				case 'End Song':
					close();
					PlayState.instance.notes.clear();
					PlayState.instance.unspawnNotes = [];
					PlayState.instance.finishSong(true);
				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
				case 'Options':
					PlayState.instance.paused = true; // For lua
					PlayState.instance.vocals.volume = 0;
					PlayState.instance.canResync = false;
					MusicBeatState.switchState(new OptionsState());
					if(ClientPrefs.data.pauseMusic != 'None')
					{
						FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
						FlxG.sound.music.time = pauseMusic.time;
					}
					OptionsState.onPlayState = true;
				case "Exit to menu":
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					PlayState.instance.canResync = false;
					backend.StickerTransition.prepare();
					Mods.loadTopMod();
					if(PlayState.isStoryMode)
						backend.StickerTransition.switchState(new StoryMenuState());
					else 
						if (ClientPrefs.data.freeplayStyle == 'V-Slice') {
							backend.StickerTransition.switchState(new FreeplayStateVslice());
						} else {
							backend.StickerTransition.switchState(new FreeplayState());
						}

					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					FlxG.camera.followLerp = 0;
			}
		}
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}

	override function destroy()
	{
		pauseMusic.destroy();
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		for (num => item in grpMenuShit.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}
		missingText.visible = false;
		missingTextBG.visible = false;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function regenMenu():Void {
		for (i in 0...grpMenuShit.members.length)
		{
			var obj:Alphabet = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (num => str in menuItems) {
			var item = new Alphabet(90, 320, Language.getPhrase('pause_$str', str), true);
			item.isMenuItem = true;
			item.targetY = num;
			grpMenuShit.add(item);

			if(str == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		changeSelection();
	}
	
	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
}
