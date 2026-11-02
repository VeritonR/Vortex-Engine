package backend;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.math.FlxRect;
import flixel.FlxSubState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import haxe.Json;

typedef TutorialStep = {
	var text:String;
	/** What's shown: a path to an object of the screen ("mainBox", "mainBox.tabs.Note", "menuItems.members.2"), or several. */
	@:optional var target:Dynamic;
	/** Or a place of the screen: [x, y, width, height]. */
	@:optional var rect:Array<Float>;
	/** A part of the target: [x, y, width, height] from its top left corner. */
	@:optional var area:Array<Float>;
	/** The whole height of the screen, at the target's place (a column of the chart editor's grid). */
	@:optional var tall:Null<Bool>;
	/** How close it goes (2 if not given; it never goes further than what fits). */
	@:optional var zoom:Null<Float>;
	/** Changed when the step is shown, and put back when the tutorial ends: {"mainBox.selectedName": "Note"}. */
	@:optional var set:Dynamic;
	/** "hey", "left", "down", "up", "right", "idle" (by default he looks towards what's shown). */
	@:optional var pose:String;
}

typedef TutorialFile = {
	@:optional var button:Dynamic;
	/** The start of the keys that translate the steps ("<key>_1", "<key>_2"...). The game's own tutorials use "tutorial_<screen>". */
	@:optional var key:String;
	var steps:Array<TutorialStep>;
}

/**
 * The tutorials: on a screen that has one ("data/tutorials/<the screen's class>.json", in the game or a mod), a "Tutorial" button
 * (and the tutorial key, see the Controls menu) has Boyfriend explain it step by step, going close to each thing he talks about.
 *
 * The screen stops while it runs (a substate is opened on it) and the whole game is zoomed in (FlxG.game), so everything is shown as
 * it is: the tutorial itself is drawn over the game, like the chat.
 *
 * A step's text is translated with the key "tutorial_<screen>_<number>" (its number from 1), the text in the file being the English one.
 */
@:access(flixel.FlxSubState)
@:access(flixel.FlxState)
class Tutorial extends Sprite
{
	public static var instance(default, null):Tutorial;
	public static var running(default, null):Bool = false;

	static inline var FOLDER:String = 'data/tutorials/';
	static inline var MASCOT_SCALE:Float = 0.5;
	static inline var BUBBLE_WIDTH:Float = 470;
	static inline var SIDE_ROOM:Float = 500; //(where Boyfriend and his bubble are, by the side of the screen)
	static inline var ZOOM_TIME:Float = 0.55;
	static inline var LETTERS_PER_SECOND:Float = 55;

	// what the screens have (by their class), found again on every screen change: null when it doesn't have one
	static var found:Map<String, String> = new Map();

	var layer:Sprite; //(laid out in the game's size, scaled to the window like the game)
	var button:Sprite;
	var buttonText:TextField;
	var buttonHover:Bool = false;
	var area:FlxState; //(the screen the button is for)
	var areaName:String;
	var areaFile:String;

	// The tutorial
	var blocker:Sprite;
	var dim:Shape;
	var frame:Shape;
	var mascot:Shape;
	var bubble:Sprite;
	var bubbleText:TextField;
	var hintText:TextField;
	var countText:TextField;
	var steps:Array<TutorialStep> = [];
	var step:Int = 0;
	var textKey:String = null;
	var pause:FlxSubState;
	var pauseParent:FlxState; //(the screen the pause was opened on)
	var undo:Array<{object:Dynamic, field:String, value:Dynamic}> = [];
	var oldSystemCursor:Bool = false;
	var oldMouseVisible:Bool = false;
	var oldPersistentUpdate:Bool = false;

	var shownText:String = '';
	var typed:Float = 0;
	var lastBlip:Int = 0;

	// the zoom: the game is shown at `zoom`, moved by (`moveX`, `moveY`), going from the last ones to the step's
	var zoom:Float = 1;
	var moveX:Float = 0;
	var moveY:Float = 0;
	var fromZoom:Float = 1;
	var fromX:Float = 0;
	var fromY:Float = 0;
	var toZoom:Float = 1;
	var toX:Float = 0;
	var toY:Float = 0;
	var zoomTime:Float = 1;
	var mascotRight:Bool = true;
	var hole:{x:Float, y:Float, width:Float, height:Float} = null;
	var pulse:Float = 0;
	// (what was drawn last: the shapes are only drawn again when it changes)
	var drawnDim:String = null;
	var drawnBubble:String = null;
	var drawnFrame:FlxFrame = null;
	var drawnFlip:Bool = false;
	var textHeight:Float = 0;

