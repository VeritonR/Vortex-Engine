package funkin.data.character;

import objects.Character;

/**
 * Where V-Slice scripts get characters from. Here they're Psych's, made out of the mod's character files like the ones of the song.
 */
class CharacterDataParser
{
	/**
	 * Makes a character. It isn't put anywhere: `currentStage.addCharacter(character, type)` is what places it on the stage.
	 */
	public static function fetchCharacter(charId:String, debug:Bool = false):Character
	{
		if(charId == null || charId.length < 1) return null;

		var character:Character = new Character(0, 0, charId, false);
		if(character.missingCharacter) return null;

		// its script, which V-Slice tells about the character as soon as it's made
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.attachCharacterScript(character, true);
		#end
		return character;
	}

	public static function fetchCharacterData(charId:String):Dynamic
	{
		#if MODS_ALLOWED
		var data:Dynamic = backend.PolymodCompat.getCharacterFile(charId, false);
		if(data == null) data = backend.PolymodCompat.getBaseCharacterFile(charId, false);
		return data;
		#else
		return null;
		#end
	}

	/**
	 * What a character's file has, as it's written (V-Slice's `parseCharacterData()`). Null if there's no such character.
	 */
	public static function parseCharacterData(charId:String):Dynamic
	{
		#if MODS_ALLOWED
		if(charId == null) return null;
		for (mod in [backend.Mods.currentModDirectory, backend.PolymodCompat.BASE_MOD])
		{
			if(mod == null || mod.length < 1) continue;
			var path:String = backend.PolymodCompat.findFile(mod, 'data/characters/$charId.json');
			if(path == null) continue;
			try
			{
				return haxe.Json.parse(sys.io.File.getContent(path));
			}
			catch(e:Dynamic)
			{
				trace('The character "$charId" could not be read: $e');
			}
		}
		#end
		return null;
	}

	/**
	 * V-Slice keeps the characters it read here, scripts put theirs in it too. The engine reads them when it needs them:
	 * what scripts put here is kept and not used.
	 */
	public static var characterCache:Dynamic = {h: []};

	public static function listCharacterIds():Array<String>
	{
		var ids:Array<String> = [];
		#if MODS_ALLOWED
		var mod:String = backend.Mods.currentModDirectory;
		if(!backend.PolymodCompat.isPolymod(mod)) return ids;

		var folder:String = backend.Paths.mods('$mod/data/characters');
		if(sys.FileSystem.exists(folder) && sys.FileSystem.isDirectory(folder))
			for (file in sys.FileSystem.readDirectory(folder))
				if(file.toLowerCase().endsWith('.json'))
					ids.push(file.substr(0, file.length - 5));
		ids.sort(Reflect.compare);
		#end
		return ids;
	}
}
