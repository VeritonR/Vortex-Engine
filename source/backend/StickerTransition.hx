package backend;

import flixel.FlxState;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.graphics.FlxGraphic;
import haxe.Json;
import openfl.display.BitmapData;
import openfl.media.Sound;

#if sys
import sys.FileSystem;
#end

/**
 * One of the stickers that cover the screen.
 */
class StickerSprite extends FlxSprite
{
	/**
	 * Seconds from the start of the transition to when it's put on the screen, and from the new state showing up to when it's taken off.
	 */
	public var timing:Float = 0;

	public function new(graphic:FlxGraphic)
	{
		super();
		loadGraphic(graphic);
		antialiasing = ClientPrefs.data.antialiasing;
		updateHitbox();
		scrollFactor.set();
		visible = false;
	}
}

/**
 * V-Slice's sticker transition: stickers get slapped all over the screen one by one, the state changes behind them
 * and they come off the same way. It's used when leaving a song for the menus.
 *
 * Which stickers show up comes from a sticker pack ("data/stickerpacks/(id).json", same format as V-Slice):
 * the one of the song if it's from a V-Slice mod and has one, the one of the player character otherwise.
 * The sounds are one of the folders inside "sounds/stickersounds".
 *
 * The stickers live outside of the states, on a layer of their own over the game, since they have to outlast the state they started on.
 */
class StickerTransition
{
	public static inline var DEFAULT_PACK:String = 'default';

	/**
	 * If a transition is going on, from its first sticker to its last one coming off.
	 */
	public static var active(default, null):Bool = false;

	// Images and sounds are kept by this class itself: the ones the game keeps track of are thrown away when the state changes
	static var graphics:Map<String, FlxGraphic> = [];
	static var soundCache:Map<String, Sound> = [];

	// What was found by prepare(), to be used by the next transition
	static var preparedStickers:Array<String> = null;
	// the one in the middle at the end, when the pack picks a sticker of its own for it (a pack made by a script)
	static var preparedLast:String = null;
	static var preparedSounds:Array<Sound> = null;

	static var overlay:StickerOverlay = null;
	static var stickers:Array<StickerSprite> = [];
	static var sounds:Array<Sound> = [];
	static var nextState:FlxState = null;
	static var phase:Int = 0; //1: covering the screen, 2: waiting for the new state, 3: uncovering it
	static var time:Float = 0;
	static var hooked:Bool = false;

	// ------------------------------------------------------------------------------------------
	// Starting one
	// ------------------------------------------------------------------------------------------

	/**
	 * Looks for the stickers and the sounds of the next transition, to be called while the mod of the song is still the current one
	 * (before `Mods.loadTopMod()`). Without it the transition looks for them when it starts.
	 *
	 * @param packId 	Sticker pack to use, the one of the song being played or of its player if not given.
	 */
	public static function prepare(?packId:String):Void
	{
		preparedStickers = null;
		preparedLast = null;
		preparedSounds = null;
		if(!ClientPrefs.data.stickerTransition) return;

		try
		{
			if(packId == null) packId = getSongPack();
			preparedStickers = findStickers(packId);
			preparedSounds = findSounds();
		}
		catch(e:Dynamic)
		{
			trace('Could not get the stickers of the pack "$packId" ready: $e');
		}
	}

	/**
	 * The sticker pack that goes with the song being played.
	 */
	public static function getSongPack():String
	{
		var song:Dynamic = PlayState.SONG;
		if(song != null && song.vslice != null && song.vslice.stickerPack != null) return song.vslice.stickerPack;

		var character:String = null;
		if(PlayState.instance != null && PlayState.instance.boyfriend != null) character = PlayState.instance.boyfriend.curCharacter;
		else if(song != null) character = song.player1;

		var player = (character != null) ? PlayableCharacters.getOwner(character) : null;
		if(player == null) player = PlayableCharacters.getCurrent();
		return (player != null && player.stickerPack != null) ? player.stickerPack : DEFAULT_PACK;
	}

