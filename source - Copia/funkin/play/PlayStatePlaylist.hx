package funkin.play;

/**
 * What V-Slice knows about the week being played, read from Psych's PlayState.
 */
class PlayStatePlaylist
{
	public static var isStoryMode(get, set):Bool;
	static function get_isStoryMode():Bool return states.PlayState.isStoryMode;
	static function set_isStoryMode(value:Bool):Bool return states.PlayState.isStoryMode = value;

	/**
	 * Songs of the week that are still to be played, the current one included.
	 */
	public static var playlistSongIds(get, set):Array<String>;
	static function get_playlistSongIds():Array<String> return states.PlayState.storyPlaylist;
	static function set_playlistSongIds(value:Array<String>):Array<String> return states.PlayState.storyPlaylist = value;

	public static var campaignScore(get, set):Int;
	static function get_campaignScore():Int return states.PlayState.campaignScore;
	static function set_campaignScore(value:Int):Int return states.PlayState.campaignScore = value;

	/**
	 * The week of the song. On V-Slice it's the last week picked on Story Mode, which Freeplay doesn't clear: scripts look it up even
	 * when the song isn't being played in one (`LevelRegistry.instance.fetchEntry(campaignId).getSongs()`), checking `isStoryMode` after.
	 */
	public static var campaignId(get, never):String;
	static function get_campaignId():String
	{
		// the weeks of V-Slice mods are "(mod)/levels/(level)" (or the level's title), and "(mod)/songs/(song)" on Freeplay
		var week:String = backend.WeekData.getWeekFileName();
		if(week == null) return null;
		var levels:Int = week.lastIndexOf('/levels/');
		if(levels > -1) return week.substr(levels + '/levels/'.length);

		var registry = funkin.data.story.level.LevelRegistry.instance;
		var data:backend.WeekData = backend.WeekData.getCurrentWeek();
		if(data != null && data.weekName != null && registry.hasEntry(data.weekName)) return data.weekName; //(Freeplay's: the song's level)

		// the level the song is in, if the mod has levels at all
		var song:String = (states.PlayState.SONG != null) ? Paths.formatToSongPath(states.PlayState.SONG.song) : null;
		var ids:Array<String> = registry.listEntryIds();
		if(ids.length < 1) return (week.indexOf('/songs/') > -1) ? null : week;
		for (id in ids)
		{
			var level = registry.fetchEntry(id);
			if(level != null && song != null && [for (other in level.getSongs()) Paths.formatToSongPath(other)].contains(song)) return id;
		}
		return null;
	}

	public static var campaignTitle(get, never):String;
	static function get_campaignTitle():String
	{
		var week:backend.WeekData = backend.WeekData.getCurrentWeek();
		return (week != null && week.storyName != null) ? week.storyName : 'UNKNOWN';
	}

	public static var campaignDifficulty(get, never):String;
	static function get_campaignDifficulty():String
		return Paths.formatToSongPath(Difficulty.getString(null, false));

	public static function reset():Void {}
}
