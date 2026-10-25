package funkin.input;

/**
 * The mouse cursor as V-Slice scripts know it. The engine has a single cursor, so the modes they pick only say if it's shown.
 */
class Cursor
{
	public static var cursorMode(default, set):Null<String> = null;
	static function set_cursorMode(value:Null<String>):Null<String>
	{
		cursorMode = value;
		FlxG.mouse.visible = (value != null);
		return value;
	}

	public static function show():Void
	{
		FlxG.mouse.visible = true;
		if(cursorMode == null) cursorMode = 'Default';
	}

	public static function hide():Void
	{
		FlxG.mouse.visible = false;
	}

	public static function toggle():Void
	{
		if(FlxG.mouse.visible) hide();
		else show();
	}
}
