package hxc;

#if HSCRIPT_ALLOWED
import crowplexus.hscript.Expr;
import crowplexus.hscript.Interp;
import crowplexus.hscript.Tools;
import hxc.HxcInstance.HxcSuper;
import hxc.HxcRuntime;

/**
 * Runs the code of a script class, each object made out of one has its own.
 *
 * What changes from regular HScript is where the names come from: the object's variables and functions,
 * then what the class it extends has, then the class' static ones (see `HxcScope`). `this` and `super` exist as well.
 */
class HxcInterp extends Interp
{
	public var cls(default, null):HxcClass;
	public var instance(default, null):HxcInstance;

	/**
	 * Class of the object's chain that has the function being run, `super` is relative to it.
	 */
	public var level:Int = 0;

	/**
	 * Where the names that aren't local variables come from.
	 */
	public var scope(default, null):HxcScope;

	public function new(cls:HxcClass, instance:HxcInstance)
	{
		super();
		this.cls = cls;
		this.instance = instance;

		scope = new HxcScope(this);
		imports = cls.module.imports;

		// `for (i in a...b)` takes what V-Slice's takes: a value that isn't there counts as 0 and decimals are cut, where the library
		// stops the script ("null should be Int")
		var me:HxcInterp = this;
		binops.set('...', function(e1, e2) return new HxcRange(rangeBound(me.expr(e1)), rangeBound(me.expr(e2))));

		// only set by execute(), which is never used here
		depth = 0;
		inTry = false;

		// (the ones of the files of the classes it extends as well: their code runs here too)
		for (curClass in cls.getChain())
		{
			for (name in curClass.module.usings)
			{
				try
				{
					useUsing(name);
				}
				catch(e:Dynamic) {}
			}
		}
	}

	static function rangeBound(value:Dynamic):Int
	{
		if(value == null) return 0;
		if(Std.isOfType(value, Int)) return value;
		if(Std.isOfType(value, Float)) return Std.int(value);
		var parsed:Null<Int> = Std.parseInt(Std.string(value));
		return (parsed != null) ? parsed : 0;
	}

	// What's imported by the file of the class whose code is being run. A script class can extend one of another file,
	// the functions it gets from that one use what their own file imports and declares
	function getImports():Map<String, Dynamic>
	{
		return (instance != null && level > 0) ? instance.getClassAt(level).module.imports : imports;
	}

	/**
	 * Runs an expression of the class outside of any function, like a variable's starting value.
	 */
	public function evaluate(e:Expr):Dynamic
	{
		var oldLocals = locals;
		var oldDepth:Int = depth;
		var oldDeclared = declared;

		locals = new Map();
		declared = [];
		depth = 1; //functions declared in there aren't global ones

		var value:Dynamic = null;
		try
		{
			value = expr(e);
		}
		catch(error:Dynamic)
		{
			locals = oldLocals;
			depth = oldDepth;
			declared = oldDeclared;
			throw error;
		}

		locals = oldLocals;
		depth = oldDepth;
		declared = oldDeclared;
		return value;
	}

	/**
	 * Makes a callable function out of one of the class.
	 *
	 * @param level 	Position on the object's chain of the class that has it.
	 */
	public function makeFunction(func:FunctionDecl, level:Int, name:String):Dynamic
	{
		var body:Expr = (func.expr != null) ? func.expr : makeExpr(EBlock([]), null);
		var oldLocals = locals;
		locals = new Map(); //class functions don't capture anything
		var raw:Dynamic = super.expr(makeExpr(EFunction(func.args, withDefaults(func.args, body), null, func.ret), body));
		locals = oldLocals;

		var me = this;

		// (a constructor that fails means there's no object: whoever asked for one has to know)
		if(name == 'new') return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return me.run(raw, args, level, func.args));

