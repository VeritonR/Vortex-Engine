package hxc;

#if HSCRIPT_ALLOWED
import crowplexus.hscript.Expr;
import crowplexus.hscript.Interp;
import crowplexus.hscript.Printer;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Objects made by the engine that a script class can be attached to have this, so their script is found right away.
 */
interface IHxcScripted
{
	var __hxc:HxcInstance;
}

/**
 * For the classes scripts extend whose scripts get attached to an object of another class (V-Slice's characters, attached to Psych's):
 * an object of the class the script extends is made as well, to hold what that class has and the other object doesn't.
 * It's told which object the script was attached to.
 */
interface IHxcMixin
{
	function attachTo(target:Dynamic):Void;
}

/**
 * Runs the scripted classes of V-Slice mods (.hxc files).
 *
 * On V-Slice a script is a class that extends one of the game's: `class MyModule extends Module`, `class MyNote extends ScriptedNoteKind`...
 * The library the engine uses for HScript only reads classes, it doesn't run them, that part is done here:
 * - `HxcClass` is a class of a script file, `HxcInstance` an object made out of one.
 * - Each instance has an object of the engine's class it extends (its "base"), made when the script calls `super(...)`.
 *   What the script declares comes first, everything else goes to the base, and `super.something()` always goes to it.
 * - To the scripts and to the engine the base *is* the object, `HxcRuntime.getInstance()` finds the script attached to it.
 */
class HxcRuntime
{
	/**
	 * Every script class that was loaded, by name.
	 */
	public static var classes:Map<String, HxcClass> = [];

	/**
	 * What scripts can use without importing, like on Haxe itself.
	 */
	public static var globals:Map<String, Dynamic> = makeGlobals();

	/**
	 * Imports that don't lead to a class of the same name: abstracts, and things the engine has somewhere else.
	 * The value can be the class itself or the path of another one.
	 */
	public static var customImports:Map<String, Dynamic> = [
		'flixel.math.FlxPoint' => 'flixel.math.FlxBasePoint',
		'haxe.Json' => 'hxc.HxcJson'
	];

	/**
	 * Classes that are only there to make script classes (V-Slice's `ScriptedFlxSprite.init('MyClass')` and such), by name, and the class
	 * a script class really extends when it extends one of them: `class MyMenu extends ScriptedMusicBeatSubState` is a substate.
	 */
	public static var extendedThrough:Map<String, Class<Dynamic>> = [];

	/**
	 * Classes of the engine that take other values than V-Slice's version of them when they're made, by name: what makes one out of
	 * V-Slice's values, or null to leave them to the class itself.
	 */
	public static var constructors:Map<String, Array<Dynamic>->Dynamic> = [];

	/**
	 * What scripts find by name when they use something they didn't import, after everything else was tried.
	 */
	public static var fallbacks:Map<String, Dynamic> = [];

	/**
	 * Classes that stand for an object of the engine, with V-Slice's names for its things (what `PlayState.instance` is for scripts, for one),
	 * and how to get that object out of one of them. What scripts ask of them that they don't have is asked of the object:
	 * everything the engine's own has is there for scripts too, like on V-Slice where they're one and the same.
	 */
	public static var standIns:Map<String, Dynamic->Dynamic> = [];

	/**
	 * For the stand-ins of `standIns` that have it: the names the class they stand for has on V-Slice. Only what has one of these names
	 * is asked of the engine's object, anything else doesn't exist for scripts, like on V-Slice. The engine's object has things of its own
	 * with names V-Slice's doesn't use (`strumLineNotes`...), which scripts written for both kinds of engines check for to do what they do
	 * on the other kind.
	 */
	public static var standInNames:Map<String, Map<String, Bool>> = [];

	/**
	 * For the stand-ins of `standIns`: the class of the engine's object they stand for, which counts as one of them when scripts
	 * check what something is (`FlxG.state is PlayState` is the engine's PlayState there, the stand-in is only what scripts are given).
	 */
	public static var standInTypes:Map<String, Class<Dynamic>> = [];

	/**
	 * Static variables of the libraries that V-Slice's scripts can change and can't be changed through reflection here (`FlxG.width`,
	 * which the library only lets itself change), by the name of the class and then of the variable: what changes them.
	 */
	public static var staticSetters:Map<String, Map<String, Dynamic->Void>> = [];

