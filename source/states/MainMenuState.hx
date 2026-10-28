package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import options.OptionsMenu;
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
	var isOptionsAnimating:Bool = false;

	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:MainMenuItemList;

	/**
	 * What V-Slice's main menu has, for the scripts of its mods that change it: its backgrounds (`bg` is its first member) and the
	 * screen it goes to (`startExitState()`). This menu is the engine's own: those backgrounds are there but aren't seen, and the
	 * options the mods add to the list (`menuItems.addItem()`) are kept out of it.
	 */
	public var bg:FlxSprite;
	public var magenta:FlxSprite;

	// (above the text V-Slice's mods write on, which they make taller)
	var vortexVer:FlxText;
	var psychVer:FlxText;

	var parallaxBg:FlxSprite;
	var cloudsBg:FlxBackdrop;
	var parallaxBg1:FlxSprite;
	var parallaxBg2:FlxSprite;
	var itemsBaseX:Array<Float> = [];
	var itemsBaseY:Array<Float> = [];

	var road:FlxSprite;
	var phillyCar:FlxSprite;
	var carMoving:Bool = false;
	var carDirection:Int = 1; // 1 vai para a direita, -1 vai para a esquerda
	var carBaseX:Float = 0;
	var carSpeed:Float = 0;

	var inFreeplayMenu:Bool = false;
	var freeplayBg:FlxSprite;
	var galleryUnlocked:Bool = true;

	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		'multiplayer',
		'gallery',
		'credits',
		'quit'
		//'options'
	];

	static var showOutdatedWarning:Bool = true;
	/**
	 * The texts on the bottom corners of the screen, with the names V-Slice gives them: its mods write on them.
	 */
	public var leftWatermarkText:FlxText;
	public var rightWatermarkText:FlxText;

	#if HSCRIPT_ALLOWED
	override function destroy()
	{
		backend.VSliceScripts.endMenu(this);
		super.destroy();
	}
	#end

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

		bg = new FlxSprite();
		bg.visible = false;
		add(bg);
		magenta = new FlxSprite();
		magenta.visible = false;

		parallaxBg = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/bg'));
		parallaxBg.antialiasing = ClientPrefs.data.antialiasing;
		parallaxBg.scale.set(0.85, 0.85);
		parallaxBg.updateHitbox();
		parallaxBg.screenCenter();
		add(parallaxBg);

		cloudsBg = new FlxBackdrop(Paths.image('mainmenu/parallax/clouds'));
		cloudsBg.antialiasing = ClientPrefs.data.antialiasing;
		cloudsBg.scale.set(0.75, 0.75);
		cloudsBg.velocity.set(-10, 5);
		add(cloudsBg);

		parallaxBg1 = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/bg1'));
		parallaxBg1.antialiasing = ClientPrefs.data.antialiasing;
		parallaxBg1.scale.set(0.85, 0.85);
		parallaxBg1.updateHitbox();
		parallaxBg1.screenCenter();
		add(parallaxBg1);

		road = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/road'));
		road.antialiasing = ClientPrefs.data.antialiasing;
		road.scale.set(0.85, 0.85);
		road.updateHitbox();
		road.screenCenter();
		//road.y += 100;
		add(road);

		phillyCar = new FlxSprite(0, 0);
		phillyCar.frames = Paths.getSparrowAtlas('mainmenu/parallax/phillyCars');
		phillyCar.animation.addByPrefix('car1', 'car1', 0, false);
		phillyCar.animation.addByPrefix('car2', 'car2', 0, false);
		phillyCar.animation.addByPrefix('car3', 'car3', 0, false);
		phillyCar.animation.addByPrefix('car4', 'car4', 0, false);
		phillyCar.antialiasing = ClientPrefs.data.antialiasing;
		phillyCar.scale.set(0.85, 0.85); 
		phillyCar.visible = false;
		add(phillyCar);

		new FlxTimer().start(FlxG.random.float(2, 4), resetCar);

		parallaxBg2 = new FlxSprite(0, 0).loadGraphic(Paths.image('mainmenu/parallax/bg2'));
		parallaxBg2.antialiasing = ClientPrefs.data.antialiasing;
		parallaxBg2.scale.set(0.85, 0.85);
		parallaxBg2.updateHitbox();
		parallaxBg2.screenCenter();
		add(parallaxBg2);

		menuItems = new MainMenuItemList();
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
			currentY += item.height + 15;
		}
		vortexVer = new FlxText(12, FlxG.height - 74, 0, "Vortex Engine v1.2", 14);
		vortexVer.scrollFactor.set();
		vortexVer.antialiasing = ClientPrefs.data.antialiasing;
		vortexVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(vortexVer);

		psychVer = new FlxText(12, FlxG.height - 54, 0, "Psych Engine v" + psychEngineVersion, 14);
		psychVer.scrollFactor.set();
		psychVer.antialiasing = ClientPrefs.data.antialiasing;
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);

		var fnfVer:FlxText = new FlxText(12, FlxG.height - 34, 0, "Friday Night Funkin" , 14);
		fnfVer.scrollFactor.set();
		fnfVer.antialiasing = ClientPrefs.data.antialiasing;
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		leftWatermarkText = fnfVer;

		// Empty until a V-Slice mod writes on it (its name and version, usually)
		rightWatermarkText = new FlxText(0, FlxG.height - 34, FlxG.width - 12, "", 14);
		rightWatermarkText.scrollFactor.set();
		rightWatermarkText.antialiasing = ClientPrefs.data.antialiasing;
		rightWatermarkText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(rightWatermarkText);

		#if HSCRIPT_ALLOWED
		// The modules of V-Slice mods that do things on the main menu
		backend.VSliceScripts.startMenu(this, true, true);
		backend.VSliceScripts.menuOpened(this);
		#end
		changeItem();

		freeplayBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		freeplayBg.alpha = 0;
		freeplayBg.scrollFactor.set(0, 0);
		freeplayBg.visible = false;
		add(freeplayBg);

		optionsGear = new FlxSprite(0, 10).loadGraphic(Paths.image('mainmenu/menu_options'));
		optionsGear.antialiasing = ClientPrefs.data.antialiasing;
		optionsGear.x = FlxG.width - (optionsGear.width / 2);
		add(optionsGear);

		// the buttons of the top left corner: the achievements and the mods (LEFT picks them with the keyboard)
		var cornerX:Float = 14;
		#if ACHIEVEMENTS_ALLOWED
		var trophy:FlxSprite = makeCornerButton('achievements', cornerX, 10, 0.42);
		cornerX += trophy.width + 10;
		#end
		#if MODS_ALLOWED
		var mods:FlxSprite = makeCornerButton('mods', cornerX, 0, 0.36);
		mods.y = 10 + (cornerButtons[0].height - mods.height) / 2;
		#end

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		// Back from the options as a screen of their own (after "Adjust Delay and Combo"): the menu is opened again over this one,
		// already there, and slides away. The static flag is reset right away, so it never happens twice
		if (returningFromOptions) {
			returningFromOptions = false;
			openOptions(OptionsMenu.SLIDE_OUT);
		}
	}

	/**
	 * Opens the options menu right on top of this one: it slides in from the right with the gear rolling along its edge,
	 * and slides back out the same way when it's left, with this menu right where it was.
	 */
	function openOptions(mode:Int):Void
	{
		isOptionsAnimating = true;
		selectedSomethin = true;
		optionsGear.visible = false;
		OptionsState.onPlayState = false;

		var menu:OptionsMenu = new OptionsMenu(false, true, mode);
		menu.onSlidOut = optionsClosed;
		openSubState(menu);
	}

	function optionsClosed():Void
	{
		optionsGear.x = FlxG.width - (optionsGear.width / 2);
		optionsGear.angle = 0;
		optionsGear.visible = true;
		isOptionsAnimating = false;
		selectedSomethin = false;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end
	}

	// ------------------------------------------------------------------------------------------
	// The buttons of the top left corner (achievements, mods)
	// ------------------------------------------------------------------------------------------

	var cornerButtons:Array<FlxSprite> = [];
	var cornerNames:Array<String> = [];
	var cornerScales:Array<Float> = [];
	var cornerSelected:Int = -1;
	var cornerActive:Bool = false;
	var controlsBlocked:Bool = false;

	function makeCornerButton(name:String, x:Float, y:Float, size:Float):FlxSprite
	{
		var button:FlxSprite = new FlxSprite(x, y);
		button.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		button.animation.addByPrefix('idle', '$name idle', 24, true);
		button.animation.addByPrefix('selected', '$name selected', 24, true);
		button.animation.play('idle');
		button.antialiasing = ClientPrefs.data.antialiasing;
		button.scrollFactor.set();
		button.scale.set(size, size);
		button.updateHitbox();
		add(button);

		cornerButtons.push(button);
		cornerNames.push(name);
		cornerScales.push(size);
		return button;
	}

	function selectCorner(num:Int, ?playSound:Bool = true):Void
	{
		if(num == cornerSelected) return;
		cornerSelected = num;
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));

		for (i => button in cornerButtons)
		{
			var picked:Bool = (i == cornerSelected);
			button.animation.play(picked ? 'selected' : 'idle', true);
			// (bigger while picked, from its middle)
			var middleX:Float = button.x + button.width / 2;
			var middleY:Float = button.y + button.height / 2;
			var size:Float = cornerScales[i] * (picked ? 1.12 : 1);
			button.scale.set(size, size);
			button.updateHitbox();
			button.setPosition(middleX - button.width / 2, middleY - button.height / 2);
		}

		// the list on the right looks unpicked while one of these is
		for (num => item in menuItems.members)
			if(item != null) item.alpha = (cornerSelected > -1) ? 0.6 : 1;
		if(cornerSelected < 0) changeItem();
	}

	function openCorner(num:Int):Void
	{
		var name:String = cornerNames[num];
		var button:FlxSprite = cornerButtons[num];
		FlxG.sound.play(Paths.sound('confirmMenu'));
		selectedSomethin = true;
		FlxG.mouse.visible = false;

		FlxFlicker.flicker(button, 1, 0.06, false, false, function(_)
		{
			switch(name)
			{
				#if ACHIEVEMENTS_ALLOWED
				case 'achievements': MusicBeatState.switchState(new AchievementsMenuState());
				#end
				#if MODS_ALLOWED
				case 'mods': MusicBeatState.switchState(new ModsMenuState());
				#end
			}
		});
		for (item in menuItems)
			if(item != null) FlxTween.tween(item, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
	}

	// The mouse over one of them picks it, a click opens it. True if the mouse was on one (the list doesn't get the click)
	function updateCornerMouse():Bool
	{
		if(!FlxG.mouse.visible && !FlxG.mouse.justMoved && !FlxG.mouse.justPressed) return false;

		for (i => button in cornerButtons)
		{
			if(!FlxG.mouse.overlaps(button)) continue;
			if(FlxG.mouse.justMoved || FlxG.mouse.justPressed) FlxG.mouse.visible = true;
			selectCorner(i);
			if(FlxG.mouse.justPressed) openCorner(i);
			return true;
		}
		return false;
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
			if (!isOptionsAnimating && subState == null && ((FlxG.mouse.justPressed && FlxG.mouse.overlaps(optionsGear)) || controls.UI_RIGHT_P)) {
				FlxG.sound.play(Paths.sound('chains'));
				openOptions(OptionsMenu.SLIDE_IN);
			}

		}

		// the buttons of the top left corner (the mouse on them, or LEFT to go to them)
		controlsBlocked = false;
		if (!selectedSomethin && !isOptionsAnimating && subState == null && cornerButtons.length > 0)
		{
			var onCorner:Bool = updateCornerMouse();
			if (!selectedSomethin)
			{
				if (controls.UI_LEFT_P)
					selectCorner((cornerSelected + 1) % cornerButtons.length);
				else if (cornerSelected > -1 && (controls.UI_UP_P || controls.UI_DOWN_P))
					selectCorner(-1);
				else if (cornerSelected > -1 && controls.ACCEPT)
					openCorner(cornerSelected);
				else if (onCorner)
				{
					// (the click was the corner's)
				}
				else if (cornerSelected > -1 && FlxG.mouse.justMoved && FlxG.mouse.visible)
					selectCorner(-1, false);
			}
			cornerActive = (onCorner || cornerSelected > -1);
		}
		else cornerActive = false;
		if (cornerActive && !selectedSomethin && controls.BACK)
		{
			selectCorner(-1);
			cornerActive = false;
			controlsBlocked = true;
		}

		// checked again because opening the options above already "selected something" this frame
		// (and not while one of the corner's buttons is picked: the keys and the click are theirs)
		if (!selectedSomethin && !cornerActive && !controlsBlocked)
		{
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
								case 'multiplayer':
                                    MusicBeatState.switchState(new states.MultiplayerMenuState());
								case 'quit':
									#if sys Sys.exit(0); #end
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

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.menuUpdate(elapsed);
		#end
		super.update(elapsed);

		var mouseOffX:Float = (FlxG.mouse.screenX - (FlxG.width / 2));
		var mouseOffY:Float = (FlxG.mouse.screenY - (FlxG.height / 2));

		var targetRoadX:Float = ((FlxG.width - road.width) / 2) - (mouseOffX * 0.05);
		var targetRoadY:Float = ((FlxG.height - road.height) / 2) - (mouseOffY * 0.05);

		var target1X:Float = ((FlxG.width - parallaxBg1.width) / 2) - (mouseOffX * 0.03);
		var target1Y:Float = ((FlxG.height - parallaxBg1.height) / 2) - (mouseOffY * 0.03);

		var target2X:Float = ((FlxG.width - parallaxBg2.width) / 2) - (mouseOffX * 0.08);
		var target2Y:Float = ((FlxG.height - parallaxBg2.height) / 2) - (mouseOffY * 0.08);

		var speed:Float = flixel.math.FlxMath.bound(elapsed * 6, 0, 1);
		
		parallaxBg1.x = flixel.math.FlxMath.lerp(parallaxBg1.x, target1X, speed);
		parallaxBg1.y = flixel.math.FlxMath.lerp(parallaxBg1.y, target1Y, speed);

		road.x = flixel.math.FlxMath.lerp(road.x, targetRoadX, speed);
		road.y = flixel.math.FlxMath.lerp(road.y, targetRoadY, speed);

		parallaxBg2.x = flixel.math.FlxMath.lerp(parallaxBg2.x, target2X, speed);
		parallaxBg2.y = flixel.math.FlxMath.lerp(parallaxBg2.y, target2Y, speed);

		if (carMoving) {
			carBaseX += (carSpeed * carDirection) * elapsed;

			var distDoCentro:Float = carBaseX - (FlxG.width / 2);
			
			var curvaY:Float = Math.pow(distDoCentro, 2) / 9000; 

			var carroYCentral:Float = 400; 
			
			var carBaseY:Float = carroYCentral + curvaY;

			var roadOffX = road.x - ((FlxG.width - road.width) / 2);
			var roadOffY = road.y - ((FlxG.height - road.height) / 2);

			phillyCar.x = carBaseX + roadOffX;
			phillyCar.y = carBaseY + roadOffY;

			if ((carDirection == 1 && carBaseX > FlxG.width + 200) || (carDirection == -1 && carBaseX < -phillyCar.width - 200)) {
				carMoving = false;
				phillyCar.visible = false;
				
				new FlxTimer().start(FlxG.random.float(2, 5), resetCar);
			}
		}
		
		var bg2CenterStartX:Float = (FlxG.width - parallaxBg2.width) / 2;
		var bg2CenterStartY:Float = (FlxG.height - parallaxBg2.height) / 2;
		var bg2OffX:Float = parallaxBg2.x - bg2CenterStartX;
		var bg2OffY:Float = parallaxBg2.y - bg2CenterStartY;

		placeVersionTexts();

		itemsScroll = FlxMath.lerp(itemsScroll, itemsScrollTarget(), speed);
		for (i in 0...menuItems.members.length) {
			var item = menuItems.members[i];
			var optionName = optionShit[i];

			if (optionName != 'options') {
				item.x = itemsBaseX[i] + bg2OffX;
				item.y = itemsBaseY[i] + bg2OffY - itemsScroll;
			} else {
				item.x = itemsBaseX[i];
				item.y = itemsBaseY[i];
			}
		}
	}

	// The items don't all fit on the screen: the list goes up just enough for the selected one to be seen whole
	var itemsScroll:Float = 0;
	function itemsScrollTarget():Float
	{
		var count:Int = menuItems.members.length;
		if(count < 1 || itemsBaseY.length < count) return 0;

		var margin:Float = 40;
		var last:FlxSprite = menuItems.members[count - 1];
		var maxScroll:Float = Math.max(0, itemsBaseY[count - 1] + last.height - (FlxG.height - margin));
		if(maxScroll <= 0) return 0;

		var selected:FlxSprite = menuItems.members[curSelected];
		var top:Float = itemsBaseY[curSelected] - margin;
		var bottom:Float = itemsBaseY[curSelected] + selected.height - (FlxG.height - margin);

		var target:Float = itemsScroll;
		if(top < target) target = top;
		else if(bottom > target) target = bottom;
		return FlxMath.bound(target, 0, maxScroll);
	}

	// V-Slice's mods add lines to `leftWatermarkText` (and move it up for them): it stays on the screen, with the engine's own
	// versions above it
	function placeVersionTexts():Void
	{
		if(leftWatermarkText == null || vortexVer == null || psychVer == null) return;

		var bottom:Float = FlxG.height - 14;
		if(leftWatermarkText.y + leftWatermarkText.height > bottom) leftWatermarkText.y = bottom - leftWatermarkText.height;
		psychVer.y = leftWatermarkText.y - 20;
		vortexVer.y = psychVer.y - 20;
	}

	/**
	 * Leaves the menu for another screen (V-Slice's, which its mods' scripts call to open one of their own).
	 */
	public function startExitState(nextState:flixel.FlxState):Void
	{
		if(nextState == null) return;
		selectedSomethin = true;
		MusicBeatState.switchState(nextState);
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

	function resetCar(?t:FlxTimer):Void 
	{
		carMoving = true;
		phillyCar.visible = true;

		var randomCar = FlxG.random.int(1, 4);
		phillyCar.animation.play('car' + randomCar);
		phillyCar.updateHitbox();

		carDirection = FlxG.random.bool(50) ? 1 : -1;
		phillyCar.flipX = (carDirection == -1);
		
		carSpeed = FlxG.random.float(600, 1200); 

		if (carDirection == 1) {
			carBaseX = -phillyCar.width - 200;
		} else {
			carBaseX = FlxG.width + 200;
		}
	}
}

/**
 * The list of the main menu's options. V-Slice's mods add their own to V-Slice's (`menuItems.addItem('gallery', item)`): this menu is
 * the engine's, with its own options, theirs are kept here for their scripts instead of being shown.
 */
class MainMenuItemList extends FlxTypedGroup<FlxSprite>
{
	public var scriptItems(default, null):Map<String, FlxSprite> = [];

	public function addItem(name:String, item:FlxSprite):FlxSprite
	{
		if(name != null && item != null) scriptItems.set(name, item);
		return item;
	}
}
