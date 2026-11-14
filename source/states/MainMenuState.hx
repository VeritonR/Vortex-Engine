package states;

import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import options.OptionsMenu;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
	CLOSE;
}

/**
 * Psych Engine's main menu: the list in the middle, the achievements on the bottom left, the options on the bottom right, and the X
 * on the top right that closes the game.
 */
class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4';
	public static var vortexEngineVersion:String = '1.5'; // This is also used for Discord RPC
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;

	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:MainMenuItemList;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;
	var closeItem:FlxSprite;

	//Centered/Text options
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		'online',
		'gallery',
		#if MODS_ALLOWED 'mods', #end
		'credits'
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var rightOption:String = 'options';

	var galleryUnlocked:Bool = true;

	/**
	 * What V-Slice's main menu has, for the scripts of its mods that change it: its backgrounds (`bg` is its first member) and the
	 * screen it goes to (`startExitState()`). This menu is the engine's own: those backgrounds are there but aren't seen, the
	 * options the mods add to the list (`menuItems.addItem()`) are kept out of it, and its options stay where they are.
	 */
	public var bg:FlxSprite;
	public var magenta:FlxSprite;

	var menuBG:FlxSprite;
	var menuFlash:FlxSprite;

	/**
	 * The texts on the bottom corners of the screen, with the names V-Slice gives them: its mods write on them.
	 */
	public var leftWatermarkText:FlxText;
	public var rightWatermarkText:FlxText;

	// (above the text V-Slice's mods write on, which they make taller)
	var vortexVer:FlxText;
	var psychVer:FlxText;

	// The list doesn't fit on the screen: it goes up and down with the selected option, the background a little with it
	var menuScroll:Float = 0;
	var itemsBaseY:Array<Float> = [];
	var itemsScroll:Float = 0;
	var bgScroll:Float = 0.25;
	var bgBaseY:Float = 0;

	// The size the menu is laid out on: its camera's, the whole window with the Widescreen option (backend.GameScaleMode.widenMenu())
	var screenWidth(get, never):Float;
	function get_screenWidth():Float return (FlxG.camera != null) ? FlxG.camera.width : FlxG.width;
	var screenHeight(get, never):Float;
	function get_screenHeight():Float return (FlxG.camera != null) ? FlxG.camera.height : FlxG.height;

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
		DiscordClient.changePresence(Language.getPhrase('discord_main_menu', 'In the Main Menu'), null, 'menu');
		#end

		persistentUpdate = persistentDraw = true;

		// (the menu's music, if something stopped it: a mod's button that fades it out on its way to its own menu, left halfway)
		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

		// (the Widescreen option: the menu covers the whole window, its things placed on the camera's size, see screenWidth)
		var wide:Bool = backend.GameScaleMode.widenMenu(FlxG.camera);

		var count:Int = optionShit.length;
		bgScroll = Math.max(0.25 - (0.05 * (count - 4)), 0.1);
		itemsScroll = (count < 5) ? 0 : (count - 4) * 0.135;

		// (V-Slice's two backgrounds, for its scripts: the engine's are menuBG and menuFlash. With a picture of their own, since
		// scripts look at it: Spooky Mix reads `magenta.graphic.key` on every frame, which failing every frame left phones at 3 FPS)
		bg = new FlxSprite().makeGraphic(1, 1, 0x00000000);
		bg.visible = false;
		add(bg);
		magenta = new FlxSprite().makeGraphic(1, 1, 0x00000000);
		magenta.visible = false;

		menuBG = makeBackground('menuBG', wide);
		add(menuBG);

		menuFlash = makeBackground('menuDesat', wide);
		menuFlash.visible = false;
		menuFlash.color = 0xFFfd719b;
		add(menuFlash);
		bgBaseY = menuBG.y;

		menuItems = new MainMenuItemList();
		add(menuItems);

		// Uncomment this if you want the gallery to unlock only after the player finishes Week 1.
		//galleryUnlocked = (Highscore.getWeekScore('week1', 0) > 0 || Highscore.getWeekScore('week1', 1) > 0 || Highscore.getWeekScore('week1', 2) > 0);

		var top:Float = (screenHeight - FlxG.height) / 2;
		var offset:Float = 108 - (Math.max(count, 4) - 4) * 80;
		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, top + (num * 140) + offset);
			item.ID = num;
			item.x = (screenWidth - item.width) / 2;
			itemsBaseY.push(item.y);
			menuItems.add(item);
		}

		var cornerY:Float = screenHeight - 300;
		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 60, cornerY);
			add(leftItem);
		}
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, 0, cornerY);
			rightItem.x = screenWidth - 60 - rightItem.width;
			add(rightItem);
		}
		closeItem = createMenuItem('close', 0, 20);
		closeItem.x = screenWidth - 20 - closeItem.width;
		add(closeItem);

		vortexVer = makeVersionText("Vortex Engine v" + vortexEngineVersion, screenHeight - 74);
		psychVer = makeVersionText("Psych Engine v" + psychEngineVersion, screenHeight - 54);
		leftWatermarkText = makeVersionText("Friday Night Funkin", screenHeight - 34);

		// Empty until a V-Slice mod writes on it (its name and version, usually)
		rightWatermarkText = new FlxText(0, screenHeight - 34, screenWidth - 12, "", 14);
		rightWatermarkText.scrollFactor.set();
		rightWatermarkText.antialiasing = ClientPrefs.data.antialiasing;
		rightWatermarkText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(rightWatermarkText);

		#if HSCRIPT_ALLOWED
		// The modules of V-Slice mods that do things on the main menu
		backend.VSliceScripts.startMenu(this, true, true);
		backend.VSliceScripts.menuOpened(this);
		#end

		if (curColumn == LEFT && leftItem == null) curColumn = CENTER;
		changeItem();
		menuScroll = scrollTarget();
		placeScrolled();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end
	}

	function makeBackground(image:String, wide:Bool):FlxSprite
	{
		var sprite:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		sprite.scrollFactor.set();
		if (wide)
			backend.GameScaleMode.cover(sprite, FlxG.camera, 1.175, 60);
		else
		{
			sprite.setGraphicSize(Std.int(sprite.width * 1.175));
			sprite.updateHitbox();
		}
		sprite.x = (screenWidth - sprite.width) / 2;
		sprite.y = (screenHeight - sprite.height) / 2;
		return sprite;
	}

	function makeVersionText(text:String, y:Float):FlxText
	{
		var version:FlxText = new FlxText(12, y, 0, text, 14);
		version.scrollFactor.set();
		version.antialiasing = ClientPrefs.data.antialiasing;
		version.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(version);
		return version;
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();

		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		if (name == 'gallery' && !galleryUnlocked) menuItem.color = 0xFF444444;
		return menuItem;
	}

	/**
	 * Opens the options menu right on top of this one, with this menu right where it was when it's left.
	 */
	function openOptions():Void
	{
		selectedSomethin = true;
		OptionsState.onPlayState = false;

		var menu:OptionsMenu = new OptionsMenu(false, true);
		menu.onClosed = optionsClosed;
		openSubState(menu);
	}

	function optionsClosed():Void
	{
		selectedSomethin = false;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence(Language.getPhrase('discord_main_menu', 'In the Main Menu'), null, 'menu');
		#end
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin && subState == null)
		{
			if (controls.UI_UP_P)
			{
				if (curColumn == RIGHT) selectColumn(CLOSE);
				else changeItem(-1);
			}

			if (controls.UI_DOWN_P)
			{
				if (curColumn == CLOSE && rightItem != null) selectColumn(RIGHT);
				else changeItem(1);
			}

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite = columnItem(curColumn);

				var corner:Null<MainMenuColumn> = null;
				if (closeItem != null && FlxG.mouse.overlaps(closeItem)) corner = CLOSE;
				else if (leftItem != null && FlxG.mouse.overlaps(leftItem)) corner = LEFT;
				else if (rightItem != null && FlxG.mouse.overlaps(rightItem)) corner = RIGHT;

				if (corner != null)
				{
					allowMouse = true;
					if (selectedItem != columnItem(corner)) selectColumn(corner);
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if (FlxG.mouse.overlaps(memb))
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

					if (distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if (timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch (curColumn)
			{
				case CENTER:
					if (controls.UI_LEFT_P && leftItem != null) selectColumn(LEFT);
					else if (controls.UI_RIGHT_P && rightItem != null) selectColumn(RIGHT);

				case LEFT:
					if (controls.UI_RIGHT_P) selectColumn(CENTER);

				case RIGHT:
					if (controls.UI_LEFT_P) selectColumn(CENTER);

				case CLOSE:
					if (controls.UI_LEFT_P) selectColumn(CENTER);
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse))
				selectOption();

			#if desktop
			if (!selectedSomethin && controls.justPressed('debug_1'))
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

		// (as the camera following the selected option did on Psych, at its speed)
		menuScroll = FlxMath.lerp(scrollTarget(), menuScroll, Math.exp(-elapsed * 9.6));
		placeScrolled();
		placeVersionTexts();
	}

	function selectOption():Void
	{
		var option:String;
		var item:FlxSprite;
		switch (curColumn)
		{
			case CENTER:
				option = optionShit[curSelected];
				item = menuItems.members[curSelected];
			case LEFT:
				option = leftOption;
				item = leftItem;
			case RIGHT:
				option = rightOption;
				item = rightItem;
			case CLOSE:
				option = 'close';
				item = closeItem;
		}

		if (option == 'gallery' && !galleryUnlocked)
		{
			FlxG.sound.play(Paths.sound('lockedElementInteract'));
			FlxG.camera.shake(0.005, 0.1);
			return;
		}

		FlxG.mouse.visible = false;
		if (option == 'options')
		{
			// (the options open right over the menu)
			FlxG.sound.play(Paths.sound('confirmMenu'));
			openOptions();
			return;
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));
		selectedSomethin = true;

		if (ClientPrefs.data.flashing && option != 'close')
			FlxFlicker.flicker(menuFlash, 1.1, 0.15, false);

		FlxFlicker.flicker(item, (option == 'close') ? 0.5 : 1, 0.06, false, false, function(flick:FlxFlicker)
		{
			switch (option)
			{
				case 'story_mode':
					MusicBeatState.switchState(new StoryMenuState());
				case 'freeplay':
					if (ClientPrefs.data.freeplayStyle == 'V-Slice')
						MusicBeatState.switchState(new states.FreeplayStateVslice());
					else
						MusicBeatState.switchState(new states.FreeplayState());
				case 'online':
					MusicBeatState.switchState(new states.MultiplayerMenuState());
				case 'gallery':
					MusicBeatState.switchState(new GalleryState());

				#if MODS_ALLOWED
				case 'mods':
					MusicBeatState.switchState(new ModsMenuState());
				#end

				#if ACHIEVEMENTS_ALLOWED
				case 'achievements':
					MusicBeatState.switchState(new AchievementsMenuState());
				#end

				case 'credits':
					MusicBeatState.switchState(new CreditsState());
				case 'close':
					backend.AppExit.exit();
				default:
					trace('Menu Item ${option} doesn\'t do anything');
					selectedSomethin = false;
					item.visible = true;
			}
		});

		for (memb in allItems())
		{
			if (memb == item) continue;
			FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
		}
	}

	function allItems():Array<FlxSprite>
	{
		var items:Array<FlxSprite> = [for (memb in menuItems.members) if (memb != null) memb];
		for (corner in [leftItem, rightItem, closeItem])
			if (corner != null) items.push(corner);
		return items;
	}

	function columnItem(column:MainMenuColumn):FlxSprite
	{
		return switch (column)
		{
			case CENTER: menuItems.members[curSelected];
			case LEFT: leftItem;
			case RIGHT: rightItem;
			case CLOSE: closeItem;
		}
	}

	function selectColumn(column:MainMenuColumn):Void
	{
		curColumn = column;
		changeItem();
	}

	// Where the list should be for the selected option to be in sight (the camera's spot on Psych)
	function scrollTarget():Float
	{
		if (itemsScroll <= 0) return 0;
		var item:FlxSprite = menuItems.members[curSelected];
		if (item == null) return 0;
		var lift:Float = (optionShit.length > 4) ? optionShit.length * 8 : 0;
		return (itemsBaseY[curSelected] + item.height / 2) - lift - screenHeight / 2;
	}

	function placeScrolled():Void
	{
		for (i in 0...optionShit.length)
		{
			var item:FlxSprite = menuItems.members[i];
			if (item == null) continue;
			item.x = (screenWidth - item.width) / 2;
			item.y = itemsBaseY[i] - menuScroll * itemsScroll;
		}
		for (layer in [menuBG, menuFlash])
			if (layer != null) layer.y = bgBaseY - menuScroll * bgScroll;
	}

	// V-Slice's mods add lines to `leftWatermarkText` (and move it up for them): it stays on the screen, with the engine's own
	// versions above it
	function placeVersionTexts():Void
	{
		if (leftWatermarkText == null || vortexVer == null || psychVer == null) return;

		var bottom:Float = screenHeight - 14;
		if (leftWatermarkText.y + leftWatermarkText.height > bottom) leftWatermarkText.y = bottom - leftWatermarkText.height;
		psychVer.y = leftWatermarkText.y - 20;
		vortexVer.y = psychVer.y - 20;
	}

	/**
	 * Leaves the menu for another screen (V-Slice's, which its mods' scripts call to open one of their own).
	 */
	public function startExitState(nextState:flixel.FlxState):Void
	{
		if (nextState == null) return;
		selectedSomethin = true;
		MusicBeatState.switchState(nextState);
	}

	function changeItem(change:Int = 0)
	{
		if (change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in allItems())
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite = columnItem(curColumn);
		if (selectedItem == null)
		{
			curColumn = CENTER;
			selectedItem = menuItems.members[curSelected];
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
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
		if (name != null && item != null) scriptItems.set(name, item);
		return item;
	}
}
