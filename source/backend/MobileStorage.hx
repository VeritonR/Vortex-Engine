package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Where the game keeps its files on phones. On a computer it reads the folder it's in (the mods, the base game's files, the saves of
 * the editors...); on a phone the files that come with the game are inside the APK, where those can't be read as files, so they're
 * copied to a folder of the phone the first time the game is opened (and after it's updated), and the game works from there:
 *
 *     Android/media/(the game's package)/      (assets, mods, modsList.txt...)
 *
 * A folder of the game's own: it needs no permission, and any file manager can open it to put mods in.
 */
class MobileStorage
{
	/**
	 * The game's folder on the phone, null on computers.
	 */
	public static var folder(default, null):String = null;

	// (written in the folder once the files of a version of the game were copied)
	static inline final COPIED_MARK:String = '.copied';

	/**
	 * Goes to the game's folder on the phone (the first thing the game does).
	 * Nothing on computers.
	 */
	public static function setup():Void
	{
		#if android
		folder = usable(mediaFolder());
		if(folder == null) folder = usable(appFolder());
		if(folder == null) folder = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);
		Sys.setCwd(folder);
		// (where the mods go, there from the start)
		try if(!FileSystem.exists('mods')) FileSystem.createDirectory('mods') catch(e:Dynamic) {}
		hideFromGallery();
		#elseif ios
		folder = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory);
		Sys.setCwd(folder);
		#end
	}

	#if android
	static function appFolder():String
		return haxe.io.Path.addTrailingSlash(extension.androidtools.content.Context.getExternalFilesDir());

	// Android/data/(package)/files/ -> Android/media/(package)/
	static function mediaFolder():String
	{
		var app:String = appFolder();
		var data:Int = app.indexOf('/Android/data/');
		if(data < 0) return null;
		var rest:String = app.substr(data + '/Android/data/'.length);
		return app.substr(0, data) + '/Android/media/' + rest.substr(0, rest.indexOf('/')) + '/';
	}

	// The folder, made if it isn't there, if it can be written to (null otherwise)
	static function usable(candidate:String):String
	{
		if(candidate == null) return null;
		try
		{
			if(!FileSystem.exists(candidate)) FileSystem.createDirectory(candidate);
			File.saveContent(candidate + '.write_test', 'ok');
			FileSystem.deleteFile(candidate + '.write_test');
			return candidate;
		}
		catch(e:Dynamic) {}
		return null;
	}

	#end

	/**
	 * The path to give lime's own loaders (images, sounds, fonts) for a file of the game's folder: on Android they look for a
	 * relative path inside the APK, not in the folder the game works from (only the files that are in both were found, the mods'
	 * never), so it's made a full path there. The path itself on computers.
	 */
	public static function forLime(path:String):String
	{
		#if mobile
		if(path != null && path.length > 0 && path.charAt(0) != '/' && folder != null) return folder + path;
		#end
		return path;
	}

	/**
	 * The path of a file as it's written on the phone's storage, which tells capital letters apart (unlike Windows, where mods and the
	 * game's own files are made): "images/menu.png" finds "images/Menu.PNG". The path itself when it's there as it is, or on computers.
	 */
	public static function realPath(path:String):String
	{
		#if mobile
		FrameProfile.count('file checks');
		if(path == null || path.length == 0 || FileSystem.exists(path)) return path;
		FrameProfile.countFrom('missing files');

		var parts:Array<String> = path.split('/');
		var found:String = (path.charAt(0) == '/') ? '/' : '';
		for (i => part in parts)
		{
			if(part.length == 0) continue;
			var next:String = found + part;
			if(!FileSystem.exists(next))
			{
				var named:String = nameIn(found, part);
				if(named == null) return path;
				next = found + named;
			}
			found = (i < parts.length - 1) ? next + '/' : next;
		}
		return found;
		#else
		return path;
		#end
	}

	#if mobile
	// The names in the folders already looked into, by their name in small letters
	static var folderNames:Map<String, Map<String, String>> = [];

	static function nameIn(folder:String, name:String):String
	{
		var names:Map<String, String> = folderNames.get(folder);
		if(names == null)
		{
			names = [];
			try
			{
				var path:String = (folder.length > 0) ? folder : '.';
				if(FileSystem.exists(path) && FileSystem.isDirectory(path))
					for (entry in FileSystem.readDirectory(path)) names.set(entry.toLowerCase(), entry);
			}
			catch(e:Dynamic) {}
			folderNames.set(folder, names);
		}
		return names.get(name.toLowerCase());
	}
	#end

	/**
	 * If the files that come with the game still have to be copied to the phone's folder.
	 */
	public static function needsCopy():Bool
	{
		#if mobile
		if(folder == null) return false;
		try
		{
			// (the files gone, deleted by someone, are copied again too)
			return !FileSystem.exists(COPIED_MARK) || !FileSystem.exists('assets/shared') || File.getContent(COPIED_MARK) != version();
		}
		catch(e:Dynamic) {}
		return true;
		#else
		return false;
		#end
	}

	static function version():String
	{
		var app = lime.app.Application.current;
		return (app != null && app.meta.get('version') != null) ? app.meta.get('version') + '|' + listToCopy().length : 'unknown';
	}

	static var toCopy:Array<String> = null;

	// The files of the APK the game reads as files: all of them but the ones built into the game itself, only read through the asset
	// library (the engine's fonts, the editors' small images, flixel's own): there's no file of those to copy
	@:access(lime.utils.AssetLibrary)
	static function listToCopy():Array<String>
	{
		if(toCopy == null)
		{
			var library:lime.utils.AssetLibrary = lime.utils.Assets.getLibrary('default');
			toCopy = [for (id in lime.utils.Assets.list())
				if(!StringTools.startsWith(id, '__') && (library == null || !library.classTypes.exists(id))) id];
		}
		return toCopy;
	}

	/**
	 * Copies one of the files, if it isn't there already with the same size. Returns false if it couldn't be done.
	 */
	public static function copyOne(id:String):Bool
	{
		#if mobile
		try
		{
			var bytes:haxe.io.Bytes = lime.utils.Assets.getBytes(id);
			// (an empty file comes as nothing: modsList.txt, the "put the files here" ones)
			if(bytes == null && lime.utils.Assets.exists(id)) bytes = haxe.io.Bytes.alloc(0);
			if(bytes == null) return false;
			if(FileSystem.exists(id) && FileSystem.stat(id).size == bytes.length) return true;

			var directory:String = haxe.io.Path.directory(id);
			if(directory.length > 0 && !FileSystem.exists(directory)) FileSystem.createDirectory(directory);
			File.saveBytes(id, bytes);
			return true;
		}
		catch(e:Dynamic)
		{
			trace('Could not copy "$id": $e');
		}
		#end
		return false;
	}

	public static function markCopied():Void
	{
		#if mobile
		try File.saveContent(COPIED_MARK, version()) catch(e:Dynamic) {}
		hideFromGallery();
		#end
	}

	/**
	 * Keeps the game's pictures (the sprites of the game and the mods, hundreds of them) out of the phone's gallery: a ".nomedia"
	 * file in a folder tells Android not to show what's in it. The game's folder itself isn't hidden, only the ones with those.
	 */
	public static function hideFromGallery():Void
	{
		#if mobile
		for (name in ['assets', 'mods', 'flixel'])
			try if(FileSystem.exists(name) && !FileSystem.exists('$name/.nomedia')) File.saveContent('$name/.nomedia', '') catch(e:Dynamic) {}
		#end
	}

	/**
	 * The list of files `CopyState` goes through.
	 */
	public static function files():Array<String> return listToCopy().copy();
}

