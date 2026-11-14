package backend;

/**
 * Where the time of a frame goes, for the test tool ("--perf", see DirectPlay): the parts of PlayState's update are timed, and some
 * things that cost on phones are counted (the files looked for). Off when the game isn't tested: then it does nothing.
 */
class FrameProfile
{
	public static var enabled:Bool = false;

	static var last:Float = 0;
	static var times:Map<String, Float> = [];
	static var counts:Map<String, Int> = [];

	public static function start():Void
	{
		if(enabled) last = haxe.Timer.stamp();
	}

	// The time since the last mark (or start()) goes to this part
	public static function mark(part:String):Void
	{
		if(!enabled) return;
		var now:Float = haxe.Timer.stamp();
		add(part, (now - last) * 1000);
		last = now;
	}

	static function add(part:String, ms:Float):Void
	{
		times.set(part, (times.exists(part) ? times.get(part) : 0) + ms);
		// (a part that took most of a slow frame by itself)
		if(ms > 150) count('spike in ' + part);
	}

	/**
	 * Updates the objects of a state one by one, timing each (by its class, and its tag if it has one): what of the screen costs.
	 * They're left inactive for the state's own update, which would update them again: restore() makes them active after it.
	 */
	public static function updateMembers(group:flixel.group.FlxGroup.FlxTypedGroup<flixel.FlxBasic>, elapsed:Float):Array<flixel.FlxBasic>
	{
		if(!enabled || group == null) return NONE;
		var done:Array<flixel.FlxBasic> = [];
		var tags:Map<flixel.FlxBasic, String> = [for (tag => object in MusicBeatState.getVariables()) if(Std.isOfType(object, flixel.FlxBasic)) (object:flixel.FlxBasic) => tag];
		// (and the state's own: "uiGroup", "boyfriendGroup"...)
		for (field in Type.getInstanceFields(Type.getClass(group)))
		{
			var value:Dynamic = try Reflect.field(group, field) catch(e:Dynamic) null;
			if(value != null && Std.isOfType(value, flixel.FlxBasic) && !tags.exists(value)) tags.set(value, field);
		}
		for (member in group.members)
		{
			if(member == null || !member.exists || !member.active) continue;
			var name:String = Type.getClassName(Type.getClass(member)).split('.').pop();
			if(tags.exists(member)) name += ' "' + tags.get(member) + '"';
			var began:Float = haxe.Timer.stamp();
			// (a group: its own members timed too, one level down)
			var inner:flixel.group.FlxGroup.FlxTypedGroup<Dynamic> = null;
			if(Std.isOfType(member, flixel.group.FlxGroup.FlxTypedGroup)) inner = cast member;
			else if(Std.isOfType(member, flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup)) inner = @:privateAccess (cast member:flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup<Dynamic>).group;
			if(inner != null)
			{
				name += ' (' + inner.length + ')';
				for (child in inner.members)
				{
					if(child == null || !child.exists || !child.active) continue;
					var childBegan:Float = haxe.Timer.stamp();
					child.update(elapsed);
					var childName:String = Type.getClassName(Type.getClass(child)).split('.').pop();
					if(tags.exists(child)) childName += ' "' + tags.get(child) + '"';
					add('    ' + name + ' > ' + childName, (haxe.Timer.stamp() - childBegan) * 1000);
					child.active = false;
					done.push(child);
				}
			}
			var groupBegan:Float = haxe.Timer.stamp();
			member.update(elapsed);
			add('  ' + name + ' (itself)', (haxe.Timer.stamp() - groupBegan) * 1000);
			member.active = false;
			done.push(member);
		}
		last = haxe.Timer.stamp();
		return done;
	}

	static final NONE:Array<flixel.FlxBasic> = []; //(when it's off: nothing made on every frame)

	public static function restore(done:Array<flixel.FlxBasic>):Void
		if(done.length > 0) for (member in done) if(member != null) member.active = true;

	// (a part timed by itself, inside another one: since `began`, a haxe.Timer.stamp())
	public static function since(part:String, began:Float):Void
	{
		if(enabled) add(part, (haxe.Timer.stamp() - began) * 1000);
	}

	// (a number added up over the frames, shown per frame like the counts)
	public static function amount(what:String, value:Float):Void
	{
		if(!enabled) return;
		counts.set(what, (counts.exists(what) ? counts.get(what) : 0) + Std.int(value));
	}

	public static function count(what:String):Void
	{
		if(!enabled) return;
		counts.set(what, (counts.exists(what) ? counts.get(what) : 0) + 1);
	}

	static var sampled:Int = 0;

	/**
	 * Counts it with where it was called from (one call in 20, the stack costs): what calls something too many times.
	 */
	public static function countFrom(what:String):Void
	{
		if(!enabled) return;
		count(what);
		if(sampled++ % 20 != 0) return;
		var places:Array<String> = [];
		for (item in haxe.CallStack.callStack())
		{
			switch(item)
			{
				case FilePos(_, file, line, _):
					if(file.indexOf('FrameProfile') >= 0 || file.indexOf('MobileStorage') >= 0) continue;
					places.push(file.split('/').pop() + ':' + line);
				default:
			}
			if(places.length >= 4) break;
		}
		count('  from ' + places.join(' < '));
	}

	/**
	 * What was measured since the last time (per frame, over that many frames), and starts again.
	 */
	public static function report(frames:Int):String
	{
		if(frames < 1) frames = 1;
		var parts:Array<String> = [for (part in times.keys()) if(times.get(part) / frames >= 0.3) part]; //(what costs: the log cuts long lines)
		parts.sort(function(a, b) return Reflect.compare(times.get(b), times.get(a)));
		var text:String = [for (part in parts) '$part ' + Std.int(times.get(part) / frames * 100) / 100].join(', ');
		var counted:Array<String> = [for (what in counts.keys()) '$what ' + Std.int(counts.get(what) / frames * 10) / 10];
		if(counted.length > 0) text += ' | per frame: ' + counted.join(', ');
		times = [];
		counts = [];
		return text;
	}
}
