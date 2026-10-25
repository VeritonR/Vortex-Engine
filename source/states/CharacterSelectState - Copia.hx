package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.group.FlxGroup.FlxTypedGroup;
import backend.Paths;
import backend.ClientPrefs;
import backend.Mods;
import objects.Character;
import objects.HealthIcon;
import flxanimate.FlxAnimate;
import openfl.utils.AssetType;

#if sys
	import sys.FileSystem;
	import sys.io.File;
#end

class CharacterSelectState extends MusicBeatState
{
	var skinList:Array<String> = [];
	var skinScales:Map<String, Float> = new Map<String, Float>();
	var iconGroup:FlxTypedGroup<HealthIcon>;
	var charPreview:FlxSprite;
	var bg:FlxSprite;
	var curtains:FlxSprite;
	
	var selectorBox:FlxSprite;
	var selectorBoxTrail:FlxSprite; 
	
	var curSelected:Int = 0;
	var onStart:Bool = true;
	var crowd:FlxAnimate;
	var barthing:FlxAnimate;
	var stageSpr:FlxAnimate;
	var gfChill:FlxSprite;
	var dipshitBacking:FlxSprite;
	var dipshitBlur:FlxSprite;
	var chooseDipshit:FlxSprite; 
	var charNameSpr:FlxSprite;
	var cutoutSize:Float = Math.max(0, (FlxG.width - 1280) / 2);

	var idleDelayTimer:Float = 0;
	var isWaitingToIdle:Bool = false;

	var isConfirming:Bool = false;
	var confirmTimer:FlxTimer;
	var prevSelected:Int = 0;

	var columns:Int = 3;
	var spacing:Float = 100;
	var gridStartX:Float = 0;
	var gridStartY:Float = 0;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		bg = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelectBG'));
		bg.x = cutoutSize + -153;
		bg.y = -140;
		bg.antialiasing = ClientPrefs.data.antialiasing;
    	bg.scrollFactor.set(0.1, 0.1);
		add(bg);
		bg.y += 160;
    	FlxTween.tween(bg, {y: bg.y - 160}, 1.2, {ease: FlxEase.expoOut});

		crowd = new FlxAnimate(cutoutSize, 0, Paths.getPath('images/charSelect/crowd'));
		crowd.antialiasing = ClientPrefs.data.antialiasing;
		crowd.anim.play(''); 
    	crowd.scrollFactor.set(0.3, 0.3);
		add(crowd);
		crowd.y += 160;
    	FlxTween.tween(crowd, {y: crowd.y - 160}, 1.2, {ease: FlxEase.expoOut});

		stageSpr = new FlxAnimate(cutoutSize - 2, 1, Paths.getPath('images/charSelect/charSelectStage'));
		stageSpr.antialiasing = ClientPrefs.data.antialiasing;
		stageSpr.anim.play(''); 
		add(stageSpr);
		stageSpr.y += 160;
    	FlxTween.tween(stageSpr, {y: stageSpr.y - 160}, 1.2, {ease: FlxEase.expoOut});

		var charLight:FlxSprite = new FlxSprite().loadGraphic(Paths.image('charSelect/charLight'));
		charLight.x = cutoutSize + 800;
		charLight.y = 250;
		charLight.antialiasing = ClientPrefs.data.antialiasing;
		add(charLight);
		charLight.y += 160;
    	FlxTween.tween(charLight, {y: charLight.y - 160}, 1.2, {ease: FlxEase.expoOut});

		var charLightGF:FlxSprite = new FlxSprite().loadGraphic(Paths.image('charSelect/charLight'));
		charLightGF.x = cutoutSize + 180;
		charLightGF.y = 240;
		charLightGF.antialiasing = ClientPrefs.data.antialiasing;
		add(charLightGF);
		charLightGF.y += 160;
    	FlxTween.tween(charLightGF, {y: charLightGF.y - 160}, 1.2, {ease: FlxEase.expoOut});

		curtains = new FlxSprite().loadGraphic(Paths.image('charSelect/curtains'));
		curtains.x = cutoutSize + -212;
		curtains.y = -99;
		curtains.antialiasing = ClientPrefs.data.antialiasing;
		add(curtains);
		curtains.y += 160;
    	FlxTween.tween(curtains, {y: curtains.y - 160}, 1.2, {ease: FlxEase.expoOut});

