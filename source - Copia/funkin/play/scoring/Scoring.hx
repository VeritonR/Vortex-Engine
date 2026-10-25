package funkin.play.scoring;

/**
 * V-Slice's scoring rules, for the scripts that work something out with them (a rank to show on the HUD, the score of a note).
 * The game itself is scored by the engine: these only answer what V-Slice would say.
 */
class Scoring
{
	public static var PBOT1_MAX_SCORE:Int = 500;
	public static var PBOT1_SCORING_OFFSET:Float = 54.99;
	public static var PBOT1_SCORING_SLOPE:Float = 0.080;
	public static var PBOT1_MIN_SCORE:Float = 9.0;
	public static var PBOT1_MISS_SCORE:Int = -100;
	public static var PBOT1_PERFECT_THRESHOLD:Float = 5.0;
	public static var PBOT1_MISS_THRESHOLD:Float = 160.0;
	public static var PBOT1_KILLER_THRESHOLD:Float = 12.5;
	public static var PBOT1_SICK_THRESHOLD:Float = 45.0;
	public static var PBOT1_GOOD_THRESHOLD:Float = 90.0;
	public static var PBOT1_BAD_THRESHOLD:Float = 135.0;
	public static var PBOT1_SHIT_THRESHOLD:Float = 160.0;

	/**
	 * The score of a note hit that many milliseconds away from its time (the "PBOT1" system, the one V-Slice uses).
	 */
	public static function scoreNote(msTiming:Float, ?scoringSystem:Dynamic):Int
	{
		var timing:Float = Math.abs(msTiming);
		if(timing > PBOT1_MISS_THRESHOLD) return PBOT1_MISS_SCORE;
		if(timing < PBOT1_PERFECT_THRESHOLD) return PBOT1_MAX_SCORE;

		var factor:Float = 1.0 - (1.0 / (1.0 + Math.exp(-PBOT1_SCORING_SLOPE * (timing - PBOT1_SCORING_OFFSET))));
		return Std.int(PBOT1_MAX_SCORE * factor + PBOT1_MIN_SCORE);
	}

	/**
	 * The judgement of a note hit that many milliseconds away from its time: "sick", "good", "bad", "shit" or "miss".
	 */
	public static function judgeNote(msTiming:Float, ?scoringSystem:Dynamic):String
	{
		var timing:Float = Math.abs(msTiming);
		if(timing <= PBOT1_SICK_THRESHOLD) return 'sick';
		if(timing <= PBOT1_GOOD_THRESHOLD) return 'good';
		if(timing <= PBOT1_BAD_THRESHOLD) return 'bad';
		if(timing <= PBOT1_SHIT_THRESHOLD) return 'shit';
		return 'miss';
	}

	public static function getMissScore(?scoringSystem:Dynamic):Int
	{
		return PBOT1_MISS_SCORE;
	}

	/**
	 * The rank of a play, out of what it has on `tallies` (sick, good, missed and totalNotes): one of the names of `ScoringRank`,
	 * null if no notes were played.
	 */
	public static function calculateRank(scoreData:Dynamic):String
	{
		var tallies:Dynamic = (scoreData != null) ? scoreData.tallies : null;
		if(tallies == null) return null;

		var rank = backend.FreeplayData.FreeplayRank.fromTallies(number(tallies.sick), number(tallies.good), number(tallies.missed), number(tallies.totalNotes));
		if(rank == null) return null;

		return switch(rank)
		{
			case PERFECT_GOLD: ScoringRank.PERFECT_GOLD;
			case PERFECT: ScoringRank.PERFECT;
			case EXCELLENT: ScoringRank.EXCELLENT;
			case GREAT: ScoringRank.GREAT;
			case GOOD: ScoringRank.GOOD;
			default: ScoringRank.SHIT;
		}
	}

	/**
	 * How much of a song was cleared, from 0 to 1: the Sicks and the Goods minus the misses, out of all the notes.
	 */
	public static function tallyCompletion(?tallies:Dynamic):Float
	{
		if(tallies == null) return 0;
		return backend.FreeplayData.FreeplayRank.getCompletion(number(tallies.sick), number(tallies.good), number(tallies.missed), number(tallies.totalNotes));
	}

	static function number(value:Dynamic):Int
	{
		return (value != null && Std.isOfType(value, Float)) ? Std.int(value) : 0;
	}
}

/**
 * The ranks, by the names V-Slice gives them.
 */
class ScoringRank
{
	public static var PERFECT_GOLD:String = 'PERFECT_GOLD';
	public static var PERFECT:String = 'PERFECT';
	public static var EXCELLENT:String = 'EXCELLENT';
	public static var GREAT:String = 'GREAT';
	public static var GOOD:String = 'GOOD';
	public static var SHIT:String = 'SHIT';
}
