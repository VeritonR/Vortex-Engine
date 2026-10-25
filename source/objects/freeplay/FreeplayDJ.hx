package objects.freeplay;

import backend.PlayableCharacters;
import backend.VSliceConvert;

import flixel.util.FlxSignal;

import funkin.data.freeplay.player.PlayerData.PlayerFreeplayDJData;

enum FreeplayDJState
{
	Intro; //Comes into the screen, then goes to Idle
	Idle;
	IdleEasterEgg; //Plays after a while without doing anything, then goes back to Idle
	Cartoon; //Plays after even longer, stays on it until something else is played
	Confirm; //A song was picked
	FistPumpIntro; //Getting ready to celebrate a new rank, or to regret it
	FistPump;
	NewUnlock; //A character was just unlocked (the engine never gets to it by itself, scripts can)
	CharSelect; //Leaving to Character Select
}

/**
 * What V-Slice scripts get for `FreeplayDJState`: the same values, as variables they can read.
 */
class FreeplayDJStates
{
	public static var Intro:FreeplayDJState = FreeplayDJState.Intro;
	public static var Idle:FreeplayDJState = FreeplayDJState.Idle;
	public static var IdleEasterEgg:FreeplayDJState = FreeplayDJState.IdleEasterEgg;
	public static var Cartoon:FreeplayDJState = FreeplayDJState.Cartoon;
	public static var Confirm:FreeplayDJState = FreeplayDJState.Confirm;
	public static var FistPumpIntro:FreeplayDJState = FreeplayDJState.FistPumpIntro;
	public static var FistPump:FreeplayDJState = FreeplayDJState.FistPump;
	public static var NewUnlock:FreeplayDJState = FreeplayDJState.NewUnlock;
	public static var CharSelect:FreeplayDJState = FreeplayDJState.CharSelect;
}

/**
 * Who's on the turntable of the V-Slice Freeplay menu, taken from the "freeplayDJ" of the player's file (same format as V-Slice):
 *
 * - `assetPath`: texture atlas inside the images folder.
 * - `animations`: `name` is what the animation is for ("intro", "idle", "idleEasterEgg", "cartoon", "confirm", "fistPump", "loss", "charSelect")
 *   and `prefix` the frame label of the atlas (when `animType` is "framelabel") or the symbol that has it.
 * - `fistPump`: frames of the "fistPump" and "loss" animations to repeat while waiting for the rank to show up, and where to go on from.
 * - `charSelect.transitionDelay`: seconds of the "charSelect" animation to show before the menu leaves.
 *
 * Only texture atlases are supported. What the base game's script for Boyfriend does while he watches TV was made part of this class.
 *
 * The scripts mods make for their DJs (`scriptClass`) do run: this class is what they get for V-Slice's `BaseFreeplayDJ` and the ones that extend it,
 * with the same names. Scripts know the animations by their `prefix` instead of by what they're for, both are taken here.
 * Each function a script has its own version of is done by the script instead (see `scripted()`); a scripted DJ deals with its own TV.
 */
class FreeplayDJ extends FreeplayAtlas
{
	// Seconds without doing anything on the menu for each thing the DJ does about it
	public var IDLE_EGG_PERIOD:Float = 60;
	public var IDLE_CARTOON_PERIOD:Float = 120;

	/**
	 * Dispatched when the intro animation ends, or right away if there's none.
	 */
	public var onIntroDone(default, null):FlxSignal = new FlxSignal();
	public var onIdleEasterEgg(default, null):FlxSignal = new FlxSignal();

	/**
	 * Dispatched with each frame of the animations (prefix, frame, frame): what scripts get for `animation.onFrameChange`.
	 */
	public var frameChanged(default, null):FlxTypedSignal<String->Int->Int->Void> = new FlxTypedSignal<String->Int->Int->Void>();

	public var charSelectDelay(default, null):Float = 0.25;

	/**
	 * Id of the player the DJ is.
	 */
	public var characterId(default, null):String;

	/**
	 * The "freeplayDJ" of the player's file, the way scripts ask about it.
	 */
	public var playableCharData(default, null):PlayerFreeplayDJData;

	public var timeIdling:Float = 0;
	public var seenIdleEasterEgg:Bool = false;

	var data:Dynamic;
	var state:FreeplayDJState = Intro;
	var introDone:Bool = false;

