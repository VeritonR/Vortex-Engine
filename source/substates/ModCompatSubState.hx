package substates;

import backend.ModCompatibility;
import flixel.math.FlxRect;
import flixel.text.FlxText.FlxTextFormat;
import flixel.text.FlxText.FlxTextFormatMarkerPair;
import flixel.util.FlxSpriteUtil;

/**
 * The mods menu's "check" of a mod: what it uses that only Vortex Engine has (see backend.ModCompatibility), so whoever made it
 * knows if it can be played on other engines too.
 */
class ModCompatSubState extends MusicBeatSubstate
{
	static inline final PANEL_X:Int = 60;
	static inline final PANEL_Y:Int = 30;
	static inline final PANEL_W:Int = 1160;
	static inline final PANEL_H:Int = 660;
	static inline final LIST_TOP:Int = 215;
	static inline final LIST_BOTTOM:Int = 640;
	static inline final PLACES_SHOWN:Int = 6;

	var folder:String;
	var modName:String;

	var list:FlxText;
	var scroll:Float = 0;
	var maxScroll:Float = 0;

	public function new(folder:String, modName:String)
	{
		super();
		this.folder = folder;
		this.modName = modName;
	}

	override function create()
	{
		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, 0xD0000000);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		add(bg);

		var panel:FlxSprite = FlxSpriteUtil.drawRoundRect(new FlxSprite(PANEL_X, PANEL_Y).makeGraphic(PANEL_W, PANEL_H, FlxColor.TRANSPARENT), 0, 0, PANEL_W, PANEL_H, 20, 20, 0xFF16162A);
		add(panel);

		var title:FlxText = new FlxText(PANEL_X + 30, PANEL_Y + 20, PANEL_W - 60, Language.getPhrase('compat_title', 'Compatibility with other engines: {1}', [modName]), 28);
		title.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, LEFT);
		add(title);

		var report:CompatReport = ModCompatibility.check(folder);
		var serious:Int = 0;
		for (finding in report.findings) if(finding.level != ModCompatibility.NOTE) serious++;

		var otherEngine:String = report.isVSlice ? 'V-Slice' : 'Psych Engine';
		var verdictText:String;
		var verdictColor:FlxColor;
		if(serious > 0)
		{
			verdictText = Language.getPhrase('compat_verdict_bad', 'This mod uses {1} thing(s) only Vortex Engine has: playing it on {2} or other engines is not recommended.', [serious, otherEngine]);
			verdictColor = 0xFFFF7070;
		}
		else
		{
			verdictText = Language.getPhrase('compat_verdict_good', 'Nothing only Vortex Engine has was found in its {1} script(s): it should also work on {2}.', [report.scripts, otherEngine]);
			verdictColor = 0xFF7CFF8A;
		}
		if(report.checksVortex.length > 0)
			verdictText += '\n' + Language.getPhrase('compat_checks_vortex', '{1} script(s) check the "VortexEngine" variable: they may already do something else on other engines.', [report.checksVortex.length]);

		var verdict:FlxText = new FlxText(PANEL_X + 30, PANEL_Y + 70, PANEL_W - 60, verdictText, 20);
		verdict.setFormat(Paths.font('vcr.ttf'), 20, verdictColor, LEFT);
		add(verdict);

		var legend:FlxText = new FlxText(PANEL_X + 30, LIST_TOP - 32, PANEL_W - 60, '', 16);
		legend.setFormat(Paths.font('vcr.ttf'), 16, 0xFFB0B0C8, LEFT);
		legend.applyMarkup(Language.getPhrase('compat_legend', '<r>ERROR<r> stops the script elsewhere   <y>DIFFERENT<y> works differently elsewhere   <b>NOTE<b> usually fine'), markers());
		add(legend);

		list = new FlxText(PANEL_X + 30, LIST_TOP, PANEL_W - 60, '', 18);
		list.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT);
		list.applyMarkup(makeList(report), markers());
		add(list);
		maxScroll = Math.max(0, list.height - (LIST_BOTTOM - LIST_TOP));
		updateScroll();

		var hint:FlxText = new FlxText(PANEL_X + 30, PANEL_Y + PANEL_H - 28, PANEL_W - 60, Language.getPhrase('compat_hint', 'UP/DOWN or the mouse wheel: scroll   -   ESC: close   (only the files are read: a script may already check before using something)'), 14);
		hint.setFormat(Paths.font('vcr.ttf'), 14, 0xFF9090A8, LEFT);
		add(hint);

		super.create();
	}

	function markers():Array<FlxTextFormatMarkerPair>
	{
		return [
			new FlxTextFormatMarkerPair(new FlxTextFormat(0xFFFF6060), '<r>'),
			new FlxTextFormatMarkerPair(new FlxTextFormat(0xFFFFD050), '<y>'),
			new FlxTextFormatMarkerPair(new FlxTextFormat(0xFF70B8FF), '<b>'),
			new FlxTextFormatMarkerPair(new FlxTextFormat(0xFF9A9AB0), '<g>')
		];
	}

	function makeList(report:CompatReport):String
	{
		if(report.findings.length < 1) return '<g>' + Language.getPhrase('compat_nothing', '(nothing to show)') + '<g>';

		var lines:Array<String> = [];
		for (finding in report.findings)
		{
			var label:String = switch(finding.level)
			{
				case ModCompatibility.BREAKS: '<r>' + Language.getPhrase('compat_level_breaks', 'ERROR') + '<r>';
				case ModCompatibility.DIFFERS: '<y>' + Language.getPhrase('compat_level_differs', 'DIFFERENT') + '<y>';
				default: '<b>' + Language.getPhrase('compat_level_note', 'NOTE') + '<b>';
			}
			lines.push('$label  ${finding.name}');
			lines.push('    ' + finding.effect);

			var shown:Array<String> = finding.places.slice(0, PLACES_SHOWN);
			var more:Int = finding.places.length - shown.length;
			lines.push('<g>    ' + shown.join(', ') + (more > 0 ? ' ' + Language.getPhrase('compat_more', '(and {1} more)', [more]) : '') + '<g>');
			lines.push('');
		}
		return lines.join('\n');
	}

	function updateScroll():Void
	{
		scroll = FlxMath.bound(scroll, 0, maxScroll);
		list.y = LIST_TOP - scroll;
		list.clipRect = FlxRect.get(0, scroll, list.width, LIST_BOTTOM - LIST_TOP);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var move:Float = 0;
		if(controls.UI_UP) move -= 600 * elapsed;
		if(controls.UI_DOWN) move += 600 * elapsed;
		if(FlxG.mouse.wheel != 0) move -= FlxG.mouse.wheel * 60;
		if(move != 0)
		{
			scroll += move;
			updateScroll();
		}

		if(controls.BACK || FlxG.mouse.justPressedRight)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
		}
	}
}
