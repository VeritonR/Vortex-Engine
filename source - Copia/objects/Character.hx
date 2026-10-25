package objects;

import backend.animation.PsychAnimationController;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

import backend.Song;
import states.stages.objects.TankmenBG;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var _editor_isPlayer:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite
{
	/**
	 * In case a character is missing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;

	/**
	 * A long note makes the character sing its note again on each of its pieces (one per step), which on fast songs is every
	 * couple of frames of the animation: it's done again only once it showed this much of it (in seconds).
	 */
	public static var HOLD_REPEAT_TIME:Float = 0.125;
	var singAnimationTime:Float = 0;

	public function canRestartForHold():Bool
		return singAnimationTime >= HOLD_REPEAT_TIME || isAnimationFinished();
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';
	public var isVSlice:Bool = false; //Converted from a V-Slice (Polymod) mod, PlayState places these by their feet

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		animOffsets = new Map<String, Array<Dynamic>>();
		this.isPlayer = isPlayer;
		changeCharacter(character);
		
		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	/**
	 * If there's a character with this name: a Psych file, one of a V-Slice mod or one of V-Slice's base game.
	 */
	public static function characterExists(character:String):Bool
	{
		if(character == null || character.trim().length < 1) return false;
		#if MODS_ALLOWED
		if(FileSystem.exists(Paths.getPath('characters/$character.json', TEXT))) return true;
		return PolymodCompat.getCharacterFile(character, false) != null || PolymodCompat.getBaseCharacterFile(character, false) != null;
		#else
		return Assets.exists(Paths.getPath('characters/$character.json', TEXT));
		#end
	}

	public function changeCharacter(character:String)
	{
		animationsArray = [];
		animOffsets = [];
		curCharacter = character;
		var characterPath:String = 'characters/$character.json';

		var path:String = Paths.getPath(characterPath, TEXT);

		// Characters of a Polymod mod come in the V-Slice format, they get converted to the same data a Psych .json has
		var vsliceFile:Dynamic = null;
		#if MODS_ALLOWED
		vsliceFile = PolymodCompat.getCharacterFile(character, isPlayer);

		// one the mod and the engine don't have, from V-Slice's base game
		if(vsliceFile == null && !FileSystem.exists(path)) vsliceFile = PolymodCompat.getBaseCharacterFile(character, isPlayer);
		#end
		isVSlice = (vsliceFile != null);

		#if MODS_ALLOWED
		if (!isVSlice && !FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
			missingCharacter = true;
			missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16);
			missingText.alignment = CENTER;
		}

		try
		{
			#if MODS_ALLOWED
			loadCharacterFile(isVSlice ? vsliceFile : Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		}
		catch(e:Dynamic)
		{
			trace('Error loading character file of "$character": $e');
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
		recalculateDanceIdle();
		dance();

		// (the size of a V-Slice texture atlas is the one of what it's playing, which is its idle now)
		if(cornerPosition) updateHitbox();
	}

	public function loadCharacterFile(json:Dynamic)
	{
		isAnimateAtlas = false;
		cornerPosition = false;
		hitboxOffsetX = 0;
		hitboxOffsetY = 0;
		#if flxanimate
		destroyExtraAtlases();
		#end

		#if flxanimate
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
		var vsliceAtlas:Dynamic = Reflect.field(json, 'vsliceAtlas');
		if (vsliceAtlas != null) isAnimateAtlas = (vsliceAtlas == true);
		else if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;
		#end

		scale.set(1, 1);
		updateHitbox();

		if(!isAnimateAtlas)
		{
			frames = Paths.getMultiAtlas(json.image.split(','));
		}
		#if flxanimate
		else
		{
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(atlas, json.image);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load atlas ${json.image}: $e');
				trace(e.stack);
			}
			mainAtlas = atlas;

			// V-Slice's texture atlases are placed and flipped by the box of what they play: see `cornerPosition`
			if(isVSlice)
			{
				cornerPosition = true;
				atlasOnDocument = (Reflect.field(json, 'applyStageMatrix') == true);
				useRenderTexture = (Reflect.field(json, 'useRenderTexture') == true);
				atlas.labelsOnDocument = atlasOnDocument;
			}
		}
		#end

		// (see `cornerPosition`)
		if(isVSlice) cornerPosition = true;

		imageFile = json.image;
		jsonScale = json.scale;
		if(json.scale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		// positioning
		positionArray = json.position;
		cameraPosition = json.camera_position;

		// data
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop; //Bruh
				var animIndices:Array<Int> = anim.indices;

				if(!isAnimateAtlas)
				{
					// (V-Slice characters can have animations mirrored on their own)
					var animFlipX:Bool = (Reflect.field(anim, 'flipX') == true);
					var animFlipY:Bool = (Reflect.field(anim, 'flipY') == true);
					if(animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop, animFlipX, animFlipY);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop, animFlipX, animFlipY);
				}
				#if flxanimate
				else
				{
					// Animations that are on another atlas (V-Slice's "multianimateatlas" characters): the character has one more atlas for each,
					// and shows the one that has what it's playing
					var target:FlxAnimate = atlas;
					var otherImage:String = Reflect.field(anim, 'atlas');
					if(otherImage != null && otherImage.length > 0 && otherImage != json.image)
					{
						target = getExtraAtlas(otherImage);
						if(target == null) continue; //its files weren't found: the character doesn't have the animation
						animationAtlases.set(animAnim, target);
					}

					// V-Slice atlases have their animations as frame labels of the main timeline instead of one symbol for each
					var isFrameLabel:Bool = (Reflect.field(anim, 'frameLabel') == true) || (!target.hasSymbol(animName) && target.hasFrameLabel(animName));
					if(isFrameLabel && target.addAnimByFrameLabel(animAnim, animName, animFps, animLoop, animIndices))
					{
						//added as a frame label
					}
					else if(animIndices != null && animIndices.length > 0)
					{
						target.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
						target.animationSources.set(animAnim, animName);
					}
					else
						target.anim.addBySymbol(animAnim, flxanimate.PsychFlxAnimate.symbolQuery(target.anim, animName), animFps, animLoop);
				}
				#end

				if(anim.offsets != null && anim.offsets.length > 1) addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else addOffset(anim.anim, 0, 0);
			}
		}
		#if flxanimate
		if(isAnimateAtlas) copyAtlasValues();
		#end
		//trace('Loaded file to character ' + curCharacter);
	}

	/**
	 * Functions of the character that the V-Slice script attached to it has its own version of (see backend.VSliceScripts.loadCharacterScripts()),
	 * out of the ones that are sent to it: "update", "dance" and "playAnimation". Null for everyone else.
	 */
	public var scriptOverrides:Array<String> = null;

	// What playAnim() was asked for when it goes through the script's `playAnimation()`, which doesn't know about either
	var _engineAnimation:Bool = false;
	var _engineFrame:Int = 0;

	override function update(elapsed:Float)
	{
		singAnimationTime += elapsed * (FlxG.animationTimeScale);
		#if HSCRIPT_ALLOWED
		if(scriptOverrides != null && scriptOverrides.contains('update') && backend.VSliceScripts.callOverride(this, 'update', [elapsed])) return;
		#end

		if(isAnimateAtlas) atlas.update(elapsed);

		if(debugMode || (!isAnimateAtlas && animation.curAnim == null) || (isAnimateAtlas && (atlas.anim.curInstance == null || atlas.anim.curSymbol == null)))
		{
			super.update(elapsed);
			return;
		}

		if(heyTimer > 0)
		{
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if(heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if(specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if(specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if(isAnimationFinished() && hasAnimation('$name-loop'))
			playAnim('$name-loop');

		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
	{
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curInstance == null || atlas.anim.curSymbol == null);
	}

	var _lastPlayedAnimation:String;
	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.curFrame = atlas.anim.length - 1;
	}

	public function hasAnimation(anim:String):Bool
	{
		return animOffsets.exists(anim);
	}

	// ------------------------------------------------------------------------------------------
	// Names V-Slice scripts know these things by, see backend.VSliceScripts
	// ------------------------------------------------------------------------------------------

	public var characterId(get, never):String;
	function get_characterId():String return curCharacter;

	public var characterName(get, never):String;
	function get_characterName():String return curCharacter;

	/**
	 * Which place it takes on the song: "bf", "dad", "gf" or "other" (the values of V-Slice's `CharacterType`).
	 */
	public var characterType:String = 'other';

	/**
	 * The offsets of the character's file.
	 */
	public var globalOffsets(get, never):Array<Float>;
	function get_globalOffsets():Array<Float> return positionArray;

	/**
	 * Where the stage put it, `resetCharacter()` takes it back there.
	 */
	public var homePosition:FlxPoint = null;

	/**
	 * Puts the character back where it started, dancing.
	 */
	public function resetCharacter(resetCamera:Bool = true):Void
	{
		if(homePosition != null) setPosition(homePosition.x, homePosition.y);

		specialAnim = false;
		holdTimer = 0;
		heyTimer = 0;
		dance();
	}

	/**
	 * Layer on V-Slice stages, only kept for the scripts that read it.
	 */
	public var zIndex:Int = 0;

	// False while an animation that asked not to be interrupted is playing, which is Psych's `specialAnim`
	public var canPlayOtherAnims(get, set):Bool;
	function get_canPlayOtherAnims():Bool return !specialAnim;
	function set_canPlayOtherAnims(value:Bool):Bool
	{
		specialAnim = !value;
		return value;
	}

	/**
	 * Animations (by how their names start) that scripts can play over one that asked not to be interrupted.
	 */
	public var ignoreExclusionPref:Array<String> = ['sing'];

	public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
	{
		name = correctAnimationName(name);
		if(name == null) return;

		// (the ones the engine itself plays were already decided by it: see playAnim())
		var frame:Int = 0;
		if(_engineAnimation)
		{
			frame = _engineFrame;
			_engineAnimation = false;
			_engineFrame = 0;
		}
		else if(specialAnim && !(restart && getCurrentAnimation() == name))
		{
			var allowed:Bool = false;
			if(ignoreExclusionPref != null)
				for (entry in ignoreExclusionPref)
					if(name.startsWith(entry))
						allowed = true;
			if(!allowed) return;
		}

		playAnim(name, restart, reversed, frame);
		if(ignoreOther) specialAnim = true; //nothing else gets to play until it's over
	}

	/**
	 * Makes the icon of a side of the health bar this character's (V-Slice's `BaseCharacter.initHealthIcon()`, which scripts call
	 * after putting a character in the place of another).
	 */
	public function initHealthIcon(isOpponent:Bool):Void
	{
		var game:states.PlayState = states.PlayState.instance;
		if(game == null) return;

		var icon:HealthIcon = isOpponent ? game.iconP2 : game.iconP1;
		if(icon != null && healthIcon != null) icon.changeIcon(healthIcon);
	}

	/**
	 * The animation that's played when this one is asked for: itself if the character has it, otherwise the same name without
	 * what comes after its last dash, as many times as it takes ("singLEFT-alt" plays "singLEFT"). Null if there's none.
	 * It's V-Slice's rule (`Bopper.correctAnimationName()`), and its scripts count on it: the bloody Tankman asks for all of
	 * his animations with "-bloody" at the end, the ones he only has without it included.
	 */
	public function correctAnimationName(name:String):String
	{
		while(name != null && !hasAnimation(name))
		{
			var dash:Int = name.lastIndexOf('-');
			if(dash < 0) return null;
			name = name.substring(0, dash);
		}
		return name;
	}

	/**
	 * Plays the animation of singing to a direction (0 to 3: left, down, up and right), or of missing it.
	 */
	public function playSingAnimation(dir:Dynamic, miss:Bool = false, ?suffix:String = ''):Void
	{
		var names:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
		var index:Int = Std.isOfType(dir, Int) ? dir : names.indexOf('sing' + Std.string(dir).toUpperCase());
		if(index < 0 || index >= names.length) return;

		// (V-Slice gives the suffix without its dash: "singLEFT-(suffix)")
		if(suffix == null) suffix = '';
		if(suffix.length > 0 && !suffix.startsWith('-')) suffix = '-' + suffix;

		var name:String = names[index] + (miss ? 'miss' : '') + suffix;
		if(!hasAnimation(name)) return;

		playAnim(name, true);
		holdTimer = 0;
	}

	public function isSinging():Bool
	{
		return getCurrentAnimation().startsWith('sing');
	}

	// More of V-Slice's names for what Psych's characters call something else

	public var debug(get, set):Bool;
	function get_debug():Bool return debugMode;
	function set_debug(value:Bool):Bool return debugMode = value;

	public var hasDanced(get, set):Bool;
	function get_hasDanced():Bool return danced;
	function set_hasDanced(value:Bool):Bool return danced = value;

	// Beats between each time the character dances, 0 to not do it by itself
	public var danceEvery(get, set):Float;
	function get_danceEvery():Float return skipDance ? 0 : danceEveryNumBeats;
	function set_danceEvery(value:Float):Float
	{
		skipDance = (value <= 0);
		if(value > 0) danceEveryNumBeats = Std.int(Math.max(1, Math.round(value)));
		return value;
	}

	public var shouldBop:Bool = true;

	/**
	 * The stage the character is on, as V-Slice scripts know it. Null outside of the songs of V-Slice mods.
	 */
	public var currentStage(get, never):funkin.play.stage.Stage;
	function get_currentStage():funkin.play.stage.Stage
	{
		var game:funkin.play.PlayState = funkin.play.PlayState.instance;
		return (game != null) ? game.currentStage : null;
	}

	public var originalPosition(get, set):FlxPoint;
	function get_originalPosition():FlxPoint
	{
		if(homePosition == null) homePosition = FlxPoint.get(x, y);
		return homePosition;
	}
	function set_originalPosition(value:FlxPoint):FlxPoint
	{
		if(value == null) return homePosition;
		if(homePosition == null) homePosition = FlxPoint.get();
		homePosition.set(value.x, value.y);
		return homePosition;
	}

	public function resetPosition():Void
	{
		if(homePosition != null) setPosition(homePosition.x, homePosition.y);
	}

	/**
	 * Where the character's feet are: the bottom center of its box.
	 */
	public var feetPosition(get, never):FlxPoint;
	function get_feetPosition():FlxPoint
	{
		var feet:FlxPoint = characterOrigin;
		feet.add(x, y);
		return feet;
	}

	/**
	 * The scale the character's file gives it, before what a stage or a script does to it.
	 */
	public function getBaseScale():Float
	{
		return jsonScale;
	}

	// If its file has it facing the other way
	public function getDataFlipX():Bool
	{
		return originalFlipX;
	}

	/**
	 * Makes the character bigger or smaller with its feet staying where they are. The same function V-Slice's characters have,
	 * which also moves them by the offsets of their file every time it's used: scripts count on that.
	 */
	public function setScale(?value:Null<Float>):Void
	{
		if(value == null) value = 1.0;

		var feet:FlxPoint = feetPosition;
		var before:Float = scale.x;
		scale.set(value, value);

		// V-Slice's animation offsets grow along with the character, here they were given their size when the file was loaded
		if(isVSlice && before != 0 && before != value)
		{
			var ratio:Float = value / before;
			for (name => offsets in animOffsets)
			{
				offsets[0] = offsets[0] * ratio;
				offsets[1] = offsets[1] * ratio;
			}
		}

		if(cornerPosition)
		{
			updateHitbox(); //(the others have no size to update: their sprite grows from its middle, see PlayState's `positionCharacterByFeet()`)
			applyAnimationOffset();
		}

		var feetNow:FlxPoint = characterOrigin;
		x = feet.x - feetNow.x + (isVSlice ? positionArray[0] : 0);
		y = feet.y - feetNow.y + (isVSlice ? positionArray[1] : 0);
	}

	/**
	 * The frames of the symbols of the character's texture atlas that have something on their name, for scripts to put things on them
	 * (see funkin.graphics.SpriteElement). None for the characters that aren't an atlas.
	 */
	public function getFramesWithKeyword(keyword:String):Array<Dynamic>
	{
		var found:Array<Dynamic> = [];
		#if flxanimate
		if(isAnimateAtlas)
			for (each in getAtlases())
				for (keyFrame in each.getFramesWithKeyword(keyword))
					found.push(keyFrame);
		#end
		return found;
	}

	// More of what V-Slice scripts ask of a character

	public var isPixel(get, never):Bool;
	function get_isPixel():Bool return noAntialiasing;

	public var isDead:Bool = false;
	public var tempVocals:Bool = false;
	public var curNoteKind:Dynamic = null;
	public var comboNoteCounts:Array<Int> = [];
	public var dropNoteCounts:Array<Int> = [];

	// If the character dances between "danceLeft" and "danceRight" (V-Slice's name for it; scripts turn it on for another dance)
	public var shouldAlternate(get, set):Bool;
	function get_shouldAlternate():Bool return danceIdle;
	function set_shouldAlternate(value:Bool):Bool return danceIdle = value;

	public function getHealthIconId():String
	{
		return healthIcon;
	}

	public function listAnimations():Array<String>
	{
		return [for (name in animOffsets.keys()) name];
	}

	// If an animation is more than a single frame
	public function isAnimationDynamic(id:String):Bool
	{
		if(!hasAnimation(id)) return false;
		if(isAnimateAtlas) return true;

		var data = animation.getByName(id);
		return data != null && data.numFrames > 1;
	}

	public function resetCameraFocusPoint():Void {}

	/**
	 * The offsets of the animations as V-Slice has them: counted before the character's scale and the offsets of its file.
	 */
	public var animationOffsets(get, never):Map<String, Array<Float>>;
	function get_animationOffsets():Map<String, Array<Float>>
	{
		var list:Map<String, Array<Float>> = [];
		for (name => offsets in animOffsets)
			list.set(name, fromEngineOffset(offsets[0], offsets[1]));
		return list;
	}

	function fromEngineOffset(offsetX:Float, offsetY:Float):Array<Float>
	{
		if(!isVSlice) return [offsetX, offsetY];
		return [((scale.x != 0) ? offsetX / scale.x : offsetX) + positionArray[0], ((scale.y != 0) ? offsetY / scale.y : offsetY) + positionArray[1]];
	}

	public function setAnimationOffsets(name:String, xOffset:Float, yOffset:Float):Void
	{
		if(isVSlice)
		{
			// (see backend.VSliceConvert.convertCharacter())
			xOffset = (xOffset - positionArray[0]) * scale.x;
			yOffset = (yOffset - positionArray[1]) * scale.y;
		}
		addOffset(name, xOffset, yOffset);
		if(name == _lastPlayedAnimation) applyAnimationOffset();
	}

	// The offset of the animation that's playing, as the sprite's
	function applyAnimationOffset():Void
	{
		var offsets:Array<Dynamic> = (_lastPlayedAnimation != null) ? animOffsets.get(_lastPlayedAnimation) : null;
		if(offsets == null) return;

		offset.set(offsets[0], offsets[1]);
		if(cornerPosition && !isAnimateAtlas) offset.add(hitboxOffsetX, hitboxOffsetY);
	}

	// ------------------------------------------------------------------------------------------
	// Setters V-Slice scripts have their own version of
	// ------------------------------------------------------------------------------------------

	#if HSCRIPT_ALLOWED
	// (the "dark" characters of the base game show another character under them as their alpha changes, which a stage does with a tween)
	inline function scriptSets(name:String, value:Dynamic):Bool
	{
		return scriptOverrides != null && scriptOverrides.contains(name) && backend.VSliceScripts.callOverride(this, name, [value]);
	}

	override function set_alpha(value:Float):Float
	{
		return scriptSets('set_alpha', value) ? alpha : super.set_alpha(value);
	}

	override function set_visible(value:Bool):Bool
	{
		return scriptSets('set_visible', value) ? visible : super.set_visible(value);
	}

	override function set_x(value:Float):Float
	{
		return scriptSets('set_x', value) ? x : super.set_x(value);
	}

	override function set_y(value:Float):Float
	{
		return scriptSets('set_y', value) ? y : super.set_y(value);
	}

	override function set_angle(value:Float):Float
	{
		return scriptSets('set_angle', value) ? angle : super.set_angle(value);
	}

	override function set_color(value:FlxColor):Int
	{
		return scriptSets('set_color', value) ? color : super.set_color(value);
	}
	#end

	var forcedAnimationTimer:FlxTimer = null;

	/**
	 * Plays an animation that nothing else gets to interrupt for some seconds.
	 */
	public function forceAnimationForDuration(name:String, duration:Float):Void
	{
		if(!hasAnimation(name)) return;

		if(forcedAnimationTimer != null) forcedAnimationTimer.cancel();
		playAnim(name, true);
		specialAnim = true;
		heyTimer = 0;

		forcedAnimationTimer = new FlxTimer().start(duration, function(_)
		{
			forcedAnimationTimer = null;
			if(!exists || getAnimationName() != name) return;

			specialAnim = false;
			dance();
		});
	}

	/**
	 * Where the character's feet are, from its position: the spot V-Slice's stages place characters by.
	 */
	public var characterOrigin(get, never):FlxPoint;
	function get_characterOrigin():FlxPoint
	{
		if(cornerPosition) return new FlxPoint(width / 2, height); //the same V-Slice has

		#if flxanimate
		var bounds:flixel.math.FlxRect = getAtlasBounds();
		if(bounds != null)
		{
			var point:FlxPoint = new FlxPoint(bounds.x + bounds.width / 2, bounds.y + bounds.height);
			bounds.put();
			return point;
		}
		#end
		return new FlxPoint(frameWidth / 2, frameHeight * (1 + scale.y) / 2);
	}

	public function getCurrentAnimation():String
	{
		return (_lastPlayedAnimation != null) ? _lastPlayedAnimation : '';
	}

	/**
	 * Where the camera goes when it's on this character, without the stage's own offsets.
	 */
	public var cameraFocusPoint(get, never):FlxPoint;
	function get_cameraFocusPoint():FlxPoint
	{
		var game:PlayState = PlayState.instance;
		var point:FlxPoint = getCameraCenter();
		if(game != null && this == game.gf)
		{
			point.x += cameraPosition[0] + game.girlfriendCameraOffset[0];
			point.y += cameraPosition[1] + game.girlfriendCameraOffset[1];
			return point;
		}

		// the same PlayState does when it moves the camera to the player or to the opponent
		var stageOffset:Array<Float> = (game == null) ? null : (isPlayer ? game.boyfriendCameraOffset : game.opponentCameraOffset);
		point.x += isPlayer ? -100 - cameraPosition[0] : 150 + cameraPosition[0];
		point.y += -100 + cameraPosition[1];
		if(stageOffset != null)
		{
			point.x += stageOffset[0];
			point.y += stageOffset[1];
		}
		return point;
	}

	/**
	 * For V-Slice characters: where the middle of the character is, counted from its position. PlayState sets it when it places the character.
	 *
	 * On V-Slice a character is a box that goes up from its feet, and the camera looks at the middle of that box.
	 * The sprite's own middle isn't the same spot here: texture atlases have no size of their own (they're drawn around their position,
	 * not from it), and the other sprites keep the size of the frame they were loaded with.
	 */
	public var focusOffset:FlxPoint = null;

	/**
	 * The point the camera's position on this character is counted from: its middle.
	 */
	public function getCameraCenter():FlxPoint
	{
		if(focusOffset == null) return getMidpoint();
		return FlxPoint.get(x + focusOffset.x, y + focusOffset.y);
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.paused : atlas.anim.isPlaying;
	}
	private function set_animPaused(value:Bool):Bool
	{
		if(isAnimationNull()) return value;
		if(!isAnimateAtlas) animation.curAnim.paused = value;
		else
		{
			if(value) atlas.pauseAnimation();
			else atlas.resumeAnimation();
		}

		return value;
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(force:Bool = false)
	{
		#if HSCRIPT_ALLOWED
		// V-Slice characters whose script has its own way of dancing: the engine still says when
		if(!debugMode && !skipDance && scriptOverrides != null && scriptOverrides.contains('dance') && backend.VSliceScripts.callOverride(this, 'dance', [force])) return;
		#end

		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix, force);
				else
					playAnim('danceLeft' + idleSuffix, force);
			}
			else if(hasAnimation('idle' + idleSuffix))
				playAnim('idle' + idleSuffix, force);
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		#if HSCRIPT_ALLOWED
		// On V-Slice everything a character plays goes through `playAnimation()`, which scripts replace to change, follow or stop it.
		// Its own version ends up back here (see backend.VSliceScripts.callOverride())
		if(scriptOverrides != null && scriptOverrides.contains('playAnimation'))
		{
			_engineAnimation = true;
			_engineFrame = Frame;
			var done:Bool = backend.VSliceScripts.callOverride(this, 'playAnimation', [AnimName, Force, false, Reversed]);
			_engineAnimation = false;
			_engineFrame = 0;
			if(done) return;
		}
		#end

		specialAnim = false;
		if(!isAnimateAtlas)
		{
			animation.play(AnimName, Force, Reversed, Frame);
		}
		else
		{
			#if flxanimate
			if(extraAtlases != null)
			{
				// the atlas that has the animation is the one that's shown
				var other:FlxAnimate = animationAtlases.get(AnimName);
				if(other != null)
				{
					if(!isExtraAtlas(atlas)) mainAtlas = atlas;
					atlas = other;
				}
				else if(mainAtlas != null && isExtraAtlas(atlas)) atlas = mainAtlas;
			}
			#end
			atlas.anim.play(AnimName, Force, Reversed, Frame);
			atlas.update(0);
		}
		_lastPlayedAnimation = AnimName;
		singAnimationTime = 0;

		if (hasAnimation(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
			if(cornerPosition && !isAnimateAtlas) offset.add(hitboxOffsetX, hitboxOffsetY);
		}
		//else offset.set(0, 0);

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;

			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if(songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	// Atlas support
	// special thanks ne_eo for the references, you're the goat!!
	@:allow(states.editors.CharacterEditorState)
	public var isAnimateAtlas(default, null):Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;

	/**
	 * For a character that's a texture atlas: if it's drawn whole on a texture of its own before going on the screen,
	 * so its shader and its alpha are those of one image instead of each of its pieces' (see `PsychFlxAnimate.useRenderTexture`).
	 */
	public var useRenderTexture:Bool = false;
	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;
		if(missingCharacter)
		{
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}

		if(isAnimateAtlas)
		{
			if(atlas.anim.curInstance != null)
			{
				copyAtlasValues();
				atlas.draw();
				if(alpha != lastAlpha) alpha = lastAlpha;
				if(color != lastColor) color = lastColor;
				if(missingCharacter && visible)
				{
					missingText.x = getMidpoint().x - 150;
					missingText.y = getMidpoint().y - 10;
					missingText.draw();
				}
			}
			return;
		}
		super.draw();
		if(missingCharacter && visible)
		{
			alpha = lastAlpha;
			color = lastColor;
			missingText.x = getMidpoint().x - 150;
			missingText.y = getMidpoint().y - 10;
			missingText.draw();
		}
	}

	#if flxanimate
	static var _measureCamera:FlxCamera = null;

	/**
	 * Area taken by the current frame of a texture atlas character, relative to its position.
	 * Unlike the other sprites these aren't drawn from their top left corner, their art can be anywhere around it.
	 * Returns null if this isn't an atlas character or if it has nothing to draw.
	 */
	public function getAtlasBounds():flixel.math.FlxRect
	{
		if(!isAnimateAtlas || atlas == null || atlas.anim.curInstance == null || atlas.anim.curSymbol == null) return null;

		// drawn on a camera that's never shown, only to know where the pieces end up at
		if(_measureCamera == null) _measureCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);

		var bounds:flixel.math.FlxRect = null;
		@:privateAccess
		{
			for (i in 0...(flipX ? 2 : 1)) //flipping uses the width of the last time it was drawn
			{
				copyAtlasValues();
				atlas.cameras = [_measureCamera];
				atlas.draw();
				_measureCamera.clearDrawStack();
			}

			if(atlas._flashRect.width > 0 && atlas._flashRect.height > 0)
				bounds = flixel.math.FlxRect.get(atlas._flashRect.x - x, atlas._flashRect.y - y, atlas._flashRect.width, atlas._flashRect.height);
		}
		atlas.cameras = cameras;
		return bounds;
	}
	#end

	/**
	 * If the character is placed like V-Slice does it (the ones that come from its format are): its position is the top left corner
	 * of what's seen, whatever its scale, and `width` and `height` are the size it has on the stage. Stages and scripts place things by that.
	 *
	 * Psych's characters grow from the middle of their frame when scaled, as their `offset` is taken by the animations: their position
	 * is only that corner at scale 1. And texture atlases aren't drawn from a corner at all: their art can be anywhere around the spot
	 * they're put at. V-Slice gives its atlases a box, the area taken by the whole timeline the animation is on (not just by the pose
	 * that's showing), and treats them like any other sprite from there: `origin` is counted from the box's corner,
	 * and when flipped the art is mirrored inside of it.
	 */
	public var cornerPosition(default, null):Bool = false;

	// If the atlas is drawn where its file puts it instead (V-Slice's "applyStageMatrix"): the position is the corner of Adobe Animate's stage then
	var atlasOnDocument:Bool = false;

	/**
	 * How far from the character's position its texture atlas is put, which is what makes the position be the corner of its box.
	 */
	public var atlasShiftX(default, null):Float = 0;
	public var atlasShiftY(default, null):Float = 0;

	// What `updateHitbox()` moves a scaled sprite by to keep its corner in place. It's the sprite's `offset` on V-Slice, here that's the animation's
	var hitboxOffsetX:Float = 0;
	var hitboxOffsetY:Float = 0;

	var atlasOrigin:FlxPoint = FlxPoint.get();

	/**
	 * The box of the animation that's playing, from where the atlas is put. Not to be changed.
	 */
	public function getAtlasBox():flixel.math.FlxRect
	{
		if(!isAnimateAtlas || atlas == null || atlas.anim == null) return null;

		var box:flixel.math.FlxRect = atlas.getAnimationBox(_lastPlayedAnimation);
		if(box == null && atlas.anim.stageInstance != null && atlas.anim.stageInstance.symbol != null)
		{
			// nothing playing yet: the one of the main timeline, which is where the animations usually are
			box = atlas.getTimelineBounds(atlas.anim.stageInstance.symbol.name, atlas.labelsOnDocument ? atlas.anim.stageInstance.matrix : null);
		}
		return box;
	}

	// (the middle of what's showing: the sprite itself has no image for it to be counted from)
	override function getGraphicMidpoint(?point:FlxPoint):FlxPoint
	{
		var box:flixel.math.FlxRect = cornerPosition ? getAtlasBox() : null;
		if(box == null) return super.getGraphicMidpoint(point);

		if(point == null) point = FlxPoint.get();
		return point.set(x + box.width * 0.5 * scale.x, y + box.height * 0.5 * scale.y);
	}

	override function updateHitbox():Void
	{
		var box:flixel.math.FlxRect = (cornerPosition && isAnimateAtlas) ? getAtlasBox() : null;
		if(!cornerPosition || (isAnimateAtlas && box == null))
		{
			super.updateHitbox();
			return;
		}

		// The same every sprite does, with the box as the frame of the ones that are an atlas
		var boxWidth:Float = (box != null) ? box.width : frameWidth;
		var boxHeight:Float = (box != null) ? box.height : frameHeight;
		var lastX:Float = hitboxOffsetX;
		var lastY:Float = hitboxOffsetY;

		width = Math.abs(scale.x) * boxWidth;
		height = Math.abs(scale.y) * boxHeight;
		hitboxOffsetX = -0.5 * (width - boxWidth);
		hitboxOffsetY = -0.5 * (height - boxHeight);
		origin.set(boxWidth * 0.5, boxHeight * 0.5);

		// The sprite's own offset has the animation's, this goes on top of it (an atlas is moved by it instead: see `copyAtlasValues()`)
		if(!isAnimateAtlas) offset.add(hitboxOffsetX - lastX, hitboxOffsetY - lastY);
	}

	// ------------------------------------------------------------------------------------------
	// More than one atlas
	// ------------------------------------------------------------------------------------------

	/**
	 * The atlas that came with the character's image. `atlas` is the one being shown, which is another one while an animation of it is playing.
	 */
	public var mainAtlas(default, null):FlxAnimate = null;

	// The other atlases by their image, and the animations that are on them. Null without any
	var extraAtlases:Map<String, FlxAnimate> = null;
	var animationAtlases:Map<String, FlxAnimate> = [];

	function getExtraAtlas(image:String):FlxAnimate
	{
		if(extraAtlases == null) extraAtlases = [];
		if(extraAtlases.exists(image)) return extraAtlases.get(image);

		var extra:FlxAnimate = null;
		var file:String = Paths.getPath('images/' + image + '/Animation.json', TEXT);
		if(#if MODS_ALLOWED FileSystem.exists(file) || #end Assets.exists(file))
		{
			extra = new FlxAnimate();
			extra.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(extra, image);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load atlas $image: $e');
			}

			if(extra.anim == null || extra.anim.symbolDictionary == null || extra.anim.stageInstance == null) extra = FlxDestroyUtil.destroy(extra);
			else if(atlas != null) extra.labelsOnDocument = atlas.labelsOnDocument;
		}
		if(extra == null) trace('The atlas "$image" of the character "$curCharacter" was not found, it is left without the animations that are on it');

		extraAtlases.set(image, extra);
		return extra;
	}

	function isExtraAtlas(which:FlxAnimate):Bool
	{
		if(extraAtlases == null || which == null) return false;

		for (extra in extraAtlases)
			if(extra == which)
				return true;
		return false;
	}

	/**
	 * Every atlas the character has, the one of its image first.
	 */
	public function getAtlases():Array<FlxAnimate>
	{
		var list:Array<FlxAnimate> = [];
		var main:FlxAnimate = (mainAtlas != null) ? mainAtlas : atlas;
		if(main != null) list.push(main);
		if(atlas != null && !list.contains(atlas)) list.push(atlas);

		if(extraAtlases != null)
			for (extra in extraAtlases)
				if(extra != null && !list.contains(extra))
					list.push(extra);
		return list;
	}

	function destroyExtraAtlases():Void
	{
		if(extraAtlases != null)
		{
			// (the one of the image is back as the one that's shown, whoever loads another does what it wants with it)
			if(isExtraAtlas(atlas)) atlas = mainAtlas;

			for (extra in extraAtlases)
			{
				if(extra == null) continue;

				// they were given the character's own points to be drawn with
				extra.offset = FlxPoint.get();
				extra.origin = FlxPoint.get();
				extra.scale = FlxPoint.get(1, 1);
				extra.scrollFactor = FlxPoint.get(1, 1);
				extra.destroy();
			}
		}
		extraAtlases = null;
		animationAtlases = [];
	}

	public function copyAtlasValues()
	{
		@:privateAccess
		{
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;

			var box:flixel.math.FlxRect = cornerPosition ? getAtlasBox() : null;
			if(box != null)
			{
				// (see `cornerPosition`)
				var left:Float = atlasOnDocument ? 0 : box.x;
				var top:Float = atlasOnDocument ? 0 : box.y;
				atlasOrigin.set(origin.x + left, origin.y + top);
				atlas.origin = atlasOrigin;
				atlasShiftX = hitboxOffsetX + left;
				atlasShiftY = hitboxOffsetY + top;
				atlas.flipWidth = box.x * 2 + box.width;
				atlas.flipHeight = box.y * 2 + box.height;
			}
			else
			{
				atlas.origin = origin;
				atlasShiftX = 0;
				atlasShiftY = 0;
				atlas.flipWidth = null;
				atlas.flipHeight = null;
			}

			atlas.x = x - atlasShiftX;
			atlas.y = y - atlasShiftY;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.useRenderTexture = useRenderTexture;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}

	public override function destroy()
	{
		destroyExtraAtlases();
		atlas = FlxDestroyUtil.destroy(atlas);
		mainAtlas = null;
		atlasOrigin = FlxDestroyUtil.put(atlasOrigin);
		super.destroy();
	}
	#end
}