		gfChill = new FlxSprite(cutoutSize, 260);
        gfChill.frames = Paths.getSparrowAtlas('charSelect/gfChill/gfChill');
        gfChill.animation.addByPrefix('idle', 'idle', 12, true);
		gfChill.animation.play('idle', false);
    	gfChill.scrollFactor.set(0.1, 0.1);
		gfChill.antialiasing = ClientPrefs.data.antialiasing;
		add(gfChill);
		gfChill.y += 160;
    	FlxTween.tween(gfChill, {y: gfChill.y - 160}, 1.2, {ease: FlxEase.expoOut});

		barthing = new FlxAnimate(cutoutSize - 2, 40, Paths.getPath('images/charSelect/barThing'));
		barthing.antialiasing = ClientPrefs.data.antialiasing;
		barthing.anim.play(''); 
    	barthing.blend = MULTIPLY;
		barthing.scale.set(2.5, 1);
		barthing.updateHitbox();
    	barthing.scrollFactor.set(0, 0);
    	add(barthing);
		barthing.y += 80;
		FlxTween.tween(barthing, {y: barthing.y - 80}, 1.3, {ease: FlxEase.expoOut});

		dipshitBlur = new FlxSprite(cutoutSize + 423, -70);
        dipshitBlur.frames = Paths.getSparrowAtlas('charSelect/dipshitBlur');
        dipshitBlur.animation.addByPrefix('idle', 'CHOOSE vertical offset instance 1', 12, true);
    	dipshitBlur.blend = ADD;
		dipshitBlur.animation.play('idle', false);
    	dipshitBlur.scrollFactor.set();
		dipshitBlur.antialiasing = ClientPrefs.data.antialiasing;
		add(dipshitBlur);
		dipshitBlur.y += 220;
    	FlxTween.tween(dipshitBlur, {y: dipshitBlur.y - 220}, 1.2, {ease: FlxEase.expoOut});
		
		dipshitBacking = new FlxSprite(cutoutSize + 423, -17);
        dipshitBacking.frames = Paths.getSparrowAtlas('charSelect/dipshitBacking');
        dipshitBacking.animation.addByPrefix('idle', 'CHOOSE horizontal offset instance 1', 12, true);
    	dipshitBacking.blend = ADD;
		dipshitBacking.animation.play('idle');
    	dipshitBacking.scrollFactor.set();
		dipshitBacking.antialiasing = ClientPrefs.data.antialiasing;
		add(dipshitBacking);
		dipshitBacking.y += 210;
    	FlxTween.tween(dipshitBacking, {y: dipshitBacking.y - 210}, 1.1, {ease: FlxEase.expoOut});

		chooseDipshit = new FlxSprite().loadGraphic(Paths.image('charSelect/chooseDipshit'));
		chooseDipshit.x = cutoutSize + 426;
		chooseDipshit.y = -13;
		chooseDipshit.antialiasing = ClientPrefs.data.antialiasing;
		add(chooseDipshit);	
		chooseDipshit.y += 200;
    	FlxTween.tween(chooseDipshit, {y: chooseDipshit.y - 200}, 1, {ease: FlxEase.expoOut});
		
		var skinListMap:Map<String, Float> = new Map<String, Float>();

		function parseLine(rawLine:String) {
			var cName = rawLine;
			var cScale:Float = -1; 
			
			if (rawLine.indexOf('(') != -1 && rawLine.indexOf(')') != -1) {
				var start = rawLine.indexOf('(');
				var end = rawLine.indexOf(')');
				cName = StringTools.trim(rawLine.substring(0, start));
				var parsed = Std.parseFloat(StringTools.trim(rawLine.substring(start + 1, end)));
				if (!Math.isNaN(parsed)) cScale = parsed;
			}
			skinListMap.set(cName, cScale);
		}

		#if sys
		var skinListPaths:Array<String> = [
			'assets/shared/characters/skins/skinList.txt',
			'assets/characters/skins/skinList.txt',
			'mods/characters/skins/skinList.txt'
		];

