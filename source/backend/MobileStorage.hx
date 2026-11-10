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
 *     Vortex Engine/      (on the phone's storage, next to Download, DCIM...: assets, mods, modsList.txt...)
 *
 * That one needs the permission to use the phone's files ("All files access" from Android 11 on), which the game asks for the first
 * time (see StorageAccessState). Without it the game uses a folder of its own that needs none, which any file manager can still open:
 *
 *     Android/media/(the game's package)/
 */
class MobileStorage
{
	/**
	 * The game's folder on the phone, null on computers.
	 */
	public static var folder(default, null):String = null;

	/**
	 * The name of the game's folder on the phone's storage.
	 */
	public static inline final FOLDER_NAME:String = 'Vortex Engine';

	// (written in the folder once the files of a version of the game were copied)
	static inline final COPIED_MARK:String = '.copied';
	// (written in the app's own folder when the permission was refused: it isn't asked for every time)
	static inline final REFUSED_MARK:String = '.no_storage_access';

	/**
	 * Goes to the game's folder on the phone (the first thing the game does, and again once the permission is given).
	 * Nothing on computers.
	 */
	public static function setup():Void
	{
		#if android
		folder = null;
		if(hasFileAccess()) folder = usable(publicFolder());
		if(folder == null) folder = usable(mediaFolder());
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
	/**
	 * "(storage)/Vortex Engine/": the folder the game uses when it can.
	 */
	public static function publicFolder():String
		return haxe.io.Path.addTrailingSlash(extension.androidtools.os.Environment.getExternalStorageDirectory()) + FOLDER_NAME + '/';

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

	/**
	 * If the game may use the phone's files: "All files access" from Android 11 on, the storage permission before that.
	 */
	public static function hasFileAccess():Bool
	{
		try
		{
			if(extension.androidtools.os.Build.VERSION.SDK_INT >= 30) return extension.androidtools.os.Environment.isExternalStorageManager();
			return extension.androidtools.Permissions.getGrantedPermissions().contains('android.permission.WRITE_EXTERNAL_STORAGE');
		}
		catch(e:Dynamic) {}
		return false;
	}

	/**
	 * Asks for it: Android 11 and newer open the page of the settings where it's given.
	 */
	public static function askFileAccess():Void
	{
		try
		{
			if(extension.androidtools.os.Build.VERSION.SDK_INT >= 30)
				extension.androidtools.Settings.requestSetting('android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION');
			else
				extension.androidtools.Permissions.requestPermissions(['android.permission.READ_EXTERNAL_STORAGE', 'android.permission.WRITE_EXTERNAL_STORAGE']);
		}
		catch(e:Dynamic)
		{
			trace('Could not ask for the storage permission: $e');
		}
	}

	/**
	 * If the game should ask for the permission when it opens: it doesn't have it, and it wasn't refused before.
	 */
	public static function shouldAsk():Bool
	{
		if(hasFileAccess()) return false;
		var own:String = usable(mediaFolder());
		if(own == null) own = usable(appFolder());
		return own == null || !FileSystem.exists(own + REFUSED_MARK);
	}

	public static function refuse():Void
	{
		var own:String = usable(mediaFolder());
		if(own == null) own = usable(appFolder());
		if(own != null) try File.saveContent(own + REFUSED_MARK, "The game uses this folder: it wasn't given the permission to use the phone's files.") catch(e:Dynamic) {}
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
		if(path == null || path.length == 0 || FileSystem.exists(path)) return path;

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

	// The files of the APK the game reads as files: all of them but the ones only read through the asset library (the fonts)
	static function listToCopy():Array<String>
	{
		if(toCopy == null) toCopy = [for (id in lime.utils.Assets.list()) if(!StringTools.startsWith(id, '__')) id];
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
			// (the ones that can't be copied are inside the game itself, read from there: the fonts, flixel's own images)
			if(failed > 0) trace('$failed of the files were not copied');
			MobileStorage.markCopied();
			FlxG.switchState(Type.createInstance(next, []));
		}
		super.update(elapsed);
	}
}

/**
 * The first time the game is opened on a phone: asks for the permission to use the phone's files, so its folder (and its mods) can
 * be "Vortex Engine" on the phone's storage. Without it the game goes on with a folder of its own (see MobileStorage).
 */
class StorageAccessState extends flixel.FlxState
{
	var text:flixel.text.FlxText;
	var wait:Float = 0;

	override function create():Void
	{
		text = new flixel.text.FlxText(80, 0, FlxG.width - 160, '', 28);
		text.alignment = CENTER;
		text.text = 'The game keeps its files and your mods in the folder\n"' + MobileStorage.FOLDER_NAME + '" of your phone.\n\n'
			+ "Touch the screen to let it use the phone's files\n(on Android 11 and newer, turn on \"Allow access to manage all files\").\n\n"
			+ 'Touch the top of the screen to skip it: the game will use a folder of its own\n(Android/media) instead.';
		text.screenCenter(Y);
		add(text);
		super.create();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if android
		// (given in the settings, the game comes back to here: checked a few times a second)
		wait -= elapsed;
		if(wait <= 0)
		{
			wait = 0.5;
			if(MobileStorage.hasFileAccess())
			{
				done();
				return;
			}
		}

		if(FlxG.mouse.justReleased)
		{
			if(FlxG.mouse.screenY < FlxG.height * 0.2)
			{
				MobileStorage.refuse();
				done();
			}
			else MobileStorage.askFileAccess();
		}
		#else
		done();
		#end
	}

	function done():Void
	{
		MobileStorage.setup();
		FlxG.switchState(MobileStorage.needsCopy() ? new CopyState() : Type.createInstance(states.TitleState, []));
	}
}
