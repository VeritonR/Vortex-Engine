package funkin.util;

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

#if FEATURE_HAXEUI
import haxe.ui.tooltips.ToolTipRegionOptions;

/**
 * Utility functions for working with HaxeUI.
 */
@:nullSafety
class HaxeUIUtil
{
  /**
   * Builds a ToolTipRegionOptions object with the specified text and positioning parameters.
   *
   * @param text The text to display in the tooltip.
   * @param left The left position of the tooltip.
   * @param top The top position of the tooltip.
   * @param width The width of the tooltip.
   * @param height The height of the tooltip.
   * @return A ToolTipRegionOptions object configured with the provided parameters.
   */
  public static function buildTooltip(text:String, left:Float = 0.0, top:Float = 0.0, width:Float = 0.0, height:Float = 0.0):ToolTipRegionOptions
  {
    return {
      tipData: {text: text},
      left: left,
      top: top,
      width: width,
      height: height
    }
  }
}
#end
