package objects.freeplay;

import backend.PlayableCharacters;
import backend.VSliceConvert;

import flixel.addons.display.FlxBackdrop;
import flixel.tweens.FlxEase.EaseFunction;
import flixel.util.FlxAxes;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;

import objects.freeplay.ExitMovers;

import openfl.display.BlendMode;

/**
 * The card behind the DJ of the V-Slice Freeplay menu.
 *
 * On V-Slice each player's card is a script, here the ones of the base game are classes:
 * `BoyfriendCard` for the player "bf", `PicoCard` for "pico" and this plain one for everybody else.
 *
 * The cards mods make for their players are still scripts: this class is what they get for V-Slice's `BackingCard`,
 * with the same names. Each function a script has its own version of is done by the script instead (see `scripted()`).
 */
class FreeplayBackingCard extends FlxSpriteGroup
{
	public var pinkBack:FlxSprite;
	public var orangeBackShit:FlxSprite;
	public var alsoOrangeLOL:FlxSprite;
	public var confirmGlow:FlxSprite;
	public var confirmGlow2:FlxSprite;
	public var confirmTextGlow:FlxSprite;
	public var cardGlow:FlxSprite;
	public var backingTextYeah:FreeplayAtlas;

	/**
	 * Set by the menu: changes the color of the image behind the songs over time (duration, from, to, ease).
	 */
	public var tintBacking:Float->FlxColor->FlxColor->EaseFunction->Void = null;

	/**
	 * The menu the card is on, for the scripts.
	 */
	public var instance:Dynamic = null;

	/**
	 * Id of the player the card is for.
	 */
	public var currentCharacter(default, null):String;

	var player:PlayableCharacter;

	public static function make(player:PlayableCharacter):FreeplayBackingCard
	{
		#if HSCRIPT_ALLOWED
		var scripted:FreeplayBackingCard = backend.VSliceScripts.makeBackingCard(player.id);
		if(scripted != null) return scripted;
		#end

		return switch(player.id)
		{
			case 'bf': new BoyfriendCard(player);
			case 'pico': new PicoCard(player);
			default: new FreeplayBackingCard(player);
		}
	}

	// True if a script made for the card has its own version of a function, after running it
	inline function scripted(name:String, ?args:Array<Dynamic>):Bool
	{
		return #if HSCRIPT_ALLOWED backend.VSliceScripts.callOverride(this, name, args) #else false #end;
	}

	/**
	 * @param player 	The player, or its id: what scripts give.
	 */
	public function new(player:Dynamic)
	{
		super();
		if(Std.isOfType(player, String))
		{
			currentCharacter = player;
			this.player = PlayableCharacters.get(currentCharacter);
		}
		else
		{
			this.player = player;
			currentCharacter = (this.player != null) ? this.player.id : null;
		}

		cardGlow = makeSprite(-30, -30, 'freeplay/cardGlow');
		confirmGlow = makeSprite(-30, 240, 'freeplay/confirmGlow');
		confirmGlow2 = makeSprite(confirmGlow.x, confirmGlow.y, 'freeplay/confirmGlow2');
		confirmTextGlow = makeSprite(-8, 115, 'freeplay/glowingText');

		// kept out of the GPU cache, the bar is cut with its pixels
		pinkBack = makeSprite(0, 0, 'freeplay/pinkBack', false);

		orangeBackShit = new FlxSprite(84, 440).makeGraphic(Std.int(pinkBack.width), 75, 0xFFFEDA00, true);
		alsoOrangeLOL = new FlxSprite(0, orangeBackShit.y).makeGraphic(100, Std.int(orangeBackShit.height), 0xFFFFD400);

		backingTextYeah = new FreeplayAtlas(640, 370, 'freeplay/backing-text-yeah');

		pinkBack.color = 0xFFFFD4E9;
		pinkBack.x -= pinkBack.width;
	}

