package backend;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
#end

/**
 * Vortex Engine: a whole camera turned in 3D (Lua: setCamera3D / tweenCamera3D). What the camera shows is drawn as a card turned
 * forward/back (angleX) and left/right (angleY) and pushed away (z), seen in perspective, the same way `Perspective3D` turns
 * sprites. Turning the HUD's camera tilts the receptors and the notes together, like the 3D modcharts.
 *
 * It's a shader on the camera, so it needs the Shaders option on (nothing changes with it off).
 */
class Camera3D
{
	static final SOURCE:String = '
		#pragma header
		uniform float angleX;
		uniform float angleY;
		uniform float depthZ;
		uniform float eye;
		uniform vec2 viewSize;

		void main()
		{
			// the point of the screen this pixel is, in pixels from its center
			vec2 screen = (openfl_TextureCoordv - 0.5) * viewSize;
			float ax = radians(angleX);
			float ay = radians(angleY);
			// the sides of the turned card (turned forward/back first, then left/right, like the sprites)
			vec3 sideX = vec3(cos(ay), 0.0, -sin(ay));
			vec3 sideY = vec3(sin(ax) * sin(ay), cos(ax), sin(ax) * cos(ay));
			vec3 normal = cross(sideX, sideY);
			vec3 center = vec3(0.0, 0.0, depthZ);
			vec3 eyePos = vec3(0.0, 0.0, -eye);
			vec3 ray = vec3(screen, 0.0) - eyePos;

			float facing = dot(normal, ray);
			if (abs(facing) < 0.0001) { gl_FragColor = vec4(0.0); return; }
			float t = dot(normal, center - eyePos) / facing;
			if (t <= 0.0) { gl_FragColor = vec4(0.0); return; }

			vec3 hit = eyePos + ray * t - center;
			vec2 uv = vec2(dot(hit, sideX), dot(hit, sideY)) / viewSize + 0.5;
			if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { gl_FragColor = vec4(0.0); return; }
			gl_FragColor = flixel_texture2D(bitmap, uv);
		}
	';

	static var states:Map<FlxCamera, Camera3DState> = [];
	static var listening:Bool = false;

	/**
	 * Turns a camera. All zero puts it back as it was (the shader is taken off). False if shaders are off.
	 */
	public static function set(camera:FlxCamera, angleX:Float, angleY:Float, z:Float):Bool
	{
		#if (!flash && sys)
		if(camera == null) return false;
		if(!listening)
		{
			listening = true;
			FlxG.signals.preStateSwitch.add(function() states.clear());
		}

		var state:Camera3DState = states.get(camera);
		if(state == null)
		{
			state = new Camera3DState();
			states.set(camera, state);
		}
		state.angleX = angleX;
		state.angleY = angleY;
		state.z = z;

		var turned:Bool = Perspective3D.isTurned(angleX, angleY, z);
		if(!turned || !ClientPrefs.data.shaders)
		{
			if(state.filter != null) takeOff(camera, state);
			return turned ? false : true;
		}

		if(state.filter == null)
		{
			state.shader = new FlxRuntimeShader(SOURCE);
			state.filter = new ShaderFilter(state.shader);
			var filters:Array<BitmapFilter> = (camera.filters != null) ? camera.filters.copy() : [];
			filters.push(state.filter);
			camera.filters = filters;
		}
		state.shader.setFloat('angleX', angleX);
		state.shader.setFloat('angleY', angleY);
		state.shader.setFloat('depthZ', z);
		state.shader.setFloat('eye', Perspective3D.eyeDistance);
		state.shader.setFloatArray('viewSize', [camera.width, camera.height]);
		return true;
		#else
		return false;
		#end
	}

	/**
	 * Turns a camera like another one (the long notes' cameras follow the HUD's, see `states.PlayState.copyHudCamera()`).
	 */
	public static function copy(from:FlxCamera, to:FlxCamera):Void
	{
		var source:Camera3DState = (from != null) ? states.get(from) : null;
		var target:Camera3DState = (to != null) ? states.get(to) : null;
		if(source == null && target == null) return;
		var values:Array<Float> = get(from);
		if(target != null && target.angleX == values[0] && target.angleY == values[1] && target.z == values[2]) return;
		set(to, values[0], values[1], values[2]);
	}

	/** [angleX, angleY, z] of a camera, zeros if it isn't turned. */
	public static function get(camera:FlxCamera):Array<Float>
	{
		var state:Camera3DState = (camera != null) ? states.get(camera) : null;
		return (state != null) ? [state.angleX, state.angleY, state.z] : [0, 0, 0];
	}

	#if (!flash && sys)
	static function takeOff(camera:FlxCamera, state:Camera3DState):Void
	{
		if(camera.filters != null)
			camera.filters = [for (filter in camera.filters) if(filter != state.filter) filter];
		state.filter = null;
		state.shader = null;
	}
	#end
}

private class Camera3DState
{
	public var angleX:Float = 0;
	public var angleY:Float = 0;
	public var z:Float = 0;
	#if (!flash && sys)
	public var shader:FlxRuntimeShader;
	public var filter:ShaderFilter;
	#end

	public function new() {}
}
