package funkin;

/**
 * V-Slice's count of how the song being played is going: `Highscore.tallies.combo`, `Highscore.tallies.missed`...
 * Here those numbers are PlayState's own, this only gives them the names scripts know. They're read when asked for:
 * what a script writes on them isn't taken by the game.
 */
class Highscore
{
	public static var tallies(get, never):Tallies;
	static function get_tallies():Tallies return new Tallies();

	/**
	 * The ones of the whole week, on Story Mode. The engine only keeps the week's score, the rest is the current song's.
	 */
	public static var talliesLevel(get, never):Tallies;
	static function get_talliesLevel():Tallies
	{
		var result:Tallies = new Tallies();
		if(states.PlayState.isStoryMode) result.score = states.PlayState.campaignScore + result.score;
		return result;
	}

	public static function combineTallies(newTally:Tallies, baseTally:Tallies):Tallies
	{
		var combined:Tallies = new Tallies(false);
		combined.missed = newTally.missed + baseTally.missed;
		combined.shit = newTally.shit + baseTally.shit;
		combined.bad = newTally.bad + baseTally.bad;
		combined.good = newTally.good + baseTally.good;
		combined.sick = newTally.sick + baseTally.sick;
		combined.totalNotes = newTally.totalNotes + baseTally.totalNotes;
		combined.totalNotesHit = newTally.totalNotesHit + baseTally.totalNotesHit;
		combined.score = newTally.score + baseTally.score;
		combined.combo = newTally.combo;
		combined.maxCombo = Std.int(Math.max(newTally.maxCombo, baseTally.maxCombo));
		return combined;
	}
}

class Tallies
{
	public var combo:Int = 0;
	public var missed:Int = 0;
	public var shit:Int = 0;
	public var bad:Int = 0;
	public var good:Int = 0;
	public var sick:Int = 0;
	public var totalNotes:Int = 0;
	public var totalNotesHit:Int = 0;
	public var maxCombo:Int = 0;
	public var score:Int = 0;
	public var isNewHighscore:Bool = false;

	/**
	 * @param current 	If it starts with the numbers of the song being played.
	 */
	public function new(current:Bool = true)
	{
		var game:states.PlayState = current ? states.PlayState.instance : null;
		if(game == null) return;

		combo = game.combo;
		missed = game.songMisses;
		score = game.songScore;
		totalNotesHit = game.songHits;
		totalNotes = game.songHits + game.songMisses;
		maxCombo = Std.int(Math.max(game.combo, maxCombo));

		// (with the notes being hit for the player nothing is counted, like on V-Slice: Psych still counts the ratings then,
		// and scripts that work out an accuracy with them would be dividing by the zero notes the rest says were hit)
		if(game.cpuControlled) return;

		for (rating in game.ratingsData)
		{
			switch(rating.name)
			{
				case 'sick': sick = rating.hits;
				case 'good': good = rating.hits;
				case 'bad': bad = rating.hits;
				case 'shit': shit = rating.hits;
			}
		}
	}
}
