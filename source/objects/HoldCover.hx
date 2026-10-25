package objects;

import haxe.Json;

/**
 * How the hold covers of a song look: one image per direction and the animations inside of it.
 */
typedef HoldCoverStyle =
{
	var enabled:Bool;
	var assets:Array<String>; //for left, down, up and right
	var starts:Array<String>;
	var holds:Array<String>;
	var ends:Array<String>;
	var scale:Float;
	var pixel:Bool;
	var offsets:Array<Float>;
}

/**
 * The sparks V-Slice shows on a receptor while a long note is being held: it starts when the note is hit,
 * stays for as long as the note is held and, on the player's side, bursts when it's held to the end.
 *
 * There's one for each receptor, made the first time it's needed.
 */
class HoldCover extends FlxSprite
{
	public var strum:StrumNote;

	/**
	 * Time of the song when the note was last held, the cover goes away by itself a little after that.
	 */
	public var lastHit:Float = 0;

	/**
	 * If it's playing the burst of a note held to the end.
	 */
	public var ending(default, null):Bool = false;

	var style:HoldCoverStyle;

	public function new(strum:StrumNote, direction:Int, style:HoldCoverStyle)
	{
		super();
		this.strum = strum;
		this.style = style;

		direction = direction % 4;
		var atlas = Paths.getSparrowAtlas(style.assets[direction]);
		if(atlas != null)
		{
			frames = atlas;
			animation.addByPrefix('start', style.starts[direction], 24, false);
			animation.addByPrefix('hold', style.holds[direction], 24, true);
			animation.addByPrefix('end', style.ends[direction], 24, false);
			animation.finishCallback = onAnimationFinished;
		}

		antialiasing = (ClientPrefs.data.antialiasing && !style.pixel);
		scrollFactor.set();
		kill();
	}

	/**
	 * If its image was found and has what it needs.
	 */
	public var usable(get, never):Bool;
	function get_usable():Bool
		return frames != null && animation.exists('hold');

	public function playStart():Void
	{
		ending = false;
		animation.play(animation.exists('start') ? 'start' : 'hold', true);
		follow();
	}

	public function playEnd():Void
	{
		if(!animation.exists('end'))
		{
			kill();
			return;
		}

		ending = true;
		animation.play('end', true);
		follow();
	}

	function onAnimationFinished(name:String):Void
	{
		switch(name)
		{
			case 'start': animation.play('hold', true);
			case 'end': kill();
		}
	}

	// Stays on its receptor wherever it goes, with its size and transparency
	function follow():Void
	{
		if(strum == null) return;

		// what the receptors are scaled by when nothing changed them
		var baseScale:Float = (strum.lookScale > 0) ? strum.lookScale : (PlayState.isPixelStage ? PlayState.daPixelZoom : 0.7);
		var ratio:Float = (baseScale != 0) ? Math.abs(strum.scale.x) / baseScale : 1;
		var size:Float = style.scale * ratio;

		if(scale.x != size || scale.y != size)
		{
			scale.set(size, size);
			updateHitbox();
		}

		// V-Slice's own numbers, from the middle of the receptor
		x = strum.x + strum.width / 2 - width / 2 - 12 * ratio + style.offsets[0] * size;
		y = strum.y + strum.height / 2 - 153.2 * ratio + style.offsets[1] * size;

		alpha = strum.alpha;
		visible = strum.visible;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(!alive) return; //the burst just ended

		follow();

		// nothing held the note for a while: it was let go, or the song went somewhere else
		var since:Float = Conductor.songPosition - lastHit;
		if(!ending && (since > Conductor.stepCrochet * 2 || since < -Conductor.stepCrochet * 2)) kill();
	}

	override function revive():Void
	{
		super.revive();
		ending = false;
	}
}

/**
 * The hold covers of a song. PlayState tells it about the long notes being hit and let go.
 */
class HoldCoverGroup extends FlxTypedGroup<HoldCover>
{
	public var style(default, null):HoldCoverStyle;

