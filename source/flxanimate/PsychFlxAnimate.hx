package flxanimate;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxDestroyUtil;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.data.AnimationData;
import flixel.math.FlxMatrix;
import flxanimate.FlxAnimate as OriginalFlxAnimate;
import flxanimate.animate.FlxElement;
import flxanimate.animate.FlxKeyFrame;
import flxanimate.animate.FlxLayer;
import flxanimate.animate.FlxSymbol;
import flixel.math.FlxRect;
import flxanimate.display.FlxAnimateFilterRenderer;
import flxanimate.interfaces.IFilterable;

import openfl.display.BitmapData;
import openfl.filters.BitmapFilter;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils.Assets as OpenFlAssets;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	/**
	 * Blend modes of atlases made with the "Better Texture Atlas" exporter (most of the V-Slice ones).
	 * Blended symbols are rendered to a bitmap first, turn this off if they ever look wrong or get too heavy.
	 */
	public static var atlasBlendModes:Bool = true;

	// OpenFL's blend modes its GPU renderer has: add, darken, lighten, multiply, screen and subtract (`OpenGLRenderer.__setBlendMode()`)
	static final DRAWN_BLEND_MODES:Array<Int> = [0, 2, 8, 9, 12, 14];

	// What the instances with a blend mode `backend.CameraBlend` does start with, before its number
	static inline var CAMERA_BLEND:String = '_cbm';

	/**
	 * Loads a texture atlas from its folder, same as the original function but it also looks on the file system (mods)
	 * and supports the newer atlas formats and atlases split in more than one spritemap.
	 */
	override public function loadAtlas(Path:String)
	{
		var folder:String = haxe.io.Path.removeTrailingSlashes(Path);

		var animation:String = _getText('$folder/Animation.json');
		if(animation == null)
		{
			super.loadAtlas(Path); //.zip files or wrong paths, let the library handle it
			return;
		}

		var loaded:Bool = false;
		for (i in 0...10)
		{
			var name:String = (i == 0) ? 'spritemap' : 'spritemap$i';
			var spritemap:String = _getText('$folder/$name.json');
			if(spritemap == null)
			{
				if(loaded) break;
				continue;
			}

			var image:FlxGraphic = _getGraphic('$folder/$name.png');
			if(image == null) continue;

			if(!loaded)
			{
				loadAtlasEx(image, spritemap, animation);
				loaded = true;
			}
			else addSpriteMap(image, spritemap);
		}

		if(!loaded) FlxG.log.error('No spritemap found in the texture atlas folder: "$Path"');
	}

	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animJson:AnimAtlas = null;
		if(myJson is String)
		{
			var trimmed:String = pathOrStr.trim();
			trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

			if(trimmed == '.json') myJson = File.getContent(myJson); //is a path
			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		var trimmed:String = pathOrStr.trim();
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		if(trimmed == '.json') //Path is json
		{
			myData = File.getContent(pathOrStr);
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			myData = File.getContent(pathOrStr);
			isXml = true;
		}
		myData = _removeBOM(myData);

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		anim._loadAtlas(cast normalizeAtlas(animJson));
		if(!isXml) frames = FlxAnimateFrames.fromSpriteMap(cast normalizeSpriteMap(myData), img);
		else frames = FlxAnimateFrames.fromSparrow(cast myData, img);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	/**
	 * Adds the sprites of another spritemap (spritemap2, spritemap3...) of an atlas that's already loaded.
	 */
	public function addSpriteMap(img:FlxGraphicAsset, spritemap:String)
	{
		var extraFrames:FlxAtlasFrames = FlxAnimateFrames.fromSpriteMap(cast normalizeSpriteMap(haxe.Json.parse(_removeBOM(spritemap))), img);
		if(extraFrames == null) return;

		var curFrames:FlxAtlasFrames = cast frames;
		if(curFrames == null)
		{
			frames = extraFrames;
			return;
		}

		// the frames could be cached and shared with other sprites, so they're merged into a new collection
		var merged:FlxAtlasFrames = new FlxAtlasFrames(curFrames.parent);
		merged.addAtlas(curFrames, true);
		merged.addAtlas(extraFrames, true);
		frames = merged;
	}

	/**
	 * Makes atlases exported in newer formats readable by the library, changing the parsed "Animation.json" in place.
	 *
	 * The "Better Texture Atlas" exporter writes 2D matrices (MX) instead of 3D ones (M3D), leaves out empty instance names
	 * and has the blend mode as a value of its own (B), the library only knows about the first of each.
	 */
	public static function normalizeAtlas(atlas:Dynamic):Dynamic
	{
		if(atlas == null) return null;

		var animation:Dynamic = _field(atlas, 'AN', 'ANIMATION');
		if(animation != null)
		{
			_normalizeElement(_field(animation, 'STI', 'StageInstance'));
			_normalizeTimeline(_field(animation, 'TL', 'TIMELINE'));
		}

		var dictionary:Dynamic = _field(atlas, 'SD', 'SYMBOL_DICTIONARY');
		if(dictionary != null)
		{
			var symbols:Array<Dynamic> = _field(dictionary, 'S', 'Symbols');
			if(symbols != null)
				for (symbol in symbols)
					_normalizeTimeline(_field(symbol, 'TL', 'TIMELINE'));
		}
		return atlas;
	}

	/**
	 * Same for a parsed spritemap: some exporters put its "meta" inside of "ATLAS", where the library doesn't look for it (and the
	 * image is given to it anyway, the name in there is only used without one).
	 */
	public static function normalizeSpriteMap(spritemap:Dynamic):Dynamic
	{
		if(spritemap == null || Reflect.field(spritemap, 'meta') != null) return spritemap;

		var atlas:Dynamic = Reflect.field(spritemap, 'ATLAS');
		var meta:Dynamic = (atlas != null) ? Reflect.field(atlas, 'meta') : null;
		Reflect.setField(spritemap, 'meta', (meta != null) ? meta : {image: ''});
		return spritemap;
	}

	static function _normalizeTimeline(timeline:Dynamic)
	{
		var layers:Array<Dynamic> = _field(timeline, 'L', 'LAYERS');
		if(layers == null) return;

		for (layer in layers)
		{
			var keyFrames:Array<Dynamic> = _field(layer, 'FR', 'Frames');
			if(keyFrames == null) continue;

			for (keyFrame in keyFrames)
			{
				var elements:Array<Dynamic> = _field(keyFrame, 'E', 'elements');
				if(elements == null) continue;

				for (element in elements)
					_normalizeElement(element);
			}
		}
	}

	static function _normalizeElement(element:Dynamic)
	{
		if(element == null) return;

		var sprite:Dynamic = _field(element, 'ASI', 'ATLAS_SPRITE_instance');
		if(sprite != null) _normalizeMatrix(sprite);

		var symbol:Dynamic = _field(element, 'SI', 'SYMBOL_Instance');
		if(symbol == null) return;

		_normalizeMatrix(symbol);

		var hasLongNames:Bool = Reflect.hasField(symbol, 'SYMBOL_name');
		var instanceField:String = hasLongNames ? 'Instance_Name' : 'IN';

		var instance:String = Reflect.field(symbol, instanceField);
		if(instance == null) instance = '';

		// the library takes blend modes from instances named "_bl(number)_(name)", with the same numbers the exporter uses (10 is normal).
		// Only the ones the game can draw: the library would render the others' symbols to a bitmap of their own first, where they come
		// out empty. Overlay and the rest that only a shader can do are marked to be done here instead (see `CAMERA_BLEND`)
		var blend:Dynamic = Reflect.field(symbol, 'B');
		if(atlasBlendModes && blend != null && Std.isOfType(blend, Int) && !instance.contains('_bl') && !instance.startsWith(CAMERA_BLEND))
		{
			if(DRAWN_BLEND_MODES.contains(blend)) instance = '_bl${blend}_$instance';
			else if(backend.CameraBlend.MODES.contains(blend)) instance = '$CAMERA_BLEND${blend}_$instance';
		}

		Reflect.setField(symbol, instanceField, instance);
	}

	// [a, b, c, d, tx, ty] to the 4x4 matrix the library expects
	static function _normalizeMatrix(object:Dynamic)
	{
		if(Reflect.hasField(object, 'M3D') || Reflect.hasField(object, 'Matrix3D')) return;

		var matrix:Array<Float> = Reflect.field(object, 'MX');
		if(matrix == null || matrix.length < 6) return;

		Reflect.setField(object, 'M3D', [
			matrix[0], matrix[1], 0, 0,
			matrix[2], matrix[3], 0, 0,
			0, 0, 1, 0,
			matrix[4], matrix[5], 0, 1
		]);
	}

	inline static function _field(object:Dynamic, shortName:String, longName:String):Dynamic
	{
		return (object == null) ? null : (Reflect.hasField(object, shortName) ? Reflect.field(object, shortName) : Reflect.field(object, longName));
	}

	/**
	 * Adds an animation out of a frame label of the atlas' main timeline, which is how V-Slice atlases have their animations.
	 * Returns false if there's no label with that name.
	 *
	 * @param indices 	Optional, frames to use counting from the label's first frame.
	 */
	public function addAnimByFrameLabel(name:String, label:String, frameRate:Float = 0, looped:Bool = false, ?indices:Array<Int>):Bool
	{
		if(anim.stageInstance == null || anim.symbolDictionary == null) return false;

		var mainName:String = anim.stageInstance.symbol.name;
		var mainSymbol = anim.symbolDictionary.get(mainName);
		if(mainSymbol == null) return false;

		var labelFrames:Array<Int> = [];
		for (keyFrame in findFrameLabel(label))
			for (index in keyFrame.getFrameIndices())
				labelFrames.push(index);
		if(labelFrames.length < 1) return false;

		if(indices != null && indices.length > 0)
			labelFrames = [for (i in indices) if(i >= 0 && i < labelFrames.length) labelFrames[i]];
		if(labelFrames.length < 1) return false;

		// the library creates a symbol with the animation's name, it's given another one so it can't replace a symbol of the atlas
		var symbolName:String = '__label_$name';
		anim.addBySymbolIndices(symbolName, mainName, labelFrames, frameRate, looped);
		@:privateAccess
		{
			var added = anim.animsMap.get(symbolName);
			if(added == null) return false;

			// keeps the art where it is when the main timeline is played as a whole
			if(added.instance.matrix != null && anim.stageInstance.matrix != null && labelsOnDocument)
				copyStageMatrix(added.instance.matrix);

			anim.animsMap.remove(symbolName);
			anim.animsMap.set(name, added);
		}
		animationSources.set(name, mainName);
		if(!_labelAnimations.contains(name)) _labelAnimations.push(name);
		return true;
	}

	// ------------------------------------------------------------------------------------------
	// Timelines and the area they take
	// ------------------------------------------------------------------------------------------

	/**
	 * The timeline each animation plays frames of, for the ones made out of only some of its frames: the library gives those a timeline of their own.
	 * The ones added with `addAnimByFrameLabel()` are put here by it, the others by whoever adds them.
	 */
	public var animationSources:Map<String, String> = [];

	var _labelAnimations:Array<String> = [];

	/**
	 * Name of the timeline an animation plays. Null if there's no such animation.
	 */
	public function getAnimationSource(name:String):String
	{
		if(animationSources.exists(name)) return animationSources.get(name);

		@:privateAccess
		var added = (anim.animsMap != null) ? anim.animsMap.get(name) : null;
		return (added != null && added.instance != null && added.instance.symbol != null) ? added.instance.symbol.name : null;
	}

	/**
	 * V-Slice 0.8's texture atlas library (flixel-animate) puts the atlas' place on its file ("applyStageMatrix") after the sprite's
	 * origin is taken away, and gives it back after: a stage matrix that scales or turns the art does it around the origin. The origin
	 * is the middle of the sprite's size, which for an atlas placed by its file is the area its main timeline takes there
	 * (V-Slice's Richard: 1920x1080 made 0.6 times smaller, 1152x648, the origin at 576,324).
	 * A matrix that only moves the art (most of them) puts it in the same place either way; one that scales it doesn't
	 * (Character Select's Richard, made 0.6 times smaller, ended up up and to the left of where V-Slice has him).
	 */
	public var stageAroundOrigin:Bool = false;
	var _stageOrigin:FlxPoint = null;

	function copyStageMatrix(target:FlxMatrix):Void
	{
		var stage:FlxMatrix = anim.stageInstance.matrix;
		target.copyFrom(stage);
		if(!stageAroundOrigin || anim.stageInstance.symbol == null) return;

		if(_stageOrigin == null)
		{
			var box:FlxRect = getTimelineBounds(anim.stageInstance.symbol.name, stage);
			_stageOrigin = FlxPoint.get(box.width / 2, box.height / 2);
			box.put();
		}
		var originX:Float = _stageOrigin.x;
		var originY:Float = _stageOrigin.y;
		target.tx += originX - (stage.a * originX + stage.c * originY);
		target.ty += originY - (stage.b * originX + stage.d * originY);
	}

	/**
	 * If the animations made out of frame labels are drawn where the atlas' file puts its main timeline (the place it has on Adobe Animate's stage),
	 * which is how they're added. V-Slice only does that when asked to ("applyStageMatrix"): without it they're the timeline as it is.
	 */
	public var labelsOnDocument(default, set):Bool = true;
	function set_labelsOnDocument(value:Bool):Bool
	{
		labelsOnDocument = value;
		if(anim == null) return value;

		@:privateAccess
		for (name in _labelAnimations)
		{
			var added = (anim.animsMap != null) ? anim.animsMap.get(name) : null;
			if(added == null || added.instance == null || added.instance.matrix == null) continue;

			if(value && anim.stageInstance != null && anim.stageInstance.matrix != null) copyStageMatrix(added.instance.matrix);
			else added.instance.matrix.identity();
		}
		_boxes = [];
		return value;
	}

	/**
	 * The area a timeline of the atlas takes from its first frame to its last one, on its own coordinates.
	 * It's the box V-Slice gives to a sprite that's playing it: the sprite's position is the corner of that box, and when flipped
	 * the art is mirrored inside of it. Layers that are masks aren't part of it, only what's seen through them.
	 *
	 * @param matrix   Something the timeline is seen through, like the placement of the animation that plays it.
	 * @param frame    Only this frame of it.
	 */
	public function getTimelineBounds(symbolName:String, ?matrix:FlxMatrix, ?frame:Null<Int>):FlxRect
	{
		var result:FlxRect = FlxRect.get();
		var symbol:FlxSymbol = (anim != null && anim.symbolDictionary != null) ? anim.symbolDictionary.get(symbolName) : null;
		if(symbol == null) return result;

		var seenThrough:FlxMatrix = new FlxMatrix();
		if(matrix != null) seenThrough.copyFrom(matrix);

		var bounds:Array<Float> = [Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY];
		if(frame != null) addFrameBounds(symbolName, frame, seenThrough, bounds, 0);
		else
		{
			for (i in 0...symbol.length)
				addFrameBounds(symbolName, i, seenThrough, bounds, 0);
		}

		if(bounds[0] > bounds[2] || bounds[1] > bounds[3]) return result; //nothing on it
		return result.set(bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]);
	}

	var _boxes:Map<String, FlxRect> = [];
	var _wholeBox:FlxRect = null;

	/**
	 * Gives each symbol of the atlas to a function, the way V-Slice does it as an atlas is loaded (the "onSymbolCreate" of its settings):
	 * scripts use it to hide layers, like the hat the base game's Monster only wears on Christmas.
	 * What the function gets has the symbol's `name` and its `timeline`, with `forEachLayer()`, `getLayer()` and the `layers` themselves.
	 */
	public function forEachSymbol(callback:Dynamic):Void
	{
		if(callback == null || anim == null || anim.symbolDictionary == null) return;

		for (name => symbol in anim.symbolDictionary)
		{
			if(symbol == null || symbol.timeline == null) continue;

			var layers = symbol.timeline.getList();
			var timeline:Dynamic = {
				name: name,
				layers: layers,
				forEachLayer: function(each:Dynamic)
				{
					for (layer in layers)
						if(layer != null) each(layer);
				},
				getLayer: function(which:Dynamic):Dynamic
				{
					if(Std.isOfType(which, Int)) return layers[which];
					for (layer in layers)
						if(layer != null && layer.name == which)
							return layer;
					return null;
				}
			};
			callback({name: name, timeline: timeline});
		}

		// (the area the atlas takes can be another now)
		_boxes = [];
		_wholeBox = null;
	}

	/**
	 * The box of the atlas' main timeline, as it is on the file. Kept after the first time, not to be changed.
	 */
	public function getWholeBox():FlxRect
	{
		if(_wholeBox == null)
			_wholeBox = (anim != null && anim.stageInstance != null && anim.stageInstance.symbol != null) ? getTimelineBounds(anim.stageInstance.symbol.name) : FlxRect.get();
		return _wholeBox;
	}

	/**
	 * The box of the timeline an animation plays (see `getTimelineBounds()`), where the animation draws it: from the atlas' position.
	 * Kept after the first time, as it takes going through the whole timeline. Null if there's no such animation.
	 */
	public function getAnimationBox(name:String):FlxRect
	{
		if(name == null || anim == null) return null;

		@:privateAccess
		var added = (anim.animsMap != null) ? anim.animsMap.get(name) : null;
		if(added == null || added.instance == null) return null;

		var source:String = getAnimationSource(name);
		if(source == null) return null;

		var matrix:FlxMatrix = added.instance.matrix;
		var key:String = (matrix != null) ? '$source|${matrix.a}|${matrix.b}|${matrix.c}|${matrix.d}|${matrix.tx}|${matrix.ty}' : source;
		var box:FlxRect = _boxes.get(key);
		if(box == null)
		{
			box = getTimelineBounds(source, matrix);
			_boxes.set(key, box);
		}
		return box;
	}

	// Adds what a symbol shows on one of its frames to the bounds, seen through a matrix
	function addFrameBounds(symbolName:String, frame:Int, matrix:FlxMatrix, bounds:Array<Float>, depth:Int):Void
	{
		var symbol:FlxSymbol = anim.symbolDictionary.get(symbolName);
		if(symbol == null || depth > 30) return;

		for (layer in symbol.timeline.getList())
		{
			if(layer.type != null && layer.type.match(Clipper)) continue; //masks aren't drawn, they only cut what's under them
			if(!layer.visible) continue; //(what a script hid doesn't count either, like on V-Slice)

			var layerBounds:Array<Float> = [Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY];
			addLayerBounds(layer, frame, matrix, layerBounds, depth);
			if(layerBounds[0] > layerBounds[2] || layerBounds[1] > layerBounds[3]) continue;

			// A masked layer only takes the area it has in common with its mask, when the mask has something on that frame
			// (flixel-animate's `Timeline.maskBounds()`: the same rule the drawing follows)
			if(layer.type != null && layer.type.getName() == 'Clipped')
			{
				var clipper:FlxLayer = symbol.timeline.get(layer.type.getParameters()[0]);
				if(clipper != null)
				{
					var maskBounds:Array<Float> = [Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY];
					addLayerBounds(clipper, frame, matrix, maskBounds, depth);
					if(maskBounds[0] < maskBounds[2] && maskBounds[1] < maskBounds[3])
					{
						layerBounds[0] = Math.max(layerBounds[0], maskBounds[0]);
						layerBounds[1] = Math.max(layerBounds[1], maskBounds[1]);
						layerBounds[2] = Math.min(layerBounds[2], maskBounds[2]);
						layerBounds[3] = Math.min(layerBounds[3], maskBounds[3]);
						if(layerBounds[0] >= layerBounds[2] || layerBounds[1] >= layerBounds[3]) continue;
					}
				}
			}

			if(layerBounds[0] < bounds[0]) bounds[0] = layerBounds[0];
			if(layerBounds[1] < bounds[1]) bounds[1] = layerBounds[1];
			if(layerBounds[2] > bounds[2]) bounds[2] = layerBounds[2];
			if(layerBounds[3] > bounds[3]) bounds[3] = layerBounds[3];
		}
	}

	// What one layer of a symbol shows on a frame
	function addLayerBounds(layer:FlxLayer, frame:Int, matrix:FlxMatrix, bounds:Array<Float>, depth:Int):Void
	{
		{
			var keyFrame = null;
			@:privateAccess
			for (candidate in layer._keyframes)
			{
				if(candidate.index <= frame && frame < candidate.index + candidate.duration)
				{
					keyFrame = candidate;
					break;
				}
			}
			if(keyFrame == null) return;

			for (element in keyFrame.getList())
			{
				var elementMatrix:FlxMatrix = new FlxMatrix();
				if(element.matrix != null) elementMatrix.copyFrom(element.matrix);
				elementMatrix.concat(matrix);

				if(element.bitmap != null)
				{
					var limb = (frames != null) ? frames.getByName(element.bitmap) : null;
					if(limb == null) continue;

					// Not its "sourceSize": for the sprites of a texture atlas the library fills that with where they are on the image.
					// The ones that are rotated on the image are drawn the right way up
					var rotated:Bool = (limb.angle != flixel.graphics.frames.FlxFrame.FlxFrameAngle.ANGLE_0);
					var limbWidth:Float = rotated ? limb.frame.height : limb.frame.width;
					var limbHeight:Float = rotated ? limb.frame.width : limb.frame.height;
					for (corner in [[0.0, 0.0], [limbWidth, 0.0], [0.0, limbHeight], [limbWidth, limbHeight]])
					{
						var pointX:Float = corner[0] * elementMatrix.a + corner[1] * elementMatrix.c + elementMatrix.tx;
						var pointY:Float = corner[0] * elementMatrix.b + corner[1] * elementMatrix.d + elementMatrix.ty;
						if(pointX < bounds[0]) bounds[0] = pointX;
						if(pointY < bounds[1]) bounds[1] = pointY;
						if(pointX > bounds[2]) bounds[2] = pointX;
						if(pointY > bounds[3]) bounds[3] = pointY;
					}
					continue;
				}

				if(element.symbol == null || element.symbol.name == null) continue;

				var child:FlxSymbol = anim.symbolDictionary.get(element.symbol.name);
				if(child == null) continue;

				// the frame of the symbol that's shown on this frame of its parent
				var length:Int = child.length;
				var passed:Int = frame - keyFrame.index;
				var childFrame:Int = 0;
				if(element.symbol.type != MovieClip && element.symbol.type != Button)
				{
					childFrame = switch(element.symbol.loop)
					{
						case SingleFrame: element.symbol.firstFrame;
						case PlayOnce: Std.int(Math.min(element.symbol.firstFrame + passed, length - 1));
						default: (length > 0) ? (element.symbol.firstFrame + passed) % length : 0;
					}
				}
				addFrameBounds(element.symbol.name, childFrame, elementMatrix, bounds, depth + 1);
			}
		}
	}

	// ------------------------------------------------------------------------------------------
	// Sprites put inside of the atlas
	// ------------------------------------------------------------------------------------------

	/**
	 * Every keyframe of the symbols that have something on their name, for things to be added to them: see `funkin.graphics.SpriteElement`.
	 */
	public function getFramesWithKeyword(keyword:String):Array<FlxKeyFrame>
	{
		var found:Array<FlxKeyFrame> = [];
		if(anim == null || anim.symbolDictionary == null || keyword == null || keyword.length < 1) return found;

		for (name => symbol in anim.symbolDictionary)
		{
			if(symbol == null || symbol.timeline == null || name.indexOf(keyword) < 0) continue;

			for (layer in symbol.timeline.getList())
			{
				@:privateAccess
				for (keyFrame in layer._keyframes)
					found.push(keyFrame);
			}
		}
		return found;
	}

	override function parseElement(instance:FlxElement, m:FlxMatrix, colorFilter:ColorTransform, ?filterInstance:{?instance:FlxElement} = null,
		?cameras:Array<FlxCamera> = null, ?scrollFactor:FlxPoint = null)
	{
		if(blendLayers == null && filterInstance == null)
		{
			var mode:Int = cameraBlendOf(instance);
			if(mode > -1 && backend.CameraBlend.supports(mode))
			{
				drawBlended(instance, m, colorFilter, (cameras != null) ? cameras : this.cameras, scrollFactor, mode);
				return;
			}
		}

		var placed:funkin.graphics.SpriteElement = Std.downcast(instance, funkin.graphics.SpriteElement);
		if(placed == null)
		{
			// the atlas itself, when it goes on a texture first (see `useRenderTexture`)
			if(!_drawingWhole && filterInstance == null && instance != null && instance == anim.curInstance && instance.visible
				&& instance.symbol != null && wantsRenderTexture() && drawWhole(instance, m, colorFilter, cameras))
			{
				return;
			}

			super.parseElement(instance, m, colorFilter, filterInstance, cameras, scrollFactor);
			return;
		}

		if(placed.visible && placed.sprite != null) drawPlacedSprite(placed, m, colorFilter, filterInstance != null, (cameras != null) ? cameras : this.cameras);
	}

	// While a symbol with one of those blend modes is drawn: the cameras its pieces go on instead of each camera
	var blendLayers:haxe.ds.ObjectMap<FlxCamera, FlxCamera> = null;

	// The blend mode of an instance that `backend.CameraBlend` does, -1 if it has none of those
	static function cameraBlendOf(instance:FlxElement):Int
	{
		if(instance == null || instance.symbol == null || instance.symbol.instance == null) return -1;

		var name:String = instance.symbol.instance;
		if(!name.startsWith(CAMERA_BLEND)) return -1;
		var end:Int = name.indexOf('_', CAMERA_BLEND.length);
		var mode:Null<Int> = Std.parseInt(name.substring(CAMERA_BLEND.length, (end > -1) ? end : name.length));
		return (mode != null) ? mode : -1;
	}

	// The symbol is drawn on cameras of its own that see the same, then put on each camera blended with what it has
	function drawBlended(instance:FlxElement, m:FlxMatrix, colorFilter:ColorTransform, cameras:Array<FlxCamera>, scrollFactor:FlxPoint, mode:Int):Void
	{
		blendLayers = new haxe.ds.ObjectMap();
		for (camera in cameras)
			if(camera != null && camera.visible && camera.exists)
				blendLayers.set(camera, backend.CameraBlend.layerFor(camera));

		parseElement(instance, m, colorFilter, null, cameras, scrollFactor);

		var layers = blendLayers;
		blendLayers = null;
		for (camera => layer in layers)
			backend.CameraBlend.blend(camera, layer, mode);
	}

	/**
	 * Draws a sprite that was put on one of the atlas' frames, as part of the atlas: on the coordinates of the symbol the frame is of
	 * (`parent` is what takes those to where the symbol is being drawn), and from there like any sprite is drawn on the screen.
	 * Its corner is at its position minus its offset, it's scaled and turned around its origin and mirrored inside of its own size.
	 *
	 * The details are the ones of V-Slice's library (flixel-animate's `FlxSpriteElement`), where the sprite isn't made part of the
	 * symbol: it draws itself as it would anywhere else, only somewhere else and turned.
	 * - Its position is taken through everything the symbol went through to where that ends up on the screen.
	 * - Its angle gets the angle the symbol ends up with added to it. It isn't scaled, skewed or mirrored by the symbol or by the atlas:
	 *   a mirrored symbol counts as one turned around, and the scripts of the LE SSERAFIM characters whose mouth is on a mirrored face
	 *   turn it by about 180 degrees to have it upright again.
	 * - A texture atlas counts as a sprite the size of its whole timeline, with its corner where that area starts, and its origin is
	 *   the middle of the first image of its spritesheet (what the sprite had as a frame when it was loaded).
	 */
	function drawPlacedSprite(placed:funkin.graphics.SpriteElement, parent:FlxMatrix, color:ColorTransform, filterin:Bool, cameras:Array<FlxCamera>):Void
	{
		var sprite:FlxSprite = Std.downcast(placed.sprite, FlxSprite);
		if(sprite == null || !sprite.visible || sprite.alpha <= 0) return;

		// the atlas it shows, when it's one
		var inner:PsychFlxAnimate = Std.downcast(sprite, PsychFlxAnimate);
		var wrapper:funkin.graphics.FunkinSprite = Std.downcast(sprite, funkin.graphics.FunkinSprite);
		if(inner == null && wrapper != null) inner = wrapper.atlas;
		if(inner == this) return;

		var boxX:Float = 0;
		var boxY:Float = 0;
		var boxWidth:Float = sprite.frameWidth;
		var boxHeight:Float = sprite.frameHeight;
		var pivotX:Float = sprite.origin.x;
		var pivotY:Float = sprite.origin.y;
		var innerSymbol:String = null;
		if(inner != null)
		{
			if(inner.anim == null || inner.anim.curInstance == null || inner.anim.curInstance.symbol == null || inner.anim.stageInstance == null) return;

			innerSymbol = inner.anim.curInstance.symbol.name;
			var box:FlxRect = inner.getWholeBox();
			boxX = box.x;
			boxY = box.y;
			boxWidth = box.width;
			boxHeight = box.height;

			pivotX = boxWidth * 0.5;
			pivotY = boxHeight * 0.5;
			var first = (inner.frames != null && inner.frames.frames != null) ? inner.frames.frames[0] : null;
			if(first != null && first.frame != null)
			{
				var turned:Bool = (first.angle != flixel.graphics.frames.FlxFrame.FlxFrameAngle.ANGLE_0);
				pivotX = (turned ? first.frame.height : first.frame.width) * 0.5;
				pivotY = (turned ? first.frame.width : first.frame.height) * 0.5;
			}
		}
		else if(sprite.frame == null) return;

		// What the atlas still does to everything it draws after `parent` (see `drawLimb()`): scaled and turned around its origin.
		// The sprite has to come out as if none of it was done to it, so it's undone here beforehand
		var own:FlxMatrix = new FlxMatrix();
		if(!filterin)
		{
			own.scale(scale.x, scale.y);
			if(bakedRotationAngle <= 0 && angle != 0) own.rotate(angle * Math.PI / 180);
		}

		var whole:FlxMatrix = new FlxMatrix();
		whole.copyFrom(parent);
		whole.tx = whole.ty = 0;
		whole.concat(own);
		var symbolAngle:Float = Math.atan2(whole.b, whole.a);

		var undone:FlxMatrix = new FlxMatrix();
		undone.copyFrom(own);
		if(undone.a * undone.d - undone.b * undone.c == 0) return;
		undone.invert();

		var local:FlxMatrix = new FlxMatrix();
		local.translate(-boxX, -boxY);
		if(sprite.flipX)
		{
			local.scale(-1, 1);
			local.translate(boxWidth, 0);
		}
		if(sprite.flipY)
		{
			local.scale(1, -1);
			local.translate(0, boxHeight);
		}
		local.translate(-pivotX, -pivotY);
		local.scale(sprite.scale.x, sprite.scale.y);
		local.rotate(sprite.angle * Math.PI / 180 + symbolAngle);
		local.translate(pivotX - sprite.offset.x, pivotY - sprite.offset.y);
		local.concat(undone);
		local.translate(parent.a * sprite.x + parent.c * sprite.y + parent.tx, parent.b * sprite.x + parent.d * sprite.y + parent.ty);

		var tinted:ColorTransform = color;
		if(sprite.alpha < 1)
		{
			tinted = new ColorTransform(color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier * sprite.alpha,
				color.redOffset, color.greenOffset, color.blueOffset, color.alphaOffset);
		}

		if(inner == null)
		{
			drawLimb(sprite.frame, local, tinted, filterin, cameras);
			return;
		}

		var instanceMatrix:FlxMatrix = inner.anim.curInstance.matrix;
		if(instanceMatrix != null)
		{
			var placedWhole:FlxMatrix = new FlxMatrix();
			placedWhole.copyFrom(instanceMatrix);
			placedWhole.concat(local);
			local = placedWhole;
		}
		drawOtherTimeline(inner, innerSymbol, inner.anim.curFrame, local, tinted, filterin, cameras, 0);
	}

	// What a symbol of another atlas shows on one of its frames, drawn by this one (where, how and with what this one is drawn).
	// Only the pieces themselves: the masks, filters and colors that atlas has on its symbols are left out
	function drawOtherTimeline(other:PsychFlxAnimate, symbolName:String, frame:Int, matrix:FlxMatrix, color:ColorTransform, filterin:Bool,
		cameras:Array<FlxCamera>, depth:Int):Void
	{
		var symbol:FlxSymbol = other.anim.symbolDictionary.get(symbolName);
		if(symbol == null || depth > 30) return;

		// (the layers of a timeline are listed from the front one to the back one)
		var layers = symbol.timeline.getList();
		var index:Int = layers.length;
		while(--index >= 0)
		{
			var layer = layers[index];
			if(layer == null || !layer.visible || (layer.type != null && layer.type.match(Clipper))) continue;

			var keyFrame:FlxKeyFrame = null;
			@:privateAccess
			for (candidate in layer._keyframes)
			{
				if(candidate.index <= frame && frame < candidate.index + candidate.duration)
				{
					keyFrame = candidate;
					break;
				}
			}
			if(keyFrame == null) continue;

			for (element in keyFrame.getList())
			{
				if(element == null || !element.visible) continue;

				var elementMatrix:FlxMatrix = new FlxMatrix();
				if(element.matrix != null) elementMatrix.copyFrom(element.matrix);
				elementMatrix.concat(matrix);

				if(element.bitmap != null)
				{
					var limb = (other.frames != null) ? other.frames.getByName(element.bitmap) : null;
					if(limb != null) drawLimb(limb, elementMatrix, color, filterin, cameras);
					continue;
				}

				if(element.symbol == null || element.symbol.name == null) continue;

				var child:FlxSymbol = other.anim.symbolDictionary.get(element.symbol.name);
				if(child == null) continue;

				var length:Int = child.length;
				var passed:Int = frame - keyFrame.index;
				var childFrame:Int = 0;
				if(element.symbol.type != MovieClip && element.symbol.type != Button)
				{
					childFrame = switch(element.symbol.loop)
					{
						case SingleFrame: element.symbol.firstFrame;
						case PlayOnce: Std.int(Math.min(element.symbol.firstFrame + passed, length - 1));
						default: (length > 0) ? (element.symbol.firstFrame + passed) % length : 0;
					}
				}
				drawOtherTimeline(other, element.symbol.name, childFrame, elementMatrix, color, filterin, cameras, depth + 1);
			}
		}
	}

	/**
	 * What the art is mirrored inside of when the sprite is flipped, counted from the atlas' position.
	 * The library uses the size of whatever it drew last, which makes flipped art move around as its frames change size:
	 * with these it's always the same place (V-Slice's sprites are mirrored inside of their box). Null leaves it to the library.
	 */
	public var flipWidth:Null<Float> = null;
	public var flipHeight:Null<Float> = null;

	/**
	 * Tells if the atlas has a symbol whose name starts with this, like `anim.addBySymbol()` looks for them.
	 */
	public function hasSymbol(prefix:String):Bool
	{
		if(anim.symbolDictionary == null) return false;

		for (name in anim.symbolDictionary.keys())
			if(name.startsWith(prefix))
				return true;
		return false;
	}

	/**
	 * What to give `anim.addBySymbol()` for a symbol: the library takes the first symbol whose name starts with what it's given,
	 * in no particular order ("Sky DJ" could be "Sky DJ fucked"). When there's one with exactly that name it's that one, like on
	 * V-Slice: the slash at the end makes the library look for that exact name.
	 */
	public static function symbolQuery(target:flxanimate.animate.FlxAnim, name:String):String
	{
		if(name == null || target == null || target.symbolDictionary == null || name.endsWith('\\')) return name;
		return target.symbolDictionary.exists(name) ? name + '\\' : name;
	}

	public function hasFrameLabel(label:String):Bool
	{
		return findFrameLabel(label).length > 0;
	}

	/**
	 * The keyframes of the main timeline that have a label, the way V-Slice's library looks for them (flixel-animate's
	 * `findFrameLabelIndices()`): spaces at the end of the label's name on the file don't count (the base game has an "up " that's asked for
	 * as "up"), and all of the frames with that label on the first layer that has it are the animation.
	 */
	public function findFrameLabel(label:String):Array<FlxKeyFrame>
	{
		var found:Array<FlxKeyFrame> = [];
		if(label == null || anim == null || anim.stageInstance == null || anim.symbolDictionary == null) return found;

		var mainSymbol = anim.symbolDictionary.get(anim.stageInstance.symbol.name);
		if(mainSymbol == null || mainSymbol.timeline == null) return found;

		for (layer in mainSymbol.timeline.getList())
		{
			if(layer == null) continue;

			@:privateAccess
			for (keyFrame in layer._keyframes)
				if(keyFrame != null && keyFrame.name != null && keyFrame.name.rtrim() == label)
					found.push(keyFrame);

			if(found.length > 0) break;
		}
		return found;
	}

	// Masked layers and the keyframe their bitmap was last made for
	var _maskedLayers:Map<FlxLayer, FlxKeyFrame> = [];

	/**
	 * Masked layers ("clipped" ones on Adobe Animate, like the static inside of the locked character on Character Select).
	 *
	 * The library's own masking expects the mask and the masked layer to have the same size and position,
	 * and only draws the mask again when it thinks it changed, so the layer is clipped here instead:
	 * the mask is always drawn again along with the layer, and the layer is cut by it pixel by pixel.
	 */
	override function renderFilter(filterInstance:IFilterable, filters:Array<BitmapFilter>, renderer:FlxAnimateFilterRenderer, ?mask:FlxCamera)
	{
		// The library draws these with a renderer of its own. It shares the game's graphics context with the one that draws the screen,
		// but each of them remembers what it last set there (shader, blend mode) and skips setting it again: after the first time,
		// what this one remembers is what the other left behind, and everything it draws comes out empty or blended wrong.
		// Both are made to forget, this one before drawing and the screen's after it
		@:privateAccess _forgetRendererState(renderer.renderer);
		_renderFilter(filterInstance, filters, renderer, mask);
		@:privateAccess _forgetRendererState(Std.downcast(FlxG.stage.__renderer, openfl.display.OpenGLRenderer));
	}

	@:access(openfl.display.OpenGLRenderer)
	@:access(openfl.display.DisplayObjectRenderer)
	static function _forgetRendererState(target:openfl.display.OpenGLRenderer)
	{
		if(target == null) return;

		target.__blendMode = null;
		target.__currentShader = null;
		target.__currentShaderBuffer = null;
		target.__currentGraphicsShader = null;
		target.__currentDisplayShader = null;
	}

	function _renderFilter(filterInstance:IFilterable, filters:Array<BitmapFilter>, renderer:FlxAnimateFilterRenderer, ?mask:FlxCamera)
	{
		var layer:FlxLayer = Std.downcast(filterInstance, FlxLayer);
		var clipper:FlxLayer = null;
		@:privateAccess
		if(layer != null && layer.type != null && layer.type.getName() == 'Clipped')
		{
			clipper = layer._clipper;
			if(clipper == null && layer._parent != null)
			{
				// drawn before the atlas had the chance to link them
				clipper = layer._parent.get(layer.type.getParameters()[0]);
				if(clipper != null)
				{
					clipper._correctClip = true;
					layer._clipper = clipper;
					if(layer._currFrame != null) clipper._setCurFrame(layer._currFrame.index);
				}
			}
		}

		if(clipper == null || (filters != null && filters.length > 0))
		{
			super.renderFilter(filterInstance, filters, renderer, mask);
			return;
		}

		@:privateAccess
		{
			// The mask's frame for the one the layer is on (found here: the library's own count of it gets lost once the mask's frames are over).
			// A mask with no frame there, or with a frame that has nothing on it, isn't masking anything and the layer is shown whole
			// (what V-Slice's library does: flixel-animate's `FilterRenderer.maskFrame()`). Characters come out from behind things
			// that way, masked while they're behind and then not at all
			var maskFrame:FlxKeyFrame = null;
			if(layer._currFrame != null)
			{
				for (candidate in clipper._keyframes)
				{
					if(candidate.index <= layer._currFrame.index && layer._currFrame.index < candidate.index + candidate.duration)
					{
						maskFrame = candidate;
						break;
					}
				}
			}
			if(maskFrame != null && maskFrame.getList().length < 1) maskFrame = null;
			var unmasked:Bool = (maskFrame == null);

			if(clipper._filterCamera == null) clipper._filterCamera = new FlxCamera();
			mask = clipper._filterCamera;
			mask.clearDrawStack();
			mask.canvas.graphics.clear();
			if(maskFrame != null)
			{
				renderLayer(maskFrame, new FlxMatrix(), new ColorTransform(), {instance: null}, [mask]);
				maskFrame._renderDirty = false;
			}

			var content:FlxCamera = filterInstance._filterCamera;
			content.render();
			mask.render();

			// Both were drawn with their symbol's coordinates, the bounds tell where each bitmap's top left corner is at
			var contentBounds:Rectangle = content.canvas.getBounds(null);
			var maskBounds:Rectangle = mask.canvas.getBounds(null);
			if(maskBounds.width < 1 || maskBounds.height < 1) unmasked = true;

			if(contentBounds.width >= 1 && contentBounds.height >= 1)
			{
				filterInstance.updateBitmaps(contentBounds);

				if(unmasked)
				{
					var contentBitmap:BitmapData = renderer.graphicstoBitmapData(content.canvas.graphics, filterInstance._bmp1);
					if(contentBitmap != null)
					{
						var target:BitmapData = filterInstance._filterFrame.parent.bitmap;
						target.fillRect(target.rect, 0);
						target.copyPixels(contentBitmap, new Rectangle(0, 0, Math.ceil(contentBounds.width), Math.ceil(contentBounds.height)), new Point(0, 0));
					}
				}

				// only the area where they overlap can be visible
				var visibleArea:Rectangle = contentBounds.intersection(maskBounds);
				if(!unmasked && visibleArea.width >= 1 && visibleArea.height >= 1)
				{
					var contentBitmap:BitmapData = renderer.graphicstoBitmapData(content.canvas.graphics, filterInstance._bmp1);
					var maskBitmap:BitmapData = renderer.graphicstoBitmapData(mask.canvas.graphics);
					if(contentBitmap != null && maskBitmap != null)
					{
						var source:Rectangle = new Rectangle(Math.round(visibleArea.x - contentBounds.x), Math.round(visibleArea.y - contentBounds.y),
							Math.floor(visibleArea.width), Math.floor(visibleArea.height));

						// for lime the alpha point is what gets added to a source pixel's position to find its pixel on the mask
						var maskOffset:Point = new Point(Math.round(contentBounds.x - maskBounds.x), Math.round(contentBounds.y - maskBounds.y));

						var target:BitmapData = filterInstance._filterFrame.parent.bitmap;
						target.copyPixels(contentBitmap, source, new Point(source.x, source.y), maskBitmap, maskOffset, false);
					}
					if(maskBitmap != null) maskBitmap.dispose();
				}
			}
			else if(filterInstance._filterFrame != null)
			{
				// nothing to show, clears what was there before
				var target:BitmapData = filterInstance._filterFrame.parent.bitmap;
				target.fillRect(target.rect, 0);
			}

			filterInstance._filterMatrix.translate(contentBounds.x, contentBounds.y);

			content.clearDrawStack();
			content.canvas.graphics.clear();
			mask.clearDrawStack();
			mask.canvas.graphics.clear();

			_maskedLayers.set(layer, layer._currFrame);
		}
	}

	// What's drawn to be kept as a bitmap (masked layers, symbols with filters or blend modes) gets the sprite's shader
	// when that bitmap is put on the screen. Drawing it with the shader as well would use it twice
	override function drawLimb(limb:flixel.graphics.frames.FlxFrame, _matrix:FlxMatrix, ?colorTransform:ColorTransform = null, filterin:Bool = false,
		?blendMode:openfl.display.BlendMode, ?scrollFactor:FlxPoint = null, cameras:Array<FlxCamera> = null)
	{
		if(blendLayers != null && !filterin)
		{
			// (on the camera of its own each camera has, which sees the same: everything is worked out for the camera it goes on)
			cameras = [for (camera in ((cameras != null) ? cameras : this.cameras)) blendLayers.exists(camera) ? blendLayers.get(camera) : camera];
		}

		if(!filterin || shader == null)
		{
			super.drawLimb(limb, _matrix, colorTransform, filterin, blendMode, scrollFactor, cameras);
			return;
		}

		var kept = shader;
		shader = null;
		super.drawLimb(limb, _matrix, colorTransform, filterin, blendMode, scrollFactor, cameras);
		shader = kept;
	}

	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;

		// A masked layer keeps a single bitmap for all of its keyframes, and the library only makes it again for the keyframes
		// it flagged while updating. Flagging every keyframe but the one the bitmap was made for makes sure it's never shown on another one
		@:privateAccess
		for (layer => rendered in _maskedLayers)
		{
			if(layer._keyframes == null) continue;

			for (keyFrame in layer._keyframes)
				if(keyFrame != rendered)
					keyFrame._renderDirty = true;
		}

		if(flipWidth == null && flipHeight == null)
		{
			super.draw();
			return;
		}

		// The library's own, with the size given for mirroring
		_matrix.identity();
		if(flipX)
		{
			_matrix.a *= -1;
			_matrix.tx += (flipWidth != null) ? flipWidth : width;
		}
		if(flipY)
		{
			_matrix.d *= -1;
			_matrix.ty += (flipHeight != null) ? flipHeight : height;
		}

		_flashRect.setEmpty();
		parseElement(anim.curInstance, _matrix, colorTransform, cameras, scrollFactor);

		width = _flashRect.width;
		height = _flashRect.height;
		frameWidth = Math.round(width);
		frameHeight = Math.round(height);

		relativeX = _flashRect.x - x;
		relativeY = _flashRect.y - y;
	}

	// ------------------------------------------------------------------------------------------
	// The whole atlas on a texture of its own
	// ------------------------------------------------------------------------------------------

	/**
	 * Draws the atlas on a texture of its own first, and that texture on the screen as if it was a single image.
	 *
	 * Each piece of an atlas is drawn by itself otherwise, and what's done to the sprite is done to every piece: a shader that lights
	 * the edges of a character lights the edges of each arm, eye and strand of hair, and a see-through sprite shows its pieces
	 * through one another. It's what V-Slice's library has under the same name (`FlxAnimate.useRenderTexture`), and with its rule:
	 * only while the sprite has something that needs it (a shader, or not being fully opaque).
	 */
	public var useRenderTexture:Bool = false;

	/**
	 * The part of that texture the atlas was last drawn on, null if it never was.
	 */
	public var wholeFrame(default, null):flixel.graphics.frames.FlxFrame = null;

	// (bigger than this and it's drawn piece by piece, as if it was off)
	static inline var WHOLE_MAX_SIZE:Int = 4096;

	var _wholeCamera:FlxCamera = null;
	var _wholeGraphic:FlxGraphic = null;
	var _wholeMatrix:FlxMatrix = new FlxMatrix();
	var _drawingWhole:Bool = false;

	inline function wantsRenderTexture():Bool
	{
		return useRenderTexture && (shader != null || alpha < 1);
	}

	/**
	 * Draws an instance of the atlas (the one on the screen) on the texture, and the texture where the instance would have been.
	 * False if it couldn't be done, and so nothing was drawn.
	 */
	function drawWhole(instance:FlxElement, m:FlxMatrix, color:ColorTransform, cameras:Array<FlxCamera>):Bool
	{
		if(cameras == null) cameras = this.cameras;
		if(_wholeCamera == null) _wholeCamera = new FlxCamera(0, 0, 0, 0, 1);

		// Its pieces, as they are on the symbol's own coordinates (what's set on the sprite is for the texture as a whole)
		@:privateAccess _wholeCamera.clearDrawStack();
		_wholeCamera.canvas.graphics.clear();

		_wholeMatrix.identity();
		_drawingWhole = true;
		super.parseElement(instance, _wholeMatrix, new ColorTransform(), {instance: instance}, [_wholeCamera]);
		_drawingWhole = false;

		@:privateAccess _wholeCamera.render();
		var bounds:Rectangle = _wholeCamera.canvas.getBounds(null);
		var wide:Int = Math.ceil(bounds.width);
		var tall:Int = Math.ceil(bounds.height);

		var drawn:Bool = (wide >= 1 && tall >= 1 && wide <= WHOLE_MAX_SIZE && tall <= WHOLE_MAX_SIZE);
		if(drawn)
		{
			// (with room to spare: the size changes on every frame of an animation, and a texture isn't cheap to make)
			if(_wholeGraphic == null || _wholeGraphic.bitmap == null || _wholeGraphic.width < wide || _wholeGraphic.height < tall)
			{
				var newWidth:Int = Std.int(Math.min(WHOLE_MAX_SIZE, Math.max(Math.ceil(wide * 1.25), (_wholeGraphic != null) ? _wholeGraphic.width : 0)));
				var newHeight:Int = Std.int(Math.min(WHOLE_MAX_SIZE, Math.max(Math.ceil(tall * 1.25), (_wholeGraphic != null) ? _wholeGraphic.height : 0)));

				_wholeGraphic = FlxDestroyUtil.destroy(_wholeGraphic);
				_wholeGraphic = FlxGraphic.fromBitmapData(new BitmapData(newWidth, newHeight, true, 0), false, null, false);
				_wholeGraphic.persist = true;
				_wholeGraphic.destroyOnNoUse = false;
				wholeFrame = null;
			}
			drawn = _renderWhole(_wholeCamera.canvas.graphics, _wholeGraphic.bitmap, bounds);
		}

		@:privateAccess _wholeCamera.clearDrawStack();
		_wholeCamera.canvas.graphics.clear();
		if(!drawn) return (wide < 1 || tall < 1); //(nothing to show is not a failure)

		@:privateAccess
		{
			if(wholeFrame == null) wholeFrame = new flixel.graphics.frames.FlxFrame(_wholeGraphic);
			if(wholeFrame.frame == null || wholeFrame.frame.width != wide || wholeFrame.frame.height != tall)
			{
				wholeFrame.frame = new FlxRect(0, 0, wide, tall);
				wholeFrame.sourceSize.set(wide, tall);
				wholeFrame.cacheFrameMatrix();
			}
		}

		var tint:ColorTransform = new ColorTransform();
		@:privateAccess
		{
			tint.__copyFrom(color);
			if(instance.symbol.colorEffect != null) tint.concat(instance.symbol.colorEffect.c_Transform);
		}

		_wholeMatrix.setTo(1, 0, 0, 1, bounds.x, bounds.y);
		_wholeMatrix.concat(m);
		drawLimb(wholeFrame, _wholeMatrix, tint, false, instance.symbol.blendMode, cameras);
		return true;
	}

	// What a camera had drawn on it, on a bitmap's texture: the texture only, the bitmap's own pixels are left as they were
	// (reading them back from the graphics card on every frame is what makes the library's own way of doing this slow)
	@:access(openfl.display.OpenGLRenderer)
	@:access(openfl.display3D.Context3D)
	@:access(openfl.display.Graphics)
	@:access(openfl.display.BitmapData)
	@:access(openfl.geom.ColorTransform)
	@:access(flxanimate.display.FlxAnimateFilterRenderer)
	@:access(openfl.display.Stage)
	@:access(openfl.display._internal.Context3DGraphics)
	function _renderWhole(graphics:openfl.display.Graphics, target:BitmapData, bounds:Rectangle):Bool
	{
		var drawer:openfl.display.OpenGLRenderer = renderer.renderer;
		if(drawer == null || graphics.__bounds == null) return false;

		var context = drawer.__context3D;
		var texture = target.getTexture(context);
		if(context == null || texture == null) return false;

		var lastTarget = context.__state.renderToTexture;
		var lastDepthStencil = context.__state.renderToTextureDepthStencil;
		var lastAntiAlias = context.__state.renderToTextureAntiAlias;
		var lastSurface = context.__state.renderToTextureSurfaceSelector;

		// (see `renderFilter()`)
		_forgetRendererState(drawer);

		drawer.__setBlendMode(NORMAL);
		drawer.__worldAlpha = 1;
		drawer.__worldColorTransform.__identity();
		drawer.__worldTransform.identity();
		drawer.__worldTransform.translate(-bounds.x, -bounds.y);

		drawer.__setRenderTarget(target);
		context.setRenderToTexture(texture);
		context.clear(0, 0, 0, 0, 1, 0, openfl.display3D.Context3DClearMask.COLOR);
		openfl.display._internal.Context3DGraphics.render(graphics, drawer);

		drawer.__worldTransform.identity();

		if(lastTarget != null) context.setRenderToTexture(lastTarget, lastDepthStencil, lastAntiAlias, lastSurface);
		else context.setRenderToBackBuffer();

		_forgetRendererState(Std.downcast(FlxG.stage.__renderer, openfl.display.OpenGLRenderer));
		return true;
	}

	override function destroy()
	{
		_maskedLayers = [];
		wholeFrame = null;
		_wholeGraphic = FlxDestroyUtil.destroy(_wholeGraphic);
		_wholeCamera = FlxDestroyUtil.destroy(_wholeCamera);

		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.curInstance = FlxDestroyUtil.destroy(anim.curInstance);
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			//anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
			anim.metadata.destroy();
			anim.symbolDictionary = null;
		}
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	function _getText(path:String):String
	{
		#if sys
		if(FileSystem.exists(path)) return File.getContent(path);
		#end
		return OpenFlAssets.exists(path, TEXT) ? OpenFlAssets.getText(path) : null;
	}

	function _getGraphic(path:String):FlxGraphic
	{
		var graphic:FlxGraphic = FlxG.bitmap.get(path);
		if(graphic != null) return graphic;

		var bitmap:BitmapData = null;
		#if sys
		if(FileSystem.exists(path)) bitmap = BitmapData.fromFile(path);
		else
		#end
		if(OpenFlAssets.exists(path, IMAGE)) bitmap = OpenFlAssets.getBitmapData(path);

		return (bitmap != null) ? FlxGraphic.fromBitmapData(bitmap, false, path) : null;
	}

	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}
