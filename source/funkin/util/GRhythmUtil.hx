package funkin.util;

import funkin.play.notes.NoteSprite;
import funkin.play.notes.Strumline;

/**
 * The start, center and end of the time a note can be hit in.
 */
typedef HitWindow =
{
	public var start:Float;
	public var center:Float;
	public var end:Float;
}

/**
 * What `GRhythmUtil.processWindow()` found: if a note that isn't the player's is hit now, and if the game should go on with it.
 */
typedef HitWindowRes =
{
	public var botplayHit:Bool;
	public var cont:Bool;
}

/**
 * V-Slice's functions for the time notes can be hit in and where they are on the screen, which scripts use to hit notes themselves
 * (Vs Impostor's Monotone Attack and Voting Time have a third singer whose notes a script hits).
 */
class GRhythmUtil
{
	/**
	 * The direction on the other side of the strumline (left for right, up for down).
	 */
	public static function mirrorNoteDirection(noteData:Int):Int
	{
		final MAX_KEY_VALUE:Int = (noteData < Strumline.KEY_COUNT ? Strumline.KEY_COUNT : Strumline.KEY_COUNT * 2);
		return (MAX_KEY_VALUE - 1) - (noteData % Strumline.KEY_COUNT);
	}

	public static function getHitWindow(note:Dynamic):HitWindow
	{
		var sprite:NoteSprite = toSprite(note);
		return {
			start: sprite.strumTime - Constants.HIT_WINDOW_MS,
			center: sprite.strumTime,
			end: sprite.strumTime + Constants.HIT_WINDOW_MS
		};
	}

	/**
	 * Where a note is in its time to be hit, marking it as missed once it's past.
	 *
	 * @param isControlled 	False for a note no one plays (an opponent's, or the bot's): it's hit as soon as its time comes.
	 */
	public static function processWindow(note:Dynamic, isControlled:Bool = true, ?inUseConductor:Dynamic):HitWindowRes
	{
		var sprite:NoteSprite = toSprite(note);
		var position:Float = (inUseConductor != null) ? inUseConductor.songPosition : backend.Conductor.songPosition;
		var window:HitWindow = getHitWindow(sprite);

		if(sprite.hasMissed || sprite.hasBeenHit) return {botplayHit: false, cont: false};

		// past the end of its time
		if(position > window.end)
		{
			sprite.tooEarly = false;
			sprite.hasMissed = true;
			sprite.mayHit = false;
			markHoldMissed(sprite, true);
			return {botplayHit: false, cont: true};
		}

		if(!isControlled && position >= window.center) return {botplayHit: true, cont: true};

		markHoldMissed(sprite, false);

		if(position >= window.start)
		{
			sprite.tooEarly = false;
			sprite.hasMissed = false;
			sprite.mayHit = true;
			return {botplayHit: false, cont: true};
		}

		sprite.tooEarly = true;
		sprite.mayHit = false;
		sprite.hasMissed = false;
		return {botplayHit: false, cont: true};
	}

	/**
	 * How far from its strum a note at that time is, on the screen.
	 */
	public static function getNoteY(strumTime:Float, scrollSpeed:Float, downscroll:Bool = false, ?conductorInUse:Dynamic):Float
	{
		var position:Float = (conductorInUse != null) ? conductorInUse.songPosition : backend.Conductor.songPosition;
		return Constants.PIXELS_PER_MS * (position - strumTime) * scrollSpeed * (downscroll ? 1 : -1);
	}

	static function markHoldMissed(sprite:NoteSprite, missed:Bool):Void
	{
		var hold:Dynamic = sprite.holdNoteSprite;
		if(Std.isOfType(hold, funkin.play.notes.SustainTrail)) (hold:funkin.play.notes.SustainTrail).missedNote = missed;
		else if(hold != null) Reflect.setProperty(hold, 'missedNote', missed);
	}

	// (scripts may give these the engine's note instead of what V-Slice's scripts know as one)
	static function toSprite(note:Dynamic):NoteSprite
	{
		if(Std.isOfType(note, objects.Note)) return NoteSprite.get(note);
		return note;
	}
}
