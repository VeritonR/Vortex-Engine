package backend;

import haxe.ds.ObjectMap;

/**
 * JSON that is written back with its fields in the order the file had them.
 *
 * `haxe.Json` loses that order (the objects it makes keep their fields in an order of their own), so a file an editor opens and saves
 * comes out with everything moved around even if only one number changed. `parse()` remembers the order of every object it makes, and
 * `stringify()` follows it, with the fields added afterwards at the end of their object.
 *
 * It writes in the style of V-Slice's files: two spaces, and short lists of numbers (`"offsets": [-169.5, -219]`) on one line.
 */
class OrderedJson
{
	static var orders:ObjectMap<Dynamic, Array<String>> = new ObjectMap();

	public static function parse(text:String):Dynamic
	{
		var parser:OrderedJsonParser = new OrderedJsonParser(text);
		return parser.parseValue();
	}

	/**
	 * The fields of an object, in the order its file had them (and the ones it got later, after them).
	 */
	public static function fieldsOf(object:Dynamic):Array<String>
	{
		var fields:Array<String> = Reflect.fields(object);
		var order:Array<String> = orders.get(object);
		if(order == null) return fields;

		var result:Array<String> = [for (field in order) if(fields.contains(field)) field];
		for (field in fields) if(!result.contains(field)) result.push(field);
		return result;
	}

	@:allow(backend.OrderedJsonParser)
	static function remember(object:Dynamic, order:Array<String>):Void
		orders.set(object, order);

	public static function stringify(value:Dynamic, indent:String = '  '):String
	{
		var buf:StringBuf = new StringBuf();
		write(buf, value, indent, '');
		buf.add('\n');
		return buf.toString();
	}

	static function write(buf:StringBuf, value:Dynamic, indent:String, current:String):Void
	{
		switch(Type.typeof(value))
		{
			case TNull: buf.add('null');
			case TBool: buf.add(value ? 'true' : 'false');
			case TInt: buf.add(Std.string(value));
			case TFloat:
				var number:Float = value;
				buf.add((Math.isNaN(number) || !Math.isFinite(number)) ? 'null' : Std.string(number));
			case TClass(String): quote(buf, value);
			case TClass(Array):
				var list:Array<Dynamic> = value;
				if(list.length == 0)
				{
					buf.add('[]');
					return;
				}
				if(list.length <= 4 && Lambda.foreach(list, (item) -> Std.isOfType(item, Float) || Std.isOfType(item, Int)))
				{
					buf.add('[');
					for (i => item in list)
					{
						if(i > 0) buf.add(', ');
						write(buf, item, indent, current);
					}
					buf.add(']');
					return;
				}
				var inner:String = current + indent;
				buf.add('[\n');
				for (i => item in list)
				{
					buf.add(inner);
					write(buf, item, indent, inner);
					if(i < list.length - 1) buf.add(',');
					buf.add('\n');
				}
				buf.add(current + ']');
			case TObject:
				var fields:Array<String> = fieldsOf(value);
				if(fields.length == 0)
				{
					buf.add('{}');
					return;
				}
				var inner:String = current + indent;
				buf.add('{\n');
				for (i => field in fields)
				{
					buf.add(inner);
					quote(buf, field);
					buf.add(': ');
					write(buf, Reflect.field(value, field), indent, inner);
					if(i < fields.length - 1) buf.add(',');
					buf.add('\n');
				}
				buf.add(current + '}');
			default:
				quote(buf, Std.string(value));
		}
	}

	static function quote(buf:StringBuf, text:String):Void
	{
		buf.add('"');
		for (i in 0...text.length)
		{
			var code:Int = StringTools.fastCodeAt(text, i);
			switch(code)
			{
				case '"'.code: buf.add('\\"');
				case '\\'.code: buf.add('\\\\');
				case '\n'.code: buf.add('\\n');
				case '\r'.code: buf.add('\\r');
				case '\t'.code: buf.add('\\t');
				default:
					if(code < 0x20) buf.add('\\u' + StringTools.hex(code, 4));
					else buf.addChar(code);
			}
		}
		buf.add('"');
	}
}

private class OrderedJsonParser
{
	var text:String;
	var pos:Int = 0;

