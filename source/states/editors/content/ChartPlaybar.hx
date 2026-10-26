package states.editors.content;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxGradient;
import flixel.util.FlxSpriteUtil;

/**
 * The bar at the bottom of the chart editor that works like a music player (V-Slice's chart editor "playbar"): where the song
 * is and how much of it is left, a slider to go anywhere in it, buttons to go to the start, back a section, play/pause, forward
 * a section and to the end, and the song's difficulty, BPM and note snap (the snap can be clicked: left more, right less).
 *
 * It only shows things and says what was done with it: the editor does the rest (see the callbacks).
 */
class ChartPlaybar extends FlxTypedGroup<FlxSprite>
{
	public static inline final BAR_HEIGHT:Int = 48;
	public static inline final SLIDER_HEIGHT:Int = 10;
	static inline final BUTTON_WIDTH:Int = 56;
	static inline final BUTTON_HEIGHT:Int = 32;
	static inline final BUTTON_GAP:Int = 6;

	static inline final BUTTON_COLOR:FlxColor = 0xFF2E2E2E;
	static inline final BUTTON_HOVER:FlxColor = 0xFF4A4A4A;
	static inline final BUTTON_DOWN:FlxColor = 0xFF6622BB;

	// What the editor answers
	/** Where the song is, in milliseconds. */
	public var getTime:Void->Float = null;
	/** How long the song is, in milliseconds. */
	public var getLength:Void->Float = null;
	public var isPlaying:Void->Bool = null;
	/** The song's beat and step where it is, its BPM there, the note snap (16 is 1/16) and the difficulty's name. */
	public var getStatus:Void->{beat:Float, step:Int, bpm:Float, snap:Int, difficulty:String} = null;

	// What it's told
	/** The slider was grabbed (the song is usually paused while it's dragged). */
	public var onDragStart:Void->Void = null;
	/** Go to this time of the song, in milliseconds (the slider being clicked or dragged). */
	public var onSeek:Float->Void = null;
	/** The slider was let go. */
	public var onDragEnd:Void->Void = null;
	/** "start", "back", "play", "forward", "end", "snapUp" or "snapDown". */
	public var onButton:String->Void = null;

	/** The first row of pixels that is the bar's, slider included: under it the editor shouldn't take clicks. */
	public var top(get, never):Float;
	function get_top():Float
		return trackBg.y - 6;

	public var dragging(default, null):Bool = false;

	var bg:FlxSprite;
	var trackBg:FlxSprite;
	var trackFill:FlxSprite;
	var head:FlxSprite;

	var timeText:FlxText;
	var beatText:FlxText;
	var stepText:FlxText;
	var leftRules:Array<FlxSprite> = [];

	var diffText:FlxText;
	var bpmText:FlxText;
	var snapText:FlxText;
	var remainingText:FlxText;
	var rightRules:Array<FlxSprite> = [];

	var buttons:Array<{name:String, bg:FlxSprite, icon:FlxSprite}> = [];
	var pauseIcon:FlxSprite;
	var pressedButton:String = null;

