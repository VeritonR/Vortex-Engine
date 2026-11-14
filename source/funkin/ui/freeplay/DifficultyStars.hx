package funkin.ui.freeplay;

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

import flixel.group.FlxSpriteGroup;
import funkin.graphics.FunkinSprite;
import funkin.graphics.shaders.HSVShader;

@:nullSafety
class DifficultyStars extends FlxSpriteGroup
{
  /**
   * Internal handler var for difficulty... ranges from 0... to 15
   * 0 is 1 star... 15 is 0 stars!
   */
  var curDifficulty(default, set):Int = 0;

  /**
   * Range between 0 and 15
   */
  public var difficulty(default, set):Int = 1;

  public var stars:FunkinSprite;
  public var flames:FreeplayFlames;

  var hsvShader:HSVShader;

  public function new(x:Float, y:Float)
  {
    super(x, y);

    hsvShader = new HSVShader();

    flames = new FreeplayFlames(0, 0);

    stars = new FunkinSprite(0, 0).loadTextureAtlas("freeplay/freeplayStars"); //(the engine's createTextureAtlas() gives the atlas itself)
    stars.anim.play("diff stars");

    add(flames);
    add(stars);

    stars.shader = hsvShader;

    for (memb in flames.members) memb.shader = hsvShader;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    // "loops" the current animation
    // for clarity, the animation file looks like
    // frame : stars
    // 0-99: 1 star
    // 100-199: 2 stars
    // ......
    // 1300-1499: 15 stars
    // 1500 : 0 stars
    if (curDifficulty < 15 && stars.anim.curAnim.curFrame >= (curDifficulty + 1) * 100)
    {
      stars.anim.play("diff stars", true, false, curDifficulty * 100);
    }
  }

  function set_difficulty(value:Int):Int
  {
    difficulty = value;

    if (difficulty <= 0)
    {
      difficulty = 0;
      curDifficulty = 15;
    }
    else if (difficulty <= 15)
    {
      difficulty = value;
      curDifficulty = difficulty - 1;
    }
    else
    {
      difficulty = 15;
      curDifficulty = difficulty - 1;
    }

    flameCheck();

    return difficulty;
  }

  public function flameCheck():Void
  {
    if (difficulty > 10) flames.flameCount = difficulty - 10;
    else
      flames.flameCount = 0;
  }

  function set_curDifficulty(value:Int):Int
  {
    curDifficulty = value;

    if (curDifficulty == 15)
    {
      stars.anim.play("diff stars", true, false, 1500);
      stars.anim.pause();
    }
    else
    {
      stars.anim.curAnim.curFrame = Std.int(curDifficulty * 100);
      stars.anim.play("diff stars", true, false, curDifficulty * 100);
    }

    return curDifficulty;
  }
}
