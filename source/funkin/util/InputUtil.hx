package funkin.util;

import flixel.input.keyboard.FlxKey;

/**
 * V-Slice's names of the keys, for the scripts that show them.
 */
class InputUtil
{
	public static function getKeyName(key:Int):String
	{
		if(key < 0) return '[?]';
		var name:String = FlxKey.toStringMap.get(key);
		return (name != null) ? name : '[?]';
	}

	public static function format(key:Int):String return getKeyName(key);
}

// (V-Slice's, for scripts: see the import of it on V-Slice)
enum abstract ControllerName(String) from String to String
{
	/**
	 * Ouya controller
	 */
	public var OUYA = 'Ouya';

	/**
	 * PlayStation 4 controller
	 */
	public var PS4 = 'PS4';

	/**
	 * Logitech controller
	 */
	public var LOGI = 'Logi';

	/**
	 * XBox controller
	 */
	public var XBOX = 'XBox';

	/**
	 * XInput controller
	 */
	public var XINPUT = 'XInput';

	/**
	 * Wii controller
	 */
	public var WII = 'Wii';

	/**
	 * Nintendo Switch Pro Controller
	 */
	public var PRO_CON = 'Pro_Con';

	/**
	 * Nintendo Switch JoyCons
	 */
	public var JOYCONS = 'Joycons';

	/**
	 * Nintendo Switch JoyCon (Left Only)
	 */
	public var JOYCON_L = 'Joycon_L';

	/**
	 * Nintendo Switch JoyCon (Right Only)
	 */
	public var JOYCON_R = 'Joycon_R';

	/**
	 * MFi controller
	 */
	public var MFI = 'MFI';

	/**
	 * A generic gamepad.
	 */
	public var PAD = 'Pad';

	/**
	 * Get the asset path for a device.
	 * @param device The input device
	 * @return The path to the device asset image
	 */
	public static function getAssetByDevice(device:funkin.input.Controls.Device):String
	{
		return switch (device)
		{
			case Keys:
				getAsset(null);
			case Gamepad(id):
				getAsset(FlxG.gamepads.getByID(id));
		}
	}

	/**
	 * Get the asset path for a gamepad.
	 * @param gamepad The gamepad to get the asset for, or null for keyboard
	 * @return The path to the device asset image
	 */
	public static function getAsset(gamepad:Null<flixel.input.gamepad.FlxGamepad>):String
	{
		if (gamepad == null) return 'assets/images/ui/devices/Keys.png';

		var name = parseName(gamepad.name);
		var path = 'assets/images/ui/devices/$name.png';
		if (openfl.utils.Assets.exists(path)) return path;

		return 'assets/images/ui/devices/Pad.png';
	}

	/**
	 * Get the controller name for a gamepad by its ID.
	 * @param id The gamepad ID
	 * @return The controller name
	 */
	public static inline function getNameById(id:Int):ControllerName
	{
		return getName(FlxG.gamepads.getByID(id));
	}

	/**
	 * Get the controller name for a gamepad.
	 * @param gamepad The gamepad to get the name from
	 * @return The controller name
	 */
	public static inline function getName(gamepad:flixel.input.gamepad.FlxGamepad):ControllerName
	{
		return parseName(gamepad.name);
	}

	/**
	 * Parse a controller name string and return the corresponding ControllerName.
	 * @param name The controller name string to parse
	 * @return The corresponding ControllerName enum value
	 */
	public static function parseName(name:String):ControllerName
	{
		name = name.toLowerCase().replace('-', '').replace('_', '');

		if (name.contains('ouya'))
		{
			return OUYA;
		}
		else if (name.contains('wireless controller') || name.contains('ps4'))
		{
			return PS4;
		}
		else if (name.contains('logitech'))
		{
			return LOGI;
		}
		else if (name.contains('xbox'))
		{
			return XBOX;
		}
		else if (name.contains('xinput'))
		{
			return XINPUT;
		}
		else if (name.contains('nintendo rvlcnt01tr') || name.contains('nintendo rvlcnt01'))
		{
			return WII;
		}
		else if (name.contains('mayflash wiimote pc adapter'))
		{
			return WII;
		}
		else if (name.contains('pro controller'))
		{
			return PRO_CON;
		}
		else if (name.contains('joycon l+r'))
		{
			return JOYCONS;
		}
		else if (name.contains('joycon (l)'))
		{
			return JOYCON_L;
		}
		else if (name.contains('joycon (r)'))
		{
			return JOYCON_R;
		}
		else if (name.contains('mfi'))
		{
			return MFI;
		}
		else
		{
			return PAD;
		}
	}
}
