package funkin.modding.base;

#if HSCRIPT_ALLOWED
import funkin.modding.base.ScriptedClasses;

/*
 * V-Slice's "Scripted" class of flixel's strips, see funkin.modding.base.ScriptedClasses.
 */
class ScriptedFlxStrip
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.FlxStrip, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.FlxStrip);
}
#end