		// On Polymod (V-Slice) an error stays inside of the function it happened on: it's reported, the function gives nothing back
		// and whoever called it goes on. That goes for the engine too, which calls these when they're given to a signal or a timer
		return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			var fromScript:Bool = (running > 0);
			try
			{
				return me.run(raw, args, level, func.args);
			}
			catch(error:Dynamic)
			{
				// (what the function threw by itself, or got from the game, is for the script that called it to catch)
				if(fromScript && !Std.isOfType(error, Error)) throw error;
				HxcRuntime.reportError(me.cls.name, name, error);
			}
			return null;
		});
	}

	// How many functions of scripts are being run, of any object
	static var running:Int = 0;

	// The parameters of the class functions that are being run and what each was given, the innermost last: see resolve()
	var callNames:Array<Array<Argument>> = [];
	var callValues:Array<Array<Dynamic>> = [];

	/**
	 * Runs a function of the script as one of a class of the object's chain. If an error comes out of it, the interpreter is left the way it was:
	 * the library only does that for what's called inside of a `try`. Without it everything from then on would look like it was
	 * being called by the script itself (see `protect()`), and the next error of a timer or a tween would close the game.
	 */
	function run(func:Dynamic, args:Array<Dynamic>, atLevel:Int, ?names:Array<Argument>):Dynamic
	{
		var oldLevel:Int = level;
		var oldDepth:Int = depth;
		var oldLocals = locals;
		var oldDeclared:Int = declared.length;
		var oldTry:Bool = inTry;
		var oldCalls:Int = callNames.length;
		level = atLevel;
		running++;
		if(names != null)
		{
			callNames.push(names);
			callValues.push(args);
		}

		var result:Dynamic = null;
		try
		{
			result = Reflect.callMethod(null, func, args);
		}
		catch(error:Dynamic)
		{
			level = oldLevel;
			depth = oldDepth;
			locals = oldLocals;
			inTry = oldTry;
			if(declared.length > oldDeclared) declared.resize(oldDeclared);
			if(callNames.length > oldCalls)
			{
				callNames.resize(oldCalls);
				callValues.resize(oldCalls);
			}
			running--;
			throw error;
		}
		level = oldLevel;
		running--;
		if(callNames.length > oldCalls)
		{
			callNames.resize(oldCalls);
			callValues.resize(oldCalls);
		}
		return result;
	}

	// Bodies of the functions that have parameters with a default value, by their list of parameters: see withDefaults()
	static var defaultsDone:haxe.ds.ObjectMap<{}, Expr> = new haxe.ds.ObjectMap();

	/**
	 * A parameter with a default value ("force:Bool = false") can be left out when calling the function. The library only knows that
	 * about the ones written as "?force", asking for all of the others, and never gives any of them its value.
	 * This marks those parameters as optional and returns what the function does with their values being set first.
	 */
	static function withDefaults(args:Array<Argument>, body:Expr):Expr
	{
		var hasDefaults:Bool = false;
		for (arg in args)
		{
			if(arg.value != null)
			{
				hasDefaults = true;
				break;
			}
		}
		if(!hasDefaults) return body;

		var done:Expr = defaultsDone.get(args);
		if(done != null) return done;

		var steps:Array<Expr> = [];
		for (arg in args)
		{
			if(arg.value == null) continue;

			// if(force == null) force = false;
			arg.opt = true;
			var isMissing:Expr = makeExpr(EBinop('==', makeExpr(EIdent(arg.name), body), makeExpr(EIdent('null'), body)), body);
			var setIt:Expr = makeExpr(EBinop('=', makeExpr(EIdent(arg.name), body), arg.value), body);
			steps.push(makeExpr(EIf(isMissing, setIt, null), body));
		}
		steps.push(body);

		done = makeExpr(EBlock(steps), body);
		defaultsDone.set(args, done);
		return done;
	}

	static function makeExpr(def:ExprDef, like:Expr):Expr
	{
		#if hscriptPos
		return {
			e: def,
			pmin: (like != null) ? like.pmin : 0,
			pmax: (like != null) ? like.pmax : 0,
			origin: (like != null) ? like.origin : 'hxc',
			line: (like != null) ? like.line : 0
		};
		#else
		return def;
		#end
	}

	override public function expr(e:Expr):Dynamic
	{
		switch(Tools.expr(e))
		{
			case ECall(target, params):
				// super(...) on a constructor
				switch(Tools.expr(target))
				{
					case EIdent('super'):
						if(instance == null) return null;

						#if hscriptPos
						curExpr = e;
						#end
						var args:Array<Dynamic> = [for (param in params) expr(param)];
						instance.callSuperConstructor(level, args);
						return null;

					// "thing?.doIt()": with nothing on the thing the library goes on and tries to call it anyway
					case EField(object, field, true):
						#if hscriptPos
						curExpr = e;
						#end
						var target:Dynamic = expr(object);
						if(target == null) return null;

						var args:Array<Dynamic> = [for (param in params) expr(param)];
						return fcall(target, field, args);
					default:
				}

			case EFunction(args, body, name, ret):
				var full:Expr = withDefaults(args, body);
				return protect(super.expr((full == body) ? e : makeExpr(EFunction(args, full, name, ret), e)));

			default:
		}
		return super.expr(e);
	}

	override function resolve(id:String):Dynamic
	{
		var local = locals.get(id);
		if(local != null) return local.r;

		if(scope.exists(id)) return scope.get(id);

		var current:Map<String, Dynamic> = getImports();
		if(current.exists(id)) return current.get(id);
		if(imports.exists(id)) return imports.get(id);
		if(HxcRuntime.fallbacks.exists(id)) return HxcRuntime.fallbacks.get(id);

		// On Polymod (V-Slice) the parameters of a function stay within reach of the functions it calls, and scripts ended up counting on it:
		// what a function was never given can be what the one that called it was (the base game's Nene reads `event` like that)
		var index:Int = callNames.length - 2; //the last one is the function being run, its own are local variables
		while(index >= 0)
		{
			var names:Array<Argument> = callNames[index];
			for (position in 0...names.length)
				if(names[position].name == id)
					return callValues[index][position];
			index--;
		}

		error(EUnknownVariable(id));
		return null;
	}

	// The three ways of changing a variable, when it isn't a local one it goes to the scope instead of to HScript's globals

	override function assign(e1:Expr, e2:Expr):Dynamic
	{
		switch(Tools.expr(e1))
		{
			case EIdent(id) if(!locals.exists(id)):
				var value:Dynamic = expr(e2);
				scope.set(id, value);
				return value;
			default:
		}
		return super.assign(e1, e2);
	}

	override function evalAssignOp(op:String, fop:Dynamic->Dynamic->Dynamic, e1:Expr, e2:Expr):Dynamic
	{
		switch(Tools.expr(e1))
		{
			case EIdent(id) if(!locals.exists(id)):
				var value:Dynamic = fop(expr(e1), expr(e2));
				scope.set(id, value);
				return value;
			default:
		}
		return super.evalAssignOp(op, fop, e1, e2);
	}

	override function increment(e:Expr, prefix:Bool, delta:Int):Dynamic
	{
		switch(Tools.expr(e))
		{
			case EIdent(id):
				#if hscriptPos
				curExpr = e;
				#end

				// the library's own version of this never changes local variables
				var local = locals.get(id);
				var value:Dynamic = (local != null) ? local.r : resolve(id);
				var newValue:Dynamic = value + delta;

				if(local == null) scope.set(id, newValue);
				else if(local.const != true) local.r = newValue;
				else error(ECustom('Cannot reassign final, for constant expression -> ' + id));

				return prefix ? newValue : value;
			default:
		}
		return super.increment(e, prefix, delta);
	}

	// Functions made by a script get called by the engine later (tweens, timers, signals...), an error in there would crash the game.
	// They also keep which class of the object's chain they were written on, to find the same names when they run
	function protect(func:Dynamic):Dynamic
	{
		var me = this;
		var madeAt:Int = level;
		return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			if(me.depth > 0) return me.run(func, args, madeAt); //called from the script itself, which can catch what it throws

			try
			{
				return me.run(func, args, madeAt);
			}
			catch(error:Dynamic)
			{
				HxcRuntime.reportError(me.cls.name, '(function)', error);
			}
			return null;
		});
	}

	override function get(o:Dynamic, f:String):Dynamic
	{
		if(o == null) error(EInvalidAccess(f));

		if(Std.isOfType(o, HxcSuper)) return cast(o, HxcSuper).getField(f, level);
		if(Std.isOfType(o, HxcClass)) return cast(o, HxcClass).getStatic(f);

		var scripted:HxcInstance = HxcRuntime.getInstance(o);
		if(scripted != null) return scripted.getField(f);

		var value:Dynamic = HxcRuntime.readMember(o, f);
		if(value == null) value = HxcRuntime.getExtra(o, f);
		if(value == null)
		{
			var real:Dynamic = HxcRuntime.getStoodFor(o, f);
			if(real != null) return HxcRuntime.readMember(real, f);
		}
		return (value != null) ? value : HxcRuntime.getLibraryExtra(o, f);
	}

	// The library tries what a "using" adds before what the object has: on Haxe it's the other way around,
	// and a "using" made out of a whole class would take over any function with the name of one of the class'
	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		var replacement:Dynamic = HxcRuntime.getReplacement(o, f);
		if(replacement != null) return Reflect.callMethod(null, replacement, [o].concat(args));

		var func:Dynamic = get(o, f);

		// The getter or the setter of a property called by its name (`PlayState.instance.get_currentChart()`): on Haxe they're
		// functions of their own, here the engine's version of the class can have it as a plain variable
		if(func == null && f.length > 4 && !Std.isOfType(o, HxcSuper))
		{
			if(f.startsWith('get_') && args.length == 0) return get(o, f.substr(4));
			if(f.startsWith('set_') && args.length == 1) return set(o, f.substr(4), args[0]);
		}

		// A plain object (`var functions = {}`) gone through like a map: scripts use them as maps of names to things
		if(func == null && args.length == 0 && Type.typeof(o) == TObject && !Std.isOfType(o, Class))
		{
			switch(f)
			{
				case 'iterator': return [for (name in Reflect.fields(o)) Reflect.field(o, name)].iterator();
				case 'keys': return Reflect.fields(o).iterator();
				case 'keyValueIterator': return [for (name in Reflect.fields(o)) {key: name, value: Reflect.field(o, name)}].iterator();
			}
		}

		if(func == null && usings.length > 0 && !Std.isOfType(o, HxcSuper))
		{
			for (entry in usings)
			{
				var value:Dynamic = entry.call(o, f, args);
				if(value != null) return value;
			}
		}
		return call(o, func, args);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		if(o == null) error(EInvalidAccess(f));

		if(Std.isOfType(o, HxcSuper))
		{
			var base:Dynamic = cast(o, HxcSuper).instance.base;
			if(base != null) Reflect.setProperty(base, f, v);
			return v;
		}
		if(Std.isOfType(o, HxcClass))
		{
			cast(o, HxcClass).setStatic(f, v);
			return v;
		}
		if(Std.isOfType(o, Class))
		{
			var setters:Map<String, Dynamic->Void> = HxcRuntime.staticSetters.get(Type.getClassName(o));
			if(setters != null && setters.exists(f))
			{
				setters.get(f)(v);
				return v;
			}
		}

		var scripted:HxcInstance = HxcRuntime.getInstance(o);
		if(scripted != null) return scripted.setField(f, v);

		// things V-Slice has on every object and the engine's classes don't ("zIndex" and such) are kept on the side
		if(!HxcRuntime.hasNativeField(o, f))
		{
			var real:Dynamic = HxcRuntime.getStoodFor(o, f);
			if(real != null)
			{
				Reflect.setProperty(real, f, v);
				return v;
			}

			HxcRuntime.setExtra(o, f, v);
			try
			{
				Reflect.setProperty(o, f, v);
			}
			catch(e:Dynamic) {}
			return v;
		}

		Reflect.setProperty(o, f, v);
		return v;
	}

	override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic
	{
		if(f == null)
		{
			// what's being extended doesn't have it: fine, there's nothing more to do there
			if(Std.isOfType(o, HxcSuper)) return null;
			error(ECustom('Tried to call a function that does not exist'));
		}

		// functions of a script don't need an object, and "super" isn't one the function could be called on
		if(Std.isOfType(o, HxcSuper) || Std.isOfType(o, HxcClass) || Std.isOfType(o, HxcInstance)) o = null;
		return Reflect.callMethod(o, f, plainArgs(args));
	}

	// `super` given to a function as a value ("FlxFlicker.flicker(super, ...)") is the object the class extends, like on Polymod
	static function plainArgs(args:Array<Dynamic>):Array<Dynamic>
	{
		for (index in 0...args.length)
			if(Std.isOfType(args[index], HxcSuper))
				args[index] = cast(args[index], HxcSuper).instance.base;
		return args;
	}

	override function cnew(cl:String, args:Array<Dynamic>):Dynamic
	{
		var current:Map<String, Dynamic> = getImports();
		var type:Dynamic = scope.exists(cl) ? scope.get(cl) : (current.exists(cl) ? current.get(cl) : (imports.exists(cl) ? imports.get(cl) : null));
		if(type == null) type = HxcRuntime.fallbacks.get(cl);
		if(type == null) type = HxcRuntime.resolveImport(cl);
		if(type == null) error(ECustom('The class "$cl" does not exist on this engine'));

		if(Std.isOfType(type, HxcClass))
		{
			var created:HxcInstance = new HxcInstance(cast type, args);
			return created.self;
		}

		var maker:Array<Dynamic>->Dynamic = Std.isOfType(type, Class) ? HxcRuntime.constructors.get(Type.getClassName(type)) : null;
		if(maker != null)
		{
			var made:Dynamic = maker(plainArgs(args));
			if(made != null) return made;
		}
		return Type.createInstance(type, plainArgs(args));
	}
}

