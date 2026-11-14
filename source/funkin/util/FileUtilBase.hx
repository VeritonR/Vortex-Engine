package funkin.util;

import funkin.util.FileUtil.FileWriteMode;
import funkin.util.FileUtil.SelectedFileData;

// V-Slice's whole FileUtil (its file dialogs, zip files, moving and deleting): the engine's own version under it, which scripts don't
// get. Scripts get funkin.util.FileUtil, which goes through V-Slice's sandboxed version of this (FileUtilSandboxed), inside of the
// game's folder.
import haxe.zip.Entry;
import lime.utils.Bytes;
import lime.ui.FileDialog;
import openfl.Lib;
import openfl.net.FileFilter;
import haxe.io.Path;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
using StringTools;

/**
 * Utilities for reading and writing files on various platforms.
 */
@:nullSafety
class FileUtilBase
{
  /**
   * File filter for Friday Night Funkin' chart files.
   */
  public static final FILE_FILTER_FNFC:FileFilter = new FileFilter('Friday Night Funkin\' Chart', '*.fnfc');

  /**
   * File filter for Friday Night Funkin' stage files.
   */
  public static final FILE_FILTER_FNFS:FileFilter = new FileFilter('Friday Night Funkin\' Stage', '*.fnfs');

  /**
   * File filter for JSON data files.
   */
  public static final FILE_FILTER_JSON:FileFilter = new FileFilter('JSON Data File', '*.json');

  /**
   * File filter for plain text files.
   */
  public static final FILE_FILTER_TXT:FileFilter = new FileFilter('Text File', '*.txt');

  /**
   * File filter for XML data files.
   */
  public static final FILE_FILTER_XML:FileFilter = new FileFilter('XML Data File', '*.xml');

  /**
   * File filter for ZIP archive files.
   */
  public static final FILE_FILTER_ZIP:FileFilter = new FileFilter('ZIP Archive', '*.zip');

  /**
   * File filter for OGG audio files.
   */
  public static final FILE_FILTER_OGG:FileFilter = new FileFilter('OGG Audio File', '*.ogg');

  /**
   * File filter for PNG image files.
   */
  public static final FILE_FILTER_PNG:FileFilter = new FileFilter('PNG Image File', '*.png');

  /**
   * File filter for StepMania chart files.
   */
  public static final FILE_FILTER_SM:FileFilter = new FileFilter('StepMania File', '*.sm');

  /**
   * File filter for OSU! beatmap files.
   */
  public static final FILE_FILTER_OSU:FileFilter = new FileFilter('OSU! Beatmap File', '*.osu');

  /**
   * Paths which should not be deleted or modified by scripts.
   */
  public static var PROTECTED_PATHS(get, never):Array<String>;

  static function get_PROTECTED_PATHS():Array<String>
  {
    final protected:Array<String> = [
      '',
      '.',
      'assets',
      'assets/*',
      'backups',
      'backups/*',
      'manifest',
      'manifest/*',
      'plugins',
      'plugins/*',
      'Funkin.exe',
      'Funkin',
      'icon.ico',
      'libvlc.dll',
      'libvlccore.dll',
      'lime.ndll',
      'scores.json'
    ];

    #if sys
    for (i in 0...protected.length)
    {
      // On Linux 'fullPath' just makes most of these null which actually just makes the paths unprotected
      protected[i] = #if !linux sys.FileSystem.fullPath #end (Path.join([gameDirectory, protected[i]]));
    }
    #end

    return protected;
  }

