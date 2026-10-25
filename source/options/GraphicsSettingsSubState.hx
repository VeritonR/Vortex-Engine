package options;

import objects.Character;
import flixel.FlxG;
import openfl.filters.ShaderFilter;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	
	// =======================================================
	// VARIÁVEIS GLOBAIS DO SHADER DE NITIDEZ
	// =======================================================
	public static var globalSharpenShader:SharpenShader = new SharpenShader();
	public static var globalSharpenFilter:ShaderFilter = new ShaderFilter(globalSharpenShader);

	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu'; //for Discord Rich Presence

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;

		// =======================================================================
		// MODO JANELA E EFEITO DE NITIDEZ
		// =======================================================================
		var option:Option = new Option('Window Mode',
			'Choose how the game is displayed on your monitor.',
			'windowMode',
			STRING,
			['Windowed', 'Fullscreen']);
		option.onChange = onChangeWindowMode;
		addOption(option);

		var option:Option = new Option('Sharpness',
			'Increases image sharpness to remove bluriness on fullscreen.\n(0% is disabled)',
			'sharpness',
			INT);
		option.minValue = 0;
		option.maxValue = 100;
		option.displayFormat = '%v%';
		option.onChange = onChangeSharpness;
		addOption(option);
		// =======================================================================

		var option:Option = new Option('Low Quality', //Name
			'If checked, disables some background details,\ndecreases loading times and improves performance.', //Description
			'lowQuality', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing; //Changing onChange is only needed if you want to make a special interaction after it changes the value
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Shaders', //Name
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker PCs.", //Description
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching', //Name
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nDon't turn this on if you have a shitty Graphics Card.", //Description
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !html5
		var option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(flixel.math.FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#end

		super();
		insert(1, boyfriend);
	}

	// =======================================================================
	// APLICADOR DO MODO JANELA CORRIGIDO (SEM BUG DE ENCOLHER)
	// =======================================================================
	function onChangeWindowMode()
	{
		ClientPrefs.applyWindowMode(ClientPrefs.data.windowMode);
	}

	// =======================================================================
	// LÓGICA DO FILTRO DE NITIDEZ CORRIGIDA
	// =======================================================================
	function onChangeSharpness()
	{
		applySharpness(ClientPrefs.data.sharpness);
	}

	static var listeningToResizes:Bool = false;

	public static function applySharpness(value:Int)
	{
		if (FlxG.game == null) return;

		// The filter works on the game as the window shows it, so a pixel is one of the window's (not of the game's 1280x720):
		// kept up to date when the window or the game change size
		if (!listeningToResizes)
		{
			listeningToResizes = true;
			FlxG.signals.gameResized.add(function(_, _) updateSharpnessSize());
		}
		updateSharpnessSize();
		if (value > 0) globalSharpenShader.amount.value = [value / 100.0];

		// Only this one is added or taken out, the game can have others. They're read from flixel's own list: the game sprite's
		// `filters` gives copies of them, where this one is never found (each change added another one on top of the others)
		@:privateAccess var current:Array<openfl.filters.BitmapFilter> = FlxG.game._filters;
		var filters:Array<openfl.filters.BitmapFilter> = [];
		if (current != null)
			for (filter in current)
				if (filter != null && !isSharpenFilter(filter))
					filters.push(filter);
		if (value > 0) filters.push(globalSharpenFilter);
		FlxG.game.setFilters(filters.length > 0 ? filters : null);
	}

	static function isSharpenFilter(filter:openfl.filters.BitmapFilter):Bool
	{
		var shaderFilter:ShaderFilter = Std.downcast(filter, ShaderFilter);
		return filter == globalSharpenFilter || (shaderFilter != null && shaderFilter.shader == globalSharpenShader);
	}

	static function updateSharpnessSize()
	{
		var width:Float = (FlxG.scaleMode != null) ? FlxG.scaleMode.gameSize.x : FlxG.width;
		var height:Float = (FlxG.scaleMode != null) ? FlxG.scaleMode.gameSize.y : FlxG.height;
		globalSharpenShader.res.value = [Math.max(1.0, width), Math.max(1.0, height)];
	}
	// =======================================================================

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = ClientPrefs.data.framerate;
			FlxG.drawFramerate = ClientPrefs.data.framerate;
		}
		else
		{
			FlxG.drawFramerate = ClientPrefs.data.framerate;
			FlxG.updateFramerate = ClientPrefs.data.framerate;
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}

// =======================================================================
// O SHADER DE NITIDEZ CORRIGIDO
// =======================================================================
class SharpenShader extends flixel.system.FlxAssets.FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform float amount;
		uniform vec2 res;

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			vec2 step = 1.0 / res;

			vec4 color = texture2D(bitmap, uv);
			vec4 up    = texture2D(bitmap, uv + vec2(0.0, -step.y));
			vec4 down  = texture2D(bitmap, uv + vec2(0.0, step.y));
			vec4 left  = texture2D(bitmap, uv + vec2(-step.x, 0.0));
			vec4 right = texture2D(bitmap, uv + vec2(step.x, 0.0));

			// (the colors only: see-through edges keep their transparency, and the colors are premultiplied so none goes past it)
			vec3 sharp = color.rgb + (color.rgb * 4.0 - (up.rgb + down.rgb + left.rgb + right.rgb)) * amount;
			gl_FragColor = vec4(clamp(sharp, 0.0, color.a), color.a);
		}
	')
	public function new()
	{
		super();
		this.amount.value = [0.0];
		this.res.value = [1280.0, 720.0];
	}
}