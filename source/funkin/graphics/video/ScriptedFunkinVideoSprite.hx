package funkin.graphics.video;

#if HSCRIPT_ALLOWED
import funkin.modding.base.ScriptedClasses;

/*
 * V-Slice's "Scripted" class of the video sprites, see funkin.modding.base.ScriptedClasses.
 */
class ScriptedFunkinVideoSprite
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(FunkinVideoSprite, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(FunkinVideoSprite);
}
#end
