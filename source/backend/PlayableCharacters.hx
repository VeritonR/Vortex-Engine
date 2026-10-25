package backend;

import backend.Song;

typedef PlayableCharacter =
{
	var id:String;
	var name:String;
	var ownedChars:Array<String>; //Characters of the charts that belong to this player: "pico-playable", "pico-christmas"...
	var showUnownedChars:Bool; //If songs whose player character belongs to nobody also show up for this player
	var unlocked:Bool;
	var position:Int; //Slot wanted on the Character Select grid, 0 to 8
	var gfAsset:String; //Image folder of who's sitting with the player on Character Select, null for nobody
	var freeplayStyle:String; //Look of the V-Slice Freeplay menu ("data/ui/freeplay/styles"), null for the default one
	var freeplayDJ:Dynamic; //"freeplayDJ" of the player's file as it is: who's on the turntable of the V-Slice Freeplay menu, null for nobody
	var results:Dynamic; //"results" of the player's file as it is: what the results screen shows and plays for each rank, null for nothing
	var stickerPack:String; //Stickers of the transition back to the menus ("data/stickerpacks"), null for the default ones
	var mod:String; //Mod folder it comes from, empty for the base game
}

typedef PlayerOverride =
{
	var character:String;
	var mod:String; //Mod folder that has the character's files, null to look for it like any other character
}

/**
 * The characters that can be picked on Character Select, same idea as V-Slice's player registry.
 *
 * They come from the "data/players/(id).json" files of the base game and of the enabled mods (V-Slice format).
 *
 * The picked one is saved on `ClientPrefs.data.playerSkin`, empty meaning the default one.
 */
class PlayableCharacters
{
	public static inline final DEFAULT:String = 'bf';

	static var players:Array<PlayableCharacter> = null;
	static var owners:Map<String, String> = []; //Character -> id of the player that owns it
	static var files:Map<String, String> = []; //Id -> the file it was read from

	/**
	 * Where the file of a player is (its "data/players/(id).json"), null for one that has none (the default Boyfriend, made by the game).
	 */
	public static function getFile(id:String):String
	{
		if(players == null) reload();
		return files.get(id);
	}

	/**
	 * Forgets the loaded players, they're read again the next time they're needed.
	 */
	public static function clearCache():Void
	{
		players = null;
	}

	public static function list():Array<PlayableCharacter>
	{
		if(players == null) reload();
		return players;
	}

	public static function get(id:String):PlayableCharacter
	{
		for (player in list())
			if(player.id == id)
				return player;
		return null;
	}

	/**
	 * The player picked on Character Select, never null.
	 */
	public static function getCurrent():PlayableCharacter
	{
		var saved:String = ClientPrefs.data.playerSkin;
		if(saved == null || saved.length < 1 || saved == 'default') saved = DEFAULT;

		var player:PlayableCharacter = get(saved);

		// saves from before the players existed have a character's name there
		if(player == null && owners.exists(saved)) player = get(owners.get(saved));
		if(player == null) player = get(DEFAULT);
		return player;
	}

	public static function select(id:String):Void
	{
		ClientPrefs.data.playerSkin = (id == null || id == DEFAULT) ? '' : id;
	}

	/**
	 * How many players can be picked, Character Select is only worth opening with more than one.
	 */
	public static function countUnlocked():Int
	{
		var count:Int = 0;
		for (player in list())
			if(player.unlocked)
				count++;
		return count;
	}

	public static function isCharacterOwned(char:String):Bool
	{
		list();
		return owners.exists(char);
	}

	/**
	 * The player a character of a chart belongs to, null if it belongs to nobody.
	 */
	public static function getOwner(char:String):PlayableCharacter
	{
		list();
		return owners.exists(char) ? get(owners.get(char)) : get(char);
	}

	/**
	 * If a chart whose player is this character should be available for the given player.
	 */
	public static function shouldShowCharacter(player:PlayableCharacter, char:String):Bool
	{
		if(player.ownedChars.contains(char)) return true;
		return player.showUnownedChars && !isCharacterOwned(char);
	}

	/**
	 * The character that should replace the chart's player, null to keep it.
	 *
	 * Songs from V-Slice mods already have a chart made for the picked player, on the others the player's sprite is swapped.
	 */
	public static function getOverride(song:SwagSong):PlayerOverride
	{
		var player:PlayableCharacter = getCurrent();
		if(player.id == DEFAULT || song == null) return null;
		if(song.vslice != null || player.ownedChars.contains(song.player1)) return null;

		var character:String = getMainCharacter(player);
		return (character != null) ? {character: character, mod: getCharacterMod(player, character)} : null;
	}

