package objects;

import flixel.math.FlxMatrix;
import flxanimate.animate.FlxElement;
import flxanimate.animate.FlxSymbol;
import flxanimate.data.AnimationData.Loop;
import flxanimate.data.AnimationData.SymbolT;

/**
 * A list of functions to call when something happens, like the ones V-Slice's sprites have (`onFinish.add(...)`).
 */
class AtlasSignal
{
	var handlers:Array<Dynamic> = [];
	var once:Array<Dynamic> = [];

	public function new() {}

	public function add(handler:Dynamic):Void
	{
		if(handler != null && !handlers.contains(handler)) handlers.push(handler);
	}

	/**
	 * Adds a function that's only called the next time, and taken out after it.
	 */
	public function addOnce(handler:Dynamic):Void
	{
		add(handler);
		if(handler != null && !once.contains(handler)) once.push(handler);
	}

	public function has(handler:Dynamic):Bool
	{
		return handlers.contains(handler);
	}

	public function remove(handler:Dynamic):Void
	{
		handlers.remove(handler);
		once.remove(handler);
	}

	public function removeAll():Void
	{
		handlers = [];
		once = [];
	}

	public function dispatch(args:Array<Dynamic>):Void
	{
		for (handler in handlers.copy())
		{
			if(!handlers.contains(handler)) continue; //taken out by one of the others
			if(once.remove(handler)) handlers.remove(handler);
			Reflect.callMethod(null, handler, args);
		}
	}
}

// An animation a script added under a name of its own: the library's animation it plays, and the frame of the main timeline it starts at
typedef AtlasAddedAnim =
{
	var real:String;
	var start:Int;
	var looped:Bool;
}

/**
 * A texture atlas that's placed and played the way V-Slice does it, for the things that are made for it:
 *
 * - Its position is the top left corner of everything its main timeline shows, instead of the timeline's own origin,
 *   and it's scaled and rotated around the middle of that.
 * - Animations are the frame labels of the main timeline ("" being the whole timeline), played through `player`,
 *   which tells when they change frame, reach a label or end.
 */
class AtlasSprite extends FlxAnimate
{
	static inline var MAIN:String = '__main__';

	public var loaded(default, null):Bool = false;

	/**
	 * V-Slice's "applyStageMatrix" setting. An atlas is exported from something that was placed somewhere on its Adobe Animate file:
	 * with this the sprite's position is that file's own corner, and the art is drawn as far from it as it was there.
	 * Without it (the default) the position is the top left corner of the art itself.
	 */
	public var applyStageMatrix(default, null):Bool = false;

	/**
	 * Layer, for whoever sorts it among other things.
	 */
	public var zIndex:Int = 0;

	/**
	 * Plays the atlas' animations. V-Slice scripts know it as the sprite's `anim` and `animation`.
	 */
	public var player(default, null):AtlasPlayer;

	// What the main timeline shows from its first frame to its last one, on the timeline's own coordinates
	var boundsX:Float = 0;
	var boundsY:Float = 0;
	var boundsWidth:Float = 0;
	var boundsHeight:Float = 0;

	var mainName:String = null;
	var mainLength:Int = 0;

	/**
	 * Name of the atlas' main symbol, the one its whole timeline belongs to.
	 */
	public var defaultSymbol(get, never):String;
	function get_defaultSymbol():String return (loaded && mainName != null) ? mainName : '';
	var labelStarts:Map<String, Int> = [];
	var labelLengths:Map<String, Int> = [];
	var labelsAt:Map<Int, String> = [];

	public function new(x:Float = 0, y:Float = 0, ?key:String)
	{
		super(x, y);
		antialiasing = ClientPrefs.data.antialiasing;
		player = new AtlasPlayer(this);
		if(key != null && key.length > 0) loadTextureAtlas(key);
	}

