package funkin.ui;

#if HSCRIPT_ALLOWED
import hxc.HxcInstance;
import hxc.HxcRuntime.IHxcScripted;
#end

/**
 * The state a script class is given when it extends one (`class MyMenu extends MusicBeatState`): a menu of its own, that the mod
 * opens with `FlxG.switchState(new MyMenu())`. What the script overrides of `create`, `update`, `draw`, `destroy`, `stepHit`, `beatHit`,
 * `openSubState`, `closeSubState`, `onFocus` and `onFocusLost` is run by the engine like on a real class.
 * A state made any other way is the engine's own, see `hxc.HxcRuntime.scriptedBases`.
 */
class ScriptedState extends backend.MusicBeatState #if HSCRIPT_ALLOWED implements IHxcScripted #end
{
	#if HSCRIPT_ALLOWED
	public var __hxc:HxcInstance = null;
	#end

	// Runs the script's version of a function, returns false if there's no script, it doesn't have one, or it's what's asking for the state's own
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

	// A mod's own screen: its files are the ones it finds for as long as it's open, like when one of its songs is being played
	// (on V-Slice the files of every mod are found from anywhere, here it's those of the mod that's set as the current one)
	var __lastMod:String = null;
	var __modSet:Bool = false;

	function enterMod():Void
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		var mod:String = backend.VSliceScripts.modOf(__hxc);
		if(mod == null || __modSet) return;

		__lastMod = Mods.currentModDirectory;
		__modSet = true;
		Mods.currentModDirectory = mod;
		#end
	}

	function leaveMod():Void
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		if(!__modSet) return;

		__modSet = false;
		Mods.currentModDirectory = __lastMod;
		#end
	}

	override function create():Void
	{
		enterMod();
		if(!callScript('create')) super.create();
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
		leaveMod();
	}

	override public function stepHit():Void
	{
		if(!callScript('stepHit')) super.stepHit();
	}

	override public function beatHit():Void
	{
		if(!callScript('beatHit')) super.beatHit();
	}

	override function openSubState(SubState:flixel.FlxSubState):Void
	{
		if(!callScript('openSubState', [SubState])) super.openSubState(SubState);
	}

	override function closeSubState():Void
	{
		if(!callScript('closeSubState')) super.closeSubState();
	}

	override function onFocus():Void
	{
		if(!callScript('onFocus')) super.onFocus();
	}

	override function onFocusLost():Void
	{
		if(!callScript('onFocusLost')) super.onFocusLost();
	}

	// What `super.create()` and the others run when called from a script
	public function __super_create():Void super.create();
	public function __super_update(elapsed:Float):Void super.update(elapsed);
	public function __super_draw():Void super.draw();
	public function __super_destroy():Void super.destroy();
	public function __super_stepHit():Void super.stepHit();
	public function __super_beatHit():Void super.beatHit();
	public function __super_openSubState(SubState:flixel.FlxSubState):Void super.openSubState(SubState);
	public function __super_closeSubState():Void super.closeSubState();
	public function __super_onFocus():Void super.onFocus();
	public function __super_onFocusLost():Void super.onFocusLost();
}

/**
 * The same for the substates: `class MyWindow extends MusicBeatSubState`, opened with `openSubState(new MyWindow())`.
 */
class ScriptedSubState extends backend.MusicBeatSubstate #if HSCRIPT_ALLOWED implements IHxcScripted #end
{
	#if HSCRIPT_ALLOWED
	public var __hxc:HxcInstance = null;
	#end

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

	// A mod's own screen: its files are the ones it finds for as long as it's open, like when one of its songs is being played
	// (on V-Slice the files of every mod are found from anywhere, here it's those of the mod that's set as the current one)
	var __lastMod:String = null;
	var __modSet:Bool = false;

	function enterMod():Void
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		var mod:String = backend.VSliceScripts.modOf(__hxc);
		if(mod == null || __modSet) return;

		__lastMod = Mods.currentModDirectory;
		__modSet = true;
		Mods.currentModDirectory = mod;
		#end
	}

	function leaveMod():Void
	{
		#if (HSCRIPT_ALLOWED && MODS_ALLOWED)
		if(!__modSet) return;

		__modSet = false;
		Mods.currentModDirectory = __lastMod;
		#end
	}

	override function create():Void
	{
		enterMod();
		if(!callScript('create')) super.create();
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
		leaveMod();
	}

	override function close():Void
	{
		if(!callScript('close')) super.close();
	}

	override public function stepHit():Void
	{
		if(!callScript('stepHit')) super.stepHit();
	}

	override public function beatHit():Void
	{
		if(!callScript('beatHit')) super.beatHit();
	}

	override function openSubState(SubState:flixel.FlxSubState):Void
	{
		if(!callScript('openSubState', [SubState])) super.openSubState(SubState);
	}

	override function closeSubState():Void
	{
		if(!callScript('closeSubState')) super.closeSubState();
	}

	override function onFocus():Void
	{
		if(!callScript('onFocus')) super.onFocus();
	}

	override function onFocusLost():Void
	{
		if(!callScript('onFocusLost')) super.onFocusLost();
	}

	public function __super_create():Void super.create();
	public function __super_update(elapsed:Float):Void super.update(elapsed);
	public function __super_draw():Void super.draw();
	public function __super_destroy():Void super.destroy();
	public function __super_close():Void super.close();
	public function __super_stepHit():Void super.stepHit();
	public function __super_beatHit():Void super.beatHit();
	public function __super_openSubState(SubState:flixel.FlxSubState):Void super.openSubState(SubState);
	public function __super_closeSubState():Void super.closeSubState();
	public function __super_onFocus():Void super.onFocus();
	public function __super_onFocusLost():Void super.onFocusLost();
}
