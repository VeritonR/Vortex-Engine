package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import sys.thread.Thread;
#end

/**
 * Online: the host sends a mod the other player doesn't have, after they accept it.
 *
 *  1. The host, before opening a song of a mod: "HAS_SONG|song|folder". The other one answers "HAS_SONG_OK" or "HAS_SONG_MISSING|folder|disabled"
 *  2. Missing: the host measures the mod's folder and offers it: "MOD_OFFER|folder|bytes|files"
 *  3. The other player sees what it is and how big, with a warning (mods can have scripts), and answers "MOD_ACCEPT" or "MOD_DECLINE"
 *  4. Accepted: each file goes as "MOD_FILE|path|size", its bytes in blocks ("MOD_BIN|length" and the raw bytes right after the line),
 *     "MOD_FILE_END", and once they're all there "MOD_DONE|folder"
 *  5. The other player puts it in "mods" (it's written in "mods_incoming" first, and only moved there once it's whole), turns it on,
 *     and answers "MOD_INSTALLED|folder": then the host opens the song like always
 *
 * The files are only written inside the mod's own folder: a path with ".." or that starts at a drive is refused.
 */
class ModTransfer
{
	public static inline var INCOMING:String = 'mods_incoming/';
	static inline var BLOCK:Int = 64 * 1024; //(small: the game's own messages wait for a block to go)

	// The one receiving
	public static var receiving(default, null):Bool = false;
	public static var receivedBytes(default, null):Float = 0;
	public static var expectedBytes(default, null):Float = 0;
	public static var receivingFolder(default, null):String = null;
	public static var receiveFailed(default, null):Bool = false;
	#if sys
	static var output:FileOutput = null;
	#end

	// The one sending
	public static var sending(default, null):Bool = false;
	public static var sentBytes(default, null):Float = 0;
	public static var totalBytes(default, null):Float = 0;

	/**
	 * A folder name that's only a folder of "mods" (not a path to somewhere else).
	 */
	public static function validFolder(folder:String):Bool
	{
		if(folder == null || folder.length < 1 || folder.length > 120) return false;
		if(folder.indexOf('/') > -1 || folder.indexOf('\\') > -1 || folder.indexOf(':') > -1 || folder.indexOf('|') > -1) return false;
		return folder != '.' && folder != '..' && !folder.startsWith('.');
	}

	/**
	 * A path inside a mod's folder, with "/": null if it would go out of it.
	 */
	public static function safePath(path:String):String
	{
		if(path == null || path.length < 1 || path.length > 400) return null;
		path = path.replace('\\', '/');
		if(path.startsWith('/') || path.indexOf(':') > -1 || path.indexOf('|') > -1) return null;
		for (part in path.split('/'))
			if(part == '..' || part == '.' || part.length < 1) return null;
		return path;
	}

	#if sys
	/**
	 * The files of a mod's folder (paths inside it, with "/") and how big it is in all.
	 */
	public static function measure(folder:String):{files:Array<String>, bytes:Float}
	{
		var root:String = Paths.mods(folder);
		var files:Array<String> = [];
		var bytes:Float = 0.0;
		function walk(relative:String)
		{
			var dir:String = (relative.length > 0) ? root + '/' + relative : root;
			for (name in FileSystem.readDirectory(dir))
			{
				var rel:String = (relative.length > 0) ? relative + '/' + name : name;
				var full:String = root + '/' + rel;
				if(FileSystem.isDirectory(full)) walk(rel);
				else
				{
					files.push(rel);
					var size:Float = FileSystem.stat(full).size;
					bytes += (size < 0) ? size + 4294967296 : size;
				}
			}
		}
		if(FileSystem.exists(root) && FileSystem.isDirectory(root)) walk('');
		return {files: files, bytes: bytes};
	}

	// ------------------------------------------------------------------------------------------
	// Sending (the host)
	// ------------------------------------------------------------------------------------------

	/**
	 * Measures the mod on a thread of its own and offers it to the other player.
	 */
	public static function offer(folder:String):Void
	{
		Thread.create(function() {
			var info = measure(folder);
			NetworkManager.send('MOD_OFFER|$folder|${Std.int(info.bytes)}|${info.files.length}');
		});
	}

	/**
	 * Sends every file of the mod, on a thread of its own.
	 */
	public static function sendMod(folder:String):Void
	{
		if(sending || !validFolder(folder)) return;
		sending = true;
		sentBytes = 0;
		Thread.create(function() {
			try
			{
				var info = measure(folder);
				totalBytes = info.bytes;
				var root:String = Paths.mods(folder) + '/';
				for (file in info.files)
				{
					if(!NetworkManager.connected) break;
					var size:Float = FileSystem.stat(root + file).size;
					NetworkManager.send('MOD_FILE|$file|${Std.int(size)}');
					var input = File.read(root + file, true);
					var buffer:haxe.io.Bytes = haxe.io.Bytes.alloc(BLOCK);
					while(true)
					{
						var read:Int = 0;
						try read = input.readBytes(buffer, 0, BLOCK) catch(e:haxe.io.Eof) read = 0;
						if(read <= 0) break;
						NetworkManager.sendBinary(buffer, read);
						sentBytes += read;
					}
					input.close();
					NetworkManager.send('MOD_FILE_END');
				}
				if(NetworkManager.connected) NetworkManager.send('MOD_DONE|$folder');
			}
			catch(e:Dynamic)
			{
				trace('Could not send the mod "$folder": $e');
				NetworkManager.send('MOD_FAILED|$folder');
			}
			sending = false;
		});
	}

