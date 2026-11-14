package funkin.data.event;

/**
 * The fields of a song event, as V-Slice describes them for its chart editor (`getEventSchema()`). The engine has its own
 * editor, this is for the scripts that make one (`new SongEventSchema([...])`) or only name the type.
 */
class SongEventSchema
{
	public var fields:Array<Dynamic>;

	public function new(?fields:Array<Dynamic>)
	{
		this.fields = (fields != null) ? fields : [];
	}

	public function getByName(name:String):Dynamic
	{
		for (field in fields)
			if(field != null && field.name == name)
				return field;
		return null;
	}

	public function getFirstField():Dynamic return (fields.length > 0) ? fields[0] : null;

	public function iterator():Iterator<Dynamic> return fields.iterator();

	public var length(get, never):Int;
	function get_length():Int return fields.length;
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
/**
 * The available field types for a song event schema.
 */
enum abstract SongEventFieldType(String) from String to String
{
	/**
	 * The STRING type will display as a text field.
	 */
	public var STRING = 'string';

	/**
	 * The INTEGER type will display as a text field that only accepts numbers.
	 */
	public var INTEGER = 'integer';

	/**
	 * The FLOAT type will display as a text field that only accepts numbers.
	 */
	public var FLOAT = 'float';

	/**
	 * The BOOL type will display as a checkbox.
	 */
	public var BOOL = 'bool';

	/**
	 * The ENUM type will display as a dropdown.
	 * Make sure to specify the `keys` field in the schema.
	 */
	public var ENUM = 'enum';

	/**
	 * The FRAME type will display a frame with child components.
	 * Make sure to specify the `children` field in the schema.
	 */
	public var FRAME = 'frame';
}