	/**
	 * Loads an atlas from its folder inside of the images one. The other arguments are what V-Slice takes there, which isn't needed here.
	 */
	public function loadTextureAtlas(key:String, ?library:String, ?settings:Dynamic):AtlasSprite
	{
		loaded = false;
		applyStageMatrix = (settings != null && Reflect.field(settings, 'applyStageMatrix') == true);

		var colon:Int = key.indexOf(':');
		if(colon > -1) key = key.substr(colon + 1);

		try
		{
			Paths.loadAnimateAtlas(this, key);
			loaded = (anim.stageInstance != null && anim.symbolDictionary != null && anim.symbolDictionary.exists(anim.stageInstance.symbol.name));
		}
		catch(e:Dynamic)
		{
			trace('Could not load the atlas "$key": $e');
		}
		if(!loaded) return this;

		mainName = anim.stageInstance.symbol.name;
		var main:FlxSymbol = anim.symbolDictionary.get(mainName);
		mainLength = main.length;

		// the labels of the main timeline, and how long each one lasts
		labelStarts = [];
		labelLengths = [];
		labelsAt = [];
		for (label in main.getFrameLabelNames())
		{
			var keyFrame = main.getFrameLabel(label);
			if(keyFrame == null || labelStarts.exists(label)) continue; //the first one with a name is the one that's played

			labelStarts.set(label, keyFrame.index);
			labelLengths.set(label, keyFrame.duration);

			// (asked for without the spaces some have at the end, like V-Slice's library takes them)
			var trimmed:String = label.rtrim();
			if(trimmed != label && !labelStarts.exists(trimmed))
			{
				labelStarts.set(trimmed, keyFrame.index);
				labelLengths.set(trimmed, keyFrame.duration);
			}
		}
		for (layer in main.timeline.getList())
		{
			@:privateAccess
			for (keyFrame in layer._keyframes)
				if(keyFrame.name != null && keyFrame.name.length > 0 && !labelsAt.exists(keyFrame.index))
					labelsAt.set(keyFrame.index, keyFrame.name);
		}

		// the whole timeline as an animation of its own, without what the file does to it when it's put on its stage
		anim.addBySymbolIndices(MAIN, mainName, [for (i in 0...mainLength) i], 0, false);
		useStageMatrix(MAIN);

		computeBounds();
		if(applyStageMatrix)
		{
			// scaled and rotated around the file's corner, which is where the sprite is
			origin.set(0, 0);
			offset.set(0, 0);
		}
		else
		{
			origin.set(boundsX + boundsWidth / 2, boundsY + boundsHeight / 2);
			offset.set(boundsX, boundsY);
		}
		width = boundsWidth;
		height = boundsHeight;

		// flipped, the art is mirrored inside of the box
		flipWidth = boundsX * 2 + boundsWidth;
		flipHeight = boundsY * 2 + boundsHeight;

		// Before anything is played it shows the first frame of its timeline, still, like V-Slice's atlases do (A-Bot's eyes are
		// only played when the camera moves: they weren't there until then). Nothing counts as being played yet
		anim.play(MAIN, true, false, 0);
		anim.pause();

		player.reset();
		return this;
	}

	/**
	 * What was found on the atlas, for when something about it looks wrong.
	 */
	public function describe():String
	{
		if(!loaded) return 'not loaded';
		return 'main symbol "$mainName" with $mainLength frames, labels: ' + [for (label => start in labelStarts) '$label@$start'].join(', ')
			+ ', bounds: x ' + Math.round(boundsX) + ' y ' + Math.round(boundsY) + ' width ' + Math.round(boundsWidth) + ' height ' + Math.round(boundsHeight);
	}

	// ------------------------------------------------------------------------------------------
	// Bounds
	// ------------------------------------------------------------------------------------------

	// One of the library's animations gets the placement the atlas has on its file, when that's wanted
	@:allow(objects.AtlasPlayer)
	function useStageMatrix(animName:String):Void
	{
		if(!applyStageMatrix || anim.stageInstance == null || anim.stageInstance.matrix == null) return;

		@:privateAccess
		var added = anim.animsMap.get(animName);
		if(added != null && added.instance != null && added.instance.matrix != null)
			added.instance.matrix.copyFrom(anim.stageInstance.matrix);
	}

