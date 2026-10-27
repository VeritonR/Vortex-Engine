package states;

import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;

/**
 * The first time the game is opened: the language is picked (Portuguese or English) before anything else, with the keyboard or the
 * mouse. The one being pointed at stands out, the other is darker; the one picked goes to the middle of the screen, a little bigger,
 * while the other fades away. The warnings come after it, already in that language.
 */
class LanguageSelectState extends MusicBeatState
{
	/** If the language was ever picked: the game asks once. */
	public static var chosen(get, never):Bool;
	static function get_chosen():Bool
		return FlxG.save.data.languageChosen == true;

	static final OPTIONS:Array<{id:String, image:String, label:String}> = [
		{id: 'pt-BR', image: 'languages/brasil', label: 'Português (Brasil)'},
		{id: 'en-US', image: 'languages/eua', label: 'English'}
	];

	static inline final SCALE:Float = 0.66;
	static inline final DARK:FlxColor = 0xFF5A5A5A;

	var flags:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var homeX:Array<Float> = [];
	var curSelected:Int = 0;
	var picked:Bool = false;
	var time:Float = 0;
	var title:FlxText;

	override function create()
	{
		super.create();

		// (just black behind them, and no music)
		FlxG.camera.bgColor = FlxColor.BLACK;

		title = new FlxText(0, 28, FlxG.width, 'Escolha seu idioma  /  Choose your language', 36);
		title.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		add(title);

		for (num => option in OPTIONS)
		{
			var flag:FlxSprite = new FlxSprite().loadGraphic(Paths.image(option.image));
			flag.antialiasing = ClientPrefs.data.antialiasing;
			flag.scale.set(SCALE, SCALE);
			flag.updateHitbox();
			// (it sways around its middle)
			flag.offset.set(flag.frameWidth * (1 - SCALE) / 2, flag.frameHeight * (1 - SCALE) / 2);
			flag.x = FlxG.width / 2 + (num == 0 ? -1 : 1) * 250 - flag.width / 2;
			flag.y = FlxG.height / 2 - flag.height / 2;
			add(flag);
			flags.push(flag);
			homeX.push(flag.x);

			var label:FlxText = new FlxText(0, flag.y + flag.height + 2, 0, option.label, 30);
			label.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			label.x = flag.x + flag.width / 2 - label.width / 2;
			add(label);
			labels.push(label);
		}

		// the one of the computer's language comes selected
		var system:String = '';
		try
		{
			var locale = lime.system.Locale.currentLocale;
			if(locale != null) system = Std.string(locale).toLowerCase();
		}
		catch(e:Dynamic) {}
		curSelected = system.startsWith('pt') ? 0 : 1;
		updateSelection(false);

		FlxG.mouse.visible = true;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;

		// swaying side by side, each one its own way
		for (num => flag in flags)
		{
			if(picked && num == curSelected) continue;
			// (going up and down slowly, one up while the other is down, and their names with them)
			var phase:Float = time * 1.6 + num * Math.PI;
			flag.y = FlxG.height / 2 - flag.height / 2 + Math.sin(phase) * 18;
			labels[num].y = flag.y + flag.height + 2;
		}
		if(picked) return;

		if(controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			curSelected = (curSelected + 1) % flags.length;
			updateSelection(true);
		}

		// the mouse picks the one it's on
		if(FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			for (num => flag in flags)
			{
				if(FlxG.mouse.overlaps(flag))
				{
					if(num != curSelected)
					{
						curSelected = num;
						updateSelection(true);
					}
					if(FlxG.mouse.justPressed) pick();
					break;
				}
			}
		}

		if(controls.ACCEPT && !picked) pick();
	}

	function updateSelection(playSound:Bool):Void
	{
		if(playSound) FlxG.sound.play(Paths.sound('Selector'), 0.7);
		for (num => flag in flags)
		{
			var selected:Bool = (num == curSelected);
			flag.color = selected ? FlxColor.WHITE : DARK;
			labels[num].color = selected ? FlxColor.YELLOW : 0xFF8A8A8A;
		}
	}

	function pick():Void
	{
		picked = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		FlxG.mouse.visible = false;

		var option = OPTIONS[curSelected];
		FlxG.save.data.languageChosen = true;
		ClientPrefs.data.language = option.id;
		ClientPrefs.saveSettings();
		Language.reloadPhrases();

		// the picked one goes to the middle, a little bigger, and the other fades out to make room for it
		var flag:FlxSprite = flags[curSelected];
		var targetX:Float = FlxG.width / 2 - flag.width / 2;
		FlxTween.tween(flag, {x: targetX, y: FlxG.height / 2 - flag.height / 2}, 0.6, {ease: FlxEase.quartOut});
		FlxTween.tween(flag.scale, {x: SCALE * 1.15, y: SCALE * 1.15}, 0.6, {ease: FlxEase.quartOut});
		var label:FlxText = labels[curSelected];
		FlxTween.tween(label, {x: FlxG.width / 2 - label.width / 2, y: FlxG.height / 2 + flag.height / 2 + flag.height * 0.075 + 2}, 0.6, {ease: FlxEase.quartOut});

		for (num => other in flags)
		{
			if(num == curSelected) continue;
			FlxTween.tween(other, {alpha: 0}, 0.5, {ease: FlxEase.quadOut});
			FlxTween.tween(labels[num], {alpha: 0}, 0.5, {ease: FlxEase.quadOut});
		}
		FlxTween.tween(title, {alpha: 0}, 0.5);

		new FlxTimer().start(1.6, function(_)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new TitleState());
		});
	}
}
