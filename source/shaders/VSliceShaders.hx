package shaders;

import openfl.display.BitmapData;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

// Shaders of V-Slice's `funkin.graphics.shaders` package that its scripts make themselves, with the same names and values.
// They're here for the same reason the others are: see AdjustColorShader.

/**
 * The files of V-Slice's shaders, which come with the engine ("shaders" folder) and can be replaced by mods.
 */
class VSliceShaderSource
{
	public static function get(name:String):String
	{
		var text:String = null;
		try
		{
			text = funkin.Assets.getText(funkin.Paths.frag(name));
		}
		catch(e:Dynamic) {}

		if(text == null) trace('The shader file "shaders/$name.frag" was not found, the shader that uses it will do nothing');
		return text;
	}
}

/**
 * Blends an image over the sprite like the "overlay" blend mode does. The image is given through `funnyShit.input`.
 */
class OverlayBlend extends ErrorHandledRuntimeShader
{
	static inline var SOURCE:String = '
		#pragma header

		uniform float alphaShit;
		uniform float yPos;
		uniform float xPos;
		uniform sampler2D funnyShit;

		vec4 blendOverlay(vec4 base, vec4 blend)
		{
			vec4 mixed = mix(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, step(base, vec4(0.5)));
			return mixed;
		}

		void main()
		{
			vec2 funnyUv = openfl_TextureCoordv;
			vec4 color = flixel_texture2D(bitmap, funnyUv);

			vec4 gf = flixel_texture2D(funnyShit, openfl_TextureCoordv.xy + vec2(0.1, 0.2));

			vec4 mixedCol = blendOverlay(color, gf);
			gl_FragColor = mixedCol;
		}';

	public var funnyX(default, set):Float = 0;
	function set_funnyX(value:Float):Float
	{
		setFloat('xPos', value);
		return funnyX = value;
	}

	public var funnyY(default, set):Float = 0;
	function set_funnyY(value:Float):Float
	{
		setFloat('yPos', value);
		return funnyY = value;
	}

	public function new()
	{
		super('overlayBlend', SOURCE);
		funnyX = 0;
		funnyY = 0;
	}
}

/**
 * Shows another image on the sprite's place, mixed with its own by `amount`. Both have to be laid out the same way (the same atlas, drawn differently).
 */
class TextureSwap extends ErrorHandledRuntimeShader
{
	static inline var SOURCE:String = '
		#pragma header

		uniform sampler2D image;
		uniform float fadeAmount;

		void main()
		{
			vec4 tex = flixel_texture2D(bitmap, openfl_TextureCoordv);
			vec4 tex2 = flixel_texture2D(image, openfl_TextureCoordv);

			vec4 finalColor = mix(tex, vec4(tex2.rgb, tex.a), fadeAmount);

			gl_FragColor = finalColor;
		}';

	public var swappedImage(default, set):BitmapData = null;
	function set_swappedImage(value:BitmapData):BitmapData
	{
		if(value != null) setSampler2D('image', value);
		return swappedImage = value;
	}

	public var amount(default, set):Float = 1;
	function set_amount(value:Float):Float
	{
		setFloat('fadeAmount', value);
		return amount = value;
	}

	public function new()
	{
		super('textureSwap', SOURCE);
		amount = 1;
	}

	/**
	 * Loads the other image from what `Paths.image()` gives for it.
	 */
	public function loadSwapImage(path:Dynamic):Void
	{
		var image:BitmapData = null;
		try
		{
			image = funkin.Assets.getBitmapData(path, false);
		}
		catch(e:Dynamic) {}

		if(image != null) swappedImage = image;
		else trace('The image "$path" of a texture swap shader was not found');
	}
}

/**
 * The ways `WiggleEffectRuntime` can move a sprite. An enum on V-Slice, numbers here: the ones the shader takes.
 */
class VSliceWiggleType
{
	public static var DREAMY:Int = 0;
	public static var WAVY:Int = 1;
	public static var HEAT_WAVE_HORIZONTAL:Int = 2;
	public static var HEAT_WAVE_VERTICAL:Int = 3;
	public static var FLAG:Int = 4;
}

/**
 * Makes a sprite wave. `update()` has to be called every frame for it to move.
 */
class WiggleEffectRuntime extends ErrorHandledRuntimeShader
{
	static var names:Array<String> = ['DREAMY', 'WAVY', 'HEAT_WAVE_HORIZONTAL', 'HEAT_WAVE_VERTICAL', 'FLAG'];

	public static function getEffectTypeId(value:Dynamic):Int
	{
		if(value == null) return 0;
		if(Std.isOfType(value, Int)) return value;
		return Std.int(Math.max(0, names.indexOf(Std.string(value))));
	}

