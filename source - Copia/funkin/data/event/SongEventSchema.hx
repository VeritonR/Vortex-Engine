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
