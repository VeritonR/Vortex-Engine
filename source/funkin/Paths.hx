package funkin;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import openfl.media.Sound;

/**
 * Psych's Paths with the functions V-Slice scripts call.
 *
 * On V-Slice most of these return the path of the file, which the game then loads by itself.
 * That only works for files the game was built with, so here they return the loaded thing instead (found on the mods like anything else),
 * which is accepted wherever a path would be: `loadGraphic(Paths.image('thing'))`, `FunkinSound.playOnce(Paths.sound('thing'))`...
 */
class Paths
{
	/**
	 * The week's folder files are also looked for in ("week6", "weekend1"...).
	 */
	public static var currentLevel(get, set):String;
	static function get_currentLevel():String return backend.Paths.currentLevel;
	static function set_currentLevel(value:String):String return backend.Paths.currentLevel = value;

	// "shared:images/thing" -> "images/thing", the libraries of V-Slice are just folders here
	static function stripLibrary(key:String):String
	{
		var index:Int = key.indexOf(':');
		return (index > -1) ? key.substr(index + 1) : key;
	}

	// The library something was asked from when it's one of the base game's weeks and the thing isn't found without it:
	// the engine only looks inside the folder of the week being played by itself
	static function getLibrary(key:String, library:String, file:String, type:openfl.utils.AssetType):String
	{
		var index:Int = key.indexOf(':');
		if(index > -1) library = key.substr(0, index);

		if(library == null || library.length < 1 || library == 'shared' || library == 'preload') return null;
		return backend.Paths.fileExists(file, type) ? null : library;
	}

	public static function image(key:String, ?library:String):FlxGraphic
	{
		var name:String = stripLibrary(key);
		return backend.Paths.image(name, getLibrary(key, library, 'images/$name.png', IMAGE));
	}

	public static function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		return backend.Paths.getSparrowAtlas(stripLibrary(key));
	}

	public static function getPackerAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		return backend.Paths.getPackerAtlas(stripLibrary(key));
	}

	/**
	 * The library the next files are looked for in first (V-Slice's are the week folders: "week7", "shared"...).
	 */
	public static function setCurrentLevel(name:String):Void
	{
		backend.Paths.setCurrentLevel(name);
	}

	// (a sound that isn't there is null, not the engine's "beep": on V-Slice it's the path of a file that isn't there, so
	// `Assets.exists(Paths.sound(...))` is false. Scripts look for numbered sounds that way, "thing1", "thing2"... until one is missing)
	public static function sound(key:String, ?library:String):Sound
	{
		var name:String = stripLibrary(key);
		return backend.Paths.returnSound('sounds/$name', getLibrary(key, library, 'sounds/$name.${backend.Paths.SOUND_EXT}', SOUND), true, false);
	}

	/**
	 * One of the sounds numbered from `min` to `max`: "thing1", "thing2"...
	 */
	public static function soundRandom(key:String, min:Int, max:Int, ?library:String):Sound
	{
		return backend.Paths.sound(stripLibrary(key) + FlxG.random.int(min, max));
	}

	public static function music(key:String, ?library:String):Sound
	{
		var name:String = stripLibrary(key);
		var sound:Sound = backend.Paths.returnSound('music/$name', getLibrary(key, library, 'music/$name.${backend.Paths.SOUND_EXT}', SOUND), true, false);

		// V-Slice keeps each music in a folder of its own ("freakyMenu/freakyMenu"), the engine's are on their own ("freakyMenu")
		var parts:Array<String> = name.split('/');
		if(sound == null && parts.length >= 2 && parts[parts.length - 1] == parts[parts.length - 2])
		{
			parts.pop();
			var plain:String = parts.join('/');
			sound = backend.Paths.returnSound('music/$plain', getLibrary(key, library, 'music/$plain.${backend.Paths.SOUND_EXT}', SOUND), true, false);
		}
		return sound;
	}

	public static function inst(song:String, ?suffix:String):Sound
	{
		return backend.Paths.inst(song);
	}

	public static function voices(song:String, ?suffix:String):Sound
	{
		return backend.Paths.voices(song, suffix);
	}

	/**
	 * Folder of a texture atlas inside the images folder, as `FunkinSprite.loadTextureAtlas()` takes it.
	 */
	public static function animateAtlas(path:String, ?library:String):String
	{
		return stripLibrary(path);
	}

	// A mod's own font, then V-Slice's (the engine's "vcr.ttf" is another font, its HUD's, and scripts lay their texts out by
	// V-Slice's: spaces to line words up), then the engine's
	public static function font(key:String):String
	{
		var found:String = backend.Paths.font(key);
		#if sys
		if(StringTools.startsWith(found, 'assets/'))
		{
			var vslice:String = backend.PolymodCompat.BASE_FOLDER + '/fonts/$key';
			if(sys.FileSystem.exists(vslice)) return vsliceFont(vslice);
		}
		#end
		return found;
	}

	#if sys
	static var vsliceFonts:Map<String, String> = [];

	// A font of V-Slice's, loaded from its bytes and given by its name instead of by its path: OpenFL also finds fonts by the name
	// of their file, and the engine's own "vcr.ttf" (its HUD's) would be taken for it, or it for the engine's
	static function vsliceFont(path:String):String
	{
		if(vsliceFonts.exists(path)) return vsliceFonts.get(path);
		var font:openfl.text.Font = null;
		try
		{
			font = openfl.text.Font.fromBytes(openfl.utils.ByteArray.fromBytes(sys.io.File.getBytes(path)));
		}
		catch(e:Dynamic) {}
		if(font == null || font.fontName == null || font.fontName.length < 1) return path;

		@:privateAccess
		{
			openfl.text.Font.__registeredFonts.push(font);
			openfl.text.Font.__fontByName.set(font.fontName, font);
		}
		vsliceFonts.set(path, font.fontName);
		return font.fontName;
	}
	#end

	public static function file(key:String, ?type:Dynamic, ?library:String):String
	{
		return backend.Paths.getPath(stripLibrary(key));
	}

	public static function txt(key:String, ?library:String):String
	{
		return backend.Paths.getPath('data/${stripLibrary(key)}.txt');
	}

	public static function json(key:String, ?library:String):String
	{
		return backend.Paths.getPath('data/${stripLibrary(key)}.json');
	}

	public static function frag(key:String, ?library:String):String
	{
		return backend.Paths.getPath('shaders/${stripLibrary(key)}.frag');
	}

	public static function vert(key:String, ?library:String):String
	{
		return backend.Paths.getPath('shaders/${stripLibrary(key)}.vert');
	}

	public static function videos(key:String, ?library:String):String
	{
		return backend.Paths.video(stripLibrary(key));
	}

	public static function exists(key:String):Bool
	{
		#if sys
		return sys.FileSystem.exists(backend.Paths.getPath(stripLibrary(key)));
		#else
		return openfl.utils.Assets.exists(backend.Paths.getPath(stripLibrary(key)));
		#end
	}
}