/**
 * The names a script can use besides its local variables, this takes the place of HScript's global variables.
 */
class HxcScope
{
	var interp:HxcInterp;
	var extras:Map<String, Dynamic> = []; //things assigned without being declared anywhere

	public function new(interp:HxcInterp)
	{
		this.interp = interp;
	}

	function findStatic(name:String):HxcClass
	{
		var cls:HxcClass = interp.cls;
		while(cls != null)
		{
			if(cls.hasStatic(name)) return cls;
			cls = cls.getParent();
		}
		return null;
	}

	public function exists(name:String):Bool
	{
		var instance:HxcInstance = interp.instance;
		if(instance != null && (name == 'this' || name == 'super' || instance.hasMember(name))) return true;
		return extras.exists(name) || findStatic(name) != null || HxcRuntime.classes.exists(name) || HxcRuntime.globals.exists(name);
	}

	public function get(name:String):Dynamic
	{
		var instance:HxcInstance = interp.instance;
		if(instance != null)
		{
			if(name == 'this') return instance.self;
			if(name == 'super') return instance.superProxy;
			if(instance.hasMember(name)) return instance.getField(name);
		}
		if(extras.exists(name)) return extras.get(name);

		var owner:HxcClass = findStatic(name);
		if(owner != null) return owner.getStatic(name);

		if(HxcRuntime.classes.exists(name)) return HxcRuntime.classes.get(name);
		return HxcRuntime.globals.get(name);
	}

	public function set(name:String, value:Dynamic):Void
	{
		var instance:HxcInstance = interp.instance;
		if(instance != null && instance.hasMember(name))
		{
			instance.setField(name, value);
			return;
		}

		var owner:HxcClass = findStatic(name);
		if(owner != null) owner.setStatic(name, value);
		else extras.set(name, value);
	}
}

/**
 * The numbers of `a...b` for scripts. Haxe's own `IntIterator` can't be used: its functions are inlined, so there's nothing to call at runtime.
 */
@:keep
class HxcRange
{
	var current:Int;
	var end:Int;

	public function new(start:Int, end:Int)
	{
		current = start;
		this.end = end;
	}

	public function hasNext():Bool return current < end;
	public function next():Int return current++;
}
#end
