package hxc;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * V-Slice builds flixel with fields of its own on every sprite (its `funkin.util.macro.FlxMacro`): where a sprite is inside of a
 * `FunkinGroup` (`localX`, `localY`, `localAngle`, `localScale`, `localAlpha`, `localVisible`). The group places its sprites with
 * them, and scripts set them. Added the same way here (Project.xml). (Its `zIndex` on everything is the engine's own, see
 * `hxc.HxcRuntime`.)
 */
class FlxSpriteMacro
{
	public static macro function build():Array<Field>
	{
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		var toAdd:Array<{name:String, kind:FieldType}> = [
			{name: 'localX', kind: FVar(macro :Float, macro 0)},
			{name: 'localY', kind: FVar(macro :Float, macro 0)},
			{name: 'localAngle', kind: FVar(macro :Float, macro 0)},
			{name: 'localScale', kind: FVar(macro :flixel.math.FlxPoint, macro new flixel.math.FlxPoint(1, 1))},
			{name: 'localAlpha', kind: FVar(macro :Float, macro 1)},
			{name: 'localVisible', kind: FVar(macro :Bool, macro true)}
		];
		for (added in toAdd)
		{
			if(Lambda.exists(fields, function(field) return field.name == added.name)) continue;
			fields.push({name: added.name, access: [APublic], kind: added.kind, pos: pos});
		}
		return fields;
	}

	/**
	 * Flixel 6's signals of the animations (`animation.onFinish.add(...)`, `onFrameChange`, `onLoop`), which V-Slice and its scripts
	 * use: added to flixel 5's controller, fired where it fires its callbacks (`callback`, `finishCallback` still work the same).
	 */
	public static macro function buildAnimationController():Array<Field>
	{
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		if(Lambda.exists(fields, function(field) return field.name == 'onFinish')) return fields;

		fields.push({name: 'onFrameChange', access: [APublic, AFinal], pos: pos,
			kind: FVar(macro :flixel.util.FlxSignal.FlxTypedSignal<(String, Int, Int) -> Void>, macro new flixel.util.FlxSignal.FlxTypedSignal<(String, Int, Int) -> Void>())});
		fields.push({name: 'onFinish', access: [APublic, AFinal], pos: pos,
			kind: FVar(macro :flixel.util.FlxSignal.FlxTypedSignal<String -> Void>, macro new flixel.util.FlxSignal.FlxTypedSignal<String -> Void>())});
		fields.push({name: 'onLoop', access: [APublic, AFinal], pos: pos,
			kind: FVar(macro :flixel.util.FlxSignal.FlxTypedSignal<String -> Void>, macro new flixel.util.FlxSignal.FlxTypedSignal<String -> Void>())});
		// (the frame of the animation last told: going back to an earlier one of the same animation is a loop)
		fields.push({name: '_lastToldFrame', access: [], pos: pos, kind: FVar(macro :Int, macro -1)});
		fields.push({name: '_lastToldName', access: [], pos: pos, kind: FVar(macro :String, macro null)});

		for (field in fields)
		{
			switch(field.kind)
			{
				case FFun(func) if(field.name == 'fireCallback'):
					func.expr = macro {
						var name:String = (_curAnim != null) ? _curAnim.name : null;
						var number:Int = (_curAnim != null) ? _curAnim.curFrame : frameIndex;
						if(callback != null) callback(name, number, frameIndex);
						onFrameChange.dispatch(name, number, frameIndex);
						if(name != null && name == _lastToldName && number < _lastToldFrame && _curAnim != null && _curAnim.looped) onLoop.dispatch(name);
						_lastToldName = name;
						_lastToldFrame = number;
					};
				case FFun(func) if(field.name == 'fireFinishCallback'):
					func.expr = macro {
						if(finishCallback != null) finishCallback(name);
						onFinish.dispatch(name);
					};
				case FFun(func) if(field.name == 'destroy'):
					var old = func.expr;
					func.expr = macro {
						$old;
						onFrameChange.removeAll();
						onFinish.removeAll();
						onLoop.removeAll();
					};
				default:
			}
		}
		return fields;
	}
}
#end
