package funkin.ui;

import flixel.graphics.frames.FlxAtlasFrames;
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

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum Case
{
	Both;
	Upper;
	Lower;
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum abstract AtlasFont(String) from String to String
{
	public var DEFAULT = 'default';
	public var BOLD = 'bold';
	public var FREEPLAY_CLEAR = 'freeplay-clear';
}

// (V-Slice's, for its classes and scripts)
class AtlasChar extends FlxSprite
{
  /**
   * Which character in the font we are using
   */
  public var char(default, set):String;

  public function new(x = 0.0, y = 0.0, atlas:FlxAtlasFrames, char:String)
  {
    super(x, y);
    frames = atlas;
    this.char = char;
  }

  function set_char(value:String):String
  {
    if (this.char == value) return this.char;

    animation.addByPrefix('anim', getAnimPrefix(value), 24);
    if (animation.exists('anim')) animation.play('anim');

    updateHitbox();

    this.char = value;
    return this.char;
  }

  function getAnimPrefix(char:String):String
  {
    return switch (char)
    {
      case '&':
        return '-andpersand-';
      case '😠':
        '-angry faic-'; // TODO: Do multi-flag characters work?
      case "'":
        '-apostraphie-';
      case '\\':
        '-back slash-';
      case ',':
        '-comma-';
      case '-':
        '-dash-';
      case '↓':
        '-down arrow-'; // U+2193
      case '”':
        '-end quote-'; // U+0022
      case '!':
        '-exclamation point-'; // U+0021
      case '/':
        '-forward slash-'; // U+002F
      case '>':
        '-greater than-'; // U+003E
      case '♥':
        '-heart-'; // U+2665
      case '♡':
        '-heart-';
      case '←':
        '-left arrow-'; // U+2190
      case '<':
        '-less than-'; // U+003C
      case '*':
        '-multiply x-';
      case '.':
        '-period-'; // U+002E
      case '?':
        '-question mark-';
      case '→':
        '-right arrow-'; // U+2192
      case '“':
        '-start quote-';
      case '↑':
        '-up arrow-'; // U+2191

      // Default to getting the character itself.
      default:
        char;
    }
  }
}