	public function new()
	{
		super();

		bg = new FlxSprite(0, FlxG.height - BAR_HEIGHT).makeGraphic(FlxG.width, BAR_HEIGHT, 0xFF141414);
		bg.alpha = 0.92;
		addPart(bg);

		var line:FlxSprite = new FlxSprite(0, bg.y).makeGraphic(FlxG.width, 1, 0xFF3A3A3A);
		addPart(line);

		// the slider, a little over the bar (where V-Slice has it)
		var trackY:Float = FlxG.height - BAR_HEIGHT - 8;
		trackBg = FlxGradient.createGradientFlxSprite(FlxG.width - 8, SLIDER_HEIGHT, [0xFF442277, 0xFF220055]);
		trackBg.setPosition(4, trackY);
		addPart(trackBg);

		trackFill = FlxGradient.createGradientFlxSprite(FlxG.width - 8, SLIDER_HEIGHT, [0xFF8844DD, 0xFF6622BB]);
		trackFill.setPosition(4, trackY);
		trackFill.origin.set(0, 0);
		trackFill.scale.x = 0;
		addPart(trackFill);

		head = new FlxSprite().makeGraphic(18, 18, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawCircle(head, 9, 9, 7, 0xFF8844DD, {thickness: 2, color: FlxColor.WHITE});
		head.y = trackY + SLIDER_HEIGHT / 2 - head.height / 2;
		addPart(head);

		// left: where it is
		var textY:Float = bg.y + 9;
		timeText = makeText(24, textY - 2);
		beatText = makeText(16, textY + 4);
		stepText = makeText(16, textY + 4);
		for (i in 0...2) leftRules.push(makeRule());

		// right: what's being charted, and how much is left
		diffText = makeText(16, textY + 4);
		bpmText = makeText(16, textY + 4);
		snapText = makeText(16, textY + 4);
		remainingText = makeText(24, textY - 2);
		for (i in 0...3) rightRules.push(makeRule());

		// middle: the buttons
		var names:Array<String> = ['start', 'back', 'play', 'forward', 'end'];
		var totalWidth:Float = names.length * BUTTON_WIDTH + (names.length - 1) * BUTTON_GAP;
		var x:Float = FlxG.width / 2 - totalWidth / 2;
		for (name in names)
		{
			var button:FlxSprite = new FlxSprite(x, bg.y + (BAR_HEIGHT - BUTTON_HEIGHT) / 2).makeGraphic(BUTTON_WIDTH, BUTTON_HEIGHT, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(button, 0, 0, BUTTON_WIDTH, BUTTON_HEIGHT, 10, 10, FlxColor.WHITE);
			button.color = BUTTON_COLOR;
			addPart(button);

			var icon:FlxSprite = makeIcon(name == 'play' ? 'play' : name);
			icon.setPosition(button.x + BUTTON_WIDTH / 2 - icon.width / 2, button.y + BUTTON_HEIGHT / 2 - icon.height / 2);
			addPart(icon);
			if(name == 'play')
			{
				pauseIcon = makeIcon('pause');
				pauseIcon.setPosition(icon.x, icon.y);
				pauseIcon.visible = false;
				addPart(pauseIcon);
			}
			buttons.push({name: name, bg: button, icon: icon});
			x += BUTTON_WIDTH + BUTTON_GAP;
		}
	}

	function addPart(sprite:FlxSprite):Void
	{
		sprite.scrollFactor.set();
		sprite.antialiasing = ClientPrefs.data.antialiasing;
		add(sprite);
	}

	function makeText(size:Int, y:Float):FlxText
	{
		var text:FlxText = new FlxText(0, y, 0, '', size);
		text.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		text.borderSize = 1;
		addPart(text);
		return text;
	}

	function makeRule():FlxSprite
	{
		var rule:FlxSprite = new FlxSprite(0, bg.y + BAR_HEIGHT * 0.15).makeGraphic(1, Std.int(BAR_HEIGHT * 0.7), 0x66FFFFFF);
		addPart(rule);
		return rule;
	}

	// The music player symbols, drawn in white (20x16)
	function makeIcon(name:String):FlxSprite
	{
		var icon:FlxSprite = new FlxSprite().makeGraphic(20, 16, FlxColor.TRANSPARENT, true);
		function triangle(points:Array<Float>)
			FlxSpriteUtil.drawPolygon(icon, [FlxPoint.weak(points[0], points[1]), FlxPoint.weak(points[2], points[3]), FlxPoint.weak(points[4], points[5])], FlxColor.WHITE);

		switch(name)
		{
			case 'play':
				triangle([5, 1, 17, 8, 5, 15]);
			case 'pause':
				FlxSpriteUtil.drawRect(icon, 4, 1, 4, 14, FlxColor.WHITE);
				FlxSpriteUtil.drawRect(icon, 12, 1, 4, 14, FlxColor.WHITE);
			case 'start':
				FlxSpriteUtil.drawRect(icon, 2, 1, 3, 14, FlxColor.WHITE);
				triangle([17, 1, 6, 8, 17, 15]);
			case 'end':
				triangle([3, 1, 14, 8, 3, 15]);
				FlxSpriteUtil.drawRect(icon, 15, 1, 3, 14, FlxColor.WHITE);
			case 'back':
				triangle([10, 1, 1, 8, 10, 15]);
				triangle([19, 1, 10, 8, 19, 15]);
			case 'forward':
				triangle([1, 1, 10, 8, 1, 15]);
				triangle([10, 1, 19, 8, 10, 15]);
		}
		return icon;
	}

	/**
	 * If the mouse is on the bar (or dragging its slider): the editor shouldn't do anything with it there.
	 */
	public function mouseOver():Bool
		return visible && (dragging || FlxG.mouse.screenY >= top);

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!visible) return;

		var length:Float = (getLength != null) ? getLength() : 0;
		var time:Float = (getTime != null) ? getTime() : 0;
		var mouseX:Float = FlxG.mouse.screenX;
		var mouseY:Float = FlxG.mouse.screenY;

		// The slider
		if(dragging)
		{
			if(FlxG.mouse.pressed)
			{
				time = timeAt(mouseX, length);
				if(onSeek != null) onSeek(time);
			}
			else
			{
				dragging = false;
				if(onDragEnd != null) onDragEnd();
			}
		}
		else if(FlxG.mouse.justPressed && length > 0 && mouseY >= top && mouseY < bg.y + 2)
		{
			dragging = true;
			if(onDragStart != null) onDragStart();
			time = timeAt(mouseX, length);
			if(onSeek != null) onSeek(time);
		}

		var progress:Float = (length > 0) ? FlxMath.bound(time / length, 0, 1) : 0;
		trackFill.scale.x = progress;
		head.x = trackBg.x + trackBg.width * progress - head.width / 2;
		head.scale.set(dragging ? 1.2 : 1, dragging ? 1.2 : 1);

		// The buttons: they do what they do when they're let go with the mouse still on them, like on a music player
		var playing:Bool = (isPlaying != null) && isPlaying();
		for (button in buttons)
		{
			var over:Bool = !dragging && FlxG.mouse.overlaps(button.bg, getCamera());
			if(over && FlxG.mouse.justPressed) pressedButton = button.name;

			if(pressedButton == button.name && FlxG.mouse.justReleased)
			{
				pressedButton = null;
				if(over && onButton != null) onButton(button.name);
			}
			button.bg.color = (pressedButton == button.name && over) ? BUTTON_DOWN : (over ? BUTTON_HOVER : BUTTON_COLOR);
			if(button.name == 'play')
			{
				button.icon.visible = !playing;
				pauseIcon.visible = playing;
			}
		}
		if(!FlxG.mouse.pressed) pressedButton = null;

		// The texts
		var status = (getStatus != null) ? getStatus() : null;
		setText(timeText, formatTime(time));
		setText(remainingText, '-' + formatTime(Math.max(length - time, 0)));
		if(status != null)
		{
			setText(beatText, 'Beat: ' + (Math.floor(status.beat * 100) / 100));
			setText(stepText, 'Step: ' + status.step);
			setText(diffText, status.difficulty);
			setText(bpmText, 'BPM: ' + (Math.round(status.bpm * 100) / 100));
			setText(snapText, '1/' + status.snap);
		}

		// the snap: left click for more, right click for less
		var overSnap:Bool = !dragging && FlxG.mouse.overlaps(snapText, getCamera());
		snapText.color = overSnap ? 0xFFFFDD55 : FlxColor.WHITE;
		if(overSnap && onButton != null)
		{
			if(FlxG.mouse.justPressed) onButton('snapUp');
			else if(FlxG.mouse.justPressedRight) onButton('snapDown');
		}

		layoutTexts();
	}