	function computeBounds():Void
	{
		var bounds:Array<Float> = [Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY];
		var identity:FlxMatrix = new FlxMatrix();
		if(applyStageMatrix && anim.stageInstance != null && anim.stageInstance.matrix != null) identity.copyFrom(anim.stageInstance.matrix);
		for (frame in 0...mainLength)
			addFrameBounds(mainName, frame, identity, bounds, 0);

		if(bounds[0] > bounds[2] || bounds[1] > bounds[3]) bounds = [0, 0, 0, 0]; //nothing on it

		boundsX = bounds[0];
		boundsY = bounds[1];
		boundsWidth = bounds[2] - bounds[0];
		boundsHeight = bounds[3] - bounds[1];
	}

	// ------------------------------------------------------------------------------------------
	// For V-Slice scripts
	// ------------------------------------------------------------------------------------------

	/**
	 * Every place a symbol is put on the atlas' timelines.
	 */
	public function getSymbolElements(symbolName:String):Array<FlxElement>
	{
		var found:Array<FlxElement> = [];
		if(!loaded) return found;

		for (symbol in anim.symbolDictionary)
		{
			for (layer in symbol.timeline.getList())
			{
				@:privateAccess
				for (keyFrame in layer._keyframes)
					for (element in keyFrame.getList())
						if(element.symbol != null && element.symbol.name == symbolName)
							found.push(element);
			}
		}
		return found;
	}

	public function getFirstElement(symbolName:String):FlxElement
	{
		var elements:Array<FlxElement> = getSymbolElements(symbolName);
		return (elements.length > 0) ? elements[0] : null;
	}

	/**
	 * Makes something of the atlas bigger, like V-Slice does to the things that are small on the file to save space.
	 */
	public function scaleElement(element:FlxElement, scale:Float, positionOffset:Float = 0, scaleEverything:Bool = false):Void
	{
		if(element == null || element.matrix == null) return;

		if(scaleEverything)
		{
			element.matrix.scale(scale, scale);
			return;
		}

		var pivotX:Float = (element.symbol != null && element.symbol.transformationPoint != null) ? element.symbol.transformationPoint.x : 0;
		var pivotY:Float = (element.symbol != null && element.symbol.transformationPoint != null) ? element.symbol.transformationPoint.y : 0;

		element.matrix.a += scale;
		element.matrix.d += scale;
		element.matrix.tx -= pivotX * scale + positionOffset;
		element.matrix.ty -= pivotY * scale + positionOffset;
	}

	/**
	 * Makes a symbol take the whole sprite and then some, wherever it's put on the main timeline.
	 * For the flashes of V-Slice's atlases: a tiny square on the file, that its scripts stretch over the screen.
	 */
	public function stretchSymbol(symbolName:String, margin:Float = 0.5):Void
	{
		if(!loaded || !anim.symbolDictionary.exists(symbolName)) return;

		var own:Array<Float> = [Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY];
		addFrameBounds(symbolName, 0, new FlxMatrix(), own, 0);
		if(own[0] >= own[2] || own[1] >= own[3]) return;

		var targetX:Float = boundsX - boundsWidth * margin;
		var targetY:Float = boundsY - boundsHeight * margin;
		var scaleX:Float = boundsWidth * (1 + margin * 2) / (own[2] - own[0]);
		var scaleY:Float = boundsHeight * (1 + margin * 2) / (own[3] - own[1]);

		var main:FlxSymbol = anim.symbolDictionary.get(mainName);
		for (layer in main.timeline.getList())
		{
			@:privateAccess
			for (keyFrame in layer._keyframes)
				for (element in keyFrame.getList())
					if(element.symbol != null && element.symbol.name == symbolName && element.matrix != null)
						element.matrix.setTo(scaleX, 0, 0, scaleY, targetX - own[0] * scaleX, targetY - own[1] * scaleY);
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(loaded) player.update(elapsed);
	}

	override function destroy():Void
	{
		if(player != null) player.destroy();
		super.destroy();
	}
}

/**
 * Plays the animations of an `AtlasSprite` with the functions and the signals V-Slice's sprites have.
 */
@:access(objects.AtlasSprite)
class AtlasPlayer
{
	/**
	 * Called with the animation's name and its frame every time the frame changes.
	 */
	public var onFrameChange(default, null):AtlasSignal = new AtlasSignal();

