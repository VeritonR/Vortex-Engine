package funkin.play.notes.notestyle;

/**
 * V-Slice's base for note styles of scripts: `class MyStyle extends ScriptedNoteStyle { new(id) super('my-style'); ... }`, with
 * functions of their own for what the style makes (`buildJudgementSprite()`). The look is still the one of the style's file of the
 * same id (`data/notestyles/(id).json`), and `NoteStyleRegistry.fetchEntry()` gives the script's for that id.
 */
class ScriptedNoteStyle extends NoteStyle
{
	public function new(id:String, ?data:Dynamic)
	{
		super(id, (data != null) ? data : funkin.data.notestyle.NoteStyleRegistry.instance.readData(id));
	}
}
