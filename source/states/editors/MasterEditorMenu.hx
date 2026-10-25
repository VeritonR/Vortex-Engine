package states.editors;

import backend.WeekData;

import objects.Character;

import states.MainMenuState;
import states.FreeplayState;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.effects.FlxFlicker;

class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		'Chart',
		'Character',
		'Stage',
		'Week',
		'Menu Character',
		'Dialogue',
		'Dialogue Portrait',
		'Note Splash',
		'Character Select'
	];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var directories:Array<String> = [null];

	private var grpSquares:FlxTypedGroup<FlxSprite>;
	private var selectorSquare:FlxSprite;
	private var lastMouseX:Float = 0;
	private var lastMouseY:Float = 0;
	private var selectedSomethin:Bool = false;

	private var curSelected = 0;
	private var curDirectory = 0;
	private var directoryTxt:FlxText;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('mainmenu/othermenus/bg'));
		bg.scrollFactor.set();
		bg.scale.set(1.3, 1.3);
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		grid.alpha = 0;
		FlxTween.tween(grid, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		add(grid);

		grpSquares = new FlxTypedGroup<FlxSprite>();
		add(grpSquares);

		selectorSquare = new FlxSprite().loadGraphic(Paths.image('mainmenu/othermenus/square_selector'));
		selectorSquare.antialiasing = ClientPrefs.data.antialiasing;
		add(selectorSquare);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		// two columns, with the rows closer together when there are more than four of them
		var rows:Int = Std.int(Math.max(4, Math.ceil(options.length / 2)));
		var rowSpacing:Float = Math.min(140, 560 / rows);
		var squareHeight:Int = Std.int(Math.min(120, rowSpacing - 15));
		for (i in 0...options.length)
		{
			var col:Int = Math.floor(i / rows);
			var row:Int = i % rows;

			var square:FlxSprite = new FlxSprite().loadGraphic(Paths.image('mainmenu/othermenus/square'));
			square.antialiasing = ClientPrefs.data.antialiasing;

			square.setGraphicSize(640, squareHeight);
			square.updateHitbox();
			
			square.x = -40 + (col * 720); 
			square.y = 80 + (row * rowSpacing);  
			grpSquares.add(square);

			var leText:Alphabet = new Alphabet(0, 0, options[i], true);

			leText.x = square.x + (square.width / 2) - (leText.width / 2);
			leText.y = square.y + (square.height / 2) - (leText.height / 2);
			grpTexts.add(leText);
		}

		var firstSquare = grpSquares.members[curSelected];
		selectorSquare.x = firstSquare.x - selectorSquare.width - 20;
		selectorSquare.y = firstSquare.y + (firstSquare.height / 2) - (selectorSquare.height / 2);
		
		#if MODS_ALLOWED
		var textBG:FlxSprite = new FlxSprite(-157, FlxG.height - 75).makeGraphic(FlxG.width + 325, 175, 0xFF000000);
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x + 25, textBG.y + 4, FlxG.width + 75, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Mods.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection();

		super.create();

		FlxG.camera.zoom = 0.8; 
		FlxG.mouse.visible = true; 

		var titleText:FlxText = new FlxText(0, -60, 0, "Editors", 48);
		titleText.setFormat(Paths.font("styledfont.ttf"), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.scrollFactor.set();
		titleText.screenCenter(X);
		add(titleText);

		infoText = new FlxText(-140, FlxG.height + 50, 0, '', 24);
		infoText.setFormat(Paths.font("styledfont.ttf"), 36, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.scrollFactor.set();
		add(infoText);
		updateInfoText();
	}

	var infoText:FlxText;
	function updateInfoText()
	{
		infoText.text = "selection: mouse / arrow keys   |   M: editor music " + (states.editors.content.EditorMusic.enabled ? "on" : "off");
	}

	function goToEditor() 
	{
		switch(options[curSelected]) {
			case 'Chart':
				LoadingState.loadAndSwitchState(new ChartingState(), false);
			case 'Character':
				LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
			case 'Stage':
				LoadingState.loadAndSwitchState(new StageEditorState());
			case 'Week':
				MusicBeatState.switchState(new WeekEditorState());
			case 'Menu Character':
				MusicBeatState.switchState(new MenuCharacterEditorState());
			case 'Dialogue':
				LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
			case 'Dialogue Portrait':
				LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
			case 'Note Splash':
				MusicBeatState.switchState(new NoteSplashEditorState());
			case 'Character Select':
				MusicBeatState.switchState(new CharSelectEditorState());
		}
		FlxG.sound.music.volume = 0;
		FreeplayState.destroyFreeplayVocals();
	}

	function selectOption() 
	{
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		flixel.tweens.FlxTween.tween(selectorSquare, {alpha: 0}, 0.4, {ease: flixel.tweens.FlxEase.cubeOut});

		for (num => square in grpSquares.members)
		{
			var item = grpTexts.members[num];
			
			if (num != curSelected) 
			{
				flixel.tweens.FlxTween.tween(square, {alpha: 0}, 0.4, {ease: flixel.tweens.FlxEase.cubeOut});
				flixel.tweens.FlxTween.tween(item, {alpha: 0}, 0.4, {ease: flixel.tweens.FlxEase.cubeOut});
			} 
			else 
			{
				item.alpha = 1;
				square.alpha = 1;

				flixel.effects.FlxFlicker.flicker(square, 1, 0.06, false, false);

				flixel.effects.FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:flixel.effects.FlxFlicker) {
					goToEditor();
				});
			}
		}
	}

	override function update(elapsed:Float)
	{
		if (!selectedSomethin)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);
			
			#if MODS_ALLOWED
			if(controls.UI_LEFT_P) changeDirectory(-1);
			if(controls.UI_RIGHT_P) changeDirectory(1);
			#end

			if (FlxG.keys.justPressed.M)
			{
				states.editors.content.EditorMusic.enabled = !states.editors.content.EditorMusic.enabled;
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				updateInfoText();
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MainMenuState());
			}
			else if (controls.ACCEPT)
			{
				selectOption();
			}
		}
		
		super.update(elapsed);

		if (!selectedSomethin) 
		{
			var mouseMoved = (FlxG.mouse.x != lastMouseX || FlxG.mouse.y != lastMouseY);
			lastMouseX = FlxG.mouse.x;
			lastMouseY = FlxG.mouse.y;

			for (num => square in grpSquares.members)
			{
				if (FlxG.mouse.overlaps(square)) 
				{
					if (mouseMoved && curSelected != num) {
						curSelected = num;
						changeSelection(0);
					}
					
					if (FlxG.mouse.justPressed) {
						curSelected = num;
						selectOption();
						return; // selectOption() takes over the alphas/selector from here
					}
				}
			}

			for (num => item in grpTexts.members)
			{
				var square = grpSquares.members[num];
				
				item.alpha = (num == curSelected) ? 1 : 0.6;
				square.alpha = (num == curSelected) ? 1 : 0.6;
			}

			var targetSquare = grpSquares.members[curSelected];
			var speed:Float = FlxMath.bound(elapsed * 12, 0, 1);
			
			var targetX = targetSquare.x - selectorSquare.width - 20;
			var targetY = targetSquare.y + (targetSquare.height / 2) - (selectorSquare.height / 2);
			
			selectorSquare.x = FlxMath.lerp(selectorSquare.x, targetX, speed);
			selectorSquare.y = FlxMath.lerp(selectorSquare.y, targetY, speed);
		}
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);
	}

	#if MODS_ALLOWED
	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;

		if(curDirectory < 0)
			curDirectory = directories.length - 1;
		if(curDirectory >= directories.length)
			curDirectory = 0;
	
		WeekData.setDirectoryFromWeek();
		if(directories[curDirectory] == null || directories[curDirectory].length < 1)
			directoryTxt.text = '< No Mod Directory Loaded >';
		else
		{
			Mods.currentModDirectory = directories[curDirectory];
			directoryTxt.text = '< Loaded Mod Directory: ' + Mods.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
	}
	#end
}