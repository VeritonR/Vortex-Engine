package funkin.modding.module;

/**
 * Lets scripts reach the modules of the mod being played.
 */
class ModuleHandler
{
	public static function getModule(moduleId:String):Module
	{
		return backend.VSliceScripts.getModule(moduleId);
	}

	public static function activateModule(moduleId:String):Void
	{
		var module:Module = getModule(moduleId);
		if(module != null) module.active = true;
	}

	public static function deactivateModule(moduleId:String):Void
	{
		var module:Module = getModule(moduleId);
		if(module != null) module.active = false;
	}

	public static function callEvent(event:funkin.modding.events.ScriptEvent):Void
	{
		backend.VSliceScripts.dispatchToModules(event);
	}
}