	public var currentState(get, set):FreeplayDJState;
	function get_currentState():FreeplayDJState return state;
	function set_currentState(value:FreeplayDJState):FreeplayDJState return state = (value != null) ? value : Idle;

	var animOffsets:Map<String, Array<Float>> = [];
	var useAnimatePosition:Bool = false;

	// Frames of the "fistPump" and "loss" animations
	var introStartFrame:Int = 0;
	var introEndFrame:Int = 0;
	var loopStartFrame:Int = 0;
	var loopEndFrame:Int = -1;
	var introBadStartFrame:Int = 0;
	var introBadEndFrame:Int = 0;
	var loopBadStartFrame:Int = 0;
	var loopBadEndFrame:Int = -1;

	// Frames of the "cartoon" animation, -1 for the ones it doesn't have
	var cartoonChangeChannelFrame:Int = -1;
	var cartoonRemoteClickFrame:Int = -1;
	var cartoonTVSoundFrame:Int = -1;
	var cartoonBlinkFrame:Int = -1;
	var cartoonLoopFrame:Int = -1;

	var lastCartoonFrame:Int = -1;
	var cartoonSound:FlxSound = null;
	var cartoonSoundStarted:Bool = false;
	var playingCartoon:Bool = false;

	// What the DJ is made with: the player, or what scripts give (x, y, id of the player)
	static function findPlayer(player:Dynamic, characterId:String):PlayableCharacter
	{
		if(characterId != null) return PlayableCharacters.get(characterId);
		if(Std.isOfType(player, String)) return PlayableCharacters.get(player);
		return (player != null && !Std.isOfType(player, Float)) ? player : null;
	}

	// True if a script made for the DJ has its own version of a function, after running it
	inline function scripted(name:String, ?args:Array<Dynamic>):Bool
	{
		return #if HSCRIPT_ALLOWED backend.VSliceScripts.callOverride(this, name, args) #else false #end;
	}

	var hasScript(get, never):Bool;
	inline function get_hasScript():Bool
		return #if HSCRIPT_ALLOWED hxc.HxcRuntime.getInstance(this) != null #else false #end;

	/**
	 * The player's mod has to be the current one when this is called, so its files are found.
	 *
	 * @param player 	The player. Scripts give a position here, and the player's id as the third value.
	 */
	public function new(player:Dynamic, ?y:Float, ?characterId:String)
	{
		var player:PlayableCharacter = findPlayer(player, characterId);
		super(0, 0, getAssetPath((player != null) ? player.freeplayDJ : null));

		this.characterId = (player != null) ? player.id : characterId;
		playableCharData = new PlayerFreeplayDJData((player != null) ? player.freeplayDJ : null);
		if(!loaded) return;

		data = player.freeplayDJ;

		useAnimatePosition = (data.useAnimatePosition == true);
		if(!useAnimatePosition) setPosition(640, 366);

		for (animation in VSliceConvert.list(data.animations))
		{
			var name:String = VSliceConvert.str(animation.name, '');
			var prefix:String = VSliceConvert.str(animation.prefix, '');
			if(name.length < 1 || prefix.length < 1) continue;

			var added:Bool = false;
			if(VSliceConvert.str(animation.animType, '').toLowerCase() == 'framelabel') added = addLabelAnim(name, prefix);
			else if(hasSymbol(prefix))
			{
				// symbols stay where the atlas' main timeline would have them, on DJs placed by the atlas itself (`useAnimatePosition`).
				// The older ones (one symbol for each animation, with offsets of their own) have the symbol where the DJ is, like
				// V-Slice's older versions drew them
				var placed:Bool = useAnimatePosition && anim.stageInstance != null && anim.stageInstance.matrix != null;
				var stageX:Float = placed ? anim.stageInstance.matrix.tx : 0;
				var stageY:Float = placed ? anim.stageInstance.matrix.ty : 0;
				if(!useAnimatePosition)
				{
					// (V-Slice puts the top left of what an animation shows where the DJ is, plus the animation's offsets)
					var exact:String = anim.symbolDictionary.exists(prefix) ? prefix : null;
					if(exact == null)
						for (symbolName in anim.symbolDictionary.keys())
							if(symbolName.startsWith(prefix)) { exact = symbolName; break; }
					var box:flixel.math.FlxRect = (exact != null) ? getTimelineBounds(exact) : null;
					if(box != null && box.width > 0)
					{
						stageX = -box.x;
						stageY = -box.y;
					}
					if(box != null) box.put();
				}
				anim.addBySymbol(name, flxanimate.PsychFlxAnimate.symbolQuery(anim, prefix), 0, true, stageX, stageY);
				added = hasAnim(name);
			}

			if(!added)
			{
				trace('Freeplay DJ of "${player.id}": there is no "$prefix" for the animation "$name"');
				continue;
			}
			animOffsets.set(name, VSliceConvert.pair(animation.offsets, 0, 0));
		}

		var fistPump:Dynamic = data.fistPump;
		if(fistPump != null)
		{
			introStartFrame = frameValue(fistPump.introStartFrame, 0);
			introEndFrame = frameValue(fistPump.introEndFrame, 0);
			loopStartFrame = frameValue(fistPump.loopStartFrame, 0);
			loopEndFrame = frameValue(fistPump.loopEndFrame, -1);
			introBadStartFrame = frameValue(fistPump.introBadStartFrame, 0);
			introBadEndFrame = frameValue(fistPump.introBadEndFrame, 0);
			loopBadStartFrame = frameValue(fistPump.loopBadStartFrame, 0);
			loopBadEndFrame = frameValue(fistPump.loopBadEndFrame, -1);
		}

		if(data.charSelect != null) charSelectDelay = VSliceConvert.num(data.charSelect.transitionDelay, charSelectDelay);

		if(hasAnim('cartoon')) findCartoonFrames();

		onAnimFinish = finishedAnim;
		onFrameChange = onAnimFrame;

		if(!hasAnim('intro')) state = Idle;
		else playDJAnim('intro');
	}

