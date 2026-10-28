package psychlua;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
import psychlua.HScript.HScriptInfos;
#end
import flixel.FlxState;
import flixel.FlxSubState;

/**
 * Vortex Engine: scripts of the game's screens ("states"), apart from the songs' ones.
 *
 * A mod puts them in a "states" folder (mods/My-Mod/states/, or mods/states/ for every mod), named after the screen they're for:
 * "MainMenuState.hx", "TitleState.hx", "LoadingState.hx", "FreeplayStateVslice.hx"... and "Global.hx" for every screen.
 * They're HScript (.hx), with the screen as `game` (its things are reached by their names, and add(), insert(), remove() work).
 *
 * Callbacks: onCreate() (before the screen makes its things), onCreatePost() (after), onUpdate(elapsed), onUpdatePost(elapsed),
 * onStepHit(), onBeatHit(), onOpenSubState(name), onCloseSubState(), onDestroy(). The loading screen also has
 * onLoadingProgress(loaded, total, percent) and onFinishedLoading() (return Function_Stop to keep it on the screen, then call
 * finishLoading() to go on). See section 11 of scripts.txt.
 *
 * Songs (PlayState) aren't here: they have their own scripts (scripts/, data/<song>/, stages/...).
 */
class StateScripts
{
	public static final FOLDER:String = 'states/';
	public static final GLOBAL_NAME:String = 'Global';

	#if HSCRIPT_ALLOWED
	public static var scripts(default, null):Array<HScript> = [];
	#end
	static var state:FlxState = null;
	static var started:Bool = false;

	/**
	 * Things scripts keep from one screen to the next (a state script and the song's scripts, for example):
	 * `sharedData.myThing = 1;` in HScript, getPropertyFromClass('psychlua.StateScripts', 'sharedData.myThing') in Lua.
	 */
	public static var sharedData:Dynamic = {};

	/**
	 * Starts listening to the screens being made and changed (once, when the game starts).
	 */
	public static function init():Void
	{
		#if HSCRIPT_ALLOWED
		if(started) return;
		started = true;

		FlxG.signals.preStateSwitch.add(unload);
		FlxG.signals.preStateCreate.add(load);
		FlxG.signals.postStateSwitch.add(function()
		{
			creating = false;
			for (line in pending) print(line.text, line.color);
			pending = [];
			call('onCreatePost');
		});
		FlxG.signals.preUpdate.add(function() if(state == FlxG.state) call('onUpdate', [FlxG.elapsed]));
		FlxG.signals.postUpdate.add(function() if(state == FlxG.state) call('onUpdatePost', [FlxG.elapsed]));
		#end
	}

	/**
	 * The name scripts of a screen go by: its class's ("MainMenuState").
	 */
	public static function nameOf(state:FlxState):String
	{
		if(state == null) return '';
		var name:String = Type.getClassName(Type.getClass(state));
		return name.substr(name.lastIndexOf('.') + 1);
	}

