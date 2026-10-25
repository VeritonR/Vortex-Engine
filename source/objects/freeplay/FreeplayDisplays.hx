package objects.freeplay;

import backend.FreeplayData;

import flixel.graphics.frames.FlxAtlasFrames;

import shaders.FreeplayShaders.PureColor;

// Smaller pieces of the V-Slice Freeplay menu: the score, the clear percent, and the difficulty with its arrows and dots

/**
 * The score of the selected song, on digital numbers.
 */
class FreeplayScore extends FlxTypedSpriteGroup<ScoreNum>
{
	var score:Int = -1;

	public function new(x:Float, y:Float, digitCount:Int, style:FreeplayStyle)
	{
		super(0, 0);

		for (i in 0...digitCount)
			add(new ScoreNum(x + (45 * i), y, style));

		updateScore(0);
	}

	public function updateScore(newScore:Int):Void
	{
		if(newScore == score) return;
		score = newScore;

		var left:Int = Std.int(Math.max(0, Math.min(newScore, Math.pow(10, members.length) - 1)));
		var position:Int = members.length - 1;
		while(position >= 0)
		{
			members[position].digit = left % 10;
			left = Math.floor(left / 10);
			position--;
		}
	}
}

class ScoreNum extends FlxSprite
{
	static final numToString:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];

	public var digit(default, set):Int = -1;

	public function new(x:Float, y:Float, style:FreeplayStyle)
	{
		super(x, y);

		var numbers:FlxAtlasFrames = Paths.fileExists('images/${style.numbersAsset}.png', IMAGE) ? Paths.getSparrowAtlas(style.numbersAsset) : null;
		frames = (numbers != null) ? numbers : Paths.getSparrowAtlas('digital_numbers');

		for (name in numToString)
			animation.addByPrefix(name, '$name DIGITAL', 24, false);
		animation.play(numToString[0], true);

		antialiasing = ClientPrefs.data.antialiasing;
		setGraphicSize(Std.int(width * 0.4));
		updateHitbox();

		digit = 0;
	}

	function set_digit(value:Int):Int
	{
		if(value < 0 || value > 9) value = 0;
		if(value == digit) return value;

		animation.play(numToString[value], true, false, 0);
		updateHitbox();

		// the one is thinner than the others
		if(value == 1) offset.x -= 15;
		else centerOffsets(false);

		return digit = value;
	}
}

/**
 * The accuracy of the selected song as a percent, from 0 to 100.
 */
class FreeplayClearText extends FlxSpriteGroup
{
	var digits:Array<FlxSprite> = [];
	var value:Int = -1;
	var maxHeight:Float = 0;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		var font:FlxAtlasFrames = Paths.getSparrowAtlas('fonts/freeplay-clear');
		if(font != null)
			for (frame in font.frames)
				maxHeight = Math.max(maxHeight, frame.frame.height);

		for (i in 0...3)
		{
			var digit:FlxSprite = new FlxSprite();
			digit.frames = font;
			if(font != null)
				for (number in 0...10)
					digit.animation.addByPrefix('$number', '$number', 24);
			digit.antialiasing = ClientPrefs.data.antialiasing;
			digit.visible = false;
			digits.push(digit);
			add(digit);
		}

		setValue(0);
	}

	public function setValue(newValue:Int):Void
	{
		newValue = Std.int(FlxMath.bound(newValue, 0, 100));
		if(newValue == value) return;
		value = newValue;

		var text:String = Std.string(newValue);
		var xPos:Float = 0;
		for (i in 0...digits.length)
		{
			var digit:FlxSprite = digits[i];
			digit.visible = (visible && i < text.length);
			digit.ID = (i < text.length) ? 1 : 0;
			if(i >= text.length || !digit.animation.exists(text.charAt(i))) continue;

			digit.animation.play(text.charAt(i));
			digit.updateHitbox();
			digit.x = x + xPos;
			digit.y = y + maxHeight - digit.height;
			xPos += digit.width;
		}

		// keeps it aligned to the right
		var offsetX:Float = switch(text.length)
		{
			case 3: 10;
			case 1: -24;
			default: 0;
		}
		for (digit in digits)
			digit.offset.x += offsetX;
	}

	// Showing the group can't show the digits that aren't in use
	override function set_visible(value:Bool):Bool
	{
		super.set_visible(value);
		for (digit in digits)
			digit.visible = (value && digit.ID == 1);
		return value;
	}
}

/**
 * Name of a difficulty: the image "freeplay/freeplay(difficulty)" if there's one, otherwise it's written with the letters of "freeplay/letterStuff".
 */
class DifficultySprite extends FlxSpriteGroup
{
	// Space the base game's images take, the written names are centered on it
	static inline final BOX_WIDTH:Float = 210;
	static inline final BOX_HEIGHT:Float = 68;

	public var difficultyId:String;