	public function new(text:String)
	{
		this.text = (text.length > 0 && StringTools.fastCodeAt(text, 0) == 0xFEFF) ? text.substr(1) : text;
	}

	public function parseValue():Dynamic
	{
		skipSpaces();
		if(pos >= text.length) throw 'Unexpected end of the JSON';

		var code:Int = StringTools.fastCodeAt(text, pos);
		switch(code)
		{
			case '{'.code:
				pos++;
				var object:Dynamic = {};
				var order:Array<String> = [];
				skipSpaces();
				if(peek() == '}'.code)
				{
					pos++;
					OrderedJson.remember(object, order);
					return object;
				}
				while(true)
				{
					skipSpaces();
					var key:String = parseString();
					skipSpaces();
					expect(':'.code);
					var value:Dynamic = parseValue();
					if(!order.contains(key)) order.push(key);
					Reflect.setField(object, key, value);
					skipSpaces();
					var next:Int = text.charCodeAt(pos++);
					if(next == '}'.code) break;
					if(next != ','.code) throw 'Expected "," or "}" at $pos';
				}
				OrderedJson.remember(object, order);
				return object;

			case '['.code:
				pos++;
				var list:Array<Dynamic> = [];
				skipSpaces();
				if(peek() == ']'.code)
				{
					pos++;
					return list;
				}
				while(true)
				{
					list.push(parseValue());
					skipSpaces();
					var next:Int = text.charCodeAt(pos++);
					if(next == ']'.code) break;
					if(next != ','.code) throw 'Expected "," or "]" at $pos';
				}
				return list;

			case '"'.code:
				return parseString();

			case 't'.code: word('true'); return true;
			case 'f'.code: word('false'); return false;
			case 'n'.code: word('null'); return null;

			default:
				var start:Int = pos;
				while(pos < text.length)
				{
					var c:Int = StringTools.fastCodeAt(text, pos);
					if((c >= '0'.code && c <= '9'.code) || c == '-'.code || c == '+'.code || c == '.'.code || c == 'e'.code || c == 'E'.code) pos++;
					else break;
				}
				var number:String = text.substring(start, pos);
				if(number.length < 1) throw 'Unexpected "${String.fromCharCode(code)}" at $pos';
				var isInt:Bool = number.indexOf('.') < 0 && number.indexOf('e') < 0 && number.indexOf('E') < 0;
				if(isInt)
				{
					var int:Null<Int> = Std.parseInt(number);
					if(int != null && Std.string(int) == number.replace('+', '')) return int;
				}
				return Std.parseFloat(number);
		}
	}

	function parseString():String
	{
		expect('"'.code);
		var buf:StringBuf = new StringBuf();
		while(true)
		{
			if(pos >= text.length) throw 'Unclosed text in the JSON';
			var code:Int = StringTools.fastCodeAt(text, pos++);
			if(code == '"'.code) break;
			if(code != '\\'.code)
			{
				buf.addChar(code);
				continue;
			}
			var escaped:Int = StringTools.fastCodeAt(text, pos++);
			switch(escaped)
			{
				case 'n'.code: buf.add('\n');
				case 'r'.code: buf.add('\r');
				case 't'.code: buf.add('\t');
				case 'b'.code: buf.addChar(8);
				case 'f'.code: buf.addChar(12);
				case 'u'.code:
					buf.addChar(Std.parseInt('0x' + text.substr(pos, 4)));
					pos += 4;
				default: buf.addChar(escaped);
			}
		}
		return buf.toString();
	}

	inline function peek():Int
		return (pos < text.length) ? StringTools.fastCodeAt(text, pos) : -1;

	function expect(code:Int):Void
	{
		if(peek() != code) throw 'Expected "${String.fromCharCode(code)}" at $pos';
		pos++;
	}

	function word(value:String):Void
	{
		if(text.substr(pos, value.length) != value) throw 'Unexpected text at $pos';
		pos += value.length;
	}

	function skipSpaces():Void
	{
		while(pos < text.length)
		{
			var c:Int = StringTools.fastCodeAt(text, pos);
			if(c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code) pos++;
			else break;
		}
	}
}
