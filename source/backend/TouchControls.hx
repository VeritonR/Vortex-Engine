package backend;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;
import openfl.display.Shape;

/**
 * Something on the screen that turns touches into keys of the game's controls.
 */
interface TouchArea
{
	/**
	 * Marks the actions of the controls ("note_left", "pause"...) held by the points being touched, in the game's pixels.
	 */
	function touch(points:Array<FlxPoint>, held:Map<String, Bool>):Void;
}

/**
 * Touch controls, for phones (and touch screens): what's touched counts as keys of the game's controls, the ones `Controls` reads.
 * The mouse counts as a finger too, which is how they're tried on a computer.
 *
 * During a song (the "Touch Controls" option, Gameplay):
 * - Arrows: the player's own arrows are touched, wherever they are (like V-Slice on phones).
 * - Hitbox: the screen is split in one lane per arrow, from left to right.
 * - Buttons: a button per arrow at the bottom of the screen, half of them on each side (like Psych Engine's phone ports).
 * With any of them a pause button is in the top right corner.
 */
class TouchControls
{
	public static final MODES:Array<String> = ['Off', 'Arrows', 'Hitbox', 'Buttons'];

	static var held:Map<String, Bool> = new Map();
	static var before:Map<String, Bool> = new Map();
	static var areas:Array<TouchArea> = [];
	static var listening:Bool = false;

	/**
	 * The points being touched this frame, in the game's pixels (they're outside of 0-1280 and 0-720 on the bars of a wider screen).
	 */
	public static var points(default, null):Array<FlxPoint> = [];

	/**
	 * For tests ("--touchlog", see DirectPlay): every finger that comes down is written to the log, with where it landed in the
	 * game's and in the window's pixels and what it touched.
	 */
	public static var logTouches:Bool = false;

	public static function logTouch(text:String):Void
	{
		if(logTouches) Sys.println('TOUCH ' + text);
	}

	public static inline function pressed(action:String):Bool return held.exists(action);
	public static inline function justPressed(action:String):Bool return held.exists(action) && !before.exists(action);
	public static inline function justReleased(action:String):Bool return before.exists(action) && !held.exists(action);

	public static function add(area:TouchArea):Void
	{
		if(!listening)
		{
			listening = true;
			FlxG.signals.preUpdate.add(readTouches); //(before anything checks the controls on this frame)
		}
		if(!areas.contains(area)) areas.push(area);
	}

	public static function remove(area:TouchArea):Void
	{
		areas.remove(area);
	}

	// ------------------------------------------------------------------------------------------
	// The song's layout for touching the arrows (V-Slice's on phones)
	// ------------------------------------------------------------------------------------------

	// V-Slice's sizes for a 16:9 screen: (720 / 1280) * 1.95 and * 2.8, and the opponent's "mini mode"
	static inline final PLAYER_SCALE:Float = 1.097;
	static inline final PLAYER_SPACING:Float = 1.575;
	static inline final OPPONENT_SCALE:Float = 0.4;
	static inline final THUMB_GAP:Float = 35; //(the two halves apart, one for each thumb)

	/**
	 * If the song is laid out for touch screens, like V-Slice on phones (any of the touch controls): the player's arrows big,
	 * apart and at the bottom (downscroll), the opponent's small in the top left corner, without its notes.
	 */
	public static function touchLayout():Bool return ClientPrefs.data.touchControls != 'Off';

	/**
	 * The player's own Downscroll while a song is played with the touch layout, which sets it (null otherwise): the arrows at the
	 * bottom, or at the top with the Touch Upscroll option (Mobile Options).
	 */
	public static var realDownScroll(default, null):Null<Bool> = null;

	public static function forceDownScroll():Void
	{
		if(realDownScroll == null) realDownScroll = ClientPrefs.data.downScroll;
		ClientPrefs.data.downScroll = !ClientPrefs.data.touchUpscroll;
	}

	// How big the player's arrows are with the touch layout: V-Slice's size times the Arrow Size option (Mobile Options)
	static function playerScale():Float
		return PLAYER_SCALE * FlxMath.bound(ClientPrefs.data.touchArrowSize, 0.5, 2);

	public static function restoreDownScroll():Void
	{
		if(realDownScroll != null) ClientPrefs.data.downScroll = realDownScroll;
		realDownScroll = null;
	}

	/**
	 * Puts a side's receptors where the touch layout has them, once they're made.
	 */
	public static function layoutStrums(game:states.PlayState, player:Int):Void
	{
		var played:Bool = (player == 1) != game.playAsOpponent;
		var group = (player == 1) ? game.playerStrums : game.opponentStrums;
		var count:Int = group.length;
		if(count == 0) return;

		var scale:Float = played ? playerScale() : OPPONENT_SCALE;
		var step:Float = objects.Note.swagWidth * (played ? PLAYER_SPACING * scale : OPPONENT_SCALE);
		var gap:Float = played ? THUMB_GAP : 0;
		// (bigger arrows come closer together rather than going off the screen)
		if(played)
		{
			var arrowWidth:Float = objects.Note.swagWidth * scale;
			var room:Float = FlxG.width - 24 - gap * 3 - arrowWidth;
			if(count > 1 && step * (count - 1) > room) step = Math.max(arrowWidth * 0.8, room / (count - 1));
			if(step * (count - 1) + arrowWidth + gap * 3 > FlxG.width - 24) gap = 0;
		}
		var left:Float = played ? Math.max(12 + gap * 2, (FlxG.width - count * step) / 2 + 48) : 18;
		if(played) left = Math.min(left, FlxG.width - 12 - gap - step * (count - 1) - objects.Note.swagWidth * scale);
		var middleY:Null<Float> = null;
		// (the opponent's next to the health bar, on its left and as high as it is, like V-Slice on phones)
		var bar = game.healthBar;
		if(!played && bar != null)
		{
			left = Math.max(12, bar.x - 24 - count * step);
			middleY = bar.y + bar.height / 2;
		}
		for (i => strum in group.members)
		{
			if(strum == null) continue;
			strum.scale.set(strum.scale.x * scale, strum.scale.y * scale);
			strum.updateHitbox();
			// (V-Slice moves the first half to the left twice as much as the second half to the right)
			var shift:Float = played ? ((i < count / 2) ? -gap * 2 : gap) : 0;
			strum.x = left + step * i + shift;
			// (at the bottom, or as far from the top with Touch Upscroll)
			var bottom:Bool = !ClientPrefs.data.touchUpscroll;
			strum.y = played ? (bottom ? (FlxG.height - strum.height) * 0.95 - 14 : (FlxG.height - strum.height) * 0.05 + 14)
				: ((middleY != null) ? middleY - strum.height / 2 : 7);
		}
	}

