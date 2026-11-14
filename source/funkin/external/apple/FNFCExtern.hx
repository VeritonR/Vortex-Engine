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
 * A utility class for FNFC loading on apple devices.
 */
@:build(funkin.util.macro.LinkerMacro.xml('project/Build.xml')) @:include('FNFCExtern.hpp') @:unreflective
extern class FNFCExtern
{
  /**
   * Copies the FNFC resource from the specified URL into the cache.
   *
   * @param url The URL of the FNFC resource to copy into the cache.
   * @param callback A function to be called when the copy operation completes.
   */
  @:native('Apple_FNFCExtern_CopyFNFCIntoCache')
  static function copyFNFCIntoCache(url:cpp.ConstCharStar, callback:cpp.Callable<(event:cpp.ConstCharStar, value:cpp.ConstCharStar) -> Void>):Void;
}
#end
