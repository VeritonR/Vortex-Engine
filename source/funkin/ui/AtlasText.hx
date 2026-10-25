package funkin.ui;

/**
 * V-Slice's text made of the letters of the alphabet's spritesheet (`new AtlasText(x, y, 'TEXT', 'bold')`): Psych's own one here.
 */
class AtlasText extends objects.Alphabet
{
	public var font(default, null):String;

	public function new(x:Float = 0, y:Float = 0, text:String = '', ?font:Dynamic)
	{
		this.font = (font != null) ? Std.string(font).toLowerCase() : 'default';
		super(x, y, text, this.font == 'bold');
	}

	public function getWidth():Int return Std.int(width);
	public function getHeight():Int return Std.int(height);
}
