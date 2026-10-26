package backend;

import openfl.media.Sound;

#if sys
import sys.FileSystem;
import sys.thread.Deque;
import sys.thread.Mutex;
import sys.thread.Thread;
#end

/**
 * Loads sound files without stopping the game while their files are read.
 *
 * The file is read by another thread, and whoever asked for the sound is called with it when it's ready. Turning it into raw audio
 * is done by the game's own thread: lime's code that does it can't run on two threads at once (it can freeze the whole game,
 * see `LoadingState.readFiles`), and the game's thread uses it all the time.
 *
 * That takes a good fraction of a second for a whole song, so what's only heard for a moment (the previews of the Freeplay menu)
 * can be loaded with `stream` instead: the sound is played straight from its file, turned into audio a bit at a time while it plays,
 * and it's ready on the next frame whatever its size.
 *
 * It's for sounds that are asked for in the middle of a menu (the songs of the Freeplay menus), not for what a state loads before showing up.
 * What's loaded goes to the same place the sounds loaded by `Paths` are kept in, so asking for it again there is instant
 * (not the streamed ones: a song played from that place has to be all there).
 */
class SoundLoader
{
	/**
	 * If these bytes are a sound lime can decode: an empty or broken audio file crashes the game inside lime itself, where nothing
	 * can catch it (a mod with a "Voices.ogg" of 0 bytes, Vs Tails.exe's Chasing). OGG (Vorbis), WAV, MP3 and FLAC are let through.
	 */
	public static function validBytes(bytes:haxe.io.Bytes):Bool
	{
		if(bytes == null || bytes.length < 64) return false;

		var head:String = bytes.getString(0, 4);
		if(head == 'OggS')
		{
			// (an OGG of something else than Vorbis, like Opus, isn't one lime can decode either)
			var start:String = bytes.getString(0, Std.int(Math.min(bytes.length, 128)));
			return start.indexOf('vorbis') > -1;
		}
		if(head == 'RIFF' || head == 'fLaC' || head.substr(0, 3) == 'ID3') return true;
		return bytes.get(0) == 0xFF && (bytes.get(1) & 0xE0) == 0xE0; //an MP3 frame
	}

	/**
	 * The same, reading the start of a file (see `validBytes()`). A file that isn't there isn't one either.
	 */
	public static function validFile(file:String):Bool
	{
		try
		{
			if(file == null || !FileSystem.exists(file) || FileSystem.isDirectory(file)) return false;
			var input = sys.io.File.read(file, true);
			var bytes:haxe.io.Bytes = haxe.io.Bytes.alloc(128);
			var read:Int = 0;
			try
			{
				read = input.readBytes(bytes, 0, 128);
			}
			catch(e:Dynamic) {}
			input.close();
			if(read < 64) return false;
			return validBytes(bytes.sub(0, read));
		}
		catch(e:Dynamic)
		{
			return false;
		}
	}

	static function warnInvalid(file:String):Void
		trace('The sound "$file" is empty or is not one that can be played: it was left out');

	#if sys
	static var jobs:Deque<{id:Int, file:String}> = null;
	static var results:Deque<{id:Int, file:String, bytes:haxe.io.Bytes}> = null;
	static var lock:Mutex = null;
	static var worker:Thread = null;

	// read by the loading thread too, always with the lock
	static var cancelled:Map<Int, Bool> = [];

	// the ones loaded with `stream`, opened by the game's thread on the next frame (if still wanted by then)
	static var streams:Array<{id:Int, file:String}> = [];
	#end

	static var callbacks:Map<Int, Sound->Void> = [];
	static var lastId:Int = 0;
	static var hooked:Bool = false;

	/**
	 * The file a sound would be loaded from, the same way `Paths.returnSound()` finds it. It may not exist.
	 * The current mod has to be the one the sound is looked for in when this is called, it doesn't matter after that.
	 */
	public static function getFile(key:String, ?path:String, modsAllowed:Bool = true):String
	{
		return Paths.getPath(Language.getFileTranslation(key) + '.${Paths.SOUND_EXT}', SOUND, path, modsAllowed);
	}

	/**
	 * If the sound of a file can be had right away: it was already loaded, or there's no such file (and so nothing to wait for).
	 */
	public static function isReady(file:String):Bool
	{
		if(file == null || Paths.currentTrackedSounds.exists(file)) return true;
		#if sys
		return !FileSystem.exists(file);
		#else
		return true;
		#end
	}

	/**
	 * Loads the sound of a file (see `getFile()`) and calls a function with it, with null if the file doesn't exist or couldn't be read.
	 * The function is called from the game's own thread: right away if the sound was already loaded, on a later frame otherwise.
	 *
	 * @return A number to give to `cancel()` if the sound isn't wanted anymore, 0 if the function was already called.
	 */
	public static function load(file:String, callback:Sound->Void, stream:Bool = false):Int
	{
		if(file == null)
		{
			callback(null);
			return 0;
		}

		if(Paths.currentTrackedSounds.exists(file))
		{
			Paths.localTrackedAssets.push(file);
			callback(Paths.currentTrackedSounds.get(file));
			return 0;
		}

		#if sys
		if(!FileSystem.exists(file))
		{
			callback(null);
			return 0;
		}

		start();

		var id:Int = ++lastId;
		callbacks.set(id, callback);
		if(stream) streams.push({id: id, file: file});
		else jobs.add({id: id, file: file});
		return id;
		#else
		var sound:Sound = openfl.utils.Assets.exists(file, SOUND) ? openfl.utils.Assets.getSound(file) : null;
		if(sound != null)
		{
			Paths.currentTrackedSounds.set(file, sound);
			Paths.localTrackedAssets.push(file);
		}
		callback(sound);
		return 0;
		#end
	}