	var covers:haxe.ds.ObjectMap<StrumNote, HoldCover> = new haxe.ds.ObjectMap();

	// The styles of the sides whose note style a V-Slice script changed (the opponent's, the player's), see `setNoteStyle()`
	var sideStyles:Array<HoldCoverStyle> = [null, null];

	/**
	 * The covers of a side take the look of another note style from now on.
	 */
	public function setNoteStyle(isPlayer:Bool, noteStyleId:String):Void
	{
		var newStyle:HoldCoverStyle = null;
		try
		{
			newStyle = fromNoteStyle(noteStyleId, 0);
		}
		catch(e:Dynamic)
		{
			trace('Could not read the hold covers of the note style "$noteStyleId": $e');
			return;
		}
		sideStyles[isPlayer ? 1 : 0] = newStyle;

		if(enabled)
			for (asset in newStyle.assets)
				if(Paths.fileExists('images/$asset.png', IMAGE))
					Paths.image(asset);

		// the side's covers are made again with it
		var game:PlayState = PlayState.instance;
		var strums:Array<StrumNote> = (game == null) ? [] : (isPlayer ? game.playerStrums.members : game.opponentStrums.members);
		for (strum in strums)
		{
			var cover:HoldCover = (strum != null) ? covers.get(strum) : null;
			if(cover == null) continue;
			covers.remove(strum);
			remove(cover, true);
			cover.destroy();
		}
	}

	function styleOf(strum:StrumNote):HoldCoverStyle
	{
		var game:PlayState = PlayState.instance;
		if(game != null)
		{
			var side:Int = game.playerStrums.members.contains(strum) ? 1 : (game.opponentStrums.members.contains(strum) ? 0 : -1);
			if(side >= 0 && sideStyles[side] != null) return sideStyles[side];
		}
		return style;
	}

	public function new()
	{
		super();
		style = getSongStyle();

		// loaded with the song instead of on the first long note
		if(enabled)
			for (asset in style.assets)
				if(Paths.fileExists('images/$asset.png', IMAGE))
					Paths.image(asset);
	}

	public var enabled(get, never):Bool;
	function get_enabled():Bool
		return ClientPrefs.data.holdCovers && style != null && style.enabled;

	/**
	 * A long note, or one of the pieces of its trail, was hit.
	 *
	 * @param strum 	Receptor it was hit on.
	 * @param burst 	If holding it to the end makes the cover burst, which is for who's playing.
	 */
	public function noteHit(note:Note, strum:StrumNote, burst:Bool):Void
	{
		if(!enabled || note == null || strum == null || note.hitCausesMiss) return;

		var head:Note = note.isSustainNote ? note.parent : note;
		if(head == null || head.tail == null || head.tail.length < 1) return;

		var cover:HoldCover = covers.get(strum);
		if(cover == null)
		{
			cover = new HoldCover(strum, note.noteData, styleOf(strum));
			covers.set(strum, cover);
			add(cover);
		}
		if(!cover.usable) return;

		// the last piece of the trail
		if(note.isSustainNote && head.tail[head.tail.length - 1] == note)
		{
			if(burst)
			{
				if(!cover.alive) cover.revive();
				cover.playEnd();
			}
			else if(cover.alive) cover.kill();
			return;
		}

		if(!cover.alive || cover.ending)
		{
			if(!cover.alive) cover.revive();
			cover.playStart();
		}
		cover.lastHit = Conductor.songPosition;
	}

	/**
	 * The long note of a receptor was let go.
	 */
	public function drop(strum:StrumNote):Void
	{
		var cover:HoldCover = (strum != null) ? covers.get(strum) : null;
		if(cover != null && cover.alive && !cover.ending) cover.kill();
	}

	public function killAll():Void
	{
		for (cover in members)
			if(cover != null && cover.alive) cover.kill();
	}

	// ------------------------------------------------------------------------------------------
	// Styles
	// ------------------------------------------------------------------------------------------

