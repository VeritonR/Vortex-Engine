package funkin.play.notes.notestyle;

import funkin.graphics.FunkinSprite;
import flixel.graphics.frames.FlxAtlasFrames;

/**
 * A note style of V-Slice (`data/notestyles/(id).json`): how the notes, the countdown and the ratings of a song look and sound.
 * The engine draws those with its own notes, receptors and splashes: a style gives them its look (`applyToNote()`, `applyToStrum()`,
 * `getSplashTexture()`), and scripts read it to make something of their own with it (a countdown of a mod, made out of the style's
 * pictures and sounds). Whatever a style doesn't have comes from its `fallback`.
 */
class NoteStyle
{
	public var id(default, null):String;
	public var fallback(get, never):NoteStyle;

	var data:Dynamic;

	public function new(id:String, data:Dynamic)
	{
		this.id = id;
		this.data = (data != null) ? data : {};
	}

	function get_fallback():NoteStyle
	{
		var fallbackId:String = (data.fallback != null) ? Std.string(data.fallback) : null;
		if(fallbackId == null || fallbackId == id) return null;
		return funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry(fallbackId);
	}

	public function getName():String return (data.name != null) ? Std.string(data.name) : id;
	public function getAuthor():String return (data.author != null) ? Std.string(data.author) : 'Unknown';
	public function getFallbackID():String return (data.fallback != null) ? Std.string(data.fallback) : null;

	// ------------------------------------------------------------------------------------------
	// Paths of the style's pictures, like V-Slice's: as written on the file with `raw` ("library:path"), without the library if not.
	// What the style doesn't have comes from its fallback
	// ------------------------------------------------------------------------------------------

	// The `assetPath` of one of the style's assets, by its name on the file ("note", "holdNote", "noteStrumline"...)
	function rawAssetPath(name:String):String
	{
		var assets:Dynamic = data.assets;
		var asset:Dynamic = (assets != null) ? Reflect.field(assets, name) : null;
		return (asset != null && asset.assetPath != null) ? Std.string(asset.assetPath) : null;
	}

	static function withoutLibrary(path:String):String
	{
		if(path == null) return null;
		var colon:Int = path.indexOf(':');
		return (colon > -1) ? path.substr(colon + 1) : path;
	}

	public function getNoteAssetPath(raw:Bool = false):String
	{
		var path:String = rawAssetPath('note');
		if(path == null) return (fallback != null) ? fallback.getNoteAssetPath(raw) : null;
		return raw ? path : withoutLibrary(path);
	}

	/**
	 * The hold notes' picture. Without `raw` it's the whole path of the file, like V-Slice's ("images/" and ".png" included).
	 */
	public function getHoldNoteAssetPath(raw:Bool = false):String
	{
		var path:String = rawAssetPath('holdNote');
		if(path == null) return (fallback != null) ? fallback.getHoldNoteAssetPath(raw) : null;
		return raw ? path : 'images/' + withoutLibrary(path) + '.png';
	}

	public function getStrumlineAssetPath(raw:Bool = false):String
	{
		var path:String = rawAssetPath('noteStrumline');
		if(path == null) return (fallback != null) ? fallback.getStrumlineAssetPath(raw) : null;
		return raw ? path : withoutLibrary(path);
	}

	public function getSplashAssetPath(raw:Bool = false):String
	{
		var path:String = rawAssetPath('noteSplash');
		if(path == null) return (fallback != null) ? fallback.getSplashAssetPath(raw) : null;
		return raw ? path : withoutLibrary(path);
	}

	/**
	 * The hold covers' picture of a direction: the direction's own, then the one of all directions, then the fallback's.
	 */
	public function getHoldCoverDirectionAssetPath(direction:Int, raw:Bool = false):String
	{
		var cover:Dynamic = (data.assets != null) ? data.assets.holdNoteCover : null;
		var path:String = null;
		if(cover != null)
		{
			var directions:Dynamic = cover.data;
			var own:Dynamic = (directions != null) ? Reflect.field(directions, funkin.play.notes.NoteDirection.getName(direction)) : null;
			if(own != null && own.assetPath != null) path = Std.string(own.assetPath);
			else if(cover.assetPath != null) path = Std.string(cover.assetPath);
		}
		if(path == null) return (fallback != null) ? fallback.getHoldCoverDirectionAssetPath(direction, raw) : null;
		return raw ? path : withoutLibrary(path);
	}

