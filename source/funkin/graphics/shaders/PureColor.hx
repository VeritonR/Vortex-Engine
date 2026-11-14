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

import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

class PureColor extends FlxShader
{
  public var col(default, set):FlxColor;
  public var colorSet(default, set):Bool;

  function set_colorSet(bol:Bool):Bool
  {
    colSet.value = [bol];

    return bol;
  }

  function set_col(val:FlxColor):FlxColor
  {
    funnyColor.value = [val.redFloat, val.greenFloat, val.blueFloat, val.alphaFloat];

    return val;
  }

  @:glFragmentSource('
        #pragma header

        uniform vec4 funnyColor;
        uniform bool colSet;

        void main()
        {
            vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

            if (color.a > 0.0 && colSet)
                color = funnyColor * color.a;

            gl_FragColor = color;
        }
    ')
  public function new(colr:FlxColor)
  {
    super();

    this.col = colr;
    this.colorSet = false;
  }
}
