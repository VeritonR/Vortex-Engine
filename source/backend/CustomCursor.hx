package backend;

import openfl.display.BitmapData;

/**
 * The mouse cursor's picture: "images/cursor.png" takes the place of the default one, on every screen. The game's own
 * (assets/shared/images/cursor.png), or a mod's (mods/My Mod/images/cursor.png): the one of the mod being played comes first.
 *
 * An optional "images/cursor.txt" next to it says how it's used, in one line: "scale, x, y"
 *     2, 0, 0        twice as big, clicking with its top left corner (the default is "1, 0, 0")
 *     1, 16, 16      clicking with the pixel 16, 16 of the picture (its middle, for a 32x32 crosshair)
 *
 * Scripts can still change it whenever they want: FlxG.mouse.load(...) (it goes back to this one on the next screen).
 */
class CustomCursor
{
	static var started:Bool = false;
	static var currentPath:String = null;

	public static function init():Void
	{
		if(started) return;
		started = true;
		FlxG.signals.postStateSwitch.add(refresh);
		refresh();
	}

	/**
	 * Looks for the cursor's picture again (the mod being played may have changed) and puts it on.
	 */
	public static function refresh():Void
	{
		var path:String = findFile('images/cursor.png');
		if(path == currentPath) return;
		currentPath = path;

		if(path == null)
		{
			FlxG.mouse.unload(); //(the default one)
			return;
		}

		try
		{
			// (a copy of its own: the images of the game are let go of between screens, the cursor stays)
			var picture:BitmapData = BitmapData.fromFile(path);
			if(picture == null) throw 'not an image';

			var scale:Float = 1;
			var hotX:Int = 0;
			var hotY:Int = 0;
			var settings:String = findFile('images/cursor.txt');
			if(settings != null)
			{
				var parts:Array<String> = [for (part in #if sys sys.io.File.getContent(settings) #else '' #end.split(',')) part.trim()];
				var number:Float = Std.parseFloat(parts[0]);
				if(!Math.isNaN(number) && number > 0) scale = number;
				if(parts.length > 2)
				{
					var x:Null<Int> = Std.parseInt(parts[1]);
					var y:Null<Int> = Std.parseInt(parts[2]);
					if(x != null) hotX = x;
					if(y != null) hotY = y;
				}
			}
			FlxG.mouse.load(picture, scale, Std.int(-hotX * scale), Std.int(-hotY * scale));
		}
		catch(e:Dynamic)
		{
			trace('The cursor "$path" could not be used: $e');
			FlxG.mouse.unload();
		}
	}

	// The file of the mod being played (or of a mod that runs globally), or the game's own; null if there's none
	static function findFile(key:String):String
	{
		#if MODS_ALLOWED
		var modded:String = Paths.modFolders(key);
		if(FileSystem.exists(modded)) return modded;
		#end
		var own:String = Paths.getSharedPath(key);
		#if sys
		return FileSystem.exists(own) ? own : null;
		#else
		return null;
		#end
	}
}