	/**
	 * Fits a note to the touch layout as it comes in: the player's as big as its receptors, the opponent's not seen (its receptors
	 * still light up when it sings).
	 */
	public static function fitNote(game:states.PlayState, note:objects.Note):Void
	{
		var played:Bool = note.mustPress != game.playAsOpponent;
		if(!played)
		{
			note.copyAlpha = false;
			note.alpha = 0;
			note.visible = false;
			note.noteSplashData.disabled = true;
			return;
		}
		var scale:Float = playerScale();
		note.scale.x *= scale;
		if(!note.isSustainNote) note.scale.y *= scale;
		note.updateHitbox();
		note.offsetX *= scale;
	}

	/**
	 * If the mouse counts as a finger on the menus too, to try them on a computer (DirectPlay's "--touch").
	 */
	public static var mouseIsTouch:Bool = false;

	/**
	 * If what's touched this frame comes from the mouse (on a computer it's only the controls of a song that take it).
	 */
	public static var fromMouse(default, null):Bool = false;

	// (once a screen has been touched for real, the menus take touches from then on)
	static var touchSeen:Bool = #if mobile true #else false #end;

	/**
	 * If the menus are used by touching: swiping to move through them, touching to pick, and a button to go back.
	 */
	public static function menusTouched():Bool return touchSeen || mouseIsTouch;

	/**
	 * Starts reading touches for the menus, once the game is made.
	 */
	public static function init():Void
	{
		add(new TouchMenus());
		TouchMouse.init(); //(and the mouse of songs, the last finger: see backend.TouchMouse)
	}

	/**
	 * The part of the game's pixels the window shows: `x` and `y` are below 0 when there are bars around the game.
	 */
	public static function visibleRect(?rect:flixel.math.FlxRect):flixel.math.FlxRect
	{
		if(rect == null) rect = flixel.math.FlxRect.get();
		var scale = FlxG.scaleMode.scale;
		var game = FlxG.game;
		if(game == null || scale.x <= 0 || scale.y <= 0) return rect.set(0, 0, FlxG.width, FlxG.height);
		return rect.set(-game.x / scale.x, -game.y / scale.y, FlxG.stage.stageWidth / scale.x, FlxG.stage.stageHeight / scale.y);
	}

	// ------------------------------------------------------------------------------------------
	// Keys the song's scripts ask for
	// ------------------------------------------------------------------------------------------

	/**
	 * The keys a script of the song asked for (a mod's dodge on SPACE...), with when it last did: while a script keeps asking for one,
	 * the touch controls show a button for it (see TouchNotes), and touching it presses the key itself.
	 */
	public static var askedKeys(default, null):Map<Int, Float> = [];
	static var notButtons:Map<Int, Bool> = [];

	/**
	 * If the keys scripts ask for are being looked at: only during a song played with the touch controls (scripts ask all the time,
	 * this keeps it from costing anything otherwise).
	 */
	public static var watchingKeys:Bool = false;

	// keys that aren't for a song's mechanics: the game's own (pause, the editors' keys mods block, the debug ones) and the modifiers
	static final NOT_BUTTONS:Array<String> = ['ESCAPE', 'ENTER', 'BACKSPACE', 'TAB', 'SHIFT', 'CONTROL', 'ALT', 'CAPSLOCK', 'WINDOWS', 'MENU',
		'PRINTSCREEN', 'GRAVEACCENT', 'SEVEN', 'EIGHT', 'NINE', 'ZERO', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
		'PAGEUP', 'PAGEDOWN', 'HOME', 'END', 'INSERT', 'DELETE', 'NUMLOCK', 'SCROLL_LOCK', 'BREAK'];

	/**
	 * A script asked if a key is pressed (by its name, "SPACE", or its code). Only counts during a song with the touch controls.
	 */
	public static function askedKey(key:Dynamic):Void
	{
		if(!watchingKeys || key == null || !Std.isOfType(FlxG.state, states.PlayState)) return;

		var code:Int = Std.isOfType(key, Int) ? key : flixel.input.keyboard.FlxKey.fromString(Std.string(key).toUpperCase().trim());
		if(code < 0 || notButtons.exists(code)) return;
		if(!askedKeys.exists(code) && !canBeButton(code))
		{
			notButtons.set(code, true);
			return;
		}
		askedKeys.set(code, haxe.Timer.stamp());
	}

	static function canBeButton(code:Int):Bool
	{
		var name:String = flixel.input.keyboard.FlxKey.toStringMap.get(code);
		if(name == null || NOT_BUTTONS.contains(name)) return false;

		// (nor the keys of the arrows and of Reset: on a phone the arrows are touched)
		for (bind => keys in ClientPrefs.keyBinds)
			if((bind.startsWith('note_') || bind == 'reset') && keys != null && keys.contains(code)) return false;
		return true;
	}

	public static function forgetAskedKeys():Void
	{
		askedKeys = [];
		notButtons = [];
	}

	/**
	 * The name on a key's button: "Space", "Q"...
	 */
	public static function keyLabel(code:Int):String
	{
		var name:String = flixel.input.keyboard.FlxKey.toStringMap.get(code);
		if(name == null) return '?';
		return name.charAt(0) + name.substr(1).toLowerCase();
	}

	/**
	 * A rounded button with a text on it.
	 */
	public static function labelGraphic(label:String, width:Int, height:Int, textSize:Int):BitmapData
	{
		var shape:Shape = new Shape();
		shape.graphics.beginFill(0x000000, 0.55);
		shape.graphics.lineStyle(3, 0xFFFFFF, 1);
		shape.graphics.drawRoundRect(2, 2, width - 4, height - 4, height - 4, height - 4);
		shape.graphics.endFill();
		var bitmap:BitmapData = new BitmapData(width, height, true, 0);
		bitmap.draw(shape, null, null, null, null, true);

		var text = new openfl.text.TextField();
		text.defaultTextFormat = new openfl.text.TextFormat('_sans', textSize, 0xFFFFFF, true);
		text.text = label;
		text.width = text.textWidth + 6;
		text.height = text.textHeight + 6;
		var matrix = new openfl.geom.Matrix();
		matrix.translate((width - text.width) / 2, (height - text.height) / 2);
		bitmap.draw(text, matrix, null, null, null, true);
		return bitmap;
	}

	/**
	 * Presses and lets go of the keyboard's own keys like a real keyboard does (FlxG.keys sees them): the ones in `keys` are held,
	 * the ones in `before` that aren't anymore are let go. Gives back `keys`.
	 */
	public static function holdKeys(keys:Array<Int>, before:Array<Int>):Array<Int>
	{
		#if FLX_KEYBOARD
		for (key in before)
			if(!keys.contains(key))
			{
				var input = @:privateAccess FlxG.keys.getKey(key);
				if(input != null) input.release();
			}
		for (key in keys)
			if(!before.contains(key))
			{
				var input = @:privateAccess FlxG.keys.getKey(key);
				if(input != null) input.press();
			}
		#end
		return keys;
	}

	// (the fingers seen down already, see readTouches())
	static var seenTouches:Map<Int, Bool> = [];

