package hxc;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.TypeTools;
using StringTools;

/**
 * What scripts can import that isn't a class: abstracts and typedefs. Like V-Slice (Polymod makes a class out of every abstract of
 * the game for its scripts), scripts here import any of them by their path:
 *
 *   - An abstract (`flixel.util.FlxAxes`, `flixel.text.FlxText.FlxTextAlign`, `openfl.display.BlendMode`...) becomes a class made
 *     here with its values and static functions (`FlxAxes.XY`, `FlxTextAlign.fromOpenFL()`). Its functions on a value (`color.red`)
 *     aren't there: on V-Slice they aren't either, the value is what the abstract is made over.
 *   - A typedef of a class (`flixel.group.FlxSpriteGroup`) is that class, one of an enum is the enum, one of an abstract is the
 *     abstract's class. One of a structure (`{x:Float, y:Float}`) is only a type: there's nothing to use it for but to name types,
 *     and scripts don't check those.
 *
 * Made after the game is typed (`Context.onAfterTyping()`), out of everything it has: `hxc.ScriptTypes` lists them for
 * `HxcRuntime.resolveImport()`. Added to the build in Project.xml.
 */
class ScriptTypesMacro
{
	// What scripts can import from: V-Slice's libraries and the engine's version of V-Slice's classes
	static final PACKAGES:Array<String> = ['flixel', 'openfl', 'lime', 'haxe', 'funkin', 'flxanimate', 'hxvlc', 'thx', 'animate'];

	// (what V-Slice doesn't let scripts have, or only exists for the compiler)
	static final SKIPPED:Array<String> = ['haxe.macro', 'haxe.display', 'haxe.ui', 'lime._internal', 'openfl._internal', 'lime.tools', 'flixel.system.macros',
		'funkin.util.macro', 'haxe.Rest', 'haxe.extern', 'haxe.atomic', 'haxe.Constraints', 'lime.system.CFFI', 'lime.system.JNI', 'hxvlc.externs'];

	static var done:Bool = false;

	public static function init():Void
	{
		// (and V-Slice's fields on every sprite, see hxc.FlxSpriteMacro)
		haxe.macro.Compiler.addMetadata('@:build(hxc.FlxSpriteMacro.build())', 'flixel.FlxSprite');
		haxe.macro.Compiler.addMetadata('@:build(hxc.FlxSpriteMacro.buildAnimationController())', 'flixel.animation.FlxAnimationController');

		Context.onAfterTyping(function(types:Array<ModuleType>)
		{
			if(done) return;
			done = true;
			build(types);
		});
	}

	// An abstract over something of C++ itself (an extern class, a native type): what's made for it wouldn't build there
	static function overNative(a:AbstractType):Bool
	{
		if(a.meta.has(':native')) return true;
		return switch(a.type)
		{
			// (String and Array are externs of Haxe itself: those are fine)
			case TInst(ref, _): (ref.get().isExtern && ref.get().pack.length > 0) || ref.get().meta.has(':native');
			case TAbstract(ref, _): ref.get().meta.has(':native') || (ref.get().meta.has(':coreType') && ref.get().pack.length > 0);
			default: false;
		}
	}

	static function allowed(pack:Array<String>, module:String):Bool
	{
		if(pack.length < 1 || !PACKAGES.contains(pack[0])) return false;
		for (skipped in SKIPPED)
			if(module == skipped || module.startsWith(skipped + '.')) return false;
		for (part in pack)
			if(part.startsWith('_')) return false;
		return true;
	}

	// The paths a type is imported by: "pack.Name", and "pack.Module.Name" when it's declared on a file with another name
	static function importPaths(pack:Array<String>, module:String, name:String):Array<String>
	{
		var paths:Array<String> = [pack.concat([name]).join('.')];
		var moduleName:String = module.split('.').pop();
		if(moduleName != name) paths.push(module + '.' + name);
		return paths;
	}

	// The expression of a type, written the way the compiler finds it from anywhere
	static function typeExpr(module:String, name:String):Expr
	{
		var parts:Array<String> = module.split('.');
		if(parts[parts.length - 1] != name) parts.push(name);
		return macro $p{parts};
	}

