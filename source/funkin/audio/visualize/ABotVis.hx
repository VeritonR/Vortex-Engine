package funkin.audio.visualize;

#if funkin.vis
import funkin.vis.dsp.SpectralAnalyzer;
#end

/**
 * V-Slice's bars that move to a sound, the ones of the speaker Nene sits on: `new ABotVis(FlxG.sound.music, false)`.
 * It's a group of 7 sprites, each showing how loud a part of the sound is.
 *
 * The images are the ones of V-Slice ("characters/abot/aBotViz", or "characters/abotPixel/aBotVizPixel" for the pixel one) when a mod has them,
 * and the engine's own otherwise (the ones of Weekend 1).
 */
class ABotVis extends FlxSpriteGroup
{
	static inline final BAR_COUNT:Int = 7;

	/**
	 * The sound it moves to. `initAnalyzer()` has to be called once it's playing.
	 */
	public var snd:FlxSound = null;

	#if funkin.vis
	var analyzer:SpectralAnalyzer = null;
	var levels:Array<Bar> = [];
	#end

	public function new(?snd:FlxSound, pixel:Bool = false)
	{
		super();
		this.snd = snd;

		var frames:flixel.graphics.frames.FlxAtlasFrames = findFrames(pixel);
		if(frames == null)
		{
			trace('The images of the speaker\'s bars were not found, they are not shown');
			return;
		}

		// how far each bar is from the one before it
		var positionX:Array<Float> = pixel ? [0, 42, 48, 54, 60, 36, 42] : [0, 59, 56, 66, 54, 52, 51];
		var positionY:Array<Float> = pixel ? [0, -12, -6, 0, 0, 6, 12] : [0, -8, -3.5, -0.4, 0.5, 4.7, 7];
		var visScale:Float = pixel ? 6 : 1;

		var posX:Float = 0;
		var posY:Float = 0;
		for (index in 1...BAR_COUNT + 1)
		{
			posX += positionX[index - 1];
			posY += positionY[index - 1];

			var viz:FlxSprite = new FlxSprite(posX, posY);
			viz.frames = frames;
			viz.antialiasing = !pixel && ClientPrefs.data.antialiasing;
			viz.scale.set(visScale, visScale);
			viz.animation.addByPrefix('VIZ', 'viz${index}0', 0);
			if(viz.animation.exists('VIZ')) viz.animation.play('VIZ', false, false, 1);
			add(viz);
		}
	}

	static function findFrames(pixel:Bool):flixel.graphics.frames.FlxAtlasFrames
	{
		var candidates:Array<Array<String>> = pixel
			? [['characters/abotPixel/aBotVizPixel', null], ['abotPixel/aBotVizPixel', 'week6'], ['abotPixel/aBotVizPixel', 'weekend1']]
			: [['characters/abot/aBotViz', null], ['abot/aBotViz', 'weekend1']];

		for (candidate in candidates)
			if(backend.Paths.fileExists('images/${candidate[0]}.png', IMAGE, false, candidate[1]))
				return backend.Paths.getSparrowAtlas(candidate[0], candidate[1]);
		return null;
	}

	/**
	 * Starts listening to the sound.
	 */
	public function initAnalyzer():Void
	{
		#if funkin.vis
		if(snd == null) return;

		try
		{
			@:privateAccess
			analyzer = new SpectralAnalyzer(snd._channel.__audioSource, BAR_COUNT, 0.1, 40);
			analyzer.minDb = -65;
			analyzer.maxDb = -25;
			analyzer.maxFreq = 22000;
			analyzer.minFreq = 10; //some songs go very low
			#if desktop
			analyzer.fftN = 256;
			#end
		}
		catch(e:Dynamic)
		{
			// (the sound isn't playing yet)
			analyzer = null;
		}
		#end
	}

	public function dumpSound():Void
	{
		snd = null;
		#if funkin.vis
		analyzer = null;
		#end
	}

	override function draw():Void
	{
		updateBars();
		super.draw();
	}

	function updateBars():Void
	{
		var quiet:Bool = (FlxG.sound.volume == 0 || FlxG.sound.muted);
		#if funkin.vis
		if(analyzer != null) levels = analyzer.getLevels(levels);
		#end

		for (index => bar in members)
		{
			if(bar == null || bar.animation.curAnim == null) continue;

			var value:Float = 0;
			#if funkin.vis
			if(analyzer != null && !quiet && index < levels.length) value = levels[index].value;
			#end

			// 0 is nothing at all, the rest are the image's 6 frames from the tallest to the shortest
			var frame:Int = Math.round(value * 6);
			bar.visible = frame > 0;
			bar.animation.curAnim.curFrame = Std.int(Math.abs(Math.max(0, Math.min(5, frame - 1)) - 5));
		}
	}
}