	/**
	 * While this is on, a class that has the name of one that's already loaded takes its place without it being reported:
	 * the scripts of a mod are loaded over the ones of the base game, and replacing those is how mods change them.
	 */
	public static var quietReplace:Bool = false;

	/**
	 * For the classes of the libraries that scripts extend and override functions of: by the name of the class, a class of the engine
	 * that extends it and sends those functions to the script (see `IHxcScripted`). It's what gets made when a script class that extends
	 * the first one is made; whatever else makes that class gets the real one.
	 */
	public static var scriptedBases:Map<String, Class<Dynamic>> = [
		'flixel.FlxSprite' => funkin.graphics.FunkinSprite,
		'flixel.group.FlxTypedSpriteGroup' => funkin.graphics.ScriptedSpriteGroup,
		'flixel.group.FlxTypedGroup' => funkin.graphics.ScriptedGroup,

		// menus of the mods' own
		'flixel.FlxState' => funkin.ui.ScriptedState,
		'flixel.addons.transition.FlxTransitionableState' => funkin.ui.ScriptedState,
		'backend.MusicBeatState' => funkin.ui.ScriptedState,
		'flixel.FlxSubState' => funkin.ui.ScriptedState.ScriptedSubState,
		'backend.MusicBeatSubstate' => funkin.ui.ScriptedState.ScriptedSubState
	];

	/**
	 * The object something stands for, when it's the one that has a member and not the stand-in. Null otherwise.
	 */
	public static function getStoodFor(object:Dynamic, name:String):Dynamic
	{
		if(object == null || !Reflect.isObject(object) || Std.isOfType(object, String)) return null;

		var cls:Class<Dynamic> = Type.getClass(object);
		if(cls == null) return null;

		var className:String = Type.getClassName(cls);
		var getter:Dynamic->Dynamic = standIns.get(className);
		if(getter == null || hasNativeField(object, name)) return null;

		var names:Map<String, Bool> = standInNames.get(className);
		if(names != null && !names.exists(name)) return null;

		var real:Dynamic = getter(object);
		return (real != null && hasNativeField(real, name)) ? real : null;
	}

	/**
	 * Classes scripts extend without importing them (they're on the same package as the "Scripted" ones on V-Slice).
	 */
	public static var defaultBases:Map<String, String> = [];

	/**
	 * Called with every error of a script, they never get to crash the game.
	 */
	public static dynamic function onError(message:String):Void
	{
		trace('[HXC] $message');
	}

	/**
	 * Static functions V-Slice's version of a library has and the engine's doesn't (`FlxTimer.wait()`), by the name of the class and then of the function.
	 */
	public static var staticExtras:Map<String, Map<String, Dynamic>> = [];

	/**
	 * The same for functions of objects, these receive the object before what the script gave them.
	 */
	public static var memberExtras:Map<String, Map<String, Dynamic>> = [];

	/**
	 * Functions of the libraries' objects scripts get another version of, by the name of the function and then of the class.
	 * Like the ones of `memberExtras`, they receive the object before what the script gave them.
	 */
	public static var memberReplacements:Map<String, Map<String, Dynamic>> = [];

	/**
	 * The same for the static functions of the libraries' classes: by the name of the function and then of the class.
	 * They receive the class before what the script gave them.
	 */
	public static var staticReplacements:Map<String, Map<String, Dynamic>> = [];

	/**
	 * Things of the engine's objects that are something else to scripts, by their name and then by the name of the class (or of one it extends).
	 * Each one is a function that receives the object and returns what the script gets, or null for what the object really has there.
	 */
	public static var memberGetters:Map<String, Map<String, Dynamic>> = [];

	/**
	 * Asked for what an object doesn't have before giving up on it, for the things that are somewhere else on the engine's version of a class.
	 */
	public static dynamic function resolveMissing(object:Dynamic, name:String):Dynamic
	{
		return null;
	}

	static var importCache:Map<String, Dynamic> = [];

