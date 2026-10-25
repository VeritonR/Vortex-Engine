package funkin;

/**
 * V-Slice's players and their controls (`PlayerSettings.player1.controls.ACCEPT`). There's one set of controls here,
 * the game's own, and both players have it.
 */
class PlayerSettings
{
	public static var numPlayers(default, null):Int = 1;
	public static var numAvatars(default, null):Int = 1;

	public static var player1(get, never):PlayerSettings;
	public static var player2(get, never):PlayerSettings;

	static var _player1:PlayerSettings = null;
	static var _player2:PlayerSettings = null;

	static function get_player1():PlayerSettings
	{
		if(_player1 == null) _player1 = new PlayerSettings(0);
		return _player1;
	}

	static function get_player2():PlayerSettings
	{
		if(_player2 == null) _player2 = new PlayerSettings(1);
		return _player2;
	}

	public var id(default, null):Int;
	public var controls(get, never):backend.Controls;
	function get_controls():backend.Controls return backend.Controls.instance;

	function new(id:Int)
	{
		this.id = id;
	}

	public static function init():Void {}
	public static function reset():Void {}
}
