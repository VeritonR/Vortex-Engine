package funkin.ui.options;

import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSignal;

/**
 * V-Slice's options menu, as the mods' scripts see it. Mods add their own options to it when it opens (a module's
 * `onStateChangeEnd`, with `event.targetState.optionsCodex.pages.get('preferences').createPrefItemCheckbox(...)`, or a page of
 * their own with `optionsCodex.addPage(...)`).
 *
 * The engine's menu is another one: this one is only made to be given to those scripts (see `VSliceScripts.collectModOptions()`),
 * and what they ask for is written down in its pages. The "Mods" tab of the options shows them, and calls the mods' own functions
 * when they're changed, like V-Slice does (the mods keep their values themselves, usually in `Save.instance.modOptions`).
 */
class OptionsState
{
	public var optionsCodex:OptionsCodex;

	public function new()
	{
		optionsCodex = new OptionsCodex();
	}
}

/**
 * The pages of the menu: "options" (the list of pages), "preferences" and "controls", plus the ones mods add.
 */
class OptionsCodex
{
	public var pages:Map<String, Dynamic> = new Map();
	public var pageOrder:Array<String> = [];
	public var currentPage:String = 'options';

	public function new()
	{
		addPage('options', new OptionsMenu());
		addPage('preferences', new PreferencesMenu());
		addPage('controls', new ControlsMenu());
	}

	public function addPage(name:String, page:Dynamic):Dynamic
	{
		if(!pages.exists(name)) pageOrder.push(name);
		pages.set(name, page);
		if(Std.isOfType(page, PreferencesMenu)) cast(page, PreferencesMenu).pageName = name;
		return page;
	}

	public function switchPage(name:String):Void
	{
		currentPage = name;
	}
}

/**
 * What a mod asked for: a setting of the kind it says, with the function of the mod that's called when it changes.
 */
typedef ModPreference = {
	var kind:String; //"checkbox", "number", "percentage", "enum"
	var name:String;
	var description:String;
	var onChange:Dynamic;
	var value:Dynamic;
	@:optional var values:Array<String>; //(enum: the values, in the order they were given)
	@:optional var labels:Array<String>; //(enum: what's shown for each one)
	@:optional var min:Null<Float>;
	@:optional var max:Null<Float>;
	@:optional var step:Null<Float>;
	@:optional var precision:Null<Int>;
	@:optional var formatter:Dynamic;
	var mod:String; //(the folder of the mod whose script asked for it)
}

/**
 * The page of settings ("preferences", or one a mod added).
 */
class PreferencesMenu extends FlxTypedGroup<FlxBasic>
{
	/**
	 * The mod whose script is being given the menu (set by `VSliceScripts.collectModOptions()`).
	 */
	public static var currentMod:String = null;

	public var pageName:String = 'preferences';
	public var entries:Array<ModPreference> = [];
	public var onExit:FlxSignal = new FlxSignal();
	public var enabled:Bool = true;

	public function new()
	{
		super();
	}

	public function createPrefItemCheckbox(name:String, description:String, onChange:Dynamic, defaultValue:Bool, ?available:Bool):Dynamic
	{
		if(available == false) return null;
		entries.push({kind: 'checkbox', name: name, description: description, onChange: onChange, value: (defaultValue == true), mod: currentMod});
		return null;
	}

	public function createPrefItemNumber(name:String, description:String, onChange:Dynamic, ?formatter:Dynamic, defaultValue:Dynamic, min:Dynamic,
		max:Dynamic, ?step:Dynamic, ?precision:Dynamic):Dynamic
	{
		entries.push({kind: 'number', name: name, description: description, onChange: onChange, value: number(defaultValue, 0), formatter: formatter,
			min: number(min, 0), max: number(max, 100), step: number(step, 1), precision: Std.int(number(precision, 0)), mod: currentMod});
		return null;
	}

	public function createPrefItemPercentage(name:String, description:String, onChange:Dynamic, defaultValue:Dynamic, ?min:Dynamic, ?max:Dynamic):Dynamic
	{
		entries.push({kind: 'percentage', name: name, description: description, onChange: onChange, value: Std.int(number(defaultValue, 100)),
			min: number(min, 0), max: number(max, 100), step: 10, mod: currentMod});
		return null;
	}

	public function createPrefItemEnum(name:String, description:String, values:Dynamic, onChange:Dynamic, defaultValue:Dynamic):Dynamic
	{
		var keys:Array<String> = [];
		var labels:Array<String> = [];
		// (a map of value => what's shown, or a plain list)
		if(Std.isOfType(values, Array))
		{
			for (value in (values:Array<Dynamic>))
			{
				keys.push(Std.string(value));
				labels.push(Std.string(value));
			}
		}
		else if(values != null)
		{
			var map:haxe.Constraints.IMap<Dynamic, Dynamic> = cast values;
			for (key in map.keys())
			{
				keys.push(Std.string(key));
				labels.push(Std.string(map.get(key)));
			}
		}
		if(keys.length < 1) return null;
		entries.push({kind: 'enum', name: name, description: description, onChange: onChange, value: Std.string(defaultValue), values: keys,
			labels: labels, mod: currentMod});
		return null;
	}

	// (anything else of V-Slice's page a script may call: nothing to do here)
	public function createPrefHeader(?name:String):Dynamic return null;

	static function number(value:Dynamic, fallback:Float):Float
	{
		if(value == null) return fallback;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}

/**
 * The list of pages. A mod can add a line to it that opens its own page: the engine shows all of them in one tab anyway.
 */
class OptionsMenu extends FlxTypedGroup<FlxBasic>
{
	public var onExit:FlxSignal = new FlxSignal();
	public var enabled:Bool = true;

	public function new()
	{
		super();
	}

	public function createItem(name:String, ?onChange:Dynamic, ?fireInstantly:Bool = false):Dynamic
	{
		return new flixel.text.FlxText(0, 0, 0, name);
	}
}

class ControlsMenu extends FlxTypedGroup<FlxBasic>
{
	public var onExit:FlxSignal = new FlxSignal();
	public var enabled:Bool = true;

	public function new()
	{
		super();
	}
}
