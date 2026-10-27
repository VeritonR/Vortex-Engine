package backend;

import flixel.FlxCamera;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxRect;
import flixel.math.FlxMatrix;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.OpenGLRenderer;
import openfl.display.Shape;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;

/**
 * Blend modes the game can't draw by itself (overlay, hard light, difference, invert), done the way V-Slice's cameras do them
 * (`funkin.graphics.FunkinCamera`, with its "customBlend" shader): what's blended is drawn on a camera of its own (`layerFor()`),
 * then that and what the camera it goes on had so far are put on textures, mixed by the shader and drawn back on it as one picture.
 */
@:access(openfl.display.BitmapData)
@:access(openfl.display.OpenGLRenderer)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.geom.ColorTransform)
@:access(flixel.FlxCamera)
@:access(openfl.display3D.textures.TextureBase)
class CameraBlend
{
	/**
	 * The ones done here, by their number in `openfl.display.BlendMode`.
	 */
	public static final MODES:Array<Int> = [3, 5, 6, 11];

	public static function supports(mode:Int):Bool
	{
		return FlxG.renderTile && MODES.contains(mode) && shaderCode() != null;
	}

	// ------------------------------------------------------------------------------------------
	// The cameras the blended things are drawn on
	// ------------------------------------------------------------------------------------------

	static var layers:haxe.ds.ObjectMap<FlxCamera, FlxCamera> = null;
	static var copies:haxe.ds.ObjectMap<FlxCamera, FlxCamera> = null;

	/**
	 * A camera that sees the same as `camera` (its size, zoom and scroll), empty, to draw what's blended on it.
	 */
	public static function layerFor(camera:FlxCamera):FlxCamera
	{
		if(layers == null)
		{
			layers = new haxe.ds.ObjectMap();
			copies = new haxe.ds.ObjectMap();
			FlxG.signals.preStateSwitch.add(clear);
		}
		return mirror(camera, layers);
	}

	static function mirror(camera:FlxCamera, cameras:haxe.ds.ObjectMap<FlxCamera, FlxCamera>):FlxCamera
	{
		// (made with the camera's own starting zoom: where a camera's corner is depends on it, and a mirror made at another one put the
		// copy of what's behind somewhere else than what's blended on a zoomed camera, a square of the wrong picture around it)
		var layer:FlxCamera = cameras.get(camera);
		if(layer != null && layer.initialZoom != camera.initialZoom)
		{
			cameras.remove(camera);
			layer.destroy();
			layer = null;
		}
		if(layer == null)
		{
			layer = new FlxCamera(0, 0, camera.width, camera.height, camera.initialZoom);
			layer.bgColor = 0;
			cameras.set(camera, layer);
		}
		if(layer.width != camera.width || layer.height != camera.height) layer.setSize(camera.width, camera.height);
		layer.zoom = camera.zoom;
		layer.scroll.copyFrom(camera.scroll);
		layer.pixelPerfectRender = camera.pixelPerfectRender;
		layer.antialiasing = camera.antialiasing;
		layer.clearDrawStack();
		layer.canvas.graphics.clear();
		return layer;
	}

	static function clear():Void
	{
		if(layers == null) return;
		for (layer in layers) layer.destroy();
		for (copy in copies) copy.destroy();
		layers = new haxe.ds.ObjectMap();
		copies = new haxe.ds.ObjectMap();
	}

	// ------------------------------------------------------------------------------------------
	// Mixing them
	// ------------------------------------------------------------------------------------------

	// The textures of each time something was blended on this frame: what's drawn reads them until the frame is shown, so the next
	// one can't use them again (it'd be drawing on a texture that's being read)
	static var textures:Array<BlendTextures> = [];
	static var texturesUsed:Int = 0;
	static var countingFrames:Bool = false;

