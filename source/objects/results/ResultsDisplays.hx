package objects.results;

import flixel.group.FlxSpriteGroup;
import shaders.FreeplayShaders.PureColor;

/**
 * The score of the results screen, with digits that shuffle before settling on their numbers.
 */
class ResultScore extends FlxTypedSpriteGroup<ScoreNum>
{
	public var scoreShit(default, set):Int = 0;
	public var scoreStart:Int = 0;

	function set_scoreShit(value:Int):Int
	{
		if(group == null || group.members == null) return value;

		var loopNum:Int = group.members.length - 1;
		var number:Int = Std.int(Math.min(Math.max(value, 0), Math.pow(10, group.members.length) - 1));

		while(number > 0)
		{
			scoreStart += 1;
			group.members[loopNum].finalDigit = number % 10;
			number = Math.floor(number / 10);
			loopNum--;
		}

		while(loopNum > 0)
		{
			group.members[loopNum].digit = 10;
			loopNum--;
		}
		return value;
	}

	public function animateNumbers():Void
	{
		for (i in group.members.length - scoreStart...group.members.length)
		{
			new FlxTimer().start((i - 1) / 24, function(_)
			{
				if(group == null || group.members[i] == null) return;

				group.members[i].finalDelay = scoreStart - (i - 1);
				group.members[i].playAnim();
				group.members[i].shuffle();
			});
		}
	}

	public function new(x:Float, y:Float, digitCount:Int, scoreShit:Int = 100)
	{
		super(x, y);

		for (i in 0...digitCount)
			add(new ScoreNum(x + (65 * i), y));

		this.scoreShit = scoreShit;
	}

	public function updateScore(scoreNew:Int):Void
	{
		scoreShit = scoreNew;
	}
}

class ScoreNum extends FlxSprite
{
	public var digit(default, set):Int = 10;
	public var finalDigit(default, set):Int = 10;
	public var glow:Bool = true;

	function set_finalDigit(value:Int):Int
	{
		animation.play('GONE', true, false, 0);
		return finalDigit = value;
	}

	function set_digit(value:Int):Int
	{
		if(value >= 0 && animation.curAnim != null && animation.curAnim.name != numToString[value])
		{
			if(glow)
			{
				animation.play(numToString[value], true, false, 0);
				glow = false;
			}
			else animation.play(numToString[value], true, false, 4);

			updateHitbox();

			switch(value)
			{
				case 1, 4, 5, 7, 9:
				default: centerOffsets(false);
			}
		}
		return digit = value;
	}

	public function playAnim():Void
	{
		animation.play(numToString[digit], true, false, 0);
	}

	public var shuffleTimer:FlxTimer;
	public var finalTween:FlxTween;
	public var finalDelay:Float = 0;

	public var baseY:Float = 0;
	public var baseX:Float = 0;

	var numToString:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE', 'DISABLED'];

	function finishShuffleTween():Void
	{
		finalTween = FlxTween.num(0.0, finalDigit, 23 / 24, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				new FlxTimer().start(finalDelay / 24, function(_)
				{
					if(animation != null && animation.curAnim != null) animation.play(animation.curAnim.name, true, false, 0);
				});
			}
		}, function(value:Float)
		{
			if(animation != null) digit = Math.floor(value);
		});
	}

	function shuffleProgress(timer:FlxTimer):Void
	{
		if(animation == null) return; //the screen was left in the middle of it

		var tempDigit:Int = digit + 1;
		if(tempDigit > 9) tempDigit = 0;
		if(tempDigit < 0) tempDigit = 0;
		digit = tempDigit;

		if(timer.loops > 0 && timer.loopsLeft == 0) finishShuffleTween();
	}

	public function shuffle():Void
	{
		var duration:Float = 41 / 24;
		var interval:Float = 1 / 24;
		shuffleTimer = new FlxTimer().start(interval, shuffleProgress, Std.int(duration / interval));
	}

	public function new(x:Float, y:Float)
	{
		super(x, y);

		baseY = y;
		baseX = x;

		frames = Paths.getSparrowAtlas('resultScreen/score-digital-numbers');
		antialiasing = ClientPrefs.data.antialiasing;

		for (i in 0...10)
		{
			var stringNum:String = numToString[i];
			animation.addByPrefix(stringNum, '$stringNum DIGITAL', 24, false);
		}

		animation.addByPrefix('DISABLED', 'DISABLED', 24, false);
		animation.addByPrefix('GONE', 'GONE', 24, false);

		this.digit = 10;
		animation.play(numToString[digit], true);
		updateHitbox();
	}

	override function destroy():Void
	{
		if(shuffleTimer != null) shuffleTimer.cancel();
		if(finalTween != null) finalTween.cancel();
		super.destroy();
	}
}

/**
 * The "clear" percentage: the big one that counts up, and the small one that stays by the song's name.
 */
class ClearPercentCounter extends FlxTypedSpriteGroup<FlxSprite>
{
	public var curNumber(default, set):Int = 0;

	var numberChanged:Bool = false;

	function set_curNumber(value:Int):Int
	{
		numberChanged = true;
		return curNumber = value;
	}

	var small:Bool = false;
	var flashShader:PureColor;