	/**
	 * Goes to another state with the stickers, or the usual way if they're turned off or there are none to show.
	 */
	public static function switchState(target:FlxState):Void
	{
		if(active)
		{
			// One at a time. While the screen is being covered the new request takes the place of the old one,
			// after that the stickers are already coming off and it's done the usual way
			if(phase == 1) nextState = target;
			else MusicBeatState.switchState(target);
			return;
		}

		if(!ClientPrefs.data.stickerTransition)
		{
			MusicBeatState.switchState(target);
			return;
		}

		if(preparedStickers == null) prepare();
		var paths:Array<String> = (preparedStickers != null) ? preparedStickers : [];
		var lastPath:String = preparedLast;
		sounds = (preparedSounds != null) ? preparedSounds : [];
		preparedStickers = null;
		preparedLast = null;
		preparedSounds = null;

		var images:Array<FlxGraphic> = [];
		for (path in paths)
		{
			var graphic:FlxGraphic = getGraphic(path);
			if(graphic != null) images.push(graphic);
		}
		if(images.length < 1)
		{
			MusicBeatState.switchState(target);
			return;
		}

		makeStickers(images, (lastPath != null) ? getGraphic(lastPath) : null);

		if(overlay == null) overlay = new StickerOverlay();
		overlay.insert();

		if(!hooked)
		{
			hooked = true;
			FlxG.signals.postUpdate.add(update);
			FlxG.signals.postStateSwitch.add(onStateSwitched);
			FlxG.signals.gameResized.add(function(_, _) if(overlay != null) overlay.onResize());
		}

		active = true;
		phase = 1;
		time = 0;
		nextState = target;

		// What's on the screen stops answering to the player, without being told it was closed (a paused song would start playing again)
		var top:FlxState = FlxG.state;
		while(top != null && top.subState != null)
			top = top.subState;
		if(top != null) top.openSubState(new StickerBlocker());
	}

	// Stickers all over the screen in rows, in a random order, with one last sticker right on the middle
	static function makeStickers(images:Array<FlxGraphic>, ?last:FlxGraphic):Void
	{
		clearStickers();

		var xPos:Float = -100;
		var yPos:Float = -100;
		while(xPos <= FlxG.width)
		{
			var sticky:StickerSprite = new StickerSprite(FlxG.random.getObject(images));
			sticky.x = xPos;
			sticky.y = yPos;
			xPos += Math.max(sticky.frameWidth * 0.5, 20);

			if(xPos >= FlxG.width && yPos <= FlxG.height)
			{
				xPos = -100;
				yPos += FlxG.random.float(70, 120);
			}

			sticky.angle = FlxG.random.int(-60, 70);
			stickers.push(sticky);
		}

		FlxG.random.shuffle(stickers);

		var lastSticker:StickerSprite = new StickerSprite((last != null) ? last : FlxG.random.getObject(images));
		lastSticker.angle = 0;
		lastSticker.screenCenter();
		stickers.push(lastSticker);

		for (num => sticker in stickers)
			sticker.timing = FlxMath.remapToRange(num, 0, stickers.length, 0, 0.9);
	}

	// ------------------------------------------------------------------------------------------
	// Running
	// ------------------------------------------------------------------------------------------

	static function update():Void
	{
		if(!active) return;

		var elapsed:Float = FlxG.elapsed;
		time += elapsed;

		switch(phase)
		{
			case 1:
				var missing:Bool = false;
				for (sticker in stickers)
				{
					if(sticker.visible) continue;

					if(sticker.timing > time)
					{
						missing = true;
						continue;
					}

					sticker.visible = true;
					sticker.scale.x = sticker.scale.y = FlxG.random.float(0.97, 1.02);
					playSound();
				}

				// a moment with everything covered, then the state changes behind the stickers
				if(!missing && time >= 0.9 + 2 / 24)
				{
					phase = 2;
					time = 0;

					var target:FlxState = nextState;
					nextState = null;

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					MusicBeatState.switchState(target);
				}

			case 2:
				// the new state never showed up, something went wrong with it
				if(time > 15) finish();

			case 3:
				var left:Bool = false;
				for (sticker in stickers)
				{
					if(!sticker.visible) continue;

					if(sticker.timing > time)
					{
						left = true;
						continue;
					}

					sticker.visible = false;
					playSound();
				}
				if(!left) finish();
		}

		if(active && overlay != null) overlay.render(stickers, elapsed);
	}

	static function onStateSwitched():Void
	{
		if(!active) return;

		// from here on the stickers come off, the ones that never got to show up included if something else changed the state first
		phase = 3;
		time = 0;
		nextState = null;
	}

	static function playSound():Void
	{
		if(sounds.length > 0) FlxG.sound.play(FlxG.random.getObject(sounds));
	}

	static function clearStickers():Void
	{
		for (sticker in stickers)
			sticker.destroy();
		stickers = [];
	}

	static function finish():Void
	{
		active = false;
		phase = 0;
		nextState = null;
		clearStickers();
		if(overlay != null) overlay.clear();
	}

	// ------------------------------------------------------------------------------------------
	// Files
	// ------------------------------------------------------------------------------------------

	// The image files of a sticker pack, the default pack's if it doesn't exist
	static function findStickers(packId:String):Array<String>
	{
		// a pack made by a script picks its stickers itself
		#if HSCRIPT_ALLOWED
		var scripted:funkin.ui.transition.stickers.StickerPack = (packId != null) ? backend.VSliceScripts.makeStickerPackScript(packId) : null;
		if(scripted != null)
		{
			var keys:Array<Dynamic> = backend.VSliceScripts.callScripted(scripted, 'getStickers', []);
			var files:Array<String> = [];
			if(keys != null)
				for (key in keys)
				{
					var file:String = stickerFile(key);
					if(file != null) files.push(file);
				}
			preparedLast = stickerFile(backend.VSliceScripts.callScripted(scripted, 'getRandomStickerPath', [true]));
			if(files.length > 0) return files;
		}
		#end

		var raw:String = (packId != null) ? Paths.getTextFromFile('data/stickerpacks/$packId.json') : null;
		if(raw == null && packId != DEFAULT_PACK) raw = Paths.getTextFromFile('data/stickerpacks/$DEFAULT_PACK.json');
		if(raw == null) return [];
		if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1);

