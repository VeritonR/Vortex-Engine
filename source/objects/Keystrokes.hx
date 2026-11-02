package objects;

import backend.ExtraKeys;
import backend.InputFormatter;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSpriteUtil;

/**
 * The keys the player presses, shown on the screen during a song (the "Keystrokes" option): a box for each arrow with the key it's on,
 * lit in the arrow's color while it's held, and how many keys per second are being pressed.
 *
 * "WASD": the 4 keys laid out like W A S D (up on top, left down right under it). "DFJK": all of them in a row, in the order of the
 * arrows; songs with more or fewer than 4 arrows always use this one.
 */
class Keystrokes extends FlxSpriteGroup
{
	static inline var MAX_SIZE:Int = 50;
	static inline var MAX_WIDTH:Float = 320; //(a row of many keys gets smaller boxes, to stay clear of the health bar)

	var SIZE:Int = 50;
	var GAP:Int = 6;

	var boxes:Array<FlxSprite> = [];
	var fills:Array<FlxSprite> = [];
	var labels:Array<FlxText> = [];
	var kpsText:FlxText;
	var wasPressed:Array<Bool> = [];
	var presses:Array<Float> = []; //(when each press of the last second was)
	var time:Float = 0;

	public function new(style:String, actions:Array<String>)
	{
		super();
		var count:Int = actions.length;
		var wasd:Bool = (style == 'WASD' && count == 4);
		if(!wasd && count > 0)
		{
			SIZE = Std.int(Math.min(MAX_SIZE, (MAX_WIDTH + GAP) / count - GAP));
			GAP = Std.int(Math.max(3, SIZE * 0.12));
		}

		// where each column's box goes: WASD has the up arrow (column 2) on top of the down one
		var places:Array<{x:Float, y:Float}> = [];
		var width:Float = 0;
		if(wasd)
		{
			places = [{x: 0, y: 1}, {x: 1, y: 1}, {x: 1, y: 0}, {x: 2, y: 1}];
			width = 3 * (SIZE + GAP) - GAP;
		}
		else
		{
			for (i in 0...count) places.push({x: i, y: 0});
			width = count * (SIZE + GAP) - GAP;
		}

		for (i in 0...count)
		{
			var x:Float = places[i].x * (SIZE + GAP);
			var y:Float = places[i].y * (SIZE + GAP);

			// the box: a dark rounded square with a light outline, and its color under it while held
			var fill:FlxSprite = new FlxSprite(x, y).makeGraphic(SIZE, SIZE, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(fill, 0, 0, SIZE, SIZE, SIZE * 0.28, SIZE * 0.28, FlxColor.WHITE);
			var colors:Array<FlxColor> = ExtraKeys.rgbOf(i, false);
			fill.color = (colors != null) ? colors[0] : FlxColor.WHITE;
			fill.alpha = 0;
			add(fill);
			fills.push(fill);

			var box:FlxSprite = new FlxSprite(x, y).makeGraphic(SIZE, SIZE, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(box, 1, 1, SIZE - 2, SIZE - 2, SIZE * 0.28, SIZE * 0.28, 0x66000000, {thickness: 2, color: 0xCCFFFFFF});
			add(box);
			boxes.push(box);

			var textSize:Int = Std.int(Math.max(10, SIZE * 0.36));
			var label:FlxText = new FlxText(x, y + SIZE / 2 - 11, SIZE, keyName(actions[i]), textSize);
			label.setFormat(Paths.font('vcr.ttf'), textSize, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			label.borderSize = 1.5;
			if(label.text.length > 3) label.size = Std.int(Math.max(8, textSize * 0.65)); //("SPACE", "SHIFT"...)
			label.y = y + (SIZE - label.height) / 2;
			add(label);
			labels.push(label);

			wasPressed.push(false);
		}

		var rows:Int = wasd ? 2 : 1;
		kpsText = new FlxText(0, rows * (SIZE + GAP), width, '0 KPS', 16);
		kpsText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		kpsText.borderSize = 1.5;
		add(kpsText);
	}

	// The first key of an action, as it's written in the Controls menu
	static function keyName(action:String):String
	{
		var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(action);
		if(binds != null)
			for (key in binds)
				if(key != NONE) return InputFormatter.getKeyName(key);
		return '-';
	}

	/**
	 * Which columns are held now.
	 */
	public function setPressed(pressed:Array<Bool>, elapsed:Float):Void
	{
		time += elapsed;
		for (i in 0...fills.length)
		{
			var held:Bool = (i < pressed.length && pressed[i] == true);
			if(held && !wasPressed[i]) presses.push(time);
			wasPressed[i] = held;

			// (lights up at once, fades out a bit slower)
			var target:Float = held ? 0.9 : 0;
			fills[i].alpha = held ? target : Math.max(0, fills[i].alpha - elapsed * 6);
			var scale:Float = held ? 0.92 : 1;
			for (part in [fills[i], boxes[i], labels[i]])
				part.scale.set(FlxMath.lerp(part.scale.x, scale, Math.min(1, elapsed * 20)), FlxMath.lerp(part.scale.y, scale, Math.min(1, elapsed * 20)));
			labels[i].color = held ? FlxColor.BLACK : FlxColor.WHITE;
			labels[i].borderColor = held ? FlxColor.WHITE : FlxColor.BLACK;
		}
		while(presses.length > 0 && time - presses[0] > 1) presses.shift();
		var text:String = presses.length + ' KPS';
		if(kpsText.text != text) kpsText.text = text;
	}
}
