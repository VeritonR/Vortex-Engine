package states;

import backend.PlayableCharacters;

import flixel.FlxObject;
import flixel.graphics.FlxGraphic;
import flxanimate.data.AnimationData.Loop;

import objects.Character;
import objects.HealthIcon;

import openfl.display.BlendMode;

/**
 * Character Select, based on the V-Slice one.
 *
 * The characters come from `PlayableCharacters`: the "data/players" files of the base game and of the mods.
 * Each one is placed on a slot of the 3x3 grid.
 *
 * Art used by a player with the id "pico", all optional:
 * - `images/charSelect/picoChill/`: texture atlas with the frame labels "idle", "slidein", "slideout", "select" and "deselect"
 * - `images/charSelect/picoNametag.png`
 * - `images/freeplay/icons/picopixel.png` (+ .xml with "idle" and "confirm")
 * Without them it shows the player's character itself, no nametag and the character's health icon.
 */
class CharacterSelectState extends MusicBeatState
{
	static inline final GRID_SIZE:Int = 9;
	static inline final DEFAULT_SLOT:Int = 4;
	static inline final LOCKED:String = 'locked';

	var slots:Array<PlayableCharacter> = [for (i in 0...GRID_SIZE) null];
	var cursorX:Int = 0;
	var cursorY:Int = 0;
	var curSlot:Int = -1;

	var allowInput:Bool = false;
	var pressedSelect:Bool = false;
	var leaving:Bool = false;
	var selectTimer:FlxTimer = new FlxTimer();
	var deselectTimer:FlxTimer = new FlxTimer();

	// Who's on the stage
	var previewGroup:FlxTypedGroup<FlxSprite>;
	var gfGroup:FlxTypedGroup<FlxSprite>;
	var previews:Map<String, FlxSprite> = [];
	var gfSprites:Map<String, FlxSprite> = [];
	var curPreview:FlxSprite;
	var curGF:FlxSprite;

	// Interface
	var barthing:FlxAnimate;
	var dipshitBlur:FlxSprite;
	var dipshitBacking:FlxSprite;
	var chooseDipshit:FlxSprite;
	var nametag:FlxSprite;
	var nametagY:Float = 100;
	var icons:Array<FlxSprite> = [];

	var cursor:FlxSprite;
	var cursorLightBlue:FlxSprite;
	var cursorDarkBlue:FlxSprite;
	var cursorConfirmed:FlxSprite;
	var cursorDenied:FlxSprite;

	var camFollow:FlxObject;
	var autoFollow:Bool = false;

	var cutoutSize:Float = Math.max(0, (FlxG.width - 1280) / 2);

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		// done here instead of on super.create(), otherwise the camera that's following things would get replaced
		initPsychCamera();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Character Select", null);
		#end

		loadPlayers();

