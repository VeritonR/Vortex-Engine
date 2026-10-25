package backend;

/**
 * Changes to JSON data the way Polymod (V-Slice's mod loader) does them for the files of a mod's "_merge" and "_append" folders.
 * See `PolymodMerge`, which is what finds those files.
 *
 * A file of "_merge" is a list of operations, the "JSON Patch" format:
 *
 *     [{"op": "add", "path": "/ownedChars/-", "value": "my-character"}, {"op": "replace", "path": "/name", "value": "New name"}]
 *
 * `op` is "add", "replace", "remove", "move", "copy" or "test". `path` says where, each part after a slash being the name of a value
 * or its position on a list, with "-" for the end of the list ("$.ownedChars[0]" is taken as well). "move" and "copy" have a `from`.
 */
class JsonPatch
{
	/**
	 * Does the operations of a "_merge" file on some data. Returns the data (it's changed in place, unless the operations replace all of it).
	 * An operation that can't be done is skipped, with a trace telling why.
	 */
	public static function patch(data:Dynamic, operations:Dynamic, ?name:String):Dynamic
	{
		if(!Std.isOfType(operations, Array)) return data;

		var list:Array<Dynamic> = operations;
		for (operation in list)
		{
			if(operation == null) continue;

			var op:String = (operation.op != null) ? Std.string(operation.op).toLowerCase() : '';
			var path:Array<String> = splitPath(operation.path);
			try
			{
				switch(op)
				{
					case 'add': data = set(data, path, operation.value, true);
					case 'replace': data = set(data, path, operation.value, false);
					case 'remove': data = remove(data, path);

					case 'move':
						var from:Array<String> = splitPath(operation.from);
						var value:Dynamic = get(data, from);
						data = remove(data, from);
						data = set(data, path, value, true);

					case 'copy':
						data = set(data, path, copy(get(data, splitPath(operation.from))), true);

					case 'test':
						// the rest of the file is only for when the value is what it expects
						if(!same(get(data, path), operation.value)) return data;

					default:
						trace('Merge file' + ((name != null) ? ' "$name"' : '') + ': unknown operation "$op"');
				}
			}
			catch(e:Dynamic)
			{
				trace('Merge file' + ((name != null) ? ' "$name"' : '') + ': could not $op "${operation.path}": $e');
			}
		}
		return data;
	}

	/**
	 * Adds the values of an "_append" file to some data: lists get the new values at their end, values with a name are replaced,
	 * and what has values of its own (an object inside of another) goes through the same thing.
	 */
	public static function append(data:Dynamic, extra:Dynamic):Dynamic
	{
		if(extra == null) return data;
		if(data == null) return extra;

		if(Std.isOfType(data, Array) && Std.isOfType(extra, Array))
		{
			var list:Array<Dynamic> = data;
			var more:Array<Dynamic> = extra;
			for (value in more)
				list.push(value);
			return data;
		}

		if(isObject(data) && isObject(extra))
		{
			for (field in Reflect.fields(extra))
			{
				var value:Dynamic = Reflect.field(extra, field);
				var old:Dynamic = Reflect.field(data, field);
				var bothLists:Bool = Std.isOfType(old, Array) && Std.isOfType(value, Array);
				Reflect.setField(data, field, (bothLists || (isObject(old) && isObject(value))) ? append(old, value) : value);
			}
			return data;
		}
		return extra;
	}

	// ------------------------------------------------------------------------------------------

