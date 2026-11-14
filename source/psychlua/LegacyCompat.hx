package psychlua;

/**
 * What mods made for older Psych Engine versions (0.4 to 0.7.3) still ask for by its old name.
 *
 * Up to 0.6 the game's classes had no package (`PlayState`, `ClientPrefs`, `Conductor`...), 0.7 put them in folders
 * (`states.PlayState`, `backend.ClientPrefs`...), and options moved from `ClientPrefs` itself to `ClientPrefs.data`. An old name is
 * only looked up here when nothing has that name now, so the current ones always win.
 */
class LegacyCompat
{
	/**
	 * Old class name => its name now.
	 */
	public static final CLASSES:Map<String, String> = [
		// (0.4 to 0.6: no packages)
		'Achievements' => 'backend.Achievements',
		'AchievementsMenuState' => 'states.AchievementsMenuState',
		'Alphabet' => 'objects.Alphabet',
		'AttachedSprite' => 'objects.AttachedSprite',
		'AttachedText' => 'objects.AttachedText',
		'BGSprite' => 'objects.BGSprite',
		'BackgroundDancer' => 'states.stages.objects.BackgroundDancer',
		'BackgroundGirls' => 'states.stages.objects.BackgroundGirls',
		'BlendModeEffect' => 'shaders.BlendModeEffect',
		'Boyfriend' => 'objects.Character',
		'Character' => 'objects.Character',
		'CheckboxThingie' => 'objects.CheckboxThingie',
		'ClientPrefs' => 'backend.ClientPrefs',
		'ColorSwap' => 'shaders.ColorSwap',
		'Conductor' => 'backend.Conductor',
		'Controls' => 'backend.Controls',
		'CoolUtil' => 'backend.CoolUtil',
		'CreditsState' => 'states.CreditsState',
		'CustomFadeTransition' => 'backend.CustomFadeTransition',
		'CutsceneHandler' => 'cutscenes.CutsceneHandler',
		'DialogueBox' => 'cutscenes.DialogueBox',
		'DialogueBoxPsych' => 'cutscenes.DialogueBoxPsych',
		'Discord' => 'backend.DiscordClient',
		'DiscordClient' => 'backend.DiscordClient',
		'backend.Discord' => 'backend.DiscordClient',
		'FlashingState' => 'states.FlashingState',
		'FreeplayState' => 'states.FreeplayState',
		'FunkinLua' => 'psychlua.FunkinLua',
		'GameOverSubstate' => 'substates.GameOverSubstate',
		'GameplayChangersSubstate' => 'options.GameplayChangersSubstate',
		'substates.GameplayChangersSubstate' => 'options.GameplayChangersSubstate',
		'HealthIcon' => 'objects.HealthIcon',
		'Highscore' => 'backend.Highscore',
		'InputFormatter' => 'backend.InputFormatter',
		'LoadingState' => 'states.LoadingState',
		'MainMenuState' => 'states.MainMenuState',
		'MenuCharacter' => 'objects.MenuCharacter',
		'MenuItem' => 'objects.MenuItem',
		'ModsMenuState' => 'states.ModsMenuState',
		'MusicBeatState' => 'backend.MusicBeatState',
		'MusicBeatSubstate' => 'backend.MusicBeatSubstate',
		'Note' => 'objects.Note',
		'NoteSplash' => 'objects.NoteSplash',
		'OptionsState' => 'options.OptionsState',
		'OutdatedSubState' => 'substates.OutdatedSubState',
		'OverlayShader' => 'shaders.OverlayShader',
		'Paths' => 'backend.Paths',
		'PauseSubState' => 'substates.PauseSubState',
		'PlayState' => 'states.PlayState',
		'ResetScoreSubState' => 'substates.ResetScoreSubState',
		'Song' => 'backend.Song',
		'StageData' => 'backend.StageData',
		'StoryMenuState' => 'states.StoryMenuState',
		'StrumNote' => 'objects.StrumNote',
		'TankmenBG' => 'states.stages.objects.TankmenBG',
		'TitleState' => 'states.TitleState',
		'TypedAlphabet' => 'objects.TypedAlphabet',
		'WeekData' => 'backend.WeekData',
		'WiggleEffect' => 'shaders.WiggleEffect',
		'editors.CharacterEditorState' => 'states.editors.CharacterEditorState',
		'editors.ChartingState' => 'states.editors.ChartingState',
		'editors.DialogueCharacterEditorState' => 'states.editors.DialogueCharacterEditorState',
		'editors.DialogueEditorState' => 'states.editors.DialogueEditorState',
		'editors.MasterEditorMenu' => 'states.editors.MasterEditorMenu',
		'editors.MenuCharacterEditorState' => 'states.editors.MenuCharacterEditorState',
		'editors.WeekEditorState' => 'states.editors.WeekEditorState',
		// (0.7)
		'states.editors.EditorPlayState' => 'states.editors.content.EditorPlayState',
		'substates.Prompt' => 'states.editors.content.Prompt',
		// (flixel's own, moved by flixel 5.3)
		'flixel.system.FlxSound' => 'flixel.sound.FlxSound',
		'flixel.system.FlxSoundGroup' => 'flixel.sound.FlxSoundGroup'
	];

