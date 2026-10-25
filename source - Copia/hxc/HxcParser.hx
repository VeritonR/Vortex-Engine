package hxc;

#if HSCRIPT_ALLOWED
import crowplexus.hscript.Expr;
import crowplexus.hscript.Parser;

/**
 * Parser for V-Slice script files (.hxc), which are whole Haxe modules instead of loose statements.
 * The library already reads classes, imports and typedefs, this adds what else can be at the top of a file.
 */
class HxcParser extends Parser
{
	public var usings:Array<String> = [];

	/**
	 * Things declared outside of the classes that have to run when the file is loaded, like enums.
	 */
	public var moduleExprs:Array<Expr> = [];

	public function new()
	{
		super();
		allowTypes = true;
		allowJSON = true;
		allowMetadata = true;
	}

	// `for (key => value in map)`, Haxe 4's loop over keys and values, which the library doesn't read: made into the loop it stands for,
	// over `keyValueIterator()` (what Haxe does with it too)
	var keyValueLoops:Int = 0;

	override function parseStructure(id:String)
	{
		// `cast(value, Type)` and `cast value`, which the library doesn't know (it's a variable to it): the value itself, the type is only read
		if(id == 'cast')
		{
			var open = token();
			if(open == TPOpen)
			{
				var value:Expr = parseExpr();
				var next = token();
				if(next == TComma)
				{
					parseType();
					next = token();
				}
				if(next != TPClose) unexpected(next);
				return mk(EParent(value));
			}
			push(open);
			return parseExpr();
		}

		if(id == 'for')
		{
			var open = token();
			switch(open)
			{
				case TPOpen:
					var first = token();
					var arrow = token();
					switch([first, arrow])
					{
						case [TId(keyName), TOp('=>')]:
							return parseKeyValueLoop(keyName);
						default:
					}
					push(arrow);
					push(first);
				default:
			}
			push(open);
		}
		return super.parseStructure(id);
	}

	function parseKeyValueLoop(keyName:String):Expr
	{
		var valueName:String = getIdent();
		ensureToken(TId('in'));
		var iterable:Expr = parseExpr();
		ensure(TPClose);
		var body:Expr = parseExpr();

		var iterName:String = '__hxc_kv' + (keyValueLoops++);
		var entryName:String = iterName + '_e';
		var iterator:Expr = mk(EVar(iterName, null, mk(ECall(mk(EField(iterable, 'keyValueIterator', false)), []))));
		var entry:Expr = mk(EVar(entryName, null, mk(ECall(mk(EField(mk(EIdent(iterName)), 'next', false)), []))));
		var key:Expr = mk(EVar(keyName, null, mk(EField(mk(EIdent(entryName)), 'key', false))));
		var value:Expr = mk(EVar(valueName, null, mk(EField(mk(EIdent(entryName)), 'value', false))));
		var hasNext:Expr = mk(ECall(mk(EField(mk(EIdent(iterName)), 'hasNext', false)), []));
		return mk(EBlock([iterator, mk(EWhile(hasNext, mk(EBlock([entry, key, value, body]))))]));
	}

	// The library's, but the last thing of a block can go without its ";" (`() -> {thing.dispatch()}`), like on V-Slice's scripts
	override function parseFullExpr(exprs:Array<Expr>)
	{
		var e = parseExpr();
		if (!expr(e).match(EIgnore(_)))
			exprs.push(e);

		var tk = token();
		while (tk == TComma && e != null && expr(e).match(EVar(_)))
		{
			e = parseStructure("var");
			if (!expr(e).match(EIgnore(_)))
				exprs.push(e);
			tk = token();
		}

		if (tk != TSemicolon && tk != TEof)
		{
			if (isBlock(e) || tk == TBrClose)
				push(tk);
			else
				unexpected(tk);
		}
	}