		var bg:FlxSprite = new FlxSprite(cutoutSize - 153, -140).loadGraphic(Paths.image('charSelect/charSelectBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0.1, 0.1);
		add(bg);

		var crowd:FlxAnimate = makeAtlas(cutoutSize, 0, 'charSelect/crowd');
		crowd.scrollFactor.set(0.3, 0.3);
		add(crowd);

		add(makeAtlas(cutoutSize - 2, 1, 'charSelect/charSelectStage'));

		var curtains:FlxSprite = new FlxSprite(cutoutSize - 212, -99).loadGraphic(Paths.image('charSelect/curtains'));
		curtains.antialiasing = ClientPrefs.data.antialiasing;
		curtains.scrollFactor.set(1.4, 1.4);
		add(curtains);

		barthing = makeAtlas(0, 0, 'charSelect/barThing');
		barthing.blend = BlendMode.MULTIPLY;
		barthing.scale.x = 2.5;
		barthing.scrollFactor.set();
		add(barthing);

		for (position in [[800, 250], [180, 240]])
		{
			var charLight:FlxSprite = new FlxSprite(cutoutSize + position[0], position[1]).loadGraphic(Paths.image('charSelect/charLight'));
			charLight.antialiasing = ClientPrefs.data.antialiasing;
			add(charLight);
		}

		gfGroup = new FlxTypedGroup<FlxSprite>();
		add(gfGroup);
		previewGroup = new FlxTypedGroup<FlxSprite>();
		add(previewGroup);

		var speakers:FlxAnimate = makeAtlas(cutoutSize - 10, 0, 'charSelect/charSelectSpeakers');
		speakers.scrollFactor.set(1.8, 1.8);
		speakers.scale.set(1.05, 1.05);
		add(speakers);

		var fgBlur:FlxSprite = new FlxSprite(cutoutSize - 125, 170).loadGraphic(Paths.image('charSelect/foregroundBlur'));
		fgBlur.antialiasing = ClientPrefs.data.antialiasing;
		fgBlur.blend = BlendMode.MULTIPLY;
		add(fgBlur);

		dipshitBlur = new FlxSprite(cutoutSize + 419, -65);
		dipshitBlur.frames = Paths.getSparrowAtlas('charSelect/dipshitBlur');
		dipshitBlur.animation.addByPrefix('idle', 'CHOOSE vertical offset instance 1', 24, true);
		dipshitBlur.animation.play('idle');
		dipshitBlur.blend = BlendMode.ADD;
		add(dipshitBlur);

		dipshitBacking = new FlxSprite(cutoutSize + 423, -17);
		dipshitBacking.frames = Paths.getSparrowAtlas('charSelect/dipshitBacking');
		dipshitBacking.animation.addByPrefix('idle', 'CHOOSE horizontal offset instance 1', 24, true);
		dipshitBacking.animation.play('idle');
		dipshitBacking.blend = BlendMode.ADD;
		add(dipshitBacking);

		chooseDipshit = new FlxSprite(cutoutSize + 426, -13).loadGraphic(Paths.image('charSelect/chooseDipshit'));
		add(chooseDipshit);

		nametag = new FlxSprite();
		add(nametag);

		for (sprite in [dipshitBlur, dipshitBacking, chooseDipshit, nametag])
		{
			sprite.antialiasing = ClientPrefs.data.antialiasing;
			sprite.scrollFactor.set();
		}

		createCursor();
		createIcons();

		// Everything slides into place
		barthing.y += 80;
		FlxTween.tween(barthing, {y: barthing.y - 80}, 1.3, {ease: FlxEase.expoOut});
		dipshitBacking.y += 210;
		FlxTween.tween(dipshitBacking, {y: dipshitBacking.y - 210}, 1.1, {ease: FlxEase.expoOut});
		chooseDipshit.y += 200;
		FlxTween.tween(chooseDipshit, {y: chooseDipshit.y - 200}, 1, {ease: FlxEase.expoOut});
		dipshitBlur.y += 220;
		FlxTween.tween(dipshitBlur, {y: dipshitBlur.y - 220}, 1.2, {ease: FlxEase.expoOut});
		nametagY += 200;
		FlxTween.num(nametagY, nametagY - 200, 1, {ease: FlxEase.expoOut}, function(value:Float) nametagY = value);
		for (icon in icons)
		{
			icon.y += 300;
			FlxTween.tween(icon, {y: icon.y - 300}, 1, {ease: FlxEase.expoOut});
		}

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.screenCenter();
		camFollow.y -= 150;
		add(camFollow);
		FlxG.camera.follow(camFollow, LOCKON, 1);
		FlxG.camera.snapToTarget();
		FlxTween.tween(camFollow, {y: camFollow.y + 150}, 1.5, {ease: FlxEase.expoOut, onComplete: function(_)
		{
			autoFollow = true;
			FlxG.camera.followLerp = 0.05;
		}});

		// the music's tempo, the idles and the cursor follow it
		Conductor.bpmChangeMap = [];
		Conductor.bpm = 90;
		FlxG.sound.playMusic(Paths.music('stayFunky'), 1);

		// Starts on the character that's currently picked
		var startSlot:Int = slots.indexOf(PlayableCharacters.getCurrent());
		if(startSlot < 0) startSlot = (slots[DEFAULT_SLOT] != null) ? DEFAULT_SLOT : 0;
		cursorX = (startSlot % 3) - 1;
		cursorY = Math.floor(startSlot / 3) - 1;
		changeSelection(false);
		updateCursor(0, true);

		super.create();

		new FlxTimer().start(0.5, function(_) allowInput = true);
	}

	// Each player asks for a slot, if it's taken it goes to the next free one
	function loadPlayers()
	{
		PlayableCharacters.clearCache();
		for (player in PlayableCharacters.list())
		{
			if(!player.unlocked) continue;

			var slot:Int = Std.int(FlxMath.bound(player.position, 0, GRID_SIZE - 1));
			var tries:Int = 0;
			while(slots[slot] != null && tries++ < GRID_SIZE)
				slot = (slot + 1) % GRID_SIZE;

			if(slots[slot] == null) slots[slot] = player;
			else trace('No slot left on Character Select for "${player.id}"');
		}
	}

	function makeAtlas(x:Float, y:Float, key:String):FlxAnimate
	{
		var atlas:FlxAnimate = new FlxAnimate(x, y);
		atlas.antialiasing = ClientPrefs.data.antialiasing;
		try
		{
			Paths.loadAnimateAtlas(atlas, key);
			atlas.anim.play('');
		}
		catch(e:Dynamic)
		{
			trace('Could not load the atlas "$key": $e');
		}
		return atlas;
	}

	// Runs a function with the player's mod as the current one, so its files are found
	function withPlayerMod(player:PlayableCharacter, func:Void->Void)
	{
		var lastMod:String = Mods.currentModDirectory;
		if(player != null && player.mod != null && player.mod.length > 0) Mods.currentModDirectory = player.mod;

		try
		{
			func();
		}
		catch(e:Dynamic)
		{
			trace('Error loading the Character Select art of "${(player != null) ? player.id : LOCKED}": $e');
		}
		Mods.currentModDirectory = lastMod;
	}

	// ------------------------------------------------------------------------------------------
	// Cursor and icons
	// ------------------------------------------------------------------------------------------

	function createCursor()
	{
		cursorDarkBlue = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		cursorDarkBlue.color = 0xFF3C74F7;
		cursorDarkBlue.blend = BlendMode.SCREEN;

		cursorLightBlue = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		cursorLightBlue.color = 0xFF3EBBFF;
		cursorLightBlue.blend = BlendMode.SCREEN;

		cursor = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		cursor.color = 0xFFFFFF00;
		FlxTween.color(cursor, 0.2, 0xFFFFFF00, 0xFFFFCC00, {type: PINGPONG});

		cursorConfirmed = new FlxSprite();
		cursorConfirmed.frames = Paths.getSparrowAtlas('charSelect/charSelectorConfirm');
		cursorConfirmed.animation.addByPrefix('idle', 'cursor ACCEPTED instance 1', 24, true);
		cursorConfirmed.visible = false;

		cursorDenied = new FlxSprite();
		cursorDenied.frames = Paths.getSparrowAtlas('charSelect/charSelectorDenied');
		cursorDenied.animation.addByPrefix('idle', 'cursor DENIED instance 1', 24, false);
		cursorDenied.animation.finishCallback = function(_) cursorDenied.visible = false;
		cursorDenied.visible = false;

		for (sprite in [cursorDarkBlue, cursorLightBlue, cursor, cursorConfirmed, cursorDenied])
		{
			sprite.antialiasing = ClientPrefs.data.antialiasing;
			sprite.scrollFactor.set();
			add(sprite);
		}
	}

	function updateCursor(elapsed:Float, snap:Bool = false)
	{
		var targetX:Float = (110 * cursorX) + (FlxG.width / 2) - cursor.width / 2 - 16;
		var targetY:Float = (110 * cursorY) + (FlxG.height / 2) - cursor.height / 2 - 48;

		if(snap)
		{
			for (sprite in [cursor, cursorLightBlue, cursorDarkBlue])
				sprite.setPosition(targetX, targetY);
		}
		else
		{
			// each one trails behind the one before
			cursor.x = FlxMath.lerp(targetX, cursor.x, Math.exp(-elapsed * 46));
			cursor.y = FlxMath.lerp(targetY, cursor.y, Math.exp(-elapsed * 46));
			cursorLightBlue.x = FlxMath.lerp(cursor.x, cursorLightBlue.x, Math.exp(-elapsed * 23));
			cursorLightBlue.y = FlxMath.lerp(cursor.y, cursorLightBlue.y, Math.exp(-elapsed * 23));
			cursorDarkBlue.x = FlxMath.lerp(targetX, cursorDarkBlue.x, Math.exp(-elapsed * 11.5));
			cursorDarkBlue.y = FlxMath.lerp(targetY, cursorDarkBlue.y, Math.exp(-elapsed * 11.5));
		}

		cursorConfirmed.setPosition(cursor.x - 2, cursor.y - 4);
		cursorDenied.setPosition(cursor.x - 2, cursor.y - 4);
	}

	function setCursorConfirmed(confirmed:Bool)
	{
		cursorConfirmed.visible = confirmed;
		if(confirmed) cursorConfirmed.animation.play('idle', true);
		cursor.visible = cursorLightBlue.visible = cursorDarkBlue.visible = !confirmed;
	}

	function createIcons()
	{
		for (i in 0...GRID_SIZE)
		{
			var player:PlayableCharacter = slots[i];
			var icon:FlxSprite = null;
			if(player != null) withPlayerMod(player, function() icon = makePlayerIcon(player));
			if(icon == null) icon = makeLock(i);

			icon.x += cutoutSize + 450 + (i % 3) * 107;
			icon.y += 120 + Math.floor(i / 3) * 127;
			icon.scrollFactor.set();
			icon.ID = (player != null) ? 0 : 1; //same as V-Slice: 0 is a character, 1 a lock
			icons.push(icon);
			add(icon);
		}
	}

	public static function makePlayerIcon(player:PlayableCharacter):FlxSprite
	{
		// Pixel icon, the same ones V-Slice uses on Freeplay
		var key:String = 'freeplay/icons/${player.id}pixel';
		if(Paths.fileExists('images/$key.png', IMAGE))
		{
			var icon:FlxSprite = new FlxSprite();
			if(Paths.fileExists('images/$key.xml', TEXT))
			{
				icon.frames = Paths.getSparrowAtlas(key);
				icon.animation.addByPrefix('idle', 'idle0', 10, true);
				icon.animation.addByPrefix('confirm', 'confirm0', 10, false);
				icon.animation.play('idle');
			}
			else icon.loadGraphic(Paths.image(key));

			icon.antialiasing = false;
			icon.setGraphicSize(128, 128);
			icon.updateHitbox();
			icon.scale.set(2, 2);
			return icon;
		}

		// Health icon of its character as a replacement
		var character:String = PlayableCharacters.getMainCharacter(player);
		var healthIcon:HealthIcon = new HealthIcon(getHealthIconName(player, (character != null) ? character : player.id), true);
		healthIcon.scale.set(0.65, 0.65);
		healthIcon.updateHitbox();
		healthIcon.x = (128 - healthIcon.width) / 2;
		healthIcon.y = (128 - healthIcon.height) / 2;
		return healthIcon;
	}

	public static function getHealthIconName(player:PlayableCharacter, character:String):String
	{
		var icon:String = 'face';
		var lastMod:String = Mods.currentModDirectory;
		var characterMod:String = PlayableCharacters.getCharacterMod(player, character);
		if(characterMod != null) Mods.currentModDirectory = characterMod;

		try
		{
			#if MODS_ALLOWED
			var vslice:Dynamic = PolymodCompat.getCharacterFile(character, true);
			if(vslice != null) icon = vslice.healthicon;
			else
			#end
			{
				var raw:String = Paths.getTextFromFile('characters/$character.json');
				if(raw != null) icon = haxe.Json.parse(raw).healthicon;
			}
		}
		catch(e:Dynamic) {}

		Mods.currentModDirectory = lastMod;
		return (icon != null) ? icon : 'face';
	}

	public static function makeLock(index:Int):FlxSprite
	{
		var lockIndex:Int = (index >= 4) ? index - 2 : Std.int(Math.min(index + 1, 3));

		var lock:FlxSprite = new FlxSprite(3, -2);
		lock.frames = Paths.getSparrowAtlas('charSelect/locks');
		lock.animation.addByIndices('idle', 'LOCK FULL $lockIndex instance 1', [0], '', 24);
		lock.animation.addByIndices('selected', 'LOCK FULL $lockIndex instance 1', [3, 4, 5], '', 24, false);
		lock.animation.addByIndices('clicked', 'LOCK FULL $lockIndex instance 1', [9, 10, 11, 12, 13, 14, 15], '', 24, false);
		lock.animation.play('idle');
		lock.antialiasing = ClientPrefs.data.antialiasing;
		return lock;
	}

	function updateIcons()
	{
		for (index => icon in icons)
		{
			var selected:Bool = (index == curSlot);
			if(icon.ID == 1) //lock
			{
				var anim:String = icon.animation.name;
				if(!selected) icon.animation.play('idle');
				else if(anim == 'idle') icon.animation.play('selected');
				continue;
			}

			if(Std.isOfType(icon, HealthIcon)) continue;

			icon.scale.set(selected ? 2.6 : 2, selected ? 2.6 : 2);
			if(icon.animation.exists('confirm'))
			{
				if(selected && pressedSelect && icon.animation.name == 'idle') icon.animation.play('confirm');
				else if(!(selected && pressedSelect) && icon.animation.name != 'idle') icon.animation.play('idle');
			}
		}
	}

	// ------------------------------------------------------------------------------------------
	// Characters on the stage
	// ------------------------------------------------------------------------------------------

	function getPreview(player:PlayableCharacter):FlxSprite
	{
		var key:String = (player != null) ? player.id : LOCKED;
		if(previews.exists(key)) return previews.get(key);

		var preview:FlxSprite = null;
		withPlayerMod(player, function()
		{
			var atlasKey:String = 'charSelect/${key}Chill';
			if(Paths.fileExists('images/$atlasKey/Animation.json', TEXT))
				preview = new CharSelectAtlas(cutoutSize, 0, atlasKey, onPreviewAnimFinished);
			else if(player != null)
				preview = makeCharacterPreview(player);
		});

		if(preview != null)
		{
			preview.visible = false;
			previewGroup.add(preview);
		}
		previews.set(key, preview);
		return preview;
	}

	// For players without a texture atlas made for this menu: the character they play as
	function makeCharacterPreview(player:PlayableCharacter):FlxSprite
	{
		var character:String = PlayableCharacters.getMainCharacter(player);
		if(character == null) character = player.id;

		var lastMod:String = Mods.currentModDirectory;
		var characterMod:String = PlayableCharacters.getCharacterMod(player, character);
		if(characterMod != null) Mods.currentModDirectory = characterMod;

		var x:Float = chooseDipshit.x + chooseDipshit.width - 25;
		var y:Float = FlxG.height * 0.15 + 125;

		var preview:Character = new Character(x, y, character, true);
		preview.dance();

		Mods.currentModDirectory = lastMod;
		return preview;
	}

	function getGF(player:PlayableCharacter):FlxSprite
	{
		if(player == null || player.gfAsset == null) return null;
		if(gfSprites.exists(player.gfAsset)) return gfSprites.get(player.gfAsset);

		var gf:FlxSprite = null;
		withPlayerMod(player, function()
		{
			var key:String = player.gfAsset;
			if(Paths.fileExists('images/$key/Animation.json', TEXT))
				gf = new CharSelectAtlas(cutoutSize, 0, key, onGFAnimFinished);
			else
			{
				// spritesheet with the same name inside the folder
				var sheet:String = key + '/' + key.substr(key.lastIndexOf('/') + 1);
				if(Paths.fileExists('images/$sheet.png', IMAGE))
				{
					gf = new FlxSprite(cutoutSize, 260);
					gf.frames = Paths.getSparrowAtlas(sheet);
					gf.animation.addByPrefix('idle', 'idle', 12, false);
					gf.animation.play('idle');
					gf.antialiasing = ClientPrefs.data.antialiasing;
				}
			}
		});

		if(gf != null)
		{
			gf.visible = false;
			gfGroup.add(gf);
		}
		gfSprites.set(player.gfAsset, gf);
		return gf;
	}

	// Returns false if the sprite isn't an atlas or doesn't have that animation
	function playPreviewAnim(sprite:FlxSprite, name:String, looped:Bool = false):Bool
	{
		var atlas:CharSelectAtlas = Std.downcast(sprite, CharSelectAtlas);
		return atlas != null && atlas.playAnim(name, looped);
	}

	function onPreviewAnimFinished(atlas:CharSelectAtlas, name:String)
	{
		switch(name)
		{
			case 'slidein':
				if(!atlas.playAnim('slidein idle point')) atlas.playAnim('idle');
			case 'slidein idle point', 'cannot select Label', 'unlock':
				atlas.playAnim('idle');
			case 'deselect':
				if(!atlas.playAnim('deselect loop start')) atlas.playAnim('idle');
			case 'slideout':
				if(atlas != curPreview) atlas.visible = false;
			case 'idle':
				if(atlas == previews.get(LOCKED)) atlas.playAnim('idle'); //Mr. Static doesn't wait for the beat
		}
	}

	function onGFAnimFinished(atlas:CharSelectAtlas, name:String)
	{
		if(name == 'deselect') atlas.playAnim('idle');
	}

	function changeSelection(playSlide:Bool = true)
	{
		var slot:Int = (cursorX + 1) + (cursorY + 1) * 3;
		if(slot == curSlot) return;

		curSlot = slot;
		var player:PlayableCharacter = slots[slot];

		// Who was there leaves
		var lastPreview:FlxSprite = curPreview;
		curPreview = getPreview(player);
		if(lastPreview != null && lastPreview != curPreview)
		{
			FlxTween.cancelTweensOf(lastPreview);
			if(!playSlide) lastPreview.visible = false;
			else if(!playPreviewAnim(lastPreview, 'slideout'))
			{
				if(Std.isOfType(lastPreview, CharSelectAtlas)) lastPreview.visible = false;
				else FlxTween.tween(lastPreview, {alpha: 0}, 0.15, {onComplete: function(_) if(lastPreview != curPreview) lastPreview.visible = false});
			}
		}

		// And the new one comes in
		if(curPreview != null)
		{
			FlxTween.cancelTweensOf(curPreview);
			curPreview.visible = true;
			curPreview.alpha = 1;
			if(!playPreviewAnim(curPreview, playSlide ? 'slidein' : 'idle') && !playPreviewAnim(curPreview, 'idle') && playSlide)
			{
				curPreview.alpha = 0;
				FlxTween.tween(curPreview, {alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
			}
		}

		var lastGF:FlxSprite = curGF;
		curGF = getGF(player);
		if(lastGF != null && lastGF != curGF) lastGF.visible = false;
		if(curGF != null)
		{
			curGF.visible = true;
			if(lastGF != curGF) playPreviewAnim(curGF, 'idle');
		}

		// Nametag
		var graphic:FlxGraphic = null;
		withPlayerMod(player, function() graphic = getNametag(player));
		nametag.visible = (graphic != null);
		if(graphic != null)
		{
			nametag.loadGraphic(graphic);
			nametag.updateHitbox();
			nametag.scale.set(0.77, 0.77);
		}
	}

	public static function getNametag(player:PlayableCharacter):FlxGraphic
	{
		var key:String = 'charSelect/lockedNametag';
		if(player != null) key = 'charSelect/' + ((player.id == PlayableCharacters.DEFAULT) ? 'boyfriend' : player.id) + 'Nametag';

		return Paths.fileExists('images/$key.png', IMAGE) ? Paths.image(key) : null;
	}

	// ------------------------------------------------------------------------------------------

	var holdTimers:Array<Float> = [0, 0, 0, 0]; //left, down, up, right
	override function update(elapsed:Float)
	{
		if(FlxG.sound.music != null) Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);

		if(allowInput && !leaving)
		{
			if(!pressedSelect)
			{
				var moved:Bool = false;
				var held:Array<Bool> = [controls.UI_LEFT, controls.UI_DOWN, controls.UI_UP, controls.UI_RIGHT];
				var pressed:Array<Bool> = [controls.UI_LEFT_P, controls.UI_DOWN_P, controls.UI_UP_P, controls.UI_RIGHT_P];
				for (i in 0...4)
				{
					holdTimers[i] = held[i] ? holdTimers[i] + elapsed : 0;
					if(pressed[i])
					{
						moveCursor(i);
						moved = true;
					}
				}
				if(moved) FlxG.sound.play(Paths.sound('CS_select'), 0.7);

				if(controls.BACK) exit(false);
				else if(controls.ACCEPT) confirm();
			}
			else if(controls.BACK) deselect();
		}

		updateIcons();
		updateCursor(elapsed);

		nametag.setPosition(cutoutSize + 1008 - nametag.width / 2, nametagY - nametag.height / 2);

		if(autoFollow && !leaving)
		{
			camFollow.screenCenter();
			camFollow.x += cursorX * 10;
			camFollow.y += cursorY * 10;
		}

		// Characters used as preview keep dancing
		var char:Character = Std.downcast(curPreview, Character);
		if(char != null && char.isAnimationFinished()) char.dance();
	}

	function moveCursor(direction:Int)
	{
		switch(direction)
		{
			case 0: cursorX--;
			case 1: cursorY++;
			case 2: cursorY--;
			case 3: cursorX++;
		}
		cursorX = FlxMath.wrap(cursorX, -1, 1);
		cursorY = FlxMath.wrap(cursorY, -1, 1);

		cursorDenied.visible = false;
		changeSelection();
	}

	// Holding a direction keeps moving the cursor to the music
	override function stepHit()
	{
		super.stepHit();
		if(!allowInput || pressedSelect || leaving) return;

		var moved:Bool = false;
		for (i in 0...4)
		{
			if(holdTimers[i] < 0.5) continue;

			moveCursor(i);
			moved = true;
		}
		if(moved) FlxG.sound.play(Paths.sound('CS_select'), 0.7);
	}

	override function beatHit()
	{
		super.beatHit();

		// the idles are a single bop, repeated to the music
		for (sprite in [curPreview, curGF])
		{
			if(sprite == null) continue;

			var atlas:CharSelectAtlas = Std.downcast(sprite, CharSelectAtlas);
			if(atlas != null)
			{
				if(atlas.curAnim == 'idle' && atlas.animFinished && (sprite != curGF || curBeat % 2 == 0))
					atlas.playAnim('idle');
			}
			else if(sprite == curGF && curBeat % 2 == 0)
				sprite.animation.play('idle', true);
		}
	}

	function confirm()
	{
		var player:PlayableCharacter = slots[curSlot];
		if(player == null)
		{
			// Nobody there
			playPreviewAnim(curPreview, 'cannot select Label');
			FlxG.sound.play(Paths.sound('CS_locked'));
			if(icons[curSlot].animation.exists('clicked')) icons[curSlot].animation.play('clicked', true);

			cursorDenied.visible = true;
			cursorDenied.animation.play('idle', true);
			return;
		}

		pressedSelect = true;
		setCursorConfirmed(true);
		FlxG.sound.play(Paths.sound('CS_confirm'), 0.5);

		FlxTween.cancelTweensOf(FlxG.sound.music);
		FlxTween.tween(FlxG.sound.music, {pitch: 0.1}, 1, {ease: FlxEase.quadInOut});
		FlxTween.tween(FlxG.sound.music, {volume: 0}, 1.5, {ease: FlxEase.quadInOut});

		playPreviewAnim(curPreview, 'select');
		playPreviewAnim(curGF, 'confirm', true);

		selectTimer.start(1.5, function(_) exit(true));
	}

	function deselect()
	{
		pressedSelect = false;
		selectTimer.cancel();
		setCursorConfirmed(false);
		FlxG.sound.play(Paths.sound('cancelMenu'));

		FlxTween.cancelTweensOf(FlxG.sound.music);
		FlxTween.tween(FlxG.sound.music, {pitch: 1, volume: 1}, 1, {ease: FlxEase.quartInOut});

		if(!playPreviewAnim(curPreview, 'deselect')) playPreviewAnim(curPreview, 'idle');
		if(!playPreviewAnim(curGF, 'deselect')) playPreviewAnim(curGF, 'idle');

		// back to dancing once the music is back to normal, like on V-Slice ("deselect loop start" goes on until then)
		deselectTimer.start(1, function(_)
		{
			var atlas:CharSelectAtlas = Std.downcast(curPreview, CharSelectAtlas);
			if(atlas == null || (atlas.curAnim != 'deselect' && atlas.curAnim != 'deselect loop start')) return;

			atlas.playAnim('idle');
			playPreviewAnim(curGF, 'idle');
		});
	}

	function exit(saveSelection:Bool)
	{
		if(leaving) return;
		leaving = true;
		autoFollow = false;

		if(saveSelection && slots[curSlot] != null)
		{
			PlayableCharacters.select(slots[curSlot].id);
			ClientPrefs.saveSettings();
		}
		else
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxTween.tween(FlxG.sound.music, {volume: 0}, 0.7, {ease: FlxEase.quadInOut});
		}

		for (sprite in [cursor, cursorLightBlue, cursorDarkBlue, cursorConfirmed])
			FlxTween.tween(sprite, {alpha: 0}, 0.8, {ease: FlxEase.expoOut});

		FlxTween.tween(barthing, {y: barthing.y + 80}, 0.8, {ease: FlxEase.backIn});
		FlxTween.num(nametagY, nametagY + 80, 0.8, {ease: FlxEase.backIn}, function(value:Float) nametagY = value);
		FlxTween.tween(dipshitBacking, {y: dipshitBacking.y + 210}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(chooseDipshit, {y: chooseDipshit.y + 200}, 0.8, {ease: FlxEase.backIn});
		FlxTween.tween(dipshitBlur, {y: dipshitBlur.y + 220}, 0.8, {ease: FlxEase.backIn});
		for (icon in icons)
			FlxTween.tween(icon, {y: icon.y + 300}, 0.8, {ease: FlxEase.backIn});

		FlxG.camera.followLerp = 1;
		FlxTween.cancelTweensOf(camFollow);
		FlxTween.tween(camFollow, {y: camFollow.y - 150}, 0.8, {ease: FlxEase.backIn});
		FlxG.camera.fade(FlxColor.BLACK, 0.8, false);

		new FlxTimer().start(0.8, function(_)
		{
			// the sound object keeps its pitch between songs
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.pitch = 1;
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

			FlxTransitionableState.skipNextTransIn = true;
			if(ClientPrefs.data.freeplayStyle == 'V-Slice')
			{
				FreeplayStateVslice.fromCharSelect = true;
				MusicBeatState.switchState(new FreeplayStateVslice());
			}
			else
				MusicBeatState.switchState(new FreeplayState());
		});
	}
}

/**
 * Texture atlas whose animations are the frame labels of its main timeline, like the Character Select ones from V-Slice.
 */
class CharSelectAtlas extends FlxAnimate
{
	public var curAnim(default, null):String = null;
	public var animFinished(default, null):Bool = true;

	var onFinish:CharSelectAtlas->String->Void;

	public function new(x:Float, y:Float, key:String, ?onFinish:CharSelectAtlas->String->Void)
	{
		super(x, y);
		this.onFinish = onFinish;
		antialiasing = ClientPrefs.data.antialiasing;

		Paths.loadAnimateAtlas(this, key);
		stageAroundOrigin = true; //(V-Slice's Character Select atlases are all placed by their files: see PsychFlxAnimate)
		if(anim.curSymbol != null)
		{
			for (label in anim.curSymbol.getFrameLabelNames())
				addAnimByFrameLabel(label, label);
		}
	}

	public function hasAnim(name:String):Bool
	{
		@:privateAccess
		return anim.animsMap.exists(name);
	}

	public function playAnim(name:String, looped:Bool = false):Bool
	{
		if(!hasAnim(name)) return false;

		anim.play(name, true);
		anim.loopType = looped ? Loop : PlayOnce;
		curAnim = name;
		animFinished = false;

		// animations can change after the sprite's update, without this the next draw would use what was left from the last one
		anim.update(0);
		return true;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!animFinished && curAnim != null && anim.finished)
		{
			animFinished = true;
			if(onFinish != null) onFinish(this, curAnim);
		}
	}
}