	// What each script file was read into, by its path. Kept for as long as the file's text doesn't change
	static var parseCache:Map<String, {code:String, decls:Array<ModuleDecl>, usings:Array<String>, moduleExprs:Array<Expr>}> = [];
	static var attached:haxe.ds.ObjectMap<Dynamic, HxcInstance> = new haxe.ds.ObjectMap();
	static var attachedCount:Int = 0;
	static var reportedErrors:Map<String, Bool> = [];

	// What scripts put on objects of the engine that don't have a variable for it, see setExtra()
	static var extraFields:haxe.ds.ObjectMap<Dynamic, Map<String, Dynamic>> = new haxe.ds.ObjectMap();
	static var extraCount:Int = 0;
	static var classFields:Map<String, Map<String, Bool>> = [];

	/**
	 * What the "is" operator of scripts answers: if a value is of a class, the classes made by scripts included
	 * (an object made from one of those, or from one that extends it).
	 */
	public static function isOfType(value:Dynamic, type:Dynamic):Bool
	{
		if(value == null || type == null) return false;

		if(type == HScriptedClass) return getInstance(value) != null;
		if(Std.isOfType(type, HxcClass))
		{
			var instance:HxcInstance = getInstance(value);
			return instance != null && instance.cls != null && instance.cls.getChain().contains(cast type);
		}

		try
		{
			if(Std.isOfType(value, type)) return true;
			var stoodFor:Class<Dynamic> = Std.isOfType(type, Class) ? standInTypes.get(Type.getClassName(type)) : null;
			return stoodFor != null && Std.isOfType(value, stoodFor);
		}
		catch(e:Dynamic) {}
		return false;
	}

	static function makeGlobals():Map<String, Dynamic>
	{
		var list:Map<String, Dynamic> = [
			'Std' => Std,
			'Math' => Math,
			'StringTools' => ScriptStringTools, //(Haxe's, without inline functions scripts couldn't call)
			'Reflect' => Reflect,
			'Type' => Type,
			'Lambda' => Lambda,
			'Date' => Date,
			'Json' => HxcJson,
			'String' => String,
			'Int' => Int,
			'Float' => Float,
			'Bool' => Bool,
			'Array' => Array,
			'Dynamic' => Dynamic,
			'Map' => haxe.ds.StringMap,
			'StringMap' => haxe.ds.StringMap,
			'IntMap' => haxe.ds.IntMap,
			'ObjectMap' => haxe.ds.ObjectMap,
			'true' => true,
			'false' => false
		];
		list.set('null', null);
		list.set(HxcParser.IS_FUNCTION, isOfType);
		list.set('trace', Reflect.makeVarArgs(function(values:Array<Dynamic>) trace(values.join(', '))));
		return list;
	}

	// ------------------------------------------------------------------------------------------
	// Loading
	// ------------------------------------------------------------------------------------------

	/**
	 * Forgets every class and instance, to be called before loading the scripts of another mod.
	 */
	public static function clear():Void
	{
		classes = [];
		attached = new haxe.ds.ObjectMap();
		attachedCount = 0;
		reportedErrors = [];
		extraFields = new haxe.ds.ObjectMap();
		extraCount = 0;
	}

	#if sys
	/**
	 * Loads every .hxc file inside a folder and the folders inside of it, returns how many classes were found.
	 */
	public static function loadFolder(folder:String):Int
	{
		if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) return 0;

