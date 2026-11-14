package funkin.audio.visualize;

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

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;

@:nullSafety
class PolygonVisGroup extends FlxTypedGroup<PolygonSpectogram>
{
  public var playerVis:Null<PolygonSpectogram>;
  public var opponentVis:Null<PolygonSpectogram>;
  public var instVis:Null<PolygonSpectogram>;

  public function new()
  {
    super();
    playerVis = new PolygonSpectogram();
    opponentVis = new PolygonSpectogram();
  }

  /**
   * Adds the player's visualizer to the group.
   * @param visSnd The visualizer to add.
   */
  public function addPlayerVis(visSnd:FlxSound):Void
  {
    var vis:PolygonSpectogram = new PolygonSpectogram(visSnd);
    super.add(vis);
    playerVis = vis;
  }

  /**
   * Adds the opponent's visualizer to the group.
   * @param visSnd The visualizer to add.
   */
  public function addOpponentVis(visSnd:FlxSound):Void
  {
    var vis:PolygonSpectogram = new PolygonSpectogram(visSnd);
    super.add(vis);
    opponentVis = vis;
  }

  /**
   * Adds the instrument's visualizer to the group.
   * @param visSnd The visualizer to add.
   */
  public function addInstVis(visSnd:FlxSound):Void
  {
    var vis:PolygonSpectogram = new PolygonSpectogram(visSnd);
    super.add(vis);
    instVis = vis;
  }

  public function clearPlayerVis():Void
  {
    if (playerVis != null)
    {
      remove(playerVis);
      playerVis.destroy();
      playerVis = null;
    }
  }

  public function clearOpponentVis():Void
  {
    if (opponentVis != null)
    {
      remove(opponentVis);
      opponentVis.destroy();
      opponentVis = null;
    }
  }

  public function clearInstVis():Void
  {
    if (instVis != null)
    {
      remove(instVis);
      instVis.destroy();
      instVis = null;
    }
  }

  public function clearAllVis():Void
  {
    clearPlayerVis();
    clearOpponentVis();
    clearInstVis();
  }

  /**
   * Overrides the add function to add a visualizer to the group.
   * @param vis The visualizer to add.
   * @return The added visualizer.
   */
  override public function add(vis:PolygonSpectogram):PolygonSpectogram
  {
    var result:PolygonSpectogram = super.add(vis);
    return result;
  }

  override public function destroy():Void
  {
    if (playerVis != null)
    {
      playerVis.destroy();
    }
    if (opponentVis != null)
    {
      opponentVis.destroy();
    }
    super.destroy();
  }
}
