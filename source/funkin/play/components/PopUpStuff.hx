package funkin.play.components;

import flixel.util.FlxSignal.FlxTypedSignal;

/**
 * The ratings and the combo numbers that pop up when a note is hit, as V-Slice scripts know them (`PlayState.instance.comboPopUps`).
 * On Psych they're the sprites of PlayState's `comboGroup`.
 */
class PopUpStuff
{
	var game:states.PlayState;

	public function new(game:states.PlayState)
	{
		this.game = game;
	}

	/**
	 * The note style the ratings and the numbers are drawn with (see `states.PlayState.popUpScore()`).
	 */
	public var noteStyle:funkin.play.notes.notestyle.NoteStyle = null;

	var group(get, never):FlxSpriteGroup;
	inline function get_group():FlxSpriteGroup return game.comboGroup;

	/**
	 * How far from their usual place they show up.
	 */
	public var offsets(default, set):Array<Float> = [0, 0];
	function set_offsets(value:Array<Float>):Array<Float>
	{
		if(value == null || value.length < 2) value = [0, 0];
		if(group != null) group.setPosition(value[0], value[1]);
		return offsets = value;
	}

	/**
	 * Null puts them on the game's camera, where they can be among the things of the stage.
	 */
	public var cameras(get, set):Array<FlxCamera>;
	function get_cameras():Array<FlxCamera> return (group != null) ? group.cameras : null;
	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		if(group != null) group.cameras = (value != null) ? value : [game.camGame];
		return value;
	}

	public var camera(get, set):FlxCamera;
	function get_camera():FlxCamera return (group != null) ? group.camera : null;
	function set_camera(value:FlxCamera):FlxCamera
	{
		cameras = (value != null) ? [value] : null;
		return value;
	}

	/**
	 * Called with each sprite that pops up.
	 */
	public var memberAdded(get, never):FlxTypedSignal<FlxSprite->Void>;
	function get_memberAdded():FlxTypedSignal<FlxSprite->Void> return group.group.memberAdded;

	public var memberRemoved(get, never):FlxTypedSignal<FlxSprite->Void>;
	function get_memberRemoved():FlxTypedSignal<FlxSprite->Void> return group.group.memberRemoved;

	public var members(get, never):Array<FlxSprite>;
	function get_members():Array<FlxSprite> return (group != null) ? group.members : [];

	public var visible(get, set):Bool;
	function get_visible():Bool return (group != null && group.visible);
	function set_visible(value:Bool):Bool
	{
		if(group != null) group.visible = value;
		return value;
	}

	public var alpha(get, set):Float;
	function get_alpha():Float return (group != null) ? group.alpha : 1;
	function set_alpha(value:Float):Float
	{
		if(group != null) group.alpha = value;
		return value;
	}

	public var zIndex:Int = 0;
}
