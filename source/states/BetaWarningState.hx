package states;

/**
 * The warning shown when the game opens, while the engine is a beta: it isn't finished, some things may not work and crashes are
 * to be expected. In English and in Portuguese at once, as it comes before anyone had the chance to pick a language.
 * It goes away with ACCEPT or BACK, and is only shown once each time the game is opened.
 */
class BetaWarningState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var texts:FlxTypedSpriteGroup<FlxText>;
	var leaving:Bool = false;
	var ready:Bool = false;

	override function create()
	{
		super.create();

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));

		texts = new FlxTypedSpriteGroup<FlxText>();
		texts.alpha = 0;
		add(texts);

		// (in the language that was picked; in both if there's none yet)
		var both:Bool = !LanguageSelectState.chosen;
		var inPortuguese:Bool = ClientPrefs.data.language == 'pt-BR';
		var title:FlxText = new FlxText(0, 70, FlxG.width, both ? "ATTENTION  /  ATENÇÃO" : (inPortuguese ? "ATENÇÃO" : "ATTENTION"));
		title.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		texts.add(title);

		var english:FlxText = new FlxText(140, title.y + title.height + 40, FlxG.width - 280,
			"Vortex Engine is still in BETA.\n"
			+ "It is not completely finished: some things may not work as they should, and crashes are expected.");
		english.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		if(both || !inPortuguese) texts.add(english);

		var portuguese:FlxText = new FlxText(140, both ? english.y + english.height + 36 : english.y, FlxG.width - 280,
			"O Vortex Engine ainda está em BETA.\n"
			+ "Ele não está completamente pronto: algumas coisas podem não funcionar como deveriam, e crashes são esperados.");
		portuguese.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		if(both || inPortuguese) texts.add(portuguese);

		var press:FlxText = new FlxText(0, FlxG.height - 110, FlxG.width, both ? "Press ENTER to continue  /  Aperte ENTER para continuar"
			: (inPortuguese ? "Aperte ENTER para continuar" : "Press ENTER to continue"));
		press.setFormat(Paths.font("vcr.ttf"), 24, 0xFFB0B0B0, CENTER);
		texts.add(press);

		FlxTween.tween(texts, {alpha: 1}, 0.5, {onComplete: function(_) ready = true});
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(leaving || !ready) return;

		if(controls.ACCEPT || controls.BACK)
		{
			leaving = true;
			leftState = true;
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxTween.tween(texts, {alpha: 0}, 0.3, {onComplete: function(_) MusicBeatState.switchState(new TitleState())});
		}
	}
}