  /**
   * Regex for invalid filesystem characters.
   */
  public static final INVALID_CHARS:EReg = ~/[:*?"<>|\n\r\t]/g;

  #if sys
  private static var _gameDirectory:Null<String> = null;
  public static var gameDirectory(get, never):String;

  public static function get_gameDirectory():String
  {
    if (_gameDirectory != null)
    {
      return _gameDirectory;
    }

    return _gameDirectory = sys.FileSystem.fullPath(Path.directory(Sys.programPath()));
  }
  #end

  /**
   * Browses for a directory.
   *
   * Note that on HTML5 this will immediately fail.
   */
  public static function browseForDirectory(dialogTitle:String, onSelect:(String) -> Void, ?onCancel:() -> Void, ?defaultPath:String):Void
  {
    #if html5
    trace('WARNING: browseForDirectory not implemented for this platform');

    if (onCancel != null)
    {
      onCancel();
    }
    #else
    LimeDialogs.openDirectory(Lib.current.stage.window, dialogTitle, function(filepaths:Array<String>):Void
    {
      if (filepaths.length > 0)
      {
        if (onSelect != null)
        {
          onSelect(filepaths[0]);
        }
      }
      else
      {
        if (onCancel != null)
        {
          onCancel();
        }
      }
    }, defaultPath, false);
    #end
  }

  /**
   * Browses for a file.
   *
   * Note that on HTML5 this will immediately fail.
   */
  public static function browseForFile(dialogTitle:String, ?typeFilter:Array<FileFilter>, onSelect:(SelectedFileData) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    #if html5
    trace('WARNING: browseForFile not implemented for this platform');

    if (onCancel != null)
    {
      onCancel();
    }
    #else
    LimeDialogs.openFile(Lib.current.stage.window, dialogTitle, function(filepaths:Array<String>, filter):Void
    {
      if (filepaths.length > 0)
      {
        if (onSelect != null)
        {
          onSelect(SelectedFileData.fromPath(filepaths[0]));
        }
      }
      else
      {
        if (onCancel != null)
        {
          onCancel();
        }
      }
    }, LimeDialogs.filterOf(typeFilter),
      defaultPath, false);
    #end
  }

  /**
   * Browses for a multiple files.
   *
   * Note that on HTML5 this will immediately fail.
   */
  public static function browseForMultipleFiles(dialogTitle:String, ?typeFilter:Array<FileFilter>, onSelect:(Array<String>) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    #if html5
    trace('WARNING: browseForMultipleFiles not implemented for this platform');

    if (onCancel != null)
    {
      onCancel();
    }
    #else
    LimeDialogs.openFile(Lib.current.stage.window, dialogTitle, function(filepaths:Array<String>, filter):Void
    {
      if (filepaths.length > 0)
      {
        if (onSelect != null)
        {
          onSelect(filepaths);
        }
      }
      else
      {
        if (onCancel != null)
        {
          onCancel();
        }
      }
    }, LimeDialogs.filterOf(typeFilter),
      defaultPath, true);
    #end
  }

  /**
   * Browses for a file location to save to.
   *
   * Note that on HTML5 this will immediately fail.
   */
  public static function browseForSaveFile(dialogTitle:String, ?typeFilter:Array<FileFilter>, onSelect:(String) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    #if html5
    trace('WARNING: browseForSaveFile not implemented for this platform');

    if (onCancel != null)
    {
      onCancel();
    }
    #else
    LimeDialogs.saveFile(Lib.current.stage.window, dialogTitle, function(filepath:String, filter):Void
    {
      if (filepath != null)
      {
        if (onSelect != null)
        {
          onSelect(filepath);
        }
      }
      else
      {
        if (onCancel != null)
        {
          onCancel();
        }
      }
    }, LimeDialogs.filterOf(typeFilter), defaultPath);
    #end
  }

  /**
   * Browses for a single file location, then writes the provided `haxe.io.Bytes` data and calls `onSave(path)` when done.
   *
   * Note that on HTML5 this will immediately fail.
   */
  public static function saveFile(dialogTitle:String, data:Bytes, ?typeFilter:Array<FileFilter>, ?onSave:(String) -> Void, ?onCancel:() -> Void,
      ?defaultPath:String):Void
  {
    #if html5
    trace('WARNING: saveFile not implemented for this platform');

    if (onCancel != null)
    {
      onCancel();
    }
    #else
    LimeDialogs.saveFile(Lib.current.stage.window, dialogTitle, function(filepath:String, filter):Void
    {
      if (filepath != null)
      {
        if (data != null)
        {
          LimeDialogs.toFile(filepath, data);
        }

        if (onSave != null)
        {
          onSave(filepath);
        }
      }
      else
      {
        if (onCancel != null)
        {
          onCancel();
        }
      }
    }, LimeDialogs.filterOf(typeFilter), defaultPath);
    #end
  }

  /**
   * Prompts the user to save multiple files.
   * On desktop, this will prompt the user for a directory, then write all of the files to there.
   * On HTML5, this will zip the files up and prompt the user to save that.
   *
   * @param typeFilter TODO What does this do?
   * @return Whether the file dialog was opened successfully.
   */
  public static function saveMultipleFiles(resources:Array<Entry>, ?onSaveAll:(Array<String>) -> Void, ?onCancel:() -> Void, ?defaultPath:String,
      force:Bool = false):Void
  {
    #if html5
    trace('WARNING: saveMultipleFiles not implemented for this platform');

    if (onCancel != null)
    {
      onCancel();
    }
    #elseif desktop
    trace('Browsing for directory to save individual files to...');

    browseForDirectory('Choose directory to save all files to...', function(targetPath:String):Void
    {
      var paths:Array<String> = new Array<String>();

      for (resource in resources)
      {
        if (resource.data == null)
        {
          trace('WARNING: File ${resource.fileName} has no data or content. Skipping.');
          continue;
        }

        var filePath:String = Path.join([targetPath, resource.fileName]);

        paths.push(filePath);
      }

      if (onSaveAll != null)
      {
        onSaveAll(paths);
      }
    }, onCancel, defaultPath);
    #else
    saveFilesAsZIP(resources, onSaveAll, onCancel, defaultPath, force);
    #end
  }

  /**
   * Takes an array of file entries and prompts the user to save them as a ZIP file.
   */
  public static function saveFilesAsZIP(resources:Array<Entry>, ?onSave:(Array<String>) -> Void, ?onCancel:() -> Void, ?defaultPath:String,
      force:Bool = false):Void
  {
    saveFile('Save files as ZIP...', createZIPFromEntries(resources), [FILE_FILTER_ZIP], function(path:String)
    {
      trace('Saved ${resources.length} files to ZIP at "$path"');

      if (onSave != null)
      {
        onSave([path]);
      }
    }, onCancel, defaultPath);
  }

  /**
   * Takes an array of file entries and prompts the user to save them as a FNFC file.
   */
  public static function saveChartAsFNFC(resources:Array<Entry>, ?onSave:(Array<String>) -> Void, ?onCancel:() -> Void, ?defaultPath:String,
      force:Bool = false):Void
  {
    saveFile('Save chart as FNFC...', createZIPFromEntries(resources), [FILE_FILTER_FNFC], function(path:String)
    {
      trace('Saved FNFC file to "$path"');

      if (onSave != null)
      {
        onSave([path]);
      }
    }, onCancel, defaultPath);
  }

  /**
   * Takes an array of file entries and forcibly writes a ZIP to the given path.
   *
   * Only works on native.
   *
   * @param force Whether to force overwrite an existing file.
   */
  public static function saveFilesAsZIPToPath(resources:Array<Entry>, path:String, mode:FileWriteMode = Skip):Void
  {
    #if sys
    writeBytesToPath(path, createZIPFromEntries(resources), mode);
    #end
  }

  /**
   * Read string file contents directly from a given path.
   * Only works on native.
   *
   * @param path The path to the file.
   * @return The file contents.
   */
  public static function readStringFromPath(path:String):String
  {
    #if sys
    return sys.io.File.getContent(path);
    #else
    throw 'Direct file reading by path is not supported on this platform.';
    #end
  }

  /**
   * Read bytes file contents directly from a given path.
   * Only works on native.
   *
   * @param path The path to the file.
   * @return The file contents.
   */
  public static function readBytesFromPath(path:String):Bytes
  {
    #if sys
    return sys.io.File.getBytes(path);
    #else
    throw 'Direct file reading by path is not supported on this platform.';
    #end
  }

  /**
   * Browse for a file to read and execute a callback once we have a file reference.
   * Works great on HTML5 or desktop.
   *
   * @param	callback The function to call when the file is loaded.
   */
  public static function browseFileReference(callback:(FileReference) -> Void):Void
  {
    var file = new FileReference();
    file.addEventListener(Event.SELECT, function(e)
    {
      var selectedFileRef:FileReference = e.target;
      trace('Selected file: ' + selectedFileRef.name);

      selectedFileRef.addEventListener(Event.COMPLETE, function(e)
      {
        var loadedFileRef:FileReference = e.target;
        trace('Loaded file: ' + loadedFileRef.name);

        callback(loadedFileRef);
      });

      selectedFileRef.load();
    });

    file.browse();
  }

  /**
   * Prompts the user to save a file to their computer.
   */
  public static function writeFileReference(path:String, data:String, callback:String->Void)
  {
    var file = new FileReference();

    file.addEventListener(Event.COMPLETE, function(e:Event)
    {
      trace('Successfully wrote file: "$path"');
      callback('success');
    });

    file.addEventListener(Event.CANCEL, function(e:Event)
    {
      trace('Cancelled writing file: "$path"');
      callback('info');
    });

    file.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent)
    {
      trace('IO error writing file: "$path"');
      callback('error');
    });

