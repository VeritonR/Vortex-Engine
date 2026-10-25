package shaders;

import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import openfl.display.BitmapData;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

/**
 * V-Slice's recreation of Adobe Animate's drop shadow, which its stages use to light the edges of the characters ("rim lighting").
 * It has the "Adjust Color" filter in it as well (see `AdjustColorShader`).
 * It's what V-Slice scripts get when they import `funkin.graphics.shaders.DropShadowShader`.
 */
class DropShadowShader extends ErrorHandledRuntimeShader
{
	static inline var SOURCE:String = '
		#pragma header

		#ifdef GL_ES
			#ifdef GL_OES_standard_derivatives
				#define HAS_DERIVATIVES
			#endif
		#else
			#if __VERSION__ >= 130
				#define HAS_DERIVATIVES
			#endif
		#endif

		// equals (frame.left, frame.top, frame.right, frame.bottom)
		uniform vec4 uFrameBounds;

		uniform float dist;
		uniform float str;
		uniform float thr;

		uniform float angCos;
		uniform float angSin;

		uniform sampler2D altMask;
		uniform bool useMask;
		uniform float thr2;

		uniform vec3 dropColor;

		uniform mat3 hueMatrix;
		uniform float contrast;
		uniform mat3 saturationMatrix;
		uniform float brightness;

		const vec3 lumaValue = vec3(0.2126, 0.7152, 0.0722);

		vec3 applyHSBCEffect(vec3 color)
		{
			vec3 bh = (brightness + color) * hueMatrix;
			vec3 c = (bh - 0.25) * contrast + 0.25;
			vec3 s = c * saturationMatrix;

			return s;
		}

		float getLumaRGB(vec3 color)
		{
			return dot(color.rgb, lumaValue);
		}

		vec4 getTexRGBA(vec2 uv)
		{
			return texture2D(bitmap, uv);
		}

		// Used as Difference Based AA.
		// Return value range (0.0, 2.0)
		float lwidth_manual(float center, vec2 uv, vec2 px)
		{
			vec3 p2x1 = getTexRGBA(uv + vec2(1.0, 0.0) * px).rgb;
			vec3 p1x2 = getTexRGBA(uv + vec2(0.0, 1.0) * px).rgb;
			vec3 p2x2 = getTexRGBA(uv + vec2(1.0, 1.0) * px).rgb;

			float right = getLumaRGB(p2x1);
			float down = getLumaRGB(p1x2);
			float diagonal = getLumaRGB(p2x2);

			float dx = abs(right - center);
			float dy = abs(down - center);
			float dd = abs(diagonal - center);

			return ((dx + dy + dd * 0.7) / (1.0 + 1.0 + 0.7)) * 2.0;
		}

		float getThreshold(vec2 uv)
		{
			float threshold = thr;
			float maskIntensity = 0.0;

			if (useMask)
			{
				maskIntensity = texture2D(altMask, uv).b;
				if (maskIntensity > 0.0)
					threshold = thr2;
			}

			return threshold;
		}

		vec4 createDropShadowEx(vec2 uv, vec2 ratio, vec2 size)
		{
			vec4 color4 = texture2D(bitmap, uv);

			#ifdef HAS_DERIVATIVES
				// Increase the pixel distance if the screen is smaller than the sprite!
				vec2 px = max(ratio, fwidth(uv));
			#else
				vec2 px = ratio;
			#endif

			float color3_light = getLumaRGB(color4.rgb);

			float delta = lwidth_manual(color3_light, uv, px);

			float threshold = getThreshold(uv);
			float intensity = smoothstep(threshold - delta, threshold + delta, color3_light);

			float shadowAlpha = 0.0;

			vec3 color3_no_effect = color4.a > 0.0 ? color4.rgb / color4.a : color4.rgb;
			vec3 color3 = applyHSBCEffect(color3_no_effect);

			vec2 checked = vec2(
				uv.x + (dist * angCos * ratio.x),
				uv.y - (dist * angSin * ratio.y)
			);

			if (checked.x > uFrameBounds.x &&
				checked.y > uFrameBounds.y &&
				checked.x < uFrameBounds.z &&
				checked.y < uFrameBounds.w)
			{
				shadowAlpha = texture2D(bitmap, checked).a;
			}

			float rim = (1.0 - (shadowAlpha * str)) * intensity;

			color3 += dropColor * rim;

			return vec4(color3 * color4.a, color4.a);
		}

		void main()
		{
			gl_FragColor = createDropShadowEx(openfl_TextureCoordv, 1.0 / openfl_TextureSize.xy, openfl_TextureSize.xy);
		}';

