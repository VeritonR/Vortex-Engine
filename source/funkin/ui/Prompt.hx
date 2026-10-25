package funkin.ui;

/**
 * V-Slice's yes or no window, with a text and a background. Its menus that use it are V-Slice's own, this is so the scripts
 * that make one can be loaded and do what they do with it.
 */
class Prompt extends FlxSpriteGroup
{
	public var back:FlxSprite;
	public var field:AtlasText;
	public var buttons:FlxSpriteGroup;
	public var onYes:Void->Void;
	public var onNo:Void->Void;

	var text:String;
	var style:Dynamic;

	public function new(text:String = '', ?style:Dynamic)
	{
		super();
		this.text = text;
		this.style = style;
		back = new FlxSprite();
		buttons = new FlxSpriteGroup();
	}

	public function create():Void
	{
		field = new AtlasText(0, 0, text, 'bold');
		field.scrollFactor.set();
		add(field);
		add(buttons);
	}

	public function createBg(width:Int, height:Int, color:FlxColor = 0xFF808080):Void
	{
		back.makeGraphic(width, height, color);
		back.screenCenter();
		insert(0, back);
	}

	public function createBgFromMargin(margin:Float = 100, color:FlxColor = 0xFF808080):Void
	{
		createBg(Std.int(FlxG.width - margin * 2), Std.int(FlxG.height - margin * 2), color);
	}

	public function setText(text:String):Void
	{
		this.text = text;
		if(field != null) field.text = text;
	}

	public function setButtons(style:Dynamic):Void this.style = style;
}
