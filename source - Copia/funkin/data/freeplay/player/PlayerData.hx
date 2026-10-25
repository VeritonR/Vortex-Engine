package funkin.data.freeplay.player;

import backend.VSliceConvert;

/**
 * Only here so `funkin.data.freeplay.player.PlayerData.PlayerFreeplayDJData` leads to the class below, like on V-Slice.
 */
class PlayerData {}

/**
 * The "freeplayDJ" of a player's file as V-Slice scripts read it: who's on the turntable of the Freeplay menu and the animations it has.
 * Each animation has a `name` (what it's for: "intro", "idle", "confirm"...) and a `prefix` (what it's called on the character's images),
 * scripts ask for the prefix of a name to know which one is playing.
 */
class PlayerFreeplayDJData
{
	/**
	 * The file's own values.
	 */
	public var raw(default, null):Dynamic;

	public function new(raw:Dynamic)
	{
		this.raw = (raw != null) ? raw : {};
	}

	public var assetPath(get, never):String;
	function get_assetPath():String return VSliceConvert.str(raw.assetPath, '');

	public var renderType(get, never):String;
	function get_renderType():String return VSliceConvert.str(raw.renderType, 'animateatlas');

	public var scriptClass(get, never):String;
	function get_scriptClass():String return VSliceConvert.str(raw.scriptClass, null);

	public var useAnimatePosition(get, never):Bool;
	function get_useAnimatePosition():Bool return raw.useAnimatePosition == true;

	public var animations(get, never):Array<Dynamic>;
	function get_animations():Array<Dynamic> return VSliceConvert.list(raw.animations);

	public var atlasSettings(get, never):Dynamic;
	function get_atlasSettings():Dynamic return raw.atlasSettings;

	public function useApplyStageMatrix():Bool return raw.applyStageMatrix == true;
	public function getAtlasSettings():Dynamic return raw.atlasSettings;

	public function getGlobalOffsets():Array<Float>
	{
		return VSliceConvert.pair(raw.offsets, 0, 0);
	}

	/**
	 * The texts that go by on the back of the menu, 1 to 3.
	 */
	public function getFreeplayDJText(index:Int):String
	{
		var text:Dynamic = Reflect.field(raw, 'text$index');
		if(text != null) return Std.string(text);

		return switch(index)
		{
			case 1: 'BOYFRIEND';
			case 2: 'HOT BLOODED IN MORE WAYS THAN ONE';
			case 3: 'PROTECT YO NUTS';
			default: '';
		}
	}

	function findAnimation(name:String):Dynamic
	{
		for (animation in animations)
			if(animation != null && animation.name == name)
				return animation;
		return null;
	}

	public function getAnimationPrefix(name:String):String
	{
		var animation:Dynamic = findAnimation(name);
		return (animation != null) ? VSliceConvert.str(animation.prefix, null) : null;
	}

	/**
	 * What an animation is for, by its prefix. Null if the file has none with it.
	 */
	public function getAnimationName(prefix:String):String
	{
		for (animation in animations)
			if(animation != null && animation.prefix == prefix)
				return VSliceConvert.str(animation.name, null);
		return null;
	}

	public function getAnimationOffsets(name:String):Array<Float>
	{
		var animation:Dynamic = findAnimation(name);
		return (animation != null) ? VSliceConvert.pair(animation.offsets, 0, 0) : null;
	}

	public function getAnimationOffsetsByPrefix(?prefix:String):Array<Float>
	{
		for (animation in animations)
			if(animation != null && animation.prefix == prefix)
				return VSliceConvert.pair(animation.offsets, 0, 0);
		return [0, 0];
	}

	function fistPumpFrame(field:String, defaultValue:Int):Int
	{
		var fistPump:Dynamic = raw.fistPump;
		return (fistPump != null) ? Std.int(VSliceConvert.num(Reflect.field(fistPump, field), defaultValue)) : defaultValue;
	}

	public function getFistPumpIntroStartFrame():Int return fistPumpFrame('introStartFrame', 0);
	public function getFistPumpIntroEndFrame():Int return fistPumpFrame('introEndFrame', 0);
	public function getFistPumpLoopStartFrame():Int return fistPumpFrame('loopStartFrame', 0);
	public function getFistPumpLoopEndFrame():Int return fistPumpFrame('loopEndFrame', -1);
	public function getFistPumpIntroBadStartFrame():Int return fistPumpFrame('introBadStartFrame', 0);
	public function getFistPumpIntroBadEndFrame():Int return fistPumpFrame('introBadEndFrame', 0);
	public function getFistPumpLoopBadStartFrame():Int return fistPumpFrame('loopBadStartFrame', 0);
	public function getFistPumpLoopBadEndFrame():Int return fistPumpFrame('loopBadEndFrame', -1);

	public function getCharSelectTransitionDelay():Float
	{
		return (raw.charSelect != null) ? VSliceConvert.num(raw.charSelect.transitionDelay, 0.25) : 0.25;
	}
}