	static function getAssetPath(data:Dynamic):String
	{
		var renderType:String = (data != null) ? VSliceConvert.str(data.renderType, 'animateatlas').trim().toLowerCase() : '';
		if(data == null || renderType != 'animateatlas')
		{
			if(data != null) trace('Freeplay DJs of the type "$renderType" are not supported, only texture atlases are');
			return '';
		}
		return VSliceConvert.stripLibrary(VSliceConvert.str(data.assetPath, ''));
	}

	inline static function frameValue(value:Dynamic, defaultValue:Int):Int
	{
		return Std.int(VSliceConvert.num(value, defaultValue));
	}

	// The cartoon animation says where its parts are with frame labels inside of its own symbol
	function findCartoonFrames()
	{
		for (name => symbol in anim.symbolDictionary)
		{
			if(name.startsWith('__label_')) continue; //the ones made for the frame labels

			if(!symbol.getFrameLabelNames().contains('TV_SOUND')) continue;

			cartoonChangeChannelFrame = getSymbolLabelFrame(name, 'CHANGE_CHANNEL');
			cartoonRemoteClickFrame = getSymbolLabelFrame(name, 'REMOTE_CLICK');
			cartoonTVSoundFrame = getSymbolLabelFrame(name, 'TV_SOUND');
			cartoonBlinkFrame = getSymbolLabelFrame(name, 'BLINK');
			cartoonLoopFrame = getSymbolLabelFrame(name, 'LOOP');
			break;
		}
	}

	function playDJAnim(name:String, looped:Bool = false, frame:Int = 0):Bool
	{
		if(!playAnim(name, looped, frame)) return false;

		if(name == 'cartoon') lastCartoonFrame = frame;
		applyAnimOffset(name);
		return true;
	}

	// ------------------------------------------------------------------------------------------

	/**
	 * To be called every time the player does something on the menu.
	 */
	public function onPlayerAction():Void
	{
		if(scripted('onPlayerAction')) return;
		resetAFKTimer();
	}

	public function resetAFKTimer():Void
	{
		timeIdling = 0;
		seenIdleEasterEgg = false;
	}

	/**
	 * The song previews get quieter while the TV is on.
	 */
	public function getMusicPreviewMult():Float
	{
		#if HSCRIPT_ALLOWED
		if(scripted('getMusicPreviewMult'))
		{
			var result:Dynamic = backend.VSliceScripts.overrideResult;
			return Std.isOfType(result, Float) ? result : 1;
		}
		#end
		return playingCartoon ? 0.15 : 1;
	}

	public function onConfirm():Void
	{
		if(scripted('onConfirm')) return;

		state = Confirm;
		fadeCartoonSound();
	}

