package objects;

import flixel.math.FlxPoint.FlxCallbackPoint;
import flixel.math.FlxRect;

class Bar extends FlxSpriteGroup
{
	public var leftBar:FlxSprite;
	public var rightBar:FlxSprite;
	public var bg:FlxSprite;
	public var valueFunction:Void->Float = null;
	public var percent(default, set):Float = 0;
	public var bounds:Dynamic = {min: 0, max: 1};
	public var leftToRight(default, set):Bool = true;
	public var barCenter(default, null):Float = 0;

	// you might need to change this if you want to use a custom bar
	public var barWidth(default, set):Int = 1;
	public var barHeight(default, set):Int = 1;
	public var barOffset:FlxPoint = new FlxPoint(3, 3);

	public function new(x:Float, y:Float, image:String = 'healthBar', valueFunction:Void->Float = null, boundX:Float = 0, boundY:Float = 1)
	{
		super(x, y);
		
		this.valueFunction = valueFunction;
		setBounds(boundX, boundY);
		
		bg = new FlxSprite().loadGraphic(Paths.image(image));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		barWidth = Std.int(bg.width - 6);
		barHeight = Std.int(bg.height - 6);

		leftBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		//leftBar.color = FlxColor.WHITE;
		leftBar.antialiasing = antialiasing = ClientPrefs.data.antialiasing;

		rightBar = new FlxSprite().makeGraphic(Std.int(bg.width), Std.int(bg.height), FlxColor.WHITE);
		rightBar.color = FlxColor.BLACK;
		rightBar.antialiasing = ClientPrefs.data.antialiasing;

		add(leftBar);
		add(rightBar);
		add(bg);
		regenerateClips();
	}

	public var enabled:Bool = true;
	override function update(elapsed:Float) {
		if(!enabled)
		{
			super.update(elapsed);
			return;
		}

		if(valueFunction != null)
		{
			var value:Null<Float> = FlxMath.remapToRange(FlxMath.bound(valueFunction(), bounds.min, bounds.max), bounds.min, bounds.max, 0, 100);
			percent = (value != null ? value : 0);
		}
		else percent = 0;
		super.update(elapsed);
	}
	
	public function setBounds(min:Float, max:Float)
	{
		bounds.min = min;
		bounds.max = max;
	}

	public function setColors(left:FlxColor = null, right:FlxColor = null)
	{
		if (left != null)
			leftBar.color = left;
		if (right != null)
			rightBar.color = right;
	}

	/**
	 * If a V-Slice script gave the bar its colors: they're kept when a character is changed, like on V-Slice, where the bar's colors
	 * never come from the characters (see `states.PlayState.reloadHealthBarColors()`).
	 */
	public var colorsFromScript:Bool = false;

	// How V-Slice scripts color the health bar: FlxBar's function, the "empty" side is the left one here
	public function createFilledBar(empty:FlxColor, fill:FlxColor, showBorder:Bool = false, ?border:FlxColor):Bar
	{
		setColors(empty, fill);
		colorsFromScript = true;
		return this;
	}

	// One side at a time
	public function createColoredEmptyBar(empty:FlxColor, showBorder:Bool = false, ?border:FlxColor):Bar
	{
		setColors(empty, null);
		colorsFromScript = true;
		return this;
	}

	public function createColoredFilledBar(fill:FlxColor, showBorder:Bool = false, ?border:FlxColor):Bar
	{
		setColors(null, fill);
		colorsFromScript = true;
		return this;
	}

	/**
	 * On V-Slice the health bar and its frame are two sprites, and scripts move, scale and center them apart: "healthBar" is only the
	 * colored part and "healthBarBG" the frame. Here both are this group, so when a V-Slice script asks for them (see
	 * `funkin.play.PlayState`) the frame comes apart: the bar's place, size and scale become the colored part's, and the colors stop
	 * following the frame. Mods that change the frame for one of their own put it around the bar like that (Sonic.exe's HUD).
	 */
	public var bgApart(default, null):Bool = false;

	public function separateBg():Void
	{
		if(bgApart || bg == null || leftBar == null || rightBar == null) return;
		bgApart = true;

		// (where the colors start, as it is now: nothing moves)
		@:bypassAccessor x = leftBar.x + barOffset.x;
		@:bypassAccessor y = leftBar.y + barOffset.y;
		var oldScale:FlxPoint = scale;
		scale = new FlxCallbackPoint(function(point:FlxPoint) {
			for (part in [leftBar, rightBar])
				if(part != null) part.scale.copyFrom(point);
		});
		scale.set(leftBar.scale.x, leftBar.scale.y);
		if(oldScale != null) oldScale.destroy();
		updateBar();
	}

	override function set_x(value:Float):Float
	{
		if(!bgApart) return super.set_x(value);
		@:bypassAccessor x = value;
		updateBar();
		return value;
	}

	override function set_y(value:Float):Float
	{
		if(!bgApart) return super.set_y(value);
		@:bypassAccessor y = value;
		updateBar();
		return value;
	}

	override public function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		if(!bgApart)
		{
			super.setPosition(X, Y);
			return;
		}
		@:bypassAccessor x = X;
		@:bypassAccessor y = Y;
		updateBar();
	}

	override function get_width():Float
		return bgApart ? barWidth : super.get_width();

	override function get_height():Float
		return bgApart ? barHeight : super.get_height();

	public function updateBar()
	{
		if(leftBar == null || rightBar == null) return;

		var left:Float = bgApart ? x - barOffset.x : bg.x;
		var top:Float = bgApart ? y - barOffset.y : bg.y;
		leftBar.setPosition(left, top);
		rightBar.setPosition(left, top);

		var leftSize:Float = 0;
		if(leftToRight) leftSize = FlxMath.lerp(0, barWidth, percent / 100);
		else leftSize = FlxMath.lerp(0, barWidth, 1 - percent / 100);

		leftBar.clipRect.width = leftSize;
		leftBar.clipRect.height = barHeight;
		leftBar.clipRect.x = barOffset.x;
		leftBar.clipRect.y = barOffset.y;

		rightBar.clipRect.width = barWidth - leftSize;
		rightBar.clipRect.height = barHeight;
		rightBar.clipRect.x = barOffset.x + leftSize;
		rightBar.clipRect.y = barOffset.y;

		barCenter = leftBar.x + leftSize + barOffset.x;

		// flixel is retarded
		leftBar.clipRect = leftBar.clipRect;
		rightBar.clipRect = rightBar.clipRect;
	}

	public function regenerateClips()
	{
		if(leftBar != null)
		{
			leftBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			leftBar.updateHitbox();
			leftBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		if(rightBar != null)
		{
			rightBar.setGraphicSize(Std.int(bg.width), Std.int(bg.height));
			rightBar.updateHitbox();
			rightBar.clipRect = new FlxRect(0, 0, Std.int(bg.width), Std.int(bg.height));
		}
		updateBar();
	}

	private function set_percent(value:Float)
	{
		var doUpdate:Bool = false;
		if(value != percent) doUpdate = true;
		percent = value;

		if(doUpdate) updateBar();
		return value;
	}

	private function set_leftToRight(value:Bool)
	{
		leftToRight = value;
		updateBar();
		return value;
	}

	private function set_barWidth(value:Int)
	{
		barWidth = value;
		regenerateClips();
		return value;
	}

	private function set_barHeight(value:Int)
	{
		barHeight = value;
		regenerateClips();
		return value;
	}
}