	@:access(flixel.input.FlxPointer)
	static function readTouches():Void
	{
		before = held;
		held = new Map();
		for (point in points) point.put();
		points = [];

		fromMouse = false;
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if(touch == null) continue;
			// (a finger that touched and lifted between two frames, a quick tap on a slow phone, counts on the frame that sees it lifted:
			// otherwise it was never down at all, and the note was missed)
			var quickTap:Bool = touch.justReleased && !seenTouches.exists(touch.touchPointID);
			if(logTouches && (touch.justPressed || quickTap))
				logTouch('down at game ' + Math.round(touch._globalScreenX) + ',' + Math.round(touch._globalScreenY) + ' window '
					+ Math.round(touch._globalScreenX * FlxG.scaleMode.scale.x + FlxG.game.x) + ',' + Math.round(touch._globalScreenY * FlxG.scaleMode.scale.y + FlxG.game.y)
					+ ' (stage ' + FlxG.stage.stageWidth + 'x' + FlxG.stage.stageHeight + ', game at ' + Math.round(FlxG.game.x) + ',' + Math.round(FlxG.game.y)
					+ ' scale ' + flixel.math.FlxMath.roundDecimal(FlxG.scaleMode.scale.x, 3) + ')');
			if(touch.pressed || quickTap)
				points.push(FlxPoint.get(touch._globalScreenX, touch._globalScreenY));
			if(touch.pressed) seenTouches.set(touch.touchPointID, true);
		}
		for (id in [for (id in seenTouches.keys()) id])
			if(FlxG.touches.getByID(id) == null) seenTouches.remove(id);
		if(points.length > 0) touchSeen = true;
		#end
		#if FLX_MOUSE
		// (a touch screen moves the mouse too: only when nothing is being touched)
		if(points.length == 0 && FlxG.mouse.pressed)
		{
			points.push(FlxPoint.get(FlxG.mouse._globalScreenX, FlxG.mouse._globalScreenY));
			fromMouse = true;
		}
		#end

		for (area in areas.copy()) area.touch(points, held);
	}
}

/**
 * The touch controls of a song, drawn over the whole window (the bars of a wider screen included). They're not on a camera of the
 * game: the menus over a song (the pause menu, a lot of mods' screens) go on the last camera there is, and would end up on theirs.
 */
@:access(states.PlayState)
class TouchNotes implements TouchArea
{
	static inline final BUTTON_SIZE:Int = 130;
	static inline final PAUSE_SIZE:Int = 72;

	var game:states.PlayState;
	var mode:String;
	var actions:Array<String>;

	var holder:openfl.display.Sprite = new openfl.display.Sprite();
	var lanes:Array<openfl.display.Bitmap> = []; //the hitbox's lanes or the buttons, one per arrow
	var lanePressed:Array<Bool> = [];
	var pauseButton:openfl.display.Bitmap;
	var pausePressed:Bool = false;
	var lastTime:Float = 0;

	// Dialogues and cutscenes: a touch is ENTER (next line), and this button skips them
	static inline final SKIP_WIDTH:Int = 150;
	static inline final SKIP_HEIGHT:Int = 64;
	var skipButton:openfl.display.Bitmap;
	var skipPressed:Bool = false;

	// The buttons of the keys the song's scripts ask for (TouchControls.askedKeys), shown while they're asked for
	static inline final KEY_WIDTH:Int = 190;
	static inline final KEY_HEIGHT:Int = 96;
	static inline final KEY_SHOWN:Float = 2.5; //(seconds a button stays after the last time its key was asked for)
	var keyButtons:Map<Int, openfl.display.Bitmap> = [];
	var keysShown:Array<Int> = [];
	var keysHeld:Array<Int> = [];

	public function new(game:states.PlayState)
	{
		this.game = game;
		mode = ClientPrefs.data.touchControls;
		@:privateAccess actions = game.keysArray;

		for (i in 0...actions.length)
		{
			var graphic:BitmapData = (mode == 'Buttons') ? buttonGraphic(i) : new BitmapData(1, 1, false, ExtraKeys.rgbOf(i)[0]);
			var lane:openfl.display.Bitmap = new openfl.display.Bitmap(graphic, AUTO, true);
			lane.visible = (mode == 'Hitbox' || mode == 'Buttons');
			lane.alpha = 0;
			holder.addChild(lane);
			lanes.push(lane);
			lanePressed.push(false);
		}

		pauseButton = new openfl.display.Bitmap(pauseGraphic(), AUTO, true);
		holder.addChild(pauseButton);

		skipButton = new openfl.display.Bitmap(TouchControls.labelGraphic(Language.getPhrase('touch_skip', 'Skip'), SKIP_WIDTH, SKIP_HEIGHT, 26), AUTO, true);
		skipButton.visible = false;
		holder.addChild(skipButton);

		TouchControls.forgetAskedKeys();
		TouchControls.watchingKeys = true;
		TouchControls.add(this);
	}

	// A dialogue, a video or a cutscene is going on: the arrows aren't played, a touch goes on with it
	function inCutscene():Bool
	{
		// (a video in the middle of the song plays over it while the notes go on: it's not one)
		return game.inCutscene || game.psychDialogue != null || game.conversation != null || !game.startedCountdown;
	}

	// If there's something the skip button can skip: a dialogue, or a video that can be skipped
	function canSkip():Bool
	{
		return game.psychDialogue != null || game.conversation != null || (game.inCutscene && game.videoCutscene != null && game.videoCutscene.canSkip);
	}

	// The keys asked for recently enough to have their button, in the order they were first asked for
	function updateShownKeys():Void
	{
		var now:Float = haxe.Timer.stamp();
		for (key => when in TouchControls.askedKeys)
			if(now - when <= KEY_SHOWN && !keysShown.contains(key)) keysShown.push(key);
		keysShown = keysShown.filter((key) -> keysHeld.contains(key) || (TouchControls.askedKeys.exists(key) && now - TouchControls.askedKeys.get(key) <= KEY_SHOWN));
		if(keysShown.length > 4) keysShown = keysShown.slice(keysShown.length - 4);
	}

	function within(button:openfl.display.Bitmap, x:Float, y:Float, margin:Float = 0):Bool
	{
		return button != null && button.visible && x >= button.x - margin && x <= button.x + button.width + margin && y >= button.y - margin && y <= button.y + button.height + margin;
	}