	/**
	 * Puts what was drawn on `layer` on `camera`, blended with what's on it so far.
	 *
	 * Only the area of what's blended is mixed: that part of the camera is put on a texture, mixed with what's blended by the shader
	 * and drawn over it again (where nothing is blended the mix is the camera itself, which is left as it was).
	 */
	public static function blend(camera:FlxCamera, layer:FlxCamera, mode:Int):Void
	{
		if(shaderCode() == null || layer._headOfDrawStack == null) return;

		if(!countingFrames)
		{
			countingFrames = true;
			FlxG.signals.preDraw.add(function() texturesUsed = 0);
		}

		// at the size the window shows the camera at, not to lose any detail
		var scaleX:Float = FlxG.scaleMode.scale.x;
		var scaleY:Float = FlxG.scaleMode.scale.y;
		var cameraWidth:Float = camera.width * scaleX;
		var cameraHeight:Float = camera.height * scaleY;

		// where what's blended is on the camera, in the window's pixels from the camera's corner
		layer.render();
		layer.flashSprite.__update(false, true);
		var bounds = layer.canvas.getBounds(layer.flashSprite);
		var left:Int = Std.int(Math.max(0, Math.floor(bounds.x + layer._flashOffset.x) - 2));
		var top:Int = Std.int(Math.max(0, Math.floor(bounds.y + layer._flashOffset.y) - 2));
		var right:Int = Std.int(Math.min(Math.ceil(cameraWidth), Math.ceil(bounds.right + layer._flashOffset.x) + 2));
		var bottom:Int = Std.int(Math.min(Math.ceil(cameraHeight), Math.ceil(bounds.bottom + layer._flashOffset.y) + 2));
		var width:Int = right - left;
		var height:Int = bottom - top;
		if(width < 1 || height < 1)
		{
			layer.clearDrawStack();
			layer.canvas.graphics.clear();
			return;
		}

		var set:BlendTextures = textures[texturesUsed];
		if(set == null || set.width < width || set.height < height)
		{
			if(set != null) set.dispose();
			// (a bit bigger than needed, not to make them again each time what's blended grows a little)
			set = new BlendTextures(Std.int(Math.ceil(width / 128) * 128), Std.int(Math.ceil(height / 128) * 128));
			if(set.background == null || set.source == null)
			{
				set.dispose();
				return;
			}
			textures[texturesUsed] = set;
		}
		texturesUsed++;

		// What the camera has so far, drawn again on a camera of its own (the camera's own drawing is left alone, it's done at the end of
		// the frame like always, with the blend going over that area after it)
		var copy:FlxCamera = mirror(camera, copies);
		copy.fill(camera.bgColor.to24Bit(), camera.useBgAlphaBlending, camera.bgColor.alphaFloat);
		var item = camera._headOfDrawStack;
		while(item != null)
		{
			item.render(copy);
			item = item.next;
		}
		capture(copy, set.background, left, top);
		copy.canvas.graphics.clear();
		capture(layer, set.source, left, top);
		layer.clearDrawStack();
		layer.canvas.graphics.clear();

		var shader:shaders.ErrorHandledShader.ErrorHandledRuntimeShader = set.shader;
		// (both: OpenFL gives the samplers after one with nothing set the wrong texture unit)
		shader.setSampler2D('sourceSwag', set.source);
		shader.setSampler2D('backgroundSwag', set.background);
		shader.setInt('blendMode', mode);

		var frame:FlxFrame = set.graphic.imageFrame.frame;
		frame.frame = new FlxRect(0, 0, width, height);
		frame.sourceSize.set(width, height);

		// from the texture's pixels to the camera's view: the window's scale and the zoom undone, from where the view starts
		var matrix:FlxMatrix = new FlxMatrix();
		matrix.scale(1 / (camera.scaleX * scaleX), 1 / (camera.scaleY * scaleY));
		matrix.translate(0.5 * camera.width * (1 - camera.initialZoom / camera.scaleX) + left / (camera.scaleX * scaleX),
			0.5 * camera.height * (1 - camera.initialZoom / camera.scaleY) + top / (camera.scaleY * scaleY));
		camera.drawPixels(frame, null, matrix, null, null, camera.antialiasing, shader);
	}

	// ------------------------------------------------------------------------------------------
	// Drawing a camera on a texture (V-Slice's `BitmapDataUtil.drawCameraScreen()`)
	// ------------------------------------------------------------------------------------------

	static var _renderer:OpenGLRenderer = null;