	public var effectType(default, set):Dynamic = 0;
	function set_effectType(value:Dynamic):Dynamic
	{
		setInt('effectType', getEffectTypeId(value));
		return effectType = value;
	}

	public var waveSpeed(default, set):Float = 0;
	function set_waveSpeed(value:Float):Float
	{
		setFloat('uSpeed', value);
		return waveSpeed = value;
	}

	public var waveFrequency(default, set):Float = 0;
	function set_waveFrequency(value:Float):Float
	{
		setFloat('uFrequency', value);
		return waveFrequency = value;
	}

	public var waveAmplitude(default, set):Float = 0;
	function set_waveAmplitude(value:Float):Float
	{
		setFloat('uWaveAmplitude', value);
		return waveAmplitude = value;
	}

	public var time(default, set):Float = 0;
	function set_time(value:Float):Float
	{
		setFloat('uTime', value);
		return time = value;
	}

	public function new(speed:Float = 0, freq:Float = 0, amplitude:Float = 0, ?effect:Dynamic)
	{
		super('wiggle', VSliceShaderSource.get('wiggle'));
		waveSpeed = speed;
		waveFrequency = freq;
		waveAmplitude = amplitude;
		effectType = effect;
		time = 0;
	}

	public function update(elapsed:Float):Void
	{
		time += elapsed;
	}
}

/**
 * V-Slice's base for the shaders that have to know where things are on the screen and on the world: it gives their files the functions for it
 * (`screenToWorld()`, `screenToFrame()`, `sampleBitmapWorld()`...), and is told about the view with `updateViewInfo()`
 * and about the sprite it's on with `updateFrameInfo()`.
 */
class RuntimePostEffectShader extends ErrorHandledRuntimeShader
{
	// The one every shader of the engine has, with the screen coord added. Without flixel's part of it (the alpha and the colors of what's drawn)
	// the shader could only be on a camera: sprites are drawn with those
	static inline var VERTEX_SOURCE:String = '
		#pragma header

		attribute float alpha;
		attribute vec4 colorMultiplier;
		attribute vec4 colorOffset;
		uniform bool hasColorTransform;

		// normalized screen coord
		//   (0, 0) is the top left of the window
		//   (1, 1) is the bottom right of the window
		varying vec2 screenCoord;

		void main(void)
		{
			#pragma body

			openfl_Alphav = openfl_Alpha * alpha;

			if (hasColorTransform)
			{
				openfl_ColorOffsetv = colorOffset / 255.0;
				openfl_ColorMultiplierv = colorMultiplier;
			}

			screenCoord = vec2(
				openfl_TextureCoord.x > 0.0 ? 1.0 : 0.0,
				openfl_TextureCoord.y > 0.0 ? 1.0 : 0.0
			);
		}';

	static inline var FRAGMENT_HEADER:String = '
		// normalized screen coord
		//   (0, 0) is the top left of the window
		//   (1, 1) is the bottom right of the window
		varying vec2 screenCoord;

		// equals (FlxG.width, FlxG.height)
		uniform vec2 uScreenResolution;

		// equals (camera.viewLeft, camera.viewTop, camera.viewRight, camera.viewBottom)
		uniform vec4 uCameraBounds;

		// equals (frame.left, frame.top, frame.right, frame.bottom)
		uniform vec4 uFrameBounds;

		// screen coord -> world coord conversion
		// returns world coord in px
		vec2 screenToWorld(vec2 screenCoord) {
			float left = uCameraBounds.x;
			float top = uCameraBounds.y;
			float right = uCameraBounds.z;
			float bottom = uCameraBounds.w;
			vec2 scale = vec2(right - left, bottom - top);
			vec2 offset = vec2(left, top);
			return screenCoord * scale + offset;
		}

		// world coord -> screen coord conversion
		// returns normalized screen coord
		vec2 worldToScreen(vec2 worldCoord) {
			float left = uCameraBounds.x;
			float top = uCameraBounds.y;
			float right = uCameraBounds.z;
			float bottom = uCameraBounds.w;
			vec2 scale = vec2(right - left, bottom - top);
			vec2 offset = vec2(left, top);
			return (worldCoord - offset) / scale;
		}

		// screen coord -> frame coord conversion
		// returns normalized frame coord
		vec2 screenToFrame(vec2 screenCoord) {
			float left = uFrameBounds.x;
			float top = uFrameBounds.y;
			float right = uFrameBounds.z;
			float bottom = uFrameBounds.w;
			float width = right - left;
			float height = bottom - top;

			float clampedX = clamp(screenCoord.x, left, right);
			float clampedY = clamp(screenCoord.y, top, bottom);

			return vec2(
				(clampedX - left) / (width),
				(clampedY - top) / (height)
			);
		}

