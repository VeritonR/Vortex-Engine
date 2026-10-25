package funkin.play.character;

import flixel.system.FlxAssets.FlxShader;
import funkin.modding.events.ScriptEvent;
import funkin.play.character.BaseCharacter.AnimateAtlasCharacter;
import states.stages.objects.ABotSpeaker;

#if HSCRIPT_ALLOWED
import hxc.HxcRuntime;
#end

/**
 * On V-Slice this is a script of the base game (Nene, with the speaker she sits on) that mods extend for their own Nenes.
 * Here the speaker is the one the engine has for its own Nene (`ABotSpeaker`), with the names that script gives to its parts
 * so the scripts that extend it find them: `abot`, `stereoBG`, `eyeWhites`, `pupil` and `abotViz`.
 */
@:access(states.PlayState)
class NeneBaseCharacter extends AnimateAtlasCharacter
{
	public var abot:ABotProxy = null;
	public var abotViz:ABotVizProxy = null;
	public var stereoBG:FlxSprite = null;
	public var eyeWhites:FlxSprite = null;
	public var pupil:FlxSprite = null;

	public var hasSetupAbot:Bool = false;
	public var currentShader:FlxShader = null;

	var speaker:ABotSpeaker = null;

	public function new(id:String, ?renderType:Dynamic)
	{
		super((id == 'UNKNOWN') ? 'nene' : id, renderType);
	}

	override public function onCreate(event:ScriptEvent):Void
	{
		super.onCreate(event);
		if(character == null || speaker != null) return;

		// the speaker's images are the ones of the base game's Weekend 1, mods only replace what they change
		if(!backend.Paths.fileExists('images/abot/stereoBG.png', IMAGE, false, 'weekend1')
			&& !backend.Paths.fileExists('images/abot/stereoBG.png', IMAGE))
		{
			#if HSCRIPT_ALLOWED
			backend.VSliceScripts.warn('The images of the speaker of "$characterId" (images/abot) were not found, it is not shown');
			#end
			return;
		}

		var oldLevel:String = backend.Paths.currentLevel;
		backend.Paths.currentLevel = 'weekend1';
		try
		{
			speaker = new ABotSpeaker(0, 0);
		}
		catch(e:Dynamic)
		{
			speaker = null;
			#if HSCRIPT_ALLOWED
			backend.VSliceScripts.warn('The speaker of "$characterId" could not be made: $e');
			#end
		}
		backend.Paths.currentLevel = oldLevel;
		if(speaker == null) return;

		abot = new ABotProxy(speaker);
		abotViz = new ABotVizProxy(speaker);
		stereoBG = speaker.bg;
		eyeWhites = speaker.eyeBg;
		pupil = speaker.eyes;

		// behind the character
		var game:states.PlayState = states.PlayState.instance;
		if(game != null)
		{
			var front:flixel.FlxBasic = character;
			for (group in [game.gfGroup, game.dadGroup, game.boyfriendGroup])
				if(group != null && group.members.contains(character))
					front = group;

			var index:Int = game.members.indexOf(front);
			if(index > -1) game.insert(index, speaker);
			else game.add(speaker);
		}
	}

	override public function onUpdate(event:UpdateScriptEvent):Void
	{
		super.onUpdate(event);
		if(speaker == null || character == null) return;

		speaker.visible = character.visible;

		// these two are what scripts change, so they go through the script
		#if HSCRIPT_ALLOWED
		if(!hasSetupAbot) HxcRuntime.call(this, 'setupAbot');
		HxcRuntime.call(this, 'synchronizeShader');
		#else
		if(!hasSetupAbot) setupAbot();
		synchronizeShader();
		#end
	}

	/**
	 * Puts the speaker under the character.
	 */
	public function setupAbot():Void
	{
		hasSetupAbot = true;
		if(speaker == null || character == null) return;

		// V-Slice places it from the top left corner of the character: (-95, 384). Psych's characters don't have theirs on the same spot
		// (texture atlases aren't drawn from it), so the area her pose takes is used
		var left:Float = character.x;
		var top:Float = character.y;
		if(character.cornerPosition)
		{
			// its position is the same corner V-Slice has, the script's own numbers: moved by the offsets of the character's file as well
			left += character.positionArray[0] * character.scale.x;
			top += character.positionArray[1] * character.scale.y;
		}

		var bounds:flixel.math.FlxRect = #if flxanimate (character.cornerPosition ? null : character.getAtlasBounds()) #else null #end;
		if(bounds != null)
		{
			left += bounds.x;
			top += bounds.y;
			bounds.put();
		}

		// the speaker itself is 65 to the left and 10 above the engine's whole group
		speaker.setPosition(left - 95 + 65, top + 384 + 10);

		// what scripts give to `abot.x` and `abot.y` is counted from where V-Slice's script would have put it
		abot.originX = speaker.x - (character.x - 95 + character.positionArray[0] * character.scale.x);
		abot.originY = speaker.y - (character.y + 384 + character.positionArray[1] * character.scale.y);
	}

