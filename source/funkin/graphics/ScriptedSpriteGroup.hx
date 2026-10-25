package funkin.graphics;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

#if HSCRIPT_ALLOWED
import hxc.HxcInstance;
import hxc.HxcRuntime.IHxcScripted;
#end

/**
 * The group of sprites a script class is given when it extends one (`class MyGroup extends FlxTypedSpriteGroup`):
 * what the script overrides of `update`, `draw`, `destroy`, `kill`, `revive` and `reset` is run by the engine like on a real class.
 * A group made any other way is flixel's own, see `hxc.HxcRuntime.scriptedBases`.
 *
 * The base game's tankmen that run in to get shot on Stress are one: the group makes them on its `update()`.
 */
class ScriptedSpriteGroup extends FlxTypedSpriteGroup<FlxSprite> #if HSCRIPT_ALLOWED implements IHxcScripted #end
{
	#if HSCRIPT_ALLOWED
	public var __hxc:HxcInstance = null;
	#end

	/**
	 * Layer on the stage, like V-Slice's sprites have.
	 */
	public var zIndex:Int = 0;

	public function new(x:Float = 0, y:Float = 0, maxSize:Int = 0)
	{
		super(x, y, maxSize);
	}

	// Runs the script's version of a function, returns false if there's no script, it doesn't have one, or it's what's asking for the group's own
	function callScript(name:String, ?args:Array<Dynamic>):Bool
	{
		#if HSCRIPT_ALLOWED
		if(__hxc != null && __hxc.hasMethod(name) && !__hxc.inSuperCall(name))
		{
			__hxc.call(name, args);
			return true;
		}
		#end
		return false;
	}

	override function update(elapsed:Float):Void
	{
		if(!callScript('update', [elapsed])) super.update(elapsed);
	}

	override function draw():Void
	{
		if(!callScript('draw')) super.draw();
	}

	override function destroy():Void
	{
		if(!callScript('destroy')) super.destroy();
	}

	override function kill():Void
	{
		if(!callScript('kill')) super.kill();
	}

	override function revive():Void
	{
		if(!callScript('revive')) super.revive();
	}

	override function reset(x:Float, y:Float):Void
	{
		if(!callScript('reset', [x, y])) super.reset(x, y);
	}

	// What `super.update(elapsed)` and the others run when called from a script
	public function __super_update(elapsed:Float):Void super.update(elapsed);
	public function __super_draw():Void super.draw();
	public function __super_destroy():Void super.destroy();
	public function __super_kill():Void super.kill();
	public function __super_revive():Void super.revive();
	public function __super_reset(x:Float, y:Float):Void super.reset(x, y);
}
