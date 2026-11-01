package backend;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

/**
 * The chat of the online matches: the chat key ("T" by default, see the Controls menu) opens a line to type on, ENTER sends it and ESC
 * closes it. It's on top of every screen (the lobby, the songs, the results), over the game rather than in a state of it.
 *
 * While it's open the game doesn't get the keyboard (no notes are hit, no menu moves). In a song the chat key doesn't open it when it's
 * also a note key: the note comes first (the Controls menu warns about that).
 */
class OnlineChat extends Sprite
{
	public static var instance(default, null):OnlineChat;

	/**
	 * If the chat line is open and being typed on.
	 */
	public static var typing(default, null):Bool = false;

	/**
	 * Set by screens that are typing something of their own (the lobby's nickname and IP): the chat key doesn't open the chat then.
	 */
	public static var blocked:Bool = false;

	static inline var MAX_LENGTH:Int = 120;
	static inline var SHOWN_LINES:Int = 6;
	static inline var LINE_TIME:Float = 8;

	// messages that came from the other player, from the network's thread
	static var inbox:Array<String> = [];
	#if sys
	static var inboxMutex:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	var lines:Array<{text:String, mine:Bool, age:Float}> = [];
	var history:TextField;
	var input:TextField;
	var typed:String = '';
	var lastTime:Float = 0;
	var reenableKeys:Bool = false;

	/**
	 * Puts the chat over the game. Called once, after the game was made.
	 */
	public static function init():Void
	{
		if(instance != null || FlxG.stage == null) return;
		instance = new OnlineChat();
		FlxG.stage.addChild(instance);
	}

	/**
	 * A message of the other player (called from the network's thread: the chat shows it on its next frame).
	 */
	public static function receive(text:String):Void
	{
		#if sys inboxMutex.acquire(); #end
		inbox.push(text);
		#if sys inboxMutex.release(); #end
	}

	/**
	 * Takes the chat's messages away (a new match).
	 */
	public static function clear():Void
	{
		if(instance != null) instance.lines = [];
		#if sys inboxMutex.acquire(); #end
		inbox = [];
		#if sys inboxMutex.release(); #end
	}

	/**
	 * Test runs (see DirectPlay): text put on the open chat line.
	 */
	public static function testType(text:String):Void
	{
		if(instance == null || !typing) return;
		instance.typed += text;
		instance.redraw();
	}

