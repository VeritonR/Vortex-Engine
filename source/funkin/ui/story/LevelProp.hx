package funkin.ui.story;

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

import funkin.play.stage.Bopper;
import funkin.util.assets.FlxAnimationUtil;
import funkin.data.story.level.LevelData.LevelPropData;

class LevelProp extends Bopper
{
  public var propData(default, set):Null<LevelPropData> = null;

  function set_propData(value:LevelPropData):LevelPropData
  {
    // Only reset the prop if the asset path has changed.
    if (propData == null || !(thx.Dynamics.equals(value, propData)))
    {
      this.propData = value;

      this.visible = this.propData != null;
      danceEvery = this.propData?.danceEvery ?? 1.0;

      applyData();
    }

    return this.propData;
  }

  public function new(propData:LevelPropData)
  {
    super();
    this.danceEvery = propData.danceEvery;
    this.propData = propData;
  }

  public function playConfirm():Void
  {
    if (hasAnimation('confirm')) playAnimation('confirm', true, true);
  }

  function applyData():Void
  {
    if (propData == null)
    {
      this.visible = false;
      return;
    }
    else
    {
      this.visible = true;
    }

    // Reset animation state.
    this.shouldAlternate = null;

    var isAnimated:Bool = propData.animations.length > 0;
    if (isAnimated)
    {
      // Initalize sprite frames.
      // Sparrow atlas only LEL.
      this.frames = Paths.getSparrowAtlas(propData.assetPath);
    }
    else
    {
      // Initalize static sprite.
      this.loadGraphic(Paths.image(propData.assetPath));

      // Disables calls to update() for a performance boost.
      this.active = false;
    }

    if (this.frames == null || this.frames.numFrames == 0)
    {
      trace('ERROR: Could not build texture for level prop (${propData.assetPath}).');
      return;
    }

    var scale:Float = propData.scale * (propData.isPixel ? 6 : 1);
    this.scale.set(scale, scale);
    this.antialiasing = !propData.isPixel;
    this.alpha = propData.alpha;
    this.x = propData.offsets[0];
    this.y = propData.offsets[1];
    this.flipX = propData.flipX;
    this.flipY = propData.flipY;

    FlxAnimationUtil.addAtlasAnimations(this, propData.animations);
    for (propAnim in propData.animations)
    {
      this.setAnimationOffsets(propAnim.name, propAnim.offsets[0], propAnim.offsets[1]);
    }

    if (propData.startingAnimation != "" && this.hasAnimation(propData.startingAnimation))
    {
      this.playAnimation(propData.startingAnimation, true);
    }
    else
    {
      this.dance();
      this.animation.paused = true;
    }
  }

  public static function build(propData:Null<LevelPropData>):Null<LevelProp>
  {
    if (propData == null) return null;

    return new LevelProp(propData);
  }
}
