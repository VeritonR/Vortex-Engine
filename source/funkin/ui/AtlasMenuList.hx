package funkin.ui;

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

import funkin.ui.AtlasMenuItem;
// (its items are the engine's AtlasMenuItem, see funkin/ui/AtlasMenuItem.hx)

import flixel.graphics.frames.FlxAtlasFrames;
import funkin.ui.MenuList;

typedef AtlasAsset = flixel.util.typeLimit.OneOfTwo<String, FlxAtlasFrames>;

/**
 * A menulist whose items share a single texture atlas.
 */
class AtlasMenuList extends MenuTypedList<AtlasMenuItem>
{
  public var atlas:Null<FlxAtlasFrames>;

  public function new(atlas, navControls:NavControls = Vertical, ?wrapMode)
  {
    super(navControls, wrapMode);

    if (Std.isOfType(atlas, String)) this.atlas = Paths.getSparrowAtlas(cast atlas);
    else
      this.atlas = cast atlas;
  }

  public function createItem(x = 0.0, y = 0.0, name, callback, fireInstantly = false)
  {
    var item = new AtlasMenuItem(x, y, name, atlas, callback);
    item.fireInstantly = fireInstantly;
    return addItem(name, item);
  }

  override function destroy()
  {
    super.destroy();
    atlas = null;
  }
}
