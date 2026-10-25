package funkin.data.dialogue;

/**
 * Where V-Slice scripts get conversations from (`ConversationRegistry.instance.fetchEntry('senpai')`): the files of
 * "data/dialogue/conversations", of the song's mod or of the base game.
 */
class ConversationRegistry
{
	public static var instance(get, never):ConversationRegistry;
	static var _instance:ConversationRegistry = null;
	static function get_instance():ConversationRegistry
	{
		if(_instance == null) _instance = new ConversationRegistry();
		return _instance;
	}

	function new() {}

	/**
	 * A conversation, ready to be added and started. Null if there's no such conversation.
	 */
	public function fetchEntry(id:String, ?params:Dynamic):cutscenes.VSliceConversation
	{
		return cutscenes.VSliceConversation.load(id);
	}

	public function hasEntry(id:String):Bool
	{
		return parseEntryData(id) != null;
	}

	/**
	 * What the conversation's file has, as it's written.
	 */
	public function parseEntryData(id:String):Dynamic
	{
		return cutscenes.VSliceConversation.loadData('conversations', id);
	}

	public function parseEntryDataWithMigration(id:String, ?version:Dynamic):Dynamic return parseEntryData(id);

	public function listEntryIds():Array<String>
	{
		var ids:Array<String> = [];
		#if sys
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/dialogue/conversations/'))
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
