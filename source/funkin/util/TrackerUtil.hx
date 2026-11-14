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

// This may or may not already be imported via imports.hx...
import flixel.system.debug.watch.Tracker;
import flixel.FlxG;

/**
 * Utility class that helps manage adding profiles to the flixel debugger tracker
 */
@:nullSafety
class TrackerUtil
{
  /**
   * Adds profiles to the debugger to help track certain game objects.
   * NOTE: This isn't the full list of profiles made, as sometimes they're made
   * on in various places in code for random debugging purposes!
   * Might be good to put them all here though!
   */
  public static function initTrackers():Void
  {
    #if FLX_DEBUG
    Tracker.addProfile(new TrackerProfile(Highscore, ['tallies']));
    FlxG.console.registerClass(Highscore);
    #end
  }
}