    file.save(data, path);
  }

  /**
   * Read JSON file contents directly from a given path.
   * Only works on native.
   *
   * @param path The path to the file.
   * @return The JSON data.
   */
  public static function readJSONFromPath(path:String):Dynamic
  {
    #if sys
    return SerializerUtil.fromJSON(sys.io.File.getContent(path));
    #else
    throw 'Direct file reading by path is not supported on this platform.';
    #end
  }

  /**
   * Write string file contents directly to a given path.
   * Only works on native.
   *
   * @param path The path to the file.
   * @param data The string to write.
   * @param mode Whether to Force, Skip, or Ask to overwrite an existing file.
   */
  public static function writeStringToPath(path:String, data:String, mode:FileWriteMode = Skip):Void
  {
    #if sys
    if (directoryExists(path))
    {
      throw 'Target path is a directory, not a file: "$path"';
    }

    createDirIfNotExists(Path.directory(path));

    switch (mode)
    {
      case Force:
        sys.io.File.saveContent(path, data);
      case Skip:
        if (!pathExists(path))
        {
          sys.io.File.saveContent(path, data);
        }
      case Ask:
        if (pathExists(path))
        {
          // TODO: We don't have the technology to use native popups yet.
          throw 'Entry at path already exists: $path';
        }
        else
        {
          sys.io.File.saveContent(path, data);
        }
    }
    #else
    throw 'Direct file writing by path is not supported on this platform.';
    #end
  }

  /**
   * Write byte file contents directly to a given path.
   * Only works on native.
   *
   * @param path The path to the file.
   * @param data The bytes to write.
   * @param mode Whether to Force, Skip, or Ask to overwrite an existing file.
   */
  public static function writeBytesToPath(path:String, data:Bytes, mode:FileWriteMode = Skip):Void
  {
    #if sys
    if (directoryExists(path))
    {
      throw 'Target path is a directory, not a file: "$path"';
    }

    var shouldWrite:Bool = true;
    switch (mode)
    {
      case Force:
        shouldWrite = true;
      case Skip:
        if (!pathExists(path))
        {
          shouldWrite = true;
        }
      case Ask:
        if (pathExists(path))
        {
          // TODO: We don't have the technology to use native popups yet.
          throw 'Entry at path already exists: "$path"';
        }
        else
        {
          shouldWrite = true;
        }
    }

    if (shouldWrite)
    {
      createDirIfNotExists(Path.directory(path));
      sys.io.File.saveBytes(path, data);
    }
    #else
    throw 'Direct file writing by path is not supported on this platform.';
    #end
  }

  /**
   * Write string file contents directly to the end of a file at the given path.
   * Only works on native.
   *
   * @param path The path to the file.
   * @param data The string to append.
   */
  public static function appendStringToPath(path:String, data:String):Void
  {
    #if sys
    if (!pathExists(path))
    {
      writeStringToPath(path, data, Force);
      return;
    }
    else if (directoryExists(path))
    {
      throw 'Target path is a directory, not a file: "$path"';
    }

    var output:Null<sys.io.FileOutput> = null;
    try
    {
      output = sys.io.File.append(path, false);
      output.writeString(data);
      output.close();
    }
    catch (e:Dynamic)
    {
      if (output != null)
      {
        output.close();
      }

      throw 'Failed to append to file: "$path"';
    }
    #else
    throw 'Direct file writing by path is not supported on this platform.';
    #end
  }

  /**
   * Moves a file from one location to another.
   * Only works on native.
   *
   * @param path The path to the file.
   * @param destination The path to move the file to.
   */
  public static function moveFile(path:String, destination:String):Void
  {
    #if sys
    if (Path.extension(destination) != '')
    {
      destination = Path.directory(destination);
    }

    sys.FileSystem.rename(path, Path.join([destination, Path.withoutDirectory(path)]));
    #else
    throw 'File moving is not supported on this platform.';
    #end
  }

  /**
   * Delete a file at the given path.
   * Only works on native.
   *
   * @param path The path to the file.
   */
  public static function deleteFile(path:String):Void
  {
    #if sys
    sys.FileSystem.deleteFile(path);
    #else
    throw 'File deletion is not supported on this platform.';
    #end
  }

  /**
   * Get a file's size in bytes. Max representable size is ~2.147 GB.
   * Only works on native.
   *
   * @param path The path to the file.
   * @return The size of the file in bytes.
   */
  public static function getFileSize(path:String):Int
  {
    #if sys
    return sys.FileSystem.stat(path).size;
    #else
    throw 'File size calculation is not supported on this platform.';
    #end
  }

  /**
   * Check if a path exists on the filesystem.
   * Only works on native.
   *
   * @param path The path to the potential file or directory.
   * @return Whether the path exists.
   */
  public static function pathExists(path:String):Bool
  {
    #if sys
    return sys.FileSystem.exists(path);
    #else
    return false;
    #end
  }

  /**
   * Check if a path is a file on the filesystem.
   * Only works on native.
   *
   * @param path The path to the potential file.
   * @return Whether the path exists and is a file.
   */
  public static function fileExists(path:String):Bool
  {
    #if sys
    return pathExists(path) && !directoryExists(path);
    #else
    throw 'Filesystem check is not supported on this platform.';
    #end
  }

  /**
   * Check if a path is a directory on the filesystem.
   * Only works on native.
   *
   * @param path The path to the potential directory.
   * @return Whether the path exists and is a directory.
   */
  public static function directoryExists(path:String):Bool
  {
    #if sys
    try
    {
      return sys.FileSystem.isDirectory(path);
    }
    catch (e:Dynamic)
    {
      return false;
    }
    #else
    throw 'Filesystem check is not supported on this platform.';
    #end
  }

  /**
   * Create a directory if it doesn't already exist.
   * Only works on native.
   *
   * @param dir The path to the directory.
   */
  public static function createDirIfNotExists(dir:String):Void
  {
    if (!directoryExists(dir))
    {
      #if sys
      sys.FileSystem.createDirectory(dir);
      #else
      throw 'Directory creation is not supported on this platform.';
      #end
    }
  }

  /**
   * List all entries in a directory.
   * Only works on native.
   *
   * @param path The path to the directory.
   * @return An array of entries in the directory.
   */
  public static function readDir(path:String):Array<String>
  {
    #if sys
    return sys.FileSystem.readDirectory(path);
    #else
    throw 'Directory reading is not supported on this platform.';
    #end
  }

  /**
   * Move a directory from one location to another, optionally ignoring some paths.
   * Only works on native.
   *
   * @param path The path to the directory.
   * @param destination The path to move the directory to.
   * @param ignore A list of paths to ignore.
   * @param strict Fails if the destination directory is not empty.
   */
  public static function moveDir(path:String, destination:String, ?ignore:Array<String>, strict:Bool = true):Void
  {
    #if sys
    if (!directoryExists(path))
    {
      throw 'Path is not a directory: "$path"';
    }

    createDirIfNotExists(destination);
    if (strict)
    {
      // Ensure the destination is empty if strict mode is enabled.
      var entries:Array<String> = readDir(destination);
      if (entries.length > 0)
      {
        throw 'Destination directory "$destination" is not empty.';
      }
    }

    var stack:Array<String> = [path];
    while (stack.length > 0)
    {
      var currentPath:Null<String> = stack.pop();
      if (currentPath == null) continue;

      var entries:Array<String> = readDir(currentPath);
      for (entry in entries)
      {
        var entryPath:String = Path.join([currentPath, entry]);
        if (ignore != null && ignore.contains(entryPath)) continue;
        if (directoryExists(entryPath))
        {
          stack.push(entryPath);
        }
        else
        {
          moveFile(entryPath, Path.join([destination, entry]));
        }
      }
    }

    if (readDir(path)?.length == 0)
    {
      deleteDir(path);
    }
    #else
    throw 'Directory moving is not supported on this platform.';
    #end
  }

  /**
   * Delete a directory, optionally including its contents, and optionally ignoring some paths.
   * Only works on native.
   *
   * @param path The path to the directory.
   * @param recursive Whether to delete all contents of the directory.
   * @param ignore A list of paths to ignore.
   */
  public static function deleteDir(path:String, recursive:Bool = false, ?ignore:Array<String>):Void
  {
    #if sys
    if (!directoryExists(path))
    {
      throw 'Path is not a valid directory: "$path"';
    }

    if (recursive)
    {
      var stack:Array<String> = [path];
      while (stack.length > 0)
      {
        var currentPath:Null<String> = stack.pop();
        if (currentPath == null) continue;

        var entries:Array<String> = readDir(currentPath);
        for (entry in entries)
        {
          var entryPath:String = Path.join([currentPath, entry]);
          if (ignore != null && ignore.contains(entryPath)) continue;
          if (directoryExists(entryPath))
          {
            stack.push(entryPath);
          }
          else
          {
            deleteFile(entryPath);
          }
        }
      }
    }
    else
    {
      sys.FileSystem.deleteDirectory(path);
    }
    #else
    throw 'Directory deletion is not supported on this platform.';
    #end
  }

  /**
   * Get a directory's total size in bytes. Max representable size is ~2.147 GB.
   * Only works on native.
   *
   * @param path The path to the directory.
   * @return The total size of the directory in bytes.
   */
  public static function getDirSize(path:String):Int
  {
    #if sys
    if (!directoryExists(path))
    {
      throw 'Path is not a valid directory path: $path';
    }

    var stack:Array<String> = [path];
    var total:Int = 0;
    while (stack.length > 0)
    {
      var currentPath:Null<String> = stack.pop();
      if (currentPath == null) continue;

      for (entry in readDir(currentPath))
      {
        var entryPath:String = Path.join([currentPath, entry]);
        if (directoryExists(entryPath))
        {
          stack.push(entryPath);
        }
        else
        {
          total += getFileSize(entryPath);
        }
      }
    }

    return total;
    #else
    throw 'Directory size calculation not supported on this platform.';
    #end
  }

  static var tempDir:Null<String> = null;
  static final TEMP_ENV_VARS:Array<String> = ['TEMP', 'TMPDIR', 'TEMPDIR', 'TMP'];

  /**
   * Get the path to a temporary directory we can use for writing files.
   * Only works on native.
   *
   * @return The path to the temporary directory.
   */
  public static function getTempDir():Null<String>
  {
    if (tempDir != null) return tempDir;
    #if sys
    #if windows
    var path:Null<String> = null;
    for (envName in TEMP_ENV_VARS)
    {
      path = Sys.getEnv(envName);
      if (path == '') path = null;
      if (path != null) break;
    }
    tempDir = Path.join([path ?? '', 'funkin/']);
    return tempDir;
    #elseif android
    tempDir = Path.addTrailingSlash(extension.androidtools.content.Context.getCacheDir());
    return tempDir;
    #else
    tempDir = '/tmp/funkin/';
    return tempDir;
    #end
    #else
    return null;
    #end
  }

  /**
   * Rename a file or directory.
   * Only works on native.
   *
   * @param path The path to the file or directory.
   * @param newName The new name of the file or directory.
   * @param keepExtension Whether to keep the extension the same, if applicable.
   */
  public static function rename(path:String, newName:String, keepExtension:Bool = true):Void
  {
    #if sys
    if (!pathExists(path))
    {
      throw 'Path does not exist: "$path"';
    }

    final isDirectory:Bool = directoryExists(path);
    newName = Path.withoutDirectory(newName);
    if (isDirectory)
    {
      newName = Path.withoutExtension(newName);
    }
    else if (keepExtension)
    {
      newName = Path.withExtension(newName, Path.extension(path));
    }

    newName = Path.join([Path.directory(path), newName]);
    if (newName == path)
    {
      return;
    }

    if (pathExists(newName))
    {
      // Prevent overwriting something.
      throw 'Destination path already exists: "$newName"';
    }

    sys.FileSystem.rename(path, newName);
    #else
    throw 'File renaming by path is not supported on this platform.';
    #end
  }

  /**
   * Create a Bytes object containing a ZIP file, containing the provided entries.
   *
   * @param entries The entries to add to the ZIP file.
   * @return The ZIP file as a Bytes object.
   */
  public static function createZIPFromEntries(entries:Array<Entry>):Bytes
  {
    var o:haxe.io.BytesOutput = new haxe.io.BytesOutput();
    var zipWriter:haxe.zip.Writer = new haxe.zip.Writer(o);
    zipWriter.write(Lambda.list(entries));
    return o.getBytes();
  }

  public static function readZIPFromBytes(input:Bytes):Array<Entry>
  {
    var bytesInput = new haxe.io.BytesInput(input);
    var zippedEntries = haxe.zip.Reader.readZip(bytesInput);
    var results:Array<Entry> = new Array<Entry>();
    for (entry in zippedEntries)
    {
      if (entry.compressed)
      {
        entry.data = haxe.zip.Reader.unzip(entry);
      }

      results.push(entry);
    }

    return results;
  }

  public static function mapZIPEntriesByName(input:Array<Entry>):Map<String, Entry>
  {
    var results:Map<String, Entry> = new Map<String, Entry>();
    for (entry in input)
    {
      results.set(entry.fileName, entry);
    }

    return results;
  }

  /**
   * Create a ZIP file entry from a file name and its string contents.
   *
   * @param name The name of the file. You can use slashes to create subdirectories.
   * @param content The string contents of the file.
   * @return The resulting entry.
   */
  public static function makeZIPEntry(name:String, content:String):Entry
  {
    var data:Bytes = haxe.io.Bytes.ofString(content, UTF8);
    return makeZIPEntryFromBytes(name, data);
  }

  /**
   * Create a ZIP file entry from a file name and its string contents.
   *
   * @param name The name of the file. You can use slashes to create subdirectories.
   * @param data The byte data of the file.
   * @return The resulting entry.
   */
  public static function makeZIPEntryFromBytes(name:String, data:haxe.io.Bytes):Entry
  {
    return {
      fileName: name,
      fileSize: data.length,
      data: data,
      dataSize: data.length,
      compressed: false,
      fileTime: Date.now(),
      crc32: null,
      extraFields: null,
    };
  }

  /**
   * Runs platform-specific code to open a path in the file explorer.
   *
   * @param pathFolder The path of the folder to open.
   * @param createIfNotExists If `true`, creates the folder if missing; otherwise, throws an error.
   */
  public static function openFolder(pathFolder:String, createIfNotExists:Bool = true):Void
  {
    #if sys
    pathFolder = pathFolder.trim();
    if (createIfNotExists)
    {
      createDirIfNotExists(pathFolder);
    }
    else if (!directoryExists(pathFolder))
    {
      throw 'Path is not a directory: "$pathFolder"';
    }

    #if windows
    Sys.command('explorer', [pathFolder.replace('/', '\\')]);
    #elseif mac
    // mac could be fuckie with where the log folder is relative to the game file...
    // if this comment is still here... it means it has NOT been verified on mac yet!
    //
    // FileUtilBase.hx note: this was originally used to open the logs specifically!
    // thats why the above comment is there!
    Sys.command('open', [pathFolder]);
    #elseif linux
    var exitCode = Sys.command('xdg-open', [pathFolder]);
    if (exitCode == 0) return;
    var fileManagers:Array<String> = [
      'dolphin',
      'nautilus',
      'nemo',
      'thunar',
      'caja',
      'konqueror',
      'spacefm',
      'pcmanfm'
    ];

    for (fm in fileManagers)
    {
      if (Sys.command('which', [fm]) == 0)
      {
        exitCode = Sys.command(fm, [pathFolder]);
        if (exitCode == 0) return;
      }
    }

    trace('No compatible file manager found for Linux.');
    #end
    #else
    throw 'External folder open is not supported on this platform.';
    #end
  }

  /**
   * Runs platform-specific code to open a file explorer and select a specific file.
   *
   * @param path The path of the file to select.
   */
  public static function openSelectFile(path:String):Void
  {
    #if sys
    path = path.trim();
    if (!pathExists(path))
    {
      throw 'Path does not exist: "$path"';
    }

    #if windows
    Sys.command('explorer', ['/select,', path.replace('/', '\\')]);
    #elseif mac
    Sys.command('open', ['-R', path]);
    #elseif linux
    trace('File selection not reliably supported on Linux, opening parent folder instead.');
    path = Path.directory(path);
    openFolder(path);
    #end
    #else
    throw 'External file selection is not supported on this platform.';
    #end
  }
}