		var count:Int = 0;
		for (file in FileSystem.readDirectory(folder))
		{
			var path:String = haxe.io.Path.addTrailingSlash(folder) + file;
			if(FileSystem.isDirectory(path)) count += loadFolder(path);
			else if(file.toLowerCase().endsWith('.hxc'))
			{
				try
				{
					count += loadSource(File.getContent(path), path);
				}
				catch(e:Dynamic)
				{
					onError('Could not read "$path": $e');
				}
			}
		}
		return count;
	}
	#end

	/**
	 * Reads the classes of a script file from its text, returns how many it had.
	 */
	public static function loadSource(code:String, origin:String):Int
	{
		if(code.fastCodeAt(0) == 0xFEFF) code = code.substr(1); //UTF-8 BOM

		// Scripts are loaded again for every song (and for some menus), reading one is the slow part and gives the same thing every time
		var parsed = parseCache.get(origin);
		if(parsed == null || parsed.code != code)
		{
			var parser:HxcParser = new HxcParser();
			try
			{
				parsed = {code: code, decls: parser.parseModule(HxcParser.expandStrings(code), origin), usings: parser.usings, moduleExprs: parser.moduleExprs};
			}
			catch(e:Dynamic)
			{
				parseCache.remove(origin);
				onError('Could not parse "$origin": ' + describeError(e));
				return 0;
			}
			parseCache.set(origin, parsed);
		}
		var decls:Array<ModuleDecl> = parsed.decls;

		var module:HxcModule = new HxcModule(origin);
		module.usings = parsed.usings;

		for (decl in decls)
		{
			switch(decl)
			{
				case DImport(path, everything, alias):
					if(everything == true) continue; //whole packages can't be listed at runtime

					var fullPath:String = path.join('.');
					var name:String = (alias != null && alias.length > 0) ? alias : path[path.length - 1];
					var value:Dynamic = resolveImport(fullPath);
					if(value != null) module.imports.set(name, value);
					else if(isNameUsed(code, name)) module.missingImports.push(fullPath);
					else module.unusedImports.push(fullPath); //lots of scripts import things they never touch, those can't break anything

				case DClass(classDecl):
					var cls:HxcClass = new HxcClass(classDecl, module);
					module.classes.push(cls);
					if(classes.exists(cls.name) && !quietReplace) onError('The class "${cls.name}" of "$origin" replaces the one of "${classes.get(cls.name).module.path}"');
					classes.set(cls.name, cls);

				default:
			}
		}

		// Enums declared on the file are visible to its classes like something they imported
		if(parsed.moduleExprs.length > 0)
		{
			try
			{
				var interp:Interp = new Interp();
				var builtIn:Array<String> = [for (name in interp.variables.keys()) name];
				for (expr in parsed.moduleExprs)
					interp.execute(expr);

				for (name => value in interp.variables)
					if(!builtIn.contains(name))
						module.imports.set(name, value);
			}
			catch(e:Dynamic)
			{
				onError('Error on "$origin": ' + describeError(e));
			}
		}
		return module.classes.length;
	}

	/**
	 * Finds what a script is importing: a class, an enum, or one of the custom imports. Null if there's no such thing on the engine.
	 */
	public static function resolveImport(path:String):Dynamic
	{
		if(importCache.exists(path)) return importCache.get(path);

		var result:Dynamic = null;
		if(customImports.exists(path))
		{
			result = customImports.get(path);
			if(Std.isOfType(result, String)) result = resolveType(result);
		}
		if(result == null) result = resolveType(path);

		// "package.File.Type", for types declared on the file of another one
		if(result == null)
		{
			var parts:Array<String> = path.split('.');
			if(parts.length > 2)
			{
				var type:String = parts.pop();
				parts.pop();
				parts.push(type);

				var shortPath:String = parts.join('.');
				if(customImports.exists(shortPath))
				{
					result = customImports.get(shortPath);
					if(Std.isOfType(result, String)) result = resolveType(result);
				}
				if(result == null) result = resolveType(shortPath);
			}
		}

		if(result != null) importCache.set(path, result);
		return result;
	}

	static function resolveType(path:String):Dynamic
	{
		var cls:Dynamic = Type.resolveClass(path);
		return (cls != null) ? cls : Type.resolveEnum(path);
	}

	// If a name shows up on a script's code besides the line that imports it ("import some.package.Name;" has a dot before the name)
	static function isNameUsed(code:String, name:String):Bool
	{
		var position:Int = code.indexOf(name);
		while(position > -1)
		{
			var before:Int = (position > 0) ? code.fastCodeAt(position - 1) : ' '.code;
			var after:Int = (position + name.length < code.length) ? code.fastCodeAt(position + name.length) : ' '.code;
			if(!isNameChar(before) && !isNameChar(after) && before != '.'.code) return true;

			position = code.indexOf(name, position + name.length);
		}
		return false;
	}

	static inline function isNameChar(char:Int):Bool
	{
		return (char >= 'a'.code && char <= 'z'.code) || (char >= 'A'.code && char <= 'Z'.code) || (char >= '0'.code && char <= '9'.code) || char == '_'.code;
	}

	// ------------------------------------------------------------------------------------------
	// Instances
	// ------------------------------------------------------------------------------------------

	/**
	 * Script classes that extend an engine's class, directly or through other script classes.
	 */
	public static function listSubclasses(base:Class<Dynamic>):Array<HxcClass>
	{
		var found:Array<HxcClass> = [for (cls in classes) if(cls.isSubclassOf(base)) cls];
		found.sort((a, b) -> (a.name < b.name) ? -1 : ((a.name > b.name) ? 1 : 0));
		return found;
	}

	/**
	 * Makes an object out of a script class, null if it couldn't be made.
	 *
	 * @param presetBase 	Object of the engine to attach the script to instead of making a new one when it calls `super()`.
	 */
	public static function instantiate(cls:HxcClass, ?args:Array<Dynamic>, ?presetBase:Dynamic, withMixin:Bool = false):HxcInstance
	{
		try
		{
			return new HxcInstance(cls, (args != null) ? args : [], presetBase, withMixin);
		}
		catch(e:Dynamic)
		{
			reportError(cls.name, 'new', e);
		}
		return null;
	}

	/**
	 * The script attached to an object, null if it has none.
	 */
	public static function getInstance(object:Dynamic):HxcInstance
	{
		if(object == null) return null;
		if(Std.isOfType(object, HxcInstance)) return object;
		if(Std.isOfType(object, IHxcScripted)) return cast(object, IHxcScripted).__hxc;
		return (attachedCount > 0 && Reflect.isObject(object) && !Std.isOfType(object, String)) ? attached.get(object) : null;
	}

	@:allow(hxc.HxcInstance)
	static function attach(object:Dynamic, instance:HxcInstance):Void
	{
		if(object == null) return;

		if(Std.isOfType(object, IHxcScripted)) cast(object, IHxcScripted).__hxc = instance;
		else
		{
			attached.set(object, instance);
			attachedCount++;
		}
	}

	/**
	 * Calls a function of an object, the one of its script if it has it. Errors are reported instead of thrown.
	 */
	public static function call(object:Dynamic, name:String, ?args:Array<Dynamic>):Dynamic
	{
		if(object == null) return null;
		if(args == null) args = [];

		var instance:HxcInstance = getInstance(object);
		if(instance != null) return instance.call(name, args);

		var func:Dynamic = Reflect.field(object, name);
		return Reflect.isFunction(func) ? Reflect.callMethod(object, func, args) : null;
	}

	// ------------------------------------------------------------------------------------------
	// Variables that only exist for scripts
	// ------------------------------------------------------------------------------------------

	/**
	 * If an object of the engine has a variable (or a function) with that name.
	 * V-Slice gives things like `zIndex` to every object, scripts set them on whatever they make.
	 */
	public static function hasNativeField(object:Dynamic, name:String):Bool
	{
		var cls:Class<Dynamic> = Type.getClass(object);
		if(cls == null) return true; //structures and classes themselves take anything

		var className:String = Type.getClassName(cls);
		var fields:Map<String, Bool> = classFields.get(className);
		if(fields == null)
		{
			fields = [];
			for (field in Type.getInstanceFields(cls))
				fields.set(field, true);
			classFields.set(className, fields);
		}
		return fields.exists(name) || fields.exists('set_$name') || fields.exists('get_$name');
	}

	/**
	 * Keeps a value for an object under a name it has no variable for.
	 */
	public static function setExtra(object:Dynamic, name:String, value:Dynamic):Void
	{
		var values:Map<String, Dynamic> = extraFields.get(object);
		if(values == null)
		{
			values = [];
			extraFields.set(object, values);
			extraCount++;
		}
		values.set(name, value);
	}

	public static function getExtra(object:Dynamic, name:String):Dynamic
	{
		if(extraCount < 1 || object == null || !Reflect.isObject(object) || Std.isOfType(object, String)) return null;

		var values:Map<String, Dynamic> = extraFields.get(object);
		return (values != null) ? values.get(name) : null;
	}

	/**
	 * A variable of an object as scripts see it: its own, or what a script kept for it with that name.
	 */
	public static function getValue(object:Dynamic, name:String):Dynamic
	{
		if(object == null) return null;

		var instance:HxcInstance = getInstance(object);
		if(instance != null) return instance.getField(name);

		var value:Dynamic = null;
		try
		{
			value = Reflect.getProperty(object, name);
		}
		catch(e:Dynamic) {}
		return (value != null) ? value : getExtra(object, name);
	}

	/**
	 * Reads something of an object the way scripts do. See `memberGetters`.
	 */
	public static function readMember(object:Dynamic, name:String):Dynamic
	{
		var byClass:Map<String, Dynamic> = memberGetters.get(name);
		if(byClass != null && object != null && !Std.isOfType(object, String))
		{
			var cls:Class<Dynamic> = Type.getClass(object);
			while(cls != null)
			{
				var getter:Dynamic = byClass.get(Type.getClassName(cls));
				if(getter != null)
				{
					var value:Dynamic = getter(object);
					if(value != null) return value;
					break;
				}
				cls = Type.getSuperClass(cls);
			}
		}
		return Reflect.getProperty(object, name);
	}

	/**
	 * The version scripts get of a function of an object, null if it's the object's own. See `memberReplacements`.
	 */
	public static function getReplacement(object:Dynamic, name:String):Dynamic
	{
		if(object != null && Std.isOfType(object, Class))
		{
			var statics:Map<String, Dynamic> = staticReplacements.get(name);
			return (statics != null) ? statics.get(Type.getClassName(object)) : null;
		}

		var byClass:Map<String, Dynamic> = memberReplacements.get(name);
		if(byClass == null || object == null || Std.isOfType(object, String)) return null;

		var cls:Class<Dynamic> = Type.getClass(object);
		while(cls != null)
		{
			var func:Dynamic = byClass.get(Type.getClassName(cls));
			if(func != null) return func;
			cls = Type.getSuperClass(cls);
		}
		return null;
	}

	/**
	 * Something a script asked an object or a class of a library for that it doesn't have, see `staticExtras` and `memberExtras`.
	 */
	public static function getLibraryExtra(object:Dynamic, name:String):Dynamic
	{
		if(object == null || Std.isOfType(object, String)) return null;

		if(Std.isOfType(object, Class))
		{
			var functions:Map<String, Dynamic> = staticExtras.get(Type.getClassName(object));
			return (functions != null) ? functions.get(name) : null;
		}

		var found:Dynamic = resolveMissing(object, name);
		if(found != null) return found;

		var cls:Class<Dynamic> = Type.getClass(object);
		while(cls != null)
		{
			var functions:Map<String, Dynamic> = memberExtras.get(Type.getClassName(cls));
			if(functions != null && functions.exists(name))
			{
				var func:Dynamic = functions.get(name);
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Reflect.callMethod(null, func, [object].concat(args)));
			}
			cls = Type.getSuperClass(cls);
		}
		return null;
	}

	// ------------------------------------------------------------------------------------------
	// Errors
	// ------------------------------------------------------------------------------------------

	public static function describeError(error:Dynamic):String
	{
		#if hscriptPos
		if(Std.isOfType(error, Error)) return Printer.errorToString(error, true);
		#end
		return Std.string(error);
	}

	/**
	 * Reports an error of a script, each different one only once: something broken on an update would be reported every frame.
	 */
	public static function reportError(className:String, funcName:String, error:Dynamic):Void
	{
		var message:String = '$className.$funcName(): ' + describeError(error);
		if(reportedErrors.exists(message)) return;

		reportedErrors.set(message, true);
		onError(message);
	}
}