	/**
	 * The color of the light.
	 */
	public var color(default, set):FlxColor = FlxColor.WHITE;
	function set_color(value:FlxColor):FlxColor
	{
		color = value;
		setFloatArray('dropColor', [value.red / 255, value.green / 255, value.blue / 255]);
		return value;
	}

	/**
	 * Where the light comes from, in degrees: 0 is the right, 90 the top, 180 the left and 270 the bottom.
	 */
	public var angle(default, set):Float = 0;
	function set_angle(value:Float):Float
	{
		angle = value;
		updateAngle();
		return value;
	}

	/**
	 * Added to the angle, for frames that are rotated on their image.
	 */
	public var angleOffset(default, set):Float = 0;
	function set_angleOffset(value:Float):Float
	{
		angleOffset = value;
		updateAngle();
		return value;
	}

	/**
	 * How far the light gets into the sprite, in pixels of its image.
	 */
	public var distance(default, set):Float = 15;
	function set_distance(value:Float):Float
	{
		distance = value;
		setFloat('dist', value);
		return value;
	}

	public var strength(default, set):Float = 1;
	function set_strength(value:Float):Float
	{
		strength = value;
		setFloat('str', value);
		return value;
	}

	/**
	 * How bright a part of the image has to be to get the light, from 0 (everything gets it) to 1.
	 */
	public var threshold(default, set):Float = 0.1;
	function set_threshold(value:Float):Float
	{
		threshold = value;
		setFloat('thr', value);
		return value;
	}

	/**
	 * If the parts of the image that are blue on `altMaskImage` use `maskThreshold` instead.
	 */
	public var useAltMask(default, set):Bool = false;
	function set_useAltMask(value:Bool):Bool
	{
		useAltMask = value;
		setBool('useMask', value);
		return value;
	}

	public var altMaskImage(default, set):BitmapData = null;
	function set_altMaskImage(value:BitmapData):BitmapData
	{
		altMaskImage = value;
		if(value != null) setSampler2D('altMask', value);
		return value;
	}

	public var maskThreshold(default, set):Float = 0;
	function set_maskThreshold(value:Float):Float
	{
		maskThreshold = value;
		setFloat('thr2', value);
		return value;
	}

	/**
	 * The sprite that has the shader: the light has to stay inside of the frame it's showing, which is taken from it every time the game is drawn.
	 */
	public var attachedSprite(default, set):FlxSprite = null;
	function set_attachedSprite(value:FlxSprite):FlxSprite
	{
		attachedSprite = value;
		if(value == null)
		{
			attached.remove(this);
			return value;
		}

		// A texture atlas is lit as one image, not piece by piece: it's drawn whole on a texture of its own first
		// (V-Slice's shader turns that on for the sprite it's attached to as well)
		var character:objects.Character = Std.downcast(value, objects.Character);
		if(character != null && character.isAnimateAtlas) character.useRenderTexture = true;
		var sprite:funkin.graphics.FunkinSprite = Std.downcast(value, funkin.graphics.FunkinSprite);
		if(sprite != null && sprite.atlas != null) sprite.useRenderTexture = true;
		var atlas:flxanimate.PsychFlxAnimate = Std.downcast(value, flxanimate.PsychFlxAnimate);
		if(atlas != null) atlas.useRenderTexture = true;

		updateFrameInfo(frameOf(value));
		if(!attached.contains(this)) attached.push(this);
		if(!hooked)
		{
			hooked = true;
			FlxG.signals.preDraw.add(updateAttached);
			FlxG.signals.preStateSwitch.add(function() attached = []);
		}
		return value;
	}

	// The texture atlas a sprite shows, null if it's not one
	static function atlasOf(sprite:FlxSprite):flxanimate.PsychFlxAnimate
	{
		var atlas:flxanimate.PsychFlxAnimate = Std.downcast(sprite, flxanimate.PsychFlxAnimate);
		if(atlas != null) return atlas;

		var character:objects.Character = Std.downcast(sprite, objects.Character);
		if(character != null) return character.isAnimateAtlas ? character.atlas : null;

		var wrapper:funkin.graphics.FunkinSprite = Std.downcast(sprite, funkin.graphics.FunkinSprite);
		return (wrapper != null) ? wrapper.atlas : null;
	}

	// The frame a sprite is showing. For a texture atlas that's the texture it was drawn whole on
	// (its own `frame` is whatever piece of its spritesheet comes first)
	static function frameOf(sprite:FlxSprite):FlxFrame
	{
		var atlas:flxanimate.PsychFlxAnimate = atlasOf(sprite);
		return (atlas != null) ? atlas.wholeFrame : sprite.frame;
	}

	static var attached:Array<DropShadowShader> = [];
	static var hooked:Bool = false;

