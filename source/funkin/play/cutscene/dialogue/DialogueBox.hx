package funkin.play.cutscene.dialogue;

import flixel.addons.text.FlxTypeText;

/**
 * What V-Slice's dialogue box scripts extend: the engine's own box (`cutscenes.VSliceConversation.VSliceDialogueBox`) for the box
 * with that id, with the script doing what it has its own version of (the font and sound of the text, `loadText()`; what's typed,
 * `setText()`...). V-Slice uses the script's box instead of the file's own when there's one for the id.
 */
class DialogueBox extends cutscenes.VSliceConversation.VSliceDialogueBox
{
	public var dialogueBoxName(get, never):String;
	function get_dialogueBoxName():String return (data != null && data.name != null) ? data.name : 'UNKNOWN';

	public function new(id:String, ?params:Dynamic)
	{
		// (made later, when it's shown: a script is made first only to know which box it is, see VSliceScripts.makeDialogueBoxScript())
		super(id, withDefaults(cutscenes.VSliceConversation.loadData('boxes', id)), false);
	}

	// V-Slice's data of a box has values when the file leaves them out, its scripts count on them (Hazier Hiver's box has no size
	// for its text: 32), and its font is found by name. The font is given here as the game's file of it, which is what the text needs
	@:access(cutscenes.VSliceConversation.VSliceDialogueBox)
	static function withDefaults(data:Dynamic):Dynamic
	{
		if(data == null) return null;
		if(data.offsets == null) data.offsets = [0, 0];
		if(data.animations == null) data.animations = [];
		if(data.text == null) data.text = {};
		var text:Dynamic = data.text;
		if(text.offsets == null) text.offsets = [0, 0];
		if(text.width == null) text.width = 300;
		if(text.size == null) text.size = 32;
		if(text.color == null) text.color = '#000000';
		text.fontFamily = cutscenes.VSliceConversation.VSliceDialogueBox.findFont((text.fontFamily != null) ? text.fontFamily : 'Arial');
		return data;
	}

	// What V-Slice's has that scripts call or replace
	public function onCreate(event:Dynamic):Void {}
	public function onDestroy(event:Dynamic):Void {}
	public function onUpdate(event:Dynamic):Void {}
	public function onScriptEvent(event:Dynamic):Void {}
	public function onDialogueStart(event:Dynamic):Void {}
	public function onDialogueCompleteLine(event:Dynamic):Void {}
	public function onDialogueLine(event:Dynamic):Void {}
	public function onDialogueSkip(event:Dynamic):Void {}
	public function onDialogueEnd(event:Dynamic):Void {}

	public function setScale(scale:Null<Float>):Void
	{
		if(scale == null) scale = 1;
		if(boxSprite == null) return;
		boxSprite.scale.set(scale, scale);
		boxSprite.updateHitbox();
	}

	override public function toString():String
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
