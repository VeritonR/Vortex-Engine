package funkin.util;

import funkin.util.FileUtilBase.LimeDialogs;

import openfl.net.FileFilter;
import haxe.zip.Entry;
import openfl.net.FileReference;
import lime.utils.Bytes as LimeBytes;
import haxe.io.Path;

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
	// (the rest of V-Slice's functions for scripts, done by its sandboxed version: FileUtilSandboxed below)
	public static var browseFileReference:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'browseFileReference'), args));
	public static var browseForDirectory:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'browseForDirectory'), args));
	public static var browseForFile:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'browseForFile'), args));
	public static var browseForMultipleFiles:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'browseForMultipleFiles'), args));
	public static var browseForSaveFile:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'browseForSaveFile'), args));
	public static var createZIPFromEntries:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'createZIPFromEntries'), args));
	public static var deleteDir:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'deleteDir'), args));
	public static var getDirSize:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'getDirSize'), args));
	public static var getTempDir:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'getTempDir'), args));
	public static var makeZIPEntry:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'makeZIPEntry'), args));
	public static var makeZIPEntryFromBytes:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'makeZIPEntryFromBytes'), args));
	public static var mapZIPEntriesByName:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'mapZIPEntriesByName'), args));
	public static var moveDir:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'moveDir'), args));
	public static var moveFile:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'moveFile'), args));
	public static var openFolder:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'openFolder'), args));
	public static var openSelectFile:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'openSelectFile'), args));
	public static var readZIPFromBytes:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'readZIPFromBytes'), args));
	public static var rename:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'rename'), args));
	public static var saveChartAsFNFC:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'saveChartAsFNFC'), args));
	public static var saveFile:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'saveFile'), args));
	public static var saveFilesAsZIP:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'saveFilesAsZIP'), args));
	public static var saveFilesAsZIPToPath:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'saveFilesAsZIPToPath'), args));
	public static var saveMultipleFiles:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'saveMultipleFiles'), args));
	public static var writeFileReference:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(FileUtilSandboxed, Reflect.field(FileUtilSandboxed, 'writeFileReference'), args));

	// (V-Slice's kinds of files for its file dialogs)
	public static final FILE_FILTER_FNFC:openfl.net.FileFilter = new openfl.net.FileFilter('Friday Night Funkin\' Chart', '*.fnfc');
	public static final FILE_FILTER_FNFS:openfl.net.FileFilter = new openfl.net.FileFilter('Friday Night Funkin\' Stage', '*.fnfs');
	public static final FILE_FILTER_JSON:openfl.net.FileFilter = new openfl.net.FileFilter('JSON Data File', '*.json');
	public static final FILE_FILTER_TXT:openfl.net.FileFilter = new openfl.net.FileFilter('Text File', '*.txt');
	public static final FILE_FILTER_XML:openfl.net.FileFilter = new openfl.net.FileFilter('XML Data File', '*.xml');
	public static final FILE_FILTER_ZIP:openfl.net.FileFilter = new openfl.net.FileFilter('ZIP Archive', '*.zip');
	public static final FILE_FILTER_OGG:openfl.net.FileFilter = new openfl.net.FileFilter('OGG Audio File', '*.ogg');
	public static final FILE_FILTER_PNG:openfl.net.FileFilter = new openfl.net.FileFilter('PNG Image File', '*.png');
	public static final FILE_FILTER_SM:openfl.net.FileFilter = new openfl.net.FileFilter('StepMania File', '*.sm');
	public static final FILE_FILTER_OSU:openfl.net.FileFilter = new openfl.net.FileFilter('OSU! Beatmap File', '*.osu');

	/**
	 * Folders scripts can't write to, like on V-Slice: the game's own files.
	 */
	public static var PROTECTED_PATHS(get, never):Array<String>;
	static function get_PROTECTED_PATHS():Array<String> return ['assets', 'manifest', 'plugins', 'export'];

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

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum FileWriteMode
{
	/**
	 * Forcibly overwrite the file if it already exists.
	 */
	Force;

	/**
	 * Ask the user if they want to overwrite the file if it already exists.
	 */
	Ask;

	/**
	 * Skip the file if it already exists.
	 */
	Skip;
}

// (V-Slice's, for its classes and scripts)
@:structInit
class SelectedFileData
{
  public static function fromPath(path:String):SelectedFileData
  {
    return {
      name: new Path(path).file,
      bytes: LimeDialogs.fromFile(path),
      fullPath: path
    };
  }

  public var name:String;
  public var bytes:Bytes;
  public var fullPath:String;
}

