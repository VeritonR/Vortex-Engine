package funkin.modding;

/**
 * What V-Slice scripts tell the player about a problem with: there it's a window of the system that stops the game until it's closed,
 * here it's a line on the screen during a song and on the script log ("hxc_errors.txt") always.
 */
class PolymodErrorHandler
{
	public static function showAlert(name:String, desc:String):Void
	{
		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.warn((name != null ? name : 'Alert') + ((desc != null && desc.length > 0) ? ': $desc' : ''));
		#else
		trace('$name: $desc');
		#end
	}
}
