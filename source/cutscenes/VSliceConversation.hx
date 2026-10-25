package cutscenes;

import flixel.addons.text.FlxTypeText;
import flixel.group.FlxSpriteGroup;
import haxe.Json;

enum ConversationState
{
	START;
	OPENING; //the box is showing up
	SPEAKING; //the text is being typed
	IDLE; //waiting for the player
	ENDING;
	DONE;
}

/**
 * V-Slice's dialogues: a conversation ("data/dialogue/conversations") is a list of lines, each said by a speaker
 * ("data/dialogue/speakers") inside of a box ("data/dialogue/boxes"), over a backdrop and with its own music.
 *
 * ACCEPT finishes the line being typed or goes to the next one, BACK skips the whole conversation.
 */
class VSliceConversation extends FlxSpriteGroup
{
	public var id(default, null):String;
	public var state(default, null):ConversationState = START;

	/**
	 * Called when the conversation is over, by reaching its end or by being skipped.
	 */
	public var completeCallback:Void->Void = null;

	var data:Dynamic;
	var entries:Array<Dynamic>;
	var curEntry:Int = 0;
	var curLine:Int = 0;

	var music:FlxSound = null;
	var backdrop:FlxSprite = null;
	var speaker:VSliceSpeaker = null;
	var box:VSliceDialogueBox = null;
	var outroTween:FlxTween = null;

	// the ones that were already shown, they come back as the conversation goes from one to another
	var speakers:Map<String, VSliceSpeaker> = [];
	var boxes:Map<String, VSliceDialogueBox> = [];

