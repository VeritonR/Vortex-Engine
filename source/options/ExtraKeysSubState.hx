package options;

import backend.ExtraKeys;
import backend.InputFormatter;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.input.keyboard.FlxKey;
import objects.StrumNote;

/**
 * The keys of the songs with more or fewer than 4 arrows (see backend.ExtraKeys): UP/DOWN pick how many arrows, LEFT/RIGHT the arrow,
 * ENTER waits for its new key (ESC while waiting leaves it as it was), R puts that number's keys back to the default ones.
 * 4 arrows are the usual note keys, set in Controls.
 */
class ExtraKeysSubState extends MusicBeatSubstate
{
	static final COUNTS:Array<Int> = [1, 2, 3, 5, 6, 7, 8, 9];
	static var lastCount:Int = 4; //(index of COUNTS: 6 keys first)

	var countIndex:Int = 4;
	var column:Int = 0;
	var waiting:Bool = false;
	var waitTime:Float = 0;

	var titleText:FlxText;
	var countText:FlxText;
	var hintText:FlxText;
	var strums:FlxTypedGroup<StrumNote>;
	var keyTexts:FlxTypedGroup<FlxText>;
	var cursor:FlxSprite;

	public function new()
	{
		super();
		countIndex = lastCount;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF3A1F5C;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		var grid:FlxBackdrop = new FlxBackdrop(FlxGridOverlay.createGrid(80, 80, 160, 160, true, 0x33FFFFFF, 0x0));
		grid.velocity.set(40, 40);
		add(grid);

		titleText = new FlxText(0, 50, FlxG.width, Language.getPhrase('extra_keys_title', 'Extra Keys'), 48);
		titleText.setFormat(Paths.font('vcr.ttf'), 48, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 3;
		add(titleText);

		countText = new FlxText(0, 140, FlxG.width, '', 36);
		countText.setFormat(Paths.font('vcr.ttf'), 36, 0xFFFFD8F5, CENTER, OUTLINE, FlxColor.BLACK);
		countText.borderSize = 2;
		add(countText);

		cursor = new FlxSprite().makeGraphic(1, 1, 0x66FF5FC8);
		add(cursor);
		strums = new FlxTypedGroup<StrumNote>();
		add(strums);
		keyTexts = new FlxTypedGroup<FlxText>();
		add(keyTexts);

		hintText = new FlxText(40, FlxG.height - 120, FlxG.width - 80, '', 22);
		hintText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		hintText.borderSize = 2;
		add(hintText);

		showCount();
	}

	function count():Int
		return COUNTS[countIndex];

	// The arrows of that number, as they look in a song, with their keys under them
	function showCount():Void
	{
		var keys:Int = count();
		ExtraKeys.setKeyCount(keys);
		for (strum in strums) strum.destroy();
		strums.clear();
		for (text in keyTexts) text.destroy();
		keyTexts.clear();

		var width:Float = objects.Note.swagWidth;
		var left:Float = (FlxG.width - keys * width) / 2;
		for (i in 0...keys)
		{
			var strum:StrumNote = new StrumNote(left + i * width, 300, i, 0);
			strum.playAnim('static');
			strum.x = left + i * width + (width - strum.width) / 2;
			strums.add(strum);

			var text:FlxText = new FlxText(left + i * width, 430, width, '', 22);
			text.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			text.borderSize = 2;
			keyTexts.add(text);
		}
		column = Std.int(Math.min(column, keys - 1));
		countText.text = '< ' + Language.getPhrase('extra_keys_count', '{1} arrows', [keys]) + ' >';
		refreshKeys();
	}

	function refreshKeys():Void
	{
		var actions:Array<String> = ExtraKeys.actions(count());
		for (i => text in keyTexts.members)
		{
			var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(actions[i]);
			var name:String = (binds != null && binds.length > 0) ? InputFormatter.getKeyName(binds[0]) : '---';
			text.text = (waiting && i == column) ? '...' : name;
			text.color = (i == column) ? 0xFFFFE066 : FlxColor.WHITE;
		}
		var width:Float = objects.Note.swagWidth;
		var left:Float = (FlxG.width - count() * width) / 2;
		cursor.setGraphicSize(Std.int(width - 6), 200);
		cursor.updateHitbox();
		cursor.setPosition(left + column * width + 3, 280);

		hintText.text = waiting
			? Language.getPhrase('extra_keys_waiting', 'Press the new key (ESC: leave it as it was)')
			: Language.getPhrase('extra_keys_hint', 'UP/DOWN: how many arrows | LEFT/RIGHT: arrow | ENTER: change its key | R: default keys | ESC: back');
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(waiting)
		{
			waitTime += elapsed;
			if(waitTime < 0.15) return; //(the ENTER that started it)
			var pressed:FlxKey = FlxG.keys.firstJustPressed();
			if(pressed == NONE) return;
			waiting = false;
			if(pressed != ESCAPE && pressed != BACKSPACE)
			{
				var action:String = ExtraKeys.actions(count())[column];
				ClientPrefs.keyBinds.set(action, [pressed]);
				ClientPrefs.saveSettings();
				FlxG.sound.play(Paths.sound('confirmMenu'));
			}
			else FlxG.sound.play(Paths.sound('cancelMenu'));
			refreshKeys();
			return;
		}

		if(controls.UI_UP_P || controls.UI_DOWN_P)
		{
			countIndex = FlxMath.wrap(countIndex + (controls.UI_UP_P ? -1 : 1), 0, COUNTS.length - 1);
			lastCount = countIndex;
			FlxG.sound.play(Paths.sound('scrollMenu'));
			showCount();
		}
		if(controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			column = FlxMath.wrap(column + (controls.UI_LEFT_P ? -1 : 1), 0, count() - 1);
			FlxG.sound.play(Paths.sound('scrollMenu'));
			refreshKeys();
		}
		if(controls.ACCEPT)
		{
			waiting = true;
			waitTime = 0;
			FlxG.sound.play(Paths.sound('scrollMenu'));
			refreshKeys();
		}
		if(controls.RESET)
		{
			for (i => action in ExtraKeys.actions(count()))
				ClientPrefs.keyBinds.set(action, [ExtraKeys.DEFAULT_KEYS[count()][i]]);
			ClientPrefs.saveSettings();
			FlxG.sound.play(Paths.sound('cancelMenu'));
			refreshKeys();
		}
		if(controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}

	override function destroy()
	{
		ExtraKeys.setKeyCount(4); //(the menus' notes have 4 arrows)
		super.destroy();
	}
}