	/**
	 * The speaker gets the shader of the character, stages give theirs to the characters only.
	 */
	public function synchronizeShader():Void
	{
		if(speaker == null || character == null || currentShader == character.shader) return;

		currentShader = character.shader;
		abot.shader = currentShader;
		abotViz.shader = currentShader;
		stereoBG.shader = currentShader;
		eyeWhites.shader = currentShader;
	}

	override public function onSongStart(event:ScriptEvent):Void
	{
		super.onSongStart(event);

		// it moves to the song from here on
		if(speaker != null && FlxG.sound.music != null) speaker.snd = FlxG.sound.music;
	}

	// The eyes look at who the camera goes to
	override public function onSongEvent(event:SongEventScriptEvent):Void
	{
		super.onSongEvent(event);
		if(speaker == null || event.eventData == null || event.eventData.eventKind != 'FocusCamera') return;

		var char:Null<Int> = event.eventData.getInt('char');
		if(char == null && Std.isOfType(event.eventData.value, Float)) char = Std.int(event.eventData.value);

		if(char == 1) speaker.lookLeft();
		else if(char == 0) speaker.lookRight();
	}
}

/**
 * The speaker as `abot`, V-Slice's is a single texture atlas.
 */
class ABotProxy
{
	public var speaker(default, null):ABotSpeaker;

	// Where the engine's speaker is when V-Slice's would be at (0, 0)
	public var originX:Float = 0;
	public var originY:Float = 0;

	public var zIndex:Int = 0;

	public function new(speaker:ABotSpeaker)
	{
		this.speaker = speaker;
	}

	public var x(get, set):Float;
	function get_x():Float return speaker.x - originX;
	function set_x(value:Float):Float
	{
		speaker.x = value + originX;
		return value;
	}

	public var y(get, set):Float;
	function get_y():Float return speaker.y - originY;
	function set_y(value:Float):Float
	{
		speaker.y = value + originY;
		return value;
	}

	public var visible(get, set):Bool;
	function get_visible():Bool return speaker.visible;
	function set_visible(value:Bool):Bool return speaker.visible = value;

	public var alpha(get, set):Float;
	function get_alpha():Float return speaker.alpha;
	function set_alpha(value:Float):Float return speaker.alpha = value;

	public var shader(get, set):FlxShader;
	function get_shader():FlxShader return speaker.speaker.shader;
	function set_shader(value:FlxShader):FlxShader
	{
		speaker.speaker.shader = value;
		speaker.eyes.shader = value;
		return value;
	}

	/**
	 * Changes the speaker's looks to another texture atlas with the same animation.
	 */
	public function loadTextureAtlas(path:String, ?library:String, ?settings:Dynamic):ABotProxy
	{
		var colon:Int = path.indexOf(':');
		if(colon > -1) path = path.substr(colon + 1);

		try
		{
			backend.Paths.loadAnimateAtlas(speaker.speaker, path);
			speaker.speaker.anim.addBySymbol('anim', 'Abot System', 24, false);
			speaker.speaker.anim.play('anim', true);
			speaker.speaker.anim.curFrame = speaker.speaker.anim.length - 1;
		}
		catch(e:Dynamic)
		{
			#if HSCRIPT_ALLOWED
			backend.VSliceScripts.warn('The speaker\'s texture atlas "$path" could not be loaded: $e');
			#end
		}
		return this;
	}
}

/**
 * The bars of the speaker as `abotViz`, a group on V-Slice.
 */
class ABotVizProxy
{
	var speaker:ABotSpeaker;

	public var x:Float = 0;
	public var y:Float = 0;
	public var zIndex:Int = 0;

	public function new(speaker:ABotSpeaker)
	{
		this.speaker = speaker;
	}

	public var members(get, never):Array<FlxSprite>;
	function get_members():Array<FlxSprite> return speaker.vizSprites;

	public var shader(get, set):FlxShader;
	function get_shader():FlxShader return (speaker.vizSprites.length > 0) ? speaker.vizSprites[0].shader : null;
	function set_shader(value:FlxShader):FlxShader
	{
		for (sprite in speaker.vizSprites)
			sprite.shader = value;
		return value;
	}

	public var alpha(get, set):Float;
	function get_alpha():Float return (speaker.vizSprites.length > 0) ? speaker.vizSprites[0].alpha : 1;
	function set_alpha(value:Float):Float return value; //V-Slice's starts hidden, this one is drawn by the speaker itself

	public var visible(get, set):Bool;
	function get_visible():Bool return (speaker.vizSprites.length > 0 && speaker.vizSprites[0].visible);
	function set_visible(value:Bool):Bool
	{
		for (sprite in speaker.vizSprites)
			sprite.visible = value;
		return value;
	}
}
