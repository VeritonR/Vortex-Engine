package options;

// The settings of the touch controls (and the phone's own ones), under Options > More
class MobileSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('mobile_menu', 'Mobile Options');
		rpcTitle = 'Mobile Options Menu'; //for Discord Rich Presence

		var option:Option = new Option('Touch Controls',
			"How songs are played by touching the screen (phones, touch screens, or the mouse):
Arrows: touch your arrows. Hitbox: one lane of the screen per arrow.
Buttons: a button per arrow on each side. A pause button is in the corner.",
			'touchControls',
			STRING,
			backend.TouchControls.MODES);
		addOption(option);

		var option:Option = new Option('Touch Controls Opacity',
			'How visible the touch controls are.',
			'touchOpacity',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('Arrow Size',
			"How big your arrows (and their notes) are with the touch controls.
Bigger arrows come closer together to fit the screen.",
			'touchArrowSize',
			PERCENT);
		option.scrollSpeed = 1;
		option.minValue = 0.7;
		option.maxValue = 1.6;
		option.changeValue = 0.05;
		option.decimals = 2;
		addOption(option);

		var option:Option = new Option('Touch Upscroll',
			"If checked, with the touch controls your arrows are at the top
of the screen and the notes go up (they're at the bottom otherwise).",
			'touchUpscroll',
			BOOL);
		addOption(option);

		#if mobile
		var option:Option = new Option('Render Resolution',
			"How many lines of pixels the game is drawn at, stretched to the screen by the phone.
Lower is faster: 720p is the game's own, Native the screen's (the slowest).",
			'renderResolution',
			STRING,
			backend.MobileGraphics.RESOLUTIONS);
		option.onChange = backend.MobileGraphics.apply;
		addOption(option);
		#end

		super();
	}
}
