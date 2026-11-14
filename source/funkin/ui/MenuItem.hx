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

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import funkin.util.MathUtil;
import flixel.util.FlxColor;

@:nullSafety
class MenuItem extends FlxSpriteGroup
{
  public var targetY:Float = 0;
  public var week:FlxSprite;

  public function new(x:Float, y:Float, weekNum:Int = 0, weekType:WeekType)
  {
    super(x, y);

    var weekStr:String = switch (weekType)
    {
      case WEEK:
        'week';
      case WEEKEND:
        'weekend';
    }

    week = new FlxSprite().loadGraphic(Paths.image('storymenu/' + weekStr + weekNum));
    add(week);
  }

  var isFlashing:Bool = false;
  var flashTick:Float = 0;
  final flashFramerate:Float = 20;

  public function startFlashing():Void
  {
    isFlashing = true;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    y = MathUtil.smoothLerpPrecision(y, (targetY * 120) + 480, elapsed, 0.451);

    if (isFlashing)
    {
      flashTick += elapsed;
      if (flashTick >= 1 / flashFramerate)
      {
        flashTick %= 1 / flashFramerate;
        week.color = (week.color == FlxColor.WHITE) ? 0xFF33FFFF : FlxColor.WHITE;
      }
    }
  }
}

enum abstract WeekType(String) to String
{
  public var WEEK;
  public var WEEKEND;
}
