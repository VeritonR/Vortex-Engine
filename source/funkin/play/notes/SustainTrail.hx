package funkin.play.notes;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import funkin.data.song.SongData.SongNoteData;
import objects.Note;

/**
 * A long note as V-Slice scripts know it (what's in `strumline.holdNotes`): one for the whole hold, around the pieces Psych
 * makes it out of. What scripts change on it goes to all of its pieces.
 */
class SustainTrail
{
	/**
	 * Psych's note the hold comes out of (its pieces are its `tail`).
	 */
	public var parentNote(default, null):Note;

	/**
	 * The same object is returned for the same hold every time.
	 */
	public static function get(note:Note):SustainTrail
	{
		if(note == null) return null;

		var trail:SustainTrail = note.extraData.get('vsliceHold');
		if(trail == null)
		{
			trail = new SustainTrail(note);
			note.extraData.set('vsliceHold', trail);
		}
		return trail;
	}

	function new(note:Note)
	{
		parentNote = note;
	}

	// The pieces still on the screen
	function pieces():Array<Note>
	{
		return [for (piece in parentNote.tail) if(piece != null && piece.exists) piece];
	}

	function firstPiece():Note
	{
		for (piece in parentNote.tail)
			if(piece != null && piece.exists) return piece;
		return null;
	}

	public var noteData(get, never):SongNoteData;
	function get_noteData():SongNoteData return NoteSprite.get(parentNote).noteData;

	public var noteDirection(get, never):Int;
	function get_noteDirection():Int return parentNote.noteData;

	public var strumTime(get, never):Float;
	function get_strumTime():Float return parentNote.strumTime;

	public var fullSustainLength(get, never):Float;
	function get_fullSustainLength():Float return parentNote.sustainLength;

	/**
	 * How much of the hold is left: all of it until its note is hit, then less and less while it's held.
	 */
	public var sustainLength(get, never):Float;
	function get_sustainLength():Float
	{
		if(!hitNote) return parentNote.sustainLength;
		return Math.max(0, parentNote.strumTime + parentNote.sustainLength - backend.Conductor.songPosition);
	}

	public var hitNote(get, never):Bool;
	function get_hitNote():Bool return parentNote.mustPress ? parentNote.wasGoodHit : parentNote.hitByOpponent;

	public var missedNote(get, never):Bool;
	function get_missedNote():Bool return parentNote.missed || parentNote.tooLate;

	public var handledMiss:Bool = false;

	public var alive(get, never):Bool;
	function get_alive():Bool
	{
		for (piece in parentNote.tail)
			if(piece != null && piece.exists && piece.alive) return true;
		return false;
	}

	public var exists(get, never):Bool;
	function get_exists():Bool return firstPiece() != null;

	public var x(get, set):Float;
	function get_x():Float
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.x : 0;
	}
	function set_x(value:Float):Float
	{
		for (piece in pieces()) piece.x = value;
		return value;
	}

	public var y(get, set):Float;
	function get_y():Float
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.y : 0;
	}
	function set_y(value:Float):Float
	{
		var change:Float = value - y;
		for (piece in pieces()) piece.y += change;
		return value;
	}

	public var alpha(get, set):Float;
	function get_alpha():Float
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.alpha : 1;
	}
	function set_alpha(value:Float):Float
	{
		for (piece in pieces())
		{
			piece.multAlpha = value; //(the pieces take their strum's alpha every frame, times this)
			piece.alpha = value;
		}
		return value;
	}

	public var visible(get, set):Bool;
	function get_visible():Bool
	{
		var piece:Note = firstPiece();
		return piece != null && piece.visible;
	}
	function set_visible(value:Bool):Bool
	{
		for (piece in pieces()) piece.visible = value;
		return value;
	}

	public var color(get, set):FlxColor;
	function get_color():FlxColor
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.color : FlxColor.WHITE;
	}
	function set_color(value:FlxColor):FlxColor
	{
		for (piece in pieces()) piece.color = value;
		return value;
	}

	public var shader(get, set):FlxShader;
	function get_shader():FlxShader
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.shader : null;
	}
	function set_shader(value:FlxShader):FlxShader
	{
		for (piece in pieces()) piece.shader = value;
		return value;
	}

	public var cameras(get, set):Array<FlxCamera>;
	function get_cameras():Array<FlxCamera>
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.cameras : null;
	}
	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		for (piece in pieces()) piece.cameras = value;
		return value;
	}

	/**
	 * The size of the first piece: change its `x` and call `updateHitbox()` to have all of them take it.
	 */
	public var scale(get, never):FlxPoint;
	function get_scale():FlxPoint
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.scale : FlxPoint.get(1, 1);
	}

	/**
	 * Gives the long note the look of a note style.
	 */
	public function setupHoldNoteGraphic(noteStyle:funkin.play.notes.notestyle.NoteStyle):Void
	{
		if(noteStyle == null) return;
		var own:Bool = noteStyle.usesEngineLook('holdNote');
		for (piece in parentNote.tail)
		{
			if(piece == null) continue;
			if(own) piece.restoreEngineLook();
			else noteStyle.applyToNote(piece);
		}
	}

	// What V-Slice draws its long notes with, the pieces here do it themselves
	public var graphic(get, never):flixel.graphics.FlxGraphic;
	function get_graphic():flixel.graphics.FlxGraphic
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.graphic : null;
	}
	public var zoom:Float = 1;
	public var graphicWidth:Float = 0;
	public var graphicHeight:Float = 0;
	public var noteStyleOffsets:Array<Float> = [0, 0];
	public function updateClipping(songTime:Float = 0):Void {}
	public function updateColorTransform():Void {}

	public function updateHitbox():Void
	{
		var first:Note = firstPiece();
		if(first == null) return;
		for (piece in pieces())
		{
			piece.scale.x = first.scale.x;
			piece.updateHitbox();
		}
	}

	public var width(get, never):Float;
	function get_width():Float
	{
		var piece:Note = firstPiece();
		return (piece != null) ? piece.width : 0;
	}

	public var height(get, never):Float;
	function get_height():Float
	{
		var total:Float = 0;
		for (piece in pieces()) total += piece.height;
		return total;
	}

	public function kill():Void
	{
		for (piece in pieces()) piece.kill();
	}

	public function toString():String
	{
		return 'SustainTrail(${noteData})';
	}
}