	public function new(x:Float, y:Float, startingNumber:Int = 0, small:Bool = false)
	{
		super(x, y);

		flashShader = new PureColor(FlxColor.WHITE);
		flashShader.colorSet = false;

		curNumber = startingNumber;
		this.small = small;

		var clearPercentText:FlxSprite = new FlxSprite().loadGraphic(Paths.image('resultScreen/clearPercent/clearPercentText' + (small ? 'Small' : '')));
		clearPercentText.antialiasing = ClientPrefs.data.antialiasing;
		clearPercentText.x = small ? 40 : 0;
		add(clearPercentText);

		drawNumbers();
	}

	/**
	 * Makes the numbers white, or back to normal.
	 */
	public function flash(enabled:Bool):Void
	{
		flashShader.colorSet = enabled;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(numberChanged) drawNumbers();
	}

	function drawNumbers():Void
	{
		numberChanged = false;

		var seperatedScore:Array<Int> = [];
		var tempCombo:Int = Math.round(curNumber);

		while(tempCombo > 0)
		{
			seperatedScore.push(tempCombo % 10);
			tempCombo = Math.floor(tempCombo / 10);
		}

		if(seperatedScore.length == 0) seperatedScore.push(0);
		seperatedScore.reverse();

		for (ind => num in seperatedScore)
		{
			var digitIndex:Int = ind + 1;

			// 3 digits = offset by 1 left, 1 digit = offset by 1 right
			var digitOffset:Int = (seperatedScore.length == 1) ? 1 : ((seperatedScore.length == 3) ? -1 : 0);
			var digitSize:Float = small ? 32 : 72;
			var digitHeightOffset:Float = small ? -4 : 0;

			var xPos:Float = (digitIndex - 1 + digitOffset) * (digitSize * this.scale.x);
			xPos += small ? -24 : 0;
			var yPos:Float = (digitIndex - 1 + digitOffset) * (digitHeightOffset * this.scale.y);
			yPos += small ? 0 : 72;

			if(digitIndex >= members.length)
			{
				// three digits = LRL, two digits = RL, one digit = L
				var variant:Bool = (seperatedScore.length == 3) ? (digitIndex >= 2) : (digitIndex >= 1);
				var numb:ClearPercentNumber = new ClearPercentNumber(xPos, yPos, num, variant, this.small);
				numb.scale.set(this.scale.x, this.scale.y);
				numb.shader = flashShader;
				numb.visible = true;
				add(numb);
			}
			else
			{
				members[digitIndex].animation.play(Std.string(num));
				members[digitIndex].x = xPos + this.x;
				members[digitIndex].y = yPos + this.y;
				members[digitIndex].visible = true;
			}
		}

		for (ind in (seperatedScore.length + 1)...members.length)
			members[ind].visible = false;
	}
}

class ClearPercentNumber extends FlxSprite
{
	public function new(x:Float, y:Float, digit:Int, variant:Bool, small:Bool)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('resultScreen/clearPercent/clearPercentNumber' + (small ? 'Small' : (variant ? 'Right' : 'Left')));
		antialiasing = ClientPrefs.data.antialiasing;

		for (i in 0...10)
			animation.addByPrefix('$i', 'number $i 0', 24, false);

		animation.play('$digit');
		updateHitbox();
	}
}

/**
 * One of the counters of the results screen (notes hit, max combo, sicks, goods...), that counts up to its number.
 */
class TallyCounter extends FlxTypedSpriteGroup<FlxSprite>
{
	public var curNumber:Float = 0;
	public var neededNumber:Int = 0;
	public var flavour:Int = 0xFFFFFFFF;

	public function new(x:Float, y:Float, neededNumber:Int = 0, ?flavour:Int)
	{
		super(x, y);

		this.flavour = (flavour != null) ? flavour : 0xFFFFFFFF;
		this.neededNumber = neededNumber;

		if(curNumber == neededNumber) drawNumbers();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(curNumber < neededNumber) drawNumbers();
	}

	function drawNumbers():Void
	{
		var seperatedScore:Array<Int> = [];
		var tempCombo:Int = Math.round(curNumber);

		while(tempCombo != 0)
		{
			seperatedScore.push(tempCombo % 10);
			tempCombo = Math.floor(tempCombo / 10);
		}

		if(seperatedScore.length == 0) seperatedScore.push(0);
		seperatedScore.reverse();

		for (ind => num in seperatedScore)
		{
			if(ind >= members.length)
			{
				var numb:TallyNumber = new TallyNumber(ind * (43 * this.scale.x), 0, num);
				numb.scale.set(this.scale.x, this.scale.y);
				add(numb);
				numb.color = flavour;
			}
			else
			{
				members[ind].animation.play(Std.string(num));
				members[ind].color = flavour;
			}
		}
	}
}

class TallyNumber extends FlxSprite
{
	public function new(x:Float, y:Float, digit:Int)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('resultScreen/tallieNumber');
		antialiasing = ClientPrefs.data.antialiasing;

		for (i in 0...10)
			animation.addByPrefix(Std.string(i), '$i small', 24, false);

		animation.play(Std.string(digit));
		updateHitbox();
	}
}
