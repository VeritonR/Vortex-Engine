package states;

import backend.CrashHandler;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * The crash screen: what went wrong and where (the mod, the song, the screen), with a way back to the menus instead of the game closing.
 * Kept simple on purpose (no scripts, no music, no transitions): it's opened when something already went wrong.
 */
class CrashState extends FlxState
{
	var info:CrashInfo;
	var notice:FlxText;
	var leaving:Bool = false;

	public function new(info:CrashInfo)
	{
		super();
		this.info = info;
	}

	override function create():Void
	{
		super.create();
		CrashHandler.recovered();
		FlxG.mouse.visible = true;
		FlxG.camera.bgColor = 0xFF101014;

		var font:String = Paths.font('vcr.ttf');
		var left:Float = 50;
		var width:Float = FlxG.width - left * 2;

		var bar = new FlxSprite().makeGraphic(FlxG.width, 8, 0xFFE0303A);
		add(bar);

		var title = new FlxText(left, 34, width, Language.getPhrase('crash_title', 'Something went wrong'), 40);
		title.setFormat(font, 40, 0xFFFF5A62, LEFT);
		add(title);

		var subtitle = new FlxText(left, title.y + title.height + 4, width, Language.getPhrase('crash_subtitle', 'The game caught the error and is still open.'), 18);
		subtitle.setFormat(font, 18, 0xFFB8B8C4, LEFT);
		add(subtitle);

		// the error itself, cut if it's too long to fit
		var errorText:String = info.error;
		if(errorText.length > 300) errorText = errorText.substr(0, 297) + '...';
		var error = new FlxText(left, subtitle.y + subtitle.height + 22, width, errorText, 22);
		error.setFormat(font, 22, FlxColor.WHITE, LEFT);
		add(error);

		// where it happened
		var y:Float = error.y + error.height + 20;
		for (entry in info.context)
		{
			if(entry[0] == 'Date' || entry[0] == 'Version') continue;
			var label:String = Language.getPhrase('crash_' + entry[0].toLowerCase(), entry[0]);
			var line = new FlxText(left, y, width, label + ': ' + entry[1], 18);
			line.setFormat(font, 18, 0xFFD8D8E0, LEFT);
			add(line);
			y += line.height + 2;
		}

		// the first lines of the code it happened in
		if(info.stack.length > 0)
		{
			var code = new FlxText(left, y + 14, width, info.stack.slice(0, 4).join('\n'), 14);
			code.setFormat(font, 14, 0xFF8A8A98, LEFT);
			add(code);
		}

		var help:String = Language.getPhrase(info.fromSong ? (info.storyMode ? 'crash_back_story' : 'crash_back_freeplay') : 'crash_back_menu',
			info.fromSong ? (info.storyMode ? 'ENTER: back to Story Mode' : 'ENTER: back to Freeplay') : 'ENTER: back to the main menu');
		#if !mobile
		help += '   |   ' + Language.getPhrase('crash_copy', 'C: copy the report');
		if(info.path != null) help += '   |   ' + Language.getPhrase('crash_folder', 'O: open the crash folder');
		#end
		var bottom = new FlxText(left, FlxG.height - 46, width, help, 18);
		bottom.setFormat(font, 18, FlxColor.WHITE, LEFT);
		add(bottom);

		var saved:String = (info.path != null) ? Language.getPhrase('crash_saved', 'Report saved to {1}', [info.path]) : '';
		notice = new FlxText(left, bottom.y - 30, width, saved, 16);
		notice.setFormat(font, 16, 0xFF8AD08A, LEFT);
		add(notice);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(leaving) return;

		var controls = Controls.instance;
		if(controls != null && (controls.justPressed('accept') || controls.justPressed('back')))
		{
			goBack();
			return;
		}

		#if !mobile
		if(FlxG.keys.justPressed.C)
		{
			try
			{
				lime.system.Clipboard.text = @:privateAccess CrashHandler.report(info);
				notice.text = Language.getPhrase('crash_copied', 'The report was copied.');
			}
			catch(e:Dynamic) {}
		}
		if(FlxG.keys.justPressed.O && info.path != null) CoolUtil.openFolder('crash');
		#end
	}

	function goBack():Void
	{
		leaving = true;
		try Mods.loadTopMod() catch(e:Dynamic) {}
		try FlxG.sound.playMusic(Paths.music('freakyMenu')) catch(e:Dynamic) {}

		var next:FlxState = if(!info.fromSong) new MainMenuState();
			else if(info.storyMode) new StoryMenuState();
			else if(ClientPrefs.data.freeplayStyle == 'V-Slice') new FreeplayStateVslice();
			else new FreeplayState();
		FlxG.switchState(next);
	}
}
