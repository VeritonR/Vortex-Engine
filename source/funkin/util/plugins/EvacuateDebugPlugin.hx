package funkin.util.plugins;

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

import flixel.FlxBasic;

/**
 * A plugin which adds functionality to press `F4` to immediately transition to the main menu.
 * This is useful for debugging or if you get softlocked or something.
 */
@:nullSafety
class EvacuateDebugPlugin extends FlxBasic
{
  public function new()
  {
    super();
  }

  public static function initialize():Void
  {
    FlxG.plugins.addPlugin(new EvacuateDebugPlugin());
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (FlxG.keys.justPressed.F4)
    {
      FlxG.switchState(() -> new funkin.ui.mainmenu.MainMenuState());
    }
  }

  override public function destroy():Void
  {
    super.destroy();
  }
}