/**
 * The file dialogs as V-Slice's version of lime has them (static functions with a callback), made with lime's own FileDialog, which
 * the engine is built with. And the bytes of a file, read and written, like its lime's Bytes.
 */
class LimeDialogs
{
  public static function openDirectory(window:Dynamic, title:String, callback:Array<String>->Void, ?defaultPath:String, multiple:Bool = false):Void
  {
    #if desktop
    var dialog = new lime.ui.FileDialog();
    dialog.onSelect.add(function(path:String) callback([path]));
    dialog.onCancel.add(function() callback([]));
    if (!dialog.browse(OPEN_DIRECTORY, null, defaultPath, title)) callback([]);
    #else
    callback([]);
    #end
  }

  public static function openFile(window:Dynamic, title:String, callback:(Array<String>, Dynamic) -> Void, ?filter:String, ?defaultPath:String,
      multiple:Bool = false):Void
  {
    #if desktop
    var dialog = new lime.ui.FileDialog();
    dialog.onSelect.add(function(path:String) callback([path], null));
    dialog.onSelectMultiple.add(function(paths:Array<String>) callback(paths, null));
    dialog.onCancel.add(function() callback([], null));
    if (!dialog.browse(multiple ? OPEN_MULTIPLE : OPEN, filter, defaultPath, title)) callback([], null);
    #else
    callback([], null);
    #end
  }

