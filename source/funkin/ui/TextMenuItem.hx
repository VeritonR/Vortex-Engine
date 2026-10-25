package funkin.ui;

/**
 * An item of one of V-Slice's text menus: a text, and what's done when it's picked. Those menus are V-Slice's own (the options
 * pages), this is so the scripts that add items to them can be loaded.
 */
class TextMenuItem extends FlxSpriteGroup
{
	public var name:String;
	public var label:AtlasText;
	public var callback:Void->Void;
	public var fireInstantly:Bool = false;
	public var selected(default, null):Bool = false;

	public function new(x:Float = 0, y:Float = 0, name:String = '', ?font:Dynamic, ?callback:Void->Void)
	{
		super(x, y);
		this.name = name;
		this.callback = callback;
		label = new AtlasText(0, 0, name, font);
		add(label);
	}

	public function setItem(name:String, ?callback:Void->Void):Void
	{
		this.name = name;
		if(callback != null) this.callback = callback;
		label.text = name;
	}

	public function select():Void selected = true;
	public function idle():Void selected = false;
}