	public function buildJudgementSpritePath(rating:String):String
	{
		var name:String = switch(rating)
		{
			case 'sick': 'judgementSick';
			case 'good': 'judgementGood';
			case 'bad': 'judgementBad';
			case 'shit': 'judgementShit';
			default: null;
		}
		var path:String = (name != null) ? rawAssetPath(name) : null;
		if(path == null) return (fallback != null) ? fallback.buildJudgementSpritePath(rating) : null;
		return withoutLibrary(path);
	}

	public function buildComboNumSpritePath(digit:Int):String
	{
		var path:String = (digit >= 0 && digit <= 9) ? rawAssetPath('comboNumber$digit') : null;
		if(path == null) return (fallback != null) ? fallback.buildComboNumSpritePath(digit) : null;
		return withoutLibrary(path);
	}

	// The style's part for a step of the countdown ("THREE", "TWO", "ONE", "GO")
	function countdownAsset(step:String):Dynamic
	{
		var assets:Dynamic = data.assets;
		if(assets == null) return null;
		return switch(step)
		{
			case 'THREE': assets.countdownThree;
			case 'TWO': assets.countdownTwo;
			case 'ONE': assets.countdownOne;
			case 'GO': assets.countdownGo;
			default: null;
		}
	}

	public function buildCountdownSprite(step:String):FunkinSprite
	{
		var asset:Dynamic = countdownAsset(step);
		if(asset == null) return (fallback != null) ? fallback.buildCountdownSprite(step) : null;

		var path:String = buildCountdownSpritePath(step);
		if(path == null) return null;

		var sprite:FunkinSprite = new FunkinSprite();
		sprite.loadTexture(path);
		var scale:Float = (asset.scale != null) ? asset.scale : 1;
		sprite.scale.set(scale, scale);
		return sprite;
	}

	public function buildCountdownSpritePath(step:String):String
	{
		var asset:Dynamic = countdownAsset(step);
		var path:String = (asset != null && asset.assetPath != null) ? Std.string(asset.assetPath) : null;
		if(path == null) return (fallback != null) ? fallback.buildCountdownSpritePath(step) : null;
		return backend.VSliceConvert.stripLibrary(path);
	}

	public function isCountdownSpritePixel(step:String):Bool
	{
		var asset:Dynamic = countdownAsset(step);
		if(asset != null && asset.isPixel != null) return asset.isPixel == true;
		return (fallback != null) ? fallback.isCountdownSpritePixel(step) : false;
	}

	public function getCountdownSpriteOffsets(step:String):Array<Float>
	{
		var asset:Dynamic = countdownAsset(step);
		if(asset != null && asset.offsets != null) return asset.offsets;
		return (fallback != null) ? fallback.getCountdownSpriteOffsets(step) : [0, 0];
	}

	/**
	 * The sound of a step of the countdown: the sound itself, or its path ("library:path") with `raw`.
	 */
	public function getCountdownSoundPath(step:String, raw:Bool = false):Dynamic
	{
		var asset:Dynamic = countdownAsset(step);
		var path:String = (asset != null && asset.data != null && asset.data.audioPath != null) ? Std.string(asset.data.audioPath) : null;
		if(path == null) return (fallback != null) ? fallback.getCountdownSoundPath(step, raw) : null;
		if(raw) return path;
		return funkin.Paths.sound(path);
	}

	public function isHoldNoteCoverEnabled():Bool
	{
		var assets:Dynamic = data.assets;
		if(assets != null && assets.holdNoteCover != null) return assets.holdNoteCover.enabled != false;
		return (fallback != null) ? fallback.isHoldNoteCoverEnabled() : true;
	}

	public function isNoteSplashEnabled():Bool
	{
		var assets:Dynamic = data.assets;
		var splash:Dynamic = (assets != null) ? assets.noteSplash : null;
		if(splash != null && splash.data != null && splash.data.enabled != null) return splash.data.enabled == true;
		return (fallback != null) ? fallback.isNoteSplashEnabled() : true;
	}

	/**
	 * Path of a picture of the style (`assets.note`, `assets.noteStrumline`...), without its library.
	 */
	public function getAssetPath(name:String):String
	{
		var assets:Dynamic = data.assets;
		var asset:Dynamic = (assets != null) ? Reflect.field(assets, name) : null;
		if(asset == null || asset.assetPath == null) return (fallback != null) ? fallback.getAssetPath(name) : null;
		return backend.VSliceConvert.stripLibrary(Std.string(asset.assetPath));
	}