	static var directions:Array<String> = ['left', 'down', 'up', 'right'];

	public static function defaultStyle():HoldCoverStyle
	{
		var colors:Array<String> = ['Purple', 'Blue', 'Green', 'Red'];
		return {
			enabled: true,
			assets: [for (color in colors) 'holdCover$color'],
			starts: [for (color in colors) 'holdCoverStart$color'],
			holds: [for (color in colors) 'holdCover$color'],
			ends: [for (color in colors) 'holdCoverEnd$color'],
			scale: 1,
			pixel: false,
			offsets: [0, 0]
		};
	}

	public static function pixelStyle():HoldCoverStyle
	{
		return {
			enabled: true,
			assets: [for (i in 0...4) 'pixelUI/noteHoldCover'],
			starts: [for (i in 0...4) 'loop0000'],
			holds: [for (i in 0...4) 'loop'],
			ends: [for (i in 0...4) 'explode'],
			scale: 6,
			pixel: true,
			offsets: [28, -0.5]
		};
	}

	/**
	 * The style of the song being played: the one of its note style if it's from a V-Slice mod, the engine's own otherwise.
	 */
	public static function getSongStyle():HoldCoverStyle
	{
		var song:Dynamic = PlayState.SONG;
		if(song != null && song.vslice != null && song.vslice.noteStyle != null)
		{
			try
			{
				return fromNoteStyle(song.vslice.noteStyle, 0);
			}
			catch(e:Dynamic)
			{
				trace('Could not read the hold covers of the note style "${song.vslice.noteStyle}": $e');
			}
		}
		return PlayState.isPixelStage ? pixelStyle() : defaultStyle();
	}

	// What a V-Slice note style file says about its hold covers, on top of what the style it falls back to says
	public static function fromNoteStyle(id:String, depth:Int = 0):HoldCoverStyle
	{
		var raw:String = Paths.getTextFromFile('data/notestyles/$id.json');
		if(raw == null) return (id == 'pixel') ? pixelStyle() : defaultStyle();

		var data:Dynamic = Json.parse(raw);
		var fallback:String = (data.fallback != null) ? data.fallback : 'funkin';
		var style:HoldCoverStyle = (fallback != id && depth < 5) ? fromNoteStyle(fallback, depth + 1) : defaultStyle();

		var cover:Dynamic = (data.assets != null) ? data.assets.holdNoteCover : null;
		if(cover == null) return style;

		if(cover.scale != null) style.scale = cover.scale;
		if(cover.isPixel != null) style.pixel = (cover.isPixel == true);
		if(cover.offsets != null && cover.offsets.length > 1) style.offsets = [cover.offsets[0], cover.offsets[1]];

		var rootAsset:String = stripLibrary(cover.assetPath);
		var perDirection:Dynamic = cover.data;
		if(perDirection != null && perDirection.enabled != null) style.enabled = (perDirection.enabled == true);

		for (num => direction in directions)
		{
			var entry:Dynamic = (perDirection != null) ? Reflect.field(perDirection, direction) : null;
			var asset:String = (entry != null) ? stripLibrary(entry.assetPath) : null;
			if(asset == null) asset = rootAsset;
			if(asset != null) style.assets[num] = asset;

			if(entry == null) continue;
			if(entry.start != null && entry.start.prefix != null) style.starts[num] = entry.start.prefix;
			if(entry.hold != null && entry.hold.prefix != null) style.holds[num] = entry.hold.prefix;
			if(entry.end != null && entry.end.prefix != null) style.ends[num] = entry.end.prefix;
		}
		return style;
	}

	// "shared:holdCoverRed" -> "holdCoverRed", nothing if there's no path
	static function stripLibrary(path:String):String
	{
		if(path == null) return null;

		var colon:Int = path.indexOf(':');
		if(colon > -1) path = path.substr(colon + 1);
		return (path.length > 0) ? path : null;
	}
}