	public function new(difficultyId:String, name:String)
	{
		super();
		this.difficultyId = difficultyId;

		var image:String = findImage(difficultyId);
		if(image != null)
		{
			var sprite:FlxSprite = new FlxSprite();
			if(Paths.fileExists('images/$image.xml', TEXT))
			{
				sprite.frames = Paths.getSparrowAtlas(image);
				sprite.animation.addByPrefix('idle', 'idle0', 24, true);
				if(ClientPrefs.data.flashing) sprite.animation.play('idle');
			}
			else sprite.loadGraphic(Paths.image(image));

			sprite.antialiasing = ClientPrefs.data.antialiasing;
			add(sprite);
			return;
		}

		// No image for it, writes its name
		var letters:Array<FlxSprite> = [];
		var totalWidth:Float = 0;
		var maxHeight:Float = 0;
		for (i in 0...name.length)
		{
			var char:String = name.charAt(i).toLowerCase();
			if(char == ' ' || char == '-')
			{
				totalWidth += 15;
				continue;
			}

			var letter:FlxSprite = new FlxSprite(totalWidth, 0);
			letter.frames = Paths.getSparrowAtlas('freeplay/letterStuff');
			letter.animation.addByPrefix('idle', '$char instance 10000', 24, true);
			if(!letter.animation.exists('idle'))
			{
				letter.destroy(); //the letters only go from A to Z
				continue;
			}

			letter.animation.play('idle');
			letter.updateHitbox();
			letter.antialiasing = ClientPrefs.data.antialiasing;
			letters.push(letter);

			totalWidth += letter.width + 2;
			maxHeight = Math.max(maxHeight, letter.height);
		}

		for (letter in letters)
		{
			letter.x += (BOX_WIDTH - totalWidth) / 2;
			letter.y = (BOX_HEIGHT - maxHeight) / 2 + (maxHeight - letter.height);
			add(letter);
		}
	}

	// The images used to be on the "VsliceFreeplay" folder, the ones mods have there still work
	static function findImage(difficultyId:String):String
	{
		var id:String = difficultyId;
		while(id.length > 0)
		{
			for (folder in ['freeplay', 'VsliceFreeplay'])
				if(Paths.fileExists('images/$folder/freeplay$id.png', IMAGE))
					return '$folder/freeplay$id';

			// "hard-something" can use the image of "hard"
			var cut:Int = id.lastIndexOf('-');
			if(cut < 0) break;
			id = id.substr(0, cut);
		}
		return null;
	}
}

/**
 * The arrows around the difficulty.
 */
class DifficultySelector extends FlxSprite
{
	var whiteShader:PureColor;
	var pressTimer:FlxTimer = null;

	public function new(x:Float, y:Float, flipped:Bool, style:FreeplayStyle)
	{
		super(x, y);

		var key:String = Paths.fileExists('images/${style.selectorAsset}.png', IMAGE) ? style.selectorAsset : 'freeplay/freeplaySelector/freeplaySelector';
		frames = Paths.getSparrowAtlas(key);
		animation.addByPrefix('shine', 'arrow pointer loop', 24);
		animation.play('shine');
		antialiasing = ClientPrefs.data.antialiasing;

		whiteShader = new PureColor(FlxColor.WHITE);
		whiteShader.colorSet = true;

		flipX = flipped;
	}

	/**
	 * Shrinks and flashes for a moment.
	 */
	public function press():Void
	{
		offset.y -= 5;
		scale.x = scale.y = 0.5;
		if(ClientPrefs.data.shaders) shader = whiteShader;

		if(pressTimer != null) pressTimer.cancel();
		pressTimer = new FlxTimer().start(2 / 24, function(_)
		{
			scale.x = scale.y = 1;
			shader = null;
			updateHitbox();
		});
	}

	override function destroy():Void
	{
		if(pressTimer != null) pressTimer.cancel();
		super.destroy();
	}
}

enum DotType
{
	NORMAL;
	ERECT;
	INACTIVE; //the selected song doesn't have this difficulty
}

enum DotState
{
	DESELECTING;
	DESELECTED;
	SELECTED;
}

/**
 * One of the dots under the difficulty, there's one for each difficulty the menu has.
 */
class DifficultyDot extends FlxSprite
{
	static final normalColors:Array<FlxColor> = [0xFF484848, 0xFFFAFAFA];
	static final nightColors:Array<FlxColor> = [0xFF34296A, 0xFFC28AFF];

	public var difficultyId:String;

	var colorTween:FlxTween = null;
	var fadeTween:FlxTween = null;
	var type:DotType = NORMAL;
	var fadedIn:Bool = false;

	public function new(difficultyId:String)
	{
		super();
		this.difficultyId = difficultyId;

		loadGraphic(Paths.image('freeplay/seperator'));
		antialiasing = ClientPrefs.data.antialiasing;
		alpha = 0;
	}

	public function updateState(type:DotType, state:DotState):Void
	{
		this.type = type;

		if(colorTween != null) colorTween.cancel();

		var colors:Array<FlxColor> = (type == ERECT) ? nightColors : normalColors;
		if(type == INACTIVE) color = 0xFF121212;
		else
		{
			switch(state)
			{
				case SELECTED: color = colors[1];
				case DESELECTING: colorTween = FlxTween.color(this, 0.5, colors[1], colors[0], {ease: FlxEase.quartOut});
				case DESELECTED: color = colors[0];
			}
		}

		if(fadedIn && (fadeTween == null || fadeTween.finished)) alpha = (type == INACTIVE) ? 0.33 : 1;
	}

	public function fadeIn():Void
	{
		alpha = 0;
		fadedIn = true;
		if(fadeTween != null) fadeTween.cancel();
		fadeTween = FlxTween.tween(this, {alpha: (type == INACTIVE) ? 0.33 : 1}, 0.5, {ease: FlxEase.quartOut});
	}

	public function fadeOut():Void
	{
		fadedIn = false;
		if(fadeTween != null) fadeTween.cancel();
		fadeTween = FlxTween.tween(this, {alpha: 0}, 0.25, {ease: FlxEase.quartOut});
	}

	override function destroy():Void
	{
		if(colorTween != null) colorTween.cancel();
		if(fadeTween != null) fadeTween.cancel();
		super.destroy();
	}
}
