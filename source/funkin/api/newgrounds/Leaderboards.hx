package funkin.api.newgrounds;

// (V-Slice's Leaderboards is the engine's, scripts get the same one)
typedef Leaderboards = funkin.api.newgrounds.Leaderboards.LeaderboardsSandboxed;

/**
 * V-Slice's Newgrounds leaderboards as scripts get them. The engine doesn't log in to Newgrounds: there are no scores to ask for.
 */
class LeaderboardsSandboxed
{
	public static function getLeaderboardBySong(songId:String, difficultyId:String):Dynamic return null;
	public static function getLeaderboardByLevel(levelId:String):Dynamic return null;
	public static function requestScores(leaderboard:Dynamic, params:Dynamic):Void {}
}
