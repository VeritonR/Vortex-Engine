package shaders;

import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

/**
 * The shader of V-Slice's "sserafim" stage: tints a sprite by the lights of that stage, with the "Adjust Color" filter in it as well.
 * It's what V-Slice scripts get when they import `funkin.graphics.shaders.SserafimShader`.
 */
class SserafimShader extends ErrorHandledRuntimeShader
{
	static inline var SOURCE:String = '
			#pragma header

			// this shader includes a recreation of the Animate/Flash "Adjust Color" filter,
			// which was kindly provided and written by Rozebud https://github.com/ThatRozebudDude ( thank u rozebud :) )
			// Adapted from Andrey-Postelzhuks shader found here: https://forum.unity.com/threads/hue-saturation-brightness-contrast-shader.260649/
			// Hue rotation stuff is from here: https://www.w3.org/TR/filter-effects/#feColorMatrixElement

			uniform float hue;
			uniform float saturation;
			uniform float brightness;
			uniform float contrast;

			uniform float darkAmt;
			uniform vec3 lightColor;
			uniform float pulseStrength;
			uniform float truckStrength;
			uniform bool isChar;

			const vec3 grayscaleValues = vec3(0.3098039215686275, 0.607843137254902, 0.0823529411764706);
		const float e = 2.718281828459045;

		vec3 applyHueRotate(vec3 aColor, float aHue){
		 float angle = radians(aHue);

		 mat3 m1 = mat3(0.213, 0.213, 0.213, 0.715, 0.715, 0.715, 0.072, 0.072, 0.072);
		 mat3 m2 = mat3(0.787, -0.213, -0.213, -0.715, 0.285, -0.715, -0.072, -0.072, 0.928);
		 mat3 m3 = mat3(-0.213, 0.143, -0.787, -0.715, 0.140, 0.715, 0.928, -0.283, 0.072);
		 mat3 m = m1 + cos(angle) * m2 + sin(angle) * m3;

		 return m * aColor;
		}

		vec3 applySaturation(vec3 aColor, float value){
		 if(value > 0.0){ value = value * 3.0; }
		 value = (1.0 + (value / 100.0));
		 vec3 grayscale = vec3(dot(aColor, grayscaleValues));
				return clamp(mix(grayscale, aColor, value), 0.0, 1.0);
		}

		vec3 applyContrast(vec3 aColor, float value){
		 value = (1.0 + (value / 100.0));
		 if(value > 1.0){
			value = (((0.00852259 * pow(e, 4.76454 * (value - 1.0))) * 1.01) - 0.0086078159) * 10.0; //Just roll with it...
			value += 1.0;
		 }
				return clamp((aColor - 0.25) * value + 0.25, 0.0, 1.0);
		}

			vec3 applyHSBCEffect(vec3 color){

		 //Brightness
		 color = color + ((brightness) / 255.0);

		 //Hue
		 color = applyHueRotate(color, hue);

		 //Contrast
		 color = applyContrast(color, contrast);

		 //Saturation
				color = applySaturation(color, saturation);

				return color;
			}

			#define saturate(v) clamp(v,0.,1.)

			vec3 hue2rgb(float hue){
			 hue=fract(hue);
			 return saturate(vec3(
				abs(hue*6.-3.)-1.,
				2.-abs(hue*6.-2.),
				2.-abs(hue*6.-4.)
			 ));
			}

			vec3 rgb2hsl(vec3 c){
			 float cMin=min(min(c.r,c.g),c.b),
			 cMax=max(max(c.r,c.g),c.b),
			 delta=cMax-cMin;
			 vec3 hsl=vec3(0.,0.,(cMax+cMin)/2.);
			 if(delta!=0.0){ //If it has chroma and isnt gray.
				if(hsl.z<.5){
				 hsl.y=delta/(cMax+cMin); //Saturation.
				}else{
				 hsl.y=delta/(2.-cMax-cMin); //Saturation.
			}
			float deltaR=(((cMax-c.r)/6.)+(delta/2.))/delta,
				deltaG=(((cMax-c.g)/6.)+(delta/2.))/delta,
				deltaB=(((cMax-c.b)/6.)+(delta/2.))/delta;
			//Hue.
			if(c.r==cMax){
			 hsl.x=deltaB-deltaG;
			}else if(c.g==cMax){
			 hsl.x=(1./3.)+deltaR-deltaB;
			}else{ //if(c.b==cMax){
			 hsl.x=(2./3.)+deltaG-deltaR;
			}
				hsl.x=fract(hsl.x);
			 }
			 return hsl;
			}

			vec3 hsl2rgb(vec3 hsl){
			 if(hsl.y==0.){
				return vec3(hsl.z); //Luminance.
			 }else{
				float b;
				if(hsl.z<.5){
				 b=hsl.z*(1.+hsl.y);
				}else{
				 b=hsl.z+hsl.y-hsl.y*hsl.z;
				}
				float a=2.*hsl.z-b;
				return a+hue2rgb(hsl.x)*(b-a);
			 }
			}