	// Boyfriend
	static var atlas:FlxAtlasFrames;
	var animFrames:Array<FlxFrame> = [];
	var animOffset:Array<Float> = [0, 0];
	var animFrame:Float = 0;
	var animName:String = '';
	var animHold:Float = 0;

	static final ANIMS:Map<String, {prefix:String, offset:Array<Float>}> = [
		'idle' => {prefix: 'BF idle dance', offset: [-5, 0]},
		'left' => {prefix: 'BF NOTE LEFT', offset: [5, -6]},
		'down' => {prefix: 'BF NOTE DOWN', offset: [-20, -51]},
		'up' => {prefix: 'BF NOTE UP', offset: [-46, 27]},
		'right' => {prefix: 'BF NOTE RIGHT', offset: [-48, -7]},
		'hey' => {prefix: 'BF HEY!!', offset: [-3, 5]}
	];

	var lastTime:Float = 0;

	public static function init():Void
	{
		if(instance != null || FlxG.stage == null) return;
		instance = new Tutorial();
		FlxG.stage.addChild(instance);
		FlxG.signals.preStateSwitch.add(function() {
			found.clear();
			if(running) instance.stop();
		});
	}

	public function new()
	{
		super();
		layer = new Sprite();
		addChild(layer);

		blocker = new Sprite();
		blocker.graphics.beginFill(0, 0);
		blocker.graphics.drawRect(0, 0, FlxG.width, FlxG.height);
		blocker.graphics.endFill();
		blocker.visible = false;
		blocker.addEventListener(MouseEvent.MOUSE_DOWN, function(event:MouseEvent) {
			event.stopPropagation();
			if(running) next();
		});
		layer.addChild(blocker);

		dim = new Shape();
		dim.visible = false;
		layer.addChild(dim);
		frame = new Shape();
		frame.visible = false;
		layer.addChild(frame);
		mascot = new Shape();
		mascot.visible = false;
		layer.addChild(mascot);

		bubble = new Sprite();
		bubble.visible = false;
		bubble.mouseChildren = false;
		bubbleText = makeField(21, 0x101010);
		bubbleText.width = BUBBLE_WIDTH - 40;
		bubbleText.autoSize = LEFT; //(as tall as its lines, with the width kept)
		bubbleText.x = 20;
		bubbleText.y = 16;
		bubble.addChild(bubbleText);
		hintText = makeField(12, 0x6A5A80);
		hintText.wordWrap = false;
		hintText.width = BUBBLE_WIDTH - 85;
		hintText.x = 20;
		bubble.addChild(hintText);
		countText = makeField(14, 0x6A5A80);
		countText.width = 50;
		countText.x = BUBBLE_WIDTH - 65;
		var format = countText.defaultTextFormat;
		format.align = TextFormatAlign.RIGHT;
		countText.defaultTextFormat = format;
		bubble.addChild(countText);
		layer.addChild(bubble);

		button = new Sprite();
		button.buttonMode = true;
		button.mouseChildren = false;
		buttonText = makeField(18, 0xFFFFFF);
		buttonText.autoSize = LEFT;
		buttonText.wordWrap = false;
		buttonText.x = 12;
		buttonText.y = 4;
		button.addChild(buttonText);
		button.visible = false;
		button.addEventListener(MouseEvent.MOUSE_DOWN, function(event:MouseEvent) {
			event.stopPropagation(); //(the screen under it doesn't get the click)
			if(!running && area != null) start();
		});
		button.addEventListener(MouseEvent.MOUSE_OVER, function(_) buttonHover = true);
		button.addEventListener(MouseEvent.MOUSE_OUT, function(_) buttonHover = false);
		layer.addChild(button);

		addEventListener(Event.ENTER_FRAME, onFrame);
		lastTime = haxe.Timer.stamp();
	}

	function makeField(size:Int, color:Int):TextField
	{
		var field:TextField = new TextField();
		field.selectable = false;
		field.mouseEnabled = false;
		field.multiline = true;
		field.wordWrap = true;
		field.embedFonts = true;
		var font:String = '_sans';
		try
		{
			var loaded = openfl.utils.Assets.getFont(Paths.font('vcr.ttf'));
			if(loaded != null) font = loaded.fontName;
		}
		catch(e:Dynamic) {}
		if(font == '_sans') field.embedFonts = false;
		field.defaultTextFormat = new TextFormat(font, size, color);
		return field;
	}

	// ------------------------------------------------------------------------------------------
	// Every frame
	// ------------------------------------------------------------------------------------------