/**
 * The screen of the first time the game is opened on a phone: the game's files are copied to its folder (see MobileStorage),
 * a few at a time so the screen keeps moving, then the game starts.
 */
class CopyState extends flixel.FlxState
{
	var next:Class<flixel.FlxState>;
	var queue:Array<String>;
	var total:Int = 0;
	var failed:Int = 0;
	var text:flixel.text.FlxText;
	var bar:FlxSprite;

	public function new(?next:Class<flixel.FlxState>)
	{
		super();
		this.next = (next != null) ? next : states.TitleState;
	}

	override function create():Void
	{
		queue = MobileStorage.files();
		total = queue.length;

		text = new flixel.text.FlxText(0, FlxG.height / 2 - 60, FlxG.width, 'Preparing the game files...', 32);
		text.alignment = CENTER;
		add(text);

		var back:FlxSprite = new FlxSprite(140, FlxG.height / 2 + 10).makeGraphic(FlxG.width - 280, 24, 0xFF333333);
		add(back);
		bar = new FlxSprite(back.x, back.y).makeGraphic(1, 24, 0xFFFFFFFF);
		bar.origin.set(0, 0);
		add(bar);
		super.create();
	}

	override function update(elapsed:Float):Void
	{
		// (as many as fit in a part of a frame: the bar moves, and the phone doesn't think the game froze)
		var start:Float = haxe.Timer.stamp();
		while(queue.length > 0 && haxe.Timer.stamp() - start < 0.03)
			if(!MobileStorage.copyOne(queue.shift())) failed++;

		var done:Int = total - queue.length;
		bar.scale.x = (total > 0) ? (FlxG.width - 280) * done / total : 0;
		text.text = 'Preparing the game files...\n$done / $total';

		if(queue.length == 0)
		{
			if(failed > 0) trace('$failed of the files were not copied');
			MobileStorage.markCopied();
			FlxG.switchState(Type.createInstance(next, []));
		}
		super.update(elapsed);
	}
}
