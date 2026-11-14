package funkin.input;

// (V-Slice's own imports, from its funkin/import.hx: this file is V-Slice's)
#if !macro
import funkin.util.Constants;
import funkin.Assets;
import funkin.Paths;
import funkin.Preferences;
import flixel.FlxG;
import haxe.ds.Option;

using Lambda;
using StringTools;
using thx.Arrays;
using funkin.util.tools.ArraySortTools;
using funkin.util.tools.ArrayTools;
using funkin.util.tools.FloatTools;
using funkin.util.tools.Int64Tools;
using funkin.util.tools.IntTools;
using funkin.util.tools.IteratorTools;
using funkin.util.tools.MapTools;
using funkin.util.tools.SongEventDataArrayTools;
using funkin.util.tools.SongNoteDataArrayTools;
using funkin.util.tools.StringTools;
using funkin.util.AnsiUtil;
#end

import flixel.FlxBasic;
import funkin.input.Controls.Action;

/**
 * Handles repeating behavior when holding down a control action.
 *
 * When the `action` is pressed, `activated` will be true for the first frame,
 * then wait `delay` seconds before becoming true for one frame every `interval` seconds.
 *
 * Example: Pressing Ctrl+Z will undo, while holding Ctrl+Z will start to undo repeatedly.
 */
@:nullSafety
class TurboActionHandler extends FlxBasic
{
  /**
   * Default delay before repeating.
   */
  static inline final DEFAULT_DELAY:Float = 0.4;

  /**
   * Default interval between repeats.
   */
  static inline final DEFAULT_INTERVAL:Float = 0.1;

  /**
   * Whether the action for this handler is pressed.
   */
  public var pressed(get, never):Bool;

  /**
   * Whether the action for this handler is pressed,
   * and the handler is ready to repeat.
   */
  public var activated(default, null):Bool = false;

  /**
   * The Funkin Controls handler.
   */
  var controls(get, never):Controls;

  function get_controls():Controls
  {
    return PlayerSettings.player1.controls;
  }

  var action:Action;
  var delay:Float;
  var interval:Float;
  var gamepadOnly:Bool;
  var pressedTime:Float = 0;

  function new(action:Action, delay:Float = DEFAULT_DELAY, interval:Float = DEFAULT_INTERVAL, gamepadOnly:Bool = false)
  {
    super();
    this.action = action;
    this.delay = delay;
    this.interval = interval;
    this.gamepadOnly = gamepadOnly;
  }

  function get_pressed():Bool
  {
    return controls.check(action, PRESSED, gamepadOnly);
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (pressed)
    {
      if (pressedTime == 0)
      {
        activated = true;
      }
      else if (pressedTime >= (delay + interval))
      {
        activated = true;
        pressedTime -= interval;
      }
      else
      {
        activated = false;
      }
      pressedTime += elapsed;
    }
    else
    {
      pressedTime = 0;
      activated = false;
    }
  }

  /**
   * Builds a TurboActionHandler that monitors from a single key.
   * @param inputKey The key to monitor.
   * @param delay How long to wait before repeating.
   * @param repeatDelay How long to wait between repeats.
   * @return A TurboActionHandler
   */
  overload public static extern inline function build(action:Action, ?delay:Float = DEFAULT_DELAY, ?interval:Float = DEFAULT_INTERVAL,
      ?gamepadOnly:Bool = false):TurboActionHandler
  {
    return new TurboActionHandler(action, delay, interval);
  }
}
