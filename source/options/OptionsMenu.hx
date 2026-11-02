package options;

import backend.StageData;
import flixel.FlxCamera;
import flixel.FlxBasic;
import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxSpriteGroup;
import objects.StrumNote;
import objects.NoteSplash;

/**
 * The options menu itself: a panel with a tab for each kind of setting (Gameplay, Graphics, Visuals, V-Slice, Vortex Engine and
 * "More": note colors, controls, delay and combo, language), the settings of the tab as "Name: < value >" lines, and what the
 * selected one does at the bottom.
 *
 * It's a substate so it can be opened right on top of the main menu, which it slides in over (and back out from) with the gear
 * rolling along its edge, the main menu staying where it is underneath. `OptionsState` opens it too, when the options are opened
 * from a song or come back from "Adjust Delay and Combo".
 *
 * The settings themselves are the ones of the menus each tab used to open (GraphicsSettingsSubState...): they're made to read their
 * list, and changing a value works the same way it did there.
 */
class OptionsMenu extends MusicBeatSubstate
{
	public static final OPTIONS:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay',
		'V-Slice',
		'Vortex Engine'
		#if TRANSLATIONS_ALLOWED , 'Language' #end
	];

	// The tabs, in their order, and what the "More" one lists (each opens a menu of its own)
	static final TABS:Array<String> = ['Gameplay', 'Graphics', 'Visuals', 'V-Slice', 'Vortex Engine', 'Mods', 'More'];
	static final MORE:Array<String> = ['Note Colors', 'Controls', 'Extra Keys', 'Adjust Delay and Combo' #if TRANSLATIONS_ALLOWED , 'Language' #end];

	public static inline final SLIDE_TIME:Float = 0.8;

	/**
	 * How the menu shows up: right away, sliding in, or already there and sliding out at once (back from `OptionsState` to the main menu).
	 */
	public static inline final APPEAR:Int = 0;
	public static inline final SLIDE_IN:Int = 1;
	public static inline final SLIDE_OUT:Int = -1;

	/**
	 * Called once it slid out, to the main menu (which it was opened over).
	 */
	public var onSlidOut:Void->Void = null;

	// Where it was the last time (it opens on the same tab and line)
	static var lastTab:Int = 0;
	static var lastRows:Map<Int, Int> = [];

	// The panel
	static inline final PANEL_X:Float = 90;
	static inline final PANEL_Y:Float = 40;
	static inline final PANEL_W:Float = 1130;
	static inline final PANEL_H:Float = 640;
	static inline final TAB_H:Float = 62;
	static inline final ROW_H:Float = 44;
	static inline final LIST_TOP:Float = PANEL_Y + TAB_H + 16;
	static inline final LIST_BOTTOM:Float = PANEL_Y + PANEL_H - 70;

	static inline final COLOR_PANEL:Int = 0xD8261038;
	static inline final COLOR_TABS:Int = 0xFF2E1248;
	static inline final COLOR_TAB_ON:Int = 0xFF8C4FD6;
	static inline final COLOR_ROW_ON:Int = 0x55FF5FC8;
	static inline final COLOR_BOTTOM:Int = 0xFF1C0A2E;
	static inline final COLOR_TEXT:Int = 0xFFE7D8FF;

	var onPlayState:Bool;
	var inMainMenu:Bool;
	var startMode:Int;

	var bfBackdrop:FlxBackdrop;
	var gear:FlxSprite;
	var content:FlxSpriteGroup; //(everything of the panel: it's what slides)

	var tabBacks:Array<FlxSprite> = [];
	var tabTexts:Array<FlxText> = [];
	var tabGlow:FlxSprite;
	var rowHighlight:FlxSprite;
	var rows:Array<FlxText> = [];
	var descText:FlxText;
	var hintText:FlxText;

	var curTab:Int = 0;
	var curRow:Int = 0;
	var scroll:Float = 0;
	var scrollTarget:Float = 0;

	// The settings of each tab, read from the menu that has them (made once, never shown)
	var menus:Map<String, BaseOptionsMenu> = [];
	var tabOptions:Array<Option> = [];

	var holdTime:Float = 0;
	var holdValue:Float = 0;

	// (while sliding, the menu is on a camera of its own that moves, and the gear on one above it)
	// The receptors and splashes of the Visuals tab (its own, so a change of skin shows on them), shown by the note and splash settings
	var previewNotes:FlxTypedGroup<StrumNote> = null;
	var previewSplashes:FlxTypedGroup<NoteSplash> = null;
	var previewShown:Float = 0;
	var previewWanted:Bool = false;
	var splashesPending:Bool = false;

	var slideCam:FlxCamera = null;
	var gearCam:FlxCamera = null;
	var sliding:Bool = false;
	var exiting:Bool = false;

	/**
	 * @param onPlayState 	Opened from a song: going back goes back to it, and there's no gear.
	 * @param inMainMenu 	Opened over the main menu, which going back slides it off of.
	 */
	public function new(onPlayState:Bool, inMainMenu:Bool, startMode:Int = APPEAR)
	{
		super();
		this.onPlayState = onPlayState;
		this.inMainMenu = inMainMenu;
		this.startMode = startMode;
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		bfBackdrop = new FlxBackdrop(Paths.image('mainmenu/othermenus/bficom'));
		bfBackdrop.antialiasing = ClientPrefs.data.antialiasing;
		bfBackdrop.velocity.set(35, 35);
		bfBackdrop.spacing.set(50, 50);
		bfBackdrop.scrollFactor.set();
		bfBackdrop.alpha = (startMode == SLIDE_OUT) ? 0.125 : 0;
		add(bfBackdrop);
		if(startMode != SLIDE_OUT) FlxTween.tween(bfBackdrop, {alpha: 0.125}, 1.2, {ease: FlxEase.quadOut});

		content = new FlxSpriteGroup();
		content.scrollFactor.set();
		add(content);
		makePanel();

		if(!onPlayState)
		{
			gear = new FlxSprite(0, 10).loadGraphic(Paths.image('mainmenu/menu_options'));
			gear.antialiasing = ClientPrefs.data.antialiasing;
			gear.scrollFactor.set();
			gear.x = -(gear.width / 2);
			add(gear);
		}

		curTab = FlxMath.wrap(lastTab, 0, TABS.length - 1);
		showTab(curTab, false);
		ClientPrefs.saveSettings();

		super.create();

		switch(startMode)
		{
			case SLIDE_IN: slide(true);
			case SLIDE_OUT: slide(false);
			default:
		}
	}

	// ------------------------------------------------------------------------------------------
	// The panel
	// ------------------------------------------------------------------------------------------

	function makePanel():Void
	{
		// a soft shadow, the panel, a pink line along its top
		var shadow:FlxSprite = new FlxSprite(PANEL_X + 8, PANEL_Y + 10).makeGraphic(Std.int(PANEL_W), Std.int(PANEL_H), 0x55000000);
		content.add(shadow);
		var panel:FlxSprite = new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(Std.int(PANEL_W), Std.int(PANEL_H), COLOR_PANEL);
		content.add(panel);
		var tabBar:FlxSprite = new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(Std.int(PANEL_W), Std.int(TAB_H), COLOR_TABS);
		content.add(tabBar);

		var tabWidth:Float = PANEL_W / TABS.length;
		tabGlow = new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(Std.int(tabWidth), Std.int(TAB_H), COLOR_TAB_ON);
		content.add(tabGlow);
		for (i => tab in TABS)
		{
			var back:FlxSprite = new FlxSprite(PANEL_X + i * tabWidth, PANEL_Y).makeGraphic(Std.int(tabWidth), Std.int(TAB_H), 0x00FFFFFF);
			tabBacks.push(back);
			content.add(back);

			var text:FlxText = new FlxText(back.x, PANEL_Y + 20, tabWidth, tabName(tab), 20);
			text.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, OUTLINE, 0xFF140820);
			text.borderSize = 2;
			tabTexts.push(text);
			content.add(text);
		}
		var line:FlxSprite = new FlxSprite(PANEL_X, PANEL_Y + TAB_H).makeGraphic(Std.int(PANEL_W), 4, 0xFFFF5FC8);
		content.add(line);

		rowHighlight = new FlxSprite(PANEL_X + 14, LIST_TOP).makeGraphic(Std.int(PANEL_W - 28), Std.int(ROW_H - 4), COLOR_ROW_ON);
		content.add(rowHighlight);

		var bottom:FlxSprite = new FlxSprite(PANEL_X, PANEL_Y + PANEL_H - 62).makeGraphic(Std.int(PANEL_W), 62, COLOR_BOTTOM);
		content.add(bottom);
		descText = new FlxText(PANEL_X + 16, bottom.y + 6, PANEL_W - 32, '', 18);
		descText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT);
		content.add(descText);

		hintText = new FlxText(PANEL_X, PANEL_Y + PANEL_H + 6, PANEL_W, Language.getPhrase('options_tabs_hint',
			'Q/E or TAB: tab | UP/DOWN: setting | LEFT/RIGHT: change | ENTER: on/off, open | R: default'), 16);
		hintText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		content.add(hintText);
	}

	static function tabName(tab:String):String
	{
		return (tab == 'More') ? Language.getPhrase('options_more', 'More') : Language.getPhrase('options_$tab', tab);
	}

	// The settings of a tab, read from the menu that has them
	function optionsOf(tab:String):Array<Option>
	{
		if(tab == 'More') return [];
		if(tab == 'Mods')
		{
			if(modTabOptions == null) modTabOptions = buildModOptions();
			return modTabOptions;
		}
		var menu:BaseOptionsMenu = menus.get(tab);
		if(menu == null)
		{
			menu = switch(tab)
			{
				case 'Graphics': new options.GraphicsSettingsSubState();
				case 'Visuals': new options.VisualsSettingsSubState();
				case 'Gameplay': new options.GameplaySettingsSubState();
				case 'V-Slice': new options.InterfaceSettingsSubState();
				case 'Vortex Engine': new options.VortexSettingsSubState();
				default: null;
			}
			if(menu == null) return [];
			menus.set(tab, menu);
			if(Std.isOfType(menu, options.VisualsSettingsSubState)) attachPreview(cast menu);
		}
		@:privateAccess return (menu.optionsArray != null) ? menu.optionsArray : [];
	}

	function showTab(index:Int, playSound:Bool = true):Void
	{
		lastRows[curTab] = curRow;
		curTab = FlxMath.wrap(index, 0, TABS.length - 1);
		lastTab = curTab;
		var tab:String = TABS[curTab];
		tabOptions = optionsOf(tab);

		for (row in rows)
		{
			content.remove(row, true);
			row.destroy();
		}
		rows = [];
		var count:Int = (tab == 'More') ? MORE.length : tabOptions.length;
		for (i in 0...count)
		{
			var text:FlxText = new FlxText(PANEL_X + 34, LIST_TOP + i * ROW_H + 6, PANEL_W - 68, '', 28);
			text.setFormat(Paths.font('vcr.ttf'), 28, COLOR_TEXT, LEFT, OUTLINE, 0xFF140820);
			text.borderSize = 2;
			rows.push(text);
			content.insert(content.members.indexOf(rowHighlight) + 1, text);
		}
		for (i in 0...rows.length) refreshRow(i);

		var tabWidth:Float = PANEL_W / TABS.length;
		FlxTween.cancelTweensOf(tabGlow);
		FlxTween.tween(tabGlow, {x: content.x + PANEL_X + curTab * tabWidth}, 0.18, {ease: FlxEase.quadOut});
		for (i => text in tabTexts) text.alpha = (i == curTab) ? 1 : 0.6;

		curRow = lastRows.exists(curTab) ? lastRows.get(curTab) : 0;
		scroll = scrollTarget = 0;
		changeRow(0, false);
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	// "Name: < value >", or the name of a menu of "More"
	function refreshRow(index:Int):Void
	{
		var text:FlxText = rows[index];
		if(TABS[curTab] == 'More')
		{
			text.text = Language.getPhrase('options_' + MORE[index], MORE[index]);
			return;
		}
		var option:Option = tabOptions[index];
		if(option.header)
		{
			text.text = '- ' + option.name + ' -';
			return;
		}
		text.text = option.name + ':  < ' + valueText(option) + ' >';
	}

	static function valueText(option:Option):String
	{
		var value:Dynamic = option.getValue();
		if(option.formatter != null && Reflect.isFunction(option.formatter))
			try return Std.string(Reflect.callMethod(null, option.formatter, [value])) catch(e:Dynamic) {}
		switch(option.type)
		{
			case BOOL:
				return (value == true) ? Language.getPhrase('options_on', 'ON') : Language.getPhrase('options_off', 'OFF');
			case KEYBIND:
				return backend.InputFormatter.getKeyName(value);
			case STRING:
				@:privateAccess var key:String = option._translationKey;
				return Language.getPhrase('setting_$key-$value', Std.string(value));
			default:
				var shown:Dynamic = value;
				if(option.type == PERCENT) shown = Math.round(value * 100);
				return option.displayFormat.replace('%v', Std.string(shown)).replace('%d', Std.string(option.defaultValue));
		}
	}

	// ------------------------------------------------------------------------------------------
	// The "Mods" tab: the settings mods add, each mod under its name
	// ------------------------------------------------------------------------------------------

	var modTabOptions:Array<Option> = null;
	var psychModMenus:Array<options.ModSettingsSubState> = [];

	function buildModOptions():Array<Option>
	{
		var list:Array<Option> = [];

		// V-Slice mods: what their scripts add to V-Slice's options menu
		var byMod:Array<{mod:String, entries:Array<funkin.ui.options.OptionsState.ModPreference>}> = [];
		for (entry in backend.VSliceScripts.collectModOptions())
		{
			var group = null;
			for (other in byMod) if(other.mod == entry.mod) group = other;
			if(group == null)
			{
				group = {mod: entry.mod, entries: []};
				byMod.push(group);
			}
			group.entries.push(entry);
		}
		for (group in byMod)
		{
			list.push(headerOption(modName(group.mod)));
			for (entry in group.entries)
			{
				var option:Option = vsliceOption(entry);
				if(option != null) list.push(option);
			}
		}

		// Psych mods: their "data/settings.json" (the same settings as their button of the mods menu)
		#if MODS_ALLOWED
		for (folder in Mods.parseList().enabled)
		{
			var path:String = Paths.mods('$folder/data/settings.json');
			if(!sys.FileSystem.exists(path)) continue;
			try
			{
				var settings:Array<Dynamic> = tjson.TJSON.parse(sys.io.File.getContent(path));
				if(settings == null || settings.length < 1) continue;
				var menu:options.ModSettingsSubState = new options.ModSettingsSubState(settings, folder, modName(folder));
				psychModMenus.push(menu);
				@:privateAccess var settingsList:Array<Option> = menu.optionsArray;
				if(settingsList == null || settingsList.length < 1) continue;
				list.push(headerOption(modName(folder)));
				for (option in settingsList) list.push(option);
			}
			catch(e:Dynamic) trace('The settings of "$folder" could not be read: $e');
		}
		#end
		return list;
	}

	static function modName(folder:String):String
	{
		if(folder == null || folder.length < 1) return Language.getPhrase('options_mods_other', 'Other');
		#if MODS_ALLOWED
		var pack:Dynamic = Mods.getPack(folder);
		if(pack != null && pack.name != null && Std.string(pack.name).length > 0) return Std.string(pack.name);
		#end
		return folder;
	}

	static function headerOption(name:String):Option
	{
		var option:Option = new Option(name, '', '__header', BOOL);
		option.header = true;
		option.getValue = function() return null;
		option.setValue = function(value:Dynamic) return null;
		return option;
	}

	// A setting a V-Slice mod asked for: its value kept here, the mod's function called on each change (with the value, like V-Slice)
	static function vsliceOption(entry:funkin.ui.options.OptionsState.ModPreference):Option
	{
		var holder:{value:Dynamic} = {value: entry.value};
		var option:Option = null;
		switch(entry.kind)
		{
			case 'checkbox':
				option = new Option(entry.name, entry.description, '__mod', BOOL);
				option.defaultValue = entry.value;
			case 'number':
				var decimals:Int = (entry.precision != null) ? entry.precision : 0;
				option = new Option(entry.name, entry.description, '__mod', decimals > 0 ? FLOAT : INT);
				option.minValue = entry.min;
				option.maxValue = entry.max;
				option.changeValue = entry.step;
				option.decimals = decimals;
				option.scrollSpeed = Math.max(1, (entry.max - entry.min) / 2);
				option.formatter = entry.formatter;
				option.defaultValue = entry.value;
			case 'percentage':
				option = new Option(entry.name, entry.description, '__mod', INT);
				option.minValue = entry.min;
				option.maxValue = entry.max;
				option.changeValue = 10;
				option.scrollSpeed = 50;
				option.displayFormat = '%v%';
				option.defaultValue = entry.value;
			case 'enum':
				// (a list with a single empty value is how some mods write a title between their settings)
				if(entry.labels.length == 1 && entry.labels[0].trim().length < 1)
				{
					var title:Option = headerOption(entry.name.replace('=', '').trim());
					title.description = entry.description;
					return title;
				}
				option = new Option(entry.name, entry.description, '__mod', STRING, entry.labels);
				var index:Int = entry.values.indexOf(Std.string(entry.value));
				option.defaultValue = entry.labels[index > -1 ? index : 0];
				option.curOption = index > -1 ? index : 0;
			default:
				return null;
		}

		if(entry.kind == 'enum')
		{
			option.getValue = function() {
				var index:Int = entry.values.indexOf(Std.string(holder.value));
				return entry.labels[index > -1 ? index : 0];
			};
			option.setValue = function(label:Dynamic) {
				var index:Int = entry.labels.indexOf(Std.string(label));
				holder.value = entry.values[index > -1 ? index : 0];
				return label;
			};
		}
		else
		{
			option.getValue = function() return holder.value;
			option.setValue = function(value:Dynamic) return holder.value = value;
		}
		option.onChange = function() callMod(entry.onChange, holder.value);
		return option;
	}

	// (some mods' functions take the old value too: they're given it twice then)
	static function callMod(func:Dynamic, value:Dynamic):Void
	{
		if(func == null || !Reflect.isFunction(func)) return;
		try Reflect.callMethod(null, func, [value])
		catch(e:Dynamic)
		{
			try Reflect.callMethod(null, func, [value, value]) catch(e2:Dynamic) trace('A mod setting could not be changed: $e');
		}
	}

	function attachPreview(visuals:options.VisualsSettingsSubState):Void
	{
		@:privateAccess
		{
			previewNotes = visuals.notes;
			previewSplashes = visuals.splashes;
		}
		if(previewNotes == null || previewSplashes == null) return;
		var cameras:Array<FlxCamera> = (content != null) ? content.cameras : null;
		for (group in [previewNotes, cast previewSplashes])
		{
			add(group);
			if(cameras != null) group.cameras = cameras;
		}
		for (note in previewNotes.members) if(note != null) note.alpha = 0;
	}

	// Shown while a setting of the notes or of their splashes is selected
	function updatePreview(elapsed:Float):Void
	{
		if(previewNotes == null) return;
		var option:Option = (TABS[curTab] != 'More' && curRow >= 0 && curRow < tabOptions.length) ? tabOptions[curRow] : null;
		var wanted:Bool = TABS[curTab] == 'Visuals' && option != null && ['noteSkin', 'splashSkin', 'splashAlpha'].contains(option.variable);
		var splashOption:Bool = wanted && option.variable.startsWith('splash');
		if(wanted && !previewWanted && splashOption) splashesPending = true;
		if(wanted && previewWanted && splashOption && previewShown >= 1 && option != lastPreviewOption) splashesPending = true;
		previewWanted = wanted;
		lastPreviewOption = option;

		previewShown = wanted ? Math.min(1, previewShown + elapsed * 4) : Math.max(0, previewShown - elapsed * 5);
		var eased:Float = FlxEase.quadOut(previewShown);
		var spacing:Float = 112;
		var left:Float = content.x + PANEL_X + PANEL_W - previewNotes.length * spacing - 30;
		var top:Float = content.y + LIST_TOP + 24;
		for (i => note in previewNotes.members)
		{
			if(note == null) continue;
			note.x = left + i * spacing + (spacing - note.width) / 2;
			note.y = top - 30 * (1 - eased);
			note.alpha = eased;
			note.visible = previewShown > 0;
		}
		if(previewShown <= 0) for (splash in previewSplashes.members) if(splash != null && splash.alive) splash.kill();

		// (the splashes play once the receptors are there, like they did in the Visuals menu)
		if(splashesPending && previewShown >= 1)
		{
			splashesPending = false;
			var visuals = menus.get('Visuals');
			if(visuals != null) @:privateAccess (cast visuals:options.VisualsSettingsSubState).playNoteSplashes();
		}
	}
	var lastPreviewOption:Option = null;

	function changeRow(change:Int, playSound:Bool = true):Void
	{
		var count:Int = rows.length;
		if(count < 1)
		{
			rowHighlight.visible = false;
			descText.text = (TABS[curTab] == 'Mods') ? Language.getPhrase('options_mods_none', 'None of the mods that are on has settings of its own.') : '';
			return;
		}
		rowHighlight.visible = true;
		curRow = FlxMath.wrap(curRow + change, 0, count - 1);
		// (the titles of the "Mods" tab are skipped, in the way it was going)
		if(TABS[curTab] != 'More')
		{
			var step:Int = (change < 0) ? -1 : 1;
			var tries:Int = 0;
			while(tabOptions[curRow] != null && tabOptions[curRow].header && tries++ < count) curRow = FlxMath.wrap(curRow + step, 0, count - 1);
		}
		if(playSound && change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

		var visibleRows:Int = Std.int((LIST_BOTTOM - LIST_TOP) / ROW_H);
		var top:Float = scrollTarget / ROW_H;
		if(curRow < top) scrollTarget = curRow * ROW_H;
		else if(curRow >= top + visibleRows) scrollTarget = (curRow - visibleRows + 1) * ROW_H;

		descText.text = (TABS[curTab] == 'More') ? Language.getPhrase('options_more_desc', 'Press ENTER to open.') : tabOptions[curRow].description;
		holdTime = 0;
	}

	// The lines where they are with the scroll, the ones out of the list hidden
	function placeRows(elapsed:Float):Void
	{
		scroll = FlxMath.lerp(scrollTarget, scroll, Math.exp(-elapsed * 14));
		for (i => text in rows)
		{
			var y:Float = LIST_TOP + i * ROW_H - scroll;
			text.y = content.y + y + 6;
			text.visible = (y >= LIST_TOP - 2 && y + ROW_H <= LIST_BOTTOM + 2);
			var isHeader:Bool = TABS[curTab] != 'More' && tabOptions[i] != null && tabOptions[i].header;
			text.color = isHeader ? 0xFFFF8ADA : ((i == curRow) ? FlxColor.WHITE : COLOR_TEXT);
			text.alpha = (i == curRow) ? 1 : 0.75;
		}
		var selectedY:Float = LIST_TOP + curRow * ROW_H - scroll;
		rowHighlight.visible = rows.length > 0 && selectedY >= LIST_TOP - 2 && selectedY + ROW_H <= LIST_BOTTOM + 2;
		rowHighlight.y = FlxMath.lerp(content.y + selectedY, rowHighlight.y, Math.exp(-elapsed * 20));
	}

	// ------------------------------------------------------------------------------------------
	// Sliding over the main menu
	// ------------------------------------------------------------------------------------------

	function setCameras(cameras:Array<FlxCamera>, gearCameras:Array<FlxCamera>):Void
	{
		for (member in members)
		{
			if(member == null) continue;
			member.cameras = (member == gear) ? gearCameras : cameras;
		}
	}

	function makeCamera():FlxCamera
	{
		var camera:FlxCamera = new FlxCamera();
		camera.bgColor = 0;
		FlxG.cameras.add(camera, false);
		return camera;
	}

	/**
	 * Slides the menu in from the right (or out to it), the gear rolling along its left edge. In, it's then on the game's camera
	 * like any menu (the menus it opens go on top of it there).
	 */
	function slide(goingIn:Bool):Void
	{
		sliding = true;
		FlxG.camera.scroll.y = 0;

		slideCam = makeCamera();
		if(gear != null) gearCam = makeCamera();
		setCameras([slideCam], (gearCam != null) ? [gearCam] : [slideCam]);

		var width:Float = FlxG.width;
		slideCam.x = goingIn ? width : 0;
		FlxTween.tween(slideCam, {x: goingIn ? 0 : width}, SLIDE_TIME, {ease: goingIn ? FlxEase.cubeOut : FlxEase.cubeInOut, onComplete: function(_)
		{
			sliding = false;
			if(goingIn)
			{
				setCameras([FlxG.camera], [FlxG.camera]);
				removeSlideCameras();
			}
			else
			{
				// (the main menu's own gear is back where this one ended up)
				removeSlideCameras();
				close();
				if(onSlidOut != null) onSlidOut();
			}
		}});

		if(gear != null)
		{
			gear.x = goingIn ? width - (gear.width / 2) : -(gear.width / 2);
			gear.angle = goingIn ? 0 : -360;
			FlxTween.tween(gear, {x: goingIn ? -(gear.width / 2) : width - (gear.width / 2), angle: goingIn ? -360 : 0}, SLIDE_TIME,
				{ease: goingIn ? FlxEase.cubeOut : FlxEase.cubeInOut});
		}
	}

	function removeSlideCameras():Void
	{
		for (camera in [slideCam, gearCam])
			if(camera != null && FlxG.cameras.list.contains(camera))
				FlxG.cameras.remove(camera);
		slideCam = gearCam = null;
	}

	// ------------------------------------------------------------------------------------------

	function openSelectedSubstate(label:String)
	{
		switch(label)
		{
			case 'Note Colors':
				openSubState(new options.NotesColorSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Extra Keys':
				openSubState(new options.ExtraKeysSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new options.VisualsSettingsSubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'V-Slice':
				openSubState(new options.InterfaceSettingsSubState());
			case 'Vortex Engine':
				openSubState(new options.VortexSettingsSubState());
			case 'Adjust Delay and Combo':
				exiting = true;
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'Language':
				openSubState(new options.LanguageSubState());
		}
	}

	// (the menus that open over this one are made for a camera that's standing still)
	override function openSubState(SubState:flixel.FlxSubState)
	{
		FlxG.camera.scroll.y = 0;
		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		// (a language or a control may have changed what the lines say)
		for (i in 0...rows.length) refreshRow(i);
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		placeRows(elapsed);
		updatePreview(elapsed);
		if(sliding || exiting || subState != null) return;

		// (the gear is only there when the menu wasn't opened from a song)
		if(gear != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(gear))
		{
			goBack();
			return;
		}

		// tabs: Q/E, TAB (SHIFT+TAB back), or a click on them
		if(FlxG.keys.justPressed.E || (FlxG.keys.justPressed.TAB && !FlxG.keys.pressed.SHIFT)) showTab(curTab + 1);
		else if(FlxG.keys.justPressed.Q || (FlxG.keys.justPressed.TAB && FlxG.keys.pressed.SHIFT)) showTab(curTab - 1);
		if(FlxG.mouse.justPressed)
			for (i => back in tabBacks)
				if(FlxG.mouse.overlaps(back) && i != curTab) showTab(i);

		if(controls.UI_UP_P) changeRow(-1);
		if(controls.UI_DOWN_P) changeRow(1);
		if(FlxG.mouse.wheel != 0) changeRow(-FlxG.mouse.wheel);

		// a click on a line selects it (and does what ENTER does, on a setting that's on/off or a menu)
		var clicked:Bool = false;
		if(FlxG.mouse.justPressed && FlxG.mouse.screenX >= PANEL_X && FlxG.mouse.screenX < PANEL_X + PANEL_W)
		{
			for (i => text in rows)
			{
				var top:Float = text.y - 6;
				if(!text.visible || FlxG.mouse.screenY < top || FlxG.mouse.screenY >= top + ROW_H) continue;
				clicked = (i == curRow);
				if(i != curRow) changeRow(i - curRow);
				break;
			}
		}

		if(controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			goBack();
			return;
		}

		if(rows.length < 1) return;
		if(TABS[curTab] == 'More')
		{
			if(controls.ACCEPT || clicked) openSelectedSubstate(MORE[curRow]);
			return;
		}

		var option:Option = tabOptions[curRow];
		if(option == null || option.header) return;
		switch(option.type)
		{
			case BOOL:
				if(controls.ACCEPT || clicked || controls.UI_LEFT_P || controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
					option.setValue(option.getValue() != true);
					option.change();
					refreshRow(curRow);
				}
			case KEYBIND:
				//(changed in the Controls menu)
			default:
				changeValue(option, elapsed);
		}

		if(controls.RESET && option.type != KEYBIND)
		{
			option.setValue(option.defaultValue);
			if(option.type == STRING) option.curOption = option.options.indexOf(option.getValue());
			option.change();
			refreshRow(curRow);
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}
	}

	// LEFT and RIGHT on a number or a list: a step on each press, quicker while held (like the menus of each kind did)
	function changeValue(option:Option, elapsed:Float):Void
	{
		if(!(controls.UI_LEFT || controls.UI_RIGHT))
		{
			if(controls.UI_LEFT_R || controls.UI_RIGHT_R)
			{
				if(holdTime > 0.5) FlxG.sound.play(Paths.sound('scrollMenu'));
				holdTime = 0;
			}
			return;
		}

		var pressed:Bool = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
		if(pressed)
		{
			switch(option.type)
			{
				case INT, FLOAT, PERCENT:
					var step:Dynamic = controls.UI_LEFT ? -option.changeValue : option.changeValue;
					holdValue = FlxMath.bound(option.getValue() + step, option.minValue, option.maxValue);
					if(option.type == INT) holdValue = Math.round(holdValue);
					else holdValue = FlxMath.roundDecimal(holdValue, option.decimals);
					option.setValue(holdValue);
				case STRING:
					var num:Int = option.curOption + (controls.UI_LEFT_P ? -1 : 1);
					num = FlxMath.wrap(num, 0, option.options.length - 1);
					option.curOption = num;
					option.setValue(option.options[num]);
				default:
			}
			option.change();
			refreshRow(curRow);
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		else if(option.type != STRING && holdTime > 0.5)
		{
			holdValue = FlxMath.bound(holdValue + option.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1), option.minValue, option.maxValue);
			switch(option.type)
			{
				case INT: option.setValue(Math.round(holdValue));
				case PERCENT: option.setValue(FlxMath.roundDecimal(holdValue, option.decimals));
				default: option.setValue(holdValue);
			}
			option.change();
			refreshRow(curRow);
		}
		if(option.type != STRING) holdTime += elapsed;
	}

	function goBack():Void
	{
		if(onPlayState)
		{
			exiting = true;
			StageData.loadDirectory(PlayState.SONG);
			LoadingState.loadAndSwitchState(new PlayState());
			FlxG.sound.music.volume = 0;
			return;
		}

		FlxG.sound.play(Paths.sound('chains'));
		if(inMainMenu)
		{
			slide(false);
			return;
		}

		// (opened by OptionsState: the main menu opens it again over itself and slides it out from there)
		exiting = true;
		states.MainMenuState.returningFromOptions = true;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new states.MainMenuState());
	}

	override function destroy()
	{
		removeSlideCameras();
		lastRows[curTab] = curRow;
		// (the preview is the Visuals menu's own: it goes with it)
		if(previewNotes != null) remove(previewNotes, true);
		if(previewSplashes != null) remove(previewSplashes, true);
		previewNotes = null;
		previewSplashes = null;
		for (menu in psychModMenus)
		{
			menu.saveSettings();
			menu.destroy();
		}
		psychModMenus = [];
		for (menu in menus) menu.destroy();
		menus.clear();
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
