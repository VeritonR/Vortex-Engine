package funkin.modding.base;

#if HSCRIPT_ALLOWED
import hxc.HxcRuntime;

/**
 * V-Slice's "Scripted" classes, for the mods that make their script classes through them:
 *
 *     var thing = ScriptedFlxSprite.init('MyScriptedSprite', 100, 200);
 *
 * which is the same as `new MyScriptedSprite(100, 200)` (older versions of V-Slice couldn't do that one).
 * `listScriptClasses()` gives the names of the script classes that extend what the class is for.
 */
class ScriptedClasses
{
	public static function make(base:Class<Dynamic>, args:Array<Dynamic>):Dynamic
	{
		var name:String = (args != null && args.length > 0) ? Std.string(args[0]) : null;
		var cls = (name != null) ? HxcRuntime.classes.get(name) : null;
		if(cls == null)
		{
			trace('There is no script class called "$name"');
			return null;
		}

		var made = HxcRuntime.instantiate(cls, args.slice(1));
		return (made != null) ? made.self : null;
	}

	public static function list(base:Class<Dynamic>):Array<String>
	{
		return [for (cls in HxcRuntime.listSubclasses(base)) cls.name];
	}
}

class ScriptedFlxBasic
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.FlxBasic, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.FlxBasic);
}

class ScriptedFlxObject
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.FlxObject, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.FlxObject);
}

class ScriptedFlxSprite
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.FlxSprite, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.FlxSprite);
}

class ScriptedFunkinSprite
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(funkin.graphics.FunkinSprite, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(funkin.graphics.FunkinSprite);
}

class ScriptedFlxSpriteGroup
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.group.FlxSpriteGroup, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.group.FlxSpriteGroup);
}

class ScriptedFlxTypedGroup
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.group.FlxGroup, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.group.FlxGroup);
}

class ScriptedFlxState
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.FlxState, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.FlxState);
}

class ScriptedFlxSubState
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.FlxSubState, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.FlxSubState);
}

class ScriptedMusicBeatState
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(backend.MusicBeatState, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(backend.MusicBeatState);
}

class ScriptedMusicBeatSubState
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(backend.MusicBeatSubstate, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(backend.MusicBeatSubstate);
}

class ScriptedFlxRuntimeShader
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(flixel.addons.display.FlxRuntimeShader, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(flixel.addons.display.FlxRuntimeShader);
}
#end