	/**
	 * A class by its name, the old ones too. Null if there's none.
	 */
	public static function resolveClass(name:String):Dynamic
	{
		if(name == null) return null;
		name = name.trim();
		var found:Dynamic = Type.resolveClass(name);
		if(found == null && CLASSES.exists(name)) found = Type.resolveClass(CLASSES.get(name));
		return found;
	}

	// ------------------------------------------------------------------------------------------
	// ClientPrefs
	// ------------------------------------------------------------------------------------------

	/**
	 * An option read the way older versions did (`ClientPrefs.downScroll`, now `ClientPrefs.data.downScroll`): the path it has now,
	 * or null if `ClientPrefs` has it as it's written (`data.downScroll`, `keyBinds`...) or it's one of the options that changed.
	 */
	public static function clientPrefsPath(variable:String):String
	{
		var first:String = variable.split('.')[0].split('[')[0];
		if(Type.getClassFields(backend.ClientPrefs).contains(first)) return null;
		if(first == 'globalAntialiasing') return 'data.antialiasing' + variable.substr(first.length);
		if(Reflect.hasField(backend.ClientPrefs.data, first) || Type.getInstanceFields(Type.getClass(backend.ClientPrefs.data)).contains(first))
			return 'data.' + variable;
		return null;
	}

	/**
	 * The options of older versions that aren't there anymore, as they would be now. False in `found` if it isn't one of them.
	 */
	public static function oldOption(name:String):{found:Bool, value:Dynamic}
	{
		var data = backend.ClientPrefs.data;
		return switch(name)
		{
			case 'hideTime': {found: true, value: data.timeBarType == 'Disabled'};
			case 'noteSplashes': {found: true, value: data.splashAlpha > 0};
			case 'violence' | 'cursing': {found: true, value: true};
			case 'imagesPersist' | 'controllerMode': {found: true, value: false};
			case 'arrowHSV': {found: true, value: [for (i in 0...4) [0, 0, 0]]};
			default: {found: false, value: null};
		}
	}

	// ------------------------------------------------------------------------------------------
	// Note skins
	// ------------------------------------------------------------------------------------------

	/**
	 * Up to 0.6 the notes' skin was "NOTE_assets" (`images/NOTE_assets.png`) and the splashes' "noteSplashes", already colored;
	 * 0.7 moved them to "noteSkins/NOTE_assets" and "noteSplashes/noteSplashes", templates the RGB shader colors. A mod of then
	 * that has the old one (and not a new one) plays with it. Null if there's none.
	 */
	public static function oldNoteSkin(?pixel:Bool = false):String
	{
		var folder:String = pixel ? 'images/pixelUI/' : 'images/';
		return remembered('skin' + pixel, function() return (modHas(folder + 'NOTE_assets.png') && !modHas(folder + 'noteSkins/NOTE_assets.png')) ? 'NOTE_assets' : null);
	}

	public static function oldNoteSplash():String
		return remembered('splash', function() return (modHas('images/noteSplashes.png') && !modHas('images/noteSplashes/noteSplashes.png')) ? 'noteSplashes' : null);

	// (asked for every note: the files are only looked for once a screen, looking for them is slow on phones)
	static var answers:Map<String, String> = null;
	static function remembered(question:String, answer:Void->String):String
	{
		if(answers == null)
		{
			answers = [];
			FlxG.signals.preStateCreate.add(function(_) answers.clear());
		}
		var key:String = question + '|' + Mods.currentModDirectory;
		if(!answers.exists(key)) answers.set(key, answer());
		return answers.get(key);
	}

	// (a mod's: the current one, a global one, or the "mods" folder itself like 0.4 had them)
	static function modHas(file:String):Bool
	{
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(file);
		return path != null && path.replace('\\', '/').contains('mods/') && FileSystem.exists(path);
		#else
		return false;
		#end
	}

	static var coloredSkins:Map<String, Bool> = [];

