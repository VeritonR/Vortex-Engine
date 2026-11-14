package funkin.external.apple;

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

#if ((ios || macos) && cpp)
/**
 * A utility class to manage the audio session on apple devices.
 */
@:build(funkin.util.macro.LinkerMacro.xml('project/Build.xml')) @:include('AudioSession.hpp') @:unreflective
extern class AudioSession
{
  /**
   * Initializes the audio session for playback.
   *
   * This function configures the shared AVAudioSession instance with the following settings:
   * - Sets the audio session category to Playback, allowing Bluetooth A2DP and mixing with spoken audio interruptions.
   * - For iOS 17.0 and above, disables interruption on route disconnect.
   * - For iOS 14.5 and above, prefers no interruptions from system alerts.
   */
  @:native('Apple_AudioSession_Initialize')
  static function initialize():Void;

  /**
   * Sets the active state of the shared AVAudioSession.
   *
   * @param active Whether to activate or deactivate the audio session.
   */
  @:native('Apple_AudioSession_SetActive')
  static function setActive(active:Bool):Void;
}
#end