	// Where everything goes, in the window's pixels
	function layout():Void
	{
		var width:Float = FlxG.stage.stageWidth;
		var height:Float = FlxG.stage.stageHeight;
		var scale:Float = FlxG.scaleMode.scale.y; //(the size the game is shown at)
		var count:Int = lanes.length;

		for (i => lane in lanes)
		{
			if(mode == 'Hitbox')
			{
				lane.x = Math.floor(width / count * i);
				lane.y = 0;
				lane.width = Math.ceil(width / count);
				lane.height = height;
			}
			else if(mode == 'Buttons')
			{
				// a column on each side of the screen, one for each thumb, from the bottom up (the arrows are in the middle)
				var left:Int = Math.ceil(count / 2);
				var margin:Float = 36 * scale;
				var size:Float = Math.min(BUTTON_SIZE * scale, (height - margin * 2) / (left * 1.1)); //(smaller when there are many)
				var pressedScale:Float = lanePressed[i] ? 0.92 : 1;
				var gap:Float = size * 1.1;
				var onLeft:Bool = i < left;
				var place:Int = onLeft ? i : count - 1 - i; //(from the outside in: the first and the last arrows are at the bottom)
				var x:Float = onLeft ? margin : width - margin - size;
				var y:Float = height - size - margin - gap * place;
				lane.width = lane.height = size * pressedScale;
				lane.x = x + size * (1 - pressedScale) / 2;
				lane.y = y + size * (1 - pressedScale) / 2;
			}
		}
		var pauseSize:Float = PAUSE_SIZE * scale;
		pauseButton.width = pauseButton.height = pauseSize;
		pauseButton.x = width - pauseSize - 24 * scale;
		// (at the bottom when your arrows are up there, with Touch Upscroll)
		pauseButton.y = (mode == 'Arrows' && ClientPrefs.data.touchUpscroll) ? height - pauseSize - 24 * scale : 24 * scale;

		var skipGrow:Float = skipPressed ? 0.94 : 1;
		skipButton.width = SKIP_WIDTH * scale * skipGrow;
		skipButton.height = SKIP_HEIGHT * scale * skipGrow;
		skipButton.x = pauseButton.x - 16 * scale - SKIP_WIDTH * scale + SKIP_WIDTH * scale * (1 - skipGrow) / 2;
		skipButton.y = pauseButton.y + (pauseSize - SKIP_HEIGHT * scale) / 2 + SKIP_HEIGHT * scale * (1 - skipGrow) / 2;

		// the keys' buttons on the right side, from the middle of the screen up (the arrows are at the bottom)
		for (key => button in keyButtons) button.visible = keysShown.contains(key);
		for (i => key in keysShown)
		{
			var button:openfl.display.Bitmap = keyButtons.get(key);
			var grow:Float = keysHeld.contains(key) ? 0.92 : 1;
			button.width = KEY_WIDTH * scale * grow;
			button.height = KEY_HEIGHT * scale * grow;
			button.x = width - 32 * scale - KEY_WIDTH * scale + KEY_WIDTH * scale * (1 - grow) / 2;
			button.y = height * 0.42 - (KEY_HEIGHT + 18) * scale * i + KEY_HEIGHT * scale * (1 - grow) / 2;
		}
	}

	public function touch(points:Array<FlxPoint>, held:Map<String, Bool>):Void
	{
		var lanesBefore:Array<Bool> = lanePressed.copy(); //(for --touchlog: the lanes a finger just came down on)
		for (i in 0...lanePressed.length) lanePressed[i] = false;
		pausePressed = false;
		var wasSkipping:Bool = skipPressed;
		skipPressed = false;

		var playing:Bool = game != null && !game.paused && game.subState == null && FlxG.state == game;
		var cutscene:Bool = playing && inCutscene();
		skipButton.visible = cutscene && canSkip();
		if(playing && !cutscene) updateShownKeys();
		else keysShown = [];
		for (key in keysShown)
			if(!keyButtons.exists(key))
			{
				var button = new openfl.display.Bitmap(TouchControls.labelGraphic(TouchControls.keyLabel(key), KEY_WIDTH, KEY_HEIGHT, 34), AUTO, true);
				holder.addChild(button);
				keyButtons.set(key, button);
			}
		var keysNow:Array<Int> = [];

		if(playing)
		{
			for (point in points)
			{
				// (in the window's pixels, where the buttons are)
				var windowX:Float = point.x * FlxG.scaleMode.scale.x + FlxG.game.x;
				var windowY:Float = point.y * FlxG.scaleMode.scale.y + FlxG.game.y;

				if(windowX >= pauseButton.x && windowX <= pauseButton.x + pauseButton.width && windowY >= pauseButton.y && windowY <= pauseButton.y + pauseButton.height)
				{
					pausePressed = true;
					held.set('pause', true);
					continue;
				}

				if(cutscene)
				{
					if(within(skipButton, windowX, windowY, 12 * FlxG.scaleMode.scale.y))
					{
						skipPressed = true;
						continue;
					}
					// anywhere else: the next line (ENTER too before the song starts, for the dialogues mods make themselves)
					held.set('accept', true);
					if(!game.startedCountdown && !keysNow.contains(flixel.input.keyboard.FlxKey.ENTER)) keysNow.push(flixel.input.keyboard.FlxKey.ENTER);
					continue;
				}

				var keyTouched:Int = -1;
				for (key in keysShown)
					if(within(keyButtons.get(key), windowX, windowY, 10 * FlxG.scaleMode.scale.y)) keyTouched = key;
				if(keyTouched >= 0)
				{
					if(!keysNow.contains(keyTouched)) keysNow.push(keyTouched);
					continue;
				}

				var lane:Int = switch(mode)
				{
					case 'Hitbox': Std.int(Math.min(lanes.length - 1, Math.max(0, windowX / FlxG.stage.stageWidth * lanes.length)));
					case 'Buttons': buttonAt(windowX, windowY);
					default: arrowAt(point);
				}
				if(TouchControls.logTouches && (lane < 0 || !lanesBefore[lane]))
				{
					var places:Array<String> = [];
					var strums = game.playableStrums;
					if(strums != null)
						for (i in 0...strums.length)
						{
							var strum:objects.StrumNote = strums.members[i];
							if(strum == null) continue;
							var camera:FlxCamera = strumCamera(strum);
							var shownX:Float = strum.x - strum.offset.x + strum.origin.x - camera.scroll.x * strum.scrollFactor.x;
							var shownY:Float = strum.y - strum.offset.y + strum.origin.y - camera.scroll.y * strum.scrollFactor.y;
							var windowX:Float = ((shownX - camera.width / 2) * camera.zoom + camera.width / 2 + camera.x) * FlxG.scaleMode.scale.x + FlxG.game.x;
							var windowY:Float = ((shownY - camera.height / 2) * camera.zoom + camera.height / 2 + camera.y) * FlxG.scaleMode.scale.y + FlxG.game.y;
							places.push(i + ':' + Math.round(windowX) + ',' + Math.round(windowY) + ' (hitbox middle ' + Math.round(strum.x + strum.width / 2) + ' vs drawn ' + Math.round(strum.x - strum.offset.x + strum.origin.x) + ')');
						}
					TouchControls.logTouch('song: lane ' + lane + ' | arrows drawn at (window) ' + places.join('  '));
				}
				if(lane < 0 || lane >= actions.length) continue;
				lanePressed[lane] = true;
				held.set(actions[lane], true);
			}
		}
		keysHeld = TouchControls.holdKeys(keysNow, keysHeld);

		// the skip button skips when it's touched: a dialogue gets BACK, a video is skipped right away
		if(skipPressed && !wasSkipping)
		{
			if(game.inCutscene && game.videoCutscene != null && game.videoCutscene.canSkip) game.videoCutscene.skipNow();
			else held.set('back', true);
		}
		draw(playing);
	}

