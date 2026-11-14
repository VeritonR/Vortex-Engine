package funkin.data;

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

/**
 * An interface defining the necessary functions for a registry entry.
 * A `String->Void` constructor is also mandatory, but enforced elsewhere.
 * @param T The JSON data type of the registry entry.
 */
@:autoBuild(funkin.util.macro.RegistryMacro.buildEntry())
interface IRegistryEntry<T>
{
  public final id:String;
  // public function new(id:String):Void;
  public function destroy():Void;
  public function toString():String;
  // Can't make an interface field private I guess.
  public final _data:T;
  // Can't make a static field required by an interface I guess.
  // private static function _fetchData(id:String):Null<T>;
}
