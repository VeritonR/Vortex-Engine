package funkin.play.components;

// (V-Slice's HealthIcon is the engine's, scripts get the same one)
typedef HealthIcon = objects.HealthIcon;

// (V-Slice's, for scripts: see the import of it on V-Slice)
/**
 * The current state of the health
 */
enum abstract HealthIconState(String) to String from String
{
	/**
	 * Indicates the health icon is in the default animation.
	 * Plays as long as health is between 20% and 80%.
	 */
	public var Idle = 'idle';

	/**
	 * Indicates the health icon is playing the Winning animation.
	 * Plays as long as health is above 80%.
	 */
	public var Winning = 'winning';

	/**
	 * Indicates the health icon is playing the Losing animation.
	 * Plays as long as health is below 20%.
	 */
	public var Losing = 'losing';

	/**
	 * Indicates that the health icon is transitioning between `idle` and `winning`.
	 * The next animation will play once the current animation finishes.
	 */
	public var ToWinning = 'toWinning';

	/**
	 * Indicates that the health icon is transitioning between `idle` and `losing`.
	 * The next animation will play once the current animation finishes.
	 */
	public var ToLosing = 'toLosing';

	/**
	 * Indicates that the health icon is transitioning between `winning` and `idle`.
	 * The next animation will play once the current animation finishes.
	 */
	public var FromWinning = 'fromWinning';

	/**
	 * Indicates that the health icon is transitioning between `losing` and `idle`.
	 * The next animation will play once the current animation finishes.
	 */
	public var FromLosing = 'fromLosing';
}