	override function parseModuleDecl():ModuleDecl
	{
		var tk = token();
		switch(tk)
		{
			case TId('using'):
				var path:Array<String> = parsePath();
				ensure(TSemicolon);
				usings.push(path.join('.'));
				return DPackage([]);

			case TId('enum'):
				push(tk);
				moduleExprs.push(parseExpr());
				maybe(TSemicolon);
				return DPackage([]);

			case TId('final'): //"final class", there's no inheritance to forbid here
				return parseModuleDecl();

			case TId('import'):
				// with what Haxe has that the library doesn't read here: `import a.b.Thing as Other;` (or `in Other`)
				var path:Array<String> = [getIdent()];
				var everything:Bool = false;
				while(true)
				{
					var next = token();
					if(next != TDot)
					{
						push(next);
						break;
					}
					next = token();
					switch(next)
					{
						case TId(name): path.push(name);
						case TOp('*'): everything = true;
						default: unexpected(next);
					}
				}

				var alias:String = null;
				var next = token();
				switch(next)
				{
					case TId('as'), TId('in'): alias = getIdent();
					default: push(next);
				}
				ensure(TSemicolon);
				return DImport(path, everything, alias);

			default:
				push(tk);
				return super.parseModuleDecl();
		}
	}

	// ------------------------------------------------------------------------------------------
	// The "is" operator
	// ------------------------------------------------------------------------------------------

	/**
	 * `value is Type`, which V-Slice scripts can write without the parentheses Haxe itself asks for. It's read as a call to
	 * `HxcRuntime.isOfType()`, and before the operators around it: `state is TitleState == false` is the check first, compared after.
	 */
	override function parseExprNext(e1:Expr)
	{
		var tk = token();
		switch(tk)
		{
			case TId('is'):
				var path:Array<String> = parsePath();
				var type:Expr = mk(EIdent(path[0]), pmin(e1));
				for (index in 1...path.length)
					type = mk(EField(type, path[index], false), pmin(e1));
				return parseExprNext(mk(ECall(mk(EIdent(IS_FUNCTION), pmin(e1)), [e1, type]), pmin(e1)));

			default:
				push(tk);
				return super.parseExprNext(e1);
		}
	}

	public static inline var IS_FUNCTION:String = '__hxc_is';

	// ------------------------------------------------------------------------------------------
	// String interpolation
	// ------------------------------------------------------------------------------------------

	/**
	 * Turns the texts with values in the middle of them ('Hello $name, you have ${count + 1} things') into what they mean:
	 * the pieces of text added to the values. The library reads those texts as they're written, without it they'd say "$name" itself.
	 *
	 * It's done on the code as a whole before it's parsed, without adding or taking lines so errors still point to the right one.
	 */
	public static function expandStrings(code:String):String
	{
		if(code.indexOf("'") < 0) return code;

		var out:StringBuf = new StringBuf();
		var length:Int = code.length;
		var i:Int = 0;
		while(i < length)
		{
			var char:Int = StringTools.fastCodeAt(code, i);
			var next:Int = (i + 1 < length) ? StringTools.fastCodeAt(code, i + 1) : 0;

			if(char == '/'.code && next == '/'.code)
			{
				var end:Int = code.indexOf('\n', i);
				if(end < 0) end = length;
				out.add(code.substring(i, end));
				i = end;
			}
			else if(char == '/'.code && next == '*'.code)
			{
				var end:Int = code.indexOf('*/', i + 2);
				end = (end < 0) ? length : end + 2;
				out.add(code.substring(i, end));
				i = end;
			}
			else if(char == '~'.code && next == '/'.code)
			{
				// a regular expression, whatever it has inside isn't code
				var end:Int = i + 2;
				while(end < length)
				{
					var inside:Int = StringTools.fastCodeAt(code, end);
					if(inside == '\\'.code) end += 2;
					else if(inside == '/'.code || inside == '\n'.code) break;
					else end++;
				}
				end = (end < length) ? end + 1 : length;
				out.add(code.substring(i, end));
				i = end;
			}
			else if(char == '"'.code)
			{
				var end:Int = skipString(code, i);
				out.add(code.substring(i, end));
				i = end;
			}
			else if(char == "'".code)
			{
				i = expandString(code, i, out);
			}
			else
			{
				out.addChar(char);
				i++;
			}
		}
		return out.toString();
	}