	/**
	 * If a skin is colored already, like all of them up to 0.6 (the left arrow purple, the down one cyan...), and not a template the
	 * RGB shader colors, where the four arrows are the same: the shader would color it over its colors. Told apart by those: the
	 * frames of each arrow, or of each column for pixel skins (a grid with no xml).
	 *
	 * @param prefixes  The frames of each color in the atlas ("purple0", "blue0"... for notes, "note splash purple 1"... for splashes).
	 */
	public static function isColoredSkin(key:String, ?prefixes:Array<String>, ?pixelGrid:Bool = false):Bool
	{
		if(key == null || key.length < 1) return false;
		var cacheKey:String = key + '|' + prefixes + '|' + pixelGrid + '|' + Mods.currentModDirectory;
		if(coloredSkins.exists(cacheKey)) return coloredSkins.get(cacheKey);

		var result:Bool = false;
		try
		{
			result = pixelGrid ? measureGrid(key) : measureAtlas(key, prefixes != null ? prefixes : ['purple0', 'blue0', 'green0', 'red0']);
		}
		catch(e:Dynamic) trace('Could not tell if "$key" is colored: $e');
		coloredSkins.set(cacheKey, result);
		return result;
	}

	static function imageFile(key:String, extension:String):String
	{
		#if sys
		var path:String = Paths.getPath('images/$key.$extension', extension == 'png' ? IMAGE : TEXT);
		if(path != null && FileSystem.exists(path)) return path;
		#end
		return null;
	}

	static function measureAtlas(key:String, prefixes:Array<String>):Bool
	{
		#if sys
		var png:String = imageFile(key, 'png');
		var xml:String = imageFile(key, 'xml');
		if(png == null || xml == null) return false;

		var image = lime.graphics.Image.fromBytes(File.getBytes(png));
		var atlas = Xml.parse(File.getContent(xml)).firstElement();
		if(image == null || atlas == null) return false;

		var colors:Array<Array<Float>> = [];
		for (prefix in prefixes)
		{
			var node:Xml = null;
			for (texture in atlas.elementsNamed('SubTexture'))
				if(texture.get('name') != null && texture.get('name').startsWith(prefix)) { node = texture; break; }
			if(node == null) return false;
			colors.push(averageColor(image, Std.parseInt(node.get('x')), Std.parseInt(node.get('y')), Std.parseInt(node.get('width')), Std.parseInt(node.get('height'))));
		}
		return differentColors(colors);
		#else
		return false;
		#end
	}

	// (a pixel skin is a grid of 4 columns and 5 rows, the notes on the second row)
	static function measureGrid(key:String):Bool
	{
		#if sys
		var png:String = imageFile(key, 'png');
		if(png == null) return false;
		var image = lime.graphics.Image.fromBytes(File.getBytes(png));
		if(image == null) return false;
		var width:Int = Std.int(image.width / 4);
		var height:Int = Std.int(image.height / 5);
		return differentColors([for (column in 0...4) averageColor(image, column * width, height, width, height)]);
		#else
		return false;
		#end
	}

	// The average color of the colored pixels of a part of the image (null if it has none: gray, black and white)
	static function averageColor(image:lime.graphics.Image, x:Int, y:Int, width:Int, height:Int):Array<Float>
	{
		var red:Float = 0, green:Float = 0, blue:Float = 0, count:Int = 0;
		var right:Int = Std.int(Math.min(image.width, x + width));
		var bottom:Int = Std.int(Math.min(image.height, y + height));
		var step:Int = Std.int(Math.max(1, Math.min(width, height) / 40));
		var py:Int = Std.int(Math.max(0, y));
		while(py < bottom)
		{
			var px:Int = Std.int(Math.max(0, x));
			while(px < right)
			{
				var pixel:Int = image.getPixel32(px, py, lime.graphics.PixelFormat.ARGB32);
				var a:Int = (pixel >> 24) & 0xFF, r:Int = (pixel >> 16) & 0xFF, g:Int = (pixel >> 8) & 0xFF, b:Int = pixel & 0xFF;
				var high:Int = Std.int(Math.max(r, Math.max(g, b)));
				var low:Int = Std.int(Math.min(r, Math.min(g, b)));
				if(a > 200 && high - low > 60)
				{
					red += r; green += g; blue += b; count++;
				}
				px += step;
			}
			py += step;
		}
		return (count > 0) ? [red / count, green / count, blue / count] : null;
	}

	static function differentColors(colors:Array<Array<Float>>):Bool
	{
		// (no color at all: a gray skin, which the shader would color too)
		var colored:Array<Array<Float>> = [for (color in colors) if(color != null) color];
		if(colored.length == 0) return true;
		if(colored.length < colors.length) return false;

		var hues:Array<Float> = [for (color in colored) FlxColor.fromRGBFloat(color[0] / 255, color[1] / 255, color[2] / 255).hue];
		for (i in 0...hues.length)
			for (j in i + 1...hues.length)
			{
				var distance:Float = Math.abs(hues[i] - hues[j]);
				if(Math.min(distance, 360 - distance) > 30) return true;
			}
		return false;
	}

