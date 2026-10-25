package funkin.ui.debug;

/**
 * V-Slice's debug menu, which scripts add options to (`createItem()`) when it opens. The engine has its own menu for its editors
 * (states.editors.MasterEditorMenu), so this one never opens: it's here for the scripts that check for it, which have nothing to do then.
 */
class DebugMenuSubState extends backend.MusicBeatSubstate
{
	public var items:Array<{name:String, callback:Void->Void}> = [];

	public function createItem(name:String, callback:Void->Void, fireInstantly:Bool = false):Dynamic
	{
		var item = {name: name, callback: callback};
		items.push(item);
		return item;
	}
}