// (V-Slice's, for its classes and scripts)
class FileUtilSandboxed
{
  /**
   * Prevent paths from exiting the root.
   *
   * @param path The path to sanitize.
   * @return The sanitized path.
   */
  public static function sanitizePath(path:String):String
  {
    path = (path ?? '').trim();
    if (path == '')
    {
      #if sys
      return FileUtilBase.gameDirectory;
      #else
      return '';
      #end
    }

    if (path.contains(':'))
    {
      path = path.substring(path.lastIndexOf(':') + 1);
    }

    path = path.replace('\\', '/');
    while (path.contains('//'))
    {
      path = path.replace('//', '/');
    }

    final parts:Array<String> = FileUtilBase.INVALID_CHARS.replace(path, '').split('/');
    final sanitized:Array<String> = new Array<String>();
    for (part in parts)
    {
      switch (part)
      {
        case '.' | '':
          continue;
        case '..':
          sanitized.pop();
        default:
          sanitized.push(part.trim());
      }
    }

    if (sanitized.length == 0)
    {
      #if sys
      return FileUtilBase.gameDirectory;
      #else
      return '';
      #end
    }

    #if sys
    // TODO: figure out how to get "real" path of symlinked paths
    #if linux
    // The implementation on Linux fails if the path doesn't exist
    var realPath:Null<String> = null;
    var unresolvedSegments:Array<String> = [];
    while (realPath == null && sanitized.length > 0)
    {
      realPath = sys.FileSystem.fullPath(Path.join([FileUtilBase.gameDirectory].concat(sanitized)));
      if (realPath == null) unresolvedSegments.unshift(sanitized.pop() ?? continue);
    }

    if (unresolvedSegments.length > 0)
    {
      if (realPath != null) unresolvedSegments.unshift(realPath);
      realPath = Path.join(unresolvedSegments);
    }
    #else
    final realPath:Null<String> = sys.FileSystem.fullPath(Path.join([FileUtilBase.gameDirectory].concat(sanitized)));
    #end

    if (realPath == null || !realPath.startsWith(FileUtilBase.gameDirectory))
    {
      return FileUtilBase.gameDirectory;
    }

    return realPath;
    #else
    return sanitized.join('/');
    #end
  }

  /**
   * Check against protected paths.
   * @param path The path to check.
   * @return Whether the path is protected.
   */
  public static function isProtected(path:String, sanitizeFirst:Bool = true):Bool
  {
    if (sanitizeFirst) path = sanitizePath(path);
    @:privateAccess for (protected in FileUtilBase.PROTECTED_PATHS)
    {
      if (path == protected || (protected.contains('*') && path.startsWith(protected.substring(0, protected.indexOf('*')))))
      {
        return true;
      }
    }

    return false;
  }

  public static final FILE_FILTER_FNFC:FileFilter = FileUtilBase.FILE_FILTER_FNFC;
  public static final FILE_FILTER_FNFS:FileFilter = FileUtilBase.FILE_FILTER_FNFS;
  public static final FILE_FILTER_JSON:FileFilter = FileUtilBase.FILE_FILTER_JSON;
  public static final FILE_FILTER_TXT:FileFilter = FileUtilBase.FILE_FILTER_TXT;
  public static final FILE_FILTER_XML:FileFilter = FileUtilBase.FILE_FILTER_XML;
  public static final FILE_FILTER_ZIP:FileFilter = FileUtilBase.FILE_FILTER_ZIP;
  public static final FILE_FILTER_OGG:FileFilter = FileUtilBase.FILE_FILTER_OGG;
  public static final FILE_FILTER_PNG:FileFilter = FileUtilBase.FILE_FILTER_PNG;
  public static final FILE_FILTER_SM:FileFilter = FileUtilBase.FILE_FILTER_SM;
  public static final FILE_FILTER_OSU:FileFilter = FileUtilBase.FILE_FILTER_OSU;

  public static function browseForDirectory(dialogTitle:String, onSelect:(String) -> Void, ?onCancel:() -> Void, ?defaultPath:String):Void
  {
    FileUtilBase.browseForDirectory(dialogTitle, onSelect, onCancel, defaultPath);
  }

  public static function browseForFile(dialogTitle:String, ?typeFilter:Array<FileFilter>, onSelect:(SelectedFileData) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    FileUtilBase.browseForFile(dialogTitle, typeFilter, onSelect, onCancel, defaultPath);
  }

  public static function browseForMultipleFiles(dialogTitle:String, ?typeFilter:Array<FileFilter>, onSelect:(Array<String>) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    FileUtilBase.browseForMultipleFiles(dialogTitle, typeFilter, onSelect, onCancel, defaultPath);
  }

  public static function browseForSaveFile(dialogTitle:String, ?typeFilter:Array<FileFilter>, onSelect:(String) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    FileUtilBase.browseForSaveFile(dialogTitle, typeFilter, onSelect, onCancel, defaultPath);
  }

  public static function saveFile(dialogTitle:String, data:Bytes, ?typeFilter:Array<FileFilter>, ?onSave:(String) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    FileUtilBase.saveFile(dialogTitle, data, typeFilter, onSave, onCancel, defaultPath);
  }

  public static function saveMultipleFiles(resources:Array<Entry>, ?onSaveAll:(Array<String>) -> Void, ?onCancel:() -> Void, ?defaultPath:String,
      force:Bool = false):Void
  {
    FileUtilBase.saveMultipleFiles(resources, onSaveAll, onCancel, defaultPath, force);
  }

  public static function saveFilesAsZIP(resources:Array<Entry>, ?onSave:(Array<String>) -> Void, ?onCancel:() -> Void, ?defaultPath:String,
      force:Bool = false):Void
  {
    FileUtilBase.saveFilesAsZIP(resources, onSave, onCancel, defaultPath, force);
  }