	/**
	 * Loads several files and calls a function when all of them are done, with their sounds in the same order (null for the ones that failed
	 * and for the files that were given as null).
	 *
	 * @return The numbers of the sounds that are being waited for, to give to `cancelAll()`.
	 */
	public static function loadAll(files:Array<String>, callback:Array<Sound>->Void):Array<Int>
	{
		var sounds:Array<Sound> = [for (file in files) null];
		var ids:Array<Int> = [];
		var missing:Int = files.length;
		var started:Bool = false;

		function done():Void
		{
			missing--;
			if(missing < 1 && started) callback(sounds);
		}

		for (num => file in files)
		{
			var id:Int = load(file, function(sound:Sound)
			{
				sounds[num] = sound;
				done();
			});
			if(id != 0) ids.push(id);
		}

		// the ones that were ready called back before the loop was over
		started = true;
		if(missing < 1) callback(sounds);
		return ids;
	}

	/**
	 * Gives up on a sound that was asked for: its function isn't called, and if it wasn't being read yet it isn't even loaded.
	 */
	public static function cancel(id:Int):Void
	{
		if(id == 0 || !callbacks.exists(id)) return;

		callbacks.remove(id);
		#if sys
		lock.acquire();
		cancelled.set(id, true);
		lock.release();
		#end
	}

	public static function cancelAll(ids:Array<Int>):Void
	{
		if(ids == null) return;
		for (id in ids)
			cancel(id);
	}

	#if sys
	static function start():Void
	{
		if(worker == null)
		{
			jobs = new Deque();
			results = new Deque();
			lock = new Mutex();
			worker = Thread.create(work);
		}

		if(!hooked)
		{
			hooked = true;
			FlxG.signals.preUpdate.add(deliver);
		}
	}

	// The loading thread: one file at a time, in the order they were asked for
	static function work():Void
	{
		while(true)
		{
			var job = jobs.pop(true);
			if(job == null) continue;

			lock.acquire();
			var unwanted:Bool = cancelled.exists(job.id);
			if(unwanted) cancelled.remove(job.id);
			lock.release();
			if(unwanted) continue;

			var bytes:haxe.io.Bytes = null;
			try
			{
				bytes = sys.io.File.getBytes(job.file);
			}
			catch(e:Dynamic)
			{
				trace('Could not read the sound "${job.file}": $e');
			}
			results.add({id: job.id, file: job.file, bytes: bytes});
		}
	}

	// On the game's thread: hands the sounds that got ready to who asked for them
	static function deliver():Void
	{
		// the streamed ones: only the ones still wanted (a menu scrolled through quickly gives up on most of them)
		var opening:Array<{id:Int, file:String}> = streams;
		streams = [];
		for (job in opening)
		{
			var callback:Sound->Void = callbacks.get(job.id);
			if(callback == null) continue;
			callbacks.remove(job.id);
			callback(openStream(job.file));
		}

		while(true)
		{
			var result = results.pop(false);
			if(result == null) break;

			var callback:Sound->Void = callbacks.get(result.id);
			if(callback == null)
			{
				// given up on while it was being read: it isn't kept, and there's nothing left to tell the loading thread about it
				lock.acquire();
				cancelled.remove(result.id);
				lock.release();
				continue;
			}
			callbacks.remove(result.id);

			var sound:Sound = null;
			if(Paths.currentTrackedSounds.exists(result.file)) sound = Paths.currentTrackedSounds.get(result.file);
			else if(result.bytes != null && !validBytes(result.bytes)) warnInvalid(result.file);
			else if(result.bytes != null)
			{
				try
				{
					var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromBytes(result.bytes);
					if(buffer != null) sound = Sound.fromAudioBuffer(buffer);
				}
				catch(e:Dynamic)
				{
					trace('Could not load the sound "${result.file}": $e');
				}
			}

			if(sound != null)
			{
				if(!Paths.currentTrackedSounds.exists(result.file)) Paths.currentTrackedSounds.set(result.file, sound);
				Paths.localTrackedAssets.push(result.file);
				callback(Paths.currentTrackedSounds.get(result.file));
			}
			else callback(null);
		}
	}

	// A sound played straight from its file (only OGG files can be, the others are loaded whole). On the game's thread, like all of lime's
	static function openStream(file:String):Sound
	{
		if(!validFile(file))
		{
			warnInvalid(file);
			return null;
		}
		try
		{
			#if lime_vorbis
			if(file.toLowerCase().endsWith('.ogg'))
			{
				var buffer:lime.media.AudioBuffer = lime.media.AudioBuffer.fromVorbisFile(lime.media.vorbis.VorbisFile.fromFile(file));
				if(buffer != null) return Sound.fromAudioBuffer(buffer);
			}
			#end
			return Sound.fromFile(file);
		}
		catch(e:Dynamic)
		{
			trace('Could not open the sound "$file": $e');
		}
		return null;
	}
	#end
}
