package backend;

import flixel.FlxCamera;
import openfl.geom.Rectangle;

/**
 * Keeps a camera covered while it's turned (`camera.angle`).
 *
 * Flixel cuts what a camera draws to its own rectangle and only draws what's inside of that rectangle, and the turning happens after
 * that, to the cut picture: the corners of the camera were left empty, showing its background (or the cameras under it).
 * While a camera is turned, the cut and what's drawn grow just enough for the turned picture to still cover all of the camera,
 * what's around the view is shown in the corners instead. It's what scripts like "zCameraFix" did on older versions of flixel.
 */
class RotatedCameras
{
	static var installed:Bool = false;

	// cameras that have the bigger cut right now, to give them back their own once they aren't turned
	static var grown:Array<FlxCamera> = [];

	public static function install():Void
	{
		if(installed || !FlxG.renderTile) return;
		installed = true;

		// (before the cameras are cleared and filled with their background, and before anything is drawn)
		FlxG.signals.preDraw.add(beforeDraw);
		// (what the cameras tell about their view goes back to normal for the game's logic, what was drawn is kept)
		FlxG.signals.postDraw.add(afterDraw);
	}

	static function beforeDraw():Void
	{
		var index:Int = grown.length;
		while(--index >= 0)
		{
			var camera:FlxCamera = grown[index];
			if(camera == null || camera.flashSprite == null || !FlxG.cameras.list.contains(camera))
			{
				grown.splice(index, 1);
			}
			else if(!isTurned(camera))
			{
				grown.splice(index, 1);
				@:privateAccess camera.updateScrollRect();
			}
		}

		for (camera in FlxG.cameras.list)
			if(camera != null && camera.exists && camera.visible && camera.flashSprite != null && isTurned(camera))
				grow(camera);
	}

	static function afterDraw():Void
	{
		for (camera in grown)
		{
			@:privateAccess
			{
				camera.calcMarginX();
				camera.calcMarginY();
			}
		}
	}

	inline static function isTurned(camera:FlxCamera):Bool
	{
		// (turned upside down it's still covered, turned sideways it isn't: the camera isn't a square)
		return Math.abs(camera.flashSprite.rotation % 180) > 0.001;
	}

	static function grow(camera:FlxCamera):Void
	{
		// how much bigger the camera's rectangle has to be for it to still cover the camera when it's turned that much
		var radians:Float = camera.flashSprite.rotation * Math.PI / 180;
		var cos:Float = Math.abs(Math.cos(radians));
		var sin:Float = Math.abs(Math.sin(radians));
		var halfWidth:Float = camera.width / 2;
		var halfHeight:Float = camera.height / 2;
		var extraX:Float = (halfWidth * cos + halfHeight * sin) - halfWidth;
		var extraY:Float = (halfWidth * sin + halfHeight * cos) - halfHeight;

		@:privateAccess
		{
			// what's drawn: the view, in the units of the world, which the camera's zoom changes
			camera.calcMarginX();
			camera.calcMarginY();
			camera.viewMarginX -= extraX / camera.scaleX * camera.initialZoom;
			camera.viewMarginY -= extraY / camera.scaleY * camera.initialZoom;

			// where it's cut, on the screen
			var rect:Rectangle = (camera._scrollRect != null) ? camera._scrollRect.scrollRect : null;
			if(rect == null) return;

			var screenX:Float = extraX * camera.initialZoom * FlxG.scaleMode.scale.x;
			var screenY:Float = extraY * camera.initialZoom * FlxG.scaleMode.scale.y;
			var width:Float = camera.width * camera.initialZoom * FlxG.scaleMode.scale.x;
			var height:Float = camera.height * camera.initialZoom * FlxG.scaleMode.scale.y;
			rect.setTo(-screenX, -screenY, width + screenX * 2, height + screenY * 2);
			camera._scrollRect.scrollRect = rect;
			camera._scrollRect.x = -0.5 * width - screenX;
			camera._scrollRect.y = -0.5 * height - screenY;
		}

		if(!grown.contains(camera)) grown.push(camera);
	}
}
