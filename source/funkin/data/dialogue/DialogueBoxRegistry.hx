package funkin.data.dialogue;

/**
 * Where V-Slice scripts get dialogue boxes from (`DialogueBoxRegistry.instance.fetchEntry('pixel')`): the files of "data/dialogue/boxes", of the song's
 * mod or of the base game. They're the same ones the engine's conversations use (cutscenes.VSliceConversation).
 */
class DialogueBoxRegistry
{
	public static var instance(get, never):DialogueBoxRegistry;
	static var _instance:DialogueBoxRegistry = null;
	static function get_instance():DialogueBoxRegistry
	{
		if(_instance == null) _instance = new DialogueBoxRegistry();
		return _instance;
	}

	function new() {}

	/**
	 * A new one, made out of its file. Null if there's no such file.
	 */
	public function fetchEntry(id:String, ?params:Dynamic):cutscenes.VSliceConversation.VSliceDialogueBox
	{
		var data:Dynamic = parseEntryData(id);
		return (data != null) ? new cutscenes.VSliceConversation.VSliceDialogueBox(id, data) : null;
	}

	public function hasEntry(id:String):Bool
	{
		return parseEntryData(id) != null;
	}

	/**
	 * What its file has, as it's written.
	 */
	public function parseEntryData(id:String):Dynamic
	{
		return (id != null && id.length > 0) ? cutscenes.VSliceConversation.loadData('boxes', id) : null;
	}

	public function parseEntryDataWithMigration(id:String, ?version:Dynamic):Dynamic return parseEntryData(id);

	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = [];
		#if sys
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/dialogue/boxes/'))
		{
			if(!sys.FileSystem.exists(folder) || !sys.FileSystem.isDirectory(folder)) continue;
			for (file in sys.FileSystem.readDirectory(folder))
			{
				if(!file.toLowerCase().endsWith('.json')) continue;
				var id:String = file.substr(0, file.length - 5);
				if(!ids.contains(id)) ids.push(id);
			}
		}
		#end
		return ids;
	}
}
