package backend;

import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxFrame.FlxFrameType;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;

using flixel.util.FlxColorTransformUtil;

/**
 * Vortex Engine: sprites turned in 3D. A sprite with `angleX` (turned forward/back), `angleY` (turned left/right) or `z` (pushed
 * away from the screen, or toward it with a negative number) is drawn as a flat card in 3D, seen in perspective from the center of
 * the screen. Lua sprites, receptors and notes have these (setProperty('mySprite.angleY', 45),
 * setPropertyFromGroup('playerStrums', 0, 'z', 300)); `angle` still turns it on the screen as always.
 *
 * It's drawn with two triangles, so it works with any camera, shader, color and blend the sprite has. Frames that a texture
 * packer stored turned on their side are drawn flat (the rare atlases that do that).
 */
@:access(flixel.FlxSprite)
class Perspective3D
{
	/**
	 * How far the eye is from the screen, in pixels: smaller is a stronger perspective. With 1000, something at z = 1000 looks
	 * half its size. Scripts can change it (getPropertyFromClass('backend.Perspective3D', 'eyeDistance')).
	 */
	public static var eyeDistance:Float = 1000;

	// (made once and filled again for each sprite: a card is always 4 corners and the same 2 triangles)
	static var vertices:DrawData<Float> = new DrawData<Float>(8, true);
	static var uvs:DrawData<Float> = new DrawData<Float>(8, true);
	static var indices:DrawData<Int> = {
		var list:DrawData<Int> = new DrawData<Int>(6, true);
		list[0] = 0; list[1] = 1; list[2] = 2;
		list[3] = 1; list[4] = 3; list[5] = 2;
		list;
	};
	// (white: flixel wants colors for the corners whenever a sprite's color is changed, even if it only uses its transform)
	static var colors:DrawData<Int> = {
		var list:DrawData<Int> = new DrawData<Int>(4, true);
		for (i in 0...4) list[i] = 0xFFFFFFFF;
		list;
	};

	/**
	 * If triangles flixel would draw on that camera are on it, with flixel's own test (`FlxDrawTrianglesItem.addTriangles()`).
	 * The ones it finds off the camera have to be skipped before: flixel drops their corners but keeps their color, and from then on
	 * every triangle drawn after them in the same batch gets the color of another (a model's leaves in its trunk's brown).
	 */
	public static function onCamera(points:DrawData<Float>, camera:FlxCamera):Bool
	{
		var left:Float = points[0], right:Float = points[0];
		var top:Float = points[1], bottom:Float = points[1];
		var i:Int = 2;
		while(i < points.length)
		{
			if(points[i] < left) left = points[i];
			if(points[i] > right) right = points[i];
			if(points[i + 1] < top) top = points[i + 1];
			if(points[i + 1] > bottom) bottom = points[i + 1];
			i += 2;
		}
		return right > 0 && left < camera.width && bottom > 0 && top < camera.height;
	}

	/**
	 * Makes the next triangles of that camera start a batch of their own. Flixel 5.6.1 puts calls of the same texture together, and
	 * on each one gives the colors and the alpha again for every triangle the batch already has (`numTriangles` there is the batch's,
	 * not the call's): from the second call on every triangle got another one's color (a model's trunk in its leaves' green, notes
	 * turned in 3D with the alpha of another). A batch with only one call is right.
	 */
	public static function freshBatch(camera:FlxCamera, graphic:flixel.graphics.FlxGraphic, smoothing:Bool, blend:openfl.display.BlendMode,
		transform:openfl.geom.ColorTransform, shader:flixel.system.FlxAssets.FlxShader):Void
	{
		// (a new one, linked after what was drawn before, with what drawTriangles() is going to ask for: it takes this one as it is.
		// Colors are always given for the corners, so it's a colored one)
		if(!FlxG.renderTile) return;
		camera.getNewDrawTrianglesItem(graphic, smoothing, true, blend, transform != null && transform.hasRGBAOffsets(), shader);
	}

	public static inline function isTurned(angleX:Float, angleY:Float, z:Float):Bool
		return angleX != 0 || angleY != 0 || z != 0;

