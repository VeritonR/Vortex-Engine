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

#if ios
/**
 * Utility class for keyboard detection.
 */
@:build(funkin.util.macro.LinkerMacro.xml('project/Build.xml')) @:include('KeyboardUtil.hpp') @:unreflective
extern class KeyboardUtil
{
  /**
   * Retrieves whether a hardware keyboard is connected to the device.
   *
   * Works on iOS 16.4 and later.
   *
   * @return Returns a Boolean value that indicates whether someone is likely to enter text using a hardware keyboard.
   */
  @:native('Apple_KeyboardUtil_isKeyboardConnected')
  static function isKeyboardConnected():Bool;
}
#end