	public function new()
	{
		super();
		mouseEnabled = mouseChildren = false;

		history = makeField(18);
		addChild(history);
		input = makeField(20);
		input.background = true;
		input.backgroundColor = 0x000000;
		input.visible = false;
		addChild(input);

		addEventListener(Event.ENTER_FRAME, onFrame);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 100); //(before the game's own)
		lime.app.Application.current.window.onTextInput.add(onTextInput);
		lastTime = haxe.Timer.stamp();
	}

	function makeField(size:Int):TextField
	{
		var field:TextField = new TextField();
		field.selectable = false;
		field.multiline = true;
		field.wordWrap = true;
		field.defaultTextFormat = new TextFormat('_sans', size, 0xFFFFFF, true);
		field.width = 560;
		return field;
	}

	function onFrame(_):Void
	{
		var now:Float = haxe.Timer.stamp();
		var elapsed:Float = Math.min(now - lastTime, 0.5);
		lastTime = now;

		if(reenableKeys)
		{
			reenableKeys = false;
			FlxG.keys.reset();
			FlxG.keys.enabled = true;
		}

		var connected:Bool = NetworkManager.connected;
		if(!connected && typing) close();

		// the other player's messages
		#if sys inboxMutex.acquire(); #end
		var arrived:Array<String> = inbox;
		inbox = [];
		#if sys inboxMutex.release(); #end
		for (text in arrived)
		{
			addLine(NetworkManager.opponentNickname + ': ' + text, false);
			NetworkManager.log('chat from ' + NetworkManager.opponentNickname + ': ' + text);
		}

		// the chat key, when nothing else is being typed (FlxG.keys sees it before it's turned off)
		if(connected && !typing && !blocked && FlxG.keys.enabled && FlxG.keys.anyJustPressed(ClientPrefs.keyBinds.get('chat')) && canOpenHere())
			open();

		for (line in lines) line.age += elapsed;
		while(lines.length > 30) lines.shift();
		redraw();
	}

	// In a song the chat key opens nothing when it's also a note key (the note is pressed instead)
	function canOpenHere():Bool
	{
		if(!Std.isOfType(FlxG.state, states.PlayState)) return true;
		for (other in options.ControlsSubState.conflictsOf('chat'))
			if(other.startsWith('note_')) return false;
		return true;
	}

	function open():Void
	{
		typing = true;
		typed = '';
		FlxG.keys.reset(); //(what was held is let go: a long note stops being held)
		FlxG.keys.enabled = false;
		lime.app.Application.current.window.textInputEnabled = true;
		redraw();
	}

	function close():Void
	{
		typing = false;
		typed = '';
		reenableKeys = true; //(on the next frame: the ENTER or ESC that closed it isn't taken by the game too)
		redraw();
	}

	function onKeyDown(event:KeyboardEvent):Void
	{
		if(!typing) return;
		switch(event.keyCode)
		{
			case Keyboard.ENTER, Keyboard.NUMPAD_ENTER:
				send();
				close();
			case Keyboard.ESCAPE:
				close();
			case Keyboard.BACKSPACE:
				if(typed.length > 0) typed = typed.substr(0, typed.length - 1);
				redraw();
			default:
		}
		event.stopImmediatePropagation(); //(the game doesn't see the keys typed on the chat)
	}

	function onTextInput(text:String):Void
	{
		if(!typing || text == null) return;
		for (i in 0...text.length)
		{
			var char:String = text.charAt(i);
			var code:Int = text.charCodeAt(i);
			if(code < 32 || char == '|' || typed.length >= MAX_LENGTH) continue;
			typed += char;
		}
		redraw();
	}

	function send():Void
	{
		var text:String = StringTools.trim(typed);
		if(text.length < 1 || !NetworkManager.connected) return;
		NetworkManager.send('CHAT|' + text);
		NetworkManager.log('chat sent: ' + text);
		addLine(NetworkManager.myNickname + ': ' + text, true);
	}

	function addLine(text:String, mine:Bool):Void
	{
		lines.push({text: text, mine: mine, age: 0});
		if(!mine && FlxG.sound != null) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function redraw():Void
	{
		var showAll:Bool = typing;
		var shown:Array<{text:String, mine:Bool, age:Float}> = [];
		var start:Int = Std.int(Math.max(0, lines.length - (showAll ? SHOWN_LINES * 2 : SHOWN_LINES)));
		for (i in start...lines.length)
			if(showAll || lines[i].age < LINE_TIME) shown.push(lines[i]);

		var html:String = '';
		for (line in shown)
		{
			var color:String = line.mine ? '#7FE0FF' : '#FFC27F';
			var fade:Float = showAll ? 1 : Math.min(1, (LINE_TIME - line.age) / 1.5);
			if(fade <= 0) continue;
			html += '<font color="$color">' + StringTools.htmlEscape(line.text) + '</font><br>';
		}
		if(history.htmlText != html) history.htmlText = html;
		history.alpha = 1;
		var oldest:Float = 0;
		for (line in shown) oldest = Math.max(oldest, line.age);
		if(!showAll && shown.length > 0) history.alpha = Math.min(1, (LINE_TIME - shown[shown.length - 1].age) / 1.5 + 0.35);
		history.visible = shown.length > 0;

		input.visible = typing;
		if(typing) input.text = '> ' + typed + '_';

		// at the bottom left of the window, over the game
		var stageHeight:Float = FlxG.stage.stageHeight;
		input.height = input.textHeight + 6;
		input.x = history.x = 12;
		input.y = stageHeight - input.height - 12;
		history.height = history.textHeight + 6;
		history.y = (typing ? input.y : stageHeight - 12) - history.height - 4;
	}
}
