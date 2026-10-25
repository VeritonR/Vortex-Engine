package shaders;

import flixel.math.FlxAngle;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

/**
 * V-Slice's recreation of Adobe Animate's "Adjust Color" filter, stage scripts put it on the characters.
 * It's what V-Slice scripts get when they import `funkin.graphics.shaders.AdjustColorShader`: a class on a package with that name
 * can't extend one of the engine's `shaders` package, the C++ compiler mixes both up.
 * Originally written by Rozebud (https://github.com/ThatRozebudDude), adapted from Andrey-Postelzhuk's shader.
 */
class AdjustColorShader extends ErrorHandledRuntimeShader
{
	static inline var SOURCE:String = '
		#pragma header

		uniform mat3 hueMatrix;
		uniform float contrast;
		uniform mat3 saturationMatrix;
		uniform float brightness;

		vec3 applyHSBCEffect(vec3 color)
		{
			vec3 bh = (brightness + color) * hueMatrix;
			vec3 c = (bh - 0.25) * contrast + 0.25;
			vec3 s = c * saturationMatrix;

			return s;
		}

		void main()
		{
			vec4 color4 = flixel_texture2D(bitmap, openfl_TextureCoordv);
			vec3 color3 = color4.a > 0.0 ? color4.rgb / color4.a : color4.rgb;

			color3 = applyHSBCEffect(color3);

			gl_FragColor = vec4(color3 * color4.a, color4.a);
		}';

	public var hue(default, set):Float = 0;
	function set_hue(value:Float):Float
	{
		hue = value;
		setFloatArray('hueMatrix', makeHueMatrix(value * FlxAngle.TO_RAD));
		return value;
	}

	public var saturation(default, set):Float = 0;
	function set_saturation(value:Float):Float
	{
		saturation = value;

		var amount:Float = (value > 0) ? value * 3 : value;
		setFloatArray('saturationMatrix', makeSaturationMatrix(1 + (amount / 100)));
		return value;
	}

	public var brightness(default, set):Float = 0;
	function set_brightness(value:Float):Float
	{
		brightness = value;
		setFloat('brightness', value / 255);
		return value;
	}

	public var contrast(default, set):Float = 0;
	function set_contrast(value:Float):Float
	{
		contrast = value;

		var amount:Float = 1 + (value / 100);
		if(amount > 1.0) amount = (((0.00852259 * Math.exp(4.76454 * (amount - 1.0))) * 1.01) - 0.0086078159) * 10.0 + 1.0;
		setFloat('contrast', amount);
		return value;
	}

	public function new()
	{
		super('adjustColor', SOURCE);
		hue = 0;
		saturation = 0;
		brightness = 0;
		contrast = 0;
	}

	static function makeHueMatrix(h:Float):Array<Float>
	{
		var c:Float = Math.cos(h);
		var s:Float = Math.sin(h);

		var wR:Float = 0.299;
		var wG:Float = 0.587;
		var wB:Float = 0.114;

		return [
			wR + (1 - wR) * c - wR * s, wG - wG * c - wG * s, wB - wB * c + (1 - wB) * s,
			wR - wR * c + 0.143 * s, wG + (1 - wG) * c + 0.140 * s, wB - wB * c - 0.283 * s,
			wR - wR * c - (1 - wR) * s, wG - wG * c + wG * s, wB + (1 - wB) * c + wB * s
		];
	}

	static function makeSaturationMatrix(s:Float):Array<Float>
	{
		var lr:Float = 0.2126;
		var lg:Float = 0.7152;
		var lb:Float = 0.0722;
		var inv:Float = 1.0 - s;

		return [
			lr * inv + s, lg * inv, lb * inv,
			lr * inv, lg * inv + s, lb * inv,
			lr * inv, lg * inv, lb * inv + s
		];
	}

	public function toString():String
	{
		return 'AdjustColorShader($hue, $saturation, $brightness, $contrast)';
	}
}
