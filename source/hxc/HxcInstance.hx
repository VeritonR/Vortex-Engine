package hxc;

#if HSCRIPT_ALLOWED
import crowplexus.hscript.Expr;
import hxc.HxcRuntime;

/**
 * An object made out of a script class.
 */
class HxcInstance
{
	public var cls(default, null):HxcClass;

	/**
	 * The object of the engine's class the script extends, null until the script calls `super()`
	 * and for classes that don't extend anything from the engine.
	 */
	public var base(default, null):Dynamic = null;

	/**
	 * What `this` is for the script: the base when there's one, so the engine can be given it.
	 */
	public var self(get, never):Dynamic;
	inline function get_self():Dynamic
		return (base != null) ? base : this;

	/**
	 * For scripts attached to an object that isn't of the class they extend: an object of that class, which has the rest of what the script expects.
	 * See `IHxcMixin`.
	 */
	public var mixin(default, null):Dynamic = null;

	public var interp(default, null):HxcInterp;
	public var superProxy(default, null):HxcSuper;

	var chain:Array<HxcClass>; //the class and the script classes it extends, starting from the class itself
	var fields:Map<String, Dynamic> = [];
	var properties:Map<String, VarDecl> = []; //variables with a getter or a setter
	var methods:Array<Map<String, Dynamic>> = []; //for each class of the chain
	var presetBase:Dynamic;
	var withMixin:Bool;
	var baseFields:Map<String, Bool> = null;
	var mixinFields:Map<String, Bool> = null;
	var inAccessor:Map<String, Bool> = [];

	@:allow(hxc.HxcRuntime)
	@:allow(hxc.HxcInterp)
	function new(cls:HxcClass, args:Array<Dynamic>, ?presetBase:Dynamic, withMixin:Bool = false)
	{
		this.cls = cls;
		this.presetBase = presetBase;
		this.withMixin = withMixin;
		chain = cls.getChain();
		interp = new HxcInterp(cls, this);
		superProxy = new HxcSuper(this);

		for (level => curClass in chain)
		{
			var levelMethods:Map<String, Dynamic> = [];
			methods.push(levelMethods);

			for (field in curClass.decl.fields)
			{
				if(field.access.contains(AStatic)) continue;

				switch(field.kind)
				{
					case KFunction(func):
						levelMethods.set(field.name, interp.makeFunction(func, level, field.name));
					case KVar(decl):
						if(decl.get == 'get' || decl.set == 'set') properties.set(field.name, decl);
				}
			}
		}

		// Variables get their starting values before the constructor runs, the ones of the classes it extends first
		var level:Int = chain.length - 1;
		while(level >= 0)
		{
			for (field in chain[level].decl.fields)
			{
				if(field.access.contains(AStatic)) continue;

				switch(field.kind)
				{
					case KVar(decl):
						interp.level = level;
						fields.set(field.name, (decl.expr != null) ? interp.evaluate(decl.expr) : null);
					default:
				}
			}
			level--;
		}
		interp.level = 0;

		if(!callConstructor(0, args)) constructBase(args);
		if(base == null) constructBase(args); //its constructor never called super()
	}

	// Runs the first constructor found from a class of the chain on, returns false if there's none
	function callConstructor(fromLevel:Int, args:Array<Dynamic>):Bool
	{
		for (level in fromLevel...chain.length)
		{
			var constructor:Dynamic = methods[level].get('new');
			if(constructor == null) continue;

			Reflect.callMethod(null, constructor, args);
			return true;
		}
		return false;
	}

	// Functions of the object the script is running through `super`, see inSuperCall()
	var superCalls:Array<String> = [];

	/**
	 * If the object's own version of a function is being run because the script asked for it (`super.thing()`).
	 * Objects that send their functions to the script check this, to not send it there again.
	 */
	public inline function inSuperCall(name:String):Bool
	{
		return superCalls.length > 0 && superCalls.contains(name);
	}

	@:noCompletion
	public function callSuper(target:Dynamic, func:Dynamic, name:String, args:Array<Dynamic>):Dynamic
	{
		superCalls.push(name);

		var result:Dynamic = null;
		try
		{
			result = Reflect.callMethod(target, func, args);
		}
		catch(error:haxe.Exception)
		{
			superCalls.pop();
			throw error;
		}
		superCalls.pop();
		return result;
	}

	/**
	 * The class at a position of the chain: 0 is the object's own, the rest are the script classes it extends.
	 */
	public function getClassAt(level:Int):HxcClass
	{
		return (level >= 0 && level < chain.length) ? chain[level] : cls;
	}

