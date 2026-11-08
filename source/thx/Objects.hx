package thx;

/**
 * The part of the "thx.core" library's `Objects` that V-Slice mods' scripts use (V-Slice comes with that library): putting the
 * fields of objects together, the later ones over the earlier ones.
 */
@:keep
class Objects
{
	/**
	 * A new object with the fields of `first`, and those of `second` over them.
	 */
	public static function shallowCombine(first:Dynamic, second:Dynamic):Dynamic
	{
		var result:Dynamic = {};
		for (from in [first, second])
			if(from != null)
				for (field in Reflect.fields(from))
					Reflect.setField(result, field, Reflect.field(from, field));
		return result;
	}

	/**
	 * Like `shallowCombine()`, and the fields that are objects on both are combined the same way.
	 */
	public static function deepCombine(first:Dynamic, second:Dynamic):Dynamic
	{
		var result:Dynamic = shallowCombine(first, null);
		if(second == null) return result;
		for (field in Reflect.fields(second))
		{
			var mine:Dynamic = Reflect.field(result, field);
			var theirs:Dynamic = Reflect.field(second, field);
			if(isObject(mine) && isObject(theirs)) Reflect.setField(result, field, deepCombine(mine, theirs));
			else Reflect.setField(result, field, theirs);
		}
		return result;
	}

	public static function combine(first:Dynamic, second:Dynamic):Dynamic return shallowCombine(first, second);
	public static function merge(to:Dynamic, from:Dynamic):Dynamic
	{
		if(to == null || from == null) return to;
		for (field in Reflect.fields(from)) Reflect.setField(to, field, Reflect.field(from, field));
		return to;
	}

	public static function isEmpty(object:Dynamic):Bool return object == null || Reflect.fields(object).length < 1;
	public static function fields(object:Dynamic):Array<String> return (object != null) ? Reflect.fields(object) : [];
	public static function values(object:Dynamic):Array<Dynamic> return [for (field in fields(object)) Reflect.field(object, field)];
	public static function size(object:Dynamic):Int return fields(object).length;
	public static function hasPath(object:Dynamic, path:String):Bool return getPath(object, path) != null;

	public static function getPath(object:Dynamic, path:String):Dynamic
	{
		var current:Dynamic = object;
		for (part in path.split('.'))
		{
			if(current == null) return null;
			current = Reflect.field(current, part);
		}
		return current;
	}

	static function isObject(value:Dynamic):Bool
		return value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && Type.getClass(value) == null && !Std.isOfType(value, Array);
}
