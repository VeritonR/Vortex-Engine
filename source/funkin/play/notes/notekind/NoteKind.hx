package funkin.play.notes.notekind;

import funkin.play.notes.NoteSprite;

/**
 * What V-Slice note kind scripts extend. A kind is what Psych calls a note type: the notes of a chart that have its name
 * use its note style and send it their events (incoming, hit, miss).
 */
class NoteKind extends funkin.modding.ScriptedBase
{
	public var noteKind:String;
	public var description:String;
	public var noteStyleId:String;
	public var noanim:Bool;
	public var suffix:String;
	public var params:Array<Dynamic>;
	public var scoreable:Bool = true;

	public function new(noteKind:String, description:String = '', ?noteStyleId:String, ?params:Array<Dynamic>, ?noanim:Bool, ?suffix:String)
	{
		this.noteKind = noteKind;
		this.description = description;
		this.noteStyleId = noteStyleId;
		this.params = (params != null) ? params : [];
		this.noanim = (noanim == true);
		this.suffix = (suffix != null) ? suffix : '';
	}

	/**
	 * The notes of this kind that are on the screen.
	 */
	public function getNotes(visibleCheck:Bool = false):Array<NoteSprite>
	{
		return listNotes(true, visibleCheck);
	}

	public function getOtherNotes(visibleCheck:Bool = false):Array<NoteSprite>
	{
		return listNotes(false, visibleCheck);
	}

	function listNotes(sameKind:Bool, visibleCheck:Bool):Array<NoteSprite>
	{
		var found:Array<NoteSprite> = [];
		var game:states.PlayState = states.PlayState.instance;
		if(game == null || game.notes == null) return found;

		for (note in game.notes.members)
			if(note != null && !note.isSustainNote && (note.noteType == noteKind) == sameKind && (!visibleCheck || note.visible))
				found.push(NoteSprite.get(note));
		return found;
	}

	public function toString():String
	{
		return noteKind;
	}
}
