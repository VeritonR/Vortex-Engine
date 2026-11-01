package backend;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;

/**
 * The screenshot key ("F3" by default, see the Controls menu): a picture of the game as the window shows it goes to the gallery
 * ("mods/images/gallery", the Gallery menu shows it, with a button there to save a copy anywhere), with V-Slice's feedback:
 * a white flash (with the Flashing Lights option on), its camera sound, and the picture small at the top left for a moment
 * (clicking it opens the folder).
 */
class Screenshots extends Sprite
{
	public static var instance(default, null):Screenshots;

	/**
	 * Where the pictures go: the gallery of the "mods" folder, which the Gallery menu reads (and the clean export leaves out).
	 */
	public static inline var FOLDER:String = 'mods/images/gallery/';

	static inline var PREVIEW_DELAY:Float = 0.25;
	static inline var PREVIEW_FADE_IN:Float = 0.3;
	static inline var PREVIEW_STAY:Float = 1.25;
	static inline var PREVIEW_FADE_OUT:Float = 0.3;
	static inline var FLASH_TIME:Float = 0.15;

	var flash:Bitmap;
	var preview:Sprite;
	var outline:Bitmap;
	var picture:Bitmap;

	var flashTime:Float = 0;
	var previewTime:Float = -1;
	var lastTime:Float = 0;
	var waitFrames:Int = 0;

	public static function init():Void
	{
		if(instance != null || FlxG.stage == null) return;
		instance = new Screenshots();
		FlxG.stage.addChild(instance);
	}

	public function new()
	{
		super();

		flash = new Bitmap(new BitmapData(1, 1, false, 0xFFFFFFFF));
		flash.alpha = 0;
		addChild(flash);

		preview = new Sprite();
		preview.alpha = 0;
		preview.visible = false;
		preview.buttonMode = true;
		outline = new Bitmap(new BitmapData(1, 1, false, 0xFFFFFFFF));
		preview.addChild(outline);
		picture = new Bitmap();
		picture.smoothing = true;
		preview.addChild(picture);
		preview.addEventListener(MouseEvent.MOUSE_DOWN, function(_) if(preview.visible && preview.alpha > 0.1) openFolder());
		addChild(preview);

		mouseEnabled = false;
		addEventListener(Event.ENTER_FRAME, onFrame);
		lastTime = haxe.Timer.stamp();
	}

	function onFrame(_):Void
	{
		var now:Float = haxe.Timer.stamp();
		var elapsed:Float = Math.min(now - lastTime, 0.5);
		lastTime = now;

		// The key hides the last preview and the flash first, and the picture is taken once a frame was drawn without them
		// (what's read is the window's last finished picture)
		if(waitFrames > 0)
		{
			if(--waitFrames == 0) take();
		}
		// (not while something is being typed: an editor's text field or the chat, where the key may be a letter)
		else if(FlxG.keys != null && FlxG.keys.enabled && backend.ui.PsychUIInputText.focusOn == null && !OnlineChat.typing
			&& FlxG.keys.anyJustPressed(ClientPrefs.keyBinds.get('screenshot')))
		{
			hidePreview();
			flashTime = 0;
			flash.alpha = 0;
			waitFrames = 2;
		}

		var width:Float = FlxG.stage.stageWidth;
		var height:Float = FlxG.stage.stageHeight;

		if(flashTime > 0)
		{
			flashTime -= elapsed;
			flash.width = width;
			flash.height = height;
			flash.alpha = Math.max(0, flashTime / FLASH_TIME);
		}
		else flash.alpha = 0;

		if(previewTime >= 0)
		{
			previewTime += elapsed;
			var t:Float = previewTime - PREVIEW_DELAY;
			var alpha:Float = 0;
			var offset:Float = -10;
			if(t >= 0 && t < PREVIEW_FADE_IN)
			{
				var progress:Float = 1 - Math.pow(1 - t / PREVIEW_FADE_IN, 4); //(quart out)
				alpha = progress;
				offset = -10 * (1 - progress);
			}
			else if(t >= PREVIEW_FADE_IN && t < PREVIEW_FADE_IN + PREVIEW_STAY)
			{
				alpha = 1;
				offset = 0;
			}
			else if(t >= PREVIEW_FADE_IN + PREVIEW_STAY)
			{
				var progress:Float = Math.min(1, (t - PREVIEW_FADE_IN - PREVIEW_STAY) / PREVIEW_FADE_OUT);
				alpha = 1 - progress;
				offset = 10 * progress;
				if(progress >= 1) hidePreview();
			}
			// (lighter while the mouse is over it: it can be clicked)
			if(preview.hitTestPoint(FlxG.stage.mouseX, FlxG.stage.mouseY)) alpha *= 0.6;
			preview.alpha = alpha;
			preview.y = offset;
		}
	}

