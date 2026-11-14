package funkin.graphics.shaders;

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

import flixel.addons.display.FlxRuntimeShader;

/**
 * Note... not actually gaussian!
 */
@:nullSafety
class GaussianBlurShader extends FlxRuntimeShader
{
  public var amount:Float = 1;

  public function new(amount:Float = 1.0)
  {
    super(Assets.getText(Paths.frag('gaussianBlur')));
    setAmount(amount);
  }

  public function setAmount(value:Float):Void
  {
    this.amount = value;
    this.setFloat('_amount', amount);
  }
}
