package funkin.ui.freeplay;

import flixel.FlxSprite;

/**
 * V-Slice's Freeplay is the engine's (scripts get the same one), for the classes of V-Slice the engine has.
 */
typedef FreeplayState = states.FreeplayStateVslice;

/**
 * A song of V-Slice's Freeplay (a capsule's `freeplayData`) is the engine's (scripts get the same one).
 */
typedef FreeplaySongData = objects.freeplay.FreeplaySong;

/**
 * The arrows that change the difficulty on Freeplay are the engine's (scripts get the same ones).
 */
typedef DifficultySelector = objects.freeplay.FreeplayDisplays.DifficultySelector;

// (V-Slice's, for scripts: see the import of it on V-Slice)
/**
 * Possible types to use for the song filter.
 */
enum abstract FilterType(String)
{
	/**
	 * Filter to songs which start with a string
	 */
	public var STARTSWITH;

	/**
	 * Filter to songs which match a regular expression
	 */
	public var REGEXP;

	/**
	 * Filter to songs which are favorited
	 */
	public var FAVORITE;

	/**
	 * Filter to all songs
	 */
	public var ALL;
}

/**
 * Structure for the current song filter.
 */
typedef SongFilter =
{
	var filterType:FilterType;
	var ?filterData:Dynamic;
}

/**
 * Parameters used to initialize the FreeplayState.
 */
typedef FreeplayStateParams =
{
	?character:String,
	?fromCharSelect:Bool,
	?fromResults:FromResultsParams,
};

/**
 * A set of parameters for transitioning to the FreeplayState from the ResultsState.
 */
typedef FromResultsParams =
{
	/**
	 * The previous rank the song hand, if any. Null if it had no score before.
	 */
	var ?oldRank:String; //(one of funkin.play.scoring.Scoring.ScoringRank)

	/**
	 * Whether or not to play the rank animation on returning to freeplay.
	 */
	var playRankAnim:Bool;

	/**
	 * The new rank the song has.
	 */
	var newRank:String; //(one of funkin.play.scoring.Scoring.ScoringRank)

	/**
	 * The song ID to play the animation on.
	 */
	var songId:String;

	/**
	 * The difficulty ID to play the animation on.
	 */
	var difficultyId:String;
};

/**
 * The map storing information about the exit movers.
 */
typedef ExitMoverData = Map<Array<FlxSprite>, MoveData>;

/**
 * The data for an exit mover.
 */
typedef MoveData =
{
	var ?x:Float;
	var ?y:Float;
	var ?speed:Float;
	var ?wait:Float;
}