	/**
	 * The file of something of a dialogue, null if it doesn't exist or can't be read.
	 */
	public static function loadData(folder:String, id:String):Dynamic
	{
		if(id == null || id.length < 1) return null;

		try
		{
			var raw:String = Paths.getTextFromFile('data/dialogue/$folder/$id.json');
			if(raw == null) return null;
			if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1); //UTF-8 BOM

			try
			{
				return Json.parse(raw);
			}
			catch(e:Dynamic)
			{
				return tjson.TJSON.parse(raw); //more forgiving with hand written files
			}
		}
		catch(e:Dynamic)
		{
			trace('Could not read the dialogue file "$folder/$id": $e');
		}
		return null;
	}

	/**
	 * Makes a conversation out of its file, null if there's no such conversation.
	 */
	public static function load(id:String):VSliceConversation
	{
		var data:Dynamic = loadData('conversations', id);
		if(data == null || !Std.isOfType(data.dialogue, Array)) return null;
		return new VSliceConversation(id, data);
	}

	function new(id:String, data:Dynamic)
	{
		super();
		this.id = id;
		this.data = data;
		entries = data.dialogue;
		scrollFactor.set();
	}

	// ------------------------------------------------------------------------------------------
	// Flow
	// ------------------------------------------------------------------------------------------

	var entry(get, never):Dynamic;
	function get_entry():Dynamic
		return (curEntry >= 0 && curEntry < entries.length) ? entries[curEntry] : null;

	var lines(get, never):Array<Dynamic>;
	function get_lines():Array<Dynamic>
		return (entry != null && Std.isOfType(entry.text, Array)) ? entry.text : [];

	var line(get, never):String;
	function get_line():String
		return (curLine < lines.length && lines[curLine] != null) ? Std.string(lines[curLine]) : '';

	// Tells V-Slice scripts about what the dialogue is doing or about to do, returns true if one of them said not to
	function tellScripts(type:String, cancelable:Bool):Bool
	{
		#if HSCRIPT_ALLOWED
		var event = new funkin.modding.events.ScriptEvent.DialogueScriptEvent(type, this, cancelable);
		backend.VSliceScripts.dispatch(event);
		return event.eventCanceled;
		#else
		return false;
		#end
	}

	// The dialogue is over: scripts are told right away, before it fades out (the base game's songs start their countdown on this)
	function end():Void
	{
		if(state == ENDING || state == DONE) return;

		state = ENDING;
		tellScripts(funkin.modding.events.ScriptEventType.DIALOGUE_END, false);
	}

	public function start():Void
	{
		if(state != START) return;
		if(tellScripts(funkin.modding.events.ScriptEventType.DIALOGUE_START, true)) return;

		curEntry = 0;
		curLine = 0;

		if(entries.length < 1)
		{
			finish();
			return;
		}

		setupMusic();
		setupBackdrop();

		state = OPENING;
		showBox();
	}

	/**
	 * What the confirm key does.
	 */
	public function advance():Void
	{
		switch(state)
		{
			case START: start();
			case OPENING, SPEAKING:
				if(!tellScripts(funkin.modding.events.ScriptEventType.DIALOGUE_COMPLETE_LINE, true) && box != null) box.skip();
			case IDLE:
				if(!tellScripts(funkin.modding.events.ScriptEventType.DIALOGUE_LINE, true)) nextLine();
			case ENDING: finish();
			default:
		}
	}

	/**
	 * Ends the conversation right where it is.
	 */
	public function skip():Void
	{
		if(state == DONE || state == ENDING) return;
		if(!tellScripts(funkin.modding.events.ScriptEventType.DIALOGUE_SKIP, true)) end();
	}

	function nextLine():Void
	{
		curLine++;
		if(curLine < lines.length)
		{
			// another line of the same speaker, typed after what's already there
			state = SPEAKING;
			if(box != null) box.appendText(line);
			else state = IDLE;
			return;
		}

		curLine = 0;
		curEntry++;
		if(curEntry >= entries.length)
		{
			end();
			return;
		}

		state = OPENING;
		showBox();
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		switch(state)
		{
			case OPENING:
				// On V-Slice this is meant to wait for the box to finish showing up, but the way it checks that never makes it wait.
				// Dialogues are made around that: boxes whose animation loops would never get to say anything
				state = SPEAKING;
				showSpeaker();
				if(box != null) box.setText(line);
				else state = IDLE;

			case ENDING:
				if(outroTween == null && !startOutro()) return; //it's over, and gone

			default:
		}

		if(state == DONE) return;

		var controls:Controls = Controls.instance;
		if(controls.BACK && state != ENDING) skip();
		else if(controls.ACCEPT) advance();
	}

	// Returns false if the conversation ended right away
	function startOutro():Bool
	{
		var outro:Dynamic = data.outro;
		var fadeTime:Float = (outro != null && outro.type == 'fade') ? ((outro.fadeTime != null) ? outro.fadeTime : 1) : 0;
		if(fadeTime <= 0)
		{
			finish();
			return false;
		}

		if(box != null) box.stopTyping();

		// in steps, like the pixel art it usually goes with
		outroTween = FlxTween.tween(this, {alpha: 0}, fadeTime, {
			ease: function(t:Float) return Math.floor(t * 8) / 8,
			onComplete: function(_) finish()
		});
		if(music != null) FlxTween.tween(music, {volume: 0}, fadeTime);
		return true;
	}

	function finish():Void
	{
		if(state == DONE) return;
		state = DONE;

		if(outroTween != null) outroTween.cancel();
		outroTween = null;

		if(music != null)
		{
			FlxTween.cancelTweensOf(music);
			funkin.audio.FunkinSound.dispose(music); //(not destroyed directly: the game still has it on its list of sounds)
			music = null;
		}
		if(box != null) box.stopTyping();

		visible = false;
		active = false;

		// whoever started it takes it from here, getting rid of it included
		if(completeCallback != null) completeCallback();
	}

	override function destroy():Void
	{
		if(outroTween != null) outroTween.cancel();
		outroTween = null;

		if(music != null)
		{
			FlxTween.cancelTweensOf(music);
			music.stop();
		}
		music = null;

		// the ones that aren't being shown aren't inside of the group to be destroyed with it
		for (other in speakers)
			if(other != speaker) other.destroy();
		for (other in boxes)
			if(other != box) other.destroy();
		speakers.clear();
		boxes.clear();

		super.destroy();
	}

	// ------------------------------------------------------------------------------------------
	// What's on the screen
	// ------------------------------------------------------------------------------------------

	function setupMusic():Void
	{
		var info:Dynamic = data.music;
		if(info == null || info.asset == null || info.asset == '') return;

		var sound:openfl.media.Sound = findSound('music', info.asset);
		if(sound == null) return;

		var fadeTime:Float = (info.fadeTime != null) ? info.fadeTime : 0;
		music = FlxG.sound.load(sound, (fadeTime > 0) ? 0 : 1, true);
		music.play();
		if(fadeTime > 0) FlxTween.tween(music, {volume: 1}, fadeTime);
	}

	function setupBackdrop():Void
	{
		var info:Dynamic = data.backdrop;
		if(info == null || info.type != 'solid') return;

		var color:Null<FlxColor> = (info.color != null) ? FlxColor.fromString(info.color) : null;
		if(color == null) color = 0x80000000;

		backdrop = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		backdrop.scale.set(FlxG.width, FlxG.height);
		backdrop.updateHitbox();
		backdrop.color = color.to24Bit();
		backdrop.alpha = color.alphaFloat;

		var fadeTime:Float = (info.fadeTime != null) ? info.fadeTime : 0;
		if(fadeTime > 0)
		{
			var target:Float = backdrop.alpha;
			backdrop.alpha = 0;
			FlxTween.tween(backdrop, {alpha: target}, fadeTime, {ease: function(t:Float) return Math.floor(t * 10) / 10});
		}
		layout();
	}

	// The box of the line about to be said, playing the animation the line asks for
	function showBox():Void
	{
		var boxId:String = (entry.box != null) ? entry.box : '';
		if(box == null || box.id != boxId)
		{
			var next:VSliceDialogueBox = boxes.get(boxId);
			if(next == null)
			{
				var boxData:Dynamic = loadData('boxes', boxId);
				if(boxData != null)
				{
					next = new VSliceDialogueBox(boxId, boxData);
					next.typingCompleteCallback = onTypingComplete;
					boxes.set(boxId, next);
				}
				else trace('The dialogue box "$boxId" of the conversation "$id" does not exist');
			}

			if(box != null) box.stopTyping();
			box = next;
			layout();
		}

		if(box != null)
		{
			box.clearText();
			if(entry.boxAnimation != null) box.playAnimation(entry.boxAnimation);
		}
	}

	function showSpeaker():Void
	{
		var speakerId:String = (entry.speaker != null) ? entry.speaker : '';
		if(speaker == null || speaker.id != speakerId)
		{
			var next:VSliceSpeaker = speakers.get(speakerId);
			if(next == null)
			{
				var speakerData:Dynamic = loadData('speakers', speakerId);
				if(speakerData != null)
				{
					next = new VSliceSpeaker(speakerId, speakerData);
					speakers.set(speakerId, next);
				}
				else trace('The speaker "$speakerId" of the conversation "$id" does not exist');
			}

			speaker = next;
			layout();
		}

		if(speaker != null && entry.speakerAnimation != null) speaker.playAnimation(entry.speakerAnimation);
	}

	function onTypingComplete():Void
	{
		if(state == SPEAKING) state = IDLE;
	}

	// Puts what's being shown on the group in its order: backdrop, speaker and box
	function layout():Void
	{
		for (member in members.copy())
			if(member != null) remove(member, true);

		if(backdrop != null) add(backdrop);
		if(speaker != null && speaker.usable) add(speaker);
		if(box != null) add(box);
	}

	// A sound of the mod or of the game, the ones of the base game's weeks are only found by themselves during those weeks
	@:allow(cutscenes.VSliceDialogueBox)
	static function findSound(folder:String, key:String):openfl.media.Sound
	{
		var colon:Int = key.indexOf(':');
		if(colon > -1) key = key.substr(colon + 1);

		var file:String = '$folder/$key.${Paths.SOUND_EXT}';
		if(Paths.fileExists(file, SOUND)) return Paths.returnSound('$folder/$key');

		#if sys
		if(sys.FileSystem.exists('assets') && sys.FileSystem.isDirectory('assets'))
			for (level in sys.FileSystem.readDirectory('assets'))
				if(sys.FileSystem.exists('assets/$level/$file'))
					return Paths.returnSound('$folder/$key', level, false);
		#end

		trace('The sound "$folder/$key" of a dialogue was not found');
		return null;
	}
}

