package funkin.play.notes.notekind;

/**
 * Lets scripts reach the note kinds of the mod being played.
 */
class NoteKindManager
{
	public static function getNoteKind(?noteKind:String):NoteKind
	{
		return (noteKind != null) ? backend.VSliceScripts.getNoteKind(noteKind) : null;
	}

	public static function getNoteStyleId(noteKind:String, ?suffix:String):String
	{
		var kind:NoteKind = getNoteKind(noteKind);
		var id:String = (kind != null) ? kind.noteStyleId : null;

		// the kind's version of a style of its own, when there's one ("(kind's style)-(suffix)")
		if(id != null && suffix != null && suffix.length > 0 && funkin.data.notestyle.NoteStyleRegistry.instance.hasEntry('$id-$suffix'))
			id = '$id-$suffix';
		return id;
	}

	/**
	 * The note style of a note kind, null for the kinds that don't have one.
	 */
	public static function getNoteStyle(noteKind:String, ?suffix:String):funkin.play.notes.notestyle.NoteStyle
	{
		var id:String = getNoteStyleId(noteKind, suffix);
		return (id != null) ? funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry(id) : null;
	}
}