	/**
	 * Returns false if there's no animation for it.
	 */
	public function toCharSelect():Bool
	{
		if(scripted('toCharSelect')) return state == CharSelect;

		fadeCartoonSound();
		if(hasAnim('charSelect'))
		{
			state = CharSelect;
			playDJAnim('charSelect');
			return true;
		}

		state = Confirm;
		return false;
	}

	public function fistPumpIntro():Void
	{
		if(scripted('fistPumpIntro')) return;

		state = FistPumpIntro;
		if(!playDJAnim('fistPump', false, introStartFrame)) state = Idle;
	}

	public function fistPump():Void
	{
		if(scripted('fistPump')) return;

		state = FistPump;
		if(!playDJAnim('fistPump', false, loopStartFrame)) state = Idle;
	}

	public function fistPumpLossIntro():Void
	{
		if(scripted('fistPumpLossIntro')) return;

		state = FistPumpIntro;
		if(!playDJAnim('loss', false, introBadStartFrame)) state = Idle;
	}

	public function fistPumpLoss():Void
	{
		if(scripted('fistPumpLoss')) return;

		state = FistPump;
		if(!playDJAnim('loss', false, loopBadStartFrame)) state = Idle;
	}

	// ------------------------------------------------------------------------------------------
	// For the scripts
	// ------------------------------------------------------------------------------------------

	// What an animation is for, given that or its prefix
	function animName(name:String):String
	{
		if(name == null || hasAnim(name)) return name;

		var found:String = playableCharData.getAnimationName(name);
		return (found != null) ? found : name;
	}

	// The prefix of an animation, what scripts know it by
	function animPrefix(name:String):String
	{
		var prefix:String = (name != null) ? playableCharData.getAnimationPrefix(name) : null;
		return (prefix != null) ? prefix : name;
	}

	public function playFlashAnimation(id:String, force:Bool = false, reverse:Bool = false, loop:Bool = false, frame:Int = 0):Void
	{
		playDJAnim(animName(id), loop, frame);
	}

	public function hasAnimation(id:String):Bool
	{
		return hasAnim(animName(id));
	}

	public function getCurrentAnimation():String
	{
		return (curAnim != null) ? animPrefix(curAnim) : '';
	}

	public function isAnimationFinished():Bool
	{
		return animFinished;
	}

	/**
	 * Called when the animation of leaving to Character Select ends, the menu leaves on its own time.
	 */
	public function onCharSelectComplete():Void {}

	public function resetPosition():Void
	{
		if(useAnimatePosition) setPosition(0, 0);
		else setPosition(640, 366);
	}

	/**
	 * V-Slice's texture atlases keep their symbols on a "library", scripts go there to find the frame labels of one:
	 * `getFrameLabel('LABEL', library.getSymbol('name').timeline).index`.
	 */
	public var library(get, never):Dynamic;
	function get_library():Dynamic
	{
		var dj:FreeplayDJ = this;
		return {
			getSymbol: function(name:String):Dynamic return dj.hasSymbol(name) ? {name: name, timeline: {symbol: name}} : null
		};
	}

	public function getFrameLabel(label:String, ?timeline:Dynamic):Dynamic
	{
		var symbol:String = (timeline != null) ? timeline.symbol : null;
		var index:Int = (symbol != null) ? getSymbolLabelFrame(symbol, label) : -1;
		return (index > -1) ? {name: label, index: index} : null;
	}

	// ------------------------------------------------------------------------------------------

	// ------------------------------------------------------------------------------------------
	// For the Character Select editor
	// ------------------------------------------------------------------------------------------

	/**
	 * The DJ only plays what it's told to (`previewAnimation()`), none of what it does by itself on Freeplay.
	 */
	public var editorMode:Bool = false;

	/**
	 * What the DJ's animations are for ("intro", "idle"...), the ones it could be given.
	 */
	public function animationNames():Array<String>
	{
		var names:Array<String> = [];
		if(data != null)
			for (animation in VSliceConvert.list(data.animations))
			{
				var name:String = VSliceConvert.str(animation.name, '');
				if(name.length > 0 && hasAnim(name) && !names.contains(name)) names.push(name);
			}
		return names;
	}

	public function previewAnimation(name:String, looped:Bool = false):Bool
	{
		return playDJAnim(name, looped);
	}