	/**
	 * Called with the name of the frame label the main timeline got to.
	 */
	public var onFrameLabel(default, null):AtlasSignal = new AtlasSignal();

	/**
	 * Called with the animation's name when it ends, looped ones don't.
	 */
	public var onFinish(default, null):AtlasSignal = new AtlasSignal();

	/**
	 * Called with the animation's name every time a looped one starts over.
	 */
	public var onLoop(default, null):AtlasSignal = new AtlasSignal();

	/**
	 * Name of the animation being played: a frame label, or the name of the atlas' main symbol when it's the whole timeline.
	 */
	public var name(default, null):String = '';
	var requested:String = '';

	public var finished(default, null):Bool = true;
	public var paused(default, null):Bool = false;

	/**
	 * If the animation starts over when it gets to its end.
	 */
	public var looped(default, set):Bool = false;

	// To scripts the animation being played is an object of its own: `anim.curAnim.looped = true`
	public var curAnim(get, never):AtlasPlayer;
	function get_curAnim():AtlasPlayer return started ? this : null;

	public var curFrame(get, set):Int;
	function get_curFrame():Int return sprite.loaded ? sprite.anim.curFrame : 0;
	function set_curFrame(value:Int):Int
	{
		if(sprite.loaded)
		{
			if(sprite.anim.curFrame != value)
			{
				sprite.anim.curFrame = value;
				sprite.anim.update(0); //what's drawn comes from the last update, and whoever sets the frames by hand may not be updating the sprite
			}
			lastFrame = sprite.anim.curFrame;
		}
		return value;
	}

	public var isPlaying(get, never):Bool;
	function get_isPlaying():Bool return started && !paused && !finished;

	public var numFrames(get, never):Int;
	function get_numFrames():Int return (sprite.loaded && started) ? sprite.anim.length : 0;

	// Frame of the main timeline that's being shown
	public var frameIndex(get, never):Int;
	function get_frameIndex():Int return startFrame + curFrame;

	public var hasAnimateAtlas(get, never):Bool;
	function get_hasAnimateAtlas():Bool return sprite.loaded;

	// Animations scripts added by name, see addBySymbol() and the others
	var added:Map<String, AtlasAddedAnim> = [];

	var sprite:AtlasSprite;
	var started:Bool = false;
	var startFrame:Int = 0; //of the main timeline, where the animation being played starts
	var lastFrame:Int = -1;
	var finishTimer:Float = -1;
	var plays:Int = 0;

	public function new(sprite:AtlasSprite)
	{
		this.sprite = sprite;
	}

	@:allow(objects.AtlasSprite)
	function reset():Void
	{
		started = false;
		finished = true;
		paused = false;
		name = '';
		requested = '';
		added = [];
	}

	public function exists(animName:String):Bool
	{
		if(!sprite.loaded) return false;
		return animName == null || animName == '' || animName == sprite.mainName || added.exists(animName) || sprite.labelStarts.exists(animName)
			|| sprite.anim.symbolDictionary.exists(animName);
	}

	// ------------------------------------------------------------------------------------------
	// Animations added by name, like V-Slice's sprites do. They're played at the atlas' own speed.
	// ------------------------------------------------------------------------------------------

