package objects;

import backend.animation.PsychAnimationController;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;

	/**
	 * The direction of the receptor, 0 to 3 (its `ID` isn't, flixel gives every object one of its own).
	 */
	public var noteDirection(get, never):Int;
	inline function get_noteDirection():Int return noteData;

	/**
	 * The scale the receptor's look comes with (Psych's, or the one of the note style that gave it its look): what it's scaled by
	 * when nothing changed it.
	 */
	public var lookScale(default, null):Float = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	/**
	 * The room a receptor takes on V-Slice (its note style's, see `funkin.play.notes.notestyle.NoteStyle.getStrumlineSize()`), for the
	 * receptors made while it's set: PlayState sets it for the songs of V-Slice mods, whose scripts place receptors by their corner and
	 * their size, which have to mean what they do there. Psych's are smaller, these get that room with their picture in the middle of it.
	 */
	public static var vsliceHitbox:FlxPoint = null;

	/**
	 * The room of the receptors of the song being played (the last `vsliceHitbox` PlayState made them with), for the ones scripts make.
	 */
	public static var songRoom:FlxPoint = null;
	var vsliceSize:FlxPoint = null;
	var baseRoom:FlxPoint = null; //(the room of the song's own receptors, for when a note style gives it back its look)

	/**
	 * How much bigger than Psych's this receptor's room is on each side (see `vsliceHitbox`): Psych puts things on a receptor from where
	 * its own receptor's corner would be, which is this much inside of `x` and `y` (`psychX`, `psychY`).
	 */
	public var hitboxShift(default, null):FlxPoint = FlxPoint.get();
	public var psychX(get, never):Float;
	inline function get_psychX():Float return x + hitboxShift.x;
	public var psychY(get, never):Float;
	inline function get_psychY():Float return y + hitboxShift.y;

	public var useRGBShader:Bool = true;
	public function new(x:Float, y:Float, leData:Int, player:Int) {
		if(vsliceHitbox != null)
		{
			vsliceSize = FlxPoint.get(vsliceHitbox.x, vsliceHitbox.y);
			baseRoom = FlxPoint.get(vsliceHitbox.x, vsliceHitbox.y);
		}
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
		
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[leData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[leData];
		
		if(leData <= arr.length)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);

		var skin:String = null;
		if(PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
		else skin = Note.defaultNoteSkin;

		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if(Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		texture = skin; //Load texture and anims
		scrollFactor.set();
		playAnim('static');
	}

	public function reloadNote()
	{
		var middleX:Null<Float> = (vsliceSize != null && psychSize != null) ? x + width / 2 : null;
		var middleY:Null<Float> = (vsliceSize != null && psychSize != null) ? y + height / 2 : null;

		var lastAnim:String = null;
		if(animation.curAnim != null) lastAnim = animation.curAnim.name;

		if(PlayState.isPixelStage)
		{
			loadGraphic(Paths.image('pixelUI/' + texture));
			width = width / 4;
			height = height / 5;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(texture);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(Std.int(width * 0.7));

			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();
		lookScale = scale.x;
		applyVSliceSize(middleX, middleY);

		if(lastAnim != null)
		{
			playAnim(lastAnim, true);
		}
	}

	// The size Psych's own receptor has here, which what Psych puts on receptors is made for (see `hitboxShift`)
	var psychSize:FlxPoint = null;

	// The room of a V-Slice receptor instead of the picture's own, with the receptor's middle staying where it was: given, or the middle
	// of Psych's receptor the first time (made at the corner Psych gives it)
	function applyVSliceSize(middleX:Null<Float>, middleY:Null<Float>):Void
	{
		if(vsliceSize == null)
		{
			hitboxShift.set(0, 0);
			return;
		}

		var ownWidth:Float = width;
		var ownHeight:Float = height;
		if(psychSize == null) psychSize = FlxPoint.get(ownWidth, ownHeight);

		width = vsliceSize.x;
		height = vsliceSize.y;
		centerOffsets();
		centerOrigin();
		hitboxShift.set((width - psychSize.x) / 2, (height - psychSize.y) / 2);

		if(middleX == null) middleX = x + ownWidth / 2;
		if(middleY == null) middleY = y + ownHeight / 2;
		x = middleX - width / 2;
		y = middleY - height / 2;
	}

	/**
	 * Gives the receptor the look of a V-Slice note style (see `funkin.play.notes.notestyle.NoteStyle.applyToStrum()`): its pictures,
	 * the animations `addAnimations` gives it ("static", "pressed", "confirm"), its size and its room, with its middle where it was.
	 */
	public function takeLook(frames:flixel.graphics.frames.FlxAtlasFrames, addAnimations:FlxSprite->Void, scale:Float, pixel:Bool, ?room:FlxPoint):Void
	{
		var middleX:Float = x + width / 2;
		var middleY:Float = y + height / 2;
		if(psychSize == null) psychSize = FlxPoint.get(width - hitboxShift.x * 2, height - hitboxShift.y * 2);

		var lastAnim:String = (animation.curAnim != null) ? animation.curAnim.name : 'static';
		this.frames = frames;
		addAnimations(this);
		this.scale.set(scale, scale);
		updateHitbox();
		lookScale = scale;
		antialiasing = !pixel && ClientPrefs.data.antialiasing;
		useRGBShader = false;
		rgbShader.enabled = false;

		if(room != null)
		{
			if(vsliceSize == null) vsliceSize = FlxPoint.get();
			vsliceSize.copyFrom(room);
		}
		applyVSliceSize(middleX, middleY);
		if(vsliceSize == null)
		{
			x = middleX - width / 2;
			y = middleY - height / 2;
		}
		playAnim(animation.exists(lastAnim) ? lastAnim : 'static', true);
		hasStyleLook = true;
	}

	/**
	 * If a V-Slice note style gave the receptor its look (`takeLook()`).
	 */
	public var hasStyleLook(default, null):Bool = false;

	/**
	 * Gives the receptor back the engine's own look after a note style gave it another, with its middle where it is.
	 */
	public function restoreEngineLook():Void
	{
		if(!hasStyleLook) return;
		hasStyleLook = false;

		if(baseRoom != null)
		{
			if(vsliceSize == null) vsliceSize = FlxPoint.get();
			vsliceSize.copyFrom(baseRoom);
		}
		useRGBShader = !(PlayState.SONG != null && PlayState.SONG.disableNoteRGB);
		antialiasing = ClientPrefs.data.antialiasing && !PlayState.isPixelStage;
		reloadNote();
		playAnim((animation.curAnim != null) ? animation.curAnim.name : 'static', true);
	}

	public function playerPosition()
	{
		x += Note.swagWidth * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		// a receptor whose pictures were changed has no animation until one it has is played: one asked for that it doesn't have
		// (a note style without "pressed"...) would leave it like that, with nothing to show or to be checked by the input
		if(anim == null || !animation.exists(anim))
		{
			if(animation.curAnim != null || !animation.exists('static')) return;
			anim = 'static';
		}
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}
		if(useRGBShader) rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
	}
}