	function draw(playing:Bool):Void
	{
		var parent = (FlxG.game != null) ? FlxG.game.parent : null;
		if(parent == null) return;
		if(holder.parent != parent) parent.addChild(holder);
		else if(parent.getChildIndex(holder) != parent.numChildren - 1) parent.setChildIndex(holder, parent.numChildren - 1);
		holder.visible = playing; //(the menus over the song have their own: see TouchMenus)
		if(!playing) return;

		var now:Float = haxe.Timer.stamp();
		var elapsed:Float = Math.min(0.1, now - lastTime);
		lastTime = now;

		var opacity:Float = ClientPrefs.data.touchOpacity;
		for (i => lane in lanes)
		{
			var target:Float = (mode == 'Hitbox') ? (lanePressed[i] ? 0.3 : 0) : (lanePressed[i] ? 1 : 0.55);
			lane.alpha = FlxMath.lerp(lane.alpha, target * opacity, Math.min(1, elapsed * 24));
		}
		pauseButton.alpha = (pausePressed ? 1 : 0.55) * opacity;
		skipButton.alpha = (skipPressed ? 1 : 0.7) * opacity;
		for (key => button in keyButtons) button.alpha = (keysHeld.contains(key) ? 1 : 0.65) * opacity;
		layout();
	}

	function buttonAt(x:Float, y:Float):Int
	{
		for (i => button in lanes)
		{
			var radius:Float = Math.max(button.width, button.height) / 2;
			var dx:Float = x - (button.x + button.width / 2);
			var dy:Float = y - (button.y + button.height / 2);
			if(dx * dx + dy * dy <= radius * radius * 1.3) return i; //(a bit past the circle still counts)
		}
		return -1;
	}

	// The player's arrow under the point, wherever the song has put the arrows (scrolls, modcharts)
	function arrowAt(point:FlxPoint):Int
	{
		var strums = game.playableStrums;
		if(strums == null || strums.length == 0) return -1;

		var best:Int = -1;
		var bestDistance:Float = Math.POSITIVE_INFINITY;
		for (i in 0...strums.length)
		{
			var strum:objects.StrumNote = strums.members[i];
			if(strum == null || !strum.exists) continue;

			// the point on the strum's camera, zoomed like it
			var camera:FlxCamera = strumCamera(strum);
			var x:Float = (point.x - camera.x - camera.width / 2) / camera.zoom + camera.width / 2 + camera.scroll.x * strum.scrollFactor.x;
			var y:Float = (point.y - camera.y - camera.height / 2) / camera.zoom + camera.height / 2 + camera.scroll.y * strum.scrollFactor.y;

			var dx:Float = Math.abs(x - (strum.x + strum.width / 2));
			var dy:Float = Math.abs(y - (strum.y + strum.height / 2));
			// (as wide as the space between two arrows, and much taller than one: a finger isn't precise)
			if(dx > Math.max(objects.Note.swagWidth, strum.width) * 0.75 || dy > strum.height * 1.75) continue;
			if(dx < bestDistance)
			{
				bestDistance = dx;
				best = i;
			}
		}
		return best;
	}

	// The camera a receptor is drawn on: its own if a script gave it one, or else its group's (the HUD's). Asking the receptor
	// itself gives flixel's default camera, the stage's, which Widescreen makes wider: on a phone's screen a touch landed on the
	// arrow next to the one touched
	@:access(flixel.FlxBasic)
	function strumCamera(strum:objects.StrumNote):FlxCamera
	{
		if(strum._cameras != null && strum._cameras.length > 0) return strum._cameras[0];
		var group = game.strumLineNotes;
		if(group != null && group._cameras != null && group._cameras.length > 0) return group._cameras[0];
		return (game.camHUD != null) ? game.camHUD : FlxG.camera;
	}

	public function destroy():Void
	{
		keysHeld = TouchControls.holdKeys([], keysHeld);
		TouchControls.forgetAskedKeys();
		TouchControls.watchingKeys = false;
		TouchControls.remove(this);
		if(holder.parent != null) holder.parent.removeChild(holder);
		game = null;
	}

	// A circle of the arrow's color with a white arrow on it
	static function buttonGraphic(column:Int):BitmapData
	{
		var size:Int = BUTTON_SIZE;
		var radius:Float = size / 2;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(ExtraKeys.rgbOf(column)[0], 0.75);
		shape.graphics.lineStyle(5, 0xFFFFFF, 1);
		shape.graphics.drawCircle(radius, radius, radius - 4);
		shape.graphics.endFill();

		// the arrow, pointing right, then turned to its direction (a circle for the middle one of odd counts)
		var direction:Int = ExtraKeys.shapeOf(column);
		shape.graphics.lineStyle();
		shape.graphics.beginFill(0xFFFFFF, 1);
		if(direction == 4) shape.graphics.drawCircle(radius, radius, radius * 0.28);
		else
		{
			var angle:Float = [Math.PI, Math.PI / 2, -Math.PI / 2, 0][direction];
			var tip:Float = radius * 0.45;
			var back:Float = radius * 0.3;
			var side:Float = radius * 0.38;
			inline function px(along:Float, across:Float):Float return radius + Math.cos(angle) * along - Math.sin(angle) * across;
			inline function py(along:Float, across:Float):Float return radius + Math.sin(angle) * along + Math.cos(angle) * across;
			shape.graphics.moveTo(px(tip, 0), py(tip, 0));
			shape.graphics.lineTo(px(-back, side), py(-back, side));
			shape.graphics.lineTo(px(-back, -side), py(-back, -side));
			shape.graphics.lineTo(px(tip, 0), py(tip, 0));
		}
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape, null, null, null, null, true);
		return bitmap;
	}

	static function pauseGraphic():BitmapData
	{
		var size:Int = PAUSE_SIZE;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(0x000000, 0.5);
		shape.graphics.lineStyle(4, 0xFFFFFF, 1);
		shape.graphics.drawRoundRect(2, 2, size - 4, size - 4, 18, 18);
		shape.graphics.endFill();
		shape.graphics.lineStyle();
		shape.graphics.beginFill(0xFFFFFF, 1);
		shape.graphics.drawRect(size * 0.3, size * 0.25, size * 0.14, size * 0.5);
		shape.graphics.drawRect(size * 0.56, size * 0.25, size * 0.14, size * 0.5);
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape, null, null, null, null, true);
		return bitmap;
	}
}

/**
 * Touching the menus (and the screens over a song: pause, game over): dragging a finger up or down moves through a list like the
 * arrow keys do, left and right too, touching picks, and a button in the top left corner goes back. It turns into the same keys of
 * the controls, so it works on every screen, the ones of mods too.
 *
 * Touching picks the item touched on the engine's lists made the Psych Engine way (a group of items and `curSelected`: the pause
 * menu...), the second touch on it confirms it; anywhere else it's ENTER (the title screen, the results, a dialogue...). The screens
 * that are used with the mouse already (the main menu, the mods, the options...) get the touch as a click, which is what a phone does
 * with the first finger: they're only given the dragging and the back button.
 */
