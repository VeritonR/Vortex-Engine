package states.editors.content;

/**
 * Mouse controls the editors that show a scene share: the wheel zooms in and out where the mouse is, and the middle button
 * (held and moved) moves the camera around.
 */
class EditorMouse
{
	/**
	 * Returns true if the camera was moved or zoomed.
	 */
	public static function cameraControls(camera:FlxCamera, minZoom:Float, maxZoom:Float):Bool
	{
		var changed:Bool = false;

		#if FLX_MOUSE
		if(FlxG.mouse.wheel != 0)
		{
			// (what's under the mouse stays under it)
			var before:FlxPoint = FlxG.mouse.getWorldPosition(camera);
			var zoom:Float = camera.zoom * Math.pow(1.1, FlxG.mouse.wheel);
			camera.zoom = FlxMath.bound(zoom, minZoom, maxZoom);
			var after:FlxPoint = FlxG.mouse.getWorldPosition(camera);
			camera.scroll.x += before.x - after.x;
			camera.scroll.y += before.y - after.y;
			before.put();
			after.put();
			changed = true;
		}

		#if FLX_MOUSE_ADVANCED
		if(FlxG.mouse.pressedMiddle && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
		{
			camera.scroll.x -= FlxG.mouse.deltaScreenX / camera.zoom;
			camera.scroll.y -= FlxG.mouse.deltaScreenY / camera.zoom;
			changed = true;
		}
		#end
		#end

		return changed;
	}
}
