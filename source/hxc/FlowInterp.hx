package hxc;

import crowplexus.hscript.Expr;
import crowplexus.hscript.Interp;
import crowplexus.hscript.Tools;

/**
 * The script interpreter (the one of HScript and of V-Slice's scripts) with `return`, `break` and `continue` done without exceptions.
 *
 * The library throws one for each of them, and catches it where it's handled (the function, the loop). On a computer that's quick,
 * on a phone it isn't: an exception there goes back through every function of the interpreter one by one, a third of a second for a
 * `return` on a slow phone. A script that returns from a function called every frame (V-Slice's characters do) left the game at a
 * few frames a second. Here they leave a mark instead (`flow`), and each block, loop and function stops at it and hands it up,
 * until the one it's for.
 *
 * The same goes for loops over a range (`for (i in 0...10)`): the library asks every value for its iterator in a try, and a range
 * has none, so every one of those loops threw an exception before it began.
 */
class FlowInterp extends Interp
{
	// What a return, break or continue reached left to do (0: nothing, the code goes on)
	var flow:Int = 0;
	static inline final BREAK:Int = 1;
	static inline final CONTINUE:Int = 2;
	static inline final RETURN:Int = 3;

	override public function expr(e:Expr):Dynamic
	{
		switch(Tools.expr(e))
		{
			case EReturn(value):
				#if hscriptPos curExpr = e; #end
				var result:Dynamic = (value == null) ? null : expr(value);
				if(flow != 0) return null; //(something in the value itself stopped already)
				returnValue = result;
				flow = RETURN;
				return null;

			case EBreak:
				flow = BREAK;
				return null;

			case EContinue:
				flow = CONTINUE;
				return null;

			case EBlock(exprs):
				#if hscriptPos curExpr = e; #end
				var old:Int = declared.length;
				var result:Dynamic = null;
				for (item in exprs)
				{
					result = expr(item);
					if(flow != 0) break;
				}
				restore(old);
				return result;

			case EIf(econd, e1, e2):
				#if hscriptPos curExpr = e; #end
				var condition:Dynamic = expr(econd);
				if(flow != 0) return null;
				return (condition == true) ? expr(e1) : ((e2 == null) ? null : expr(e2));

			case ETernary(econd, e1, e2):
				#if hscriptPos curExpr = e; #end
				var condition:Dynamic = expr(econd);
				if(flow != 0) return null;
				return (condition == true) ? expr(e1) : expr(e2);

			case ESwitch(value, cases, def):
				#if hscriptPos curExpr = e; #end
				var val:Dynamic = expr(value);
				if(flow != 0) return null;
				var match:Bool = false;
				for (c in cases)
				{
					for (v in c.values)
						if((!Type.enumEq(Tools.expr(v), EIdent("_")) && expr(v) == val) && (c.ifExpr == null || expr(c.ifExpr) == true))
						{
							match = true;
							break;
						}
					if(match)
					{
						val = expr(c.expr);
						break;
					}
				}
				if(!match) val = (def == null) ? null : expr(def);
				return val;

			case ETry(body, name, _, ecatch):
				#if hscriptPos curExpr = e; #end
				var old:Int = declared.length;
				var oldTry:Bool = inTry;
				try
				{
					inTry = true;
					var result:Dynamic = expr(body);
					restore(old);
					inTry = oldTry;
					return result;
				}
				catch(err:Dynamic)
				{
					backend.FrameProfile.count('caught by a try of a script: ' + Std.string(err).substr(0, 120));
					restore(old);
					inTry = oldTry;
					flow = 0; //(what was going on in the try was left by the error)
					declared.push({n: name, old: locals.get(name)});
					locals.set(name, {r: err, const: false});
					var result:Dynamic = expr(ecatch);
					restore(old);
					return result;
				}

			default:
		}
		return super.expr(e);
	}

	// `i++` on a local variable: the library's own version never changes those (only the others), so `while(i < 10) i++;` never ended
	override function increment(e:Expr, prefix:Bool, delta:Int):Dynamic
	{
		switch(Tools.expr(e))
		{
			case EIdent(id):
				var local = locals.get(id);
				if(local == null) return super.increment(e, prefix, delta);
				#if hscriptPos curExpr = e; #end
				var value:Dynamic = local.r;
				var newValue:Dynamic = value + delta;
				if(local.const != true) local.r = newValue;
				else error(ECustom('Cannot reassign final, for constant expression -> ' + id));
				return prefix ? newValue : value;
			default:
		}
		return super.increment(e, prefix, delta);
	}

	// A function's body (and the script's own code): a return stops here, with its value
	override function exprReturn(e:Expr):Dynamic
	{
		var result:Dynamic = expr(e);
		var reached:Int = flow;
		flow = 0;
		switch(reached)
		{
			case RETURN:
				result = returnValue;
				returnValue = null;
			case BREAK:
				throw "Invalid break";
			case CONTINUE:
				throw "Invalid continue";
			default:
		}
		return result;
	}

	// (true if the loop has to end: a break, or a return that goes on up)
	inline function loopEnds():Bool
	{
		if(flow == 0) return false;
		if(flow == CONTINUE)
		{
			flow = 0;
			return false;
		}
		if(flow == BREAK) flow = 0;
		return true;
	}

	override function whileLoop(econd:Expr, e:Expr)
	{
		var old:Int = declared.length;
		while(expr(econd) == true)
		{
			expr(e);
			if(loopEnds()) break;
		}
		restore(old);
	}

	override function doWhileLoop(econd:Expr, e:Expr)
	{
		var old:Int = declared.length;
		do
		{
			expr(e);
			if(loopEnds()) break;
		}
		while(expr(econd) == true);
		restore(old);
	}

	override function forLoop(n:String, it:Expr, e:Expr)
	{
		var old:Int = declared.length;
		declared.push({n: n, old: locals.get(n)});
		var iterator:Iterator<Dynamic> = makeIterator(expr(it));
		while(iterator.hasNext())
		{
			locals.set(n, {r: iterator.next(), const: false});
			expr(e);
			if(loopEnds()) break;
		}
		restore(old);
	}

	// A value's iterator, or the value itself when it is one (a range, `0...10`): asked without a try, which threw for those
	override function makeIterator(v:Dynamic):Iterator<Dynamic>
	{
		if(v != null)
		{
			var getIterator:Dynamic = (Std.isOfType(v, Array) || Std.isOfType(v, haxe.Constraints.IMap)) ? null : Reflect.field(v, 'iterator');
			if(Std.isOfType(v, Array)) v = (v:Array<Dynamic>).iterator();
			else if(Std.isOfType(v, haxe.Constraints.IMap)) v = (v:haxe.Constraints.IMap<Dynamic, Dynamic>).iterator();
			else if(getIterator != null && Reflect.isFunction(getIterator)) v = Reflect.callMethod(v, getIterator, []);
		}
		if(v == null || v.hasNext == null || v.next == null)
			error(EInvalidIterator(v));
		return v;
	}
}
