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
 * A utility class to get screen related informations on apple devices.
 */
@:build(funkin.util.macro.LinkerMacro.xml('project/Build.xml')) @:include('ScreenUtil.hpp') @:unreflective
extern class ScreenUtil
{
  /**
   * Retrieves the safe area insets for the current screen on iOS devices.
   *
   * This function populates the provided pointers with the safe area insets (in pixels) for the top, bottom, left, and right edges of the screen.
   * On iOS 11 and later, it uses the main window's safeAreaInsets and converts them to pixel values using the screen scale.
   * On earlier iOS versions, all insets are set to 0.0.
   *
   * @param top Pointer to a double to receive the top safe area inset (in pixels).
   * @param bottom Pointer to a double to receive the bottom safe area inset (in pixels).
   * @param left Pointer to a double to receive the left safe area inset (in pixels).
   * @param right Pointer to a double to receive the right safe area inset (in pixels).
   */
  @:native('Apple_ScreenUtil_GetSafeAreaInsets')
  static function getSafeAreaInsets(top:cpp.RawPointer<Float>, bottom:cpp.RawPointer<Float>, left:cpp.RawPointer<Float>, right:cpp.RawPointer<Float>):Void;

  /**
   * Retrieves the size of the main screen in pixels.
   *
   * @param width  Pointer to a double where the screen width (in pixels) will be stored.
   * @param height Pointer to a double where the screen height (in pixels) will be stored.
   */
  @:native('Apple_ScreenUtil_GetScreenSize')
  static function getScreenSize(width:cpp.RawPointer<Float>, height:cpp.RawPointer<Float>):Void;
}
#end