	/**
	 * Draws the sprite turned in 3D on each of its cameras. False when it can't be (the caller draws it the usual way).
	 */
	public static function draw(sprite:FlxSprite, angleX:Float, angleY:Float, z:Float):Bool
	{
		var frame:FlxFrame = sprite._frame;
		if(frame == null || sprite.graphic == null) return false;
		if(frame.angle != FlxFrameAngle.ANGLE_0) return false;
		if(sprite.alpha == 0 || frame.type == FlxFrameType.EMPTY) return true;

		// The 4 corners of what's drawn, from the sprite's origin, as FlxSprite places them (trimmed frames, flips, scale)
		var flipX:Bool = (sprite.flipX != frame.flipX);
		var flipY:Bool = (sprite.flipY != frame.flipY);
		var width:Float = frame.frame.width;
		var height:Float = frame.frame.height;
		var left:Float = flipX ? sprite.frameWidth - frame.offset.x - width : frame.offset.x;
		var top:Float = flipY ? sprite.frameHeight - frame.offset.y - height : frame.offset.y;
		left -= sprite.origin.x;
		top -= sprite.origin.y;

		var uvLeft:Float = frame.uv.x;
		var uvTop:Float = frame.uv.y;
		var uvRight:Float = frame.uv.width;
		var uvBottom:Float = frame.uv.height;
		if(flipX) { var swap:Float = uvLeft; uvLeft = uvRight; uvRight = swap; }
		if(flipY) { var swap:Float = uvTop; uvTop = uvBottom; uvBottom = swap; }
		uvs[0] = uvLeft;  uvs[1] = uvTop;
		uvs[2] = uvRight; uvs[3] = uvTop;
		uvs[4] = uvLeft;  uvs[5] = uvBottom;
		uvs[6] = uvRight; uvs[7] = uvBottom;

		var radZ:Float = sprite.angle * Math.PI / 180;
		var radX:Float = angleX * Math.PI / 180;
		var radY:Float = angleY * Math.PI / 180;
		var cosZ:Float = Math.cos(radZ), sinZ:Float = Math.sin(radZ);
		var cosX:Float = Math.cos(radX), sinX:Float = Math.sin(radX);
		var cosY:Float = Math.cos(radY), sinY:Float = Math.sin(radY);

		for (camera in sprite.cameras)
		{
			if(camera == null || !camera.visible || !camera.exists) continue;

			// where the origin is on this camera's screen (what FlxSprite.drawComplex() starts from)
			sprite.getScreenPosition(sprite._point, camera).subtractPoint(sprite.offset);
			var originX:Float = sprite._point.x + sprite.origin.x;
			var originY:Float = sprite._point.y + sprite.origin.y;
			var centerX:Float = camera.width / 2;
			var centerY:Float = camera.height / 2;

			var behind:Bool = false;
			for (i in 0...4)
			{
				var px:Float = (left + ((i & 1) == 1 ? width : 0)) * sprite.scale.x;
				var py:Float = (top + ((i & 2) == 2 ? height : 0)) * sprite.scale.y;

				// turned on the screen (angle), then forward/back (X), then left/right (Y)
				var x1:Float = px * cosZ - py * sinZ;
				var y1:Float = px * sinZ + py * cosZ;
				var y2:Float = y1 * cosX;
				var z2:Float = y1 * sinX;
				var x3:Float = x1 * cosY + z2 * sinY;
				var z3:Float = -x1 * sinY + z2 * cosY;

				// seen from the eye, in front of the center of the screen
				var depth:Float = eyeDistance + z + z3;
				if(depth <= 1) { behind = true; break; }
				var scale:Float = eyeDistance / depth;
				vertices[i * 2] = centerX + (originX + x3 - centerX) * scale;
				vertices[i * 2 + 1] = centerY + (originY + y2 - centerY) * scale;
			}
			if(behind) continue; //(it went behind the eye: nothing to see)
			if(!onCamera(vertices, camera)) continue; //(off the camera: see onCamera())
			freshBatch(camera, sprite.graphic, sprite.antialiasing, sprite.blend, sprite.colorTransform, sprite.shader);

			sprite._point.set(0, 0);
camera.drawTriangles(sprite.graphic, vertices, indices, uvs, colors, sprite._point, sprite.blend, false, sprite.antialiasing, sprite.colorTransform, sprite.shader);
		}
		return true;
	}
}