	// Draws what was drawn on the camera so far (`render()` already done) on a texture, from that point of it in the window's pixels
	static function capture(camera:FlxCamera, target:BitmapData, left:Float, top:Float):Void
	{
		if(_renderer == null)
		{
			_renderer = new OpenGLRenderer(FlxG.stage.context3D);
			_renderer.__worldTransform = new Matrix();
			_renderer.__worldColorTransform = new ColorTransform();
		}
		var renderer:OpenGLRenderer = _renderer;

		// (a new texture has nothing to draw on until something was drawn on it once)
		if(target.__texture != null && target.__texture.__glFramebuffer == null)
		{
			renderer.__setRenderTarget(target);
			target.__drawGL(new Shape(), renderer);
		}
		target.__fillRect(target.rect, 0, true);

		camera.flashSprite.__update(false, true);

		// the camera's middle is where its sprite is, half the camera away from its corner
		var matrix:Matrix = new Matrix(1, 0, 0, 1, camera._flashOffset.x - left, camera._flashOffset.y - top);

		renderer.__cleanup();
		renderer.setShader(renderer.__defaultShader);
		renderer.__allowSmoothing = camera.antialiasing;
		renderer.__pixelRatio = Lib.current.stage.window.scale;
		renderer.__worldAlpha = 1 / camera.flashSprite.__worldAlpha;
		renderer.__worldTransform.copyFrom(camera.flashSprite.__renderTransform);
		renderer.__worldTransform.invert();
		renderer.__worldTransform.concat(matrix);
		renderer.__worldColorTransform.__copyFrom(camera.flashSprite.__worldColorTransform);
		renderer.__worldColorTransform.__invert();
		renderer.__setRenderTarget(target);
		target.__drawGL(camera.canvas, renderer);

		// each renderer remembers what it last set on the graphics context and skips setting it again (see `PsychFlxAnimate.renderFilter()`)
		forgetState(renderer);
		forgetState(Std.downcast(FlxG.stage.__renderer, OpenGLRenderer));
	}

	static function forgetState(target:OpenGLRenderer):Void
	{
		if(target == null) return;
		target.__blendMode = null;
		target.__currentShader = null;
		target.__currentShaderBuffer = null;
		target.__currentGraphicsShader = null;
		target.__currentDisplayShader = null;
	}

	// ------------------------------------------------------------------------------------------
	// The shader: V-Slice's, with the picture of what's blended as the one it's drawing
	// ------------------------------------------------------------------------------------------

	static var _shaderCode:String = null;
	static var shaderMissing:Bool = false;

	// (each blend of a frame has a shader of its own: OpenFL only reads what textures a shader has when the frame is shown)
	@:allow(backend.BlendTextures)
	static function shaderCode():String
	{
		if(_shaderCode != null || shaderMissing) return _shaderCode;

		var code:String = shaders.VSliceShaders.VSliceShaderSource.get('customBlend');
		if(code == null || code.indexOf('screenCoord') < 0)
		{
			shaderMissing = true;
			return null;
		}

		// (V-Slice's samples what's blended where it is on the screen, here it's the picture being drawn: the same place)
		code = code.split('flixel_texture2D(sourceSwag, screenCoord)').join('flixel_texture2D(bitmap, openfl_TextureCoordv)');
		_shaderCode = code;
		return _shaderCode;
	}
}

/**
 * The two textures a blend is made with: what the camera had, and what's blended on it (also as a graphic, to be drawn).
 */
private class BlendTextures
{
	public var width:Int;
	public var height:Int;
	public var background:BitmapData;
	public var source:BitmapData;
	public var graphic:FlxGraphic;
	public var shader:shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

	public function new(width:Int, height:Int)
	{
		this.width = width;
		this.height = height;
		background = make(width, height);
		source = make(width, height);
		if(source == null) return;

		graphic = FlxGraphic.fromBitmapData(source, false, null, false);
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		shader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader('customBlend', CameraBlend.shaderCode());
	}

	static function make(width:Int, height:Int):BitmapData
	{
		var context = FlxG.stage.context3D;
		if(context == null) return null;
		return BitmapData.fromTexture(context.createRectangleTexture(width, height, BGRA, true));
	}

	public function dispose():Void
	{
		if(graphic != null)
		{
			graphic.persist = false;
			graphic.destroy();
			graphic = null;
		}
		for (texture in [background, source])
			if(texture != null) texture.dispose();
		background = source = null;
	}
}