			// controls how much to brighten/darken depending on combinedAlpha.
			const float lightMultiplier = 0.07;

			void main()
			{
				vec4 col = texture2D(bitmap, openfl_TextureCoordv);

				vec3 unpremultipliedColor = col.a > 0.0 ? col.rgb / col.a : col.rgb;

				vec3 outColor = applyHSBCEffect(unpremultipliedColor);

				// truckLight1.alpha + backLightColor.alpha
				float combinedAlpha = truckStrength + pulseStrength;

				float darkFactor = (combinedAlpha*lightMultiplier) + darkAmt;
				if(darkAmt > 0.65) darkFactor = (combinedAlpha*(-1.0 * lightMultiplier)) + darkAmt;

				// interpolate between white and black depending on darkness
				vec3 multiplyColor;

				vec3 bruhColor = lightColor;
				bruhColor = rgb2hsl(bruhColor);
				bruhColor.b = bruhColor.b * pulseStrength;
				bruhColor = hsl2rgb(bruhColor);

				if(isChar == true){
					multiplyColor = mix(vec3(1.0, 1.0, 1.0), vec3(0.0, 0.0, 0.0), darkFactor/5.0);

					//multiplyColor = mix(multiplyColor, lightColor * vec3(pulseStrength), darkFactor/3.0);

					multiplyColor = mix(multiplyColor, bruhColor, darkFactor/3.0);
				}else{
					multiplyColor = mix(vec3(1.0, 1.0, 1.0), vec3(0.0, 0.0, 0.0), darkFactor);

					//multiplyColor = mix(multiplyColor, lightColor * vec3(pulseStrength), darkFactor/2.0);

					multiplyColor = mix(multiplyColor, bruhColor, darkFactor/2.0);
				}

				outColor *= multiplyColor;

				gl_FragColor = vec4(outColor.rgb * col.a, col.a);
			}';

	/**
	 * How dark the stage is, from 0 to 1. Characters take it differently.
	 */
	public var darkenAmount(default, set):Float = 0;
	function set_darkenAmount(value:Float):Float
	{
		setFloat('darkAmt', value);
		return darkenAmount = value;
	}

	/**
	 * Color of the light behind the truck, and how strong it is.
	 */
	public var pulseLightColor(default, set):FlxColor = FlxColor.WHITE;
	function set_pulseLightColor(value:FlxColor):FlxColor
	{
		setFloatArray('lightColor', [value.red / 255, value.green / 255, value.blue / 255]);
		return pulseLightColor = value;
	}

	public var pulseLightStrength(default, set):Float = 0;
	function set_pulseLightStrength(value:Float):Float
	{
		setFloat('pulseStrength', value);
		return pulseLightStrength = value;
	}

	/**
	 * How strong the lights of the truck are.
	 */
	public var truckLightStrength(default, set):Float = 0;
	function set_truckLightStrength(value:Float):Float
	{
		setFloat('truckStrength', value);
		return truckLightStrength = value;
	}

	/**
	 * If it's on a character, which get more out of the lights.
	 */
	public var isCharacter(default, set):Bool = false;
	function set_isCharacter(value:Bool):Bool
	{
		setBool('isChar', value);
		return isCharacter = value;
	}

	// The "Adjust Color" part, these go to the shader as they are

	public var baseHue(default, set):Float = 0;
	function set_baseHue(value:Float):Float
	{
		setFloat('hue', value);
		return baseHue = value;
	}

	public var baseSaturation(default, set):Float = 0;
	function set_baseSaturation(value:Float):Float
	{
		setFloat('saturation', value);
		return baseSaturation = value;
	}

	public var baseBrightness(default, set):Float = 0;
	function set_baseBrightness(value:Float):Float
	{
		setFloat('brightness', value);
		return baseBrightness = value;
	}

	public var baseContrast(default, set):Float = 0;
	function set_baseContrast(value:Float):Float
	{
		setFloat('contrast', value);
		return baseContrast = value;
	}

	public function new(char:Bool = false)
	{
		super('sserafim', SOURCE);

		darkenAmount = 0;
		pulseLightColor = FlxColor.WHITE;
		pulseLightStrength = 0;
		truckLightStrength = 0;
		isCharacter = char;

		baseHue = 0;
		baseSaturation = 0;
		baseBrightness = 0;
		baseContrast = 0;
	}

	public function setAdjustColor(brightness:Float, hue:Float, contrast:Float, saturation:Float):Void
	{
		baseBrightness = brightness;
		baseHue = hue;
		baseContrast = contrast;
		baseSaturation = saturation;
	}
}