	/**
	 * Takes a picture now: saved in the gallery, with the flash, the sound and the preview.
	 */
	public function take():Void
	{
		var bitmap:BitmapData = null;
		try
		{
			// (the window's own picture: an image drawn off the screen can leave its framebuffer bound, see backend.DirectPlay)
			var bound:Dynamic = null;
			try
			{
				bound = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.FRAMEBUFFER_BINDING);
				lime.graphics.opengl.GL.bindFramebuffer(lime.graphics.opengl.GL.FRAMEBUFFER, null);
			}
			catch(e:Dynamic) {}
			bitmap = BitmapData.fromImage(FlxG.stage.window.readPixels());
			if(bound != null) try lime.graphics.opengl.GL.bindFramebuffer(lime.graphics.opengl.GL.FRAMEBUFFER, bound) catch(e:Dynamic) {}
		}
		catch(e:Dynamic)
		{
			trace('Screenshot: the window could not be read ($e)');
			return;
		}
		if(bitmap == null) return;

		var saved:String = save(bitmap);
		feedback(bitmap);
		if(saved != null) trace('Screenshot saved: $saved');
	}

	// The picture in the gallery folder; its path, or null if it couldn't be written
	function save(bitmap:BitmapData):String
	{
		#if sys
		try
		{
			if(!sys.FileSystem.exists(FOLDER)) sys.FileSystem.createDirectory(FOLDER);
			var path:String = FOLDER + fileName() + '.png';
			sys.io.File.saveBytes(path, bitmap.encode(bitmap.rect, new PNGEncoderOptions()));
			return path;
		}
		catch(e:Dynamic)
		{
			trace('Screenshot: it could not be saved ($e)');
		}
		#end
		return null;
	}

	/**
	 * "Bopeebo 2026-11-01 08h30m12s_Screenshot": the Gallery shows what's before the "_" as the title and the rest as its creator.
	 */
	static function fileName():String
	{
		var where:String = 'Vortex Engine';
		if(states.PlayState.SONG != null && Std.isOfType(FlxG.state, states.PlayState)) where = states.PlayState.SONG.song;
		// (what can't be in a file name, and the "_" the Gallery splits by)
		where = ~/[\\\/:*?"<>|_]/g.replace(where, ' ').trim();
		if(where.length < 1) where = 'Vortex Engine';

		var date:Date = Date.now();
		inline function two(value:Int):String return (value < 10 ? '0' : '') + value;
		var stamp:String = '${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())} ${two(date.getHours())}h${two(date.getMinutes())}m${two(date.getSeconds())}s';
		return '$where $stamp' + '_' + Language.getPhrase('screenshot_creator', 'Screenshot');
	}

	function feedback(bitmap:BitmapData):Void
	{
		if(ClientPrefs.data.flashing) flashTime = FLASH_TIME;
		try FlxG.sound.play(Paths.sound('screenshot')) catch(e:Dynamic) {}

		// the picture at the top left, a fifth of the window, with a white edge
		if(picture.bitmapData != null) picture.bitmapData.dispose();
		picture.bitmapData = bitmap;
		picture.smoothing = true;
		var width:Float = FlxG.stage.stageWidth / 5;
		var height:Float = FlxG.stage.stageHeight / 5;
		outline.x = 5;
		outline.y = 5;
		outline.width = width + 10;
		outline.height = height + 10;
		picture.x = outline.x + 5;
		picture.y = outline.y + 5;
		picture.width = width;
		picture.height = height;
		preview.visible = true;
		preview.alpha = 0;
		previewTime = 0;
		// (over everything that's on the stage, the chat included)
		if(parent != null) parent.setChildIndex(this, parent.numChildren - 1);
	}

	function hidePreview():Void
	{
		previewTime = -1;
		preview.visible = false;
		preview.alpha = 0;
	}

	static function openFolder():Void
	{
		#if sys
		try
		{
			if(!sys.FileSystem.exists(FOLDER)) sys.FileSystem.createDirectory(FOLDER);
			var full:String = sys.FileSystem.fullPath(FOLDER);
			// (no "\" at the end: Windows reads a "\" before the closing quote as a quote, and Explorer then opens Documents)
			while(full.endsWith('/') || full.endsWith('\\')) full = full.substr(0, full.length - 1);
			#if windows Sys.command('explorer', [full.split('/').join('\\')]);
			#elseif mac Sys.command('open', [full]);
			#else Sys.command('xdg-open', [full]); #end
		}
		catch(e:Dynamic) {}
		#end
	}
}