class TouchMenus implements TouchArea
{
	static inline final STEP:Float = 90; //pixels of the game a finger is dragged for each item
	static inline final TAP_MOVE:Float = 24;
	static inline final BACK_SIZE:Int = 72;

	static final MOUSE_SCREENS:Array<String> = ['states.MainMenuState', 'states.ModsMenuState', 'states.GalleryState', 'states.LanguageSelectState',
		'options.OptionsMenu', 'options.NotesColorSubState', 'options.NoteOffsetState', 'options.LanguageSubState', 'substates.ModCompatSubState'];
	static final LIST_GROUPS:Array<String> = ['grpMenuShit', 'grpSongs', 'grpWeekText', 'grpOptions', 'grpControls', 'grpTexts', 'menuItems'];
	static final LIST_MOVES:Array<String> = ['changeSelection', 'changeItem', 'changeWeek'];

	var tracking:Bool = false;
	var moved:Bool = false;
	var startX:Float = 0;
	var startY:Float = 0;
	var stepX:Float = 0;
	var stepY:Float = 0;
	var lastX:Float = 0;
	var lastY:Float = 0;
	var startTime:Float = 0;
	var backButton:openfl.display.Bitmap;

	// The buttons on the screen, for the ones who'd rather not drag: arrows in the bottom left corner, A (ENTER) and B (back) in
	// the bottom right one. Held, they're held keys (a list goes on moving like with the keyboard)
	static inline final PAD_SIZE:Int = 96;
	static final PAD_ACTIONS:Array<String> = ['ui_up', 'ui_down', 'ui_left', 'ui_right', 'accept', 'back'];
	var pad:Array<openfl.display.Bitmap> = [];
	var padPressed:Array<Bool> = [];
	var startedOnPad:Bool = false;

	// The keys some screens need that the pad doesn't have, as buttons over A and B: [label, key]. Touched, the key itself is
	// pressed (they're read as keys, not as actions of the controls)
	static final SCREEN_KEYS:Map<String, Array<Array<String>>> = [
		'states.FreeplayStateVslice' => [['Changers', 'CONTROL'], ['Listen', 'SPACE'], ['Favorite', 'F']],
		'states.FreeplayState' => [['Changers', 'CONTROL'], ['Listen', 'SPACE']],
		'states.StoryMenuState' => [['Changers', 'CONTROL']]
	];
	var keyButtons:Map<String, openfl.display.Bitmap> = [];
	var keysHeld:Array<String> = []; //(the keys pressed by those, let go when the finger is)

	public function new()
	{
		backButton = new openfl.display.Bitmap(backGraphic(), AUTO, true);
		backButton.visible = false;
		for (action in PAD_ACTIONS)
		{
			var button = new openfl.display.Bitmap(padGraphic(action), AUTO, true);
			button.visible = false;
			pad.push(button);
			padPressed.push(false);
		}
	}

	// Where the pad's buttons are, in the window's pixels
	function placePad(show:Bool):Void
	{
		var game = FlxG.game;
		if(game == null || game.parent == null) return;

		var scale:Float = FlxG.scaleMode.scale.y;
		var size:Float = PAD_SIZE * scale;
		var margin:Float = 24 * scale;
		var width:Float = FlxG.stage.stageWidth;
		var height:Float = FlxG.stage.stageHeight;
		var centerX:Float = margin + size * 1.5;
		var centerY:Float = height - margin - size * 1.5;
		var spots:Array<Array<Float>> = [
			[centerX, centerY - size], [centerX, centerY + size], [centerX - size, centerY], [centerX + size, centerY], //the arrows
			[width - margin - size * 0.5, height - margin - size * 1.4], //A
			[width - margin - size * 1.75, height - margin - size * 0.5] //B
		];
		for (i => button in pad)
		{
			if(button.parent != game.parent) game.parent.addChild(button);
			else if(game.parent.getChildIndex(button) != game.parent.numChildren - 1) game.parent.setChildIndex(button, game.parent.numChildren - 1);
			button.visible = show;
			var grow:Float = padPressed[i] ? 0.9 : 1;
			button.width = button.height = size * grow;
			button.x = spots[i][0] - size * grow / 2;
			button.y = spots[i][1] - size * grow / 2;
			button.alpha = (padPressed[i] ? 0.9 : 0.45) * ClientPrefs.data.touchOpacity;
		}
	}

	// The keyboard's own keys, pressed and let go like a real keyboard does (FlxG.keys sees them)
	function pressKeys(keys:Array<String>):Void
	{
		#if FLX_KEYBOARD
		for (key in keysHeld)
			if(!keys.contains(key))
			{
				var input = @:privateAccess FlxG.keys.getKey(flixel.input.keyboard.FlxKey.fromString(key));
				if(input != null) input.release();
			}
		for (key in keys)
			if(!keysHeld.contains(key))
			{
				var input = @:privateAccess FlxG.keys.getKey(flixel.input.keyboard.FlxKey.fromString(key));
				if(input != null) input.press();
			}
		#end
		keysHeld = keys;
	}

	static inline final KEY_WIDTH:Int = 170;
	static inline final KEY_HEIGHT:Int = 56;

	// The screen's keys, in a column over A and B
	function placeScreenKeys(keys:Array<Array<String>>, pressed:Array<String>):Void
	{
		var game = FlxG.game;
		if(game == null || game.parent == null) return;
		var shown:Array<String> = (keys != null) ? [for (entry in keys) entry[1]] : [];
		for (key => button in keyButtons) button.visible = shown.contains(key);
		if(keys == null) return;

		var scale:Float = FlxG.scaleMode.scale.y;
		var margin:Float = 24 * scale;
		var top:Float = FlxG.stage.stageHeight - margin - PAD_SIZE * scale * 2.1 - KEY_HEIGHT * scale;
		for (i => entry in keys)
		{
			var button:openfl.display.Bitmap = keyButtons.get(entry[1]);
			if(button == null)
			{
				button = new openfl.display.Bitmap(keyGraphic(entry[0]), AUTO, true);
				keyButtons.set(entry[1], button);
			}
			if(button.parent != game.parent) game.parent.addChild(button);
			else if(game.parent.getChildIndex(button) != game.parent.numChildren - 1) game.parent.setChildIndex(button, game.parent.numChildren - 1);
			button.visible = true;
			button.width = KEY_WIDTH * scale;
			button.height = KEY_HEIGHT * scale;
			button.x = FlxG.stage.stageWidth - margin - button.width;
			button.y = top - (KEY_HEIGHT + 12) * scale * i;
			button.alpha = (pressed.contains(entry[1]) ? 0.9 : 0.5) * ClientPrefs.data.touchOpacity;
		}
	}

