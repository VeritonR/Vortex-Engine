package psychlua;

class ModchartSprite extends FlxSprite
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	/**
	 * For the sprites of V-Slice stages: an animation's offsets are scaled along with the sprite and go on top of the ones its
	 * hitbox gives it, instead of replacing them (V-Slice's `Bopper.getScreenPosition()`).
	 */
	public var vsliceOffsets:Bool = false;
	var hitboxOffset:FlxPoint = null;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public function playAnim(name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
	{
		animation.play(name, forced, reverse, startFrame);
		applyAnimOffset(name);
	}

	function applyAnimOffset(name:String)
	{
		var daOffset = animOffsets.get(name);
		if(!vsliceOffsets)
		{
			if (animOffsets.exists(name)) offset.set(daOffset[0], daOffset[1]);
			return;
		}

		if(hitboxOffset == null) hitboxOffset = FlxPoint.get(offset.x, offset.y);
		offset.set(hitboxOffset.x, hitboxOffset.y);
		if(daOffset != null) offset.add(daOffset[0] * scale.x, daOffset[1] * scale.y);
	}

	/**
	 * Overlay, hard light, difference and invert are blend modes the game can't draw by itself: they're done like on V-Slice's
	 * cameras (`backend.CameraBlend`), drawn on a camera of their own first and then mixed with what's under them.
	 */
	/**
	 * If those blend modes are done (see `draw()`). On for the sprites Lua scripts make, the ones it was made for: the props of
	 * V-Slice stages are sprites of this class too, and one with "hardlight" (Hazier Hiver's alleyway) made the whole stage black.
	 * HScript can turn it on for its own.
	 */
	public var cameraBlends:Bool = false;

	override function draw()
	{
		var mode:Int = (blend != null && cameraBlends) ? cast blend : -1;
		if(mode < 0 || !backend.CameraBlend.supports(mode))
		{
			super.draw();
			return;
		}

		@:privateAccess var keptCameras:Array<FlxCamera> = _cameras;
		var keptBlend = blend;
		var layers:Array<{camera:FlxCamera, layer:FlxCamera}> = [];
		for (camera in cameras)
			if(camera != null && camera.visible && camera.exists)
				layers.push({camera: camera, layer: backend.CameraBlend.layerFor(camera)});

		blend = null;
		cameras = [for (pair in layers) pair.layer];
		super.draw();
		@:privateAccess _cameras = keptCameras;
		blend = keptBlend;

		for (pair in layers)
			backend.CameraBlend.blend(pair.camera, pair.layer, mode);
	}

	override function updateHitbox()
	{
		super.updateHitbox();
		if(!vsliceOffsets) return;

		// (the offsets the new size gives it are the ones the animations' go on top of)
		if(hitboxOffset == null) hitboxOffset = FlxPoint.get();
		hitboxOffset.set(offset.x, offset.y);
		if(animation.curAnim != null) applyAnimOffset(animation.curAnim.name);
	}

	public function addOffset(name:String, x:Float, y:Float)
	{
		animOffsets.set(name, [x, y]);
	}

	override function destroy()
	{
		hitboxOffset = flixel.util.FlxDestroyUtil.put(hitboxOffset);
		super.destroy();
	}
}
