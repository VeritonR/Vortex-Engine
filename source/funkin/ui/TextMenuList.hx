package funkin.ui;

import funkin.ui.MenuList;

/**
 * A V-Slice menu of texts in its bold letters ("Remap...", "EXIT"...), for the mods that make menus of their own with it.
 * Ported from V-Slice (funkin.ui.TextMenuList).
 */
class TextMenuList extends MenuTypedList<TextMenuItem>
{
	public function new(?navControls:NavControls, ?wrapMode:WrapMode)
	{
		super(navControls, wrapMode);
	}

	public function createItem(x:Float = 0, y:Float = 0, name:String, ?font:Dynamic, ?callback:Void->Void, fireInstantly:Bool = false,
		available:Bool = true):TextMenuItem
	{
		var item:TextMenuItem = new TextMenuItem(x, y, name, (font != null) ? font : 'bold', callback, available);
		item.fireInstantly = fireInstantly;
		return addItem(name, item);
	}
}

/**
 * An item of a `TextMenuList`: its name written with `AtlasText`.
 */
class TextMenuItem extends TextTypedMenuItem<AtlasText>
{
	public var atlasText:AtlasText;

	public function new(x:Float = 0, y:Float = 0, name:String = '', ?font:Dynamic, ?callback:Void->Void, available:Bool = true)
	{
		atlasText = new AtlasText(0, 0, name, (font != null) ? font : 'bold');
		super(x, y, atlasText, name, callback, available);
		setEmptyBackground();
	}
}

class TextTypedMenuItem<T:AtlasText> extends MenuTypedItem<T>
{
	public function new(x:Float = 0, y:Float = 0, label:T, name:String, ?callback:Void->Void, available:Bool = true)
	{
		super(x, y, label, name, callback, available);
	}

	override function setItem(name:String, ?callback:Void->Void):Void
	{
		if(label != null)
		{
			label.text = name;
			label.alpha = alpha;
			width = label.width;
			height = label.height;
		}
		super.setItem(name, callback);
	}

	override function set_label(value:T):T
	{
		super.set_label(value);
		setItem(name, callback);
		return value;
	}
}
