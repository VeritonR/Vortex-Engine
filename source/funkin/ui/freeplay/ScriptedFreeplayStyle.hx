package funkin.ui.freeplay;

/**
 * V-Slice's "Scripted" class of its Freeplay freeplaystyles (see funkin.modding.base.ScriptedClasses): `listScriptClasses()`, and
 * `init()`/`scriptInit()` to make one of a script class.
 */
class ScriptedFreeplayStyle
{
	#if HSCRIPT_ALLOWED
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return funkin.modding.base.ScriptedClasses.make(FreeplayStyle, args));
	public static var scriptInit:Dynamic = init;
	public static function listScriptClasses():Array<String> return funkin.modding.base.ScriptedClasses.list(FreeplayStyle);
	#else
	public static function scriptInit(name:String, id:String):Dynamic return null;
	public static function listScriptClasses():Array<String> return [];
	#end
}
