package funkin.util.assets;

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

@:nullSafety
class DataAssets
{
  static function buildDataPath(path:String):String
  {
    return 'assets/data/${path}';
  }

  public static function listDataFilesInPath(path:String, suffix:String = '.json'):Array<String>
  {
    var textAssets = openfl.utils.Assets.list(TEXT);

    var queryPath = buildDataPath(path);

    var results:Array<String> = [];
    for (textPath in textAssets)
    {
      if (textPath.startsWith(queryPath) && textPath.endsWith(suffix))
      {
        var pathNoSuffix = textPath.substring(0, textPath.length - suffix.length);
        var pathNoPrefix = pathNoSuffix.substring(queryPath.length);

        // No duplicates! Why does this happen?
        if (!results.contains(pathNoPrefix)) results.push(pathNoPrefix);
      }
    }

    return results;
  }
}
