package funkin.play.notes;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import funkin.data.song.SongData.SongNoteData;
import objects.Note;

/**
 * A note as V-Slice scripts know it, around one of Psych's.
 *
 * It can't be the Psych note itself: scripts read `note.noteData.time` and such, and on Psych's notes `noteData` is just the direction.
 * What scripts usually change on the sprite goes to the real note, which is also here as `note` for anything else.
 */
class NoteSprite
{
	/**
	 * Psych's note.
	 */
	public var note(default, null):Note;

	public var noteData(default, null):SongNoteData;

	/**
	 * Set by scripts to tell the note's miss was already dealt with.
	 */
	public var handledMiss:Bool = false;

	/**
	 * The note's long note (`SustainTrail`), null for a note without one. Scripts can give it another.
	 */
	public var holdNoteSprite(get, set):Dynamic;
	var customHold:Dynamic = null;
	function get_holdNoteSprite():Dynamic
	{
		if(customHold != null) return customHold;
		return (note.tail != null && note.tail.length > 0) ? SustainTrail.get(note) : null;
	}
	function set_holdNoteSprite(value:Dynamic):Dynamic return customHold = value;

	/**
	 * Gives the note the look of a note style (V-Slice's mods change the style of the notes on the screen with it).
	 */
	public function setupNoteGraphic(noteStyle:funkin.play.notes.notestyle.NoteStyle):Void
	{
		if(noteStyle == null) return;
		if(noteStyle.usesEngineLook('note')) note.restoreEngineLook();
		else noteStyle.applyToNote(note);
	}

	public function playNoteAnimation(?direction:Int):Void
	{
		if(direction == null) direction = note.noteData;
		var name:String = Note.colArray[direction % Note.colArray.length] + 'Scroll';
		if(note.animation.exists(name)) note.animation.play(name, true);
	}

	/**
	 * The same object is returned for the same note every time.
	 */
	public static function get(note:Note):NoteSprite
	{
		if(note == null) return null;

		var sprite:NoteSprite = note.extraData.get('vsliceNote');
		if(sprite == null)
		{
			sprite = new NoteSprite(note);
			note.extraData.set('vsliceNote', sprite);
		}
		return sprite;
	}

	function new(note:Note)
	{
		this.note = note;
		noteData = new SongNoteData(note.strumTime, note.noteData + (note.mustPress ? 0 : 4), note.sustainLength, (note.noteType != null) ? note.noteType : '');

		// what the chart says besides the kind: [{n: (name), v: (value)}, ...]
		var raw:Dynamic = note.extraData.get('vsliceParams');
		if(Std.isOfType(raw, Array))
		{
			var list:Array<Dynamic> = raw;
			for (param in list)
				if(param != null)
					noteData.params.push({name: (param.n != null) ? param.n : param.name, value: (param.v != null) ? param.v : param.value});
		}
	}

	/**
	 * The parameters the note has on the chart, for the note kinds that have them.
	 */
	public var params(get, never):Array<Dynamic>;
	function get_params():Array<Dynamic> return noteData.params;

	public function getParam(name:String):Dynamic
	{
		for (param in noteData.params)
			if(param.name == name)
				return param.value;
		return null;
	}

	public var kind(get, set):String;
	function get_kind():String return noteData.kind;
	function set_kind(value:String):String
	{
		note.noteType = value;
		return noteData.kind = value;
	}

	public var direction(get, never):Int;
	function get_direction():Int return note.noteData;

	public var strumTime(get, never):Float;
	function get_strumTime():Float return note.strumTime;

	public var isHoldNote(get, never):Bool;
	function get_isHoldNote():Bool return note.sustainLength > 0;

	public var hasMissed(get, never):Bool;
	function get_hasMissed():Bool return note.missed || note.tooLate;

	// Scripts that deal with a note themselves (cancelling its hit) set this so the game leaves it alone from then on
	public var hasBeenHit(get, set):Bool;
	function get_hasBeenHit():Bool return note.mustPress ? note.wasGoodHit : note.hitByOpponent;
	function set_hasBeenHit(value:Bool):Bool
	{
		if(note.mustPress) note.wasGoodHit = value;
		else note.hitByOpponent = value;
		return value;
	}

	public var mayHit(get, never):Bool;
	function get_mayHit():Bool return note.canBeHit;

	public var tooEarly(get, never):Bool;
	function get_tooEarly():Bool return !note.canBeHit && !note.tooLate && !note.wasGoodHit;

	public var lowPriority(get, set):Bool;
	function get_lowPriority():Bool return note.lowPriority;
	function set_lowPriority(value:Bool):Bool return note.lowPriority = value;

	// The sprite

	public var x(get, set):Float;
	function get_x():Float return note.x;
	function set_x(value:Float):Float return note.x = value;

	public var y(get, set):Float;
	function get_y():Float return note.y;
	function set_y(value:Float):Float return note.y = value;

	public var alpha(get, set):Float;
	function get_alpha():Float return note.alpha;
	function set_alpha(value:Float):Float
	{
		note.multAlpha = value; //the note's own alpha follows its strum's every frame
		return note.alpha = value;
	}

	public var visible(get, set):Bool;
	function get_visible():Bool return note.visible;
	function set_visible(value:Bool):Bool return note.visible = value;

	public var angle(get, set):Float;
	function get_angle():Float return note.angle;
	function set_angle(value:Float):Float return note.angle = value;

	public var color(get, set):FlxColor;
	function get_color():FlxColor return note.color;
	function set_color(value:FlxColor):FlxColor return note.color = value;

	public var shader(get, set):FlxShader;
	function get_shader():FlxShader return note.shader;
	function set_shader(value:FlxShader):FlxShader return note.shader = value;

	public var cameras(get, set):Array<FlxCamera>;
	function get_cameras():Array<FlxCamera> return note.cameras;
	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera> return note.cameras = value;

	public var scale(get, never):FlxPoint;
	function get_scale():FlxPoint return note.scale;

	public var offset(get, never):FlxPoint;
	function get_offset():FlxPoint return note.offset;

	public var width(get, never):Float;
	function get_width():Float return note.width;

	public var height(get, never):Float;
	function get_height():Float return note.height;

	public function toString():String
	{
		return 'NoteSprite($noteData)';
	}
}