	function getCamera():FlxCamera
		return (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;

	function timeAt(mouseX:Float, length:Float):Float
		return FlxMath.bound((mouseX - trackBg.x) / trackBg.width, 0, 1) * length;

	function setText(text:FlxText, value:String):Void
	{
		if(text.text != value) text.text = value;
	}

	// The texts of each side, one after the other with a line between them (their widths change with what they say)
	function layoutTexts():Void
	{
		var x:Float = 12;
		for (num => text in [timeText, beatText, stepText])
		{
			text.x = x;
			x += text.width + 10;
			if(num < leftRules.length)
			{
				leftRules[num].x = x;
				x += 11;
			}
		}

		x = FlxG.width - 12;
		for (num => text in [remainingText, snapText, bpmText, diffText])
		{
			x -= text.width;
			text.x = x;
			x -= 10;
			if(num < rightRules.length)
			{
				rightRules[num].x = x;
				x -= 11;
			}
		}
	}

	// "01:32.45", minutes, seconds and hundredths
	public static function formatTime(ms:Float):String
	{
		var negative:Bool = ms < 0;
		ms = Math.abs(ms);
		var minutes:Int = Math.floor(ms / 60000);
		var seconds:Int = Math.floor(ms / 1000) % 60;
		var hundredths:Int = Math.floor(ms / 10) % 100;
		return (negative ? '-' : '') + StringTools.lpad('$minutes', '0', 2) + ':' + StringTools.lpad('$seconds', '0', 2) + '.' + StringTools.lpad('$hundredths', '0', 2);
	}
}
