package funkin.input;

import flixel.input.FlxInput.FlxInputState;
import flixel.input.actions.FlxActionInput;
import flixel.input.actions.FlxAction.FlxActionDigital;
// (V-Slice's Controls is the engine's, scripts get the same one)
typedef Controls = backend.Controls;

// (V-Slice's, for scripts: see the import of it on V-Slice)
/**
 * Since, in many cases multiple actions should use similar keys, we don't want the
 * rebinding UI to list every action. ActionBinders are what the user perceives as
 * an input so, for instance, they can't set jump-press and jump-release to different keys.
 */
enum Control
{
	// NOTE
	NOTE_LEFT;
	NOTE_DOWN;
	NOTE_UP;
	NOTE_RIGHT;
	// UI
	UI_LEFT;
	UI_DOWN;
	UI_UP;
	UI_RIGHT;
	ACCEPT;
	BACK;
	PAUSE;
	RESET;
	// CUTSCENE
	CUTSCENE_ADVANCE;
	// FREEPLAY
	FREEPLAY_FAVORITE;
	FREEPLAY_LEFT;
	FREEPLAY_RIGHT;
	FREEPLAY_CHAR_SELECT;
	FREEPLAY_JUMP_TO_TOP;
	FREEPLAY_JUMP_TO_BOTTOM;
	// WINDOW
	#if FEATURE_SCREENSHOTS WINDOW_SCREENSHOT; #end
	WINDOW_FULLSCREEN;
	// VOLUME
	VOLUME_UP;
	VOLUME_DOWN;
	VOLUME_MUTE;
	// DEBUG
	#if FEATURE_DEBUG_MENU DEBUG_MENU; #end
	#if FEATURE_CHART_EDITOR DEBUG_CHART; #end
	#if FEATURE_STAGE_EDITOR DEBUG_STAGE; #end
	DEBUG_DISPLAY;
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum abstract Action(String) to String from String
{
	// NOTE
	public var NOTE_UP = 'note_up';
	public var NOTE_LEFT = 'note_left';
	public var NOTE_RIGHT = 'note_right';
	public var NOTE_DOWN = 'note_down';
	// UI
	public var UI_UP = 'ui_up';
	public var UI_LEFT = 'ui_left';
	public var UI_RIGHT = 'ui_right';
	public var UI_DOWN = 'ui_down';
	public var ACCEPT = 'accept';
	public var BACK = 'back';
	public var PAUSE = 'pause';
	public var RESET = 'reset';
	// WINDOW
	public var WINDOW_FULLSCREEN = 'window_fullscreen';
	#if FEATURE_SCREENSHOTS
	var WINDOW_SCREENSHOT = 'window_screenshot';
	#end
	// CUTSCENE
	public var CUTSCENE_ADVANCE = 'cutscene_advance';
	// FREEPLAY
	public var FREEPLAY_FAVORITE = 'freeplay_favorite';
	public var FREEPLAY_LEFT = 'freeplay_left';
	public var FREEPLAY_RIGHT = 'freeplay_right';
	public var FREEPLAY_CHAR_SELECT = 'freeplay_char_select';
	public var FREEPLAY_JUMP_TO_TOP = 'freeplay_jump_to_top';
	public var FREEPLAY_JUMP_TO_BOTTOM = 'freeplay_jump_to_bottom';
	// VOLUME
	public var VOLUME_UP = 'volume_up';
	public var VOLUME_DOWN = 'volume_down';
	public var VOLUME_MUTE = 'volume_mute';
	// DEBUG
	#if FEATURE_DEBUG_MENU
	var DEBUG_MENU = 'debug_menu';
	#end
	#if FEATURE_CHART_EDITOR
	var DEBUG_CHART = 'debug_chart';
	#end
	#if FEATURE_STAGE_EDITOR
	var DEBUG_STAGE = 'debug_stage';
	#end
	public var DEBUG_DISPLAY = 'debug_display';
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum Device
{
	Keys;
	Gamepad(id:Int);
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum KeyboardScheme
{
	Solo;
	Duo(first:Bool);
	None;
	Custom;
}

// (V-Slice's, for its classes and scripts)
/**
 * An FlxActionDigital with additional functionality, including:
 * - Combining `pressed` and `released` inputs into one action.
 * - Filtering by input method (`KEYBOARD`, `MOUSE`, `GAMEPAD`, etc).
 */
class FunkinAction extends FlxActionDigital
{
  public var namePressed(default, null):Null<String>;
  public var nameReleased(default, null):Null<String>;

  var cache:Map<String,
    {timestamp:Float, value:Bool}> = [];

  public function new(?name:String = '', ?namePressed:String, ?nameReleased:String)
  {
    super(name);

    this.namePressed = namePressed;
    this.nameReleased = nameReleased;

    updateLastDeviceUsed();
  }

  /**
   * Input checks default to whether the input was just pressed, on any input device.
   */
  override public function check():Bool
  {
    return checkFiltered(JUST_PRESSED);
  }

  /**
   * Check whether the input is currently being held.
   */
  public function checkPressed():Bool
  {
    if (checkFiltered(PRESSED)) updateLastDeviceUsed();
    return checkFiltered(PRESSED);
  }

  /**
   * Check whether the input is currently being held, and was not held last frame.
   */
  public function checkJustPressed():Bool
  {
    if (checkFiltered(JUST_PRESSED)) updateLastDeviceUsed();
    return checkFiltered(JUST_PRESSED);
  }

  /**
   * Check whether the input is not currently being held.
   */
  public function checkReleased():Bool
  {
    return checkFiltered(RELEASED);
  }

  /**
   * Check whether the input is not currently being held, and was held last frame.
   */
  public function checkJustReleased():Bool
  {
    if (checkFiltered(JUST_RELEASED)) updateLastDeviceUsed();
    return checkFiltered(JUST_RELEASED);
  }

  /**
   * Check whether the input is currently being held by a gamepad device.
   */
  public function checkPressedGamepad():Bool
  {
    return checkFiltered(PRESSED, GAMEPAD);
  }

  /**
   * Check whether the input is currently being held by a gamepad device, and was not held last frame.
   */
  public function checkJustPressedGamepad():Bool
  {
    return checkFiltered(JUST_PRESSED, GAMEPAD);
  }

  /**
   * Check whether the input is not currently being held by a gamepad device.
   */
  public function checkReleasedGamepad():Bool
  {
    return checkFiltered(RELEASED, GAMEPAD);
  }

  /**
   * Check whether the input is not currently being held by a gamepad device, and was held last frame.
   */
  public function checkJustReleasedGamepad():Bool
  {
    return checkFiltered(JUST_RELEASED, GAMEPAD);
  }

  public function checkMultiFiltered(?filterTriggers:Array<FlxInputState>, ?filterDevices:Array<FlxInputDevice>):Bool
  {
    filterTriggers ??= [PRESSED, JUST_PRESSED];
    filterDevices ??= [];

    // Perform checkFiltered for each combination.
    for (i in filterTriggers)
    {
      if (filterDevices.length == 0)
      {
        if (checkFiltered(i))
        {
          return true;
        }
      }
      else
      {
        for (j in filterDevices)
        {
          if (checkFiltered(i, j))
          {
            return true;
          }
        }
      }
    }
    return false;
  }

  /**
   * Performs the functionality of `FlxActionDigital.check()`, but with optional filters.
   * @param action The action to check for.
   * @param filterTrigger Optionally filter by trigger condition (`JUST_PRESSED`, `PRESSED`, `JUST_RELEASED`, `RELEASED`).
   * @param filterDevice Optionally filter by device (`KEYBOARD`, `MOUSE`, `GAMEPAD`, `OTHER`).
   * @return bool if our input has been triggered
   */
  public function checkFiltered(?filterTrigger:FlxInputState, ?filterDevice:FlxInputDevice):Bool
  {
    // Make sure we only update the inputs once per frame.
    var key = '${filterTrigger}:${filterDevice}';
    var cacheEntry = cache.get(key);

    if (cacheEntry != null && cacheEntry.timestamp == FlxG.game.ticks)
    {
      return cacheEntry.value;
    }

    _x = null;
    _y = null;

    _timestamp = FlxG.game.ticks;
    triggered = false;

    var i = inputs?.length ?? 0;
    while (i-- > 0) // Iterate backwards, since we may remove items
    {
      var input = inputs[i];

      // Filter out dead inputs.
      if (input.destroyed)
      {
        inputs.remove(input);
        continue;
      }

      // Update the input.
      input.update();

      // Check whether the input is the right trigger.
      if (filterTrigger != null && input.trigger != filterTrigger)
      {
        continue;
      }

      // Check whether the input is the right device.
      if (filterDevice != null && input.device != filterDevice)
      {
        continue;
      }

      // Check whether the input has triggered.
      if (input.check(this))
      {
        triggered = true;
      }
    }

    cache.set(key, {timestamp: FlxG.game.ticks, value: triggered});

    return triggered;
  }

  public static var lastDeviceUsed:FlxInputDevice;

  /**
   * Checks which is the last device you have used and stores the value in `lastDeviceUsed`.
   */
  public function updateLastDeviceUsed()
  {
    if (FlxG.keys.pressed.ANY)
    {
      lastDeviceUsed = FlxInputDevice.KEYBOARD;
      return;
    }

    if (FlxG.gamepads.lastActive != null)
    {
      lastDeviceUsed = FlxInputDevice.GAMEPAD;
      return;
    }

    // Default value (just in case everything's null somehow)
    lastDeviceUsed = FlxInputDevice.KEYBOARD;
  }
}
