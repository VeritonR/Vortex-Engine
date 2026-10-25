package shaders;

import flixel.system.FlxAssets.FlxShader;
import flixel.tweens.FlxTween.TweenOptions;

// Shaders of the V-Slice Freeplay menu, taken from V-Slice as they are

/**
 * Cuts the left side of a sprite diagonally and tints it, used by the image behind the songs.
 */
class AngleMask extends FlxShader
{
	public var extraColor(default, set):FlxColor = 0xFFFFFFFF;

	function set_extraColor(value:FlxColor):FlxColor
	{
		extraTint.value = [value.redFloat, value.greenFloat, value.blueFloat];
		return extraColor = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec3 extraTint;
		uniform vec2 endPosition;

		vec2 hash22(vec2 p) {
			vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
			p3 += dot(p3, p3.yzx + 33.33);
			return fract((p3.xx + p3.yz) * p3.zy);
		}

		vec4 mainPass(vec2 fragCoord) {
			vec4 base = flixel_texture2D(bitmap, fragCoord);

			vec2 uv = fragCoord.xy;

			vec2 start = vec2(0.0, 0.0);
			vec2 end = vec2(endPosition.x / openfl_TextureSize.x, 1.0);

			float dx = end.x - start.x;
			float dy = end.y - start.y;

			float angle = atan(dy, dx);

			uv.x -= start.x;
			uv.y -= start.y;

			float uvA = atan(uv.y, uv.x);

			if (uvA < angle)
				return base;
			else
				return vec4(0.0);
		}

		vec4 antialias(vec2 fragCoord) {
			const float AA_STAGES = 2.0;

			const float AA_TOTAL_PASSES = AA_STAGES * AA_STAGES + 1.0;
			const float AA_JITTER = 0.5;

			vec4 color = mainPass(fragCoord);
			for (float x = 0.0; x < AA_STAGES; x++)
			{
				for (float y = 0.0; y < AA_STAGES; y++)
				{
					vec2 offset = AA_JITTER * (2.0 * hash22(vec2(x, y)) - 1.0) / openfl_TextureSize.xy;
					color += mainPass(fragCoord + offset);
				}
			}
			return color / AA_TOTAL_PASSES;
		}

		void main() {
			vec4 col = antialias(openfl_TextureCoordv);
			col.xyz = col.xyz * extraTint.xyz;
			gl_FragColor = col;
		}')
	public function new()
	{
		super();

		endPosition.value = [90, 100];
		extraTint.value = [1, 1, 1];
	}
}

/**
 * Blur behind the song names, ranks and hearts of the capsules.
 */
class GaussianBlurShader extends FlxShader
{
	public var amount(default, set):Float = 1;

	function set_amount(value:Float):Float
	{
		_amount.value = [value];
		return amount = value;
	}

	// How V-Slice scripts change it
	public function setAmount(value:Float):Void
	{
		amount = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform float _amount;

		vec4 blur13(sampler2D image, vec2 uv, vec2 resolution, vec2 direction) {
			vec4 color = vec4(0.0);
			vec2 off1 = vec2(1.411764705882353) * direction;
			vec2 off2 = vec2(3.2941176470588234) * direction;
			vec2 off3 = vec2(5.176470588235294) * direction;
			color += texture2D(image, uv) * 0.1964825501511404;
			color += texture2D(image, uv + (off1 / resolution)) * 0.2969069646728344;
			color += texture2D(image, uv - (off1 / resolution)) * 0.2969069646728344;
			color += texture2D(image, uv + (off2 / resolution)) * 0.09447039785044732;
			color += texture2D(image, uv - (off2 / resolution)) * 0.09447039785044732;
			color += texture2D(image, uv + (off3 / resolution)) * 0.010381362401148057;
			color += texture2D(image, uv - (off3 / resolution)) * 0.010381362401148057;
			return color;
		}

		void main() {
			vec4 blurred = blur13(bitmap, openfl_TextureCoordv, openfl_TextureSize.xy, vec2(0.0, _amount * 2.0));
			blurred = mix(blur13(bitmap, openfl_TextureCoordv, openfl_TextureSize.xy, vec2(_amount * 2.0, 0.0)), blurred, 0.5);
			gl_FragColor = blurred;
		}')
	public function new(amount:Float = 1)
	{
		super();
		this.amount = amount;
	}
}

/**
 * Outline around a sprite, the texts at the top of the menu flash with it when they show up.
 */
class StrokeShader extends FlxShader
{
	public var width(default, set):Float = 0;
	public var height(default, set):Float = 0;
	public var col(default, set):FlxColor = 0xFFFFFFFF;