	static function updateAttached():Void
	{
		var index:Int = attached.length - 1;
		while(index >= 0)
		{
			var shader:DropShadowShader = attached[index];
			var sprite:FlxSprite = shader.attachedSprite;
			if(sprite == null || !sprite.exists) attached.splice(index, 1);
			else shader.updateFrameInfo(frameOf(sprite));
			index--;
		}
	}

	// The "Adjust Color" part

	public var baseHue(default, set):Float = 0;
	function set_baseHue(value:Float):Float
	{
		baseHue = value;
		setFloatArray('hueMatrix', makeHueMatrix(value * FlxAngle.TO_RAD));
		return value;
	}

	public var baseSaturation(default, set):Float = 0;
	function set_baseSaturation(value:Float):Float
	{
		baseSaturation = value;

		var amount:Float = (value > 0) ? value * 3 : value;
		setFloatArray('saturationMatrix', makeSaturationMatrix(1 + (amount / 100)));
		return value;
	}

	public var baseBrightness(default, set):Float = 0;
	function set_baseBrightness(value:Float):Float
	{
		baseBrightness = value;
		setFloat('brightness', value / 255);
		return value;
	}

	public var baseContrast(default, set):Float = 0;
	function set_baseContrast(value:Float):Float
	{
		baseContrast = value;

		var amount:Float = 1 + (value / 100);
		if(amount > 1.0) amount = (((0.00852259 * Math.exp(4.76454 * (amount - 1.0))) * 1.01) - 0.0086078159) * 10.0 + 1.0;
		setFloat('contrast', amount);
		return value;
	}

	public function new()
	{
		super('dropShadow', SOURCE);

		color = FlxColor.WHITE;
		angle = 0;
		angleOffset = 0;
		strength = 1;
		distance = 15;
		threshold = 0.1;
		maskThreshold = 0;
		useAltMask = false;
		setFloatArray('uFrameBounds', [0, 0, 1, 1]);

		baseHue = 0;
		baseSaturation = 0;
		baseBrightness = 0;
		baseContrast = 0;
	}

	/**
	 * Sets the four values of the "Adjust Color" part.
	 */
	public function setAdjustColor(brightness:Float, hue:Float, contrast:Float, saturation:Float):Void
	{
		baseBrightness = brightness;
		baseHue = hue;
		baseContrast = contrast;
		baseSaturation = saturation;
	}

	/**
	 * Loads the image of the mask from the path `Paths` gives for it.
	 */
	public function loadAltMask(path:Dynamic):Void
	{
		// (V-Slice's `Paths.image()` is the path of the image, the one scripts get here is the image itself)
		var image:BitmapData = null;
		if(Std.isOfType(path, BitmapData)) image = path;
		else if(Std.isOfType(path, flixel.graphics.FlxGraphic)) image = cast(path, flixel.graphics.FlxGraphic).bitmap;
		else
		{
			try
			{
				image = funkin.Assets.getBitmapData(Std.string(path), false);
			}
			catch(e:Dynamic) {}
		}

		if(image != null) altMaskImage = image;
		else trace('The mask "$path" of a drop shadow shader was not found');
	}

	/**
	 * What V-Slice scripts give to the sprite's animations to be called on each frame, here the shader keeps up with its sprite by itself.
	 */
	public function onAttachedFrame(?name:String, ?frameNum:Int, ?frameIndex:Int):Void
	{
		if(attachedSprite != null) updateFrameInfo(frameOf(attachedSprite));
	}

	public function updateFrameInfo(frame:FlxFrame):Void
	{
		// (scripts give the frame of the sprite on every frame of its animations, which for a texture atlas is not what's on the screen)
		if(attachedSprite != null && atlasOf(attachedSprite) != null) frame = frameOf(attachedSprite);

		// nothing to keep the light inside of
		if(frame == null || frame.uv == null)
		{
			setFloatArray('uFrameBounds', [0, 0, 1, 1]);
			if(angleOffset != 0) angleOffset = 0;
			return;
		}

		// (the "width" and "height" of a frame's UV are really its right and bottom edges)
		setFloatArray('uFrameBounds', [frame.uv.x, frame.uv.y, frame.uv.width, frame.uv.height]);

		var frameAngle:Float = frame.angle;
		if(frameAngle != angleOffset) angleOffset = frameAngle; //a rotated frame would get the light from the wrong side
	}

	function updateAngle():Void
	{
		var radians:Float = (angle + angleOffset) * FlxAngle.TO_RAD;
		setFloat('angCos', Math.cos(radians));
		setFloat('angSin', Math.sin(radians));
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
		return 'DropShadowShader($angle, $distance, $strength, $threshold)';
	}
}
