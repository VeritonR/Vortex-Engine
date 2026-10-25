package shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Hides what's to the left of a position on the screen, the results screen uses it so the song's name shows up from behind the difficulty.
 */
class LeftMaskShader extends FlxShader
{
	public var swagMaskX(default, set):Float = 0;
	public var swagSprX(default, set):Float = 0;

	function set_swagSprX(x:Float):Float
	{
		sprX.value[0] = x;
		return swagSprX = x;
	}

	function set_swagMaskX(x:Float):Float
	{
		maskX.value[0] = x;
		return swagMaskX = x;
	}

	@:glFragmentSource('
		#pragma header

		uniform float sprX;
		uniform float maskX;
		uniform float uvFrameX;
		uniform float uvFrameY;

		void main()
		{
			float cutOff = maskX - sprX;
			float sprPos = cutOff / openfl_TextureSize.x;

			vec2 uv = openfl_TextureCoordv.xy;
			vec4 color = flixel_texture2D(bitmap, uv);

			if (uv.x < sprPos + uvFrameX)
				color = vec4(0.0, 0.0, 0.0, 0.0);

			gl_FragColor = color;
		}
	')
	public function new()
	{
		super();
		sprX.value = [0];
		maskX.value = [0];
		uvFrameX.value = [0];
		uvFrameY.value = [0];
	}
}
