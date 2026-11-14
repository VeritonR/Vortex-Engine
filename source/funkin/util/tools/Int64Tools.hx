package funkin.util.tools;

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

import haxe.Int64;

/**
 * Why `haxe.Int64` doesn't have a built-in `toFloat` function is beyond me.
 */
@:nullSafety
class Int64Tools
{
  static inline var MAX_32_PRECISION:Float = 4294967296.0;

  public static function fromFloat(f:Float):Int64
  {
    var h = Std.int(f / MAX_32_PRECISION);
    var l = Std.int(f);
    return Int64.make(h, l);
  }

  public static function toFloat(i:Int64):Float
  {
    var f:Float = i.low;
    if (f < 0) f += MAX_32_PRECISION;
    return (i.high * MAX_32_PRECISION + f);
  }

  public static function isToIntSafe(i:Int64):Bool
  {
    return i.high != i.low >> 31;
  }

  public static function toIntSafe(i:Int64):Int
  {
    try
    {
      return Int64.toInt(i);
    }
    catch (e:Dynamic)
    {
      throw 'Could not represent value "${Int64.toStr(i)}" as an integer.';
    }
  }
}
