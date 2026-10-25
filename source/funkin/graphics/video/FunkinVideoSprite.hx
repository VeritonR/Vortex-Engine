package funkin.graphics.video;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;

/**
 * The sprite V-Slice scripts play videos on: `load()` it with what `Paths.videos()` gives, then `play()`.
 * It's the video library's own sprite, at the speed the song is being played.
 */
class FunkinVideoSprite extends FlxVideoSprite
{
	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);

		if(bitmap != null)
		{
			bitmap.onOpening.add(function()
			{
				var game:states.PlayState = states.PlayState.instance;
				if(bitmap != null && game != null) bitmap.rate = game.playbackRate;
			});
		}
	}
}
#end