	// ------------------------------------------------------------------------------------------
	// The style on the engine's notes, receptors and splashes (V-Slice's `buildNoteSprite()`, `applyStrumlineFrames()`,
	// `applyStrumlineAnimations()` and `buildSplashSprite()`, done to Psych's)
	// ------------------------------------------------------------------------------------------

	static final DIRECTION_NAMES:Array<String> = ['left', 'down', 'up', 'right'];

	// One of the style's parts ("note", "noteStrumline", "holdNote", "noteSplash"): the first of the style and its fallbacks that has
	// a picture for it
	function part(name:String):Dynamic
	{
		var assets:Dynamic = data.assets;
		var found:Dynamic = (assets != null) ? Reflect.field(assets, name) : null;
		if(found != null && found.assetPath != null) return found;
		return (fallback != null) ? fallback.part(name) : null;
	}

	// A value of one of the style's parts, the fallback's when the style doesn't have it
	function partValue(name:String, field:String):Dynamic
	{
		var assets:Dynamic = data.assets;
		var found:Dynamic = (assets != null) ? Reflect.field(assets, name) : null;
		var value:Dynamic = (found != null) ? Reflect.field(found, field) : null;
		if(value != null) return value;
		return (fallback != null) ? fallback.partValue(name, field) : null;
	}

	// An animation (or another value of its "data") of one of the style's parts, by its name on the file ("left", "leftStatic"...)
	function partAnimation(name:String, animation:String):Dynamic
	{
		var assets:Dynamic = data.assets;
		var found:Dynamic = (assets != null) ? Reflect.field(assets, name) : null;
		var animations:Dynamic = (found != null) ? found.data : null;
		var value:Dynamic = (animations != null) ? Reflect.field(animations, animation) : null;
		if(value != null) return value;
		return (fallback != null) ? fallback.partAnimation(name, animation) : null;
	}

	/**
	 * If one of the style's parts is drawn the way the engine draws it anyway: the base game's style has the same picture for it
	 * ("funkin", or "pixel" on the pixel stages). Those keep the engine's own look, with the colors and skins of its options.
	 */
	public function usesEngineLook(name:String):Bool
	{
		var baseId:String = states.PlayState.isPixelStage ? 'pixel' : 'funkin';
		var own:Dynamic = part(name);
		if(own == null) return true;

		// (the base game's own: a mod can have a "funkin" style of its own, that changes it)
		var base:NoteStyle = funkin.data.notestyle.NoteStyleRegistry.instance.fetchBaseEntry(baseId);
		if(base == null) return id == baseId;
		var basePart:Dynamic = (base != null) ? base.part(name) : null;
		return basePart != null && withoutLibrary(Std.string(basePart.assetPath)) == withoutLibrary(Std.string(own.assetPath));
	}

	function isPartPixel(name:String):Bool
		return partValue(name, 'isPixel') == true;

	function partScale(name:String):Float
	{
		var scale:Dynamic = partValue(name, 'scale');
		return (scale != null) ? scale : 1.0;
	}

	// (a song has thousands of notes, each of them would read the spritesheet's file again)
	static var sheets:Map<String, FlxAtlasFrames> = [];
	static var sheetScreens:Map<String, Int> = [];
	static var screen:Int = 0;
	static var countingScreens:Bool = false;

	static function partSheet(info:Dynamic):FlxAtlasFrames
	{
		if(info == null || info.assetPath == null) return null;

		if(!countingScreens)
		{
			countingScreens = true;
			FlxG.signals.preStateCreate.add(function(_) screen++);
		}

		var path:String = withoutLibrary(Std.string(info.assetPath));
		var frames:FlxAtlasFrames = sheets.get(path);
		if(frames != null && sheetScreens.get(path) == screen && frames.parent != null && frames.parent.bitmap != null) return frames;

		try
		{
			// Once on each screen the image is asked for again: the game frees the images a new screen didn't ask for, and these frames
			// would be left with a freed one (the notes and receptors made with them showed flixel's logo instead). It also gives the one
			// that's loaded now, when the one they were made with was freed already
			var graphic:flixel.graphics.FlxGraphic = Paths.image(path);
			if(graphic == null || graphic.bitmap == null) return null;

			if(frames == null || frames.parent != graphic)
			{
				frames = Paths.getSparrowAtlas(path);
				if(frames == null || frames.frames.length < 1) return null;
			}
			sheets.set(path, frames);
			sheetScreens.set(path, screen);
			return frames;
		}
		catch(e:Dynamic) {}
		return null;
	}

