package funkin.util;

import haxe.io.Bytes;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * V-Slice's file functions, the ones scripts use (reading the game's folders, keeping files of their own). Like V-Slice's version
 * for scripts, it only works inside of the game's folder: paths that go out of it ("..", "C:/...") are refused.
 * Opening the system's file dialogs and making zip files aren't here.
 */
class FileUtil
{
	public static var gameDirectory(get, never):String;
	static function get_gameDirectory():String
	{
		#if sys
		return haxe.io.Path.addTrailingSlash(Sys.getCwd());
		#else
		return '';
		#end
	}

	/**
	 * The path inside of the game's folder, or null if it'd be outside of it.
	 */
	public static function sanitizePath(path:String):String
	{
		if(path == null) return null;
		path = StringTools.trim(path).split('\\').join('/');
		if(path.length < 1 || haxe.io.Path.isAbsolute(path) || path.indexOf(':') > -1) return null;
		for (part in path.split('/'))
			if(part == '..') return null;
		return path;
	}

	public static function isProtected(path:String):Bool return sanitizePath(path) == null;

	public static function readStringFromPath(path:String):String
	{
		#if sys
		path = sanitizePath(path);
		return (path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path)) ? File.getContent(path) : null;
		#else
		return null;
		#end
	}

	public static function readBytesFromPath(path:String):Bytes
	{
		#if sys
		path = sanitizePath(path);
		return (path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path)) ? File.getBytes(path) : null;
		#else
		return null;
		#end
	}

	public static function readJSONFromPath(path:String):Dynamic
	{
		var text:String = readStringFromPath(path);
		if(text == null) return null;
		try
		{
			return haxe.Json.parse(text);
		}
		catch(e:Dynamic)
		{
			trace('Could not read the JSON of "$path": $e');
			return null;
		}
	}

	/**
	 * @param mode 	"force" replaces what's there, "skip" leaves a file that's already there alone (V-Slice's `FileWriteMode`).
	 */
	public static function writeStringToPath(path:String, data:String, ?mode:Dynamic):Void
	{
		#if sys
		path = sanitizePath(path);
		if(path == null || data == null) return;
		if(isSkip(mode) && FileSystem.exists(path)) return;
		makeFolderFor(path);
		File.saveContent(path, data);
		#end
	}

	public static function writeBytesToPath(path:String, data:Bytes, ?mode:Dynamic):Void
	{
		#if sys
		path = sanitizePath(path);
		if(path == null || data == null) return;
		if(isSkip(mode) && FileSystem.exists(path)) return;
		makeFolderFor(path);
		File.saveBytes(path, data);
		#end
	}

	public static function appendStringToPath(path:String, data:String):Void
	{
		#if sys
		path = sanitizePath(path);
		if(path == null || data == null) return;
		makeFolderFor(path);
		var output = File.append(path, false);
		output.writeString(data);
		output.close();
		#end
	}

	public static function deleteFile(path:String):Void
	{
		#if sys
		path = sanitizePath(path);
		if(path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path)) FileSystem.deleteFile(path);
		#end
	}

	public static function getFileSize(path:String):Int
	{
		#if sys
		path = sanitizePath(path);
		return (path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path)) ? FileSystem.stat(path).size : 0;
		#else
		return 0;
		#end
	}

	public static function pathExists(path:String):Bool
	{
		#if sys
		path = sanitizePath(path);
		return path != null && FileSystem.exists(path);
		#else
		return false;
		#end
	}

	public static function fileExists(path:String):Bool
	{
		#if sys
		path = sanitizePath(path);
		return path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path);
		#else
		return false;
		#end
	}

	public static function directoryExists(path:String):Bool
	{
		#if sys
		path = sanitizePath(path);
		return path != null && FileSystem.exists(path) && FileSystem.isDirectory(path);
		#else
		return false;
		#end
	}

	public static function createDirIfNotExists(dir:String):Void
	{
		#if sys
		dir = sanitizePath(dir);
		if(dir != null && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		#end
	}

	/**
	 * The names of what's in a folder, an empty list if it isn't one.
	 */
	public static function readDir(path:String):Array<String>
	{
		#if sys
		path = sanitizePath(path);
		return (path != null && FileSystem.exists(path) && FileSystem.isDirectory(path)) ? FileSystem.readDirectory(path) : [];
		#else
		return [];
		#end
	}

	static function isSkip(mode:Dynamic):Bool
	{
		return mode != null && Std.string(mode).toLowerCase() == 'skip';
	}

	#if sys
	static function makeFolderFor(path:String):Void
	{
		var folder:String = haxe.io.Path.directory(path);
		if(folder.length > 0 && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
	}
	#end
}