/**
 * The box a line of dialogue is typed in: an animated sprite and the text over it.
 */
class VSliceDialogueBox extends FlxSpriteGroup
{
	public var id(default, null):String;
	public var typingCompleteCallback:Void->Void = null;

	var data:Dynamic;
	var boxSprite:FlxSprite = null;
	var textDisplay:FlxTypeText;
	var animOffsets:Map<String, Array<Float>> = [];
	var baseX:Float = 0;
	var baseY:Float = 0;

	public function new(id:String, data:Dynamic)
	{
		super();
		this.id = id;
		this.data = data;

		// Everything is placed from the middle of the screen, like on V-Slice
		var offsets:Array<Float> = pair(data.offsets);
		baseX = FlxG.width / 2 + offsets[0];
		baseY = FlxG.height / 2 + offsets[1];
		setPosition(baseX, baseY);
		scrollFactor.set();

		loadBox();
		loadText();
	}

	@:allow(cutscenes.VSliceSpeaker)
	static function pair(value:Dynamic):Array<Float>
	{
		var list:Array<Dynamic> = Std.isOfType(value, Array) ? value : [];
		return [(list.length > 0 && list[0] != null) ? list[0] : 0, (list.length > 1 && list[1] != null) ? list[1] : 0];
	}

	// "shared:dialogue/thing" -> "dialogue/thing"
	@:allow(cutscenes.VSliceSpeaker)
	static function stripLibrary(path:String):String
	{
		if(path == null) return '';

		var colon:Int = path.indexOf(':');
		return (colon > -1) ? path.substr(colon + 1) : path;
	}

