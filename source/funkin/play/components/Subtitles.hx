package funkin.play.components;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;
import flixel.FlxSprite;
import funkin.util.SRTUtil.SubtitleEntry;
import funkin.util.SRTUtil.SRTParser;

/**
 * V-Slice's subtitles: the lines of an .srt file shown while a sound plays (the lyrics of Sonic.exe's Prey, the cutscenes of Week 7).
 * Ported from V-Slice's `funkin.play.components.Subtitles`.
 */
class Subtitles extends FlxSpriteGroup
{
	var subtitleText:SubtitlesText;
	var background:FlxSprite;

	public var subtitlesData:Array<SubtitleEntry>;
	public var assignedSound:FlxSound;

	public var offsets(default, set):Array<Float> = [0, 0];
	public var alignment(default, set):SubtitlesAlignment = SubtitlesAlignment.SUBTITLES_BOTTOM;

	public function new(x:Float = 0, y:Float = 0, alignment:SubtitlesAlignment = SubtitlesAlignment.SUBTITLES_BOTTOM)
	{
		super(0, 0);

		background = new FlxSprite(0, 0);
		background.alpha = 0.5;
		add(background);

		subtitleText = new SubtitlesText(0, 0, 30, funkin.Paths.font('vcr.ttf'));
		add(subtitleText);

		this.offsets = [x, y];
		this.alignment = alignment;

		setText([], true);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if(assignedSound == null || subtitlesData == null) return;

		var currentLines:Array<String> = [];
		for (data in subtitlesData)
			if(assignedSound.time >= data.start && assignedSound.time <= data.end)
				currentLines.unshift(data.text);

		setText(currentLines, currentLines.length < 1);
	}

	/**
	 * Loads the subtitles of an .srt file (a path inside "data", without the extension) for a sound.
	 */
	public function assignSubtitles(filePath:String, sound:FlxSound):Void
	{
		setText([], true);

		if(!funkin.Assets.exists(funkin.Paths.srt(filePath)) || sound == null) return;

		subtitlesData = SRTParser.parseFromFile(filePath);
		if(subtitlesData == null) return;

		assignedSound = sound;
	}

	function setText(lines:Array<String>, hide:Bool = false):Void
	{
		visible = !hide;

		var targetText:String = lines.join('\n');
		if(subtitleText.text == targetText) return;

		subtitleText.text = targetText;
		background.makeGraphic(Math.ceil(Math.max(1, subtitleText.width)), Math.ceil(Math.max(1, subtitleText.height)), FlxColor.BLACK, true);

		updatePosition();
	}

	function updatePosition():Void
	{
		if(offsets == null) return;

		screenCenter(X);
		x += offsets[0];

		switch(alignment)
		{
			case SubtitlesAlignment.SUBTITLES_TOP:
				y = 0 + offsets[1];
			default:
				y = FlxG.height - this.height - offsets[1];
		}
	}

	function set_alignment(value:SubtitlesAlignment):SubtitlesAlignment
	{
		alignment = value;
		updatePosition();
		return alignment;
	}

	function set_offsets(value:Array<Float>):Array<Float>
	{
		offsets = value;
		updatePosition();
		return offsets;
	}
}

/**
 * The text of the subtitles, which is HTML (`<font color=...>` and such).
 */
class SubtitlesText extends FlxText
{
	public function new(x:Float = 0, y:Float = 0, size:Int, font:String)
	{
		super(x, y, 0, '', size);

		this.font = font;
		this.size = size;
		this.alignment = FlxTextAlign.CENTER;
	}

	override function set_text(Text:String):String
	{
		text = Text;
		if(textField != null)
		{
			var old:String = textField.htmlText;
			textField.htmlText = Text;
			_regen = (textField.htmlText != old) || _regen;
		}
		return Text;
	}

	override function applyFormats(_:openfl.text.TextFormat, __:Bool = false):Void
	{
		// (it would undo what the HTML of the text does)
	}
}

enum abstract SubtitlesAlignment(String) from String to String
{
	public var SUBTITLES_TOP:String = 'top';
	public var SUBTITLES_BOTTOM:String = 'bottom';
}