	// Where a text between double quotes ends, right after its closing quote
	static function skipString(code:String, start:Int):Int
	{
		var i:Int = start + 1;
		while(i < code.length)
		{
			var char:Int = StringTools.fastCodeAt(code, i);
			if(char == '\\'.code) i += 2;
			else if(char == '"'.code) return i + 1;
			else i++;
		}
		return code.length;
	}

	static inline function isNameStart(char:Int):Bool
	{
		return (char >= 'a'.code && char <= 'z'.code) || (char >= 'A'.code && char <= 'Z'.code) || char == '_'.code;
	}

	// Writes a text between single quotes with its values taken out of it, returns where it ends
	static function expandString(code:String, start:Int, out:StringBuf):Int
	{
		var pieces:Array<String> = [];
		var hasValues:Bool = false;
		var text:StringBuf = new StringBuf();
		var textLength:Int = 0;

		function endText():Void
		{
			if(textLength > 0) pieces.push("'" + text.toString() + "'");
			text = new StringBuf();
			textLength = 0;
		}

		var length:Int = code.length;
		var i:Int = start + 1;
		var closed:Bool = false;
		while(i < length)
		{
			var char:Int = StringTools.fastCodeAt(code, i);
			if(char == '\\'.code)
			{
				text.add(code.substr(i, 2));
				textLength += 2;
				i += 2;
			}
			else if(char == "'".code)
			{
				closed = true;
				i++;
				break;
			}
			else if(char == "$".code)
			{
				var next:Int = (i + 1 < length) ? StringTools.fastCodeAt(code, i + 1) : 0;
				if(next == "$".code)
				{
					// "$$" is how a single one is written
					text.addChar("$".code);
					textLength++;
					i += 2;
				}
				else if(next == '{'.code)
				{
					// up to the brace that closes it, texts inside of the value can have braces and values of their own
					var depth:Int = 1;
					var end:Int = i + 2;
					while(end < length)
					{
						var inside:Int = StringTools.fastCodeAt(code, end);
						if(inside == '"'.code)
						{
							end = skipString(code, end);
							continue;
						}
						if(inside == "'".code)
						{
							end = expandString(code, end, new StringBuf());
							continue;
						}

						if(inside == '{'.code) depth++;
						else if(inside == '}'.code)
						{
							depth--;
							if(depth == 0) break;
						}
						end++;
					}
					if(end >= length) break; //never closed, the parser is the one to complain about it

					endText();
					pieces.push('(' + expandStrings(code.substring(i + 2, end)) + ')');
					hasValues = true;
					i = end + 1;
				}
				else if(isNameStart(next))
				{
					var end:Int = i + 2;
					while(end < length)
					{
						var inside:Int = StringTools.fastCodeAt(code, end);
						if(isNameStart(inside) || (inside >= '0'.code && inside <= '9'.code)) end++;
						else break;
					}

					endText();
					pieces.push(code.substring(i + 1, end));
					hasValues = true;
					i = end;
				}
				else
				{
					text.addChar(char);
					textLength++;
					i++;
				}
			}
			else
			{
				text.addChar(char);
				textLength++;
				i++;
			}
		}

		if(!closed || !hasValues)
		{
			// nothing to take out of it (or it's broken): it stays as it was written
			if(!closed) i = length;
			out.add(code.substring(start, i));
			return i;
		}

		endText();

		// it has to be a text even when it starts with a value that isn't one
		if(!StringTools.startsWith(pieces[0], "'")) pieces.unshift("''");
		out.add('(' + pieces.join(' + ') + ')');
		return i;
	}
}
#end