	function makeSprite(x:Float, y:Float, key:String, allowGPU:Bool = true):FlxSprite
	{
		var sprite:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image(key, null, allowGPU));
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		return sprite;
	}

	/**
	 * What V-Slice calls `create()`: scripts make their own to add their sprites.
	 */
	public function onCreate(event:Dynamic):Void
	{
		create();
	}

	/**
	 * Adds the sprites, called once by the menu.
	 */
	public function create():Void
	{
		#if HSCRIPT_ALLOWED
		if(scripted('onCreate', [new funkin.modding.events.ScriptEvent(funkin.modding.events.ScriptEventType.CREATE)])) return;
		#end

		FlxTween.tween(pinkBack, {x: 0}, 0.6, {ease: FlxEase.quartOut});
		add(pinkBack);

		add(orangeBackShit);
		add(alsoOrangeLOL);

		// the bar ends along the card's edge
		try
		{
			FlxSpriteUtil.alphaMaskFlxSprite(orangeBackShit, pinkBack, orangeBackShit);
		}
		catch(e:Dynamic) {}
		orangeBackShit.visible = false;
		alsoOrangeLOL.visible = false;

		addConfirmGlows();
		add(backingTextYeah);

		cardGlow.blend = BlendMode.ADD;
		cardGlow.visible = false;
		add(cardGlow);
	}

	function addConfirmGlows():Void
	{
		confirmTextGlow.blend = BlendMode.ADD;
		confirmTextGlow.visible = false;

		confirmGlow.blend = BlendMode.ADD;
		confirmGlow.visible = false;
		confirmGlow2.visible = false;

		add(confirmGlow2);
		add(confirmGlow);
		add(confirmTextGlow);
	}

	public function applyExitMovers(?exitMovers:ExitMoverData, ?exitMoversCharSel:ExitMoverData):Void
	{
		if(scripted('applyExitMovers', [exitMovers, exitMoversCharSel])) return;
		if(exitMovers == null || exitMoversCharSel == null) return;

		exitMovers.set([pinkBack, orangeBackShit, alsoOrangeLOL], {
			x: -pinkBack.width,
			y: pinkBack.y,
			speed: 0.4,
			wait: 0
		});

		exitMoversCharSel.set([pinkBack], {
			y: -100,
			speed: 0.8,
			wait: 0.1
		});

		exitMoversCharSel.set([orangeBackShit, alsoOrangeLOL], {
			y: -40,
			speed: 0.8,
			wait: 0.1
		});
	}

	/**
	 * Puts the card where it ends up, used when coming back from Character Select.
	 */
	public function skipIntroTween():Void
	{
		if(scripted('skipIntroTween')) return;

		FlxTween.cancelTweensOf(pinkBack);
		pinkBack.x = 0;
	}

	/**
	 * Called when the DJ ends its intro animation.
	 */
	public function introDone():Void
	{
		if(scripted('introDone')) return;

		pinkBack.color = 0xFFFFD863;
		orangeBackShit.visible = true;
		alsoOrangeLOL.visible = true;
		flashCardGlow(0.45);
	}

	function flashCardGlow(duration:Float):Void
	{
		cardGlow.visible = true;
		cardGlow.alpha = 1;
		cardGlow.scale.set(1, 1);
		FlxTween.tween(cardGlow, {alpha: 0, "scale.x": 1.2, "scale.y": 1.2}, duration, {ease: FlxEase.sineOut});
	}

	/**
	 * Called when a song is picked.
	 */
	public function confirm():Void
	{
		if(scripted('confirm')) return;

		FlxTween.color(pinkBack, 0.33, 0xFFFFD0D5, 0xFF171831, {ease: FlxEase.quadOut});
		orangeBackShit.visible = false;
		alsoOrangeLOL.visible = false;

		confirmGlow.visible = true;
		confirmGlow2.visible = true;

		backingTextYeah.playMain();
		confirmGlow2.alpha = 0;
		confirmGlow.alpha = 0;

		tint(0.5, 0xFFA8A8A8, 0xFF646464);
		FlxTween.tween(confirmGlow2, {alpha: 0.5}, 0.33, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				confirmGlow2.alpha = 0.6;
				confirmGlow.alpha = 1;
				confirmTextGlow.visible = true;
				confirmTextGlow.alpha = 1;
				FlxTween.tween(confirmTextGlow, {alpha: 0.4}, 0.5);
				FlxTween.tween(confirmGlow, {alpha: 0}, 0.5);
				tint(2, 0xFFCDCDCD, 0xFF555555, FlxEase.expoOut);
			}
		});
	}

	inline function tint(duration:Float, from:FlxColor, to:FlxColor, ?ease:EaseFunction):Void
	{
		if(tintBacking != null) tintBacking(duration, from, to, ease);
	}

	/**
	 * Called when leaving to Character Select.
	 */
	public function enterCharSel():Void
	{
		scripted('enterCharSel');
	}

	// (scripts take no values on theirs, they ask the Conductor)
	public function beatHit(?curBeat:Int, ?bpm:Float):Void
	{
		scripted('beatHit');
	}

	/**
	 * Called when going back to the main menu.
	 */
	public function disappear():Void
	{
		if(scripted('disappear')) return;

		FlxTween.color(pinkBack, 0.25, 0xFFFFD863, 0xFFFFD0D5, {ease: FlxEase.quadOut});
		flashCardGlow(0.25);

		orangeBackShit.visible = false;
		alsoOrangeLOL.visible = false;
	}

	// The game calls these two by itself, which would go right past a script's own versions of them

	override function update(elapsed:Float):Void
	{
		if(scripted('update', [elapsed])) return;
		super.update(elapsed);
	}

	override function destroy():Void
	{
		if(scripted('destroy')) return;
		super.destroy();
	}

	// The glows flash on every beat, on faster songs they skip beats to not flash like crazy
	function isGlowBeat(curBeat:Int, bpm:Float):Bool
	{
		var frequencies:Array<Int> = [1, 2, 4, 8];
		var frequency:Int = frequencies[Std.int(FlxMath.bound(Math.floor(bpm / 140), 0, frequencies.length - 1))];
		return curBeat % frequency == 0;
	}
}

