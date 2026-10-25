package objects.freeplay;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flxanimate.data.AnimationData.Loop;

/**
 * Texture atlas with named animations, made out of the frame labels of its main timeline or out of its symbols.
 * It also tells when an animation ends or changes frame, which the library doesn't do reliably by itself.
 */
class FreeplayAtlas extends FlxAnimate
{
	public var loaded(default, null):Bool = false;
	public var curAnim(default, null):String = null;
	public var animFinished(default, null):Bool = true;

	/**
	 * Called when an animation ends, or every time it starts over if it's a looped one.
	 */
	public var onAnimFinish:String->Void = null;

	/**
	 * Called with the animation's name and its new frame, counting from the animation's first one.
	 */
	public var onFrameChange:String->Int->Void = null;

	var curLooped:Bool = false;
	var lastFrame:Int = -1;
	var finishTimer:Float = -1;

	public function new(x:Float, y:Float, key:String)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;
		if(key == null || key.length < 1) return;

		try
		{
			Paths.loadAnimateAtlas(this, key);
			loaded = (anim.curInstance != null && anim.curSymbol != null);
		}
		catch(e:Dynamic)
		{
			trace('Could not load the atlas "$key": $e');
		}
	}

	public function hasAnim(name:String):Bool
	{
		@:privateAccess
		return loaded && anim.animsMap.exists(name);
	}

	/**
	 * Adds an animation out of a frame label of the main timeline, returns false if the atlas doesn't have it.
	 */
	public function addLabelAnim(name:String, label:String):Bool
	{
		if(!loaded || !getLabels().contains(label)) return false;
		return addAnimByFrameLabel(name, label);
	}

	/**
	 * Adds an animation out of a symbol, drawn with the symbol's origin on the sprite's position.
	 */
	public function addSymbolAnim(name:String, symbol:String):Bool
	{
		if(!loaded || !anim.symbolDictionary.exists(symbol)) return false;

		anim.addBySymbol(name, symbol + '\\', 0, true); //the slash makes the library look for that exact name
		return hasAnim(name);
	}

	/**
	 * Frame labels of the main timeline.
	 */
	public function getLabels():Array<String>
	{
		if(!loaded || anim.stageInstance == null) return [];

		var mainSymbol = anim.symbolDictionary.get(anim.stageInstance.symbol.name);
		return (mainSymbol != null) ? mainSymbol.getFrameLabelNames() : [];
	}

	/**
	 * Frame where a label of a symbol's own timeline starts, -1 if it doesn't exist.
	 */
	public function getSymbolLabelFrame(symbol:String, label:String):Int
	{
		if(!loaded) return -1;

		var symbolData = anim.symbolDictionary.get(symbol);
		if(symbolData == null || !symbolData.getFrameLabelNames().contains(label)) return -1;

		var keyFrame = symbolData.getFrameLabel(label);
		return (keyFrame != null) ? keyFrame.index : -1;
	}

	/**
	 * Returns false if there's no animation with that name.
	 */
	public function playAnim(name:String, looped:Bool = false, frame:Int = 0):Bool
	{
		if(!hasAnim(name)) return false;

		anim.play(name, true, false, 0);
		anim.loopType = looped ? Loop : PlayOnce;
		if(frame > 0) anim.curFrame = frame;

		curAnim = name;
		curLooped = looped;
		animFinished = false;
		finishTimer = -1;
		lastFrame = anim.curFrame;

		// what's drawn comes from the last update, without this the next draw would still show the previous animation
		anim.update(0);
		return true;
	}

	var replacedSizes:Map<String, FlxPoint> = [];

	/**
	 * Swaps the image of a symbol made of a single sprite for another graphic, stretched to take the same space.
	 * Returns false if the atlas doesn't have that symbol.
	 */
	public function replaceSymbolGraphic(symbol:String, graphic:FlxGraphic):Bool
	{
		if(!loaded || graphic == null || frames == null) return false;

		var symbolData = anim.symbolDictionary.get(symbol);
		if(symbolData == null) return false;

		// the sprite the symbol shows
		var spriteName:String = null;
		for (layer in symbolData.timeline.getList())
		{
			var keyFrame = layer.get(0);
			if(keyFrame == null) continue;

			for (element in keyFrame.getList())
			{
				if(element.bitmap == null) continue;

				spriteName = element.bitmap;
				break;
			}
			if(spriteName != null) break;
		}

		var frame:FlxFrame = (spriteName != null) ? frames.getByName(spriteName) : null;
		if(frame == null) return false;

		if(!replacedSizes.exists(spriteName)) replacedSizes.set(spriteName, FlxPoint.get(frame.frame.width, frame.frame.height));
		var size:FlxPoint = replacedSizes.get(spriteName);

		graphic.imageFrame.frame.copyTo(frame);
		frame.name = spriteName;
		@:privateAccess
		{
			frame.tileMatrix[0] = size.x / frame.frame.width;
			frame.tileMatrix[3] = size.y / frame.frame.height;
		}
		return true;
	}

	/**
	 * Plays the atlas' main timeline as a whole, like it's on the stage of the file it was made on.
	 */
	public function playMain(looped:Bool = false, frame:Int = 0):Void
	{
		if(!loaded) return;

		anim.curInstance = anim.stageInstance;
		anim.play('', true, false, 0);
		anim.loopType = looped ? Loop : PlayOnce;
		if(frame > 0) anim.curFrame = frame;

		curAnim = null;
		anim.update(0);
	}

	/**
	 * Frame of the current animation, counting from its first one.
	 */
	public function getAnimFrame():Int
	{
		return loaded ? anim.curFrame : 0;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(!loaded || curAnim == null) return;

		var name:String = curAnim;
		var frame:Int = anim.curFrame;
		if(frame != lastFrame)
		{
			var startedOver:Bool = (curLooped && frame < lastFrame);
			lastFrame = frame;

			if(onFrameChange != null) onFrameChange(name, frame);
			if(startedOver && curAnim == name && onAnimFinish != null) onAnimFinish(name);
		}

		// the callbacks above could have played something else
		if(curAnim != name || curLooped || animFinished || !anim.finished) return;

		// the last frame has to stay on screen for as long as the others
		if(finishTimer < 0) finishTimer = (anim.framerate > 0) ? 1 / anim.framerate : 0;
		else finishTimer -= elapsed;

		if(finishTimer <= 0)
		{
			animFinished = true;
			if(onAnimFinish != null) onAnimFinish(name);
		}
	}
}