	function onFrame(_):Void
	{
		var now:Float = haxe.Timer.stamp();
		var elapsed:Float = Math.min(now - lastTime, 0.1);
		lastTime = now;
		if(FlxG.game == null || FlxG.scaleMode == null) return;

		// laid out in the game's size, where the game is in the window
		layer.x = FlxG.scaleMode.offset.x;
		layer.y = FlxG.scaleMode.offset.y;
		layer.scaleX = FlxG.scaleMode.scale.x;
		layer.scaleY = FlxG.scaleMode.scale.y;

		if(running) updateTutorial(elapsed);
		else updateButton();
	}

	function updateButton():Void
	{
		var screen:FlxState = deepest();
		if(screen != area)
		{
			area = screen;
			areaName = (screen != null) ? Type.getClassName(Type.getClass(screen)).split('.').pop() : null;
			areaFile = fileOf(areaName);
			placeButton();
		}

		var show:Bool = areaFile != null && ClientPrefs.data.tutorialButton && !OnlineChat.typing;
		button.visible = show;
		if(show) button.alpha = buttonHover ? 1 : 0.7;

		// (the key works even with the button hidden, but not while something is being typed)
		if(areaFile != null && FlxG.keys != null && FlxG.keys.enabled && backend.ui.PsychUIInputText.focusOn == null && !OnlineChat.typing
			&& FlxG.keys.anyJustPressed(ClientPrefs.keyBinds.get('tutorial')))
			start();
	}

	// The screen being used: the last substate opened, or the state
	static function deepest():FlxState
	{
		var screen:FlxState = FlxG.state;
		while(screen != null && screen.subState != null) screen = screen.subState;
		return screen;
	}

	// The tutorial of a screen (a mod's first), or null
	static function fileOf(name:String):String
	{
		if(name == null) return null;
		if(found.exists(name)) return found.get(name);
		var path:String = null;
		#if MODS_ALLOWED
		var modded:String = Paths.modFolders(FOLDER + name + '.json');
		if(sys.FileSystem.exists(modded)) path = modded;
		#end
		if(path == null)
		{
			var shared:String = Paths.getSharedPath(FOLDER + name + '.json');
			#if sys
			if(sys.FileSystem.exists(shared)) path = shared;
			#else
			if(openfl.utils.Assets.exists(shared)) path = shared;
			#end
		}
		found.set(name, path);
		return path;
	}

	static function readFile(path:String):TutorialFile
	{
		try
		{
			#if sys
			var data:TutorialFile = cast Json.parse(sys.io.File.getContent(path));
			#else
			var data:TutorialFile = cast Json.parse(openfl.utils.Assets.getText(path));
			#end
			if(data != null && data.steps != null && data.steps.length > 0) return data;
		}
		catch(e:Dynamic)
		{
			trace('Tutorial: "$path" could not be read ($e)');
		}
		return null;
	}

	function placeButton():Void
	{
		buttonText.text = '? ' + Language.getPhrase('tutorial_button', 'Tutorial');
		var width:Float = buttonText.textWidth + 28;
		var height:Float = 30;
		button.graphics.clear();
		button.graphics.lineStyle(2, 0xFF5FB4, 1);
		button.graphics.beginFill(0x1C0A30, 0.92);
		button.graphics.drawRoundRect(0, 0, width, height, 14, 14);
		button.graphics.endFill();

		var where:Dynamic = 'top-right';
		if(areaFile != null)
		{
			var data:TutorialFile = readFile(areaFile);
			if(data == null) areaFile = null;
			else if(data.button != null) where = data.button;
		}
		if(Std.isOfType(where, Array))
		{
			var place:Array<Float> = where;
			button.x = place[0];
			button.y = place[1];
			return;
		}
		var corner:String = Std.string(where);
		button.x = corner.endsWith('left') ? 10 : corner.endsWith('center') ? (FlxG.width - width) / 2 : FlxG.width - width - 10;
		button.y = corner.startsWith('bottom') ? FlxG.height - height - 6 : 6;
	}

	// ------------------------------------------------------------------------------------------
	// The tutorial
	// ------------------------------------------------------------------------------------------