/**
 * Boyfriend's card, with his texts going by.
 */
class BoyfriendCard extends FreeplayBackingCard
{
	var moreWays:BGScrollingText;
	var funnyScroll:BGScrollingText;
	var txtNuts:BGScrollingText;
	var funnyScroll2:BGScrollingText;
	var moreWays2:BGScrollingText;
	var funnyScroll3:BGScrollingText;
	var scrollingTexts:Array<BGScrollingText>;

	var glow:FlxSprite;
	var glowDark:FlxSprite;

	public function new(player:PlayableCharacter)
	{
		super(player);

		var dj:Dynamic = player.freeplayDJ;
		var text1:String = (dj != null) ? VSliceConvert.str(dj.text1, 'BOYFRIEND') : 'BOYFRIEND';
		var text2:String = (dj != null) ? VSliceConvert.str(dj.text2, 'HOT BLOODED IN MORE WAYS THAN ONE') : 'HOT BLOODED IN MORE WAYS THAN ONE';
		var text3:String = (dj != null) ? VSliceConvert.str(dj.text3, 'PROTECT YO NUTS') : 'PROTECT YO NUTS';

		funnyScroll = new BGScrollingText(0, 220, text1, FlxG.width / 2, false, 60);
		funnyScroll2 = new BGScrollingText(0, 335, text1, FlxG.width / 2, false, 60);
		moreWays = new BGScrollingText(0, 160, text2, FlxG.width, true, 43);
		moreWays2 = new BGScrollingText(0, 397, text2, FlxG.width, true, 43);
		txtNuts = new BGScrollingText(0, 285, text3, FlxG.width / 2, true, 43);
		funnyScroll3 = new BGScrollingText(0, orangeBackShit.y + 10, text1, FlxG.width / 2, false, 60);
		scrollingTexts = [moreWays, funnyScroll, txtNuts, funnyScroll2, moreWays2, funnyScroll3];
	}

