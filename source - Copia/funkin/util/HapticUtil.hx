package funkin.util;

/**
 * V-Slice's vibration for phones and controllers. The engine has none, scripts that ask for it get nothing done.
 */
class HapticUtil
{
	public static var amplitudeTween:FlxTween = null;
	public static var defaultVibrationPreset:Dynamic = {period: 0.1, duration: 0.1, amplitude: 1, sharpness: 1};
	public static var hapticsAvailable:Bool = false;

	public static function vibrate(period:Float = 0, duration:Float = 0, amplitude:Float = 1, sharpness:Float = 1, ?targetHapticsModes:Array<Dynamic>):Void {}
	public static function vibrateByPreset(?vibrationPreset:Dynamic):Void {}
	public static function increasingVibrate(startAmplitude:Float, targetAmplitude:Float, tweenDuration:Float = 1):Void {}
	public static function stopVibration():Void {}
}
