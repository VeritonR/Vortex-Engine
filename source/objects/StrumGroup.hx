package objects;

/**
 * The group a side's receptors are kept in. It's flixel's own, with what the group V-Slice keeps its receptors in has and flixel's
 * doesn't (V-Slice's is a sprite group): an `alpha` for all of them at once, and a place (`x`, `y`) that moves them all.
 */
@:keep
class StrumGroup extends FlxTypedGroup<StrumNote>
{
	public var alpha(get, set):Float;

	function get_alpha():Float
	{
		for (strum in members)
			if(strum != null)
				return strum.alpha;
		return 1;
	}

	function set_alpha(value:Float):Float
	{
		for (strum in members)
			if(strum != null)
				strum.alpha = value;
		return value;
	}

	/**
	 * Where the group is. On V-Slice the receptors are put in their group at its corner, and the group where its strumline is: this
	 * starts at the place of the strumline of its side (see `funkin.play.notes.Strumline`), and moving it moves the receptors.
	 * Moving a receptor by itself doesn't move it, like on a sprite group.
	 */
	public var x(get, set):Float;
	var placeX:Null<Float> = null;

	function get_x():Float
	{
		if(placeX == null) placeX = startingPlace(true);
		return placeX;
	}

	function set_x(value:Float):Float
	{
		var change:Float = value - x;
		for (strum in members)
			if(strum != null)
				strum.x += change;
		placeX = value;
		return value;
	}

	public var y(get, set):Float;
	var placeY:Null<Float> = null;

	function get_y():Float
	{
		if(placeY == null) placeY = startingPlace(false);
		return placeY;
	}

	function set_y(value:Float):Float
	{
		var change:Float = value - y;
		for (strum in members)
			if(strum != null)
				strum.y += change;
		placeY = value;
		return value;
	}

	/**
	 * A receptor a V-Slice script made (`funkin.play.notes.StrumlineNote`) is put where the group is, like on a sprite group, and is
	 * drawn with the others: in the place of the one the script took out of the group, when it did.
	 */
	override public function add(strum:StrumNote):StrumNote
	{
		// (the group all receptors are drawn from is one of these too, it only keeps them)
		var game:states.PlayState = states.PlayState.instance;
		var drawn:FlxTypedGroup<StrumNote> = (game != null) ? game.strumLineNotes : null;
		if(strum == null || members.contains(strum) || drawn == this || !Std.isOfType(strum, funkin.play.notes.StrumlineNote)) return super.add(strum);

		strum.x += x;
		strum.y += y;

		if(drawn != null && !drawn.members.contains(strum))
			drawn.add(strum); //(in the place the one taken out left)
		return super.add(strum);
	}

	/**
	 * A receptor V-Slice scripts take out of the group isn't drawn anymore either. Its place is left for the one they put in.
	 */
	override public function remove(strum:StrumNote, splice:Bool = false):StrumNote
	{
		#if HSCRIPT_ALLOWED
		var game:states.PlayState = states.PlayState.instance;
		if(backend.VSliceScripts.active && strum != null && game != null && game.strumLineNotes != null && game.strumLineNotes != this && members.contains(strum))
			game.strumLineNotes.remove(strum, splice);
		#end
		return super.remove(strum, splice);
	}

	// The place of the strumline this group is the receptors of, the corner of its first receptor for a group that isn't one
	function startingPlace(horizontal:Bool):Float
	{
		var facade:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(facade != null)
		{
			for (line in [facade.playerStrumline, facade.opponentStrumline])
				if(line != null && line.strumlineNotes == this)
					return horizontal ? line.x : line.y;
		}

		for (strum in members)
			if(strum != null)
				return horizontal ? strum.x : strum.y;
		return 0;
	}
}
