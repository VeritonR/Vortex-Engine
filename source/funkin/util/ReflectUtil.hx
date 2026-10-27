package funkin.util;

/**
 * V-Slice's `ReflectUtil`: what its scripts use in place of `Reflect` and `Type`, with the same functions and a few more.
 */
class ReflectUtil
{
	public static function callMethod(obj:Dynamic, name:String, args:Array<Dynamic>):Dynamic
	{
		return Reflect.callMethod(obj, Reflect.field(obj, name), (args != null) ? args : []);
	}

	public static function compare(valueA:Dynamic, valueB:Dynamic):Int return Reflect.compare(valueA, valueB);
	public static function compareValues(valueA:Dynamic, valueB:Dynamic):Int return Reflect.compare(valueA, valueB);
	public static function compareMethods(functionA:Dynamic, functionB:Dynamic):Bool return Reflect.compareMethods(functionA, functionB);

	public static function copy(obj:Dynamic):Dynamic return Reflect.copy(obj);
	public static function copyAnonymousFieldsOf(obj:Dynamic):Dynamic return Reflect.copy(obj);

	public static function delete(obj:Dynamic, name:String):Bool return Reflect.deleteField(obj, name);
	public static function deleteAnonymousField(obj:Dynamic, name:String):Bool return Reflect.deleteField(obj, name);

	public static function field(obj:Dynamic, name:String):Dynamic return Reflect.field(obj, name);
	public static function getField(obj:Dynamic, name:String):Dynamic return Reflect.field(obj, name);
	public static function getAnonymousField(obj:Dynamic, name:String):Dynamic return Reflect.field(obj, name);

	public static function fields(obj:Dynamic):Array<String> return Reflect.fields(obj);
	public static function getFieldsOf(obj:Dynamic):Array<String> return Reflect.fields(obj);
	public static function getAnonymousFieldsOf(obj:Dynamic):Array<String> return Reflect.fields(obj);

	public static function getProperty(obj:Dynamic, name:String):Dynamic return Reflect.getProperty(obj, name);

	public static function hasField(obj:Dynamic, name:String):Bool return Reflect.hasField(obj, name);
	public static function hasAnonymousField(obj:Dynamic, name:String):Bool return Reflect.hasField(obj, name);

	public static function isEnumValue(value:Dynamic):Bool return Reflect.isEnumValue(value);
	public static function isFunction(value:Dynamic):Bool return Reflect.isFunction(value);
	public static function isObject(value:Dynamic):Bool return Reflect.isObject(value);

	public static function setField(obj:Dynamic, name:String, value:Dynamic):Void Reflect.setField(obj, name, value);
	public static function setAnonymousField(obj:Dynamic, name:String, value:Dynamic):Void Reflect.setField(obj, name, value);
	public static function setProperty(obj:Dynamic, name:String, value:Dynamic):Void Reflect.setProperty(obj, name, value);

	public static function createEmptyInstance(cls:Class<Dynamic>):Dynamic return Type.createEmptyInstance(cls);
	public static function createInstance(cls:Class<Dynamic>, args:Array<Dynamic>):Dynamic return Type.createInstance(cls, (args != null) ? args : []);

	public static function resolveClass(name:String):Class<Dynamic> return Type.resolveClass(name);
	public static function resolveEnum(name:String):Enum<Dynamic> return Type.resolveEnum(name);
	public static function typeof(value:Dynamic):Type.ValueType return Type.typeof(value);

	public static function getClass(obj:Dynamic):Class<Dynamic> return Type.getClass(obj);
	public static function getClassFields(cls:Class<Dynamic>):Array<String> return Type.getClassFields(cls);
	public static function getClassFieldsOf(obj:Dynamic):Array<String>
	{
		var cls:Class<Dynamic> = Type.getClass(obj);
		return (cls != null) ? Type.getClassFields(cls) : [];
	}

	public static function getInstanceFields(cls:Class<Dynamic>):Array<String> return Type.getInstanceFields(cls);
	public static function getInstanceFieldsOf(obj:Dynamic):Array<String>
	{
		var cls:Class<Dynamic> = Type.getClass(obj);
		return (cls != null) ? Type.getInstanceFields(cls) : [];
	}

	public static function getClassName(cls:Class<Dynamic>):String return Type.getClassName(cls);
	public static function getClassNameOf(obj:Dynamic):String
	{
		var cls:Class<Dynamic> = Type.getClass(obj);
		if(cls == null) return 'Unknown';

		var name:String = Type.getClassName(cls);
		return VSLICE_NAMES.exists(name) ? VSLICE_NAMES.get(name) : name;
	}

	/**
	 * The engine's states and menus by the names of the V-Slice ones they stand for: scripts tell where the game is by them
	 * (`getClassNameOf(FlxG.state.subState) == "funkin.play.PauseSubState"`).
	 */
	static final VSLICE_NAMES:Map<String, String> = [
		'states.PlayState' => 'funkin.play.PlayState',
		'substates.PauseSubState' => 'funkin.play.PauseSubState',
		'substates.GameOverSubstate' => 'funkin.play.GameOverSubState',
		'states.ResultsState' => 'funkin.play.ResultState',
		'states.FreeplayStateVslice' => 'funkin.ui.freeplay.FreeplayState',
		'states.FreeplayState' => 'funkin.ui.freeplay.FreeplayState',
		'states.CharacterSelectState' => 'funkin.ui.charSelect.CharSelectSubState',
		'states.StoryMenuState' => 'funkin.ui.story.StoryMenuState',
		'states.MainMenuState' => 'funkin.ui.mainmenu.MainMenuState',
		'states.TitleState' => 'funkin.ui.title.TitleState',
		'options.OptionsState' => 'funkin.ui.options.OptionsState',
		'states.editors.ChartingState' => 'funkin.ui.debug.charting.ChartEditorState'
	];

	public static function makeVarArgs(f:Array<Dynamic>->Dynamic):Dynamic return Reflect.makeVarArgs(f);
}