	override function create():Void
	{
		FlxTween.tween(pinkBack, {x: 0}, 0.6, {ease: FlxEase.quartOut});
		add(pinkBack);

		add(orangeBackShit);
		add(alsoOrangeLOL);

		try
		{
			FlxSpriteUtil.alphaMaskFlxSprite(orangeBackShit, pinkBack, orangeBackShit);
		}
		catch(e:Dynamic) {}
		orangeBackShit.visible = false;
		alsoOrangeLOL.visible = false;

		addConfirmGlows();
		add(backingTextYeah);

		cardGlow.blend = BlendMode.ADD;
		cardGlow.visible = false;

		moreWays.color = 0xFFFFF383;
		moreWays.speed = 6.8;

		funnyScroll.color = 0xFFFF9963;
		funnyScroll.speed = -3.8;

		txtNuts.speed = 3.5;

		funnyScroll2.color = 0xFFFF9963;
		funnyScroll2.speed = -3.8;

		moreWays2.color = 0xFFFFF383;
		moreWays2.speed = 6.8;

		funnyScroll3.color = 0xFFFEA400;
		funnyScroll3.speed = -3.8;

		for (text in scrollingTexts)
		{
			text.visible = false;
			add(text);
		}

		glowDark = makeSprite(-300, 330, 'freeplay/beatglow');
		glowDark.blend = BlendMode.MULTIPLY;
		glowDark.visible = false;
		add(glowDark);

		glow = makeSprite(-300, 330, 'freeplay/beatglow');
		glow.blend = BlendMode.ADD;
		glow.visible = false;
		add(glow);

		add(cardGlow);
	}

	override function applyExitMovers(?exitMovers:ExitMoverData, ?exitMoversCharSel:ExitMoverData):Void
	{
		super.applyExitMovers(exitMovers, exitMoversCharSel);

		exitMovers.set([moreWays], {
			x: FlxG.width * 2,
			speed: 0.4
		});
		exitMovers.set([funnyScroll], {
			x: -funnyScroll.width * 2,
			y: funnyScroll.y,
			speed: 0.4,
			wait: 0
		});
		exitMovers.set([txtNuts], {
			x: FlxG.width * 2,
			speed: 0.4
		});
		exitMovers.set([funnyScroll2], {
			x: -funnyScroll2.width * 2,
			speed: 0.5
		});
		exitMovers.set([moreWays2], {
			x: FlxG.width * 2,
			speed: 0.4
		});
		exitMovers.set([funnyScroll3], {
			x: -funnyScroll3.width * 2,
			speed: 0.3
		});

		exitMoversCharSel.set([for (text in scrollingTexts) (text : FlxSprite)], {
			y: -60,
			speed: 0.8,
			wait: 0.1
		});
	}

	override function enterCharSel():Void
	{
		for (text in scrollingTexts)
			FlxTween.tween(text, {speed: 0}, 0.8, {ease: FlxEase.sineIn});
	}

	override function beatHit(?curBeat:Int, ?bpm:Float):Void
	{
		if(glow == null || !isGlowBeat(curBeat, bpm)) return;

		FlxTween.cancelTweensOf(glow);
		FlxTween.cancelTweensOf(glowDark);

		glow.alpha = 0.8;
		FlxTween.tween(glow, {alpha: 0}, 16 / 24, {ease: FlxEase.quartOut});
		glowDark.alpha = 0;
		FlxTween.tween(glowDark, {alpha: 0.6}, 18 / 24, {ease: FlxEase.quartOut});
	}

	function setExtrasVisible(value:Bool):Void
	{
		for (text in scrollingTexts)
			text.visible = value;
		glowDark.visible = value;
		glow.visible = value;
	}

	override function introDone():Void
	{
		super.introDone();
		setExtrasVisible(true);
	}

	override function confirm():Void
	{
		super.confirm();
		setExtrasVisible(false);
	}

	override function disappear():Void
	{
		super.disappear();
		setExtrasVisible(false);
	}
}

/**
 * Pico's card, with his weapons going by and the glass he shoots when a song is picked.
 */
class PicoCard extends FreeplayBackingCard
{
	var scrollBack:FlxBackdrop;
	var scrollLower:FlxBackdrop;
	var scrollTop:FlxBackdrop;
	var scrollMiddle:FlxBackdrop;

	var glow:FlxSprite;
	var glowDark:FlxSprite;
	var blueBar:FlxSprite;

	var confirmAtlas:FreeplayAtlas;

