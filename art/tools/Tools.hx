package;

import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * What the tools in this folder share: paths, folders, sizes, JSON.
 */
class Tools
{
	/**
	 * The engine's folder (the one with Project.xml): the current folder or one above it.
	 */
	public static function engineRoot():String
	{
		var dir:String = full(Sys.getCwd());
		while (true)
		{
			if (FileSystem.exists('$dir/Project.xml') && FileSystem.isDirectory('$dir/art')) return dir;
			var up:String = parent(dir);
			if (up == null || up == dir) break;
			dir = up;
		}
		fail('Run it from the engine\'s folder (the one with Project.xml), for example: haxe art/export_clean_build.hxml');
		return null;
	}

	// An absolute path with "/" and no "/" at the end
	public static function full(path:String):String
	{
		var p:String = FileSystem.fullPath(path).replace('\\', '/');
		while (p.length > 1 && p.endsWith('/') && !p.endsWith(':/')) p = p.substr(0, p.length - 1);
		return p;
	}

	public static function parent(path:String):String
	{
		var i:Int = path.lastIndexOf('/');
		if (i <= 0) return null;
		var up:String = path.substr(0, i);
		return up.endsWith(':') ? up + '/' : up;
	}

	public static function baseName(path:String):String
		return path.substr(path.lastIndexOf('/') + 1);

	// (Windows doesn't tell the case of a letter apart in paths)
	static function key(path:String):String
		return Sys.systemName() == 'Windows' ? path.toLowerCase() : path;

	public static function samePath(a:String, b:String):Bool
		return key(a) == key(b);

	// If "path" is inside "folder"
	public static function inside(path:String, folder:String):Bool
		return key(path).startsWith(key(folder) + '/');

	public static function compare(a:String, b:String):Int
		return a < b ? -1 : (a > b ? 1 : 0);

	public static function deleteFolder(path:String)
	{
		for (name in FileSystem.readDirectory(path))
		{
			var p:String = '$path/$name';
			if (FileSystem.isDirectory(p)) deleteFolder(p);
			else FileSystem.deleteFile(p);
		}
		FileSystem.deleteDirectory(path);
	}

	// Empties a folder but keeps it (it can be in use)
	public static function emptyFolder(path:String)
	{
		for (name in FileSystem.readDirectory(path))
		{
			var p:String = '$path/$name';
			if (FileSystem.isDirectory(p)) deleteFolder(p);
			else FileSystem.deleteFile(p);
		}
	}

	public static function makeFolderOf(file:String)
	{
		var dir:String = parent(file);
		if (dir != null && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
	}

	public static function isFile(path:String):Bool
		return FileSystem.exists(path) && !FileSystem.isDirectory(path);

	public static function isDir(path:String):Bool
		return FileSystem.exists(path) && FileSystem.isDirectory(path);

	// (Haxe gives the size in 32 bits: a file over 2 GB comes negative)
	public static function fileSize(path:String):Float
	{
		var size:Float = FileSystem.stat(path).size;
		return size < 0 ? size + 4294967296 : size;
	}

	// The size of a file, or of everything in a folder
	public static function sizeOf(path:String):Float
	{
		if (!FileSystem.isDirectory(path)) return fileSize(path);
		var total:Float = 0.0;
		for (name in FileSystem.readDirectory(path)) total += sizeOf('$path/$name');
		return total;
	}

	// Every file under a folder, as paths relative to it (with "/")
	public static function filesIn(folder:String, ?rel:String = ''):Array<String>
	{
		var out:Array<String> = [];
		var dir:String = rel == '' ? folder : '$folder/$rel';
		for (name in FileSystem.readDirectory(dir))
		{
			var r:String = rel == '' ? name : '$rel/$name';
			if (FileSystem.isDirectory('$folder/$r')) out = out.concat(filesIn(folder, r));
			else out.push(r);
		}
		return out;
	}

	// A text file, without the BOM some have at the start
	public static function readText(path:String):String
	{
		var text:String = File.getContent(path);
		if (text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
		return text;
	}

	public static function readJson(path:String):Dynamic
		return haxe.Json.parse(readText(path));

	public static function md5(path:String):String
		return haxe.crypto.Md5.make(File.getBytes(path)).toHex();

	public static function mb(bytes:Float):String
		return oneDecimal(bytes / 1048576) + ' MB';

	// 12.3 (always with one number after the dot)
	public static function oneDecimal(value:Float):String
	{
		var tenths:Float = Math.fround(value * 10);
		var whole:String = Std.string(Math.ffloor(tenths / 10));
		if (whole.indexOf('.') >= 0) whole = whole.substr(0, whole.indexOf('.'));
		return whole + '.' + Std.string(Std.int(tenths - Math.ffloor(tenths / 10) * 10));
	}

	public static function fail(message:String)
	{
		Sys.stderr().writeString(message + '\n');
		Sys.exit(1);
	}
}