	/**
	 * `super(...)` called by the constructor of one of the chain's classes.
	 */
	public function callSuperConstructor(level:Int, args:Array<Dynamic>):Void
	{
		if(!callConstructor(level + 1, args)) constructBase(args);
	}

	function constructBase(args:Array<Dynamic>):Void
	{
		if(base != null) return;

		if(presetBase != null)
		{
			base = presetBase;
			if(withMixin) makeMixin(args);
		}
		else
		{
			var native:Class<Dynamic> = cls.getNativeSuper();
			if(native == null)
			{
				var root:HxcClass = chain[chain.length - 1];
				if(root.superName != null) throw 'The class "${root.superName}" that "${root.name}" extends does not exist on this engine';
				return;
			}
			var scripted:Class<Dynamic> = HxcRuntime.scriptedBases.get(Type.getClassName(native));
			base = Type.createInstance((scripted != null) ? scripted : native, args);
		}

		if(base != null) HxcRuntime.attach(base, this);
	}

	function makeMixin(args:Array<Dynamic>):Void
	{
		var native:Class<Dynamic> = cls.getNativeSuper();
		if(native == null || Std.isOfType(presetBase, native)) return;

		var created:Dynamic = Type.createInstance(native, args);
		if(!Std.isOfType(created, IHxcMixin)) return;

		mixin = created;
		cast(created, IHxcMixin).attachTo(presetBase);
		if(Std.isOfType(created, IHxcScripted)) cast(created, IHxcScripted).__hxc = this; //what it calls on itself goes through the script
	}

	function hasMixinField(name:String):Bool
	{
		if(mixin == null) return false;

		if(mixinFields == null)
		{
			mixinFields = [];
			for (field in Type.getInstanceFields(Type.getClass(mixin)))
				mixinFields.set(field, true);
		}
		return mixinFields.exists(name) || mixinFields.exists('get_$name');
	}

	// ------------------------------------------------------------------------------------------
	// Members
	// ------------------------------------------------------------------------------------------

	/**
	 * The script's own function with that name, looking from a class of the chain on. Null if none of them has it.
	 */
	public function findMethod(name:String, fromLevel:Int = 0):Dynamic
	{
		for (level in fromLevel...methods.length)
		{
			var method:Dynamic = methods[level].get(name);
			if(method != null) return method;
		}
		return null;
	}

	public inline function hasMethod(name:String):Bool
	{
		return findMethod(name) != null;
	}

	public function hasBaseField(name:String):Bool
	{
		if(base == null) return false;

		if(baseFields == null)
		{
			baseFields = [];
			var baseClass:Class<Dynamic> = Type.getClass(base);
			if(baseClass != null)
				for (field in Type.getInstanceFields(baseClass))
					baseFields.set(field, true);
		}

		// properties without a variable of their own only have their getter
		return baseFields.exists(name) || baseFields.exists('get_$name') || (baseFields.keys().hasNext() == false && Reflect.hasField(base, name));
	}

	/**
	 * If the script or its base have something with that name.
	 */
	/**
	 * The variables of the object that have a plain value on them (a number, a text, true or false), by their names.
	 */
	public function plainFields():Map<String, Dynamic>
	{
		var found:Map<String, Dynamic> = [];
		for (name => value in fields)
		{
			if(properties.exists(name)) continue;
			if(Std.isOfType(value, Bool) || Std.isOfType(value, Float) || Std.isOfType(value, String)) found.set(name, value);
		}
		return found;
	}

	/**
	 * Gives the object's variables the values they're given here, the ones it has.
	 */
	public function restoreFields(values:Map<String, Dynamic>):Void
	{
		for (name => value in values)
			if(fields.exists(name) && !properties.exists(name))
				fields.set(name, value);
	}

	public function hasMember(name:String):Bool
	{
		return fields.exists(name) || findMethod(name) != null || hasBaseField(name) || hasMixinField(name);
	}

