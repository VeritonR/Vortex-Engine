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
 * A utility class to get information about the mem usage.
 */
@:build(funkin.util.macro.LinkerMacro.xml('project/Build.xml')) @:include('MemoryUtil.hpp') @:unreflective
extern class MemoryUtil
{
  /**
   * Retrieves the current process's resident set size (RSS) in bytes on Apple platforms.
   *
   * @return The resident set size (RSS) in bytes if successful; otherwise, returns 0 on failure.
   */
  @:native('Apple_MemoryUtil_GetCurrentProcessRss')
  static function getCurrentProcessRss():cpp.SizeT;
}
#end