	function set_width(value:Float):Float
	{
		size.value = [value, height];
		return width = value;
	}

	function set_height(value:Float):Float
	{
		size.value = [width, value];
		return height = value;
	}

	function set_col(value:FlxColor):FlxColor
	{
		color.value = [value.red, value.green, value.blue, value.alpha];
		return col = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec2 size;
		uniform vec4 color;

		void main()
		{
			vec4 texel = flixel_texture2D(bitmap, openfl_TextureCoordv);
			if (texel.a == 0.) {
				float w = size.x / openfl_TextureSize.x;
				float h = size.y / openfl_TextureSize.y;

				if (flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x + w, openfl_TextureCoordv.y)).a != 0.
				|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x - w, openfl_TextureCoordv.y)).a != 0.
				|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x, openfl_TextureCoordv.y + h)).a != 0.
				|| flixel_texture2D(bitmap, vec2(openfl_TextureCoordv.x, openfl_TextureCoordv.y - h)).a != 0.)
					texel = color;
			}
			gl_FragColor = texel;
		}')
	public function new(color:FlxColor = 0xFFFFFFFF, width:Float = 1, height:Float = 1)
	{
		super();

		col = color;
		this.width = width;
		this.height = height;
	}
}

/**
 * Paints a sprite with a single color, the difficulty arrows flash white with it when pressed.
 */
class PureColor extends FlxShader
{
	public var col(default, set):FlxColor;
	public var colorSet(default, set):Bool;

	function set_colorSet(value:Bool):Bool
	{
		colSet.value = [value];
		return colorSet = value;
	}

	function set_col(value:FlxColor):FlxColor
	{
		funnyColor.value = [value.redFloat, value.greenFloat, value.blueFloat, value.alphaFloat];
		return col = value;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec4 funnyColor;
		uniform bool colSet;

		void main()
		{
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

			if (color.a > 0.0 && colSet)
				color = funnyColor * color.a;

			gl_FragColor = color;
		}')
	public function new(color:FlxColor)
	{
		super();

		col = color;
		colorSet = false;
	}
}

/**
 * Fades the whole menu to black with the blue lasting a bit longer, used when going to and coming from Character Select.
 */
class BlueFade extends FlxShader
{
	public var fadeVal(default, set):Float = 1;

	function set_fadeVal(value:Float):Float
	{
		fadeAmt.value = [value];
		return fadeVal = value;
	}

	public function fade(startAmount:Float = 0, targetAmount:Float = 1, duration:Float, ?options:TweenOptions):Void
	{
		fadeVal = startAmount;
		FlxTween.tween(this, {fadeVal: targetAmount}, duration, options);
	}

	@:glFragmentSource('
		#pragma header

		uniform float fadeAmt;

		void main()
		{
			vec4 tex = flixel_texture2D(bitmap, openfl_TextureCoordv);

			vec4 finalColor = mix(vec4(vec4(0.0, 0.0, tex.b, tex.a) * fadeAmt), vec4(tex * fadeAmt), fadeAmt);

			gl_FragColor = finalColor;
		}')
	public function new()
	{
		super();
		fadeVal = 1;
	}
}
