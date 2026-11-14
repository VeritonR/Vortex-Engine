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
 * A plugin which adds functionality to display several universally important values
 * in the Flixel variable watch window.
 */
class WatchPlugin extends FlxBasic
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
    FlxG.plugins.addPlugin(new WatchPlugin());
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);

    var stateClassName = Type.getClassName(Type.getClass(FlxG.state));
    FlxG.watch.addQuick('currentState', stateClassName);
    var subStateClassNames = [];
    var subState = FlxG.state.subState;
    while (subState != null)
    {
      subStateClassNames.push(Type.getClassName(Type.getClass(subState)));
      subState = subState.subState;
    }
    FlxG.watch.addQuick('currentSubStates', subStateClassNames.join(', '));

    FlxG.watch.addQuick('songPosition', Conductor.instance.songPosition);
    FlxG.watch.addQuick('songPositionNoOffset', Conductor.instance.songPosition + Conductor.instance.instrumentalOffset);

    FlxG.watch.addQuick('musicLength', FlxG.sound?.music?.length ?? 0.0);
    FlxG.watch.addQuick('musicTime', FlxG.sound?.music?.time ?? 0.0);

    FlxG.watch.addQuick('bpm', Conductor.instance.bpm);
    FlxG.watch.addQuick('currentMeasureTime', Conductor.instance.currentMeasureTime);
    FlxG.watch.addQuick('currentBeatTime', Conductor.instance.currentBeatTime);
    FlxG.watch.addQuick('currentStepTime', Conductor.instance.currentStepTime);
  }

  override public function destroy():Void
  {
    super.destroy();
  }
}