		if (FileSystem.exists('mods/')) {
			for (folder in FileSystem.readDirectory('mods/')) {
				var modDir:String = 'mods/' + folder + '/';
				if (FileSystem.isDirectory(modDir)) {
					skinListPaths.push(modDir + 'characters/skins/skinList.txt');
				}
			}
		}

		for (path in skinListPaths) {
			if (FileSystem.exists(path)) {
				try {
					var txtRaw = File.getContent(path);
					if (txtRaw != null && txtRaw.length > 0) {
						var lines = txtRaw.split('\n');
						for (line in lines) {
							var cleanLine = StringTools.trim(line);
							if (cleanLine.length > 0) parseLine(cleanLine);
						}
					}
				} catch(e:Dynamic) {}
			}
		}
		#end

		if (skinListMap.keys().hasNext() == false) {
			var txtRaw = Paths.getTextFromFile('characters/skins/skinList.txt');
			if (txtRaw != null && txtRaw.length > 0) {
				var lines = txtRaw.split('\n');
				for (line in lines) {
					var cleanLine = StringTools.trim(line);
					if (cleanLine.length > 0) parseLine(cleanLine);
				}
			}
		}

		var internalSkins:Array<String> = ['pico-playable']; // Se quiser colocar mais, separe por vírgula: ['pico-player', 'outro-char']
		
		for (internalSkin in internalSkins) {
			if (!skinListMap.exists(internalSkin)) {
				skinListMap.set(internalSkin, -1);
			}
		}

		skinList.push('default');
		skinScales.set('default', -1);

		for (skin in skinListMap.keys()) {
			if (skin != 'default') {
				skinList.push(skin);
				skinScales.set(skin, skinListMap.get(skin));
			}
		}

		while (skinList.length < 9) {
			skinList.push('default');
		}

		if (skinList.contains(ClientPrefs.data.playerSkin)) {
			curSelected = skinList.indexOf(ClientPrefs.data.playerSkin);
		}

		iconGroup = new FlxTypedGroup<HealthIcon>();
		add(iconGroup);

		gridStartX = (FlxG.width / 2) - spacing - 50;
		gridStartY = (FlxG.height / 2) - spacing - 20; 

		var oldModDir:String = Mods.currentModDirectory;

		for (i in 0...skinList.length) {
			var charName = skinList[i];
			var iconName = getCharacterIcon(charName);
			
			#if sys
			var targetMod:String = null;
			if (FileSystem.exists('mods/')) {
				for (folder in FileSystem.readDirectory('mods/')) {
					var modDir:String = 'mods/' + folder + '/';
					if (FileSystem.isDirectory(modDir) && FileSystem.exists(modDir + 'characters/' + charName + '.json')) {
						targetMod = folder;
						break;
					}
				}
			}
			if (targetMod != null) Mods.currentModDirectory = targetMod;
			#end

			var icon:HealthIcon = new HealthIcon(iconName, true);
			#if sys
			if (targetMod != null) {
				var iconPath = 'mods/' + targetMod + '/images/icons/icon-' + iconName + '.png';
				if (!FileSystem.exists(iconPath)) {
					iconPath = 'mods/' + targetMod + '/images/icons/' + iconName + '.png';
				}
				
				if (FileSystem.exists(iconPath)) {
					var bmp = openfl.display.BitmapData.fromFile(iconPath);
					if (bmp != null) {
						var graphic = flixel.graphics.FlxGraphic.fromBitmapData(bmp);
						icon.loadGraphic(graphic, true, 150, 150);
						icon.updateHitbox();
						
						var framesCount = Math.floor(graphic.width / 150);
						if (framesCount >= 3) {
							icon.animation.add(iconName, [0, 1, 2], 0, false, true);
						} else {
							icon.animation.add(iconName, [0, 1], 0, false, true);
						}
						icon.animation.play(iconName);
					}
				}
			}
			#end

			icon.scale.set(0.7, 0.7);
			icon.updateHitbox();
			
			Mods.currentModDirectory = oldModDir;

			var col = i % columns;
			var row = Math.floor(i / columns);
			
			var cx = gridStartX + (col * spacing);
			var cy = gridStartY + (row * spacing);

			icon.x = cx - (icon.width / 2);
			icon.y = cy - (icon.height / 2);
			icon.ID = i;
			iconGroup.add(icon);

			
		}