	function screenKeyAt(keys:Array<Array<String>>, x:Float, y:Float):String
	{
		var windowX:Float = x * FlxG.scaleMode.scale.x + FlxG.game.x;
		var windowY:Float = y * FlxG.scaleMode.scale.y + FlxG.game.y;
		for (entry in keys)
		{
			var button:openfl.display.Bitmap = keyButtons.get(entry[1]);
			if(button != null && button.visible && windowX >= button.x && windowX <= button.x + button.width && windowY >= button.y && windowY <= button.y + button.height)
				return entry[1];
		}
		return null;
	}

	static function keyGraphic(label:String):BitmapData
		return TouchControls.labelGraphic(label, KEY_WIDTH, KEY_HEIGHT, 24);

	/*
	 * The pad's button under a point of the game's pixels, -1 for none: the nearest one, as far as a finger reaches past it.
	 * A finger is wider than the circle drawn and lands a little off it, between two of the arrows or past one: those used to be
	 * touches of the screen, and on Freeplay the screen under the pad is the DJ's (it opened Character Select instead of going up).
	 */
	function padAt(x:Float, y:Float):Int
	{
		var windowX:Float = x * FlxG.scaleMode.scale.x + FlxG.game.x;
		var windowY:Float = y * FlxG.scaleMode.scale.y + FlxG.game.y;
		var reach:Float = PAD_SIZE * FlxG.scaleMode.scale.y * 0.8;
		var best:Int = -1;
		var bestDistance:Float = reach * reach;
		for (i => button in pad)
		{
			if(!button.visible) continue;
			var dx:Float = windowX - (button.x + button.width / 2);
			var dy:Float = windowY - (button.y + button.height / 2);
			var distance:Float = dx * dx + dy * dy;
			if(distance <= bestDistance)
			{
				bestDistance = distance;
				best = i;
			}
		}
		return best;
	}

	// If a point of the game's pixels is on the pad, its buttons or the space between them (where a finger aiming at one of
	// them lands): touching there is never a touch of the screen behind it
	function nearPad(x:Float, y:Float):Bool
	{
		var windowX:Float = x * FlxG.scaleMode.scale.x + FlxG.game.x;
		var windowY:Float = y * FlxG.scaleMode.scale.y + FlxG.game.y;
		var margin:Float = PAD_SIZE * FlxG.scaleMode.scale.y * 0.35;
		for (group in [[0, 1, 2, 3], [4, 5]])
		{
			var left:Float = Math.POSITIVE_INFINITY, top:Float = Math.POSITIVE_INFINITY;
			var right:Float = Math.NEGATIVE_INFINITY, bottom:Float = Math.NEGATIVE_INFINITY;
			for (i in group)
			{
				var button = pad[i];
				if(button == null || !button.visible) continue;
				left = Math.min(left, button.x);
				top = Math.min(top, button.y);
				right = Math.max(right, button.x + button.width);
				bottom = Math.max(bottom, button.y + button.height);
			}
			if(windowX >= left - margin && windowX <= right + margin && windowY >= top - margin && windowY <= bottom + margin) return true;
		}
		return false;
	}

	// A circle with an arrow, or a letter for A and B
	static function padGraphic(action:String):BitmapData
	{
		var size:Int = PAD_SIZE;
		var radius:Float = size / 2;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(0x000000, 0.55);
		shape.graphics.lineStyle(4, 0xFFFFFF, 1);
		shape.graphics.drawCircle(radius, radius, radius - 3);
		shape.graphics.endFill();

		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		var angle:Null<Float> = switch(action)
		{
			case 'ui_up': -Math.PI / 2;
			case 'ui_down': Math.PI / 2;
			case 'ui_left': Math.PI;
			case 'ui_right': 0;
			default: null;
		}
		if(angle != null)
		{
			shape.graphics.lineStyle();
			shape.graphics.beginFill(0xFFFFFF, 1);
			var tip:Float = radius * 0.42;
			var back:Float = radius * 0.28;
			var side:Float = radius * 0.36;
			inline function px(along:Float, across:Float):Float return radius + Math.cos(angle) * along - Math.sin(angle) * across;
			inline function py(along:Float, across:Float):Float return radius + Math.sin(angle) * along + Math.cos(angle) * across;
			shape.graphics.moveTo(px(tip, 0), py(tip, 0));
			shape.graphics.lineTo(px(-back, side), py(-back, side));
			shape.graphics.lineTo(px(-back, -side), py(-back, -side));
			shape.graphics.lineTo(px(tip, 0), py(tip, 0));
			shape.graphics.endFill();
			bitmap.draw(shape, null, null, null, null, true);
		}
		else
		{
			bitmap.draw(shape, null, null, null, null, true);
			var label = new openfl.text.TextField();
			label.defaultTextFormat = new openfl.text.TextFormat('_sans', Std.int(size * 0.42), 0xFFFFFF, true);
			label.text = (action == 'accept') ? 'A' : 'B';
			label.width = label.textWidth + 6;
			label.height = label.textHeight + 6;
			var matrix = new openfl.geom.Matrix();
			matrix.translate((size - label.width) / 2, (size - label.height) / 2);
			bitmap.draw(label, matrix, null, null, null, true);
		}
		return bitmap;
	}

	// The screen on top, null during a song (its own touch controls are backend.TouchNotes)
	static function screen():flixel.FlxState
	{
		var state:flixel.FlxState = FlxG.state;
		if(state == null) return null;
		while(state.subState != null) state = state.subState;
		return Std.isOfType(state, states.PlayState) ? null : state;
	}