	static inline function isObject(value:Dynamic):Bool
	{
		return value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Array);
	}

	/**
	 * "/a/b/0" (or "$.a.b[0]") -> ["a", "b", "0"]
	 */
	public static function splitPath(path:Dynamic):Array<String>
	{
		if(path == null) return [];

		var text:String = Std.string(path);
		if(text.length < 1 || text == '/' || text == '$') return [];

		var parts:Array<String> = [];
		if(text.charAt(0) == '$')
		{
			// JSONPath, only the plain kind: names and positions
			var current:StringBuf = new StringBuf();
			var length:Int = 0;
			inline function flush():Void
			{
				if(length > 0) parts.push(current.toString());
				current = new StringBuf();
				length = 0;
			}

			for (i in 1...text.length)
			{
				var char:String = text.charAt(i);
				switch(char)
				{
					case '.', '[', ']': flush();
					case '"', "'":
					default:
						current.add(char);
						length++;
				}
			}
			flush();
			return parts;
		}

		parts = text.split('/');
		if(parts[0] == '') parts.shift();
		return [for (part in parts) StringTools.replace(StringTools.replace(part, '~1', '/'), '~0', '~')];
	}

	static function toIndex(part:String, length:Int, adding:Bool):Int
	{
		if(part == '-') return length;

		var index:Null<Int> = Std.parseInt(part);
		if(index == null || index < 0 || index > length || (!adding && index >= length)) throw 'there is no position "$part" on a list of $length';
		return index;
	}

	static function get(data:Dynamic, path:Array<String>):Dynamic
	{
		var current:Dynamic = data;
		for (part in path)
		{
			if(Std.isOfType(current, Array))
			{
				var list:Array<Dynamic> = current;
				current = list[toIndex(part, list.length, false)];
			}
			else if(isObject(current))
			{
				if(!Reflect.hasField(current, part)) throw 'there is no "$part"';
				current = Reflect.field(current, part);
			}
			else throw 'there is nothing inside of what comes before "$part"';
		}
		return current;
	}

	static function set(data:Dynamic, path:Array<String>, value:Dynamic, adding:Bool):Dynamic
	{
		if(path.length < 1) return value; //the whole thing

		var parent:Dynamic = get(data, path.slice(0, path.length - 1));
		var last:String = path[path.length - 1];
		if(Std.isOfType(parent, Array))
		{
			var list:Array<Dynamic> = parent;
			var index:Int = toIndex(last, list.length, adding);
			if(adding) list.insert(index, value);
			else list[index] = value;
		}
		else if(isObject(parent))
		{
			if(!adding && !Reflect.hasField(parent, last)) throw 'there is no "$last" to replace';
			Reflect.setField(parent, last, value);
		}
		else throw 'there is nothing to put "$last" in';
		return data;
	}

	static function remove(data:Dynamic, path:Array<String>):Dynamic
	{
		if(path.length < 1) return null;

		var parent:Dynamic = get(data, path.slice(0, path.length - 1));
		var last:String = path[path.length - 1];
		if(Std.isOfType(parent, Array))
		{
			var list:Array<Dynamic> = parent;
			list.splice(toIndex(last, list.length, false), 1);
		}
		else if(isObject(parent))
		{
			if(!Reflect.hasField(parent, last)) throw 'there is no "$last" to remove';
			Reflect.deleteField(parent, last);
		}
		else throw 'there is nothing to take "$last" from';
		return data;
	}

	static function copy(value:Dynamic):Dynamic
	{
		if(Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = value;
			return [for (item in list) copy(item)];
		}
		if(isObject(value))
		{
			var result:Dynamic = {};
			for (field in Reflect.fields(value))
				Reflect.setField(result, field, copy(Reflect.field(value, field)));
			return result;
		}
		return value;
	}

	static function same(a:Dynamic, b:Dynamic):Bool
	{
		if(Std.isOfType(a, Array) && Std.isOfType(b, Array))
		{
			var listA:Array<Dynamic> = a;
			var listB:Array<Dynamic> = b;
			if(listA.length != listB.length) return false;
			for (i in 0...listA.length)
				if(!same(listA[i], listB[i]))
					return false;
			return true;
		}
		if(isObject(a) && isObject(b))
		{
			var fields:Array<String> = Reflect.fields(a);
			if(fields.length != Reflect.fields(b).length) return false;
			for (field in fields)
				if(!Reflect.hasField(b, field) || !same(Reflect.field(a, field), Reflect.field(b, field)))
					return false;
			return true;
		}
		return a == b;
	}
}
