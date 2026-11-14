package backend;

import lime._internal.graphics.ImageDataUtil;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import openfl.display.BitmapData;

/**
 * The "Texture Quality" option (Graphics): big images are sent to the GPU at half their size. The game still sees them at their own
 * size (frames, hitboxes and scripts don't change): only the texture the GPU draws from is smaller, which is read in proportion to it.
 * Less video memory and less of it to go through on every frame, which is what holds weak phones back.
 *
 * Small images (icons, the HUD, most pixel art) keep their size.
 *
 * And whatever the option, an image bigger than the graphics card can take (4096 pixels on a lot of cheap phones, where the base
 * game's Boyfriend is 8192) is sent at the biggest size it takes: otherwise it's black, or not there at all.
 */
class TextureQuality
{
	public static final OPTIONS:Array<String> = ['Full', 'Half'];

	// images with fewer pixels than this are left as they are (1024x1024)
	static inline final MIN_PIXELS:Int = 1024 * 1024;

	static var maxSize:Int = -1;

	/**
	 * A smaller limit for a test (the test tool's "--maxtexture=4096"): to see the game as a phone with that graphics card shows it.
	 */
	public static var testLimit:Int = 0;

	/**
	 * The biggest texture the graphics card takes (0 if it isn't known yet).
	 */
	public static function maxTextureSize():Int
	{
		if(maxSize > 0 && testLimit <= 0) return maxSize;
		#if (lime_opengl || lime_opengles)
		if(maxSize <= 0 && FlxG.stage != null && FlxG.stage.context3D != null)
		{
			try
			{
				var size:Dynamic = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.MAX_TEXTURE_SIZE);
				if(size != null && size > 0) maxSize = Std.int(size);
			}
			catch(e:Dynamic) {}
		}
		#end
		if(testLimit > 0) return (maxSize > 0) ? Std.int(Math.min(maxSize, testLimit)) : testLimit;
		return (maxSize > 0) ? maxSize : 0;
	}

	/**
	 * Sends a big image to the GPU at half its size, if the option asks for it. Its copy in the RAM is let go then, like GPU Caching does
	 * (it would be sent again whole if it was changed). True if it was done.
	 */
	@:access(openfl.display.BitmapData)
	@:access(openfl.display3D.textures.TextureBase)
	@:access(openfl.display3D.Context3D)
	public static function lighten(bitmap:BitmapData):Bool
	{
		if(bitmap == null) return false;

		var image:Image = bitmap.image;
		var context = FlxG.stage.context3D;
		if(image == null || image.buffer == null || image.data == null || context == null || bitmap.__texture != null) return false;

		var half:Bool = ClientPrefs.data.textureQuality == 'Half' && image.width * image.height >= MIN_PIXELS;
		var limit:Int = maxTextureSize();
		var tooBig:Bool = limit > 0 && (image.width > limit || image.height > limit);
		if(!half && !tooBig) return false;

		try
		{
			var factor:Float = half ? 2 : 1;
			if(tooBig) factor = Math.max(factor, Math.max(image.width, image.height) / limit);
			var width:Int = Std.int(Math.max(1, Math.min(limit > 0 ? limit : 99999, Math.ceil(image.width / factor))));
			var height:Int = Std.int(Math.max(1, Math.min(limit > 0 ? limit : 99999, Math.ceil(image.height / factor))));

			// (a buffer of its own over the same pixels: resizing replaces its data, the image's own stays as it was)
			var source:ImageBuffer = image.buffer;
			var copy:ImageBuffer = new ImageBuffer(source.data, source.width, source.height, source.bitsPerPixel, source.format);
			copy.premultiplied = source.premultiplied;
			copy.transparent = source.transparent;
			var small:Image = new Image(copy);
			ImageDataUtil.resize(small, width, height);
			if(small.transparent && !small.premultiplied) small.premultiplied = true;

			var texture = context.createRectangleTexture(width, height, BGRA, false);
			texture.__uploadFromImage(small);

			bitmap.lock();
			bitmap.__texture = texture;
			bitmap.__textureContext = context.__context;
			bitmap.__textureVersion = image.version;
			// (the size things are measured against stays the image's own: what's drawn is read in proportion from the smaller texture)
			bitmap.__textureWidth = bitmap.width;
			bitmap.__textureHeight = bitmap.height;

			bitmap.getSurface();
			bitmap.disposeImage();
			if(bitmap.image != null)
			{
				bitmap.image.data = null;
				bitmap.image = null;
			}
			bitmap.readable = true;
			return true;
		}
		catch(e:Dynamic)
		{
			trace('Texture Quality: the image stays whole, $e');
		}
		return false;
	}
}