	// ------------------------------------------------------------------------------------------
	// HScript
	// ------------------------------------------------------------------------------------------

	#if HSCRIPT_ALLOWED
	static var importsAdded:Bool = false;

	/**
	 * `import ClientPrefs;`, `import flixel.system.FlxSound;`... in HScript: the old names are given the classes they have now.
	 */
	public static function addHScriptImports():Void
	{
		if(importsAdded) return;
		importsAdded = true;
		for (oldName => newName in CLASSES)
		{
			if(Type.resolveClass(oldName) != null || crowplexus.iris.Iris.proxyImports.exists(oldName)) continue;
			var found:Dynamic = Type.resolveClass(newName);
			if(found != null) crowplexus.iris.Iris.proxyImports.set(oldName, found);
		}
	}
	#end
}

/**
 * `camFollowPos` of older versions: the point the game's camera was locked on (the middle of the screen), which went after
 * `camFollow` on its own. Moving it moves the camera right away; it then goes back to `camFollow` the way it does now.
 */
class CameraPosition
{
	var game:states.PlayState;

	public var x(get, set):Float;
	public var y(get, set):Float;

	public function new(game:states.PlayState)
	{
		this.game = game;
	}

	public function setPosition(x:Float = 0, y:Float = 0):CameraPosition
	{
		this.x = x;
		this.y = y;
		return this;
	}

	function get_x():Float
	{
		var camera:FlxCamera = game.camGame;
		return (camera != null) ? camera.scroll.x + camera.width / 2 : 0;
	}

	function set_x(value:Float):Float
	{
		var camera:FlxCamera = game.camGame;
		if(camera != null) camera.scroll.x = value - camera.width / 2;
		return value;
	}

	function get_y():Float
	{
		var camera:FlxCamera = game.camGame;
		return (camera != null) ? camera.scroll.y + camera.height / 2 : 0;
	}

	function set_y(value:Float):Float
	{
		var camera:FlxCamera = game.camGame;
		if(camera != null) camera.scroll.y = value - camera.height / 2;
		return value;
	}
}

/**
 * One of the maps older versions kept what Lua made in (`modchartSprites`, `modchartTweens`...). It all lives in the state's
 * `variables` now, the tweens as "tween_" + their tag, the timers as "timer_"..., so these are views over it: what a script reads,
 * adds or takes out through them is in `variables`, where Lua's own functions find it.
 */
class VariablesView implements haxe.Constraints.IMap<String, Dynamic>
{
	// (the prefixes the other kinds have in `variables`: the sprites and texts have none)
	static final PREFIXES:Array<String> = ['tween_', 'timer_', 'sound_', 'save_'];

	var owner:backend.MusicBeatState;
	var prefix:String;
	var kind:Class<Dynamic>;

	/**
	 * @param prefix  What the tags of this kind start with in `variables` ("" for sprites and texts).
	 * @param kind    Only what's of this class is listed (`keys()`, `iterator()`), null for anything.
	 */
	public function new(owner:backend.MusicBeatState, prefix:String, ?kind:Class<Dynamic>)
	{
		this.owner = owner;
		this.prefix = prefix;
		this.kind = kind;
	}

	inline function all():Map<String, Dynamic> return owner.variables;

	public function get(k:String):Null<Dynamic> return all().get(prefix + k);
	public function set(k:String, v:Dynamic):Void all().set(prefix + k, v);
	public function exists(k:String):Bool return all().exists(prefix + k);
	public function remove(k:String):Bool return all().remove(prefix + k);
	public function clear():Void for (k in [for (k in keys()) k]) remove(k);
	public function copy():haxe.Constraints.IMap<String, Dynamic> return new VariablesView(owner, prefix, kind);
	public function toString():String return Std.string([for (k in keys()) k]);

	function mine(fullKey:String, value:Dynamic):Bool
	{
		if(prefix.length > 0)
		{
			if(!fullKey.startsWith(prefix)) return false;
		}
		else for (other in PREFIXES) if(fullKey.startsWith(other)) return false;
		return kind == null || Std.isOfType(value, kind);
	}

	public function keys():Iterator<String>
		return [for (k => v in all()) if(mine(k, v)) k.substr(prefix.length)].iterator();

	public function iterator():Iterator<Dynamic>
		return [for (k => v in all()) if(mine(k, v)) v].iterator();

	public function keyValueIterator():KeyValueIterator<String, Dynamic>
	{
		var pairs:Map<String, Dynamic> = [for (k => v in all()) if(mine(k, v)) k.substr(prefix.length) => v];
		return pairs.keyValueIterator();
	}
}