		// internally used to get the maximum `openfl_TextureCoordv`
		vec2 bitmapCoordScale() {
			return openfl_TextureCoordv / screenCoord;
		}

		// internally used to compute bitmap coord
		vec2 screenToBitmap(vec2 screenCoord) {
			return screenCoord * bitmapCoordScale();
		}

		// samples the frame buffer using a screen coord
		vec4 sampleBitmapScreen(vec2 screenCoord) {
			return texture2D(bitmap, screenToBitmap(screenCoord));
		}

		// samples the frame buffer using a world coord
		vec4 sampleBitmapWorld(vec2 worldCoord) {
			return sampleBitmapScreen(worldToScreen(worldCoord));
		}
	';

	// What the base gives goes right after the file's own "#pragma header"
	static function withHeader(source:String):String
	{
		if(source == null) return null;

		var pragma:String = '#pragma header';
		var position:Int = source.indexOf(pragma);
		if(position < 0) return pragma + '\n' + FRAGMENT_HEADER + source;
		return source.substr(0, position + pragma.length) + '\n' + FRAGMENT_HEADER + source.substr(position + pragma.length);
	}

	public function new(?name:String = 'postEffect', ?fragmentSource:String)
	{
		super(name, withHeader(fragmentSource), (fragmentSource != null) ? VERTEX_SOURCE : null);
		if(fragmentSource == null) return;

		setFloatArray('uScreenResolution', [FlxG.width, FlxG.height]);
		setFloatArray('uCameraBounds', [0, 0, FlxG.width, FlxG.height]);
		setFloatArray('uFrameBounds', [0, 0, FlxG.width, FlxG.height]);
	}

	// basically `updateViewInfo(FlxG.width, FlxG.height, FlxG.camera)` is good
	public function updateViewInfo(screenWidth:Float, screenHeight:Float, camera:FlxCamera):Void
	{
		if(camera == null) return;

		setFloatArray('uScreenResolution', [screenWidth, screenHeight]);
		setFloatArray('uCameraBounds', [camera.viewLeft, camera.viewTop, camera.viewRight, camera.viewBottom]);
	}

	public function updateFrameInfo(frame:flixel.graphics.frames.FlxFrame):Void
	{
		// (texture atlases have no frame of their own)
		if(frame == null || frame.uv == null) return;

		// the "width" and "height" of a frame's UV are really its right and bottom edges
		setFloatArray('uFrameBounds', [frame.uv.x, frame.uv.y, frame.uv.width, frame.uv.height]);
	}
}

/**
 * V-Slice's rain, the one of its "rain" shader file: put on a camera, or on a single sprite with `spriteMode`.
 * The engine's own `shaders.RainShader` is the one Psych's stages use, made out of an older version of that file.
 */
class RuntimeRainShader extends RuntimePostEffectShader
{
	static inline var MAX_LIGHTS:Int = 8;

	public var lights:Array<{position:openfl.display.ShaderParameter<Float>, color:openfl.display.ShaderParameter<Float>, radius:openfl.display.ShaderParameter<Float>}> = [];

	public var time(default, set):Float = 1;
	function set_time(value:Float):Float
	{
		setFloat('uTime', value);
		return time = value;
	}

	/**
	 * If the shader is on a sprite instead of on a camera: the rain is then placed by the sprite's frame (see `updateFrameInfo()`).
	 */
	public var spriteMode(default, set):Bool = false;
	function set_spriteMode(value:Bool):Bool
	{
		setBool('uSpriteMode', value);
		return spriteMode = value;
	}

	// The size of the raindrops is proportional to this
	public var scale(default, set):Float = 1;
	function set_scale(value:Float):Float
	{
		setFloat('uScale', value);
		return scale = value;
	}

	// From no rain at all (0) to the most there can be (1)
	public var intensity(default, set):Float = 0.5;
	function set_intensity(value:Float):Float
	{
		setFloat('uIntensity', value);
		return intensity = value;
	}

	// the y coord of the puddle, used to mirror things
	public var puddleY(default, set):Float = 0;
	function set_puddleY(value:Float):Float
	{
		setFloat('uPuddleY', value);
		return puddleY = value;
	}

	// the y scale of the puddle, the less this value the more the puddle effects squished
	public var puddleScaleY(default, set):Float = 0;
	function set_puddleScaleY(value:Float):Float
	{
		setFloat('uPuddleScaleY', value);
		return puddleScaleY = value;
	}

