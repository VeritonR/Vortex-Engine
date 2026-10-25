package funkin.play.notes;

/**
 * The four directions of the notes, as V-Slice scripts know them: numbers with names.
 */
class NoteDirection
{
	public static final LEFT:Int = 0;
	public static final DOWN:Int = 1;
	public static final UP:Int = 2;
	public static final RIGHT:Int = 3;

	static final NAMES:Array<String> = ['left', 'down', 'up', 'right'];
	static final COLORS:Array<String> = ['purple', 'blue', 'green', 'red'];

	public static function fromInt(value:Int):Int
	{
		return ((value % 4) + 4) % 4;
	}

	public static function getName(direction:Int):String return NAMES[fromInt(direction)];
	public static function getNameUpper(direction:Int):String return NAMES[fromInt(direction)].toUpperCase();
	public static function getColorName(direction:Int):String return COLORS[fromInt(direction)];
}
