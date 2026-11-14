package funkin.group;

#if HSCRIPT_ALLOWED
import funkin.modding.base.ScriptedClasses;

/*
 * V-Slice's "Scripted" classes of `FunkinGroup` (`ScriptedFunkinGroup.init('MyGroup')`, `listScriptClasses()`), see
 * funkin.modding.base.ScriptedClasses. A script class that extends one of them is a `FunkinGroup`.
 */
class ScriptedFunkinGroup
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(FunkinGroup, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(FunkinGroup);
}

class ScriptedFunkinSpriteGroup
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(FunkinGroup, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(FunkinGroup);
}
#end