	public function getAnimationOffset(name:String):Array<Float>
	{
		var offset:Array<Float> = animOffsets.get(name);
		return (offset != null) ? offset.copy() : [0, 0];
	}

	/**
	 * Changes the offsets of an animation, on the DJ and on its data (the "freeplayDJ" of the player's file it was made with).
	 */
	public function setAnimationOffset(name:String, x:Float, y:Float):Void
	{
		animOffsets.set(name, [x, y]);
		if(data != null)
			for (animation in VSliceConvert.list(data.animations))
				if(VSliceConvert.str(animation.name, '') == name)
					animation.offsets = [x, y];

		if(curAnim == name) applyAnimOffset(name);
	}

	// V-Slice's (`BaseFreeplayDJ.applyAnimationOffset()`): a DJ placed by its atlas' stage only moves by its animation's offsets, the others
	// have an animation's offsets as where it's drawn (from the DJ's global offsets), wherever the DJ is when it starts
	function applyAnimOffset(name:String):Void
	{
		var animOffset:Array<Float> = animOffsets.get(name);
		if(animOffset == null)
		{
			offset.set(0, 0);
			return;
		}

		if(placedByStage()) offset.set(animOffset[0], animOffset[1]);
		else
		{
			var global:Array<Float> = (data != null) ? VSliceConvert.pair(data.offsets, 0, 0) : [0, 0];
			offset.set(x - global[0] - animOffset[0], y - global[1] - animOffset[1]);
		}
	}

	public inline function placedByStage():Bool
		return useAnimatePosition || (data != null && data.atlasSettings != null && data.atlasSettings.applyStageMatrix == true);

	override function update(elapsed:Float)
	{
		if(editorMode)
		{
			super.update(elapsed);
			return;
		}

		// (the game calls this by itself, which would go right past a script's own version of it)
		if(scripted('update', [elapsed])) return;

		if(loaded)
		{
			switch(state)
			{
				case Intro:
					timeIdling = 0;

				case Idle:
					if(curAnim != 'idle') playDJAnim('idle', true);
					timeIdling += elapsed;

					if(!introDone)
					{
						// there was no intro to wait for
						introDone = true;
						onIntroDone.dispatch();
					}

				case Confirm:
					if(curAnim != 'confirm') playDJAnim('confirm');
					timeIdling = 0;

				case FistPumpIntro:
					// repeats its first frames until the rank shows up
					if(curAnim == 'fistPump')
					{
						if(introEndFrame > -1 && getAnimFrame() >= introEndFrame) playDJAnim('fistPump', false, introStartFrame);
					}
					else if(curAnim == 'loss')
					{
						if(introBadEndFrame > -1 && getAnimFrame() >= introBadEndFrame) playDJAnim('loss', false, introBadStartFrame);
					}

				case FistPump:
					if(curAnim == 'fistPump')
					{
						if(loopEndFrame > -1 && getAnimFrame() >= loopEndFrame) playDJAnim('fistPump', false, loopStartFrame);
					}
					else if(curAnim == 'loss')
					{
						if(loopBadEndFrame > -1 && getAnimFrame() >= loopBadEndFrame) playDJAnim('loss', false, loopBadStartFrame);
					}

				case IdleEasterEgg:
					if(curAnim != 'idleEasterEgg')
					{
						seenIdleEasterEgg = true;
						if(!playDJAnim('idleEasterEgg')) state = Idle;
					}
					timeIdling = 0;

				case Cartoon:
					if(!hasAnim('cartoon')) state = hasAnim('idleEasterEgg') ? IdleEasterEgg : Idle;
					else if(curAnim != 'cartoon') playDJAnim('cartoon');
					timeIdling = 0;

				case NewUnlock:
					if(curAnim != 'newUnlock' && !playDJAnim('newUnlock', true)) state = Idle;

				case CharSelect:
			}
		}

		// after picking what to play, so the atlas shows it on this same frame
		super.update(elapsed);
	}

	// An animation ended. Scripts are told with its prefix, and decide what comes next by themselves
	function finishedAnim(name:String):Void
	{
		if(scripted('onFinishAnim', [animPrefix(name)]))
		{
			// (the menu waits for the intro, however the script got out of it)
			if(name == 'intro' && !introDone)
			{
				introDone = true;
				if(state == Intro) state = Idle;
			}
			return;
		}
		onFinishAnim(name);
	}

