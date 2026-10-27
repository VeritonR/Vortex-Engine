package objects;

import backend.Song.SwagSong;

/**
 * What a chart says about one of its extra characters (the "vortexCharacters" list of a Psych chart).
 */
typedef ExtraCharacterFile =
{
	/** The name notes and scripts know it by (unique in the song). */
	var tag:String;
	/** The character file. */
	var character:String;
	/** "opponent", "player" or "gf": the side it stands on and sings for. */
	@:optional var side:String;
	/** Where it stands, from the spot of the main character of its side. */
	@:optional var x:Float;
	@:optional var y:Float;
	/** It sings every note of its side (a duet), not only the ones marked for it. */
	@:optional var singsAll:Bool;
	/** It stands behind the main character of its side instead of in front. */
	@:optional var behind:Bool;
}

/**
 * Vortex Engine: a character a song has on top of the opponent, the player and the girlfriend, without a script.
 *
 * It stands next to the main character of its side, dances with them, and sings the notes of that side that are marked for it
 * ("Sung by" on the chart editor, the 5th value of a note on the chart), or all of them if it's set to. A note marked "main"
 * is only for the main character, "all" for everyone on its side, and a tag (or tags, "main,pico2") for those.
 * Scripts get it by its tag, like a Lua sprite: setProperty('pico2.alpha', 0.5), playAnim('pico2', 'hey', true).
 * The "Change Character" event changes it when its first value is the tag.
 */
class ExtraCharacter
{
	public static final SIDES:Array<String> = ['opponent', 'player', 'gf'];

	/** On a note's 5th value: only the main character sings it / everyone of its side does. */
	public static inline final MAIN:String = 'main';
	public static inline final ALL:String = 'all';

	public var tag:String;
	public var side:String;
	public var singsAll:Bool;
	public var behind:Bool;
	public var offsetX:Float;
	public var offsetY:Float;

	/** The character it is now. */
	public var char:Character;
	/** Every character it has been on this song ("Change Character"), to go back to one without loading it again. */
	public var characters:Map<String, Character> = [];

	public function new(data:ExtraCharacterFile)
	{
		tag = data.tag;
		side = SIDES.contains(data.side) ? data.side : 'opponent';
		singsAll = (data.singsAll == true);
		behind = (data.behind == true);
		offsetX = (data.x != null && !Math.isNaN(data.x)) ? data.x : 0;
		offsetY = (data.y != null && !Math.isNaN(data.y)) ? data.y : 0;
	}

	/**
	 * The extra characters of a chart that can be used: with a character and a tag no other one has.
	 */
	public static function listOf(song:SwagSong):Array<ExtraCharacterFile>
	{
		var found:Array<ExtraCharacterFile> = [];
		if(song == null || song.vortexCharacters == null || !Std.isOfType(song.vortexCharacters, Array)) return found;

		var tags:Array<String> = [];
		for (entry in (song.vortexCharacters : Array<Dynamic>))
		{
			if(entry == null || entry.character == null || entry.tag == null) continue;
			var tag:String = Std.string(entry.tag).trim();
			if(tag.length < 1 || tags.contains(tag) || tag == MAIN || tag == ALL) continue;

			tags.push(tag);
			entry.tag = tag;
			found.push(entry);
		}
		return found;
	}

	/** The side of the song a note is on, as extra characters say it. */
	public static function sideOf(note:Note):String
		return note.gfNote ? 'gf' : (note.mustPress ? 'player' : 'opponent');

	/** If this one sings that note. */
	public function sings(note:Note):Bool
	{
		if(note == null || char == null || side != sideOf(note)) return false;

		var who:String = note.singers;
		if(who == null || who.length < 1) return singsAll;
		if(who == ALL) return true;
		for (name in who.split(','))
			if(name.trim() == tag) return true;
		return false;
	}

	/** If the main character of its side sings that note (the ones marked only for extra characters it doesn't). */
	public static function mainSings(note:Note):Bool
	{
		var who:String = (note != null) ? note.singers : null;
		if(who == null || who.length < 1 || who == ALL) return true;
		for (name in who.split(','))
			if(name.trim() == MAIN) return true;
		return false;
	}
}