	public function touch(points:Array<FlxPoint>, held:Map<String, Bool>):Void
	{
		var target:flixel.FlxState = screen();
		var active:Bool = target != null && TouchControls.menusTouched() && (!TouchControls.fromMouse || TouchControls.mouseIsTouch);
		var shown:Bool = target != null && TouchControls.menusTouched() && !Std.isOfType(target, states.TitleState);
		showBack(shown);

		// the pad: every finger on one of its buttons holds its key
		for (i in 0...padPressed.length) padPressed[i] = false;
		var screenKeys:Array<Array<String>> = (target != null) ? SCREEN_KEYS.get(Type.getClassName(Type.getClass(target))) : null;
		if(!shown || !active) screenKeys = null;
		var keysNow:Array<String> = [];
		var free:Array<FlxPoint> = [];
		for (point in points)
		{
			var key:String = (screenKeys != null) ? screenKeyAt(screenKeys, point.x, point.y) : null;
			if(key != null)
			{
				if(!keysNow.contains(key)) keysNow.push(key);
				continue;
			}
			var button:Int = (active && shown) ? padAt(point.x, point.y) : -1;
			if(button < 0 && active && shown && nearPad(point.x, point.y)) button = -2; //(next to the pad: neither a button nor the screen)
			if(TouchControls.logTouches && !tracking && !startedOnPad)
				TouchControls.logTouch('menu: pad button ' + button + ' | pad drawn at (window) '
					+ [for (i => b in pad) i + ':' + Math.round(b.x + b.width / 2) + ',' + Math.round(b.y + b.height / 2) + (b.visible ? '' : ' hidden')].join('  '));
			if(button == -1)
			{
				free.push(point);
				continue;
			}
			if(button < 0) continue;
			padPressed[button] = true;
			held.set(PAD_ACTIONS[button], true);
		}
		pressKeys(keysNow);
		placePad(shown);
		placeScreenKeys(screenKeys, keysNow);
		if(!active)
		{
			tracking = false;
			return;
		}
		// (a finger that started on the pad isn't dragging the menu, even if it slides off)
		// (a finger on the pad while another one left the screen on the same frame isn't that one lifting: it's no touch of the screen)
		if(points.length > 0 && free.length == 0)
		{
			startedOnPad = true;
			tracking = false;
		}
		if(points.length == 0) startedOnPad = false;
		if(startedOnPad) return;
		points = free;

		if(points.length > 0)
		{
			var point:FlxPoint = points[0];
			if(!tracking)
			{
				tracking = true;
				moved = false;
				startX = stepX = lastX = point.x;
				startY = stepY = lastY = point.y;
				startTime = haxe.Timer.stamp();
			}
			lastX = point.x;
			lastY = point.y;
			if(Math.abs(point.x - startX) > TAP_MOVE || Math.abs(point.y - startY) > TAP_MOVE) moved = true;

			// (a finger going up brings the next item, like scrolling a list)
			var dx:Float = point.x - stepX;
			var dy:Float = point.y - stepY;
			if(Math.abs(dy) >= STEP && Math.abs(dy) >= Math.abs(dx))
			{
				held.set((dy < 0) ? 'ui_down' : 'ui_up', true);
				stepY += (dy < 0) ? -STEP : STEP;
				stepX = point.x;
			}
			else if(Math.abs(dx) >= STEP * 1.5)
			{
				held.set((dx < 0) ? 'ui_right' : 'ui_left', true);
				stepX += (dx < 0) ? -STEP * 1.5 : STEP * 1.5;
				stepY = point.y;
			}
			return;
		}

		if(!tracking) return;
		tracking = false;
		if(moved || haxe.Timer.stamp() - startTime > 0.5) return;

		// a touch, where the finger was: a screen can take it itself first (`onTouchTap(x, y):Bool`, the Freeplay menu's DJ and songs)
		var ownTap:Dynamic = Reflect.field(target, 'onTouchTap');
		TouchControls.logTouch('menu: tap at game ' + Math.round(lastX) + ',' + Math.round(lastY) + ' on ' + Type.getClassName(Type.getClass(target)));
		if(onBack(lastX, lastY)) held.set('back', true);
		else if(Reflect.isFunction(ownTap) && Reflect.callMethod(target, ownTap, [lastX, lastY]) == true) {}
		else if(!MOUSE_SCREENS.contains(Type.getClassName(Type.getClass(target))) && !pickFromList(target, lastX, lastY, held))
			held.set('accept', true);
	}

	// The item touched on a list made the Psych Engine way: picked if it wasn't, confirmed if it was. False if there's no such list
	function pickFromList(target:Dynamic, x:Float, y:Float, held:Map<String, Bool>):Bool
	{
		var current:Dynamic = Reflect.getProperty(target, 'curSelected');
		if(!Std.isOfType(current, Int)) return false;

		for (name in LIST_GROUPS)
		{
			var group:Dynamic = Reflect.getProperty(target, name);
			if(group == null || !Std.isOfType(group, flixel.group.FlxGroup.FlxTypedGroup)) continue;

			var members:Array<Dynamic> = group.members;
			for (i => item in members)
			{
				var sprite:FlxSprite = Std.downcast(item, FlxSprite);
				if(sprite == null || !sprite.exists || !sprite.visible || sprite.alpha <= 0 || !under(sprite, x, y)) continue;

				if(i == current)
				{
					held.set('accept', true);
					return true;
				}
				for (move in LIST_MOVES)
				{
					var func:Dynamic = Reflect.field(target, move);
					if(!Reflect.isFunction(func)) continue;
					Reflect.callMethod(target, func, [i - current]);
					return true;
				}
				return false;
			}
		}
		return false;
	}

	/**
	 * If a point of the game's pixels is on a sprite, as its camera shows it.
	 */
	public static function under(sprite:FlxSprite, x:Float, y:Float):Bool
	{
		var camera:FlxCamera = sprite.camera;
		if(camera == null) return false;
		var cameraX:Float = (x - camera.x - camera.width / 2) / camera.zoom + camera.width / 2;
		var cameraY:Float = (y - camera.y - camera.height / 2) / camera.zoom + camera.height / 2;
		var left:Float = sprite.x - camera.scroll.x * sprite.scrollFactor.x;
		var top:Float = sprite.y - camera.scroll.y * sprite.scrollFactor.y;
		return cameraX >= left && cameraX <= left + sprite.width && cameraY >= top && cameraY <= top + sprite.height;
	}

	// The back button, in the window's top left corner (over the game, the bars of a wider screen included)
	function showBack(show:Bool):Void
	{
		var game = FlxG.game;
		if(game == null || game.parent == null) return;
		if(backButton.parent != game.parent) game.parent.addChild(backButton);
		else if(game.parent.getChildIndex(backButton) != game.parent.numChildren - 1) game.parent.setChildIndex(backButton, game.parent.numChildren - 1);

		backButton.visible = show;
		var size:Float = BACK_SIZE * FlxG.scaleMode.scale.y;
		backButton.width = backButton.height = size;
		backButton.x = backButton.y = 16 * FlxG.scaleMode.scale.y;
		backButton.alpha = 0.7 * ClientPrefs.data.touchOpacity;
	}

	function onBack(x:Float, y:Float):Bool
	{
		if(!backButton.visible) return false;
		var windowX:Float = x * FlxG.scaleMode.scale.x + FlxG.game.x;
		var windowY:Float = y * FlxG.scaleMode.scale.y + FlxG.game.y;
		var margin:Float = 12 * FlxG.scaleMode.scale.y; //(a finger is wider than the button's edge)
		return windowX >= backButton.x - margin && windowX <= backButton.x + backButton.width + margin
			&& windowY >= backButton.y - margin && windowY <= backButton.y + backButton.height + margin;
	}

	static function backGraphic():BitmapData
	{
		var size:Int = BACK_SIZE;
		var shape:Shape = new Shape();
		shape.graphics.beginFill(0x000000, 0.5);
		shape.graphics.lineStyle(4, 0xFFFFFF, 1);
		shape.graphics.drawRoundRect(2, 2, size - 4, size - 4, 18, 18);
		shape.graphics.endFill();
		shape.graphics.lineStyle(7, 0xFFFFFF, 1);
		shape.graphics.moveTo(size * 0.58, size * 0.26);
		shape.graphics.lineTo(size * 0.36, size * 0.5);
		shape.graphics.lineTo(size * 0.58, size * 0.74);

		var bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape, null, null, null, null, true);
		return bitmap;
	}
}
