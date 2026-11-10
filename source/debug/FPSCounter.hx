package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
class FPSCounter extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	var deltaTimeout:Float = 0.0;

	// How long the game's own work takes on each frame (milliseconds, smoothed): its logic and sending what's drawn to the
	// graphics card. A frame that takes much longer than both is waiting for the graphics card
	var updateTime:Float = 0;
	var drawTime:Float = 0;
	var startedAt:Float = 0;
	var watching:Bool = false;

	function watch():Void
	{
		if(watching || FlxG.signals == null) return;
		watching = true;
		FlxG.signals.preUpdate.add(() -> startedAt = haxe.Timer.stamp());
		FlxG.signals.postUpdate.add(() -> updateTime = updateTime * 0.9 + (haxe.Timer.stamp() - startedAt) * 100);
		FlxG.signals.preDraw.add(() -> startedAt = haxe.Timer.stamp());
		FlxG.signals.postDraw.add(() -> drawTime = drawTime * 0.9 + (haxe.Timer.stamp() - startedAt) * 100);
	}

	// Event Handlers
	private override function __enterFrame(deltaTime:Float):Void
	{
		watch();
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();
		// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
		if (deltaTimeout < 50) {
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;		
		updateText();
		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void { // so people can override it in hscript
		text = 'FPS: ${currentFPS}'
		+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}'
		+ '\nLogic: ${Math.round(updateTime * 10) / 10} ms / Drawing: ${Math.round(drawTime * 10) / 10} ms';

		// (readable on a phone's screen, where the window has many more pixels than the game)
		if(stage != null) scaleX = scaleY = Math.max(1, stage.stageHeight / 720);
		#if mobile
		x = 104 * scaleX; //(right of the menus' back button, see backend.TouchMenus)
		#end

		textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.drawFramerate * 0.5)
			textColor = 0xFFFF0000;
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}
