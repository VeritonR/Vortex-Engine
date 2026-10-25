package options;

import backend.StageData;
import flixel.FlxCamera;
import flixel.FlxBasic;
import flixel.addons.display.FlxBackdrop;

/**
 * The options menu itself: its list, background and gear. It's a substate so it can be opened right on top of the main menu,
 * which it slides in over (and back out from) with the gear rolling along its edge, the main menu staying where it is underneath.
 * `OptionsState` opens it too, when the options are opened from a song or come back from "Adjust Delay and Combo".
 */
class OptionsMenu extends MusicBeatSubstate
{
	public static final OPTIONS:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay',
		'V-Slice',
		'Vortex Engine'
		#if TRANSLATIONS_ALLOWED , 'Language' #end
	];

	public static inline final SLIDE_TIME:Float = 0.8;
	// The list can be longer than the screen: the camera goes after the selected option, as far as the ends of the list
	static inline final LIST_MARGIN:Float = 50;

	/**
	 * How the menu shows up: right away, sliding in, or already there and sliding out at once (back from `OptionsState` to the main menu).
	 */
	public static inline final APPEAR:Int = 0;
	public static inline final SLIDE_IN:Int = 1;
	public static inline final SLIDE_OUT:Int = -1;

	/**
	 * Called once it slid out, to the main menu (which it was opened over).
	 */
	public var onSlidOut:Void->Void = null;

	var onPlayState:Bool;
	var inMainMenu:Bool;
	var startMode:Int;

	var grpOptions:FlxTypedGroup<Alphabet>;
	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;
	var bfBackdrop:FlxBackdrop;
	var gear:FlxSprite;
	var cameraTarget:Float = 0;

	// (while sliding, the menu is on a camera of its own that moves, and the gear on one above it)
	var slideCam:FlxCamera = null;
	var gearCam:FlxCamera = null;
	var sliding:Bool = false;
	var exiting:Bool = false;

	/**
	 * @param onPlayState 	Opened from a song: going back goes back to it, and there's no gear.
	 * @param inMainMenu 	Opened over the main menu, which going back slides it off of.
	 */
	public function new(onPlayState:Bool, inMainMenu:Bool, startMode:Int = APPEAR)
	{
		super();
		this.onPlayState = onPlayState;
		this.inMainMenu = inMainMenu;
		this.startMode = startMode;
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		bfBackdrop = new FlxBackdrop(Paths.image('mainmenu/othermenus/bficom'));
		bfBackdrop.antialiasing = ClientPrefs.data.antialiasing;
		bfBackdrop.velocity.set(35, 35);
		bfBackdrop.spacing.set(50, 50);
		bfBackdrop.scrollFactor.set();
		bfBackdrop.alpha = (startMode == SLIDE_OUT) ? 0.125 : 0;
		add(bfBackdrop);
		if(startMode != SLIDE_OUT) FlxTween.tween(bfBackdrop, {alpha: 0.125}, 1.2, {ease: FlxEase.quadOut});

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in OPTIONS)
		{
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$option', option), true);
			optionText.screenCenter();
			optionText.y += (92 * (num - (OPTIONS.length / 2))) + 45;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection(0, false);
		ClientPrefs.saveSettings();

		if(!onPlayState)
		{
			gear = new FlxSprite(0, 10).loadGraphic(Paths.image('mainmenu/menu_options'));
			gear.antialiasing = ClientPrefs.data.antialiasing;
			gear.scrollFactor.set();
			gear.x = -(gear.width / 2);
			add(gear);
		}

		super.create();

		switch(startMode)
		{
			case SLIDE_IN: slide(true);
			case SLIDE_OUT: slide(false);
			default: FlxG.camera.scroll.y = cameraTarget; //(already there when the menu opens)
		}
	}

	// ------------------------------------------------------------------------------------------
	// Sliding over the main menu
	// ------------------------------------------------------------------------------------------

	function setCameras(cameras:Array<FlxCamera>, gearCameras:Array<FlxCamera>):Void
	{
		for (member in members)
		{
			if(member == null) continue;
			member.cameras = (member == gear) ? gearCameras : cameras;
		}
	}

	function makeCamera():FlxCamera
	{
		var camera:FlxCamera = new FlxCamera();
		camera.bgColor = 0;
		FlxG.cameras.add(camera, false);
		return camera;
	}

	/**
	 * Slides the menu in from the right (or out to it), the gear rolling along its left edge. In, it's then on the game's camera
	 * like any menu (the menus it opens go on top of it there).
	 */
	function slide(goingIn:Bool):Void
	{
		sliding = true;
		FlxG.camera.scroll.y = 0;

		slideCam = makeCamera();
		slideCam.scroll.y = cameraTarget;
		if(gear != null) gearCam = makeCamera();
		setCameras([slideCam], (gearCam != null) ? [gearCam] : [slideCam]);

		var width:Float = FlxG.width;
		slideCam.x = goingIn ? width : 0;
		FlxTween.tween(slideCam, {x: goingIn ? 0 : width}, SLIDE_TIME, {ease: goingIn ? FlxEase.cubeOut : FlxEase.cubeInOut, onComplete: function(_)
		{
			sliding = false;
			if(goingIn)
			{
				setCameras([FlxG.camera], [FlxG.camera]);
				FlxG.camera.scroll.y = cameraTarget;
				removeSlideCameras();
			}
			else
			{
				// (the main menu's own gear is back where this one ended up)
				removeSlideCameras();
				close();
				if(onSlidOut != null) onSlidOut();
			}
		}});

		if(gear != null)
		{
			gear.x = goingIn ? width - (gear.width / 2) : -(gear.width / 2);
			gear.angle = goingIn ? 0 : -360;
			FlxTween.tween(gear, {x: goingIn ? -(gear.width / 2) : width - (gear.width / 2), angle: goingIn ? -360 : 0}, SLIDE_TIME,
				{ease: goingIn ? FlxEase.cubeOut : FlxEase.cubeInOut});
		}
	}

	function removeSlideCameras():Void
	{
		for (camera in [slideCam, gearCam])
			if(camera != null && FlxG.cameras.list.contains(camera))
				FlxG.cameras.remove(camera);
		slideCam = gearCam = null;
	}

	// ------------------------------------------------------------------------------------------

	function openSelectedSubstate(label:String)
	{
		switch(label)
		{
			case 'Note Colors':
				openSubState(new options.NotesColorSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new options.VisualsSettingsSubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'V-Slice':
				openSubState(new options.InterfaceSettingsSubState());
			case 'Vortex Engine':
				openSubState(new options.VortexSettingsSubState());
			case 'Adjust Delay and Combo':
				exiting = true;
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'Language':
				openSubState(new options.LanguageSubState());
		}
	}

	// (the menus that open over this one are made for a camera that's standing still)
	override function openSubState(SubState:flixel.FlxSubState)
	{
		FlxG.camera.scroll.y = 0;
		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		super.closeSubState();
		FlxG.camera.scroll.y = cameraTarget;
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(sliding || exiting || subState != null) return;

		FlxG.camera.scroll.y = FlxMath.lerp(cameraTarget, FlxG.camera.scroll.y, Math.exp(-elapsed * 9));

		// (the gear is only there when the menu wasn't opened from a song)
		if(gear != null && ((FlxG.mouse.justPressed && FlxG.mouse.overlaps(gear)) || controls.UI_LEFT_P))
		{
			goBack();
			return;
		}

		if(controls.UI_UP_P) changeSelection(-1);
		if(controls.UI_DOWN_P) changeSelection(1);

		if(controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			goBack();
		}
		else if(controls.ACCEPT) openSelectedSubstate(OPTIONS[OptionsState.curSelected]);
	}

	function goBack():Void
	{
		if(onPlayState)
		{
			exiting = true;
			StageData.loadDirectory(PlayState.SONG);
			LoadingState.loadAndSwitchState(new PlayState());
			FlxG.sound.music.volume = 0;
			return;
		}

		FlxG.sound.play(Paths.sound('chains'));
		if(inMainMenu)
		{
			slide(false);
			return;
		}

		// (opened by OptionsState: the main menu opens it again over itself and slides it out from there)
		exiting = true;
		states.MainMenuState.returningFromOptions = true;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new states.MainMenuState());
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		OptionsState.curSelected = FlxMath.wrap(OptionsState.curSelected + change, 0, OPTIONS.length - 1);

		for (num => item in grpOptions.members)
		{
			item.targetY = num - OptionsState.curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));

		// Where the camera goes: with the selected option in the middle of the screen, without going past the first and the last one.
		// A list that fits on the screen stays where it is
		var first:Alphabet = grpOptions.members[0];
		var last:Alphabet = grpOptions.members[grpOptions.length - 1];
		var selected:Alphabet = grpOptions.members[OptionsState.curSelected];
		var top:Float = first.y - LIST_MARGIN;
		var bottom:Float = last.y + last.height + LIST_MARGIN;

		cameraTarget = 0;
		if(top < 0 || bottom > FlxG.height)
			cameraTarget = FlxMath.bound(selected.y + selected.height / 2 - FlxG.height / 2, Math.min(top, 0), Math.max(bottom - FlxG.height, 0));
	}

	override function destroy()
	{
		removeSlideCameras();
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