	/**
	 * Adds one of the atlas' symbols as an animation. Its main one (see `AtlasSprite.defaultSymbol`) is the whole timeline.
	 */
	public function addBySymbol(animName:String, symbol:String, frameRate:Float = 0, looped:Bool = false, flipX:Bool = false, flipY:Bool = false):Void
	{
		if(!sprite.loaded || animName == null) return;

		if(symbol == null || symbol == '' || symbol == sprite.mainName)
		{
			added.set(animName, {real: AtlasSprite.MAIN, start: 0, looped: looped});
			return;
		}
		if(!sprite.anim.symbolDictionary.exists(symbol)) return;

		var realName:String = 'added_$animName';
		sprite.anim.addBySymbol(realName, flxanimate.PsychFlxAnimate.symbolQuery(sprite.anim, symbol), 0, false);
		sprite.useStageMatrix(realName);
		added.set(animName, {real: realName, start: 0, looped: looped});
	}

	/**
	 * Adds a frame label of the main timeline as an animation with another name.
	 */
	public function addByFrameLabel(animName:String, label:String, frameRate:Float = 0, looped:Bool = false, flipX:Bool = false, flipY:Bool = false):Void
	{
		if(!sprite.loaded || animName == null || label == null || !sprite.labelStarts.exists(label)) return;

		added.set(animName, {real: makeLabel(label), start: sprite.labelStarts.get(label), looped: looped});
	}

	/**
	 * Adds some of the frames of a symbol as an animation.
	 */
	public function addBySymbolIndices(animName:String, symbol:String, indices:Array<Int>, frameRate:Float = 0, looped:Bool = false, flipX:Bool = false,
		flipY:Bool = false):Void
	{
		if(!sprite.loaded || animName == null || indices == null || indices.length < 1) return;
		if(symbol == null || symbol == '') symbol = sprite.mainName;
		if(!sprite.anim.symbolDictionary.exists(symbol)) return;

		var realName:String = 'added_$animName';
		sprite.anim.addBySymbolIndices(realName, symbol, indices, 0, false);
		sprite.useStageMatrix(realName);
		added.set(animName, {real: realName, start: (symbol == sprite.mainName) ? indices[0] : 0, looped: looped});
	}

	/**
	 * Adds some of the frames of a frame label as an animation.
	 */
	public function addByFrameLabelIndices(animName:String, label:String, indices:Array<Int>, frameRate:Float = 0, looped:Bool = false, flipX:Bool = false,
		flipY:Bool = false):Void
	{
		if(!sprite.loaded || label == null || indices == null || !sprite.labelStarts.exists(label)) return;

		var start:Int = sprite.labelStarts.get(label);
		addBySymbolIndices(animName, sprite.mainName, [for (index in indices) start + index], frameRate, looped, flipX, flipY);
	}

	// The library's animation for a frame label of the main timeline, made the first time it's needed
	function makeLabel(label:String):String
	{
		var realName:String = 'label_$label';
		var start:Int = sprite.labelStarts.get(label);
		@:privateAccess
		if(!sprite.anim.animsMap.exists(realName))
		{
			sprite.anim.addBySymbolIndices(realName, sprite.mainName, [for (i in 0...sprite.labelLengths.get(label)) start + i], 0, false);
			sprite.useStageMatrix(realName);
		}
		return realName;
	}

	public function hasAnimation(animName:String):Bool return exists(animName);

	public function getNameList():Array<String>
	{
		return [for (label in sprite.labelStarts.keys()) label];
	}

	public function getFrameLabelNames():Array<String> return getNameList();

