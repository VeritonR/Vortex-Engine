package funkin;

import openfl.display.BitmapData;
import openfl.media.Sound;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * V-Slice's `Assets`, which its scripts have without importing (and what `openfl.utils.Assets` and `lime.utils.Assets` are for them).
 *
 * It's given the paths `Paths` makes: `Assets.getText(Paths.json('thing'))`. Here those are already the paths of the files themselves,
 * inside of the mod or of the game, so they're read right from there.
 */
class Assets
{
	// The file a path leads to: what `Paths` gave, or something written like on V-Slice ("assets/data/thing.json", "shared:assets/shared/images/thing.png")
	static function resolve(value:Dynamic):String
	{
		// (the engine's `Paths` gives some things already loaded instead of their paths, those aren't files to look for)
		if(value == null || !Std.isOfType(value, String)) return null;
		var path:String = value;

		#if sys
		if(FileSystem.exists(path)) return path;
		#end

		var key:String = path;
		var colon:Int = key.indexOf(':');
		if(colon > 1) key = key.substr(colon + 1); //more than a drive's letter
		if(key.startsWith('assets/')) key = key.substr('assets/'.length);

		var found:String = backend.Paths.getPath(key);
		#if sys
		if(FileSystem.exists(found)) return found;

		// "assets/shared/images/thing.png"
		var slash:Int = key.indexOf('/');
		if(slash > -1)
		{
			found = backend.Paths.getPath(key.substr(slash + 1));
			if(FileSystem.exists(found)) return found;
		}
		return null;
		#else
		return found;
		#end
	}

	public static function getPath(path:String):String
	{
		var found:String = resolve(path);
		return (found != null) ? found : path;
	}

	public static function exists(path:Dynamic, ?type:Dynamic):Bool
	{
		if(path != null && !Std.isOfType(path, String)) return true; //something `Paths` already loaded

		var found:String = resolve(path);
		#if sys
		return found != null;
		#else
		return found != null && openfl.utils.Assets.exists(found);
		#end
	}

	public static function getText(path:String):String
	{
		var found:String = resolve(path);
		if(found == null) return null;

		#if sys
		return File.getContent(found);
		#else
		return openfl.utils.Assets.getText(found);
		#end
	}

	public static function getBytes(path:String):haxe.io.Bytes
	{
		var found:String = resolve(path);
		if(found == null) return null;

		#if sys
		return File.getBytes(found);
		#else
		return openfl.utils.Assets.getBytes(found);
		#end
	}

	public static function getBitmapData(path:Dynamic, useCache:Bool = true):BitmapData
	{
		if(Std.isOfType(path, BitmapData)) return path;
		if(Std.isOfType(path, flixel.graphics.FlxGraphic)) return cast(path, flixel.graphics.FlxGraphic).bitmap;

		var found:String = resolve(path);
		if(found == null) return null;

		#if sys
		return BitmapData.fromFile(found);
		#else
		return openfl.utils.Assets.getBitmapData(found, useCache);
		#end
	}

	public static function getSound(path:Dynamic):Sound
	{
		if(Std.isOfType(path, Sound)) return path;

		var found:String = resolve(path);
		if(found == null) return null;

		#if sys
		return Sound.fromFile(found);
		#else
		return openfl.utils.Assets.getSound(found);
		#end
	}

	public static function getMusic(path:Dynamic):Sound
	{
		return getSound(path);
	}

	static var listed:Array<String> = null;
	static var listedMod:String = null;

	/**
	 * Every file of the game and of the current mod, the way V-Slice names them: "assets/(folder)/(file)", whatever folder they're really in.
	 * Scripts go through it to find what a folder has (`Assets.list().filter(path -> path.startsWith('assets/sounds/cartoons/'))`).
	 */
	public static function list(?type:Dynamic):Array<String>
	{
		#if sys
		var mod:String = #if MODS_ALLOWED backend.Mods.currentModDirectory #else '' #end;
		if(listed != null && listedMod == mod) return listed.copy();

		var found:Map<String, Bool> = [];
		addFolder('assets/shared', 'assets', found);
		#if MODS_ALLOWED
		if(mod != null && mod.length > 0)
		{
			var root:String = backend.Paths.mods(mod);
			addFolder(root, 'assets', found, ['scripts']);

			// (the mod's copies of the base game's libraries)
			for (library in ['shared', 'week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1'])
				addFolder('$root/$library', 'assets', found);
		}
		#end

		listed = [for (path in found.keys()) path];
		listed.sort(Reflect.compare);
		listedMod = mod;
		return listed.copy();
		#else
		return openfl.utils.Assets.list(type);
		#end
	}

	#if sys
	static function addFolder(folder:String, name:String, found:Map<String, Bool>, ?skip:Array<String>):Void
	{
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return;

		for (file in FileSystem.readDirectory(folder))
		{
			if(skip != null && skip.contains(file)) continue;

			var path:String = '$folder/$file';
			if(FileSystem.isDirectory(path)) addFolder(path, '$name/$file', found);
			else found.set('$name/$file', true);
		}
	}
	#end

	// The libraries of V-Slice are just folders here
	public static function hasLibrary(name:String):Bool
	{
		return true;
	}
}