  public static function saveChartAsFNFC(resources:Array<Entry>, ?onSave:(Array<String>) -> Void, ?onCancel:() -> Void, ?defaultPath:String,
      force:Bool = false):Void
  {
    FileUtilBase.saveChartAsFNFC(resources, onSave, onCancel, defaultPath, force);
  }

  public static function saveFilesAsZIPToPath(resources:Array<Entry>, path:String, mode:FileWriteMode = Skip):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot write to protected path: $path';
    FileUtilBase.saveFilesAsZIPToPath(resources, path, mode);
  }

  public static function readStringFromPath(path:String):String
  {
    return FileUtilBase.readStringFromPath(sanitizePath(path));
  }

  public static function readBytesFromPath(path:String):Bytes
  {
    return FileUtilBase.readBytesFromPath(sanitizePath(path));
  }

  public static function browseFileReference(callback:(FileReference) -> Void):Void
  {
    FileUtilBase.browseFileReference(callback);
  }

  public static function writeFileReference(path:String, data:String, callback:String->Void):Void
  {
    FileUtilBase.writeFileReference(path, data, callback);
  }

  public static function readJSONFromPath(path:String):Dynamic
  {
    return FileUtilBase.readJSONFromPath(sanitizePath(path));
  }

  public static function writeStringToPath(path:String, data:String, mode:FileWriteMode = Skip):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot write to protected path: $path';
    FileUtilBase.writeStringToPath(path, data, mode);
  }

  public static function writeBytesToPath(path:String, data:Bytes, mode:FileWriteMode = Skip):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot write to protected path: $path';
    FileUtilBase.writeBytesToPath(path, data, mode);
  }

  public static function appendStringToPath(path:String, data:String):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot write to protected path: $path';
    FileUtilBase.appendStringToPath(path, data);
  }

  public static function moveFile(path:String, destination:String):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot move protected path: $path';
    if (isProtected(destination = sanitizePath(destination), false)) throw 'Cannot move to protected path: $destination';
    FileUtilBase.moveFile(path, destination);
  }

  public static function deleteFile(path:String):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot delete protected path: $path';
    FileUtilBase.deleteFile(path);
  }

  public static function getFileSize(path:String):Int
  {
    return FileUtilBase.getFileSize(sanitizePath(path));
  }

  public static function pathExists(path:String):Bool
  {
    return FileUtilBase.pathExists(sanitizePath(path));
  }

  public static function fileExists(path:String):Bool
  {
    return FileUtilBase.fileExists(sanitizePath(path));
  }

  public static function directoryExists(path:String):Bool
  {
    return FileUtilBase.directoryExists(sanitizePath(path));
  }

  public static function createDirIfNotExists(dir:String):Void
  {
    FileUtilBase.createDirIfNotExists(sanitizePath(dir));
  }

  public static function readDir(path:String):Array<String>
  {
    return FileUtilBase.readDir(sanitizePath(path));
  }

  public static function moveDir(path:String, destination:String, ?ignore:Array<String>, strict:Bool = true):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot move protected path: "$path"';
    if (isProtected(destination = sanitizePath(destination), false)) throw 'Cannot move to protected path: "$destination"';
    FileUtilBase.moveDir(path, destination, ignore, strict);
  }

  public static function deleteDir(path:String, recursive:Bool = false, ?ignore:Array<String>):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot delete protected path: "$path"';
    FileUtilBase.deleteDir(path, recursive, ignore);
  }

  public static function getDirSize(path:String):Int
  {
    return FileUtilBase.getDirSize(sanitizePath(path));
  }

  public static function getTempDir():Null<String>
  {
    return FileUtilBase.getTempDir();
  }

  public static function rename(path:String, newName:String, keepExtension:Bool = true):Void
  {
    if (isProtected(path = sanitizePath(path), false)) throw 'Cannot rename protected path: "$path"';
    FileUtilBase.rename(path, sanitizePath(newName), keepExtension);
  }

  public static function createZIPFromEntries(entries:Array<Entry>):Bytes
  {
    return FileUtilBase.createZIPFromEntries(entries);
  }

  public static function readZIPFromBytes(input:Bytes):Array<Entry>
  {
    return FileUtilBase.readZIPFromBytes(input);
  }

  public static function mapZIPEntriesByName(input:Array<Entry>):Map<String, Entry>
  {
    return FileUtilBase.mapZIPEntriesByName(input);
  }

  public static function makeZIPEntry(name:String, content:String):Entry
  {
    return FileUtilBase.makeZIPEntry(name, content);
  }

  public static function makeZIPEntryFromBytes(name:String, data:haxe.io.Bytes):Entry
  {
    return FileUtilBase.makeZIPEntryFromBytes(name, data);
  }

  public static function openFolder(pathFolder:String, createIfNotExists:Bool = true):Void
  {
    FileUtilBase.openFolder(sanitizePath(pathFolder), createIfNotExists);
  }

  public static function openSelectFile(path:String):Void
  {
    FileUtilBase.openSelectFile(sanitizePath(path));
  }
}
