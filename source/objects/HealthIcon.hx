package objects;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';
	public var hasWinningIcon:Bool = false;
	public var isAnimated:Bool = false;

	/**
	 * The icon's size when it isn't bopping. 1 for the usual ones; an animated icon is made 150 pixels on its longer side, like V-Slice
	 * does (`HealthIcon.snapToTargetSize()`): their spritesheets can be of any size (the MCM mod's "SquidClone4" is 350x450).
	 */
	public var baseScale:Float = 1;

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = false)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	// (kept where they can be read by default: they're small, and scripts take their colors from their pixels, like the health bars
	// of V-Slice mods do. Only on the graphics card those can't be read)
	public function changeIcon(char:String, ?allowGPU:Bool = false) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			
			var graphic = Paths.image(name, null, allowGPU);
			
			isAnimated = Paths.fileExists('images/' + name + '.xml', TEXT);
			if (isAnimated)
			{
				frames = Paths.getSparrowAtlas(name, null, allowGPU);
				animation.addByPrefix('normal', 'normal', 24, true, isPlayer);

				// (only the ones made the way Vortex's are, with a "normal" animation: mods made for Psych have an .xml of their own
				// there for scripts that animate the icons themselves, reading this one's frame like Psych has it - Gorefield's)
				if (!animation.exists('normal')) isAnimated = false;
			}

			if (isAnimated)
			{
				animation.addByPrefix('losing', 'losing', 24, true, isPlayer);
				animation.addByPrefix('winning', 'winning', 24, true, isPlayer);
				
				animation.play('normal');
				this.char = char;
				hasWinningIcon = true;

				iconOffsets[0] = 0;
				iconOffsets[1] = 0;
				var longest:Float = Math.max(frameWidth, frameHeight);
				baseScale = (longest > 0) ? 150 / longest : 1;
				scale.set(baseScale, baseScale);
				updateHitbox();
				
				if(char.endsWith('-pixel')) antialiasing = false;
				else antialiasing = ClientPrefs.data.antialiasing;
			}
			else
			{

				var iSize:Float = Math.round(graphic.width / graphic.height);
				baseScale = 1;
				scale.set(1, 1);
				loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
				iconOffsets[0] = (width - 150) / iSize;
				iconOffsets[1] = (height - 150) / iSize;
				updateHitbox();

				animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
				animation.play(char);
				this.char = char;

				hasWinningIcon = (frames.frames.length >= 3);

				if(char.endsWith('-pixel'))
					antialiasing = false;
				else
					antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		// (an animated one is centered in its box by flixel itself: it's scaled down to fit, see baseScale)
		if(autoAdjustOffset && !isAnimated)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function getCharacter():String {
		return char;
	}

	// The names V-Slice scripts know these by

	/**
	 * If the icon is placed (and made bigger on the beat) by the game. V-Slice scripts turn it off to put the icons somewhere else.
	 */
	public var autoUpdate:Bool = true;

	public var characterId(get, set):String;
	function get_characterId():String return char;
	function set_characterId(value:String):String
	{
		if(value != null && value != char) changeIcon(value);
		return value;
	}

	/**
	 * Shows the icon for an amount of health, from 0 to 2: losing when it's low, winning when it's high (for the icons that have one).
	 */
	public function updateHealthIcon(health:Float):Void
	{
		updateIconAnim(health * 50);
	}
	
	/**
	 * Shows one of the icon's looks by its name, like V-Slice's icons: "idle", "losing" or "winning" (and any other an animated icon has).
	 */
	public function playAnimation(name:String, restart:Bool = false):Void
	{
		if(isAnimated)
		{
			var anim:String = (name == 'idle') ? 'normal' : name;
			if(!animation.exists(anim)) anim = name;
			if(animation.exists(anim)) animation.play(anim, restart);
			return;
		}
		if(animation.curAnim == null) return;

		animation.curAnim.curFrame = switch(name)
		{
			case 'losing', 'toLosing': 1;
			case 'winning', 'toWinning': hasWinningIcon ? 2 : 0;
			default: 0;
		}
	}

	public function updateIconAnim(healthPercent:Float)
	{
		if (isAnimated)
		{
			// not every animated icon has all 3 animations, fall back to "normal" instead of spamming warnings every frame
			var anim:String = 'normal';
			if (healthPercent < 20) anim = 'losing';
			else if (healthPercent > 80 && hasWinningIcon) anim = 'winning';

			if (!animation.exists(anim)) anim = 'normal';
			if (animation.exists(anim)) animation.play(anim);
		}
		else if (animation.curAnim != null)
		{
			if (healthPercent < 20)
				animation.curAnim.curFrame = 1;
			else if (healthPercent > 80 && hasWinningIcon)
				animation.curAnim.curFrame = 2;
			else
				animation.curAnim.curFrame = 0;
		}
	}
}