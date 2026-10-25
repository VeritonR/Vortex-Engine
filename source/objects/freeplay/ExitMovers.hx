package objects.freeplay;

/**
 * Where a group of sprites of the V-Slice Freeplay menu goes when the menu is closed, and how fast.
 */
typedef MoveData =
{
	var ?x:Float;
	var ?y:Float;
	var ?speed:Float;
	var ?wait:Float;
}

typedef ExitMoverData = Map<Array<FlxSprite>, MoveData>;

class ExitMovers
{
	/**
	 * Makes what scripts added (`exitMovers.set([sprite], {x: ..., speed: ...})`) into what the menu reads. A script's list of
	 * sprites isn't one of sprites to the game: going through the map, it's copied into one, and that copy finds nothing in it.
	 * And what a script writes as `{x: ..., speed: ...}` is a map of names to values, which has no `x` to be read.
	 */
	public static function fix(movers:ExitMoverData):Void
	{
		if(movers == null) return;

		var raw:haxe.ds.ObjectMap<Dynamic, Dynamic> = cast movers;
		var entries:Array<{key:Dynamic, value:Dynamic}> = [for (key in raw.keys()) {key: key, value: raw.get(key)}];
		for (entry in entries)
		{
			raw.remove(entry.key);

			var data:MoveData = moveDataOf(entry.value);
			if(data == null || !Std.isOfType(entry.key, Array)) continue;

			var list:Array<Dynamic> = entry.key;
			var sprites:Array<FlxSprite> = [for (item in list) if(Std.isOfType(item, FlxSprite)) cast item];
			if(sprites.length > 0) movers.set(sprites, data);
		}
	}

	static function moveDataOf(value:Dynamic):MoveData
	{
		if(value == null) return null;
		if(Std.isOfType(value, haxe.ds.StringMap))
		{
			var map:haxe.ds.StringMap<Dynamic> = value;
			return {x: map.get('x'), y: map.get('y'), speed: map.get('speed'), wait: map.get('wait')};
		}
		return {x: Reflect.field(value, 'x'), y: Reflect.field(value, 'y'), speed: Reflect.field(value, 'speed'), wait: Reflect.field(value, 'wait')};
	}
}