	public var blurredScreen(default, set):BitmapData;
	function set_blurredScreen(value:BitmapData):BitmapData
	{
		setSampler2D('uBlurredScreen', value);
		return blurredScreen = value;
	}

	public var mask(default, set):BitmapData;
	function set_mask(value:BitmapData):BitmapData
	{
		setSampler2D('uMask', value);
		return mask = value;
	}

	public var lightMap(default, set):BitmapData;
	function set_lightMap(value:BitmapData):BitmapData
	{
		setSampler2D('uLightMap', value);
		return lightMap = value;
	}

	public var rainColor(default, set):FlxColor;
	function set_rainColor(color:FlxColor):FlxColor
	{
		setFloatArray('uRainColor', [color.red / 255, color.green / 255, color.blue / 255]);
		return rainColor = color;
	}

	public var numLightsSwag(default, set):Int = 0;
	function set_numLightsSwag(value:Int):Int
	{
		setInt('numLights', value);
		return numLightsSwag = value;
	}

	public function new()
	{
		super('rain', VSliceShaderSource.get('rain'));
		rainColor = 0xFF6680CC;
	}

	public function update(elapsed:Float):Void
	{
		time += elapsed;
	}
}

// The small ones: a file of V-Slice's "shaders" folder each, with names for its values

/**
 * Takes the colors out of a sprite, all the way (1) or part of it.
 */
class Grayscale extends ErrorHandledRuntimeShader
{
	public var amount:Float = 1;

	public function new(amount:Float = 1)
	{
		super('grayscale', VSliceShaderSource.get('grayscale'));
		setAmount(amount);
	}

	public function setAmount(value:Float):Void
	{
		amount = value;
		setFloat('_amount', amount);
	}
}

/**
 * Multiplies the hue, the saturation and the brightness of a sprite's colors.
 */
class HSVShader extends ErrorHandledRuntimeShader
{
	public var hue(default, set):Float = 1;
	function set_hue(value:Float):Float
	{
		setFloat('_hue', value);
		return hue = value;
	}

	public var saturation(default, set):Float = 1;
	function set_saturation(value:Float):Float
	{
		setFloat('_sat', value);
		return saturation = value;
	}

	public var value(default, set):Float = 1;
	function set_value(value:Float):Float
	{
		setFloat('_val', value);
		return this.value = value;
	}

	public function new(h:Float = 1, s:Float = 1, v:Float = 1)
	{
		super('hsv', VSliceShaderSource.get('hsv'));
		hue = h;
		saturation = s;
		value = v;
	}
}

/**
 * Makes a sprite out of blocks of a size, like the censoring of something.
 */
class MosaicEffect extends ErrorHandledRuntimeShader
{
	public var blockSize:FlxPoint = FlxPoint.get(1, 1);

	public function new()
	{
		super('mosaic', VSliceShaderSource.get('mosaic'));
		setBlockSize(1, 1);
	}

	public function setBlockSize(w:Float, h:Float):Void
	{
		blockSize.set(w, h);
		setFloatArray('uBlocksize', [w, h]);
	}
}

class InverseDotsShader extends ErrorHandledRuntimeShader
{
	public var amount:Float = 0;

	public function new(amount:Float = 1)
	{
		super('InverseDots', VSliceShaderSource.get('InverseDots'));
		setAmount(amount);
	}

	public function setAmount(value:Float):Void
	{
		amount = value;
		setFloat('_amount', amount);
	}
}

class PuddleShader extends ErrorHandledRuntimeShader
{
	public function new()
	{
		super('puddle', VSliceShaderSource.get('puddle'));
	}
}

/**
 * Blends an image over another the way one of the blend modes does, for the ones the cameras can't do by themselves.
 */
class RuntimeCustomBlendShader extends RuntimePostEffectShader
{
	public var sourceSwag(default, set):BitmapData;
	function set_sourceSwag(value:BitmapData):BitmapData
	{
		if(value != null) setSampler2D('sourceSwag', value);
		return sourceSwag = value;
	}

	public var backgroundSwag(default, set):BitmapData;
	function set_backgroundSwag(value:BitmapData):BitmapData
	{
		if(value != null) setSampler2D('backgroundSwag', value);
		return backgroundSwag = value;
	}

	public var blendSwag(default, set):openfl.display.BlendMode;
	function set_blendSwag(value:openfl.display.BlendMode):openfl.display.BlendMode
	{
		setInt('blendMode', cast value);
		return blendSwag = value;
	}

	public function new()
	{
		super('customBlend', VSliceShaderSource.get('customBlend'));
	}
}