		//iconGroup.forEach(function(member:HealthIcon) {
			//member.y -= 110;
			//FlxTween.tween(member, {y: member.y + 110}, 1.4, {ease: FlxEase.backIn});
		//});

		selectorBoxTrail = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		selectorBoxTrail.color = FlxColor.CYAN;
		selectorBoxTrail.alpha = 0.5;
		selectorBoxTrail.antialiasing = ClientPrefs.data.antialiasing;
		selectorBoxTrail.scale.set(0.75, 0.75);
		selectorBoxTrail.updateHitbox();
		add(selectorBoxTrail);
		//selectorBoxTrail.y -= 200;
    	//FlxTween.tween(selectorBoxTrail, {y: selectorBoxTrail.y + 200}, 1, {ease: FlxEase.expoOut});

		selectorBox = new FlxSprite().loadGraphic(Paths.image('charSelect/charSelector'));
		selectorBox.antialiasing = ClientPrefs.data.antialiasing;
		selectorBox.scale.set(0.75, 0.75);
		selectorBox.updateHitbox();
		add(selectorBox);
		//selectorBox.y -= 200;
    	//FlxTween.tween(selectorBox, {y: selectorBox.y + 200}, 1, {ease: FlxEase.expoOut});

		charNameSpr = new FlxSprite();
		charNameSpr.antialiasing = ClientPrefs.data.antialiasing;
		add(charNameSpr);

		FlxG.sound.playMusic(Paths.music('stayFunky'), 1);

		updateSelection(0);
		
