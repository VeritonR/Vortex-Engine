package funkin.modding;

/**
 * What V-Slice scripts ask about the mods that are installed. Here those are the V-Slice mods inside of the engine's "mods" folder,
 * with what their "_polymod_meta.json" says.
 */
class PolymodHandler
{
	public static var API_VERSION:String = '0.8.0';

	public static var modFileSystem:ModFileSystem = new ModFileSystem();

	public static var loadedModDirs(get, never):Array<String>;
	static function get_loadedModDirs():Array<String> return getAllModDirs();

	public static var loadedModIds(get, never):Array<String>;
	static function get_loadedModIds():Array<String> return getAllModIds();

	/**
	 * The V-Slice mods that are turned on.
	 */
	public static function getEnabledMods():Array<Dynamic>
	{
		var found:Array<Dynamic> = [];
		#if MODS_ALLOWED
		for (mod in backend.Mods.parseList().enabled)
		{
			var metadata:Dynamic = modFileSystem.getMetadata(mod);
			if(metadata != null) found.push(metadata);
		}
		#end
		return found;
	}

	public static function getAllMods():Array<Dynamic> return getEnabledMods();
	public static function getAllModIds():Array<String> return [for (metadata in getEnabledMods()) metadata.id];
	public static function getAllModDirs():Array<String> return [for (metadata in getEnabledMods()) metadata.dirName];

	// Mods are read from their files as they're needed, there's nothing to load again
	public static function forceReloadAssets():Void {}
}

class ModFileSystem
{
	var cache:Map<String, Dynamic> = [];

	public function new() {}

	/**
	 * What a mod says about itself, by the name of its folder. Null if it isn't a V-Slice mod.
	 */
	public function getMetadata(dirName:String):Dynamic
	{
		#if MODS_ALLOWED
		if(!backend.PolymodCompat.isPolymod(dirName)) return null;
		if(cache.exists(dirName)) return cache.get(dirName);

		var raw:Dynamic = null;
		try
		{
			raw = haxe.Json.parse(sys.io.File.getContent(backend.Paths.mods('$dirName/${backend.PolymodCompat.META_FILE}')));
		}
		catch(e:Dynamic) {}
		if(raw == null) return null;

		var metadata:Dynamic = {
			id: (raw.id != null) ? raw.id : dirName,
			dirName: dirName,
			modPath: backend.Paths.mods(dirName),
			title: (raw.title != null) ? raw.title : dirName,
			description: (raw.description != null) ? raw.description : '',
			author: raw.author,
			contributors: (raw.contributors != null) ? raw.contributors : [],
			homepage: raw.homepage,
			apiVersion: (raw.api_version != null) ? raw.api_version : API_VERSION_FALLBACK,
			modVersion: (raw.mod_version != null) ? raw.mod_version : '1.0.0',
			license: raw.license,
			dependencies: (raw.dependencies != null) ? raw.dependencies : {},
			optionalDependencies: (raw.optionalDependencies != null) ? raw.optionalDependencies : {}
		};
		cache.set(dirName, metadata);
		return metadata;
		#else
		return null;
		#end
	}

	static inline var API_VERSION_FALLBACK:String = '0.8.0';

	/**
	 * The same, by the id the mod gave itself.
	 */
	public function getMetadataById(id:String):Dynamic
	{
		#if MODS_ALLOWED
		for (mod in backend.Mods.parseList().enabled)
		{
			var metadata:Dynamic = getMetadata(mod);
			if(metadata != null && metadata.id == id) return metadata;
		}
		#end
		return null;
	}
}
