package backend;

import flixel.input.gamepad.FlxGamepadButton;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.mappings.FlxGamepadMapping;
import flixel.input.keyboard.FlxKey;

class Controls
{
	//Keeping same use cases on stuff for it to be easier to understand/use
	//I'd have removed it but this makes it a lot less annoying to use in my opinion

	//You do NOT have to create these variables/getters for adding new keys,
	//but you will instead have to use:
	//   controls.justPressed("ui_up")   instead of   controls.UI_UP

	//Dumb but easily usable code, or Smart but complicated? Your choice.
	//Also idk how to use macros they're weird as fuck lol

	// Pressed buttons (directions)
	public var UI_UP_P(get, never):Bool;
	public var UI_DOWN_P(get, never):Bool;
	public var UI_LEFT_P(get, never):Bool;
	public var UI_RIGHT_P(get, never):Bool;
	public var NOTE_UP_P(get, never):Bool;
	public var NOTE_DOWN_P(get, never):Bool;
	public var NOTE_LEFT_P(get, never):Bool;
	public var NOTE_RIGHT_P(get, never):Bool;
	private function get_UI_UP_P() return justPressed('ui_up');
	private function get_UI_DOWN_P() return justPressed('ui_down');
	private function get_UI_LEFT_P() return justPressed('ui_left');
	private function get_UI_RIGHT_P() return justPressed('ui_right');
	private function get_NOTE_UP_P() return justPressed('note_up');
	private function get_NOTE_DOWN_P() return justPressed('note_down');
	private function get_NOTE_LEFT_P() return justPressed('note_left');
	private function get_NOTE_RIGHT_P() return justPressed('note_right');

	// Held buttons (directions)
	public var UI_UP(get, never):Bool;
	public var UI_DOWN(get, never):Bool;
	public var UI_LEFT(get, never):Bool;
	public var UI_RIGHT(get, never):Bool;
	public var NOTE_UP(get, never):Bool;
	public var NOTE_DOWN(get, never):Bool;
	public var NOTE_LEFT(get, never):Bool;
	public var NOTE_RIGHT(get, never):Bool;
	private function get_UI_UP() return pressed('ui_up');
	private function get_UI_DOWN() return pressed('ui_down');
	private function get_UI_LEFT() return pressed('ui_left');
	private function get_UI_RIGHT() return pressed('ui_right');
	private function get_NOTE_UP() return pressed('note_up');
	private function get_NOTE_DOWN() return pressed('note_down');
	private function get_NOTE_LEFT() return pressed('note_left');
	private function get_NOTE_RIGHT() return pressed('note_right');

	// Released buttons (directions)
	public var UI_UP_R(get, never):Bool;
	public var UI_DOWN_R(get, never):Bool;
	public var UI_LEFT_R(get, never):Bool;
	public var UI_RIGHT_R(get, never):Bool;
	public var NOTE_UP_R(get, never):Bool;
	public var NOTE_DOWN_R(get, never):Bool;
	public var NOTE_LEFT_R(get, never):Bool;
	public var NOTE_RIGHT_R(get, never):Bool;
	private function get_UI_UP_R() return justReleased('ui_up');
	private function get_UI_DOWN_R() return justReleased('ui_down');
	private function get_UI_LEFT_R() return justReleased('ui_left');
	private function get_UI_RIGHT_R() return justReleased('ui_right');
	private function get_NOTE_UP_R() return justReleased('note_up');
	private function get_NOTE_DOWN_R() return justReleased('note_down');
	private function get_NOTE_LEFT_R() return justReleased('note_left');
	private function get_NOTE_RIGHT_R() return justReleased('note_right');


	// Pressed buttons (others)
	public var ACCEPT(get, never):Bool;
	public var BACK(get, never):Bool;
	public var PAUSE(get, never):Bool;
	public var RESET(get, never):Bool;
	private function get_ACCEPT() return justPressed('accept');
	private function get_BACK() return justPressed('back');
	private function get_PAUSE() return justPressed('pause');
	private function get_RESET() return justPressed('reset');

	// What V-Slice scripts ask its Controls for

	// (V-Slice has a key of its own to go on with a cutscene, here it's the one that accepts things)
	public var CUTSCENE_ADVANCE(get, never):Bool;
	private function get_CUTSCENE_ADVANCE() return justPressed('accept');

	/**
	 * Name of the key something is done with, for the texts that tell the player about it: "Skip [ ENTER ]".
	 * It's given as the name V-Slice knows the thing by ("CUTSCENE_ADVANCE", "ACCEPT", "BACK", "PAUSE", "RESET", "UI_UP", "NOTE_LEFT"...).
	 */
	public function getDialogueNameFromToken(token:String, ?shorten:Bool):String
	{
		var name:String = (token != null) ? token.toLowerCase() : '';
		switch(name)
		{
			case 'cutscene_advance': name = 'accept';
			case 'freeplay_favorite': name = 'accept';
		}

		var keys:Array<FlxKey> = (keyboardBinds != null) ? keyboardBinds.get(name) : null;
		if(keys == null || keys.length < 1) return '???';

		for (key in keys)
			if(key != FlxKey.NONE)
				return InputFormatter.getKeyName(key).toUpperCase();
		return '???';
	}

	public function getDialogueNameFromControl(control:Dynamic, ?shorten:Bool):String
	{
		return getDialogueNameFromToken(Std.string(control), shorten);
	}

