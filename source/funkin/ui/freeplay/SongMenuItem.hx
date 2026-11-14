package funkin.ui.freeplay;

import flixel.FlxSprite;
import openfl.display.BlendMode;

/**
 * V-Slice's song capsules of Freeplay are the engine's (scripts get the same ones), for the classes of V-Slice the engine has.
 */
typedef SongMenuItem = objects.freeplay.FreeplayCapsule;

typedef CapsuleNumber = objects.freeplay.FreeplayCapsule.CapsuleNumber;

/**
 * The badge of a song's rank on its Freeplay capsule, like V-Slice's. Its `rank` is one of `ScoringRank`'s ("PERFECT_GOLD",
 * "PERFECT", "EXCELLENT", "GREAT", "GOOD", "SHIT"), or null for none.
 */
class FreeplayRank extends FlxSprite
{
	public var rank(default, set):Null<String> = null;

	function set_rank(val:Null<String>):Null<String>
	{
		rank = val;
		if(val == null)
		{
			visible = false;
			return val;
		}

		visible = true;
		animation.play(iconOf(val), true, false);
		centerOffsets(false);
		switch(val)
		{
			case 'GOOD', 'GREAT': offset.y -= 8;
			case 'SHIT', 'EXCELLENT', 'PERFECT', 'PERFECT_GOLD':
			default:
				centerOffsets(false);
				visible = false;
		}
		updateHitbox();
		return val;
	}

	// (V-Slice's ScoringRank.getFreeplayRankIconAsset())
	static function iconOf(rank:String):String
	{
		return switch(rank)
		{
			case 'PERFECT_GOLD': 'PERFECTSICK';
			case 'PERFECT': 'PERFECT';
			case 'EXCELLENT': 'EXCELLENT';
			case 'GREAT': 'GREAT';
			case 'GOOD': 'GOOD';
			default: 'LOSS';
		}
	}

	public var baseX:Float = 0;
	public var baseY:Float = 0;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('freeplay/rankbadges');
		animation.addByPrefix('PERFECT', 'PERFECT rank0', 24, false);
		animation.addByPrefix('EXCELLENT', 'EXCELLENT rank0', 24, false);
		animation.addByPrefix('GOOD', 'GOOD rank0', 24, false);
		animation.addByPrefix('PERFECTSICK', 'PERFECT rank GOLD', 24, false);
		animation.addByPrefix('GREAT', 'GREAT rank0', 24, false);
		animation.addByPrefix('LOSS', 'LOSS rank0', 24, false);

		blend = BlendMode.ADD;
		this.rank = null;
		scale.set(0.9, 0.9);
		updateHitbox();
	}
}