	public function getField(name:String):Dynamic
	{
		var property:VarDecl = properties.get(name);
		if(property != null && property.get == 'get' && !inAccessor.exists(name))
		{
			var getter:Dynamic = findMethod('get_$name');
			if(getter != null)
			{
				inAccessor.set(name, true);
				var value:Dynamic = null;
				try
				{
					value = Reflect.callMethod(null, getter, []);
				}
				catch(e:Dynamic)
				{
					inAccessor.remove(name);
					throw e;
				}
				inAccessor.remove(name);
				return value;
			}
		}

		if(fields.exists(name)) return fields.get(name);

		var method:Dynamic = findMethod(name);
		if(method != null) return method;

		// What Polymod gives to every scripted object, for scripts to reach each other's things
		switch(name)
		{
			case 'scriptGet': return function(field:String):Dynamic return getField(field);
			case 'scriptSet': return function(field:String, value:Dynamic):Dynamic return setField(field, value);
			case 'scriptCall': return function(func:String, ?args:Array<Dynamic>):Dynamic return call(func, args);
			case 'scriptHas': return function(field:String):Bool return hasMember(field) || findMethod(field) != null;

			// (the object of the class being extended: on Polymod the script's own `this` isn't one the game can take)
			case 'superClass': return base;
		}

		if(base == null) return null;

		var value:Dynamic = HxcRuntime.readMember(base, name);
		if(value == null) value = HxcRuntime.getExtra(base, name);
		if(value == null && mixin != null && !hasBaseField(name) && hasMixinField(name)) value = Reflect.getProperty(mixin, name);
		return (value != null) ? value : HxcRuntime.getLibraryExtra(base, name);
	}

	public function setField(name:String, value:Dynamic):Dynamic
	{
		var property:VarDecl = properties.get(name);
		if(property != null && property.set == 'set' && !inAccessor.exists(name))
		{
			var setter:Dynamic = findMethod('set_$name');
			if(setter != null)
			{
				inAccessor.set(name, true);
				var result:Dynamic = null;
				try
				{
					result = Reflect.callMethod(null, setter, [value]);
				}
				catch(e:Dynamic)
				{
					inAccessor.remove(name);
					throw e;
				}
				inAccessor.remove(name);
				return result;
			}
		}

		if(fields.exists(name) || base == null) fields.set(name, value);
		else if(hasBaseField(name)) Reflect.setProperty(base, name, value);
		else if(hasMixinField(name)) Reflect.setProperty(mixin, name, value);
		else
		{
			// not declared by the script and not something its base has: kept where the engine can find it too (Stage.add() reads "zIndex")
			fields.set(name, value);
			HxcRuntime.setExtra(base, name, value);
		}
		return value;
	}

	/**
	 * Calls a function of the object: the script's if it has it, the base's otherwise.
	 * Errors are reported instead of thrown, in that case it returns null.
	 */
	public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if(args == null) args = [];

		try
		{
			var method:Dynamic = findMethod(name);
			if(method != null) return Reflect.callMethod(null, method, args);

			if(base != null)
			{
				var func:Dynamic = Reflect.field(base, name);
				if(Reflect.isFunction(func)) return Reflect.callMethod(base, func, args);
			}

			if(mixin != null)
			{
				var func:Dynamic = Reflect.field(mixin, name);
				if(Reflect.isFunction(func)) return Reflect.callMethod(mixin, func, args);
			}
		}
		catch(e:Dynamic)
		{
			HxcRuntime.reportError(cls.name, name, e);
		}
		return null;
	}

	public function toString():String
	{
		return 'HxcInstance(${cls.name})';
	}
}

/**
 * What `super` is inside of a script: `super.something()` runs what the class being extended has, skipping the script's own.
 */
class HxcSuper
{
	public var instance(default, null):HxcInstance;

	public function new(instance:HxcInstance)
	{
		this.instance = instance;
	}

	/**
	 * A member of what the class at a level of the chain extends.
	 */
	public function getField(name:String, level:Int):Dynamic
	{
		var method:Dynamic = instance.findMethod(name, level + 1);
		if(method != null) return method;

		var base:Dynamic = instance.base;
		if(base == null) return null;

		// Classes of the engine that send their own functions to the script have a "__super_(name)" with what the function really does,
		// calling the function itself from the script would run the script again
		var func:Dynamic = Reflect.field(base, '__super_$name');
		if(!Reflect.isFunction(func)) func = Reflect.getProperty(base, name);
		if(Reflect.isFunction(func))
		{
			var me:HxcInstance = instance;
			return Reflect.makeVarArgs(function(args:Array<Dynamic>) return me.callSuper(base, func, name, args));
		}

		// what the object the script is attached to doesn't have is on the object of the class the script really extends
		var mixin:Dynamic = instance.mixin;
		if(func != null || mixin == null) return func;

		var mixinFunc:Dynamic = Reflect.getProperty(mixin, name);
		if(!Reflect.isFunction(mixinFunc)) return mixinFunc;

		return Reflect.makeVarArgs(function(args:Array<Dynamic>) return Reflect.callMethod(mixin, mixinFunc, args));
	}
}
#end