	/**
	 * Starts the tutorial of the screen being used, if it has one.
	 */
	public function start():Void
	{
		if(running) return;
		var screen:FlxState = deepest();
		var name:String = (screen != null) ? Type.getClassName(Type.getClass(screen)).split('.').pop() : null;
		var path:String = fileOf(name);
		var data:TutorialFile = (path != null) ? readFile(path) : null;
		if(data == null) return;

		area = screen;
		areaName = name;
		steps = data.steps;
		step = -1;
		// (a mod's tutorial isn't translated by the game's keys for the same screen: only by its own, if it says which)
		textKey = data.key;
		if(textKey == null && !path.startsWith('mods')) textKey = 'tutorial_' + name.toLowerCase();
		undo = [];
		running = true;
		button.visible = false;

		// the screen stops while it's explained
		pause = new FlxSubState();
		pause.bgColor = 0;
		// (some screens go on under their substates: not this time, or the keys of the tutorial would work on them too)
		oldPersistentUpdate = screen.persistentUpdate;
		screen.persistentUpdate = false;
		pauseParent = screen;
		screen.openSubState(pause);

		oldSystemCursor = FlxG.mouse.useSystemCursor;
		oldMouseVisible = FlxG.mouse.visible;
		FlxG.mouse.useSystemCursor = true; //(the game's own cursor would be zoomed in with it)
		FlxG.mouse.visible = true;

		if(atlas == null) atlas = Paths.getSparrowAtlas('characters/BOYFRIEND');
		zoom = fromZoom = toZoom = 1;
		moveX = moveY = fromX = fromY = toX = toY = 0;

		blocker.visible = dim.visible = frame.visible = mascot.visible = bubble.visible = true;
		drawnDim = drawnBubble = null;
		drawnFrame = null;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		go(0);
	}

	/**
	 * Ends the tutorial: the game as it was, and the screen going on.
	 */
	public function stop():Void
	{
		if(!running) return;
		running = false;

		// what the steps changed, back as it was (the last change first)
		var i:Int = undo.length;
		while(--i >= 0)
		{
			try Reflect.setProperty(undo[i].object, undo[i].field, undo[i].value) catch(e:Dynamic) {}
			if(Std.isOfType(undo[i].object, backend.ui.PsychUIBox)) paintTabs(undo[i].object);
		}
		undo = [];

		if(FlxG.game != null)
		{
			FlxG.game.scaleX = FlxG.game.scaleY = 1;
			FlxG.game.x = FlxG.scaleMode.offset.x;
			FlxG.game.y = FlxG.scaleMode.offset.y;
		}
		if(pauseParent != null)
		{
			pauseParent.persistentUpdate = oldPersistentUpdate;
			// (asked for and not open yet, which takes until the screen's next update: it doesn't open anymore)
			if(pauseParent._requestedSubState == pause) pauseParent._requestedSubState = null;
			else if(pause != null && pause._parentState != null) pause.close();
		}
		pause = null;
		pauseParent = null;
		// (the key that ended it doesn't go on to the screen: ESC would leave it, ENTER would pick something)
		if(FlxG.keys != null) FlxG.keys.reset();
		FlxG.mouse.useSystemCursor = oldSystemCursor;
		FlxG.mouse.visible = oldMouseVisible;

		blocker.visible = dim.visible = frame.visible = mascot.visible = bubble.visible = false;
		area = null; //(the button looks at the screen again)
	}

	// The colors of a box's tabs, which it only redoes when it updates (and the screen is stopped)
	static function paintTabs(box:backend.ui.PsychUIBox):Void
	{
		for (tab in box.tabs)
		{
			var style = (tab == box.selectedTab) ? box.selectedStyle : box.unselectedStyle;
			tab.color = style.bgColor;
			tab.alpha = style.bgAlpha;
			tab.text.color = style.textColor;
		}
	}

