package funkin.data.freeplay.style;

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

import funkin.data.animation.AnimationData;

/**
 * A type definition for the data for an album of songs.
 * It includes things like what graphics to display in Freeplay.
 * @see https://lib.haxe.org/p/json2object/
 */
typedef FreeplayStyleData =
{
  /**
   * Semantic version for style data.
   */
  public var version:String;

  /**
   * Asset key for the background image.
   */
  public var bgAsset:String;

  /**
   * Asset key for the difficulty selector image.
   */
  public var selectorAsset:String;

  /**
   * Asset key for the numbers shown at the top right of the screen.
   */
  public var numbersAsset:String;

  /**
   * Asset key for the freeplay capsules.
   */
  public var capsuleAsset:String;

  /**
   * Color data for the capsule text outline.
   * the order of this array goes as follows: [DESELECTED, SELECTED]
   */
  public var capsuleTextColors:Array<String>;

  /**
   * Delay time after confirming a song selection, before entering PlayState.
   * Useful for letting longer animations play out.
   */
  public var startDelay:Float;
}
