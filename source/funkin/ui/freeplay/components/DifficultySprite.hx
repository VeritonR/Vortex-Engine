package funkin.ui.freeplay.components;

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

import flixel.FlxSprite;

/**
 * The sprite for the difficulty
 */
@:nullSafety
class DifficultySprite extends FlxSprite
{
  public var difficultyId:String;

  public function new(diffId:String)
  {
    super();

    this.difficultyId = diffId;

    var assetDiffId:String = diffId;
    while (!Assets.exists(Paths.image('freeplay/freeplay${assetDiffId}')))
    {
      // Remove the last suffix of the difficulty id until we find an asset or there are no more suffixes.
      var assetDiffIdParts:Array<String> = assetDiffId.split('-');
      assetDiffIdParts.pop();
      if (assetDiffIdParts.length == 0)
      {
        trace('Could not find difficulty asset: freeplay/freeplay${diffId} (from ${diffId})');
        return;
      };
      assetDiffId = assetDiffIdParts.join('-');
    }

    // Check for an XML to use an animation instead of an image.
    if (Assets.exists(Paths.file('images/freeplay/freeplay${assetDiffId}.xml')))
    {
      this.frames = Paths.getSparrowAtlas('freeplay/freeplay${assetDiffId}');
      this.animation.addByPrefix('idle', 'idle0', 24, true);
      if (Preferences.flashingLights) this.animation.play('idle');
    }
    else
    {
      this.loadGraphic(Paths.image('freeplay/freeplay' + assetDiffId));
      trace('Loaded difficulty asset: freeplay/freeplay${assetDiffId} (from ${diffId})');
    }
  }
}