	function next():Void
	{
		// (the text appears all at once first)
		if(typed < shownText.length)
		{
			typed = shownText.length;
			return;
		}
		if(step + 1 >= steps.length)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
			stop();
		}
		else go(step + 1);
	}

	function go(index:Int):Void
	{
		if(index < 0 || index >= steps.length) return;
		var forward:Bool = index > step;
		step = index;
		var data:TutorialStep = steps[step];

		if(data.set != null)
		{
			for (path in Reflect.fields(data.set))
			{
				var place = resolveField(path);
				if(place == null) continue;
				try
				{
					undo.push({object: place.object, field: place.field, value: Reflect.getProperty(place.object, place.field)});
					Reflect.setProperty(place.object, place.field, Reflect.field(data.set, path));
					if(Std.isOfType(place.object, backend.ui.PsychUIBox)) paintTabs(place.object);
				}
				catch(e:Dynamic) trace('Tutorial: "$path" could not be changed ($e)');
			}
		}

		var english:String = (data.text != null) ? data.text : '';
		shownText = (textKey != null) ? Language.getPhrase('${textKey}_${step + 1}', english) : english;
		typed = 0;
		lastBlip = 0;
		// (the bubble is as tall as the whole text, so it doesn't grow while it's typed)
		bubbleText.text = shownText;
		textHeight = bubbleText.textHeight + 6;
		bubbleText.text = '';
		hintText.text = Language.getPhrase('tutorial_hint', 'ENTER/Click: next  BACKSPACE: back  ESC: leave');
		countText.text = (step + 1) + '/' + steps.length;
		drawnDim = null;

		var target = targetRect(data);
		var center:Float = (target != null) ? target.x + target.width / 2 : FlxG.width;
		mascotRight = center < FlxG.width / 2 || target == null;
		aimAt(target, (data.zoom != null) ? data.zoom : 2);

		var pose:String = data.pose;
		if(pose == null) pose = (target == null) ? 'hey' : poseTowards(target);
		play(pose);
		if(index > 0) FlxG.sound.play(Paths.sound('scrollMenu'), forward ? 0.5 : 0.35);
	}

	// Where the game goes for the step: the target as close as it can, in the part of the screen that Boyfriend leaves free
	function aimAt(target:{x:Float, y:Float, width:Float, height:Float}, wanted:Float):Void
	{
		fromZoom = zoom;
		fromX = moveX;
		fromY = moveY;
		zoomTime = 0;
		hole = target;
		if(target == null)
		{
			toZoom = 1;
			toX = toY = 0;
			return;
		}

		var freeWidth:Float = FlxG.width - SIDE_ROOM - 20;
		var freeHeight:Float = FlxG.height - 60;
		var size:Float = Math.min(wanted, Math.min(freeWidth / Math.max(target.width, 1), freeHeight / Math.max(target.height, 1)));
		toZoom = Math.max(1, size);

		var focusX:Float = mascotRight ? freeWidth / 2 + 10 : SIDE_ROOM + 10 + freeWidth / 2;
		var focusY:Float = FlxG.height / 2;
		var centerX:Float = target.x + target.width / 2;
		var centerY:Float = target.y + target.height / 2;
		// (the game always covers the screen: no black borders)
		toX = FlxMath.bound(focusX - toZoom * centerX, FlxG.width - toZoom * FlxG.width, 0);
		toY = FlxMath.bound(focusY - toZoom * centerY, FlxG.height - toZoom * FlxG.height, 0);
	}

	function updateTutorial(elapsed:Float):Void
	{
		// the screen went away (a state change, the connection lost...); a pause still opening is waited for (a click on the button
		// starts the tutorial before the screen's update, which is when it opens)
		var opening:Bool = pause != null && pause._parentState == null && pauseParent != null && pauseParent._requestedSubState == pause;
		if(!opening && (pause == null || pause._parentState == null || FlxG.state == null))
		{
			stop();
			return;
		}

		// keys
		if(FlxG.keys != null)
		{
			if(FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
				stop();
				return;
			}
			if(FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || FlxG.keys.justPressed.RIGHT) next();
			else if((FlxG.keys.justPressed.BACKSPACE || FlxG.keys.justPressed.LEFT) && step > 0) go(step - 1);
		}
		if(!running) return;

		// the zoom
		zoomTime = Math.min(1, zoomTime + elapsed / ZOOM_TIME);
		var t:Float = FlxEase.cubeInOut(zoomTime);
		zoom = FlxMath.lerp(fromZoom, toZoom, t);
		moveX = FlxMath.lerp(fromX, toX, t);
		moveY = FlxMath.lerp(fromY, toY, t);
		var scale = FlxG.scaleMode.scale;
		var offset = FlxG.scaleMode.offset;
		FlxG.game.scaleX = FlxG.game.scaleY = zoom;
		FlxG.game.x = offset.x + scale.x * moveX;
		FlxG.game.y = offset.y + scale.y * moveY;

		// (the target is found again: what's shown may have moved when the step changed something)
		var data:TutorialStep = steps[step];
		var target = (data != null) ? targetRect(data) : null;
		if(target != null && hole != null && zoomTime >= 1) hole = target;
		drawDim(elapsed);

		updateMascot(elapsed);
		updateBubble(elapsed);
	}

	function drawDim(elapsed:Float):Void
	{
		var width:Float = FlxG.width;
		var height:Float = FlxG.height;
		var darkness:Float = 0.55;
		var showHole:Bool = hole != null && zoomTime >= 1;
		pulse += elapsed;
		frame.alpha = 0.6 + 0.4 * Math.sin(pulse * 5);
		var key:String = showHole ? '${Math.round(moveX)},${Math.round(moveY)},${Math.round(zoom * 100)},${Math.round(hole.x)},${Math.round(hole.y)},${Math.round(hole.width)},${Math.round(hole.height)}'
			: (hole != null ? 'dark' : 'light');
		if(key == drawnDim) return;
		drawnDim = key;

		dim.graphics.clear();
		frame.graphics.clear();
		if(showHole)
		{
			// (the dark around where the target is now: four pieces, the graphics card doesn't cut holes)
			var pad:Float = 6;
			var x:Float = moveX + zoom * (hole.x - pad);
			var y:Float = moveY + zoom * (hole.y - pad);
			var w:Float = zoom * (hole.width + pad * 2);
			var h:Float = zoom * (hole.height + pad * 2);
			var left:Float = Math.max(0, x);
			var top:Float = Math.max(0, y);
			var right:Float = Math.min(width, x + w);
			var bottom:Float = Math.min(height, y + h);
			dim.graphics.beginFill(0x000000, darkness);
			if(top > 0) dim.graphics.drawRect(0, 0, width, top);
			if(bottom < height) dim.graphics.drawRect(0, bottom, width, height - bottom);
			if(left > 0) dim.graphics.drawRect(0, top, left, bottom - top);
			if(right < width) dim.graphics.drawRect(right, top, width - right, bottom - top);
			dim.graphics.endFill();

			frame.graphics.lineStyle(4, 0xFF5FB4, 1);
			frame.graphics.drawRoundRect(x - 2, y - 2, w + 4, h + 4, 12, 12);
		}
		else
		{
			dim.graphics.beginFill(0x000000, darkness * ((hole != null) ? 1 : 0.6));
			dim.graphics.drawRect(0, 0, width, height);
			dim.graphics.endFill();
		}
	}

	// ------------------------------------------------------------------------------------------
	// Boyfriend and what he says
	// ------------------------------------------------------------------------------------------

	function play(name:String):Void
	{
		var anim = ANIMS.get(name);
		if(anim == null) anim = ANIMS.get('idle');
		if(atlas == null) return;
		var pattern:EReg = new EReg('^' + escape(anim.prefix) + '\\d+$', '');
		animFrames = [for (frame in atlas.frames) if(frame.name != null && pattern.match(frame.name)) frame];
		animFrames.sort(function(a, b) return Reflect.compare(a.name, b.name));
		animOffset = anim.offset;
		animFrame = 0;
		animName = name;
		animHold = 0;
	}

	static function escape(text:String):String
	{
		var out:StringBuf = new StringBuf();
		for (i in 0...text.length)
		{
			var char:String = text.charAt(i);
			if('\\^$.|?*+()[]{}'.indexOf(char) > -1) out.add('\\');
			out.add(char);
		}
		return out.toString();
	}

	// Where he looks: towards the middle of what he's showing
	function poseTowards(target:{x:Float, y:Float, width:Float, height:Float}):String
	{
		var headX:Float = mascotRight ? FlxG.width - 130 : 130;
		var headY:Float = FlxG.height - 170;
		var dx:Float = zoomedX(target.x + target.width / 2) - headX;
		var dy:Float = zoomedY(target.y + target.height / 2) - headY;
		if(-dy > Math.abs(dx) * 0.8) return 'up';
		// (the drawings face left: turned around, "left" points to the right)
		var right:Bool = dx > 0;
		if(!mascotRight) return right ? 'left' : 'right';
		return right ? 'right' : 'left';
	}

	inline function zoomedX(x:Float):Float return toX + toZoom * x;
	inline function zoomedY(y:Float):Float return toY + toZoom * y;

	function updateMascot(elapsed:Float):Void
	{
		if(animFrames.length < 1) return;
		var index:Int = Std.int(animFrame);
		if(index >= animFrames.length)
		{
			if(animName == 'idle') animFrame = index = 0;
			else
			{
				// (a pose stays a moment, then back to dancing)
				index = animFrames.length - 1;
				animHold += elapsed;
				if(animHold > 0.8) play('idle');
				index = Std.int(Math.min(Std.int(animFrame), animFrames.length - 1));
			}
		}
		else animFrame += elapsed * 24;
		if(index >= animFrames.length) index = animFrames.length - 1;
		drawFrame(animFrames[index]);
	}

	function drawFrame(frame:FlxFrame):Void
	{
		if(frame == drawnFrame && drawnFlip == mascotRight) return;
		drawnFrame = frame;
		drawnFlip = mascotRight;
		var scale:Float = MASCOT_SCALE;
		var left:Float = (frame.offset.x - animOffset[0]) * scale;
		var top:Float = (frame.offset.y - animOffset[1]) * scale;
		var width:Float = frame.frame.width * scale;
		var height:Float = frame.frame.height * scale;
		var matrix:Matrix = new Matrix();
		matrix.scale(scale, scale);
		matrix.translate(left - frame.frame.x * scale, top - frame.frame.y * scale);

		mascot.graphics.clear();
		mascot.graphics.beginBitmapFill(frame.parent.bitmap, matrix, false, true);
		mascot.graphics.drawRect(left, top, width, height);
		mascot.graphics.endFill();

		var size:Float = 415 * scale;
		mascot.y = FlxG.height - 418 * scale + 6;
		if(mascotRight)
		{
			mascot.scaleX = 1;
			mascot.x = FlxG.width - size - 10;
		}
		else
		{
			mascot.scaleX = -1; //(facing the screen)
			mascot.x = size + 10;
		}
	}

	function updateBubble(elapsed:Float):Void
	{
		if(typed < shownText.length)
		{
			typed = Math.min(shownText.length, typed + elapsed * LETTERS_PER_SECOND);
			var letters:Int = Std.int(typed);
			if(letters - lastBlip >= 3)
			{
				lastBlip = letters;
				FlxG.sound.play(Paths.sound('dialogue'), 0.25);
			}
		}
		var text:String = shownText.substr(0, Std.int(typed));
		if(bubbleText.text != text) bubbleText.text = text;

		var height:Float = 16 + textHeight + 14 + 20 + 12;
		hintText.y = height - 34;
		countText.y = hintText.y;
		var x:Float = mascotRight ? FlxG.width - BUBBLE_WIDTH - 20 : 20;
		var y:Float = FlxG.height - 418 * MASCOT_SCALE - height - 6;
		bubble.x = x;
		bubble.y = Math.max(10, y);

		var key:String = '$height,$mascotRight';
		if(key == drawnBubble) return;
		drawnBubble = key;
		var g = bubble.graphics;
		g.clear();
		g.lineStyle(3, 0x1C0A30, 1);
		g.beginFill(0xFFFFFF, 0.97);
		g.drawRoundRect(0, 0, BUBBLE_WIDTH, height, 26, 26);
		g.endFill();
		// the tail, towards his head
		var tailX:Float = mascotRight ? BUBBLE_WIDTH - 150 : 150;
		g.lineStyle(3, 0x1C0A30, 1);
		g.beginFill(0xFFFFFF, 0.97);
		g.moveTo(tailX - 18, height - 2);
		g.lineTo(tailX + (mascotRight ? 30 : -30), height + 26);
		g.lineTo(tailX + 18, height - 2);
		g.endFill();
		// (the line under the tail's top, covered)
		g.lineStyle();
		g.beginFill(0xFFFFFF, 1);
		g.drawRect(tailX - 16, height - 5, 32, 5);
		g.endFill();
	}

	// ------------------------------------------------------------------------------------------
	// Finding things on the screen
	// ------------------------------------------------------------------------------------------

	// What a step shows, in the game's coordinates (1280x720), or null
	function targetRect(data:TutorialStep):{x:Float, y:Float, width:Float, height:Float}
	{
		if(data.rect != null && data.rect.length > 3)
			return {x: data.rect[0], y: data.rect[1], width: data.rect[2], height: data.rect[3]};
		if(data.target == null) return null;

		var paths:Array<String> = Std.isOfType(data.target, Array) ? [for (path in (data.target:Array<Dynamic>)) Std.string(path)] : [Std.string(data.target)];
		var result:{x:Float, y:Float, width:Float, height:Float} = null;
		for (path in paths)
		{
			var rect = null;
			try rect = boundsOf(findPath(path)) catch(e:Dynamic) {} //(something destroyed, or not really on the screen)
			if(rect == null) continue;
			if(result == null) result = rect;
			else
			{
				var right:Float = Math.max(result.x + result.width, rect.x + rect.width);
				var bottom:Float = Math.max(result.y + result.height, rect.y + rect.height);
				result.x = Math.min(result.x, rect.x);
				result.y = Math.min(result.y, rect.y);
				result.width = right - result.x;
				result.height = bottom - result.y;
			}
		}
		if(result != null && data.area != null && data.area.length > 3)
			result = {x: result.x + data.area[0], y: result.y + data.area[1], width: data.area[2], height: data.area[3]};
		if(result == null) return null;
		if(data.tall == true)
		{
			result.y = 0;
			result.height = FlxG.height;
		}
		// (only what's on the screen: a grid can go far beyond it)
		var left:Float = FlxMath.bound(result.x, 0, FlxG.width);
		var top:Float = FlxMath.bound(result.y, 0, FlxG.height);
		var right:Float = FlxMath.bound(result.x + result.width, 0, FlxG.width);
		var bottom:Float = FlxMath.bound(result.y + result.height, 0, FlxG.height);
		if(right - left < 2 || bottom - top < 2) return null;
		return {x: left, y: top, width: right - left, height: bottom - top};
	}

	// "mainBox.tabs.Note": fields, numbers (a list's or a group's) and names (the one of a list called that)
	function findPath(path:String):Dynamic
	{
		var current:Dynamic = area;
		for (part in path.split('.'))
		{
			if(current == null) return null;
			current = child(current, part);
		}
		// (not on the screen: maybe on the state under it)
		if(current == null && area != FlxG.state && FlxG.state != null)
		{
			current = FlxG.state;
			for (part in path.split('.'))
			{
				if(current == null) return null;
				current = child(current, part);
			}
		}
		return current;
	}

	static function child(parent:Dynamic, part:String):Dynamic
	{
		var list:Array<Dynamic> = null;
		if(Std.isOfType(parent, Array)) list = parent;
		else if(Std.isOfType(parent, FlxTypedGroup)) list = (parent:FlxTypedGroup<Dynamic>).members;

		var number:Null<Int> = Std.parseInt(part);
		if(list != null && number != null) return (number >= 0 && number < list.length) ? list[number] : null;

		var value:Dynamic = null;
		try value = Reflect.getProperty(parent, part) catch(e:Dynamic) {}
		if(value != null) return value;

		if(list != null)
			for (item in list)
				if(item != null && Reflect.getProperty(item, 'name') == part) return item;
		return null;
	}

	// For "set": the object and the field the last part names
	function resolveField(path:String):{object:Dynamic, field:String}
	{
		var dot:Int = path.lastIndexOf('.');
		if(dot < 0) return {object: area, field: path};
		var object:Dynamic = findPath(path.substr(0, dot));
		return (object != null) ? {object: object, field: path.substr(dot + 1)} : null;
	}

	// Where it is on the screen (with its camera's zoom and position)
	static function boundsOf(thing:Dynamic):{x:Float, y:Float, width:Float, height:Float}
	{
		if(thing == null) return null;
		if(Std.isOfType(thing, FlxObject))
		{
			var object:FlxObject = thing;
			if(!object.visible || !object.exists) return null;
			var camera:FlxCamera = (object.cameras != null && object.cameras.length > 0) ? object.cameras[0] : FlxG.camera;
			if(camera == null) return null;
			var rect:FlxRect;
			// (a group of sprites can't measure itself that way: flixel doesn't make what it needs for it)
			if(Std.isOfType(object, FlxSprite) && !Std.isOfType(object, flixel.group.FlxSpriteGroup)) rect = cast(object, FlxSprite).getScreenBounds(null, camera);
			else
			{
				var point = object.getScreenPosition(null, camera);
				rect = FlxRect.get(point.x, point.y, object.width, object.height);
				point.put();
			}
			var x:Float = camera.x + (rect.x - camera.width / 2) * camera.zoom + camera.width / 2;
			var y:Float = camera.y + (rect.y - camera.height / 2) * camera.zoom + camera.height / 2;
			var result = {x: x, y: y, width: rect.width * camera.zoom, height: rect.height * camera.zoom};
			rect.put();
			return result;
		}
		var list:Array<Dynamic> = null;
		if(Std.isOfType(thing, FlxTypedGroup)) list = (thing:FlxTypedGroup<Dynamic>).members;
		else if(Std.isOfType(thing, Array)) list = thing;
		if(list != null)
		{
			var result:{x:Float, y:Float, width:Float, height:Float} = null;
			for (member in list)
			{
				if(member == null || !Std.isOfType(member, FlxBasic) || !(member:FlxBasic).visible) continue;
				var rect = boundsOf(member);
				if(rect == null) continue;
				if(result == null) result = rect;
				else
				{
					var right:Float = Math.max(result.x + result.width, rect.x + rect.width);
					var bottom:Float = Math.max(result.y + result.height, rect.y + rect.height);
					result.x = Math.min(result.x, rect.x);
					result.y = Math.min(result.y, rect.y);
					result.width = right - result.x;
					result.height = bottom - result.y;
				}
			}
			return result;
		}
		return null;
	}
}
