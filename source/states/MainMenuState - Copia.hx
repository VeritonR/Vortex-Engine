package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import backend.Highscore;
import flixel.util.FlxTimer;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.transition.FlxTransitionableState;

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC
	public static var curSelected:Int = 0;

	public static var returningFromOptions:Bool = false;
	var optionsGear:FlxSprite;
	var optionsPanel:FlxSpriteGroup;
	var isOptionsOpen:Bool = false;
	var isOptionsAnimating:Bool = false;

	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedGroup<FlxSprite>;

	var parallaxBg:FlxSprite;
	var parallaxBg1:FlxSprite;
	var parallaxBg2:FlxSprite;
	var itemsBaseX:Array<Float> = [];
	var itemsBaseY:Array<Float> = [];

	var inFreeplayMenu:Bool = false;
	var freeplayBg:FlxSprite;
	var galleryUnlocked:Bool = true;

	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		'gallery',
		'credits',
		'quit'
		//'options'
	];

	static var showOutdatedWarning:Bool = true;
	override function create()
	{
		super.create();
		
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		parallaxBg = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/bg'));
		parallaxBg.antialiasing = ClientPrefs.data.antialiasing;
		parallaxBg.scale.set(0.85, 0.85);
		parallaxBg.updateHitbox();
		parallaxBg.screenCenter();
		add(parallaxBg);

		parallaxBg1 = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/bg1'));
		parallaxBg1.antialiasing = ClientPrefs.data.antialiasing;
		parallaxBg1.scale.set(0.85, 0.85);
		parallaxBg1.updateHitbox();
		parallaxBg1.screenCenter();
		add(parallaxBg1);

		parallaxBg2 = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/bg2'));
		parallaxBg2.antialiasing = ClientPrefs.data.antialiasing;
		parallaxBg2.scale.set(0.85, 0.85);
		parallaxBg2.updateHitbox();
		parallaxBg2.screenCenter();
		add(parallaxBg2);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		// Uncomment this if you want the gallery to unlock only after the player finishes Week 1.
		//if (Highscore.getWeekScore('week1', 0) > 0 || Highscore.getWeekScore('week1', 1) > 0 || Highscore.getWeekScore('week1', 2) > 0) {
			//galleryUnlocked = true;
		//}

		var currentY:Float = 0;
		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, currentY);
			item.ID = num;

			item.scale.set(0.7, 0.7);
			item.updateHitbox();

			var targetX:Float = FlxG.width - item.width - 100;

			itemsBaseX.push(item.width + 1200);
			itemsBaseY.push(currentY);

			FlxTween.num(item.width + 1200, targetX, 0.8, {ease: FlxEase.backOut, startDelay: num * 0.15}, function(val:Float) {
				itemsBaseX[item.ID] = val; 
			});

			if (option == 'gallery' && !galleryUnlocked) {
				item.color = 0xFF444444; 
			}
			currentY += item.height + 25;
		}
		var vortexVer:FlxText = new FlxText(12, FlxG.height - 74, 0, "Vortex Engine v1.0", 14);
		vortexVer.scrollFactor.set();
		vortexVer.antialiasing = ClientPrefs.data.antialiasing;
		vortexVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(vortexVer);

		var psychVer:FlxText = new FlxText(12, FlxG.height - 54, 0, "Psych Engine v" + psychEngineVersion, 14);
		psychVer.scrollFactor.set();
		psychVer.antialiasing = ClientPrefs.data.antialiasing;
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);

		var fnfVer:FlxText = new FlxText(12, FlxG.height - 34, 0, "Friday Night Funkin" , 14);
		fnfVer.scrollFactor.set();
		fnfVer.antialiasing = ClientPrefs.data.antialiasing;
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		freeplayBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		freeplayBg.alpha = 0;
		freeplayBg.scrollFactor.set(0, 0);
		freeplayBg.visible = false;
		add(freeplayBg);

		optionsPanel = new FlxSpriteGroup(0, 0);
		add(optionsPanel);

		var panelBg:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('menuDesat'));
		panelBg.color = 0xFFea71fd;
		panelBg.updateHitbox();
		panelBg.screenCenter();
		optionsPanel.add(panelBg);

		optionsGear = new FlxSprite(0, 10).loadGraphic(Paths.image('mainmenu/menu_options'));
		optionsGear.antialiasing = ClientPrefs.data.antialiasing;
		add(optionsGear);

		if (returningFromOptions) {
			optionsPanel.x = 0;
			optionsGear.x = -(optionsGear.width / 2);
			optionsGear.angle = -360;

			FlxTween.tween(optionsGear, {x: FlxG.width - (optionsGear.width / 2), angle: 0}, 0.8, {ease: FlxEase.cubeInOut});
			FlxTween.tween(optionsPanel, {x: FlxG.width + 10}, 0.8, {ease: FlxEase.cubeInOut, onComplete: function(twn:FlxTween) {
				returningFromOptions = false;
			}});
		} else {
			optionsPanel.x = FlxG.width + 10;
			optionsGear.x = FlxG.width - (optionsGear.width / 2);
		}
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		
		menuItem.loadGraphic(Paths.image('mainmenu/menu_$name'));
		menuItem.updateHitbox();
		
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(optionsGear) && !isOptionsAnimating && !returningFromOptions || (controls.UI_RIGHT_P) && !isOptionsAnimating && !returningFromOptions) {
				
				isOptionsAnimating = true;
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('scrollMenu')); 
				
				FlxTween.tween(optionsGear, {x: -(optionsGear.width / 2), angle: -360}, 0.8, {ease: FlxEase.cubeOut});
				
				FlxTween.tween(optionsPanel, {x: 0}, 0.8, {ease: FlxEase.cubeOut, onComplete: function(twn:FlxTween) {
					
					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					returningFromOptions = true;
					
					OptionsState.onPlayState = false;
					MusicBeatState.switchState(new OptionsState());
				}});
			}

			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite = menuItems.members[curSelected];

					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curSelected = distItem;
						changeItem();
					}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse))
            {
                var option:String = optionShit[curSelected];
                var item:FlxSprite = menuItems.members[curSelected];

                if (option == 'gallery' && !galleryUnlocked) {
                    FlxG.sound.play(Paths.sound('lockedElementInteract'));
                    FlxG.camera.shake(0.005, 0.1);
                }
                else 
                {
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                    selectedSomethin = true;
                    FlxG.mouse.visible = false;

                        FlxFlicker.flicker(item, 1.5, 0.06, false, false, function(flick:FlxFlicker)
                        {
                            switch (option)
                            {
                                case 'story_mode':
                                    MusicBeatState.switchState(new StoryMenuState());
                                case 'credits':
                                    MusicBeatState.switchState(new CreditsState());
								case 'freeplay':
                                    if (ClientPrefs.data.freeplayStyle == 'V-Slice')
                                        MusicBeatState.switchState(new states.FreeplayStateVslice());
                                    else
                                        MusicBeatState.switchState(new states.FreeplayState());
                                case 'options':
                                    MusicBeatState.switchState(new OptionsState());
                                    OptionsState.onPlayState = false;
                                    if (PlayState.SONG != null)
                                    {
                                        PlayState.SONG.arrowSkin = null;
                                        PlayState.SONG.splashSkin = null;
                                        PlayState.stageUI = 'normal';
                                    }
                                case 'gallery':
                                    MusicBeatState.switchState(new GalleryState());
								case 'quit':
                                Sys.exit(0);
                            }
                        });
                        
                        for (memb in menuItems)
                        {
                            if(memb == item) continue;
                            FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
                        }
                }
            }

			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);

		var mouseOffX:Float = (FlxG.mouse.screenX - (FlxG.width / 2));
		var mouseOffY:Float = (FlxG.mouse.screenY - (FlxG.height / 2));

		var target1X:Float = ((FlxG.width - parallaxBg1.width) / 2) - (mouseOffX * 0.03);
		var target1Y:Float = ((FlxG.height - parallaxBg1.height) / 2) - (mouseOffY * 0.03);

		var target2X:Float = ((FlxG.width - parallaxBg2.width) / 2) - (mouseOffX * 0.08);
		var target2Y:Float = ((FlxG.height - parallaxBg2.height) / 2) - (mouseOffY * 0.08);

		var speed:Float = flixel.math.FlxMath.bound(elapsed * 6, 0, 1);
		
		parallaxBg1.x = flixel.math.FlxMath.lerp(parallaxBg1.x, target1X, speed);
		parallaxBg1.y = flixel.math.FlxMath.lerp(parallaxBg1.y, target1Y, speed);

		parallaxBg2.x = flixel.math.FlxMath.lerp(parallaxBg2.x, target2X, speed);
		parallaxBg2.y = flixel.math.FlxMath.lerp(parallaxBg2.y, target2Y, speed);
		
		var bg2CenterStartX:Float = (FlxG.width - parallaxBg2.width) / 2;
		var bg2CenterStartY:Float = (FlxG.height - parallaxBg2.height) / 2;
		var bg2OffX:Float = parallaxBg2.x - bg2CenterStartX;
		var bg2OffY:Float = parallaxBg2.y - bg2CenterStartY;

		for (i in 0...menuItems.members.length) {
			var item = menuItems.members[i];
			var optionName = optionShit[i];

			if (optionName != 'options') {
				item.x = itemsBaseX[i] + bg2OffX;
				item.y = itemsBaseY[i] + bg2OffY;
			} else {
				item.x = itemsBaseX[i];
				item.y = itemsBaseY[i];
			}
		}
	}

	function changeItem(huh:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.forEach(function(spr:FlxSprite)
		{
			FlxTween.cancelTweensOf(spr.scale);

			if (spr.ID == curSelected)
			{
				FlxTween.tween(spr.scale, {x: 0.8, y: 0.8}, 0.15, {ease: FlxEase.quadOut});
				
				spr.alpha = 1;
				if (optionShit[spr.ID] == 'gallery' && !galleryUnlocked) 
					spr.color = 0xFF444444;
				else 
					spr.color = 0xFFFFFFFF;
			}
			else
			{
				FlxTween.tween(spr.scale, {x: 0.6, y: 0.6}, 0.15, {ease: FlxEase.quadOut});
				spr.alpha = 0.85;
				if (optionShit[spr.ID] == 'gallery' && !galleryUnlocked) 
					spr.color = 0xFF444444; 
				else 
					spr.color = 0xFF666666;
			}
		});
	}
}