	/**
	 * Plays a frame label of the main timeline from its first frame to its last one, or the whole timeline if given no name.
	 *
	 * @param frame 	Frame to start from, counting from the animation's first one.
	 */
	public function play(animName:String = '', force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if(!sprite.loaded) return;
		if(animName == null || animName == sprite.mainName) animName = '';

		if(!force && started && !finished && animName == requested)
		{
			resume();
			return;
		}

		var realName:String = AtlasSprite.MAIN;
		var start:Int = 0;
		var loops:Bool = false;
		var mine:AtlasAddedAnim = (animName != '') ? added.get(animName) : null;
		if(mine != null)
		{
			realName = mine.real;
			start = mine.start;
			loops = mine.looped;
		}
		else if(animName != '' && sprite.labelStarts.exists(animName))
		{
			realName = makeLabel(animName);
			start = sprite.labelStarts.get(animName);
		}
		else if(animName != '' && sprite.anim.symbolDictionary.exists(animName))
		{
			// like on V-Slice: what isn't a frame label can be one of the atlas' symbols
			realName = 'symbol_$animName';
			@:privateAccess
			if(!sprite.anim.animsMap.exists(realName))
			{
				sprite.anim.addBySymbol(realName, flxanimate.PsychFlxAnimate.symbolQuery(sprite.anim, animName), 0, false);
				sprite.useStageMatrix(realName);
			}
		}
		else if(animName != '')
		{
			// better the whole thing than nothing at all
			trace('The atlas has no frame label or symbol called "$animName", playing its whole timeline');
			animName = '';
		}

		sprite.anim.play(realName, true, false, 0);
		sprite.anim.loopType = PlayOnce;
		if(frame > 0) sprite.anim.curFrame = frame;

		requested = animName;
		name = (animName == '') ? sprite.mainName : animName;
		startFrame = start;
		started = true;
		finished = false;
		paused = false;
		finishTimer = -1;
		lastFrame = sprite.anim.curFrame;
		plays++;
		@:bypassAccessor looped = false;
		if(loops) looped = true;

		// what's drawn comes from the last update, without this the next draw would still show what was there before
		sprite.anim.update(0);
	}

	function set_looped(value:Bool):Bool
	{
		looped = value;
		if(sprite.loaded && started) sprite.anim.loopType = value ? Loop : PlayOnce;
		return value;
	}

	public function pause():Void
	{
		paused = true;
		if(sprite.loaded) sprite.anim.pause();
	}

	public function resume():Void
	{
		paused = false;
		if(sprite.loaded && started && !finished) sprite.anim.resume();
	}

	public function stop():Void
	{
		pause();
		finished = true;
	}

	/**
	 * Jumps to the end of the animation, which then ends like it would have.
	 */
	public function finish():Void
	{
		if(!sprite.loaded || !started || finished) return;

		paused = false;
		@:bypassAccessor looped = false;
		sprite.anim.loopType = PlayOnce;
		curFrame = sprite.anim.length - 1;
		finishTimer = 0;
	}

	@:allow(objects.AtlasSprite)
	function update(elapsed:Float):Void
	{
		if(!started || paused) return;

		var playing:Int = plays;
		var frame:Int = sprite.anim.curFrame;
		if(frame != lastFrame)
		{
			var wentAround:Bool = (looped && frame < lastFrame);
			lastFrame = frame;
			if(wentAround)
			{
				onLoop.dispatch([name]);
				if(plays != playing) return;
			}
			onFrameChange.dispatch([name, frame, startFrame + frame]); //its number on the animation, and on everything the atlas has
			if(plays != playing) return; //something else was played by who was listening

			var label:String = sprite.labelsAt.get(startFrame + frame);
			if(label != null) onFrameLabel.dispatch([label]);
			if(plays != playing) return;
		}

		if(finished || looped || !sprite.anim.finished) return;

		// the last frame stays on the screen for as long as the others before the animation counts as over
		if(finishTimer < 0) finishTimer = (sprite.anim.framerate > 0) ? 1 / sprite.anim.framerate : 0;
		else finishTimer -= elapsed;

		if(finishTimer <= 0)
		{
			finished = true;
			onFinish.dispatch([name]);
		}
	}

	public function destroy():Void
	{
		onFrameChange.removeAll();
		onFrameLabel.removeAll();
		onFinish.removeAll();
		onLoop.removeAll();
	}
}