	static function load(newState:FlxState):Void
	{
		#if HSCRIPT_ALLOWED
		unload();
		state = newState;
		creating = true; //(what's printed now is shown once the screen is made: it starts its cameras over)
		if(newState == null || Std.isOfType(newState, states.PlayState)) return;

		var name:String = nameOf(newState);
		for (fileName in [GLOBAL_NAME, name])
		{
			for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), FOLDER))
			{
				var path:String = folder + fileName + '.hx';
				if(!FileSystem.exists(path)) continue;

				try
				{
					var script:HScript = new HScript(null, path);
					preset(script);
					scripts.push(script);
				}
				catch(e:IrisError)
				{
					var pos:HScriptInfos = cast {fileName: path, showLine: false};
					Iris.error(Printer.errorToString(e, false), pos);
				}
			}
		}
		if(scripts.length < 1) return;

		newState.subStateOpened.add(function(sub:FlxSubState) call('onOpenSubState', [nameOf(sub)]));
		newState.subStateClosed.add(function(_) call('onCloseSubState'));
		call('onCreate');
		#end
	}

	static function unload():Void
	{
		#if HSCRIPT_ALLOWED
		if(scripts.length > 0)
		{
			call('onDestroy');
			for (script in scripts)
				if(script != null) script.destroy();
			scripts = [];
		}
		state = null;
		#end
	}

	#if HSCRIPT_ALLOWED
	// What every state script has besides what any HScript has
	static function preset(script:HScript):Void
	{
		script.set('game', state);
		script.set('state', state);
		script.set('stateName', nameOf(state));
		script.set('sharedData', sharedData);
		// (haxe.Json can't be imported by scripts)
		script.set('parseJson', function(text:String):Dynamic {
			try { return tjson.TJSON.parse(text); }
			catch(e:Dynamic) { return null; }
		});
		script.set('debugPrint', function(text:Dynamic, ?color:FlxColor = null) print(Std.string(text), (color != null) ? color : FlxColor.WHITE));

		// goes to another screen, by its name ("MainMenuState", "options.OptionsState") or a screen made by the script
		script.set('switchState', function(target:Dynamic, ?args:Array<Dynamic>) {
			var next:FlxState = Std.isOfType(target, FlxState) ? target : makeState(Std.string(target), args);
			if(next == null)
			{
				print('switchState: there is no screen named "$target"', FlxColor.RED);
				return false;
			}
			MusicBeatState.switchState(next);
			return true;
		});
		script.set('resetState', function() MusicBeatState.resetState());

		// the loading screen
		if(Std.isOfType(state, states.LoadingState))
		{
			var loading:states.LoadingState = cast state;
			script.set('finishLoading', function() loading.finishLoading());
			script.set('hideLoadingScreen', function(?bar:Bool = false) loading.hideDefaultScreen(bar));
		}
	}
	#end

	public static function makeState(name:String, ?args:Array<Dynamic>):FlxState
	{
		if(name == null || name.length < 1) return null;
		var cls:Class<Dynamic> = Type.resolveClass(name);
		if(cls == null) cls = Type.resolveClass('states.' + name);
		if(cls == null) cls = Type.resolveClass('options.' + name);
		if(cls == null) cls = Type.resolveClass('states.editors.' + name);
		if(cls == null) return null;
		try
		{
			var made:Dynamic = Type.createInstance(cls, (args != null) ? args : []);
			return Std.isOfType(made, FlxState) ? made : null;
		}
		catch(e:Dynamic) {}
		return null;
	}

	/**
	 * Calls a function on the scripts of the screen, returning what they returned (Function_Continue if nothing).
	 */
	public static function call(func:String, ?args:Array<Dynamic>):Dynamic
	{
		var result:Dynamic = LuaUtils.Function_Continue;
		#if HSCRIPT_ALLOWED
		if(scripts.length < 1) return result;

		for (script in scripts.copy())
		{
			if(script == null || !script.exists(func)) continue;
			try
			{
				var called = script.call(func, args);
				if(called != null && called.returnValue != null && called.returnValue != LuaUtils.Function_Continue)
					result = called.returnValue;
			}
			catch(e:Dynamic)
			{
				print('ERROR: ($func) ${script.filePath}: $e', FlxColor.RED);
			}
		}
		#end
		return result;
	}

	/**
	 * Sets a variable on the scripts of the screen.
	 */
	public static function set(name:String, value:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		for (script in scripts)
			if(script != null) script.set(name, value);
		#end
	}

	public static var hasScripts(get, never):Bool;
	static function get_hasScripts():Bool
		return #if HSCRIPT_ALLOWED scripts.length > 0 #else false #end;

	// ------------------------------------------------------------------------------------------
	// Messages of the scripts on the screen (debugPrint and errors), out of songs
	// ------------------------------------------------------------------------------------------

	static var printed:Array<FlxText> = [];
	static var printCamera:FlxCamera = null;
	static var creating:Bool = false;
	static var pending:Array<{text:String, color:FlxColor}> = [];

	/**
	 * Shows a line on the screen for a few seconds, over everything: debugPrint and the scripts' errors, in menus.
	 */
	public static function print(text:String, color:FlxColor = FlxColor.WHITE):Void
	{
		var current:FlxState = FlxG.state;
		if(creating || current == null)
		{
			pending.push({text: text, color: color});
			return;
		}
		trace(text);

		if(printCamera == null || !FlxG.cameras.list.contains(printCamera))
		{
			printCamera = new FlxCamera();
			printCamera.bgColor = FlxColor.TRANSPARENT;
			FlxG.cameras.add(printCamera, false);
			printed = [];
		}

		for (line in printed) line.y += 20;
		var line:FlxText = new FlxText(10, 10, FlxG.width - 20, text, 16);
		line.setFormat(Paths.font('vcr.ttf'), 16, color, LEFT, OUTLINE, FlxColor.BLACK);
		line.scrollFactor.set();
		line.cameras = [printCamera];
		current.add(line);
		printed.push(line);
		FlxTween.tween(line, {alpha: 0}, 1, {startDelay: 5, onComplete: function(_)
		{
			printed.remove(line);
			if(line.exists) current.remove(line, true);
			line.destroy();
		}});
	}
}
