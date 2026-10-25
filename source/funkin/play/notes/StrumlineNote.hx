package funkin.play.notes;

import funkin.play.notes.notestyle.NoteStyle;

/**
 * A receptor a V-Slice script makes itself, `new StrumlineNote(noteStyle, isPlayer, direction)`, to put in a strumline's
 * `strumlineNotes` in place of one it took out (it's how mods change the note style of a side in the middle of a song).
 * It's one of the engine's receptors, with the look of the style and the room V-Slice's have; scripts know the engine's own as
 * `StrumlineNote` too (`objects.StrumNote`, which makes one of these when it's given V-Slice's values, see `backend.VSliceScripts`).
 *
 * Like on V-Slice, it's made at the corner of the group it's added to: `objects.StrumGroup.add()` puts it where the group is.
 */
class StrumlineNote extends objects.StrumNote
{
	public var isPlayer(default, null):Bool;

	public function new(noteStyle:NoteStyle, isPlayer:Bool, direction:Int)
	{
		objects.StrumNote.vsliceHitbox = objects.StrumNote.songRoom;
		super(0, 0, direction % 4, isPlayer ? 1 : 0);
		objects.StrumNote.vsliceHitbox = null;

		this.isPlayer = isPlayer;
		downScroll = ClientPrefs.data.downScroll;
		if(noteStyle != null && !noteStyle.usesEngineLook('noteStrumline')) noteStyle.applyToStrum(this);

		x = 0;
		y = 0;
	}
}
