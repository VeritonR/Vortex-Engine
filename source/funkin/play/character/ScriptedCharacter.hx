package funkin.play.character;

#if HSCRIPT_ALLOWED
import funkin.modding.base.ScriptedClasses;

/*
 * V-Slice's "Scripted" classes of the characters (`ScriptedSparrowCharacter.init('MyCharacter', 'id')`, `listScriptClasses()`), see
 * funkin.modding.base.ScriptedClasses.
 */
class ScriptedBaseCharacter
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(BaseCharacter, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(BaseCharacter);
}

class ScriptedSparrowCharacter
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(BaseCharacter.SparrowCharacter, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(BaseCharacter.SparrowCharacter);
}

class ScriptedMultiSparrowCharacter
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(BaseCharacter.MultiSparrowCharacter, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(BaseCharacter.MultiSparrowCharacter);
}

class ScriptedPackerCharacter
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(BaseCharacter.PackerCharacter, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(BaseCharacter.PackerCharacter);
}

class ScriptedAnimateAtlasCharacter
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(BaseCharacter.AnimateAtlasCharacter, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(BaseCharacter.AnimateAtlasCharacter);
}

class ScriptedMultiAnimateAtlasCharacter
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(BaseCharacter.MultiAnimateAtlasCharacter, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(BaseCharacter.MultiAnimateAtlasCharacter);
}
#end
