package states;

import backend.WeekData;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import shaders.ColorSwap;

import states.StoryMenuState;
import states.MainMenuState;

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];

	var wackyImage:FlxSprite;

	override public function create():Void
	{
		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		if(!initialized)
		{
			ClientPrefs.loadPrefs();
			backend.NetworkManager.restoreSettings(); //(the player's own, if the game was closed during an online match)
			Language.reloadPhrases();
		}

		curWacky = FlxG.random.getObject(getIntroTextShit());

		if(!initialized)
		{
			// (the "Window Mode" option says if it's on fullscreen: the old save of it, which Alt+Enter changes, went over it)
			if(ClientPrefs.data.windowMode == null && FlxG.save.data != null && FlxG.save.data.fullscreen)
				FlxG.fullscreen = FlxG.save.data.fullscreen;
			persistentUpdate = true;
			persistentDraw = true;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		FlxG.mouse.visible = false;

		#if sys
		// the game was started with a song to open (see backend.DirectPlay)
		if(!initialized && backend.DirectPlay.start())
		{
			initialized = true;
			return;
		}
		#end

		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if(!BetaWarningState.leftState)
		{
			// (the engine is a beta: whoever opens it is told what to expect)
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new BetaWarningState());
		}
		else if(FlxG.save.data.flashing == null && !FlashingState.leftState)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else
			startIntro();
		#end
	}

	var logoBl:FlxSprite;
	var logoBaseScale:Float = 1.0;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;
	
	var spaceBg:FlxSprite;
    var portal1:FlxSprite;
    var portal2:FlxSprite;
    var portal3:FlxSprite;

	function startIntro()
	{
		persistentUpdate = true;
		if (!initialized && FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		
		if(ClientPrefs.data.shaders)
		{
			swagShader = new ColorSwap();
		}

		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x, enterPosition.y);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.32).loadGraphic(Paths.image('FNF_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.35));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

        spaceBg = new FlxSprite(0, 0).loadGraphic(Paths.image('space'));
        spaceBg.antialiasing = ClientPrefs.data.antialiasing;
        spaceBg.setGraphicSize(Std.int(FlxG.width));
        spaceBg.updateHitbox();
        spaceBg.screenCenter();
        add(spaceBg);

        portal1 = new FlxSprite(0, 0);
        portal1.frames = Paths.getSparrowAtlas('portal');
        portal1.animation.addByPrefix('idle', 'base', 1, false);
        portal1.animation.play('idle');
        portal1.antialiasing = ClientPrefs.data.antialiasing;
		portal1.setGraphicSize(Std.int(FlxG.height * 0.9)); // Ajusta o tamanho (1.2 é 20% maior que a altura da tela)
        portal1.updateHitbox();
        portal1.screenCenter();
        add(portal1);


        portal2 = new FlxSprite(0, 0);
        portal2.frames = Paths.getSparrowAtlas('portal');
        portal2.animation.addByPrefix('idle', 'middle', 1, false);
        portal2.animation.play('idle');
        portal2.antialiasing = ClientPrefs.data.antialiasing;
		portal2.setGraphicSize(Std.int(FlxG.height * 0.9)); // Ajusta o tamanho (1.2 é 20% maior que a altura da tela)
        portal2.updateHitbox();
        portal2.screenCenter();
        add(portal2);

        portal3 = new FlxSprite(0, 0);
        portal3.frames = Paths.getSparrowAtlas('portal');
        portal3.animation.addByPrefix('idle', 'front', 1, false);
        portal3.animation.play('idle');
        portal3.antialiasing = ClientPrefs.data.antialiasing;
		portal3.setGraphicSize(Std.int(FlxG.height * 0.9)); // Ajusta o tamanho (1.2 é 20% maior que a altura da tela)
        portal3.updateHitbox();
        portal3.screenCenter();
        add(portal3);

		logoBl = new FlxSprite(0, 0).loadGraphic(Paths.image('FNF_logo'));
        logoBl.antialiasing = ClientPrefs.data.antialiasing;
        
        logoBl.setGraphicSize(Std.int(logoBl.width * 0.4)); 
        logoBl.updateHitbox();
        logoBaseScale = logoBl.scale.x; 
        logoBl.screenCenter();
        add(logoBl);

		//add(gfDance);
		add(titleText); //"Press Enter to Begin" text
		add(credGroup);
		add(ngSpr);

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	var enterPosition:FlxPoint = FlxPoint.get(100, 576);

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{

        if (portal1 != null) portal1.angle += elapsed * 15;
        if (portal2 != null) portal2.angle += elapsed * 10;
        if (portal3 != null) portal3.angle += elapsed * 5;

		if (logoBl != null && !transitioning) {
            logoBl.screenCenter();
			logoBl.scale.x = FlxMath.lerp(logoBaseScale, logoBl.scale.x, Math.exp(-elapsed * 9.0));
            logoBl.scale.y = FlxMath.lerp(logoBaseScale, logoBl.scale.y, Math.exp(-elapsed * 9.0));
        }

        // the zoom is being tweened while transitioning to the main menu, don't fight it
        if (!transitioning) FlxG.camera.zoom = FlxMath.lerp(1, FlxG.camera.zoom, Math.exp(-elapsed * 6.0));

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (newTitle) {
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		// EASTER EGG

		if (initialized && !transitioning && skippedIntro)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if(pressedEnter)
            {
                titleText.color = FlxColor.WHITE;
                titleText.alpha = 1;
                
                if(titleText != null) titleText.animation.play('press');

                FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
                FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

                transitioning = true;

                if (logoBl != null) {
                    FlxTween.tween(logoBl, {angle: 720, alpha: 0}, 1.5, {ease: FlxEase.cubeIn});
                    FlxTween.tween(logoBl.scale, {x: 0, y: 0}, 1.5, {ease: FlxEase.cubeIn});
                }
                
                FlxTween.tween(FlxG.camera, {zoom: 4.5}, 1.5, {ease: FlxEase.cubeIn});
                
                var manualFade:FlxSprite = new FlxSprite(-FlxG.width, -FlxG.height).makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
                manualFade.scrollFactor.set();
                manualFade.alpha = 0; // Começa invisível
                add(manualFade);
                
                FlxTween.tween(manualFade, {alpha: 1}, 1.5, {ease: FlxEase.linear});
                // =========================================================

                new FlxTimer().start(1.5, function(tmr:FlxTimer)
                {
                    MusicBeatState.switchState(new MainMenuState());
                    closedState = true;
                });
            }
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;
	override function beatHit()
	{
		super.beatHit();

		if (!transitioning) FlxG.camera.zoom += 0.015;
		if (logoBl != null && !transitioning) 
        {
            logoBl.scale.set(logoBaseScale * 1.15, logoBaseScale * 1.15);
        }

		if(!closedState)
		{
			sickBeats++;
			switch (sickBeats)
			{
				case 1:
					//FlxG.sound.music.stop();
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
					FlxG.sound.music.fadeIn(4, 0, 0.7);
				case 2:
					createCoolText(['Psych Engine by'], 40);
				case 4:
					addMoreText('Shadow Mario', 40);
					addMoreText('Riveren', 40);
				case 5:
					deleteCoolText();
				case 6:
					createCoolText(['presented', 'by'], -40);
				case 8:
					ngSpr.visible = true;
				case 9:
					deleteCoolText();
					ngSpr.visible = false;
				case 10:
					createCoolText([curWacky[0]]);
				case 12:
					addMoreText(curWacky[1]);
				case 13:
					deleteCoolText();
				case 14:
					addMoreText('Friday');
				case 15:
					addMoreText('Night');
				case 16:
					addMoreText('Funkin'); // credTextShit.text += '\nFunkin';

				case 17:
					skipIntro();
			}
		}
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			//Default! Edit this one!!
				remove(ngSpr);
				remove(credGroup);
				FlxG.camera.flash(FlxColor.WHITE, 4);

			skippedIntro = true;
		}
	}
}
