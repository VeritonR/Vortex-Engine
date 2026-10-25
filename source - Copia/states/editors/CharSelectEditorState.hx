package states.editors;

import haxe.Json;
import flixel.FlxBasic;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileReference;

import backend.DirectPlay;
import backend.OrderedJson;
import backend.PlayableCharacters;
import backend.VSliceConvert;
import objects.AtlasSprite;
import objects.freeplay.FreeplayDJ;
import states.CharacterSelectState.CharSelectAtlas;
import states.editors.content.Prompt;

/**
 * Editor of the players of Character Select ("data/players/(id).json", V-Slice's format), with the menu as it shows them:
 *
 * - Player: its name, its place on the grid (with its icon there), if songs of nobody show up for it, if it can be picked
 *   and the characters it owns.
 * - Girlfriend: who sits with it (a texture atlas), and the other values of hers.
 * - Freeplay DJ: who's on the turntable of the V-Slice Freeplay menu, and where each of its animations is drawn.
 * - The animations of the player, the girlfriend and the DJ can be watched one by one, frame by frame.
 * - Results: what the results screen shows for each rank (the animations, where they are and when they start) and its music.
 *
 * Saving gives the player's file with what was changed, as it is otherwise (what the engine doesn't use stays in it).
 * Same idea as P-Slice's Character Select editor.
 */
class CharSelectEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static inline final GRID_SIZE:Int = 9;
	static inline final VIEW_CHAR_SELECT:Int = 0;
	static inline final VIEW_DJ:Int = 1;
	static inline final VIEW_RESULTS:Int = 2;
	static final VIEW_TABS:Array<String> = ['Player', 'Freeplay DJ', 'Results'];

	var playerId:String;
	var player:PlayableCharacter;
	var data:Dynamic;
	var filePath:String;
	var lineBreak:String = '\n'; //(the file's own, kept when it's saved)
	var unsaved:Bool = false;

	var view:Int = VIEW_CHAR_SELECT;
	var charSelectScene:FlxTypedGroup<FlxBasic>;
	var djScene:FlxTypedGroup<FlxBasic>;
	var resultsScene:FlxTypedGroup<FlxBasic>;

	var gfSprite:CharSelectAtlas;
	var playerSprite:CharSelectAtlas;
	var nametag:FlxSprite;
	var icons:FlxTypedGroup<FlxSprite>;
	var playerIcon:FlxSprite;
	var dj:FreeplayDJ;

	var mainBox:PsychUIBox;
	var previewBox:PsychUIBox;
	var statusText:FlxText;
	var helpText:FlxText;

	public function new(?playerId:String)
	{
		super();
		this.playerId = playerId;
	}

	override function create()
	{
		FlxG.mouse.visible = true;
		FlxG.camera.bgColor = FlxColor.BLACK;
		if(FlxG.sound.music != null) FlxG.sound.music.volume = 0;

		// (quiet while the results' music is being listened to)
		var editorMusic:states.editors.content.EditorMusic = new states.editors.content.EditorMusic(1, 10);
		editorMusic.busy = function() return FlxG.sound.music != null && FlxG.sound.music.playing && FlxG.sound.music.volume > 0;
		add(editorMusic);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Character Select Editor", null);
		#end

		PlayableCharacters.clearCache();
		if(playerId == null) playerId = PlayableCharacters.getCurrent().id;
		player = PlayableCharacters.get(playerId);
		if(player == null)
		{
			playerId = PlayableCharacters.DEFAULT;
			player = PlayableCharacters.get(playerId);
		}
		loadData();

		charSelectScene = new FlxTypedGroup<FlxBasic>();
		add(charSelectScene);
		djScene = new FlxTypedGroup<FlxBasic>();
		add(djScene);
		resultsScene = new FlxTypedGroup<FlxBasic>();
		add(resultsScene);

		withPlayerMod(function()
		{
			makeCharSelectScene();
			makeDJScene();
			makeResultsScene();
		});

		statusText = new FlxText(10, FlxG.height - 70, 700, '', 16);
		statusText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		statusText.scrollFactor.set();
		add(statusText);

		helpText = new FlxText(10, 10, 620, '', 14);
		helpText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		helpText.scrollFactor.set();
		add(helpText);

		makeMainBox();
		makePreviewBox();
		setView(VIEW_CHAR_SELECT);

		super.create();
	}

	// ------------------------------------------------------------------------------------------
	// The player's file
	// ------------------------------------------------------------------------------------------

	function loadData():Void
	{
		data = null;
		filePath = PlayableCharacters.getFile(playerId);
		#if sys
		if(filePath != null && sys.FileSystem.exists(filePath))
		{
			try
			{
				// (the file itself, without what other mods add to it with their "_merge" folders: saving would put that in it)
				var raw:String = sys.io.File.getContent(filePath);
				if(raw.fastCodeAt(0) == 0xFEFF) raw = raw.substr(1);
				data = OrderedJson.parse(raw); //(saved again with its fields in the same order)
				lineBreak = (raw.indexOf('\r\n') > -1) ? '\r\n' : '\n';
			}
			catch(e:Dynamic)
			{
				trace('Could not read "$filePath": $e');
			}
		}
		#end

		// the default Boyfriend has no file, one is made the same way V-Slice's is
		if(data == null)
		{
			data = {
				version: '1.0.0',
				name: player.name,
				ownedChars: player.ownedChars.copy(),
				showUnownedChars: player.showUnownedChars,
				unlocked: player.unlocked,
				charSelect: {position: player.position},
				freeplayDJ: player.freeplayDJ,
				results: player.results
			};
			if(player.gfAsset != null) data.charSelect.gf = {assetPath: player.gfAsset, animInfoPath: 'charSelect/gfAnimInfo', visualizer: false};
		}
		if(data.charSelect == null) data.charSelect = {position: player.position};
	}

	var gfData(get, never):Dynamic;
	function get_gfData():Dynamic
	{
		if(data.charSelect.gf == null) data.charSelect.gf = {assetPath: '', animInfoPath: '', visualizer: false};
		return data.charSelect.gf;
	}

	// Runs a function with the player's mod as the current one, so its files are found
	function withPlayerMod(func:Void->Void):Void
	{
		var lastMod:String = Mods.currentModDirectory;
		if(player != null && player.mod != null && player.mod.length > 0) Mods.currentModDirectory = player.mod;
		try
		{
			func();
		}
		catch(e:Dynamic)
		{
			trace('Character Select editor: $e');
		}
		Mods.currentModDirectory = lastMod;
	}

	// ------------------------------------------------------------------------------------------
	// What's shown
	// ------------------------------------------------------------------------------------------

	function makeCharSelectScene():Void
	{
		var bg:FlxSprite = new FlxSprite(-153, -140).loadGraphic(Paths.image('charSelect/charSelectBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		charSelectScene.add(bg);

		for (key in ['charSelect/crowd', 'charSelect/charSelectStage'])
		{
			var atlas:FlxAnimate = new FlxAnimate(0, 0);
			atlas.antialiasing = ClientPrefs.data.antialiasing;
			try
			{
				Paths.loadAnimateAtlas(atlas, key);
				atlas.anim.play('', true);
				atlas.anim.loopType = Loop;
			}
			catch(e:Dynamic) {}
			charSelectScene.add(atlas);
		}

		var curtains:FlxSprite = new FlxSprite(-212, -99).loadGraphic(Paths.image('charSelect/curtains'));
		curtains.antialiasing = ClientPrefs.data.antialiasing;

		reloadGF();
		reloadPlayerSprite();
		charSelectScene.add(curtains);

		nametag = new FlxSprite();
		nametag.antialiasing = ClientPrefs.data.antialiasing;
		charSelectScene.add(nametag);
		reloadNametag();

		icons = new FlxTypedGroup<FlxSprite>();
		charSelectScene.add(icons);
		reloadIcons();
	}

	function reloadGF():Void
	{
		if(gfSprite != null)
		{
			charSelectScene.remove(gfSprite, true);
			gfSprite.destroy();
			gfSprite = null;
		}

		var key:String = VSliceConvert.stripLibrary(VSliceConvert.str(gfData.assetPath, ''));
		if(key.length < 1 || !Paths.fileExists('images/$key/Animation.json', TEXT)) return;

		gfSprite = new CharSelectAtlas(0, 0, key);
		gfSprite.playAnim('idle', true); //(looped)
		// (behind the player, in front of the stage)
		charSelectScene.insert(Std.int(Math.min(3, charSelectScene.length)), gfSprite);
	}

	function reloadPlayerSprite():Void
	{
		if(playerSprite != null)
		{
			charSelectScene.remove(playerSprite, true);
			playerSprite.destroy();
			playerSprite = null;
		}

		var key:String = 'charSelect/${playerId}Chill';
		if(!Paths.fileExists('images/$key/Animation.json', TEXT)) return;

		playerSprite = new CharSelectAtlas(0, 0, key);
		playerSprite.playAnim('idle', true);
		var place:Int = (gfSprite != null) ? charSelectScene.members.indexOf(gfSprite) + 1 : Std.int(Math.min(3, charSelectScene.length));
		charSelectScene.insert(place, playerSprite);
	}

	function reloadNametag():Void
	{
		var graphic:flixel.graphics.FlxGraphic = CharacterSelectState.getNametag(player);
		nametag.visible = (graphic != null);
		if(graphic == null) return;

		nametag.loadGraphic(graphic);
		nametag.updateHitbox();
		nametag.scale.set(0.77, 0.77);
		nametag.setPosition(1008 - nametag.width / 2, 100 - nametag.height / 2);
	}

	// The grid, with the player's icon on the slot it asks for and locks on the others
	function reloadIcons():Void
	{
		for (icon in icons.members) if(icon != null) icon.destroy();
		icons.clear();

		var slot:Int = slotOf();
		for (i in 0...GRID_SIZE)
		{
			var icon:FlxSprite = null;
			if(i == slot)
			{
				icon = CharacterSelectState.makePlayerIcon(player);
				playerIcon = icon;
			}
			if(icon == null) icon = CharacterSelectState.makeLock(i);

			icon.x += 450 + (i % 3) * 107;
			icon.y += 120 + Math.floor(i / 3) * 127;
			icons.add(icon);
		}
	}

	inline function slotOf():Int
		return Std.int(FlxMath.bound(VSliceConvert.num(data.charSelect.position, 0), 0, GRID_SIZE - 1));

	function makeDJScene():Void
	{
		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, 0xFF20152E);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		djScene.add(bg);

		var floorLine:FlxSprite = new FlxSprite(0, 366).makeGraphic(FlxG.width, 2, 0x55FFFFFF);
		djScene.add(floorLine);
		var middleLine:FlxSprite = new FlxSprite(640, 0).makeGraphic(2, FlxG.height, 0x55FFFFFF);
		djScene.add(middleLine);

		reloadDJ();
	}

	function reloadDJ():Void
	{
		if(dj != null)
		{
			djScene.remove(dj, true);
			dj.destroy();
			dj = null;
		}
		if(data.freeplayDJ == null) return;

		// (made with the file being edited: what's changed on it is what the DJ shows)
		var edited:PlayableCharacter = Reflect.copy(player);
		edited.freeplayDJ = data.freeplayDJ;
		dj = new FreeplayDJ(edited);
		dj.editorMode = true;
		var names:Array<String> = dj.animationNames();
		if(names.length > 0) dj.previewAnimation(names.contains('idle') ? 'idle' : names[0], true);
		djScene.add(dj);
	}

	function setView(value:Int):Void
	{
		view = value;
		charSelectScene.visible = charSelectScene.active = (view == VIEW_CHAR_SELECT);
		djScene.visible = djScene.active = (view == VIEW_DJ);
		resultsScene.visible = resultsScene.active = (view == VIEW_RESULTS);
		if(previewBox != null) previewBox.visible = previewBox.active = (view != VIEW_RESULTS && mainBox.visible);
		if(mainBox != null && (view != VIEW_CHAR_SELECT || mainBox.selectedName == 'Freeplay DJ' || mainBox.selectedName == 'Results'))
			mainBox.selectedName = VIEW_TABS[view];

		if(view == VIEW_RESULTS)
		{
			helpText.text = 'ARROWS: move the selected animation (hold SHIFT for 10) | SPACE: play the screen | R: from the start\n'
				+ 'TAB: switch view | H: hide the boxes | CTRL+S: save | ESC: back';
			playResults(false);
		}
		else
		{
			stopResults();
			if(FlxG.sound.music != null) FlxG.sound.music.volume = 0; //(the results' music, if it was played)
			helpText.text = 'UP/DOWN: animation | LEFT/RIGHT: frame (pauses, hold SHIFT for 10) | SPACE: play\n'
				+ 'I/J/K/L: DJ animation offsets (hold SHIFT for 10) | TAB: switch view | H: hide the boxes | CTRL+S: save | ESC: back';
		}
		reloadPreviewTargets();
	}

	inline function nextView():Void
		setView((view + 1) % 3);

	// ------------------------------------------------------------------------------------------
	// The boxes
	// ------------------------------------------------------------------------------------------

	var playerDropDown:PsychUIDropDownMenu;
	var nameInput:PsychUIInputText;
	var ownedInput:PsychUIInputText;
	var positionStepper:PsychUINumericStepper;
	var unownedCheck:PsychUICheckBox;
	var unlockedCheck:PsychUICheckBox;

	var gfAssetInput:PsychUIInputText;
	var gfAnimInfoInput:PsychUIInputText;
	var visualizerCheck:PsychUICheckBox;

	var djAssetInput:PsychUIInputText;
	var djTextInputs:Array<PsychUIInputText> = [];
	var djOffsetX:PsychUINumericStepper;
	var djOffsetY:PsychUINumericStepper;
	var djGlobalX:PsychUINumericStepper;
	var djGlobalY:PsychUINumericStepper;

	function makeMainBox():Void
	{
		mainBox = new PsychUIBox(FlxG.width - 320, 10, 310, 400, ['Player', 'Girlfriend', 'Freeplay DJ', 'Results']);
		mainBox.scrollFactor.set();
		add(mainBox);

		// ---- Player
		var tab = mainBox.getTab('Player').menu;
		var ids:Array<String> = [for (one in PlayableCharacters.list()) one.id];
		playerDropDown = new PsychUIDropDownMenu(10, 25, ids, function(index:Int, id:String)
		{
			if(id == playerId) return;
			leaveFor(new CharSelectEditorState(id), function() playerDropDown.selectedLabel = playerId);
		}, 140);
		playerDropDown.selectedLabel = playerId;

		nameInput = new PsychUIInputText(10, 70, 200, VSliceConvert.str(data.name, playerId), 8);
		positionStepper = new PsychUINumericStepper(10, 110, 1, slotOf(), 0, GRID_SIZE - 1, 0);
		unownedCheck = new PsychUICheckBox(10, 140, 'Show songs nobody owns', 200);
		unownedCheck.checked = (data.showUnownedChars == true);
		unlockedCheck = new PsychUICheckBox(10, 165, 'Unlocked', 200);
		unlockedCheck.checked = (data.unlocked != false);
		ownedInput = new PsychUIInputText(10, 210, 280, [for (char in VSliceConvert.list(data.ownedChars)) Std.string(char)].join(', '), 8);

		var reloadButton:PsychUIButton = new PsychUIButton(160, 25, 'Reload', function() leaveFor(new CharSelectEditorState(playerId)));
		var saveButton:PsychUIButton = new PsychUIButton(10, 250, 'Save', saveFile);
		var viewButton:PsychUIButton = new PsychUIButton(110, 250, 'Switch view', nextView, 100);

		var fileText:FlxText = new FlxText(10, 280, 280, 'File: ' + ((filePath != null) ? filePath : '(none yet, the default one)'), 8);
		fileText.wordWrap = true;

		tab.add(new FlxText(10, 7, 0, 'Player (id):'));
		tab.add(new FlxText(10, 52, 0, 'Name:'));
		tab.add(new FlxText(10, 92, 0, 'Place on the grid (0 to 8):'));
		tab.add(new FlxText(10, 192, 0, 'Characters it owns (separated by commas):'));
		tab.add(nameInput);
		tab.add(positionStepper);
		tab.add(unownedCheck);
		tab.add(unlockedCheck);
		tab.add(ownedInput);
		tab.add(reloadButton);
		tab.add(saveButton);
		tab.add(viewButton);
		tab.add(fileText);
		tab.add(playerDropDown);

		// ---- Girlfriend
		var tab = mainBox.getTab('Girlfriend').menu;
		gfAssetInput = new PsychUIInputText(10, 30, 280, VSliceConvert.str(gfData.assetPath, ''), 8);
		gfAnimInfoInput = new PsychUIInputText(10, 75, 280, VSliceConvert.str(gfData.animInfoPath, ''), 8);
		visualizerCheck = new PsychUICheckBox(10, 105, 'Visualizer (her speakers follow the music)', 250);
		visualizerCheck.checked = (gfData.visualizer == true);
		var gfReload:PsychUIButton = new PsychUIButton(10, 135, 'Reload GF', function() withPlayerMod(function()
		{
			reloadGF();
			reloadPreviewTargets();
		}));
		tab.add(new FlxText(10, 12, 0, 'Texture atlas folder (inside "images"):'));
		tab.add(new FlxText(10, 57, 0, 'Animation info folder (In.txt and Out.txt):'));
		tab.add(gfAssetInput);
		tab.add(gfAnimInfoInput);
		tab.add(visualizerCheck);
		tab.add(gfReload);

		// ---- Freeplay DJ
		var tab = mainBox.getTab('Freeplay DJ').menu;
		var djData:Dynamic = data.freeplayDJ;
		djAssetInput = new PsychUIInputText(10, 30, 280, (djData != null) ? VSliceConvert.str(djData.assetPath, '') : '', 8);
		tab.add(new FlxText(10, 12, 0, 'Texture atlas folder (inside "images"):'));
		tab.add(djAssetInput);

		for (i in 0...3)
		{
			var field:String = 'text${i + 1}';
			var input:PsychUIInputText = new PsychUIInputText(10 + i * 95, 75, 85, (djData != null) ? VSliceConvert.str(Reflect.field(djData, field), '') : '', 8);
			djTextInputs.push(input);
			tab.add(input);
		}
		tab.add(new FlxText(10, 57, 0, 'Texts behind the DJ:'));

		var global:Array<Float> = (djData != null) ? VSliceConvert.pair(djData.offsets, 0, 0) : [0, 0];
		djGlobalX = new PsychUINumericStepper(10, 120, 1, global[0], -9999, 9999, 0, 70);
		djGlobalY = new PsychUINumericStepper(90, 120, 1, global[1], -9999, 9999, 0, 70);
		tab.add(new FlxText(10, 102, 0, 'Offsets of the DJ (all of its animations):'));
		tab.add(djGlobalX);
		tab.add(djGlobalY);

		djOffsetX = new PsychUINumericStepper(10, 165, 1, 0, -9999, 9999, 0, 70);
		djOffsetY = new PsychUINumericStepper(90, 165, 1, 0, -9999, 9999, 0, 70);
		tab.add(new FlxText(10, 147, 0, 'Offsets of the animation being previewed:'));
		tab.add(djOffsetX);
		tab.add(djOffsetY);

		var djReload:PsychUIButton = new PsychUIButton(10, 200, 'Reload DJ', function() withPlayerMod(function()
		{
			reloadDJ();
			reloadPreviewTargets();
		}));
		tab.add(djReload);
		if(djData == null) tab.add(new FlxText(10, 230, 280, 'This player has no Freeplay DJ: write the folder of its atlas above and reload.'));

		makeResultsTab();
	}

	// Which sprite is being previewed, and its animation
	var previewTargets:Array<String> = [];
	var previewTarget:String = null;
	var previewAnims:Array<String> = [];
	var previewAnim:Int = 0;
	var targetDropDown:PsychUIDropDownMenu;
	var animDropDown:PsychUIDropDownMenu;

	function makePreviewBox():Void
	{
		previewBox = new PsychUIBox(FlxG.width - 320, 420, 310, 110, ['Animation preview']);
		previewBox.scrollFactor.set();
		add(previewBox);

		var tab = previewBox.getTab('Animation preview').menu;
		targetDropDown = new PsychUIDropDownMenu(10, 25, [''], function(_, name:String) selectTarget(name), 120);
		animDropDown = new PsychUIDropDownMenu(150, 25, [''], function(index:Int, _) selectAnim(index, true), 140);
		var playButton:PsychUIButton = new PsychUIButton(10, 55, 'Play', function() playPreview());
		tab.add(new FlxText(10, 7, 0, 'Sprite:'));
		tab.add(new FlxText(150, 7, 0, 'Animation:'));
		tab.add(playButton);
		tab.add(animDropDown);
		tab.add(targetDropDown);
	}

	function reloadPreviewTargets():Void
	{
		if(targetDropDown == null) return;

		previewTargets = [];
		if(view == VIEW_CHAR_SELECT)
		{
			if(playerSprite != null) previewTargets.push('Player');
			if(gfSprite != null) previewTargets.push('Girlfriend');
		}
		else if(dj != null) previewTargets.push('Freeplay DJ');

		targetDropDown.list = (previewTargets.length > 0) ? previewTargets : ['(nothing)'];
		var keep:String = previewTargets.contains(previewTarget) ? previewTarget : previewTargets[0];
		targetDropDown.selectedLabel = (keep != null) ? keep : '(nothing)';
		selectTarget(keep);
	}

	function selectTarget(name:String):Void
	{
		previewTarget = previewTargets.contains(name) ? name : null;
		previewAnims = [];
		switch(previewTarget)
		{
			case 'Player': previewAnims = atlasAnims(playerSprite);
			case 'Girlfriend': previewAnims = atlasAnims(gfSprite);
			case 'Freeplay DJ': previewAnims = dj.animationNames();
			default:
		}
		previewAnims.sort(Reflect.compare);
		animDropDown.list = (previewAnims.length > 0) ? previewAnims : ['(none)'];
		var idle:Int = previewAnims.indexOf('idle');
		selectAnim((idle > -1) ? idle : 0, true);
	}

	static function atlasAnims(sprite:CharSelectAtlas):Array<String>
	{
		if(sprite == null) return [];
		@:privateAccess
		return [for (name in sprite.anim.animsMap.keys()) name];
	}

	function selectAnim(index:Int, play:Bool):Void
	{
		if(previewAnims.length < 1) return;
		previewAnim = FlxMath.wrap(index, 0, previewAnims.length - 1);
		animDropDown.selectedLabel = previewAnims[previewAnim];
		if(previewTarget == 'Freeplay DJ')
		{
			var offset:Array<Float> = dj.getAnimationOffset(previewAnims[previewAnim]);
			djOffsetX.value = offset[0];
			djOffsetY.value = offset[1];
		}
		if(play) playPreview();
	}

	function playPreview():Void
	{
		if(previewAnims.length < 1) return;
		var name:String = previewAnims[previewAnim];
		var loop:Bool = (name == 'idle'); //(the menus play it again and again)
		switch(previewTarget)
		{
			case 'Player': playerSprite.playAnim(name, loop);
			case 'Girlfriend': gfSprite.playAnim(name, loop);
			case 'Freeplay DJ': dj.previewAnimation(name, loop);
			default:
		}
	}

	// The texture atlas being previewed, to go through its frames
	function previewAtlas():FlxAnimate
	{
		return switch(previewTarget)
		{
			case 'Player': playerSprite;
			case 'Girlfriend': gfSprite;
			case 'Freeplay DJ': dj;
			default: null;
		}
	}

	function stepFrame(change:Int):Void
	{
		var atlas:FlxAnimate = previewAtlas();
		if(atlas == null || atlas.anim.curSymbol == null) return;

		atlas.anim.pause();
		var length:Int = atlas.anim.length;
		if(length < 1) return;
		atlas.anim.curFrame = FlxMath.wrap(atlas.anim.curFrame + change, 0, length - 1);
		atlas.anim.update(0);
	}

	function moveDJOffset(x:Float, y:Float):Void
	{
		if(dj == null || previewTarget != 'Freeplay DJ' || previewAnims.length < 1) return;
		// (x and y are where it goes on the screen: the offsets of a DJ placed by its atlas' stage are taken away from where it is, the others' are added)
		var sign:Float = dj.placedByStage() ? -1 : 1;
		djOffsetX.value += x * sign;
		djOffsetY.value += y * sign;
		dj.setAnimationOffset(previewAnims[previewAnim], djOffsetX.value, djOffsetY.value);
		unsaved = true;
	}

	// ------------------------------------------------------------------------------------------
	// Changes
	// ------------------------------------------------------------------------------------------

	public function UIEvent(id:String, sender:Dynamic):Void
	{
		// (a stepper is a text field too: what's typed on it counts right away, it only becomes its value when it's left)
		if(Std.isOfType(sender, PsychUINumericStepper) && (id == PsychUIInputText.CHANGE_EVENT || id == PsychUINumericStepper.CHANGE_EVENT))
		{
			var stepper:PsychUINumericStepper = cast sender;
			var value:Float = (id == PsychUIInputText.CHANGE_EVENT) ? Std.parseFloat(stepper.text.replace('%', '')) : stepper.value;
			if(Math.isNaN(value)) return;
			if(stepperChanged(stepper, FlxMath.bound(value, stepper.min, stepper.max))) unsaved = true;
			return;
		}

		if(id == PsychUIInputText.CHANGE_EVENT)
		{
			if(sender == nameInput) data.name = nameInput.text;
			else if(sender == ownedInput) data.ownedChars = [for (char in ownedInput.text.split(',')) if(char.trim().length > 0) char.trim()];
			else if(sender == gfAssetInput) gfData.assetPath = gfAssetInput.text.trim();
			else if(sender == gfAnimInfoInput) gfData.animInfoPath = gfAnimInfoInput.text.trim();
			else if(sender == djAssetInput) djData().assetPath = djAssetInput.text.trim();
			else if(djTextInputs.contains(sender)) Reflect.setField(djData(), 'text${djTextInputs.indexOf(sender) + 1}', sender.text);
			else if(!resultsTextChanged(sender)) return;
			unsaved = true;
		}
		else if(id == PsychUICheckBox.CLICK_EVENT)
		{
			if(sender == unownedCheck) data.showUnownedChars = unownedCheck.checked;
			else if(sender == unlockedCheck) data.unlocked = unlockedCheck.checked;
			else if(sender == visualizerCheck) gfData.visualizer = visualizerCheck.checked;
			else if(sender == propLoopedCheck)
			{
				var prop:Dynamic = selectedPropData();
				if(prop == null) return;
				prop.looped = propLoopedCheck.checked;
			}
			else return;
			unsaved = true;
		}
	}

	// Returns true if it was one of the editor's
	function stepperChanged(stepper:PsychUINumericStepper, value:Float):Bool
	{
		if(stepper == positionStepper)
		{
			data.charSelect.position = Std.int(value);
			withPlayerMod(reloadIcons);
		}
		else if(stepper == djOffsetX || stepper == djOffsetY)
		{
			var x:Float = (stepper == djOffsetX) ? value : djOffsetX.value;
			var y:Float = (stepper == djOffsetY) ? value : djOffsetY.value;
			if(dj != null && previewTarget == 'Freeplay DJ' && previewAnims.length > 0)
				dj.setAnimationOffset(previewAnims[previewAnim], x, y);
		}
		else if(stepper == djGlobalX || stepper == djGlobalY)
		{
			var x:Float = (stepper == djGlobalX) ? value : djGlobalX.value;
			var y:Float = (stepper == djGlobalY) ? value : djGlobalY.value;
			djData().offsets = [x, y];
			if(dj != null && previewTarget == 'Freeplay DJ' && previewAnims.length > 0)
				dj.setAnimationOffset(previewAnims[previewAnim], djOffsetX.value, djOffsetY.value); //(the DJ's are used with the animation's)
		}
		else return resultsStepperChanged(stepper, value);
		return true;
	}

	function djData():Dynamic
	{
		if(data.freeplayDJ == null) data.freeplayDJ = {assetPath: '', animations: []};
		return data.freeplayDJ;
	}

	// ------------------------------------------------------------------------------------------

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(PsychUIInputText.focusOn == null)
		{
			var shift:Bool = FlxG.keys.pressed.SHIFT;
			if(FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
			{
				saveFile();
				return;
			}
			if(FlxG.keys.justPressed.ESCAPE)
			{
				if(unsaved) openSubState(new ExitConfirmationPrompt());
				else
				{
					FlxG.mouse.visible = false;
					MusicBeatState.switchState(new MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				return;
			}
			if(FlxG.keys.justPressed.TAB) nextView();
			if(FlxG.keys.justPressed.H)
			{
				mainBox.visible = mainBox.active = !mainBox.visible;
				previewBox.visible = previewBox.active = (mainBox.visible && view != VIEW_RESULTS);
			}

			if(view == VIEW_RESULTS)
			{
				resultsKeys(shift);
				updateStatus();
				return;
			}

			if(FlxG.keys.justPressed.UP) selectAnim(previewAnim - 1, true);
			if(FlxG.keys.justPressed.DOWN) selectAnim(previewAnim + 1, true);
			if(FlxG.keys.justPressed.LEFT) stepFrame(shift ? -10 : -1);
			if(FlxG.keys.justPressed.RIGHT) stepFrame(shift ? 10 : 1);
			if(FlxG.keys.justPressed.SPACE) playPreview();

			var amount:Float = shift ? 10 : 1;
			if(FlxG.keys.justPressed.J) moveDJOffset(-amount, 0);
			if(FlxG.keys.justPressed.L) moveDJOffset(amount, 0);
			if(FlxG.keys.justPressed.I) moveDJOffset(0, -amount);
			if(FlxG.keys.justPressed.K) moveDJOffset(0, amount);
		}

		updateStatus();
	}

	function updateStatus():Void
	{
		var lines:Array<String> = [];
		lines.push('Player: ${VSliceConvert.str(data.name, playerId)} ($playerId)' + (unsaved ? ' - not saved' : ''));
		if(view == VIEW_RESULTS)
		{
			var prop:Dynamic = selectedPropData();
			lines.push('Results, ${RANK_NAMES[rank]}: ' + ((prop != null) ? 'animation ${selectedProp + 1}/${propList().length}' + ((prop.scriptClass != null) ? ' (the script class ${prop.scriptClass})' : '') + ', at ${propOffsets(prop)}' : 'no animations'));
			statusText.text = lines.join('\n');
			return;
		}
		var atlas:FlxAnimate = previewAtlas();
		if(atlas != null && previewAnims.length > 0 && atlas.anim.curSymbol != null)
		{
			var line:String = '$previewTarget: ${previewAnims[previewAnim]}, frame ${atlas.anim.curFrame + 1}/${atlas.anim.length}'
				+ (atlas.anim.isPlaying ? '' : ' (paused)');
			if(previewTarget == 'Freeplay DJ') line += ' | offsets: ${djOffsetX.value}, ${djOffsetY.value}';
			lines.push(line);
		}
		else lines.push('Nothing to preview' + ((view == VIEW_DJ) ? ': this player has no Freeplay DJ' : ''));
		statusText.text = lines.join('\n');
	}

	// ------------------------------------------------------------------------------------------
	// Results screen
	// ------------------------------------------------------------------------------------------

	static final RANK_NAMES:Array<String> = ['Loss', 'Good', 'Great', 'Excellent', 'Perfect', 'Perfect (gold)'];
	static final FILTERS:Array<String> = ['both', 'naughty', 'safe'];
	static final RENDER_TYPES:Array<String> = ['animateatlas', 'sparrow'];

	var rank:Int = 4;
	var selectedProp:Int = 0;
	var resultsProps:FlxTypedGroup<FlxBasic>;
	var propSprites:Array<FlxSprite> = [];
	var resultsTimers:Array<FlxTimer> = [];

	var rankDropDown:PsychUIDropDownMenu;
	var propDropDown:PsychUIDropDownMenu;
	var renderDropDown:PsychUIDropDownMenu;
	var filterDropDown:PsychUIDropDownMenu;
	var musicInput:PsychUIInputText;
	var propAssetInput:PsychUIInputText;
	var propSoundInput:PsychUIInputText;
	var propStartLabelInput:PsychUIInputText;
	var propLoopLabelInput:PsychUIInputText;
	var propScale:PsychUINumericStepper;
	var propX:PsychUINumericStepper;
	var propY:PsychUINumericStepper;
	var propDelay:PsychUINumericStepper;
	var propLayer:PsychUINumericStepper;
	var propLoopFrame:PsychUINumericStepper;
	var propLoopedCheck:PsychUICheckBox;

	function makeResultsScene():Void
	{
		var bg:FlxSprite = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFFFECC5C, 0xFFFDC05C], 90);
		resultsScene.add(bg);

		resultsProps = new FlxTypedGroup<FlxBasic>();
		resultsScene.add(resultsProps);
		selectedProp = firstShownProp();

		reloadResultsProps();
	}

	function resultsData():Dynamic
	{
		if(data.results == null) data.results = {music: {}};
		if(data.results.music == null) data.results.music = {};
		return data.results;
	}

	// The animations of the rank. Perfect (gold) uses Perfect's when it has none of its own, like the game does
	function propList():Array<Dynamic>
	{
		var results:Dynamic = data.results;
		if(results == null) return [];
		var list:Dynamic = Reflect.field(results, ResultsState.RANK_FIELDS[rank]);
		if(list == null && rank == 5) list = results.perfect;
		return Std.isOfType(list, Array) ? list : [];
	}

	// The list of the rank itself, made when something is added to it
	function ownPropList():Array<Dynamic>
	{
		var results:Dynamic = resultsData();
		var list:Dynamic = Reflect.field(results, ResultsState.RANK_FIELDS[rank]);
		if(!Std.isOfType(list, Array))
		{
			list = (rank == 5 && Std.isOfType(results.perfect, Array)) ? [for (prop in (results.perfect:Array<Dynamic>)) Reflect.copy(prop)] : [];
			Reflect.setField(results, ResultsState.RANK_FIELDS[rank], list);
		}
		return list;
	}

	function selectedPropData():Dynamic
	{
		var list:Array<Dynamic> = propList();
		return (selectedProp >= 0 && selectedProp < list.length) ? list[selectedProp] : null;
	}

	static function propOffsets(prop:Dynamic):Array<Float>
		return VSliceConvert.pair(prop.offsets, 0, 0);

	static function propName(prop:Dynamic, index:Int):String
	{
		var name:String = (prop.scriptClass != null) ? Std.string(prop.scriptClass) : ResultsState.stripLibrary(VSliceConvert.str(prop.assetPath, '?'));
		return '${index + 1}: ' + name.substr(name.lastIndexOf('/') + 1);
	}

	function reloadResultsProps():Void
	{
		stopResults();
		for (sprite in propSprites) if(sprite != null) sprite.destroy();
		propSprites = [];
		if(resultsProps == null) return;
		resultsProps.clear();

		var list:Array<Dynamic> = propList();
		withPlayerMod(function()
		{
			for (prop in list)
			{
				var sprite:FlxSprite = makeProp(prop);
				propSprites.push(sprite);
			}
		});

		// in the order of their layers, like the results screen
		var order:Array<Int> = [for (i in 0...propSprites.length) i];
		order.sort(function(a, b)
		{
			var layerA:Float = VSliceConvert.num(list[a].zIndex, 500);
			var layerB:Float = VSliceConvert.num(list[b].zIndex, 500);
			return (layerA != layerB) ? ((layerA < layerB) ? -1 : 1) : a - b;
		});
		for (index in order)
			if(propSprites[index] != null)
				resultsProps.add(propSprites[index]);

		if(selectedProp >= list.length) selectedProp = list.length - 1;
		if(selectedProp < 0) selectedProp = 0;
		if(view == VIEW_RESULTS) playResults(false);
	}

	function makeProp(prop:Dynamic):FlxSprite
	{
		if(prop == null) return null;

		var offsets:Array<Float> = propOffsets(prop);
		var size:Float = VSliceConvert.num(prop.scale, 1);
		var path:String = ResultsState.stripLibrary(VSliceConvert.str(prop.assetPath, ''));
		switch(VSliceConvert.str(prop.renderType, 'animateatlas'))
		{
			case 'sparrow':
				if(!Paths.fileExists('images/$path.png', IMAGE)) return null;
				var sprite:FlxSprite = new FlxSprite(offsets[0], offsets[1]);
				sprite.frames = Paths.getSparrowAtlas(path);
				sprite.animation.addByPrefix('idle', '', 24, false);
				sprite.antialiasing = ClientPrefs.data.antialiasing;
				var loopFrame:Null<Int> = prop.loopFrame;
				if(loopFrame != null) sprite.animation.finishCallback = function(_) sprite.animation.play('idle', true, false, loopFrame);
				sprite.scale.set(size, size);
				return sprite;

			default:
				var sprite:AtlasSprite = (prop.scriptClass != null) ? ResultsState.makeScriptedAtlas(prop.scriptClass, offsets[0], offsets[1])
					: new AtlasSprite(offsets[0], offsets[1], path);
				if(sprite == null || !sprite.loaded) return null;
				sprite.scale.set(size, size);
				ResultsState.setupAtlasLoop(sprite, prop);
				return sprite;
		}
	}

	/**
	 * Plays the animations of the rank: as the results screen does (each after its delay, with its sound), or all at once.
	 */
	function playResults(withDelays:Bool):Void
	{
		stopResults();
		var list:Array<Dynamic> = propList();
		for (index => sprite in propSprites)
		{
			if(sprite == null) continue;
			var prop:Dynamic = list[index];
			if(!propShown(prop, index))
			{
				sprite.visible = false;
				continue;
			}

			var start:Void->Void = function()
			{
				sprite.visible = true;
				var atlas:AtlasSprite = Std.downcast(sprite, AtlasSprite);
				if(atlas != null) atlas.player.play(VSliceConvert.str(prop.startFrameLabel, ''), true);
				else sprite.animation.play('idle', true);

				var sound:String = ResultsState.stripLibrary(VSliceConvert.str(prop.sound, ''));
				if(withDelays && sound.length > 0)
					withPlayerMod(function() if(Paths.fileExists('sounds/$sound.${Paths.SOUND_EXT}', SOUND)) FlxG.sound.play(Paths.sound(sound)));
			}

			var delay:Float = withDelays ? VSliceConvert.num(prop.delay, 0) : 0;
			if(delay <= 0) start();
			else
			{
				sprite.visible = false;
				resultsTimers.push(new FlxTimer().start(delay, function(_) start()));
			}
		}
		if(withDelays) playResultsMusic();
	}

	// The results screen only shows the animations for the "naughtyness" option being used (the selected one is always shown)
	function propShown(prop:Dynamic, index:Int):Bool
	{
		var filter:String = VSliceConvert.str(prop.filter, 'both');
		return index == selectedProp || filter == 'both' || filter == (ClientPrefs.data.naughtyness ? 'naughty' : 'safe');
	}

	// The first animation of the rank the results screen shows with the options being used
	function firstShownProp():Int
	{
		var list:Array<Dynamic> = propList();
		for (index => prop in list)
		{
			var filter:String = VSliceConvert.str(prop.filter, 'both');
			if(filter == 'both' || filter == (ClientPrefs.data.naughtyness ? 'naughty' : 'safe')) return index;
		}
		return 0;
	}

	// A blink of the selected animation, to see which one it is
	function flashSelected():Void
	{
		var sprite:FlxSprite = propSprites[selectedProp];
		if(sprite == null || view != VIEW_RESULTS) return;
		FlxTween.cancelTweensOf(sprite);
		sprite.alpha = 0.25;
		FlxTween.tween(sprite, {alpha: 1}, 0.5);
	}

	function stopResults():Void
	{
		for (timer in resultsTimers) timer.cancel();
		resultsTimers = [];
	}

	function playResultsMusic():Void
	{
		var music:Dynamic = (data.results != null) ? data.results.music : null;
		var path:String = (music != null) ? VSliceConvert.str(Reflect.field(music, ResultsState.MUSIC_FIELDS[rank]), '') : '';
		if(path.length < 1) path = ResultsState.DEFAULT_MUSIC[rank];

		withPlayerMod(function()
		{
			var key:String = '$path/$path';
			if(!Paths.fileExists('music/$key.${Paths.SOUND_EXT}', SOUND)) key = path;
			if(Paths.fileExists('music/$key.${Paths.SOUND_EXT}', SOUND)) FlxG.sound.playMusic(Paths.music(key), 1, true);
		});
	}

	function resultsKeys(shift:Bool):Void
	{
		var amount:Float = shift ? 10 : 1;
		if(FlxG.keys.justPressed.LEFT) moveProp(-amount, 0);
		if(FlxG.keys.justPressed.RIGHT) moveProp(amount, 0);
		if(FlxG.keys.justPressed.UP) moveProp(0, -amount);
		if(FlxG.keys.justPressed.DOWN) moveProp(0, amount);
		if(FlxG.keys.justPressed.SPACE) playResults(true);
		if(FlxG.keys.justPressed.R)
		{
			if(FlxG.sound.music != null) FlxG.sound.music.volume = 0;
			playResults(false);
		}
	}

	function moveProp(x:Float, y:Float):Void
	{
		var prop:Dynamic = selectedPropData();
		if(prop == null) return;
		var offsets:Array<Float> = propOffsets(prop);
		setPropOffsets(prop, offsets[0] + x, offsets[1] + y);
		propX.value = offsets[0] + x;
		propY.value = offsets[1] + y;
		unsaved = true;
	}

	function setPropOffsets(prop:Dynamic, x:Float, y:Float):Void
	{
		prop.offsets = [x, y];
		var sprite:FlxSprite = propSprites[selectedProp];
		if(sprite != null) sprite.setPosition(x, y);
	}

	function makeResultsTab():Void
	{
		var tab = mainBox.getTab('Results').menu;

		rankDropDown = new PsychUIDropDownMenu(10, 20, RANK_NAMES, function(index:Int, _)
		{
			rank = index;
			selectedProp = firstShownProp();
			reloadResultsProps();
			refreshResultsTab();
		}, 130);
		propDropDown = new PsychUIDropDownMenu(150, 20, [''], function(index:Int, _)
		{
			selectedProp = index;
			refreshResultsTab();
			if(view == VIEW_RESULTS) playResults(false);
			flashSelected();
		}, 140);

		musicInput = new PsychUIInputText(10, 60, 280, '', 8);
		propAssetInput = new PsychUIInputText(10, 100, 185, '', 8);
		renderDropDown = new PsychUIDropDownMenu(205, 100, RENDER_TYPES, function(_, type:String)
		{
			var prop:Dynamic = selectedPropData();
			if(prop == null) return;
			prop.renderType = type;
			reloadResultsProps();
			unsaved = true;
		}, 85);
		propSoundInput = new PsychUIInputText(10, 140, 135, '', 8);
		filterDropDown = new PsychUIDropDownMenu(160, 140, FILTERS, function(_, filter:String)
		{
			var prop:Dynamic = selectedPropData();
			if(prop == null) return;
			if(filter == 'both') Reflect.deleteField(prop, 'filter');
			else prop.filter = filter;
			if(view == VIEW_RESULTS) playResults(false);
			unsaved = true;
		}, 130);

		propScale = new PsychUINumericStepper(10, 180, 0.05, 1, 0.05, 20, 2, 60);
		propX = new PsychUINumericStepper(95, 180, 1, 0, -9999, 9999, 0, 60);
		propY = new PsychUINumericStepper(180, 180, 1, 0, -9999, 9999, 0, 60);
		propDelay = new PsychUINumericStepper(10, 220, 0.05, 0, 0, 30, 2, 60);
		propLayer = new PsychUINumericStepper(95, 220, 10, 500, -9999, 9999, 0, 60);
		propLoopFrame = new PsychUINumericStepper(180, 220, 1, -1, -1, 9999, 0, 60);
		propLoopedCheck = new PsychUICheckBox(10, 250, 'Loops', 60);
		propStartLabelInput = new PsychUIInputText(10, 290, 135, '', 8);
		propLoopLabelInput = new PsychUIInputText(160, 290, 130, '', 8);

		var addButton:PsychUIButton = new PsychUIButton(10, 320, 'Add', function()
		{
			var list:Array<Dynamic> = ownPropList();
			list.push({renderType: 'animateatlas', assetPath: '', scale: 1, offsets: [0, 0], zIndex: 500, delay: 0, looped: true});
			selectedProp = list.length - 1;
			reloadResultsProps();
			refreshResultsTab();
			flashSelected();
			unsaved = true;
		}, 70);
		var removeButton:PsychUIButton = new PsychUIButton(90, 320, 'Remove', function()
		{
			var list:Array<Dynamic> = ownPropList();
			if(selectedProp < 0 || selectedProp >= list.length) return;
			list.splice(selectedProp, 1);
			reloadResultsProps();
			refreshResultsTab();
			unsaved = true;
		}, 70);
		var reloadButton:PsychUIButton = new PsychUIButton(170, 320, 'Reload', function()
		{
			reloadResultsProps();
			refreshResultsTab();
		}, 70);
		var playButton:PsychUIButton = new PsychUIButton(10, 348, 'Play the screen', function() playResults(true), 120);

		tab.add(new FlxText(10, 2, 0, 'Rank:'));
		tab.add(new FlxText(150, 2, 0, 'Animation:'));
		tab.add(new FlxText(10, 45, 0, 'Music (folder inside "music"):'));
		tab.add(new FlxText(10, 85, 0, 'Image / atlas (inside "images"):'));
		tab.add(new FlxText(205, 85, 0, 'Type:'));
		tab.add(new FlxText(10, 125, 0, 'Sound:'));
		tab.add(new FlxText(160, 125, 0, 'Shown when:'));
		tab.add(new FlxText(10, 165, 0, 'Scale:'));
		tab.add(new FlxText(95, 165, 0, 'X:'));
		tab.add(new FlxText(180, 165, 0, 'Y:'));
		tab.add(new FlxText(10, 205, 0, 'Delay (s):'));
		tab.add(new FlxText(95, 205, 0, 'Layer:'));
		tab.add(new FlxText(180, 205, 0, 'Loop frame (-1: no):'));
		tab.add(new FlxText(10, 275, 0, 'Start label:'));
		tab.add(new FlxText(160, 275, 0, 'Loop label:'));
		for (thing in ([musicInput, propAssetInput, propSoundInput, propScale, propX, propY, propDelay, propLayer, propLoopFrame,
			propLoopedCheck, propStartLabelInput, propLoopLabelInput, addButton, removeButton, reloadButton, playButton,
			filterDropDown, renderDropDown, propDropDown, rankDropDown] : Array<FlxSprite>))
			tab.add(thing);

		rankDropDown.selectedLabel = RANK_NAMES[rank];
		refreshResultsTab();
	}

	// The boxes show the selected animation's values
	function refreshResultsTab():Void
	{
		if(propDropDown == null) return;

		var list:Array<Dynamic> = propList();
		var names:Array<String> = [for (index => prop in list) propName(prop, index)];
		propDropDown.list = (names.length > 0) ? names : ['(none)'];
		propDropDown.selectedLabel = (names.length > 0) ? names[selectedProp] : '(none)';

		var music:Dynamic = (data.results != null) ? data.results.music : null;
		musicInput.text = (music != null) ? VSliceConvert.str(Reflect.field(music, ResultsState.MUSIC_FIELDS[rank]), '') : '';

		var prop:Dynamic = selectedPropData();
		var has:Bool = (prop != null);
		propAssetInput.text = has ? VSliceConvert.str(prop.assetPath, '') : '';
		propSoundInput.text = has ? VSliceConvert.str(prop.sound, '') : '';
		renderDropDown.selectedLabel = has ? VSliceConvert.str(prop.renderType, 'animateatlas') : 'animateatlas';
		filterDropDown.selectedLabel = has ? VSliceConvert.str(prop.filter, 'both') : 'both';
		propScale.value = has ? VSliceConvert.num(prop.scale, 1) : 1;
		var offsets:Array<Float> = has ? propOffsets(prop) : [0, 0];
		propX.value = offsets[0];
		propY.value = offsets[1];
		propDelay.value = has ? VSliceConvert.num(prop.delay, 0) : 0;
		propLayer.value = has ? VSliceConvert.num(prop.zIndex, 500) : 500;
		propLoopFrame.value = (has && prop.loopFrame != null) ? VSliceConvert.num(prop.loopFrame, -1) : -1;
		propLoopedCheck.checked = !has || prop.looped != false;
		propStartLabelInput.text = has ? VSliceConvert.str(prop.startFrameLabel, '') : '';
		propLoopLabelInput.text = has ? VSliceConvert.str(prop.loopFrameLabel, '') : '';
	}

	// Returns true if it was one of the results' fields
	function resultsTextChanged(sender:Dynamic):Bool
	{
		if(sender == musicInput)
		{
			var music:Dynamic = resultsData().music;
			if(musicInput.text.trim().length > 0) Reflect.setField(music, ResultsState.MUSIC_FIELDS[rank], musicInput.text.trim());
			else Reflect.deleteField(music, ResultsState.MUSIC_FIELDS[rank]);
			return true;
		}

		var fields:Map<PsychUIInputText, String> = [propAssetInput => 'assetPath', propSoundInput => 'sound',
			propStartLabelInput => 'startFrameLabel', propLoopLabelInput => 'loopFrameLabel'];
		if(!fields.exists(sender)) return false;

		var prop:Dynamic = selectedPropData();
		if(prop == null) return false;
		var text:String = cast(sender, PsychUIInputText).text.trim();
		if(text.length > 0) Reflect.setField(prop, fields.get(sender), text);
		else Reflect.deleteField(prop, fields.get(sender));
		if(sender == propAssetInput) Reflect.deleteField(prop, 'scriptClass'); //(an image of its own instead of the script's)
		return true;
	}

	function resultsStepperChanged(stepper:PsychUINumericStepper, value:Float):Bool
	{
		var prop:Dynamic = selectedPropData();
		if(prop == null) return false;

		var sprite:FlxSprite = propSprites[selectedProp];
		if(stepper == propX || stepper == propY)
		{
			var offsets:Array<Float> = propOffsets(prop);
			setPropOffsets(prop, (stepper == propX) ? value : offsets[0], (stepper == propY) ? value : offsets[1]);
		}
		else if(stepper == propScale)
		{
			prop.scale = value;
			if(sprite != null) sprite.scale.set(value, value);
		}
		else if(stepper == propDelay) prop.delay = value;
		else if(stepper == propLayer)
		{
			prop.zIndex = Std.int(value);
			reloadResultsProps();
		}
		else if(stepper == propLoopFrame)
		{
			if(value >= 0) prop.loopFrame = Std.int(value);
			else Reflect.deleteField(prop, 'loopFrame');
		}
		else return false;
		return true;
	}

	// ------------------------------------------------------------------------------------------

	/**
	 * Goes to another state, asking first if there's something that wasn't saved.
	 */
	function leaveFor(next:flixel.FlxState, ?onCancel:Void->Void):Void
	{
		if(!unsaved)
		{
			MusicBeatState.switchState(next);
			return;
		}
		openSubState(new Prompt('There\'s unsaved progress,\nare you sure you want to leave it?', function() MusicBeatState.switchState(next), onCancel, 'Leave', 'Stay'));
	}

	// ------------------------------------------------------------------------------------------
	// Saving
	// ------------------------------------------------------------------------------------------

	var file:FileReference = null;

	function saveFile():Void
	{
		if(file != null) return;

		var text:String = OrderedJson.stringify(data);
		if(lineBreak != '\n') text = text.split('\n').join(lineBreak);
		if(DirectPlay.editorSave('$playerId.json', text))
		{
			unsaved = false;
			return;
		}
		file = new FileReference();
		file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		file.addEventListener(Event.CANCEL, onSaveEnd);
		file.addEventListener(IOErrorEvent.IO_ERROR, onSaveEnd);
		file.save(text, '$playerId.json');
	}

	function onSaveComplete(_):Void
	{
		unsaved = false;
		PlayableCharacters.clearCache(); //(read again with what was saved, if it went to the player's file)
		onSaveEnd(null);
	}

	function onSaveEnd(_):Void
	{
		if(file == null) return;
		file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		file.removeEventListener(Event.CANCEL, onSaveEnd);
		file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveEnd);
		file = null;
	}
}