	/**
	 * The character a player uses on songs that weren't made for it.
	 */
	public static function getMainCharacter(player:PlayableCharacter):String
	{
		var candidates:Array<String> = [player.id + '-playable', player.id + '-player', player.id].concat(player.ownedChars);
		for (character in candidates)
			if(characterExists(player, character))
				return character;
		return null;
	}

	static function characterExists(player:PlayableCharacter, character:String):Bool
	{
		#if MODS_ALLOWED
		if(getCharacterMod(player, character) != null) return true;
		return FileSystem.exists(Paths.getSharedPath('characters/$character.json'));
		#else
		return openfl.utils.Assets.exists(Paths.getSharedPath('characters/$character.json'));
		#end
	}

	// Looks on the player's own mod first, then on the main mods folder and on every other mod like the skins always did
	public static function getCharacterMod(player:PlayableCharacter, character:String):String
	{
		#if MODS_ALLOWED
		function hasCharacter(mod:String):Bool
		{
			return FileSystem.exists(Paths.mods('$mod/characters/$character.json')) || PolymodCompat.findFile(mod, 'data/characters/$character.json') != null;
		}

		if(player.mod != null && player.mod.length > 0 && hasCharacter(player.mod)) return player.mod;
		if(FileSystem.exists(Paths.mods('characters/$character.json'))) return '';

		for (mod in Mods.getModDirectories())
			if(hasCharacter(mod))
				return mod;
		#end
		return null;
	}

	/**
	 * Reads every player again.
	 */
	public static function reload():Void
	{
		players = [];
		owners = [];
		files = [];

		#if MODS_ALLOWED
		// Players, later folders replace the ones with the same id
		var folders:Array<Array<String>> = [[Paths.getSharedPath('data/players/'), ''], [Paths.mods('data/players/'), '']];
		for (mod in Mods.parseList().enabled)
			folders.push([Paths.mods('$mod/data/players/'), mod]);

		for (entry in folders)
		{
			var folder:String = entry[0];
			if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;

			for (file in FileSystem.readDirectory(folder))
			{
				if(!file.toLowerCase().endsWith('.json')) continue;

				var player:PlayableCharacter = parsePlayer(file.substr(0, file.length - 5), folder + file, entry[1]);
				if(player == null) continue;

				var old:PlayableCharacter = get(player.id);
				if(old != null) players.remove(old);
				players.push(player);
				files.set(player.id, folder + file);
			}
		}
		#end

		// There must always be a default one
		if(get(DEFAULT) == null)
		{
			players.unshift({
				id: DEFAULT,
				name: 'Boyfriend',
				ownedChars: ['bf', 'bf-car', 'bf-christmas', 'bf-pixel', 'bf-holding-gf', 'bf-dark'],
				showUnownedChars: true,
				unlocked: true,
				position: 4,
				gfAsset: 'charSelect/gfChill',
				freeplayStyle: null,
				freeplayDJ: null,
				results: null,
				stickerPack: null,
				mod: ''
			});
		}

		for (player in players)
			for (character in player.ownedChars)
				if(!owners.exists(character))
					owners.set(character, player.id);
	}

	#if MODS_ALLOWED
	static function parsePlayer(id:String, path:String, mod:String):PlayableCharacter
	{
		try
		{
			var raw:String = File.getContent(path);
			if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1);

			// V-Slice mods give their characters to a player by adding them to its file, with a file of their "_merge" folder
			raw = PolymodMerge.apply('data/players/$id.json', raw);
			var data:Dynamic = haxe.Json.parse(raw);

			var charSelect:Dynamic = data.charSelect;
			var gfAsset:String = null;
			if(charSelect != null && charSelect.gf != null) gfAsset = VSliceConvert.str(charSelect.gf.assetPath, null);
			if(gfAsset != null) gfAsset = VSliceConvert.stripLibrary(gfAsset);

			return {
				id: id,
				name: VSliceConvert.str(data.name, id),
				ownedChars: [for (character in VSliceConvert.list(data.ownedChars)) Std.string(character)],
				showUnownedChars: (data.showUnownedChars == true),
				unlocked: (data.unlocked != false),
				position: (charSelect != null) ? Std.int(VSliceConvert.num(charSelect.position, 0)) : 0,
				gfAsset: (gfAsset != null && gfAsset.length > 0) ? gfAsset : null,
				freeplayStyle: VSliceConvert.str(data.freeplayStyle, null),
				freeplayDJ: data.freeplayDJ,
				results: data.results,
				stickerPack: VSliceConvert.str(data.stickerPack, null),
				mod: mod
			};
		}
		catch(e:Dynamic)
		{
			trace('Could not read the player file "$path": $e');
		}
		return null;
	}
	#end
}