	// The animations of a box or a speaker, with the offsets each one has
	@:allow(cutscenes.VSliceSpeaker)
	static function addAnimations(sprite:FlxSprite, animations:Dynamic, offsets:Map<String, Array<Float>>):Void
	{
		if(!Std.isOfType(animations, Array)) return;

		var list:Array<Dynamic> = animations;
		for (anim in list)
		{
			if(anim == null || anim.name == null) continue;

			var name:String = anim.name;
			var prefix:String = (anim.prefix != null) ? anim.prefix : name;
			var frameRate:Float = (anim.frameRate != null) ? anim.frameRate : 24;
			var looped:Bool = (anim.looped == true);
			var flipX:Bool = (anim.flipX == true);
			var flipY:Bool = (anim.flipY == true);

			var indices:Array<Int> = Std.isOfType(anim.frameIndices, Array) ? anim.frameIndices : null;
			if(indices != null && indices.length > 0) sprite.animation.addByIndices(name, prefix, indices, '', frameRate, looped, flipX, flipY);
			else sprite.animation.addByPrefix(name, prefix, frameRate, looped, flipX, flipY);

			offsets.set(name, pair(anim.offsets));
		}
	}

	// The animation with a name, or the closest thing to it there is: "talk-angry" falls back to "talk", then to "idle"
	@:allow(cutscenes.VSliceSpeaker)
	static function findAnimation(sprite:FlxSprite, name:String):String
	{
		if(sprite == null || sprite.frames == null || name == null) return null;

		while(true)
		{
			if(sprite.animation.exists(name)) return name;

			var dash:Int = name.lastIndexOf('-');
			if(dash > 0) name = name.substr(0, dash);
			else if(name != 'idle') name = 'idle';
			else return null;
		}
	}

	function loadBox():Void
	{
		var path:String = stripLibrary(data.assetPath);
		if(!Paths.fileExists('images/$path.png', IMAGE))
		{
			trace('The image "$path" of the dialogue box "$id" was not found');
			return;
		}

		boxSprite = new FlxSprite();
		boxSprite.frames = Paths.getSparrowAtlas(path);
		boxSprite.antialiasing = (ClientPrefs.data.antialiasing && data.isPixel != true);
		boxSprite.flipX = (data.flipX == true);
		boxSprite.flipY = (data.flipY == true);

		var size:Float = (data.scale != null) ? data.scale : 1;
		boxSprite.scale.set(size, size);
		boxSprite.updateHitbox();

		addAnimations(boxSprite, data.animations, animOffsets);
		add(boxSprite);
	}

	function loadText():Void
	{
		var info:Dynamic = (data.text != null) ? data.text : {};
		var offsets:Array<Float> = pair(info.offsets);
		var size:Int = (info.size != null) ? info.size : 32;
		var color:Null<FlxColor> = (info.color != null) ? FlxColor.fromString(info.color) : null;
		var shadowColor:Null<FlxColor> = (info.shadowColor != null) ? FlxColor.fromString(info.shadowColor) : null;
		var shadowWidth:Float = (info.shadowWidth != null) ? info.shadowWidth : 0;

		textDisplay = new FlxTypeText(offsets[0], offsets[1], (info.width != null) ? info.width : 300, '', size);
		textDisplay.setFormat(findFont(info.fontFamily), size, (color != null) ? color : FlxColor.BLACK, LEFT, SHADOW, (shadowColor != null) ? shadowColor : FlxColor.TRANSPARENT);
		textDisplay.borderSize = shadowWidth;
		textDisplay.antialiasing = (ClientPrefs.data.antialiasing && data.isPixel != true);
		textDisplay.completeCallback = onTypingComplete;

		var blip:openfl.media.Sound = VSliceConversation.findSound('sounds', 'pixelText');
		if(blip != null) textDisplay.sounds = [FlxG.sound.load(blip, 0.6)];

		add(textDisplay);
	}