	static function build(types:Array<ModuleType>):Void
	{
		var entries:Array<String> = []; // path, what it is, path, what it is...
		var made:Map<String, String> = []; // abstract (by its first path) => the class made for it

		var abstracts:Array<AbstractType> = [];
		var typeOnly:Array<AbstractType> = []; // (abstracts with nothing to give: generic ones, or ones with only functions on a value)
		var typedefs:Array<DefType> = [];
		for (type in types)
		{
			switch(type)
			{
				case TAbstract(ref):
					var a:AbstractType = ref.get();
					if(a.isPrivate || !allowed(a.pack, a.module)) continue;
					if(a.impl != null && a.params.length == 0 && !a.meta.has(':coreType') && !overNative(a)) abstracts.push(a);
					else typeOnly.push(a);
				case TTypeDecl(ref):
					var t:DefType = ref.get();
					if(!t.isPrivate && allowed(t.pack, t.module)) typedefs.push(t);
				default:
			}
		}

		for (a in abstracts)
		{
			var className:String = 'A_' + a.pack.join('_') + '_' + a.name;
			var fields:Array<Field> = abstractFields(a);
			if(fields.length < 1)
			{
				typeOnly.push(a);
				continue;
			}

			Context.defineType({
				pack: ['hxc', 'abstracts'],
				name: className,
				pos: a.pos,
				meta: [{name: ':keep', pos: a.pos}, {name: ':noCompletion', pos: a.pos}],
				kind: TDClass(),
				fields: fields
			});
			var runtimeName:String = 'hxc.abstracts.' + className;
			for (path in importPaths(a.pack, a.module, a.name))
			{
				entries.push(path);
				entries.push('class:' + runtimeName);
			}
			made.set(a.pack.concat([a.name]).join('.'), runtimeName);
		}

		// (still something scripts import, to name types with: on V-Slice they can)
		for (a in typeOnly)
			for (path in importPaths(a.pack, a.module, a.name))
			{
				entries.push(path);
				entries.push('type');
			}

		for (t in typedefs)
		{
			var target:String = 'type';
			switch(t.type.follow())
			{
				case TInst(ref, _):
					var c:ClassType = ref.get();
					if(!c.isPrivate && !c.isExtern && c.kind.match(KNormal)) target = 'class:' + c.pack.concat([c.name]).join('.');
				case TEnum(ref, _):
					var e:EnumType = ref.get();
					if(!e.isPrivate) target = 'enum:' + e.pack.concat([e.name]).join('.');
				case TAbstract(ref, _):
					var a:AbstractType = ref.get();
					var wrapper:String = made.get(a.pack.concat([a.name]).join('.'));
					if(wrapper != null) target = 'class:' + wrapper;
				default:
			}
			for (path in importPaths(t.pack, t.module, t.name))
			{
				entries.push(path);
				entries.push(target);
			}
		}

		Sys.println('ScriptTypesMacro: ' + Lambda.count(made) + ' abstracts and ' + typedefs.length + ' typedefs for scripts');
		var pos:Position = Context.currentPos();
		var values:Array<Expr> = [for (entry in entries) {expr: EConst(CString(entry)), pos: pos}];
		var list:Expr = {expr: EArrayDecl(values), pos: pos};
		Context.defineType({
			pack: ['hxc'],
			name: 'ScriptTypes',
			pos: pos,
			meta: [{name: ':keep', pos: pos}],
			kind: TDClass(),
			fields: (macro class ScriptTypes {
				/**
				 * Paths of types scripts import, each followed by what it is: "class:(name)", "enum:(name)" or "type" (only a type).
				 */
				public static function list():Array<String> return $list;
			}).fields
		});
	}

