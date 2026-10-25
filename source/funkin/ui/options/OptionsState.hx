package funkin.ui.options;

/**
 * V-Slice's options menu. Mods use it to add their own options to it, which can't be done to the engine's menu:
 * these only exist so those scripts still load, their options keep the values the scripts start them with.
 */
class OptionsState
{
	public var optionsCodex:Dynamic = null;

	public function new() {}
}

class PreferencesMenu
{
	public function new() {}

	public function createPrefItemCheckbox(name:String, description:String, onChange:Dynamic, defaultValue:Bool, ?available:Bool):Void {}
	public function createPrefItemNumber(name:String, description:String, onChange:Dynamic, ?formatter:Dynamic, defaultValue:Dynamic, min:Dynamic, max:Dynamic, ?step:Dynamic, ?precision:Dynamic):Void {}
	public function createPrefItemPercentage(name:String, description:String, onChange:Dynamic, defaultValue:Dynamic, ?min:Dynamic, ?max:Dynamic):Void {}
	public function createPrefItemEnum(name:String, description:String, values:Dynamic, onChange:Dynamic, defaultValue:Dynamic):Void {}
}

class ControlsMenu
{
	public function new() {}
}