	// ------------------------------------------------------------------------------------------
	// Receiving (on the network's thread, see NetworkManager)
	// ------------------------------------------------------------------------------------------

	/**
	 * The other player accepted it: what's coming, to write it in "mods_incoming".
	 */
	public static function startReceiving(folder:String, bytes:Float):Bool
	{
		if(!validFolder(folder) || FileSystem.exists(Paths.mods(folder))) return false;
		var temp:String = INCOMING + folder;
		try
		{
			if(FileSystem.exists(temp)) deleteFolder(temp);
			FileSystem.createDirectory(temp);
		}
		catch(e:Dynamic)
		{
			return false;
		}
		receivingFolder = folder;
		expectedBytes = bytes;
		receivedBytes = 0;
		receiveFailed = false;
		receiving = true;
		return true;
	}

	public static function beginFile(path:String):Void
	{
		closeFile();
		if(!receiving) return;
		var safe:String = safePath(path);
		if(safe == null)
		{
			receiveFailed = true;
			return;
		}
		try
		{
			var full:String = INCOMING + receivingFolder + '/' + safe;
			var dir:String = full.substr(0, full.lastIndexOf('/'));
			if(!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			output = File.write(full, true);
		}
		catch(e:Dynamic)
		{
			receiveFailed = true;
		}
	}

	public static function writeBlock(bytes:haxe.io.Bytes, length:Int):Void
	{
		receivedBytes += length;
		if(output == null) return;
		try output.writeBytes(bytes, 0, length) catch(e:Dynamic) receiveFailed = true;
	}

	public static function closeFile():Void
	{
		if(output == null) return;
		try output.close() catch(e:Dynamic) {}
		output = null;
	}

	/**
	 * All of it came: the mod goes to "mods", turned on. False if something went wrong (then nothing of it is kept).
	 */
	public static function finishReceiving():Bool
	{
		closeFile();
		receiving = false;
		var folder:String = receivingFolder;
		var temp:String = INCOMING + folder;
		if(receiveFailed || folder == null || FileSystem.exists(Paths.mods(folder)))
		{
			try deleteFolder(temp) catch(e:Dynamic) {}
			return false;
		}
		try
		{
			FileSystem.rename(temp, Paths.mods(folder));
			try if(FileSystem.readDirectory(INCOMING).length < 1) FileSystem.deleteDirectory(INCOMING) catch(e:Dynamic) {}
			enable(folder);
		}
		catch(e:Dynamic)
		{
			trace('Could not put the mod "$folder" in the mods folder: $e');
			return false;
		}
		return true;
	}

	public static function cancelReceiving():Void
	{
		closeFile();
		receiving = false;
		if(receivingFolder != null) try deleteFolder(INCOMING + receivingFolder) catch(e:Dynamic) {}
		try if(FileSystem.exists(INCOMING) && FileSystem.readDirectory(INCOMING).length < 1) FileSystem.deleteDirectory(INCOMING) catch(e:Dynamic) {}
	}

	/**
	 * Turns a mod of the mods folder on (at the top of the list, like a new one) and reads the mods again.
	 */
	public static function enable(folder:String):Void
	{
		var lines:Array<String> = FileSystem.exists('modsList.txt') ? File.getContent('modsList.txt').replace('\r', '').split('\n') : [];
		var kept:Array<String> = [for (line in lines) if(line.trim().length > 0 && line.split('|')[0] != folder) line];
		kept.unshift('$folder|1');
		File.saveContent('modsList.txt', kept.join('\n'));
		Mods.parseList();
		Mods.loadTopMod();
		WeekData.reloadWeekFiles(false);
	}

	/**
	 * If a mod is in the mods folder but turned off.
	 */
	public static function isDisabled(folder:String):Bool
	{
		return validFolder(folder) && FileSystem.exists(Paths.mods(folder)) && Mods.parseList().disabled.contains(folder);
	}

	static function deleteFolder(path:String):Void
	{
		for (name in FileSystem.readDirectory(path))
		{
			var full:String = path + '/' + name;
			if(FileSystem.isDirectory(full)) deleteFolder(full);
			else FileSystem.deleteFile(full);
		}
		FileSystem.deleteDirectory(path);
	}
	#end
}
