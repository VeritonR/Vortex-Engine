package funkin.play.cutscene.dialogue;

import flixel.addons.text.FlxTypeText;

/**
 * What V-Slice's dialogue box scripts extend. The boxes of a dialogue are made by the engine out of their data files
 * (`cutscenes.VSliceConversation`), the scripts made for them aren't run: this is here so they load without complaining.
 */
class DialogueBox extends funkin.modding.ScriptedBase
{
	public var id(default, null):String;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
	}

	public function toString():String
	{
		return 'DialogueBox($id)';
	}
}

class ScriptedDialogueBox extends DialogueBox {}

/**
 * V-Slice's text that gets typed, the same as the library's with one more value when it's made.
 */
class FunkinTypeText extends FlxTypeText
{
	public var preWrapping:Bool = true;

	public function new(x:Float, y:Float, width:Int, text:String, size:Int = 8, embeddedFont:Bool = true, checkWrapping:Bool = true)
	{
		super(x, y, width, text, size, embeddedFont);
		preWrapping = checkWrapping;
	}
}
