package funkin.modding.events;

/**
 * Sends an event to one object (`ScriptEventDispatcher.callEvent(stage, new ScriptEvent(CREATE))`): to its script, if it has one.
 */
class ScriptEventDispatcher
{
	public static function callEvent(target:Dynamic, event:ScriptEvent):Void
	{
		#if HSCRIPT_ALLOWED
		if(target == null || event == null) return;
		backend.VSliceScripts.sendEvent(target, event);
		#end
	}
}