  public static function saveFile(window:Dynamic, title:String, callback:(String, Dynamic) -> Void, ?filter:String, ?defaultPath:String):Void
  {
    #if desktop
    var dialog = new lime.ui.FileDialog();
    dialog.onSelect.add(function(path:String) callback(path, null));
    dialog.onCancel.add(function() callback(null, null));
    if (!dialog.browse(SAVE, filter, defaultPath, title)) callback(null, null);
    #else
    callback(null, null);
    #end
  }

  // The kinds of files of a dialog, the way lime takes them: "json,txt"
  public static function filterOf(?filters:Array<FileFilter>):String
  {
    if (filters == null || filters.length < 1) return null;
    var extensions:Array<String> = [];
    for (filter in filters)
      if (filter != null && filter.extension != null)
        for (part in filter.extension.split(';'))
        {
          var extension:String = StringTools.trim(part).replace('*.', '').replace('*', '');
          if (extension.length > 0 && !extensions.contains(extension)) extensions.push(extension);
        }
    return (extensions.length > 0) ? extensions.join(',') : null;
  }

  public static function toFile(path:String, data:haxe.io.Bytes):Void
  {
    #if sys
    sys.io.File.saveBytes(path, data);
    #end
  }

  public static function fromFile(path:String):haxe.io.Bytes
  {
    #if sys
    return sys.io.File.getBytes(path);
    #else
    return null;
    #end
  }
}