/**
 * A script file: what it imports and the classes it has.
 */
class HxcModule
{
	public var path:String;
	public var imports:Map<String, Dynamic> = [];
	public var missingImports:Array<String> = [];
	public var unusedImports:Array<String> = []; //missing as well, but the script never uses them
	public var usings:Array<String> = [];
	public var classes:Array<HxcClass> = [];

	public function new(path:String)
	{
		this.path = path;
	}
}

/**
 * A class of a script file.
 */
class HxcClass
{
	public var name:String;
	public var module:HxcModule;
	public var decl:ClassDecl;

	/**
	 * Name of the class it extends, null if it doesn't extend anything.
	 */
	public var superName:String = null;

	var superPath:String = null;
	var statics:Map<String, Dynamic> = null;
	var staticInterp:HxcInterp = null;

	public function new(decl:ClassDecl, module:HxcModule)
	{
		this.decl = decl;
		this.module = module;
		this.name = decl.name;

		switch(decl.extend)
		{
			case CTPath(path):
				superName = (path.sub != null) ? path.sub : path.name;
				superPath = path.pack.concat([path.name]).join('.');
				if(path.sub != null) superPath += '.' + path.sub;
			default:
		}
	}

	/**
	 * The script class this one extends, null if it extends one of the engine's.
	 */
	public function getParent():HxcClass
	{
		if(superName == null) return null;

		var parent:HxcClass = HxcRuntime.classes.get(superName);
		return (parent != this) ? parent : null;
	}

