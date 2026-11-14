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
 * Handles volume control in a way that is compatible with alternate control schemes.
 */
@:nullSafety
class VolumePlugin extends FlxBasic
{
  public function new()
  {
    super();
  }

  /**
   * Initialize the plugin.
   */
  public static function initialize():Void
  {
    FlxG.plugins.addPlugin(new VolumePlugin());
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var isHaxeUIFocused:Bool = #if FEATURE_HAXEUI haxe.ui.focus.FocusManager.instance?.focus != null #else false #end;

    if (!isHaxeUIFocused)
    {
      // Rebindable volume keys.
      if (PlayerSettings.player1.controls.VOLUME_MUTE) FlxG.sound.toggleMuted();
      else if (PlayerSettings.player1.controls.VOLUME_UP) FlxG.sound.changeVolume(0.1);
      else if (PlayerSettings.player1.controls.VOLUME_DOWN) FlxG.sound.changeVolume(-0.1);
    }
  }

  override public function destroy():Void
  {
    if (FlxG.plugins.list.contains(this)) FlxG.plugins.remove(this);

    super.destroy();
  }
}