	//Gamepad & Keyboard stuff
	public var keyboardBinds:Map<String, Array<FlxKey>>;
	public var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;
	public function justPressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustPressed(gamepadBinds[key]) == true || TouchControls.justPressed(key);
	}

	public function pressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadPressed(gamepadBinds[key]) == true || TouchControls.pressed(key);
	}

	public function justReleased(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustReleased(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustReleased(gamepadBinds[key]) == true || TouchControls.justReleased(key);
	}

	// ------------------------------------------------------------------------------------------
	// V-Slice's names of the controls (its PlayerSettings.player1.controls), for its classes and scripts: "_P" is just pressed and
	// "_R" just released. Its own actions the engine has no bind for are on V-Slice's default keys.
	// ------------------------------------------------------------------------------------------

	public var ACCEPT_P(get, never):Bool; function get_ACCEPT_P():Bool return justPressed('accept');
	public var ACCEPT_R(get, never):Bool; function get_ACCEPT_R():Bool return justReleased('accept');
	public var BACK_P(get, never):Bool; function get_BACK_P():Bool return justPressed('back');
	public var BACK_R(get, never):Bool; function get_BACK_R():Bool return justReleased('back');
	public var PAUSE_P(get, never):Bool; function get_PAUSE_P():Bool return justPressed('pause');
	public var PAUSE_R(get, never):Bool; function get_PAUSE_R():Bool return justReleased('pause');
	public var RESET_P(get, never):Bool; function get_RESET_P():Bool return justPressed('reset');
	public var RESET_R(get, never):Bool; function get_RESET_R():Bool return justReleased('reset');

	public var VOLUME_UP(get, never):Bool; function get_VOLUME_UP():Bool return justPressed('volume_up');
	public var VOLUME_DOWN(get, never):Bool; function get_VOLUME_DOWN():Bool return justPressed('volume_down');
	public var VOLUME_MUTE(get, never):Bool; function get_VOLUME_MUTE():Bool return justPressed('volume_mute');

	public var FREEPLAY_FAVORITE(get, never):Bool; function get_FREEPLAY_FAVORITE():Bool return FlxG.keys.justPressed.F;
	public var FREEPLAY_LEFT(get, never):Bool; function get_FREEPLAY_LEFT():Bool return FlxG.keys.justPressed.Q;
	public var FREEPLAY_RIGHT(get, never):Bool; function get_FREEPLAY_RIGHT():Bool return FlxG.keys.justPressed.E;
	public var FREEPLAY_CHAR_SELECT(get, never):Bool; function get_FREEPLAY_CHAR_SELECT():Bool return FlxG.keys.justPressed.TAB;
	public var FREEPLAY_JUMP_TO_TOP(get, never):Bool; function get_FREEPLAY_JUMP_TO_TOP():Bool return FlxG.keys.justPressed.HOME;
	public var FREEPLAY_JUMP_TO_BOTTOM(get, never):Bool; function get_FREEPLAY_JUMP_TO_BOTTOM():Bool return FlxG.keys.justPressed.END;
	public var WINDOW_FULLSCREEN(get, never):Bool; function get_WINDOW_FULLSCREEN():Bool return FlxG.keys.justPressed.F11;
	public var WINDOW_SCREENSHOT(get, never):Bool; function get_WINDOW_SCREENSHOT():Bool return FlxG.keys.justPressed.F3;
	public var DEBUG_MENU(get, never):Bool; function get_DEBUG_MENU():Bool return FlxG.keys.justPressed.GRAVEACCENT;
	public var DEBUG_CHART(get, never):Bool; function get_DEBUG_CHART():Bool return false;
	public var DEBUG_STAGE(get, never):Bool; function get_DEBUG_STAGE():Bool return false;
	public var DEBUG_DISPLAY(get, never):Bool; function get_DEBUG_DISPLAY():Bool return FlxG.keys.justPressed.F6;

	/**
	 * V-Slice's way of asking about a control: one of its actions ("note_left", "ui_up", "accept"...), and how it's being pressed.
	 */
	public function check(action:Dynamic, ?state:flixel.input.FlxInput.FlxInputState, gamepadOnly:Bool = false):Bool
	{
		var key:String = (action != null) ? Std.string(action) : '';
		if(key == 'cutscene_advance') key = 'accept';
		if(state == null) state = JUST_PRESSED;
		if(keyboardBinds == null || !keyboardBinds.exists(key)) return false;
		if(gamepadOnly)
		{
			return switch(state)
			{
				case PRESSED: _myGamepadPressed(gamepadBinds[key]) == true;
				case JUST_RELEASED: _myGamepadJustReleased(gamepadBinds[key]) == true;
				case RELEASED: _myGamepadPressed(gamepadBinds[key]) != true;
				default: _myGamepadJustPressed(gamepadBinds[key]) == true;
			}
		}
		return switch(state)
		{
			case PRESSED: pressed(key);
			case JUST_RELEASED: justReleased(key);
			case RELEASED: !pressed(key);
			default: justPressed(key);
		}
	}

	public var controllerMode:Bool = false;
	private function _myGamepadJustPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadJustReleased(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustReleased(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}

	// IGNORE THESE
	public static var instance:Controls;
	public function new()
	{
		keyboardBinds = ClientPrefs.keyBinds;
		gamepadBinds = ClientPrefs.gamepadBinds;
	}
}