	// Adds one of the style's animations to a sprite: by its prefix, or by its frames for the ones that pick them
	static function addAnimation(sprite:FlxSprite, name:String, anim:Dynamic, looped:Bool = false):Bool
	{
		if(anim == null || anim.prefix == null) return false;

		var frameRate:Float = (anim.frameRate != null) ? anim.frameRate : 24;
		var loop:Bool = (anim.looped != null) ? anim.looped == true : looped;
		var flipX:Bool = anim.flipX == true;
		var flipY:Bool = anim.flipY == true;
		var indices:Array<Int> = anim.frameIndices;
		if(indices != null && indices.length > 0) sprite.animation.addByIndices(name, Std.string(anim.prefix), indices, '', frameRate, loop, flipX, flipY);
		else sprite.animation.addByPrefix(name, Std.string(anim.prefix), frameRate, loop, flipX, flipY);
		return sprite.animation.exists(name);
	}

	/**
	 * Gives a note (or a piece of a long note) the style's look, with its middle staying where it is on its receptor. False when the
	 * style doesn't have one for it, then it's left as it was.
	 */
	public function applyToNote(note:objects.Note):Bool
	{
		if(note == null || note.noteData < 0) return false;
		if(!(note.isSustainNote ? applyToHoldPiece(note) : applyToNoteHead(note))) return false;
		note.hasStyleLook = true;
		return true;
	}

	function applyToNoteHead(note:objects.Note):Bool
	{
		var frames:FlxAtlasFrames = partSheet(part('note'));
		if(frames == null) return false;

		var direction:Int = note.noteData % 4;
		var name:String = objects.Note.colArray[direction] + 'Scroll';
		var anim:Dynamic = partAnimation('note', DIRECTION_NAMES[direction]);
		if(anim == null || anim.prefix == null) return false;

		var oldWidth:Float = note.width;
		note.frames = frames;
		if(!addAnimation(note, name, anim)) return false;

		// V-Slice's notes don't play their animation unless the style says they're animated (`NoteSprite.active`): they stay on the first
		// frame, whatever else the prefix finds ("purple" also finds "purple hold piece")
		if(!isNoteAnimated())
		{
			var added:flixel.animation.FlxAnimation = note.animation.getByName(name);
			if(added != null && added.frames.length > 1) note.animation.add(name, [added.frames[0]], 0, false);
		}

		var scale:Float = partScale('note');
		note.scale.set(scale, scale);
		note.animation.play(name, true);
		note.updateHitbox();
		note.centerOffsets();
		note.centerOrigin();
		note.antialiasing = !isPartPixel('note') && ClientPrefs.data.antialiasing;
		if(note.rgbShader != null) note.rgbShader.enabled = false;

		// (its middle stays where it was: the engine's notes are as wide as the room its receptors have for them)
		note.offsetX += (oldWidth - note.width) / 2;
		return true;
	}

	// A long note's picture is of 8 columns, two for each direction: the piece that repeats and the end (see V-Slice's SustainTrail)
	static var holdSheets:Map<String, FlxAtlasFrames> = [];

	function holdSheet():FlxAtlasFrames
	{
		var info:Dynamic = part('holdNote');
		if(info == null || info.assetPath == null) return null;

		var path:String = withoutLibrary(Std.string(info.assetPath));
		var graphic:flixel.graphics.FlxGraphic = Paths.image(path);
		if(graphic == null || graphic.bitmap == null) return null;

		var frames:FlxAtlasFrames = holdSheets.get(path);
		if(frames != null && frames.parent == graphic) return frames;

		var bottom:Float = isPartPixel('holdNote') ? 1 : 0.9;
		var column:Float = graphic.width / 8;
		frames = new FlxAtlasFrames(graphic);
		for (direction in 0...4)
		{
			var piece:flixel.math.FlxRect = flixel.math.FlxRect.get(column * direction * 2, 0, column, graphic.height);
			var end:flixel.math.FlxRect = flixel.math.FlxRect.get(column * (direction * 2 + 1), 0, column, Math.floor(graphic.height * bottom));
			frames.addAtlasFrame(piece, FlxPoint.get(piece.width, piece.height), FlxPoint.get(), 'holdPiece$direction');
			frames.addAtlasFrame(end, FlxPoint.get(end.width, end.height), FlxPoint.get(), 'holdEnd$direction');
		}
		holdSheets.set(path, frames);
		return frames;
	}

