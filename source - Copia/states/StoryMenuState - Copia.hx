package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;

import objects.MenuItem;
import objects.MenuCharacter;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import backend.StageData;

class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	var scoreText:FlxText;

	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;

	private static var curWeek:Int = 0;

	var txtTracklist:FlxText;

	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
    var upArrow:FlxSprite;
    var downArrow:FlxSprite;

	var loadedWeeks:Array<WeekData> = [];

	override function create()
    {
        Paths.clearStoredMemory();
        Paths.clearUnusedMemory();

        persistentUpdate = persistentDraw = true;
        PlayState.isStoryMode = true;
        WeekData.reloadWeekFiles(true);

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Menus", null);
        #end

        if(WeekData.weeksList.length < 1)
        {
            FlxTransitionableState.skipNextTransIn = true;
            persistentUpdate = false;
            MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
                function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
                function() MusicBeatState.switchState(new states.MainMenuState())));
            return;
        }

        if(curWeek >= WeekData.weeksList.length) curWeek = 0;

        var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
        bgSprite = new FlxSprite(0, 56);
        bgSprite.visible = false; // Esconde os fundos coloridos originais

        var divider:FlxSprite = new FlxSprite(FlxG.width / 2, 0).loadGraphic(Paths.image('storymenu/story_divider'));
        divider.screenCenter(Y);
        add(divider);

        var plaque:FlxSprite = new FlxSprite(175, 15).loadGraphic(Paths.image('storymenu/week_plaque'));
        plaque.scale.set(0.25, 0.15);
		plaque.updateHitbox();
        add(plaque);

        var listX:Float = (FlxG.width / 2) + 260;

        upArrow = new FlxSprite(listX, 30);
        upArrow.antialiasing = ClientPrefs.data.antialiasing;
        upArrow.frames = ui_tex;
        upArrow.animation.addByPrefix('idle', "arrow left");
        upArrow.animation.addByPrefix('press', "arrow push left");
        upArrow.animation.play('idle');
        upArrow.angle = 90;
        add(upArrow);

        downArrow = new FlxSprite(listX, FlxG.height - 80);
        downArrow.antialiasing = ClientPrefs.data.antialiasing;
        downArrow.frames = ui_tex;
        downArrow.animation.addByPrefix('idle', 'arrow right');
        downArrow.animation.addByPrefix('press', "arrow push right", 24, false);
        downArrow.animation.play('idle');
        downArrow.angle = 90;
        add(downArrow);

        txtWeekTitle = new FlxText(50, 40, (FlxG.width / 2) - 100, "", 32);
        txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
        txtWeekTitle.alpha = 0.7;

        scoreText = new FlxText(280, FlxG.height - 190, 0, Language.getPhrase('week_score', 'WEEK SCORE: {1}', [lerpScore]), 36);
        scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

        grpWeekText = new FlxTypedGroup<MenuItem>();
        add(grpWeekText);
        grpLocks = new FlxTypedGroup<FlxSprite>();
        add(grpLocks);

        var num:Int = 0;
        var itemTargetY:Float = 0;
        for (i in 0...WeekData.weeksList.length)
        {
            var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
            var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
            if(!isLocked || !weekFile.hiddenUntilUnlocked)
            {
                loadedWeeks.push(weekFile);
                WeekData.setDirectoryFromWeek(weekFile);
                var weekThing:MenuItem = new MenuItem(0, bgSprite.y, WeekData.weeksList[i]);
                weekThing.y += ((weekThing.height + 20) * num);
                weekThing.ID = num;
                weekThing.targetY = itemTargetY;
                itemTargetY += Math.max(weekThing.height, 110) + 10;
                
                weekThing.x = (FlxG.width / 2) + 180; 
                grpWeekText.add(weekThing);

                if (isLocked)
                {
                    var lock:FlxSprite = new FlxSprite(weekThing.width + 10 + weekThing.x);
                    lock.antialiasing = ClientPrefs.data.antialiasing;
                    lock.frames = ui_tex;
                    lock.animation.addByPrefix('lock', 'lock');
                    lock.animation.play('lock');
                    lock.ID = i;
                    grpLocks.add(lock);
                }
                num++;
            }
        }

        grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
        WeekData.setDirectoryFromWeek(loadedWeeks[0]);
        var charArray:Array<String> = loadedWeeks[0].weekCharacters;
        for (char in 0...3)
        {
            var weekCharacterThing:MenuCharacter = new MenuCharacter(0, charArray[char]);
            if (char == 1) {
                weekCharacterThing.x = 50; 
                weekCharacterThing.y = 200;
            } else {
                weekCharacterThing.x = -2000; 
                weekCharacterThing.visible = false;
            }
            grpWeekCharacters.add(weekCharacterThing);
        }
        add(grpWeekCharacters);

        difficultySelectors = new FlxGroup();
        add(difficultySelectors);

        leftArrow = new FlxSprite(30, FlxG.height - 100);
        leftArrow.antialiasing = ClientPrefs.data.antialiasing;
        leftArrow.frames = ui_tex;
        leftArrow.animation.addByPrefix('idle', "arrow left");
        leftArrow.animation.addByPrefix('press', "arrow push left");
        leftArrow.animation.play('idle');
        leftArrow.scale.set(0.5, 0.5);
        leftArrow.updateHitbox();
        difficultySelectors.add(leftArrow);

        Difficulty.resetList();
        if(lastDifficultyName == '') lastDifficultyName = Difficulty.getDefault();
        curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
        
        sprDifficulty = new FlxSprite(leftArrow.x + 60, leftArrow.y);
        sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;
        difficultySelectors.add(sprDifficulty);

        rightArrow = new FlxSprite(leftArrow.x + 230, leftArrow.y);
        rightArrow.antialiasing = ClientPrefs.data.antialiasing;
        rightArrow.frames = ui_tex;
        rightArrow.animation.addByPrefix('idle', 'arrow right');
        rightArrow.animation.addByPrefix('press', "arrow push right", 24, false);
        rightArrow.animation.play('idle');
        rightArrow.scale.set(0.5, 0.5);
        rightArrow.updateHitbox();
        difficultySelectors.add(rightArrow);

        var tracksSprite:FlxSprite = new FlxSprite(380, 160).loadGraphic(Paths.image('Menu_Tracks'));
        tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
        add(tracksSprite);

        txtTracklist = new FlxText(380, tracksSprite.y + 60, 0, "", 32);
        txtTracklist.alignment = CENTER;
        txtTracklist.font = Paths.font("vcr.ttf");
        txtTracklist.color = 0xFFe55777;
        add(txtTracklist);

        add(scoreText);
        add(txtWeekTitle);

        changeWeek();
        changeDifficulty();

        super.create();
    }

	override function closeSubState() {
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
	}

	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1)
		{
			if (controls.BACK && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(new MainMenuState());
			}
			super.update(elapsed);
			return;
		}

		// scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		if(intendedScore != lerpScore)
		{
			lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
			if(Math.abs(intendedScore - lerpScore) < 10) lerpScore = intendedScore;
	
			scoreText.text = Language.getPhrase('week_score', 'WEEK SCORE: {1}', [lerpScore]);
		}

		// FlxG.watch.addQuick('font', scoreText.font);

		if (!movedBack && !selectedWeek)
		{
			var changeDiff = false;
			if (controls.UI_UP_P)
			{
				changeWeek(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if (controls.UI_DOWN_P)
			{
				changeWeek(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changeWeek(-FlxG.mouse.wheel);
				changeDifficulty();
			}

			if (controls.UI_RIGHT) rightArrow.animation.play('press')
			else rightArrow.animation.play('idle');
				
			if (controls.UI_LEFT) leftArrow.animation.play('press');	
			else leftArrow.animation.play('idle');	

            if (controls.UI_UP) upArrow.animation.play('press');
            else upArrow.animation.play('idle');

            if (controls.UI_DOWN) downArrow.animation.play('press');
            else downArrow.animation.play('idle');

			if (controls.UI_RIGHT_P)
				changeDifficulty(1);
			else if (controls.UI_LEFT_P)
				changeDifficulty(-1);
			else if (changeDiff)
				changeDifficulty();

			if(FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			else if(controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
				//FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			else if (controls.ACCEPT)
				selectWeek();
		}

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);
		
		var offY:Float = grpWeekText.members[curWeek].targetY;
        for (num => item in grpWeekText.members)
        {
            item.y = FlxMath.lerp(item.targetY - offY + 340, item.y, Math.exp(-elapsed * 10.2));

            var targetScale:Float = (num == curWeek) ? 1.0 : 0.65;
            
            var currentScale:Float = FlxMath.lerp(targetScale, item.scale.x, Math.exp(-elapsed * 10.2));
            item.scale.set(currentScale, currentScale);
        }

        for (num => lock in grpLocks.members)
            lock.y = grpWeekText.members[lock.ID].y + grpWeekText.members[lock.ID].height/2 - lock.height/2;
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			// We can't use Dynamic Array .copy() because that crashes HTML5, here's a workaround.
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			// Nevermind that's stupid lmao
			try
			{
				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;
				selectedWeek = true;
	
				var diffic = Difficulty.getFilePath(curDifficulty);
				if(diffic == null) diffic = '';
	
				PlayState.storyDifficulty = curDifficulty;
	
				Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
			}
			catch(e:Dynamic)
			{
				trace('ERROR! $e');
				return;
			}
			
			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				grpWeekText.members[curWeek].isFlashing = true;
				for (char in grpWeekCharacters.members)
				{
					if (char.character != '' && char.hasConfirmAnimation)
					{
						char.animation.play('confirm');
					}
				}
				stopspamming = true;
			}

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				LoadingState.loadAndSwitchState(new PlayState(), true);
				FreeplayState.destroyFreeplayVocals();
			});
			
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function changeDifficulty(change:Int = 0):Void
    {
        curDifficulty += change;

        if (curDifficulty < 0) curDifficulty = Difficulty.list.length-1;
        if (curDifficulty >= Difficulty.list.length) curDifficulty = 0;

        WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

        var diff:String = Difficulty.getString(curDifficulty, false);
        var newImage:FlxGraphic = Paths.image('menudifficulties/' + Paths.formatToSongPath(diff));

        if(sprDifficulty.graphic != newImage)
        {
            sprDifficulty.loadGraphic(newImage);
            
            sprDifficulty.scale.set(0.7, 0.7); 
            sprDifficulty.updateHitbox(); 

            sprDifficulty.x = leftArrow.x + leftArrow.width + 15;
            
            sprDifficulty.y = leftArrow.y - (sprDifficulty.height / 2) + (leftArrow.height / 2);
            sprDifficulty.alpha = 0;

            FlxTween.cancelTweensOf(sprDifficulty);
            FlxTween.tween(sprDifficulty, {y: sprDifficulty.y + 10, alpha: 1}, 0.07);
            
            rightArrow.x = sprDifficulty.x + sprDifficulty.width + 15;
        }
        lastDifficultyName = diff;

        #if !switch
        intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
        #end
    }

	var lerpScore:Int = 49324858;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
    {
        curWeek += change;

        if (curWeek >= loadedWeeks.length) curWeek = 0;
        if (curWeek < 0) curWeek = loadedWeeks.length - 1;

        var leWeek:WeekData = loadedWeeks[curWeek];
        WeekData.setDirectoryFromWeek(leWeek);

        var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);
        txtWeekTitle.text = leName.toUpperCase();
        
        txtWeekTitle.x = 50; 

        var unlocked:Bool = !weekIsLocked(leWeek.fileName);
        for (num => item in grpWeekText.members)
        {
            item.alpha = 0.6;
            if (num - curWeek == 0 && unlocked)
                item.alpha = 1;
        }

        PlayState.storyWeek = curWeek;

        Difficulty.loadFromWeek();
        difficultySelectors.visible = unlocked;

        if(Difficulty.list.contains(Difficulty.getDefault()))
            curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
        else
            curDifficulty = 0;

        var newPos:Int = Difficulty.list.indexOf(lastDifficultyName);
        if(newPos > -1)
        {
            curDifficulty = newPos;
        }
        updateText();
    }

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
    {
        var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
        for (i in 0...grpWeekCharacters.length) {
            grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
        }

        var leWeek:WeekData = loadedWeeks[curWeek];
        var stringThing:Array<String> = [];
        for (i in 0...leWeek.songs.length) {
            stringThing.push(leWeek.songs[i][0]);
        }

        txtTracklist.text = '';
        for (i in 0...stringThing.length)
        {
            txtTracklist.text += stringThing[i] + '\n';
        }

        txtTracklist.text = txtTracklist.text.toUpperCase();

        txtTracklist.x = 380; 

        #if !switch
        intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
        #end
    }
}