	function onFinishAnim(name:String):Void
	{
		switch(animName(name))
		{
			case 'intro':
				state = Idle;
				introDone = true;
				onIntroDone.dispatch();

			case 'idle':
				if(state != Idle) return;

				if(timeIdling >= IDLE_EGG_PERIOD && !seenIdleEasterEgg && hasAnim('idleEasterEgg'))
				{
					state = IdleEasterEgg;
					onIdleEasterEgg.dispatch();
				}
				else if(timeIdling >= IDLE_CARTOON_PERIOD && hasAnim('cartoon')) state = Cartoon;

			case 'fistPump', 'loss', 'idleEasterEgg':
				state = Idle;

			case 'cartoon':
				// keeps watching, blinking every now and then and changing the channel on a 10% chance
				var frame:Int = FlxG.random.bool(33) ? cartoonBlinkFrame : cartoonLoopFrame;
				if(FlxG.random.bool(10)) frame = cartoonChangeChannelFrame;
				playDJAnim('cartoon', false, Std.int(Math.max(frame, 0)));
		}
	}

	function onAnimFrame(name:String, frame:Int):Void
	{
		frameChanged.dispatch(animPrefix(name), frame, frame);
		if(name != 'cartoon' || hasScript) return;

		// more than one frame can go by at once when the game lags
		var lastFrame:Int = lastCartoonFrame;
		lastCartoonFrame = frame;

		if(cartoonRemoteClickFrame > lastFrame && cartoonRemoteClickFrame <= frame) FlxG.sound.play(Paths.sound('remote_click'));
		if(cartoonTVSoundFrame > lastFrame && cartoonTVSoundFrame <= frame) runTVLogic();
	}

	// ------------------------------------------------------------------------------------------
	// TV
	// ------------------------------------------------------------------------------------------

	function runTVLogic()
	{
		// the TV is either getting turned on or changing channels
		var sound:FlxSound = FlxG.sound.play(Paths.sound(cartoonSoundStarted ? 'channel_switch' : 'tv_on'));
		cartoonSoundStarted = true;

		if(sound != null) sound.onComplete = loadCartoon;
		else loadCartoon();
	}

	function loadCartoon()
	{
		if(state != Cartoon || !exists) return; //left the couch while the TV was turning on

		stopCartoonSound();

		var cartoons:Array<String> = listCartoons();
		if(cartoons.length < 1) return;

		playingCartoon = true;

		cartoonSound = FlxG.sound.load(Paths.sound('cartoons/' + FlxG.random.getObject(cartoons)), 1, false, null, false, false, null, function()
		{
			// goes to another channel when the video ends
			if(state == Cartoon && cartoonChangeChannelFrame > -1) playDJAnim('cartoon', false, cartoonChangeChannelFrame);
		});
		if(cartoonSound == null) return;

		// lowers the music so the TV can be heard
		if(FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.fadeOut(1, 0.1);
		}

		// somewhere between the video's start and 5 seconds from its end
		cartoonSound.play(true, FlxG.random.float(0, Math.max(cartoonSound.length - 5000, 0)));
	}

	static function listCartoons():Array<String>
	{
		var cartoons:Array<String> = [];
		#if sys
		var folders:Array<String> = [Paths.getSharedPath('sounds/cartoons/')];
		#if MODS_ALLOWED
		folders.push(Paths.mods('sounds/cartoons/'));
		#end

		for (folder in folders)
		{
			if(!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;

			for (file in FileSystem.readDirectory(folder))
			{
				if(!file.toLowerCase().endsWith('.${Paths.SOUND_EXT}')) continue;

				var name:String = file.substr(0, file.length - Paths.SOUND_EXT.length - 1);
				if(!cartoons.contains(name)) cartoons.push(name);
			}
		}
		#end
		return cartoons;
	}

	function fadeCartoonSound()
	{
		if(cartoonSound != null && cartoonSound.playing) cartoonSound.fadeOut(0.25, 0);
	}

	function stopCartoonSound()
	{
		if(cartoonSound == null) return;

		funkin.audio.FunkinSound.dispose(cartoonSound); //(not destroyed directly: the game still keeps track of it)
		cartoonSound = null;
	}

	override function destroy()
	{
		if(scripted('destroy')) return;

		stopCartoonSound();
		onIntroDone.removeAll();
		onIdleEasterEgg.removeAll();
		frameChanged.removeAll();
		super.destroy();
	}
}