	function applyToHoldPiece(note:objects.Note):Bool
	{
		var frames:FlxAtlasFrames = holdSheet();
		if(frames == null) return false;

		var direction:Int = note.noteData % 4;
		var color:String = objects.Note.colArray[direction];
		var isEnd:Bool = note.animation.curAnim == null || StringTools.endsWith(note.animation.curAnim.name, 'holdend');
		var oldWidth:Float = note.width;
		var oldHeight:Float = note.height;

		note.frames = frames;
		note.animation.addByPrefix(color + 'hold', 'holdPiece$direction', 24, true);
		note.animation.addByPrefix(color + 'holdend', 'holdEnd$direction', 24, true);
		note.animation.play(color + (isEnd ? 'holdend' : 'hold'), true);

		// the pieces keep the length they were given for the song's speed, the end keeps the style's size
		var scale:Float = partScale('holdNote');
		note.scale.x = scale;
		note.scale.y = isEnd ? scale : oldHeight / note.frameHeight;
		note.updateHitbox();
		note.antialiasing = !isPartPixel('holdNote') && ClientPrefs.data.antialiasing;
		if(note.rgbShader != null) note.rgbShader.enabled = false;

		note.offsetX += (oldWidth - note.width) / 2;
		return true;
	}

	/**
	 * Gives a receptor the style's look, with its middle staying where it is.
	 */
	public function applyToStrum(strum:objects.StrumNote):Bool
	{
		if(strum == null) return false;

		var frames:FlxAtlasFrames = partSheet(part('noteStrumline'));
		if(frames == null) return false;

		var direction:String = DIRECTION_NAMES[strum.noteDirection % 4];
		var animations:Array<{name:String, data:Dynamic}> = [
			{name: 'static', data: partAnimation('noteStrumline', direction + 'Static')},
			{name: 'pressed', data: partAnimation('noteStrumline', direction + 'Press')},
			{name: 'confirm', data: partAnimation('noteStrumline', direction + 'Confirm')},
			{name: 'confirm-hold', data: partAnimation('noteStrumline', direction + 'ConfirmHold')}
		];
		if(animations[0].data == null) return false;

		var built:Array<{name:String, data:Dynamic}> = [for (anim in animations) if(anim.data != null) anim];
		strum.takeLook(frames, function(sprite:FlxSprite) for (anim in built) addAnimation(sprite, anim.name, anim.data),
			partScale('noteStrumline'), isPartPixel('noteStrumline'), getStrumlineSize());
		return true;
	}

	/**
	 * Where the receptors of the style are put from their place (the "offsets" of its receptors).
	 */
	public function getStrumlineOffsets():Array<Float>
	{
		var offsets:Array<Float> = partValue('noteStrumline', 'offsets');
		return (offsets != null && offsets.length > 1) ? offsets : [0, 0];
	}

	public function applyStrumlineOffsets(target:Dynamic):Void
	{
		if(target == null) return;
		var offsets:Array<Float> = getStrumlineOffsets();
		target.x += offsets[0];
		target.y += offsets[1];
	}