	/**
	 * This class and the script classes it extends, starting from this one.
	 */
	public function getChain():Array<HxcClass>
	{
		var chain:Array<HxcClass> = [];
		var cls:HxcClass = this;
		while(cls != null && !chain.contains(cls))
		{
			chain.push(cls);
			cls = cls.getParent();
		}
		return chain;
	}

	/**
	 * The engine's class at the end of what this one extends, null if there's none or it doesn't exist here.
	 */
	public function getNativeSuper():Class<Dynamic>
	{
		var chain:Array<HxcClass> = getChain();
		var root:HxcClass = chain[chain.length - 1];
		if(root.superName == null) return null;

		var found:Dynamic = root.module.imports.get(root.superName);
		if(found == null && root.superPath != root.superName) found = HxcRuntime.resolveImport(root.superPath);
		if(found == null && HxcRuntime.defaultBases.exists(root.superName)) found = HxcRuntime.resolveImport(HxcRuntime.defaultBases.get(root.superName));
		if(!Std.isOfType(found, Class)) return null;

		var through:Class<Dynamic> = HxcRuntime.extendedThrough.get(Type.getClassName(found));
		return (through != null) ? through : found;
	}

	public function isSubclassOf(base:Class<Dynamic>):Bool
	{
		var cls:Class<Dynamic> = getNativeSuper();
		while(cls != null)
		{
			if(cls == base) return true;
			cls = Type.getSuperClass(cls);
		}
		return false;
	}

