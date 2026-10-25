package funkin.play.cutscene.dialogue;

/**
 * What V-Slice's dialogue scripts extend. The dialogues are run by the engine out of their data files (`cutscenes.VSliceConversation`),
 * the scripts made for them aren't run: this is here so they load without complaining.
 */
class Conversation extends funkin.modding.ScriptedBase
{
	public var id(default, null):String;
	public var state:String = ConversationState.Start;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
	}

	public function toString():String
	{
		return 'Conversation($id)';
	}
}

class ScriptedConversation extends Conversation {}

/**
 * The steps a dialogue goes through.
 */
class ConversationState
{
	public static var Start:String = 'Start';
	public static var Opening:String = 'Opening';
	public static var Speaking:String = 'Speaking';
	public static var Idle:String = 'Idle';
	public static var Ending:String = 'Ending';
}