	override function create():Void
	{
		FlxTween.tween(pinkBack, {x: 0}, 0.6, {ease: FlxEase.quartOut});
		add(pinkBack);

		scrollBack = new FlxBackdrop(Paths.image('freeplay/backingCards/pico/lowerLoop'), FlxAxes.X, 20);
		scrollBack.setPosition(0, 200);
		scrollBack.flipX = true;
		scrollBack.alpha = 0.39;
		scrollBack.velocity.x = 110;
		add(scrollBack);

		scrollLower = new FlxBackdrop(Paths.image('freeplay/backingCards/pico/lowerLoop'), FlxAxes.X, 20);
		scrollLower.setPosition(0, 406);
		scrollLower.velocity.x = -110;
		add(scrollLower);

		blueBar = makeSprite(0, 239, 'freeplay/backingCards/pico/blueBar');
		blueBar.blend = BlendMode.MULTIPLY;
		blueBar.alpha = 0.4;
		add(blueBar);

		scrollTop = new FlxBackdrop(null, FlxAxes.X, 20);
		scrollTop.setPosition(0, 80);
		scrollTop.velocity.x = -220;
		scrollTop.frames = Paths.getSparrowAtlas('freeplay/backingCards/pico/topLoop');
		scrollTop.animation.addByPrefix('uzi', 'uzi info', 24, false);
		scrollTop.animation.addByPrefix('sniper', 'sniper info', 24, false);
		scrollTop.animation.addByPrefix('rocket launcher', 'rocket launcher info', 24, false);
		scrollTop.animation.addByPrefix('rifle', 'rifle info', 24, false);
		scrollTop.animation.addByPrefix('base', 'base', 24, false);
		scrollTop.animation.play('base');
		add(scrollTop);

		scrollMiddle = new FlxBackdrop(Paths.image('freeplay/backingCards/pico/middleLoop'), FlxAxes.X, 15);
		scrollMiddle.setPosition(0, 346);
		scrollMiddle.velocity.x = 220;
		add(scrollMiddle);

		glowDark = makeSprite(-300, 330, 'freeplay/backingCards/pico/glow');
		glowDark.blend = BlendMode.MULTIPLY;
		add(glowDark);

		glow = makeSprite(-300, 330, 'freeplay/backingCards/pico/glow');
		glow.blend = BlendMode.ADD;
		add(glow);

		for (sprite in [scrollBack, scrollLower, scrollTop, scrollMiddle])
			sprite.antialiasing = ClientPrefs.data.antialiasing;

		setExtrasVisible(false);

		confirmAtlas = new FreeplayAtlas(5, 55, 'freeplay/backingCards/pico/pico-confirm');
		confirmAtlas.visible = false;
		add(confirmAtlas);

		cardGlow.blend = BlendMode.ADD;
		cardGlow.visible = false;
		add(cardGlow);
	}

	function setExtrasVisible(value:Bool):Void
	{
		blueBar.visible = value;
		scrollBack.visible = value;
		scrollLower.visible = value;
		scrollTop.visible = value;
		scrollMiddle.visible = value;
		glowDark.visible = value;
		glow.visible = value;
	}

	override function applyExitMovers(?exitMovers:ExitMoverData, ?exitMoversCharSel:ExitMoverData):Void
	{
		super.applyExitMovers(exitMovers, exitMoversCharSel);

		exitMoversCharSel.set([scrollTop], {
			y: -90,
			speed: 0.8,
			wait: 0.1
		});

		exitMoversCharSel.set([scrollMiddle], {
			y: -80,
			speed: 0.8,
			wait: 0.1
		});

		exitMoversCharSel.set([blueBar], {
			y: -70,
			speed: 0.8,
			wait: 0.1
		});

		exitMoversCharSel.set([scrollLower], {
			y: -60,
			speed: 0.8,
			wait: 0.1
		});

		exitMoversCharSel.set([scrollBack], {
			y: -50,
			speed: 0.8,
			wait: 0.1
		});
	}

	override function enterCharSel():Void
	{
		for (scroll in [scrollBack, scrollLower, scrollTop, scrollMiddle])
			FlxTween.tween(scroll.velocity, {x: 0}, 0.8, {ease: FlxEase.sineIn});
	}

	override function confirm():Void
	{
		confirmAtlas.visible = true;
		confirmAtlas.playMain();

		tint(10 / 24, 0xFFFFFFFF, 0xFF8A8A8A, FlxEase.expoOut);

		// each shot lights the image up
		var shots:Array<Array<Int>> = [
			[10, 0xFF343036, 0xFF696366],
			[14, 0xFF27292D, 0xFF686A6F],
			[18, 0xFF2D282D, 0xFF676164],
			[21, 0xFF29292F, 0xFF62626B],
			[24, 0xFF29232C, 0xFF808080]
		];
		for (shot in shots)
			new FlxTimer().start(shot[0] / 24, function(_) tint(3 / 24, shot[1], shot[2], FlxEase.expoOut));
	}