	// Static variables and functions are made the first time one is needed
	function initStatics():Void
	{
		if(statics != null) return;

		statics = [];
		staticInterp = new HxcInterp(this, null);
		for (field in decl.fields)
		{
			if(!field.access.contains(AStatic)) continue;

			try
			{
				switch(field.kind)
				{
					case KFunction(func): statics.set(field.name, staticInterp.makeFunction(func, 0, field.name));
					case KVar(decl): statics.set(field.name, (decl.expr != null) ? staticInterp.evaluate(decl.expr) : null);
				}
			}
			catch(e:Dynamic)
			{
				statics.set(field.name, null);
				HxcRuntime.reportError(name, field.name, e);
			}
		}
	}

	public function hasStatic(field:String):Bool
	{
		initStatics();
		return statics.exists(field);
	}

	public function getStatic(field:String):Dynamic
	{
		initStatics();
		return statics.get(field);
	}

	public function setStatic(field:String, value:Dynamic):Void
	{
		initStatics();
		statics.set(field, value);
	}

	/**
	 * The static variables of the class that are plain values (true or false, numbers, texts), for them to be given back to the class
	 * when it's loaded again (see `restoreStatics()`).
	 */
	public function plainStatics():Map<String, Dynamic>
	{
		var found:Map<String, Dynamic> = [];
		if(statics == null) return found;

		for (field in decl.fields)
		{
			if(!field.access.contains(AStatic) || !field.kind.match(KVar(_))) continue;
			var value:Dynamic = statics.get(field.name);
			if(Std.isOfType(value, Bool) || Std.isOfType(value, Float) || Std.isOfType(value, String)) found.set(field.name, value);
		}
		return found;
	}

	public function restoreStatics(values:Map<String, Dynamic>):Void
	{
		initStatics();
		for (name => value in values)
			if(statics.exists(name))
				statics.set(name, value);
	}

	public function toString():String
	{
		return 'HxcClass($name)';
	}
}
#end