	// The values and static functions of an abstract, for its class
	static function abstractFields(a:AbstractType):Array<Field>
	{
		var fields:Array<Field> = [];
		var self:Expr = typeExpr(a.module, a.name);
		var moduleName:String = a.module.split('.').pop();
		var selfType:ComplexType = TPath({pack: a.pack, name: moduleName, sub: (moduleName != a.name) ? a.name : null});
		var pos:Position = a.pos;

		var statics:Array<ClassField> = a.impl.get().statics.get();
		var publicNames:Array<String> = [for (field in statics) if(field.isPublic) field.name];
		for (field in statics)
		{
			if(!field.isPublic || field.meta.has(':op') || field.meta.has(':arrayAccess')
				|| field.name == '_new' || field.params.length > 0)
				continue;

			var name:String = field.name;
			var access:Expr = macro $self.$name;
			switch(field.kind)
			{
				case FVar(read, _):
					if(read == AccNo || read == AccNever || !compiles(macro (cast $access : Dynamic))) continue;
					fields.push({
						name: name,
						access: [APublic, AStatic],
						kind: FProp('get', 'never', macro :Dynamic),
						pos: pos
					});
					// (an abstract with a getter of its own for it: that one's made below, and is the property's)
					if(!publicNames.contains('get_' + name))
						fields.push({
							name: 'get_' + name,
							access: [AStatic],
							kind: FFun({args: [], ret: macro :Dynamic, expr: macro return (cast $access : Dynamic)}),
							pos: pos
						});

				case FMethod(kind):
					if(kind == MethMacro) continue;
					switch(field.type.follow())
					{
						case TFun(args, ret):
							// (the abstract's functions on a value get it as their first argument, "this": scripts call them like that too,
							// `Version.toString(version)`, like on V-Slice, whose Polymod gives them the same way)
							var onValue:Bool = args.length > 0 && args[0].name == 'this';
							if(Lambda.exists(args, function(arg) return arg.t.toString().indexOf('haxe.Rest') > -1)) continue;
							var made:Field = forwarder(name, access, args, ret, pos, onValue ? selfType : null);
							switch(made.kind)
							{
								case FFun(func):
									// (tried as a function of its own first: one the abstract only has for its values, or that can't be called
									// with any value, is left out instead of breaking the build)
									var test:Expr = {expr: EFunction(FAnonymous, func), pos: pos};
									if(compiles(test)) fields.push(made);
								default:
							}
						default:
					}

				default:
			}
		}
		return fields;
	}

	// If an expression types (abstracts have fields that only work on a value of theirs, or on some platforms)
	static function compiles(expr:Expr):Bool
	{
		try
		{
			Context.typeExpr(expr);
			return true;
		}
		catch(e:Dynamic) {}
		return false;
	}

	// A function that calls the abstract's own with what it gets (the optional arguments left out are left out on the call too)
	static function forwarder(name:String, target:Expr, args:Array<{name:String, opt:Bool, t:haxe.macro.Type}>, ret:haxe.macro.Type, pos:Position,
			?valueType:ComplexType):Field
	{
		var funcArgs:Array<FunctionArg> = [];
		var names:Array<String> = [];
		for (i in 0...args.length)
		{
			var argName:String = 'a$i';
			names.push(argName);
			funcArgs.push({name: argName, opt: args[i].opt, type: macro :Dynamic});
		}

		var isVoid:Bool = switch(ret.follow()) {
			case TAbstract(ref, _): ref.get().name == 'Void' && ref.get().pack.length == 0;
			default: false;
		};

		function call(count:Int):Expr
		{
			var callArgs:Array<Expr> = [for (i in 0...count) macro $i{names[i]}];
			var callExpr:Expr = macro $target($a{callArgs});
			if(valueType != null)
			{
				// (a function on a value: called on the first argument, made into one of the abstract)
				var rest:Array<Expr> = callArgs.slice(1);
				var value:Expr = macro (cast $i{names[0]} : $valueType);
				callExpr = {expr: ECall({expr: EField(value, name), pos: pos}, rest), pos: pos};
			}
			return isVoid ? macro {$callExpr; return null;} : macro return (cast $callExpr : Dynamic);
		}

		// with everything up to the last optional argument given (the ones left out keep the abstract's own default)
		var body:Array<Expr> = [];
		var required:Int = 0;
		for (i in 0...args.length)
			if(!args[i].opt) required = i + 1;
		var count:Int = args.length;
		while(count > required)
		{
			var last:String = names[count - 1];
			body.push(macro if($i{last} != null) ${call(count)});
			count--;
		}
		body.push(call(required));

		return {
			name: name,
			access: [APublic, AStatic],
			kind: FFun({args: funcArgs, ret: macro :Dynamic, expr: macro $b{body}}),
			pos: pos
		};
	}
}
#end