		selectorBoxTrail.x = selectorBox.x;
		selectorBoxTrail.y = selectorBox.y;
		
		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!isConfirming && !isLeaving) {
			if (controls.UI_LEFT_P) updateSelection(-1);
			if (controls.UI_RIGHT_P) updateSelection(1);
			if (controls.UI_UP_P) updateSelection(-3);
			if (controls.UI_DOWN_P) updateSelection(3);
		}

		if (controls.BACK && !isLeaving) {
			if (isConfirming) {
				isConfirming = false;
				if (confirmTimer != null) confirmTimer.cancel();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				
				// selection is locked while confirming, only reload the preview if it somehow changed
				var diff = prevSelected - curSelected;
				if (diff != 0) updateSelection(diff);

				FlxTween.cancelTweensOf(FlxG.sound.music);
				FlxTween.tween(FlxG.sound.music, {pitch: 1, volume: 1}, 1, {ease: FlxEase.quadInOut});
			} else {
				isLeaving = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				switchToFreeplay();
			}
		}

		if (controls.ACCEPT && !isConfirming && !isLeaving) {
			FlxG.sound.play(Paths.sound('CS_confirm'), 0.5);
			
			isConfirming = true;
			prevSelected = curSelected; 

			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxTween.tween(FlxG.sound.music, {pitch: 0.1}, 1, {ease: FlxEase.quadInOut});
        	FlxTween.tween(FlxG.sound.music, {volume: 0.0}, 1.5, {ease: FlxEase.quadInOut});

			confirmTimer = new FlxTimer().start(3.0, function(tmr:FlxTimer) {
				goToMainState();
			});
		}
		
		if (charPreview != null) {
			if (Std.isOfType(charPreview, Character)) {
				var char:Character = cast charPreview;
				if (char.animation.curAnim != null && char.animation.curAnim.finished) {
					char.dance();
				}
			} 
			else {
				if (isWaitingToIdle) {
					idleDelayTimer += elapsed;
					if (idleDelayTimer >= 0.25) { 
						idleDelayTimer = 0;
						isWaitingToIdle = false;
						if (charPreview.animation.getByName('idle') != null) {
							charPreview.animation.play('idle', true);
						}
					}
				} else {
					if (charPreview.animation.curAnim != null && charPreview.animation.curAnim.finished && charPreview.animation.curAnim.name == 'idle') {
						isWaitingToIdle = true;
						idleDelayTimer = 0;
					}
				}
			}
		}
	}

	function updateSelection(change:Int = 0)
	{
		if (change != 0) FlxG.sound.play(Paths.sound('CS_select'), 0.5);
		
		curSelected += change;
		if (curSelected < 0) curSelected = skinList.length - 1;
		if (curSelected >= skinList.length) curSelected = 0;

		var targetIcon:HealthIcon = null;
		iconGroup.forEach(function(icon:HealthIcon) {
			if (icon.ID == curSelected) {
				targetIcon = icon;
			}
		});

		if (targetIcon != null) {
			var iconCenterX = targetIcon.x + (targetIcon.width / 2);
			var iconCenterY = targetIcon.y + (targetIcon.height / 2);

			selectorBox.x = iconCenterX - (selectorBox.width / 2) + 30;
			selectorBox.y = iconCenterY - (selectorBox.height / 2 + -10);

			FlxTween.cancelTweensOf(selectorBoxTrail);
			FlxTween.tween(selectorBoxTrail, {x: selectorBox.x, y: selectorBox.y}, 0.20, {ease: FlxEase.sineOut});
		}

		if (charPreview != null) {
			var oldChar = charPreview;
			
			if (change != 0) {
				var exitDir = (change < 0) ? -1 : 1;
				
				FlxTween.tween(oldChar, {x: oldChar.x + (250 * exitDir), alpha: 0}, 0.25, {
					ease: FlxEase.cubeOut,
					onComplete: function(twn:FlxTween) {
						remove(oldChar);
						oldChar.destroy();
					}
				});
			} else {
				remove(oldChar);
				oldChar.destroy();
			}
			charPreview = null;
		}

		isWaitingToIdle = false;
		idleDelayTimer = 0;

		var charName = skinList[curSelected];
		var customScale = skinScales.get(charName);
		var loadedCustom:Bool = false;

		var targetX:Float = chooseDipshit.x + chooseDipshit.width - 25; 
		var targetY:Float = FlxG.height * 0.15 + 125;

		var startX:Float = targetX;
		if (change != 0) {
			var enterDir = (change < 0) ? 1 : -1;
			startX = targetX + (250 * enterDir);
		}

		// Isolamos a verificação do TargetMod para usarmos tanto no Char quanto no Nome
		var targetMod:String = null;
		#if sys
		if (FileSystem.exists('mods/')) {
			for (folder in FileSystem.readDirectory('mods/')) {
				var modDir:String = 'mods/' + folder + '/';
				if (FileSystem.isDirectory(modDir) && FileSystem.exists(modDir + 'characters/' + charName + '.json')) {
					targetMod = folder;
					break;
				}
			}
		}
		#end

		if (charName == 'default') {
			var spr = new FlxSprite(startX, targetY);
			spr.frames = Paths.getSparrowAtlas('charSelect/randomChill');
			
			if (spr.frames != null) {
				if (customScale != null && customScale != -1) {
					spr.scale.set(customScale, customScale);
					spr.updateHitbox();
				}

				spr.animation.addByPrefix('idle', 'idle', 16, true);
				spr.animation.play('idle');
				spr.antialiasing = ClientPrefs.data.antialiasing;
				
				charPreview = spr;
				loadedCustom = true;
			}
		} 
		else {
			#if sys
			var directoriesToCheck:Array<String> = [
				'assets/shared/images/skins/',
				'mods/images/skins/'
			];

			if (targetMod != null) {
				directoriesToCheck.push('mods/' + targetMod + '/images/skins/');
			}

			for (dir in directoriesToCheck) {
				var pngPath:String = dir + charName + '.png';
				var xmlPath:String = dir + charName + '.xml';

				if (FileSystem.exists(pngPath) && FileSystem.exists(xmlPath)) {
					try {
						var bitmapData = openfl.display.BitmapData.fromFile(pngPath);
						var xmlString = File.getContent(xmlPath);

						if (bitmapData != null && xmlString != null) {
							var spr = new FlxSprite(startX, targetY);
							
							var graphic = flixel.graphics.FlxGraphic.fromBitmapData(bitmapData);
							spr.frames = flixel.graphics.frames.FlxAtlasFrames.fromSparrow(graphic, xmlString);
							
							if (spr.frames != null) {
								if (customScale != null && customScale != -1) {
									spr.scale.set(customScale, customScale);
									spr.updateHitbox();
								}

								spr.animation.addByPrefix('idle', 'idle', 16, false);
								spr.animation.play('idle');
								spr.antialiasing = ClientPrefs.data.antialiasing;
								
								charPreview = spr;
								loadedCustom = true;
								break;
							}
						}
					} catch(e:Dynamic) {}
				}
			}
			#end
		}

		if (!loadedCustom) {
			var oldMod:String = Mods.currentModDirectory;
			if (targetMod != null) Mods.currentModDirectory = targetMod;

			var defaultChar = new Character(startX, targetY, charName, true);
			
			if (customScale != null && customScale != -1) {
				defaultChar.scale.set(customScale, customScale);
				defaultChar.updateHitbox();
			}

			defaultChar.dance();
			charPreview = defaultChar;

			Mods.currentModDirectory = oldMod;
		}

		charPreview.antialiasing = ClientPrefs.data.antialiasing;
		
		if (change != 0) {
			charPreview.alpha = 0;
			FlxTween.tween(charPreview, {x: targetX, alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
		}
		 
		var blurIndex = members.indexOf(dipshitBlur);
		if (blurIndex != -1) {
			insert(blurIndex, charPreview);
		} else {
			add(charPreview);
		}
		
		if (onStart) {
			charPreview.y = targetY - 160;
    		FlxTween.tween(charPreview, {y: charPreview.y + 160}, 1.4, {ease: FlxEase.expoOut});
			onStart = false; 
		}

		function applyNameGraphic() {
			var nameLoaded = false;
			#if sys
			var pathsToCheck:Array<String> = [
				'assets/shared/images/skins/' + charName + '-name.png',
				'mods/images/skins/' + charName + '-name.png'
			];
			if (targetMod != null) {
				pathsToCheck.push('mods/' + targetMod + '/images/skins/' + charName + '-name.png');
			}

			for (path in pathsToCheck) {
				if (FileSystem.exists(path)) {
					var bmp = openfl.display.BitmapData.fromFile(path);
					if (bmp != null) {
						charNameSpr.loadGraphic(flixel.graphics.FlxGraphic.fromBitmapData(bmp));
						nameLoaded = true;
						break;
					}
				}
			}
			#end

			if (!nameLoaded) {
				charNameSpr.loadGraphic(Paths.image('charSelect/lockedNametag'));
				charNameSpr.x = barthing.x + 900;
				charNameSpr.y = barthing.y + 100;
			} else {
				charNameSpr.x = barthing.x + 850;
				charNameSpr.y = barthing.y + 100;
			}
			
			charNameSpr.scale.x = 0.8;
			charNameSpr.updateHitbox();
		}

		if (charNameSpr != null) {
			if (change != 0) {
				FlxTween.cancelTweensOf(charNameSpr.scale);
				
				FlxTween.tween(charNameSpr.scale, {y: 0}, 0.12, {
					ease: FlxEase.expoIn,
					onComplete: function(twn:FlxTween) {
						applyNameGraphic();
						
						FlxTween.tween(charNameSpr.scale, {y: 0.8}, 0.12, {
							ease: FlxEase.expoOut
						});
					}
				});
			} else {
				applyNameGraphic();
				charNameSpr.scale.y = 0.8;
				charNameSpr.updateHitbox();
			}
		}
	}

	function getCharacterIcon(charName:String):String {
		if (charName == 'default') return 'face';

		#if sys
		var jsonPaths:Array<String> = [
			'assets/shared/characters/' + charName + '.json',
			'assets/characters/' + charName + '.json',
			'mods/characters/' + charName + '.json'
		];

		if (FileSystem.exists('mods/')) {
			for (folder in FileSystem.readDirectory('mods/')) {
				var modDir:String = 'mods/' + folder + '/';
				if (FileSystem.isDirectory(modDir)) {
					jsonPaths.push(modDir + 'characters/' + charName + '.json');
				}
			}
		}

		for (path in jsonPaths) {
			if (FileSystem.exists(path)) {
				try {
					var rawJson = File.getContent(path);
					if (rawJson != null && rawJson.length > 0) {
						var parsedJson:Dynamic = haxe.Json.parse(rawJson);
						if (parsedJson != null && parsedJson.healthicon != null) {
							return parsedJson.healthicon;
						}
					}
				} catch(e:Dynamic) {}
			}
		}
		#end

		var path:String = 'characters/' + charName + '.json';
		var rawJson = Paths.getTextFromFile(path);
		if(rawJson != null && rawJson.length > 0) {
			try {
				var parsedJson:Dynamic = haxe.Json.parse(rawJson);
				if (parsedJson != null && parsedJson.healthicon != null) {
					return parsedJson.healthicon;
				}
			} catch(e:Dynamic) {}
		}
		
		return 'face';
	}

	override function beatHit()
	{
		super.beatHit();
		if (curBeat % 2 == 0)
		{
			gfChill.animation.play('idle');
			dipshitBlur.animation.play('idle');
		}
	}

	var isLeaving:Bool = false;
	function switchToFreeplay():Void
	{
		if (ClientPrefs.data.freeplayStyle == 'V-Slice')
			MusicBeatState.switchState(new states.FreeplayStateVslice());
		else
			MusicBeatState.switchState(new states.FreeplayState());

		// the FlxSound keeps its pitch between songs, without this the menu music plays slowed down after confirming
		if (FlxG.sound.music != null)
		{
			FlxTween.cancelTweensOf(FlxG.sound.music);
			FlxG.sound.music.pitch = 1;
		}
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
	}

	function goToMainState():Void
	{
		isConfirming = true;
		isLeaving = true;

		if (barthing != null) FlxTween.tween(barthing, {y: barthing.y - 80}, 1.4, {ease: FlxEase.backIn});
		if (dipshitBacking != null) FlxTween.tween(dipshitBacking, {y: dipshitBacking.y - 210}, 1.4, {ease: FlxEase.backIn});
		if (dipshitBlur != null) FlxTween.tween(dipshitBlur, {y: dipshitBlur.y - 210}, 1.4, {ease: FlxEase.backIn});
		if (chooseDipshit != null) FlxTween.tween(chooseDipshit, {y: chooseDipshit.y - 200}, 1.4, {ease: FlxEase.backIn});
		
		if (stageSpr != null) FlxTween.tween(stageSpr, {y: stageSpr.y - 150}, 1.6, {ease: FlxEase.backIn});
		if (crowd != null) FlxTween.tween(crowd, {y: crowd.y - 150}, 1.6, {ease: FlxEase.backIn});
		if (bg != null) FlxTween.tween(bg, {y: bg.y - 150}, 1.6, {ease: FlxEase.backIn});
		if (charPreview != null) FlxTween.tween(charPreview, {y: charPreview.y - 150}, 1.6, {ease: FlxEase.backIn});
		if (curtains != null) FlxTween.tween(curtains, {y: curtains.y - 150}, 1.6, {ease: FlxEase.backIn});
		if (gfChill != null) FlxTween.tween(gfChill, {y: gfChill.y - 150}, 1.6, {ease: FlxEase.backIn});
		
		iconGroup.forEach(function(member:HealthIcon) {
			FlxTween.tween(member, {y: member.y - 300}, 1.4, {ease: FlxEase.backIn});
		});

		if (selectorBox != null) FlxTween.tween(selectorBox, {y: selectorBox.y - 300}, 1.4, {ease: FlxEase.backIn});
		if (selectorBoxTrail != null) FlxTween.tween(selectorBoxTrail, {y: selectorBoxTrail.y - 300}, 1.4, {ease: FlxEase.backIn});
		if (charPreview != null) FlxTween.tween(charPreview, {alpha: 0.75}, 1.4, {ease: FlxEase.cubeOut});
		if (gfChill != null) FlxTween.tween(gfChill, {alpha: 0.75}, 1.4, {ease: FlxEase.cubeOut});

		FlxG.camera.fade(FlxColor.BLACK, 1.3, false);

		new FlxTimer().start(1.3, function(tmr:FlxTimer) {
			if (skinList[curSelected] == 'default') {
				ClientPrefs.data.playerSkin = ''; 
			} else {
				ClientPrefs.data.playerSkin = skinList[curSelected];
			}
			
			ClientPrefs.saveSettings();
			switchToFreeplay();
		});
	}
}