		var data:Dynamic = Json.parse(raw);
		var list:Array<Dynamic> = Std.isOfType(data.stickers, Array) ? data.stickers : [];

		var found:Array<String> = [];
		for (entry in list)
		{
			if(entry == null) continue;

			var path:String = stickerFile(entry);
			if(path != null) found.push(path);
		}
		return found;
	}

	// The image file of a sticker as a pack has it ("library:path" inside of "images"), null if there's no such file
	static function stickerFile(entry:Dynamic):String
	{
		if(entry == null) return null;

		var key:String = Std.string(entry);
		var colon:Int = key.indexOf(':');
		if(colon > -1) key = key.substr(colon + 1);

		var path:String = Paths.getPath('images/$key.png', IMAGE);
		#if sys
		if(FileSystem.exists(path)) return path;
		#end
		return null;
	}

	// The sounds of one of the folders inside "sounds/stickersounds", picked at random
	static function findSounds():Array<Sound>
	{
		var found:Array<Sound> = [];
		#if sys
		var sets:Map<String, Array<String>> = [];
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'sounds/stickersounds/'))
		{
			if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;

			for (set in FileSystem.readDirectory(folder))
			{
				var setFolder:String = haxe.io.Path.addTrailingSlash(folder) + set;
				if(!FileSystem.isDirectory(setFolder)) continue;

				for (file in FileSystem.readDirectory(setFolder))
				{
					if(!file.toLowerCase().endsWith('.${Paths.SOUND_EXT}')) continue;

					if(!sets.exists(set)) sets.set(set, []);
					sets.get(set).push('$setFolder/$file');
				}
			}
		}

		var names:Array<String> = [for (name in sets.keys()) name];
		if(names.length < 1) return found;
		names.sort(Reflect.compare);

		for (path in sets.get(FlxG.random.getObject(names)))
		{
			var sound:Sound = soundCache.get(path);
			if(sound == null)
			{
				sound = Sound.fromFile(path);
				if(sound != null) soundCache.set(path, sound);
			}
			if(sound != null) found.push(sound);
		}
		#end
		return found;
	}

	static function getGraphic(path:String):FlxGraphic
	{
		var graphic:FlxGraphic = graphics.get(path);
		if(graphic != null && graphic.bitmap != null) return graphic;

		#if sys
		try
		{
			var bitmap:BitmapData = BitmapData.fromFile(path);
			if(bitmap == null) return null;

			// not on the game's list of images, which is emptied between states
			graphic = FlxGraphic.fromBitmapData(bitmap, false, null, false);
			graphic.persist = true;
			graphic.destroyOnNoUse = false;
			graphics.set(path, graphic);
			return graphic;
		}
		catch(e:Dynamic)
		{
			trace('Could not load the sticker "$path": $e');
		}
		#end
		return null;
	}
}

/**
 * Keeps whatever is under the stickers from being used while they cover the screen.
 */
class StickerBlocker extends FlxSubState
{
	public function new()
	{
		super(0x00000000);
	}
}

/**
 * Where the stickers are drawn: a camera of its own over the game, that isn't one of the state's cameras and so doesn't go away with it.
 */
@:access(flixel.FlxCamera)
class StickerOverlay extends openfl.display.Sprite
{
	public var stickersCamera:FlxCamera;

	public function new()
	{
		super();
		visible = false;

		stickersCamera = new FlxCamera();
		stickersCamera.bgColor = 0x00000000;
		addChild(stickersCamera.flashSprite);
	}

	public function insert():Void
	{
		FlxG.addChildBelowMouse(this, 1);
		visible = true;
		onResize();
	}

	public function clear():Void
	{
		FlxG.removeChild(this);
		visible = false;
		stickersCamera.clearDrawStack();
		stickersCamera.canvas.graphics.clear();
	}

	public function onResize():Void
	{
		x = y = 0;
		scaleX = scaleY = 1;
		stickersCamera.onResize();
	}

	/**
	 * Draws the stickers that are showing.
	 */
	public function render(stickers:Array<StickerSprite>, elapsed:Float):Void
	{
		stickersCamera.visible = visible;
		if(!visible) return;

		stickersCamera.update(elapsed);
		stickersCamera.clearDrawStack();
		stickersCamera.canvas.graphics.clear();

		for (sticker in stickers)
		{
			if(!sticker.visible) continue;

			sticker.cameras = [stickersCamera];
			sticker.draw();
		}

		stickersCamera.render();
	}
}