	override function beatHit(?curBeat:Int, ?bpm:Float):Void
	{
		if(glow == null || !isGlowBeat(curBeat, bpm)) return;

		FlxTween.cancelTweensOf(glow);
		FlxTween.cancelTweensOf(glowDark);

		glow.alpha = 1;
		FlxTween.tween(glow, {alpha: 0}, 16 / 24, {ease: FlxEase.quartOut});
		glowDark.alpha = 0;
		FlxTween.tween(glowDark, {alpha: 1}, 18 / 24, {ease: FlxEase.quartOut});
	}

	override function introDone():Void
	{
		pinkBack.color = 0xFF98A2F3;
		setExtrasVisible(true);
		flashCardGlow(0.45);
	}

	override function disappear():Void
	{
		FlxTween.color(pinkBack, 0.25, 0xFF98A2F3, 0xFFFFD0D5, {ease: FlxEase.quadOut});
		setExtrasVisible(false);
		flashCardGlow(0.25);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(scrollTop == null || scrollTop.animation.curAnim == null || !scrollTop.animation.curAnim.finished) return;

		// each weapon's stats flash when it goes by
		var scrollProgress:Float = Math.abs(scrollTop.x % (scrollTop.frameWidth + 20));
		var curName:String = scrollTop.animation.curAnim.name;

		if(scrollProgress >= 500 && scrollProgress <= 700 && curName != 'sniper') scrollTop.animation.play('sniper', true);
		if(scrollProgress >= 700 && scrollProgress <= 1300 && curName != 'rifle') scrollTop.animation.play('rifle', true);
		if(scrollProgress >= 1450 && scrollProgress <= 2000 && curName != 'rocket launcher') scrollTop.animation.play('rocket launcher', true);
		if(scrollProgress >= 0 && scrollProgress <= 300 && curName != 'uzi') scrollTop.animation.play('uzi', true);
	}
}

/**
 * Text that repeats itself across the screen while moving sideways, like a marquee.
 */
class BGScrollingText extends FlxText
{
	public var widthShit:Float = FlxG.width;
	public var placementOffset:Float = 20;
	public var speed:Float = 1;

	// The text's color, by the name V-Slice gives it
	public var funnyColor(get, set):FlxColor;
	function get_funnyColor():FlxColor return color;
	function set_funnyColor(value:FlxColor):FlxColor return color = value;

	var _textPositions:Array<FlxPoint> = [];
	var _positionCache:FlxPoint = FlxPoint.get();

	public function new(x:Float, y:Float, text:String, widthShit:Float = 100, bold:Bool = false, size:Int = 48)
	{
		super(x, y, 0, text, size);
		font = Paths.font('5by7.ttf');
		this.bold = bold;
		antialiasing = ClientPrefs.data.antialiasing;

		this.widthShit = widthShit;
		makePositions();
	}

	public function updateText(newText:String):Void
	{
		text = newText;
		makePositions();
	}

	function makePositions():Void
	{
		@:privateAccess
		regenGraphic();

		var needed:Int = Math.ceil(widthShit / frameWidth) + 1;

		_textPositions = [];
		for (i in 0...needed)
			_textPositions.push(FlxPoint.get((i * frameWidth) + (i * 20), 0));
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (position in _textPositions)
		{
			position.x -= speed * (elapsed / (1 / 60));

			if(speed > 0) //going left
			{
				if(position.x < -frameWidth)
				{
					position.x = _textPositions[_textPositions.length - 1].x + frameWidth + placementOffset;
					sortPositions();
				}
			}
			else if(position.x > frameWidth * 2) //going right
			{
				position.x = _textPositions[0].x - frameWidth - placementOffset;
				sortPositions();
			}
		}
	}

	override function draw():Void
	{
		_positionCache.set(x, y);
		for (position in _textPositions)
		{
			setPosition(_positionCache.x + position.x, _positionCache.y + position.y);
			super.draw();
		}
		setPosition(_positionCache.x, _positionCache.y);
	}

	function sortPositions():Void
	{
		_textPositions.sort((a, b) -> FlxSort.byValues(FlxSort.ASCENDING, a.x, b.x));
	}
}