	/**
	 * The texture of the style's splashes for the engine's (`objects.NoteSplash`), set up with what they are on V-Slice: their
	 * animations, how fast they go, their size and where they go on the receptor. Null when they're the engine's own or can't be found.
	 */
	public function getSplashTexture():String
	{
		var info:Dynamic = part('noteSplash');
		if(info == null || usesEngineLook('noteSplash')) return null;

		var texture:String = withoutLibrary(Std.string(info.assetPath));
		var key:String = 'images/$texture';
		if(objects.NoteSplash.configs.exists(key)) return texture;

		var frames:FlxAtlasFrames = partSheet(info);
		if(frames == null) return null;

		var scale:Float = partScale('noteSplash');
		var rate:Dynamic = partAnimation('noteSplash', 'framerateDefault');
		var variance:Dynamic = partAnimation('noteSplash', 'framerateVariance');
		var frameRate:Int = (rate != null) ? Std.int(rate) : 24;
		var change:Int = (variance != null) ? Std.int(variance) : 2;

		var lists:Array<Array<Dynamic>> = [];
		var count:Int = 0;
		for (direction in DIRECTION_NAMES)
		{
			var list:Array<Dynamic> = partAnimation('noteSplash', direction + 'Splashes');
			if(list == null || list.length < 1) return null;
			lists.push(list);
			if(list.length > count) count = list.length;
		}

		var config:objects.NoteSplash.NoteSplashConfig = objects.NoteSplash.createConfig();
		config.allowRGB = false;
		config.allowPixel = false;
		for (variant in 0...count)
		{
			for (direction => list in lists)
			{
				var anim:Dynamic = list[variant % list.length];
				var indices:Array<Int> = (anim.frameIndices != null) ? anim.frameIndices : [];
				objects.NoteSplash.addAnimationToConfig(config, scale, 'splash' + DIRECTION_NAMES[direction].toUpperCase() + variant,
					Std.string(anim.prefix), [frameRate - change, frameRate + change], [0, 0], indices, direction + variant * 4);
			}
		}

		var offsets:Array<Float> = partValue('noteSplash', 'offsets');
		if(offsets == null || offsets.length < 2) offsets = [0, 0];
		var first:flixel.graphics.frames.FlxFrame = frames.frames[0];
		var alpha:Dynamic = partValue('noteSplash', 'alpha');
		config.vslice = {
			offsetX: offsets[0],
			offsetY: offsets[1],
			width: first.sourceSize.x * scale,
			height: first.sourceSize.y * scale,
			pixel: isPartPixel('noteSplash'),
			alpha: (alpha != null) ? alpha : 1.0
		};
		objects.NoteSplash.configs.set(key, config);
		return texture;
	}

	/**
	 * The picture of one of the style's ratings or combo numbers ("judgementSick", "comboNumber0"...), its size and if it's pixel art.
	 * Null when the style draws it like the base game's style does: the engine's own is used then.
	 */
	public function getPopUpLook(name:String):{path:String, scale:Float, pixel:Bool}
	{
		var info:Dynamic = part(name);
		if(info == null || usesEngineLook(name)) return null;

		var path:String = withoutLibrary(Std.string(info.assetPath));
		if(!Paths.fileExists('images/$path.png', IMAGE)) return null;
		return {path: path, scale: partScale(name), pixel: isPartPixel(name)};
	}

	// ------------------------------------------------------------------------------------------
	// The rest of what V-Slice's note styles tell about themselves
	// ------------------------------------------------------------------------------------------

	public function buildNoteSprite(target:Dynamic):Void
	{
		var note:objects.Note = Std.isOfType(target, NoteSprite) ? cast(target, NoteSprite).note : Std.downcast(target, objects.Note);
		if(note != null) applyToNote(note);
	}

	public function applyStrumlineFrames(target:Dynamic):Void
	{
		var strum:objects.StrumNote = Std.downcast(target, objects.StrumNote);
		if(strum != null && !usesEngineLook('noteStrumline')) applyToStrum(strum);
	}

	// (given with the frames, by `applyStrumlineFrames()`)
	public function applyStrumlineAnimations(target:Dynamic, ?direction:Dynamic):Void {}

	public function buildSplashSprite(target:Dynamic):Void {}
	public function buildHoldCoverSprite(target:Dynamic):Void {}

	public function isNoteAnimated():Bool return partValue('note', 'animated') == true;
	public function getNoteScale():Float return partScale('note');
	public function getNoteOffsets():Array<Float> return offsetsOf('note');

	public function isHoldNotePixel():Bool return isPartPixel('holdNote');
	public function fetchHoldNoteScale():Float return partScale('holdNote');
	public function getHoldNoteOffsets():Array<Float> return offsetsOf('holdNote');

	public function isSplashAnimated():Bool return partValue('noteSplash', 'animated') == true;
	public function getSplashScale():Float return partScale('noteSplash');
	public function getSplashOffsets():Array<Float> return offsetsOf('noteSplash');
	public function getSplashFramerate():Int
	{
		var rate:Dynamic = partAnimation('noteSplash', 'framerateDefault');
		return (rate != null) ? Std.int(rate) : 24;
	}
	public function getSplashFramerateVariance():Int
	{
		var variance:Dynamic = partAnimation('noteSplash', 'framerateVariance');
		return (variance != null) ? Std.int(variance) : 2;
	}

