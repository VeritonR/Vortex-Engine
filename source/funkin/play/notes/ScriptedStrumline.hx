package funkin.play.notes;

#if HSCRIPT_ALLOWED
import funkin.modding.base.ScriptedClasses;

/*
 * V-Slice's "Scripted" class of the strumlines, see funkin.modding.base.ScriptedClasses.
 */
class ScriptedStrumline
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(Strumline, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(Strumline);
}
#end
