package funkin.modding.module;

/**
 * What V-Slice module scripts extend: scripts that aren't tied to a song, a stage or a character.
 * Here they run while playing a song of the mod they're from, and on the menus V-Slice mods change (see `backend.VSliceScripts`).
 */
class Module extends funkin.modding.ScriptedBase
{
	public var active:Bool = true;
	public var moduleId(default, null):String = 'UNKNOWN';
	public var priority:Int = 1000;

	/**
	 * Class of the only state the module wants to hear about (`PlayState`, `MainMenuState`...), null for all of them.
	 */
	public var state:Dynamic = null;

	public function new(moduleId:String, ?priority:Dynamic, ?params:Dynamic)
	{
		this.moduleId = moduleId;

		if(Std.isOfType(priority, Int)) this.priority = priority;
		else if(priority != null && params == null) params = priority; //some scripts leave the priority out: super('id', {state: PlayState})

		if(params != null) state = params.state;
	}

	public function onStateCreate(event:funkin.modding.events.ScriptEvent):Void {}

	public function toString():String
	{
		return 'Module($moduleId)';
	}
}