	public function getHoldCoverOffsets():Array<Float> return offsetsOf('holdNoteCover');

	public function isJudgementSpritePixel(rating:String):Bool return isPartPixel(judgementName(rating));
	public function getJudgementSpriteOffsets(rating:String):Array<Float> return offsetsOf(judgementName(rating));
	public function buildJudgementSprite(rating:String):FunkinSprite return buildPopUpSprite(judgementName(rating));

	public function isComboNumSpritePixel(digit:Int):Bool return isPartPixel('comboNumber$digit');
	public function getComboNumSpriteOffsets(digit:Int):Array<Float> return offsetsOf('comboNumber$digit');
	public function buildComboNumSprite(digit:Int):FunkinSprite return buildPopUpSprite('comboNumber$digit');

	static function judgementName(rating:String):String
		return (rating == null || rating.length < 1) ? 'judgementSick' : 'judgement' + rating.charAt(0).toUpperCase() + rating.substr(1).toLowerCase();

	function offsetsOf(name:String):Array<Float>
	{
		var offsets:Array<Float> = partValue(name, 'offsets');
		return (offsets != null && offsets.length > 1) ? offsets : [0, 0];
	}

	function buildPopUpSprite(name:String):FunkinSprite
	{
		var info:Dynamic = part(name);
		if(info == null) return null;

		var sprite:FunkinSprite = new FunkinSprite();
		sprite.loadTexture(withoutLibrary(Std.string(info.assetPath)));
		var scale:Float = partScale(name);
		sprite.scale.set(scale, scale);
		sprite.updateHitbox();
		sprite.antialiasing = !isPartPixel(name) && ClientPrefs.data.antialiasing;
		return sprite;
	}

	public function destroy():Void {}

	public function getStrumlineScale():Float
	{
		var asset:Dynamic = (data.assets != null) ? data.assets.noteStrumline : null;
		if(asset == null || asset.scale == null) return (fallback != null) ? fallback.getStrumlineScale() : 1.0;
		return asset.scale;
	}

	/**
	 * How much room one of the style's receptors takes on V-Slice: the first picture of their spritesheet at their scale, with the
	 * picture centered on it (`StrumlineNote.setup()`). Null when the spritesheet can't be found.
	 */
	public function getStrumlineSize():FlxPoint
	{
		var asset:Dynamic = (data.assets != null) ? data.assets.noteStrumline : null;
		if(asset == null || asset.assetPath == null) return (fallback != null) ? fallback.getStrumlineSize() : null;

		var sheet:String = readSheet(withoutLibrary(Std.string(asset.assetPath)));
		if(sheet == null) return null;

		try
		{
			for (frame in Xml.parse(sheet).firstElement().elementsNamed('SubTexture'))
			{
				var width:Null<Float> = Std.parseFloat(frame.exists('frameWidth') ? frame.get('frameWidth') : frame.get('width'));
				var height:Null<Float> = Std.parseFloat(frame.exists('frameHeight') ? frame.get('frameHeight') : frame.get('height'));
				if(Math.isNaN(width) || Math.isNaN(height)) return null;

				var scale:Float = getStrumlineScale();
				return FlxPoint.get(width * scale, height * scale);
			}
		}
		catch(e:Dynamic) {}
		return null;
	}

	// The text of a spritesheet's file (".xml") of the style, by the path of its picture
	static function readSheet(key:String):String
	{
		#if MODS_ALLOWED
		var modFile:String = Paths.modsXml(key);
		if(FileSystem.exists(modFile)) return File.getContent(modFile);

		for (mod in [Mods.currentModDirectory, backend.PolymodCompat.BASE_MOD])
		{
			if(mod == null || mod.length < 1) continue;
			var found:String = backend.PolymodCompat.findFile(mod, 'images/$key.xml');
			if(found != null) return File.getContent(found);
		}
		#end

		var path:String = Paths.getPath('images/$key.xml', TEXT);
		#if sys
		if(FileSystem.exists(path)) return File.getContent(path);
		#end
		return openfl.utils.Assets.exists(path, TEXT) ? openfl.utils.Assets.getText(path) : null;
	}

	public function toString():String return 'NoteStyle($id)';
}