	// Boxes name their font the way the system does ("Pixel Arial 11 Bold"), the game has them as files
	static function findFont(family:String):String
	{
		if(family == null || family.length < 1) return Paths.font('vcr.ttf');

		for (extension in ['', '.ttf', '.otf'])
		{
			var path:String = Paths.font(family + extension);
			#if sys
			if(sys.FileSystem.exists(path) && !sys.FileSystem.isDirectory(path)) return path;
			#end
		}

		if(family.toLowerCase().contains('pixel')) return Paths.font('pixel-latin.ttf');
		return family; //one the system has, if it does
	}

	function onTypingComplete():Void
	{
		if(typingCompleteCallback != null) typingCompleteCallback();
	}

	public function setText(text:String):Void
	{
		textDisplay.prefix = '';
		textDisplay.resetText(text);
		textDisplay.start(null, true);
	}

	/**
	 * Types something after what's already on the box.
	 */
	public function appendText(text:String):Void
	{
		textDisplay.prefix = textDisplay.text;
		textDisplay.resetText(text);
		textDisplay.start();
	}

	public function clearText():Void
	{
		textDisplay.prefix = '';
		textDisplay.resetText('');
	}

	/**
	 * Shows the rest of the line right away.
	 */
	public function skip():Void
	{
		textDisplay.skip();
	}

	public function stopTyping():Void
	{
		textDisplay.paused = true;
	}

	public function playAnimation(name:String, restart:Bool = false):Void
	{
		var found:String = findAnimation(boxSprite, name);
		if(found == null) return;

		boxSprite.animation.play(found, restart);

		var offsets:Array<Float> = animOffsets.get(found);
		setPosition(baseX + ((offsets != null) ? offsets[0] : 0), baseY + ((offsets != null) ? offsets[1] : 0));
	}

	public function getCurrentAnimation():String
	{
		return (boxSprite != null && boxSprite.animation.curAnim != null) ? boxSprite.animation.curAnim.name : '';
	}

	public function isAnimationFinished():Bool
	{
		return boxSprite == null || boxSprite.animation.curAnim == null || boxSprite.animation.curAnim.finished;
	}
}

/**
 * Who's saying a line of dialogue: a portrait with an animation for each mood.
 */
class VSliceSpeaker extends FlxSprite
{
	public var id(default, null):String;

	var data:Dynamic;
	var animOffsets:Map<String, Array<Float>> = [];
	var baseX:Float = 0;
	var baseY:Float = 0;

	public function new(id:String, data:Dynamic)
	{
		super();
		this.id = id;
		this.data = data;
		scrollFactor.set();

		var path:String = VSliceDialogueBox.stripLibrary(data.assetPath);
		if(!Paths.fileExists('images/$path.png', IMAGE))
		{
			trace('The image "$path" of the speaker "$id" was not found');
			return;
		}

		frames = Paths.getSparrowAtlas(path);
		antialiasing = (ClientPrefs.data.antialiasing && data.isPixel != true);
		flipX = (data.flipX == true);
		flipY = (data.flipY == true);

		// On the middle of the screen with its original size, then moved by its offsets and only then scaled: the order V-Slice does it in
		screenCenter();
		var offsets:Array<Float> = VSliceDialogueBox.pair(data.offsets);
		baseX = x + offsets[0];
		baseY = y + offsets[1];
		setPosition(baseX, baseY);

		var size:Float = (data.scale != null) ? data.scale : 1;
		scale.set(size, size);
		updateHitbox();

		VSliceDialogueBox.addAnimations(this, data.animations, animOffsets);
	}

	/**
	 * If its image was found.
	 */
	public var usable(get, never):Bool;
	function get_usable():Bool
		return frames != null;

	public function playAnimation(name:String, restart:Bool = false):Void
	{
		var found:String = VSliceDialogueBox.findAnimation(this, name);
		if(found == null) return;

		animation.play(found, restart);

		var offsets:Array<Float> = animOffsets.get(found);
		setPosition(baseX + ((offsets != null) ? offsets[0] : 0), baseY + ((offsets != null) ? offsets[1] : 0));
	}
}
