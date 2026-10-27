package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Something a mod uses that only Vortex Engine has, and where.
 */
typedef CompatFinding =
{
	/** BREAKS, DIFFERS or NOTE. */
	var level:Int;
	/** What it is ("setLaneUnderlay()"). */
	var name:String;
	/** What happens with it on other engines. */
	var effect:String;
	/** The files and lines it's on ("scripts/thing.lua:12"). */
	var places:Array<String>;
}

typedef CompatReport =
{
	var findings:Array<CompatFinding>;
	/** Script files that were read. */
	var scripts:Int;
	/** Script files that check the "VortexEngine" variable (made to work elsewhere too, maybe). */
	var checksVortex:Array<String>;
	/** A V-Slice (Polymod) mod. */
	var isVSlice:Bool;
}

/**
 * Reads a mod's scripts, charts and images looking for what only Vortex Engine has (see scripts.txt): mods made with it are
 * not recommended for other engines, unless they don't use any of it. The mods menu shows what this finds.
 * It only reads the files: a script that checks "VortexEngine" before using something may already be fine elsewhere.
 */
class ModCompatibility
{
	/** Other engines stop the script with an error there. */
	public static inline final BREAKS:Int = 0;
	/** It works differently or not at all elsewhere, without an error. */
	public static inline final DIFFERS:Int = 1;
	/** Worth knowing, usually fine. */
	public static inline final NOTE:Int = 2;

	static final FUNCTIONS:Array<String> = ['setLaneUnderlay', 'setScoreCamera', 'setHiddenNotes', 'getTallies', 'startConversation', 'makeStrumsEarly', 'getExtraCharacter'];
	static final CALLBACKS:Array<String> = ['onBreakStart', 'onBreakEnd', 'onConversationEnd'];
	static final VARIABLES:Array<String> = ['playAsOpponent', 'onlinePlay', 'onlineHost'];
	static final PROPERTIES:Array<String> = ['iconBop', 'sustainWiggle', 'showBreakTimer', 'ghostNotes', 'healthDrain', 'speedMiss',
		'hiddennotes', 'showLaneUnderlay', 'laneUnderlayAlpha', 'isResting', 'maxRestTime', 'maxCombo', 'scoreCamera', 'isVSliceStage',
		'playableCharacter', 'otherCharacter', 'playableStrums', 'otherStrums', 'restCountdownTxt', 'restTimerBar', 'restportrait',
		'laneUnderlays', 'camSus', 'camLanes', 'susWiggle', 'grpHoldCovers', 'onlineStatsTxt', 'conversation', 'extraCharacters'];
	static final OPTIONS:Array<String> = ['ghostNotes', 'breakTimer', 'iconBop', 'sustainWiggle', 'laneUnderlay', 'holdCovers',
		'scoreCamera', 'smoothHealthBar', 'songCredits', 'resultsScreen', 'stickerTransition', 'freeplayStyle', 'naughtyness',
		'windowMode', 'sharpness'];
	static final CHANGERS:Array<String> = ['healthdrain', 'hiddennotes', 'speedmiss'];
	static final BLENDS:Array<String> = ['overlay', 'hardlight', 'difference', 'invert'];

	// (files bigger than this aren't scripts or charts anyone wrote by hand: skipped)
	static inline final MAX_FILE_SIZE:Int = 16 * 1024 * 1024;

	public static function check(folder:String):CompatReport
	{
		var report:CompatReport = {findings: [], scripts: 0, checksVortex: [], isVSlice: false};
		#if (MODS_ALLOWED && sys)
		var root:String = Paths.mods(folder) + '/';
		if(!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return report;
		report.isVSlice = FileSystem.exists(root + '_polymod_meta.json');

		var found:Map<String, CompatFinding> = [];
		var order:Array<String> = [];
		function add(level:Int, name:String, effect:String, place:String)
		{
			var finding:CompatFinding = found.get(name);
			if(finding == null)
			{
				finding = {level: level, name: name, effect: effect, places: []};
				found.set(name, finding);
				order.push(name);
			}
			if(level < finding.level) finding.level = level;
			if(!finding.places.contains(place)) finding.places.push(place);
		}

		for (path in listFiles(root, ''))
		{
			var lower:String = path.toLowerCase();
			var isLua:Bool = lower.endsWith('.lua');
			var isHx:Bool = lower.endsWith('.hx') || lower.endsWith('.hxc') || lower.endsWith('.hscript') || lower.endsWith('.hxs');

			// animated health icons: an .xml next to an icon's image
			if(lower.endsWith('.xml') && (lower.contains('images/icons/') || lower.startsWith('icons/')))
			{
				var image:String = path.substr(0, path.length - 4) + '.png';
				if(FileSystem.exists(root + image))
					add(NOTE, Language.getPhrase('compat_icon_name', 'Animated health icon'),
						Language.getPhrase('compat_icon_effect', 'Vortex animates it by itself: other engines show the whole sheet as it is, unless a script of the mod animates it.'), path);
				continue;
			}

			if(lower.endsWith('.json') && (lower.startsWith('data/') || lower.contains('/data/')))
			{
				var text:String = read(root + path);
				if(text != null && text.contains('"vortexCharacters"') && !~/"vortexCharacters"\s*:\s*\[\s*\]/.match(text))
					add(DIFFERS, Language.getPhrase('compat_extras_name', 'Extra characters on the chart'),
						Language.getPhrase('compat_extras_effect', 'Only Vortex shows them: elsewhere they are missing and the main characters sing their notes.'), path);
				continue;
			}

			if(!isLua && !isHx) continue;
			var text:String = read(root + path);
			if(text == null) continue;

			report.scripts++;
			text = stripComments(text, isLua);
			var lines:Array<Int> = lineStarts(text);
			function lineOf(pos:Int):String return '$path:' + lineAt(lines, pos);

			if(~/\bVortexEngine\b/.match(text)) report.checksVortex.push(path);

			// functions only Vortex has: calling one elsewhere is an error
			for (name in FUNCTIONS)
			{
				var reg:EReg = new EReg('([\\w.:]*?)\\b' + name + '\\s*\\(', 'g');
				var pos:Int = 0;
				while(reg.matchSub(text, pos))
				{
					var where = reg.matchedPos();
					pos = where.pos + where.len;
					var before:String = reg.matched(1);
					var defined:Bool = ~/function\s*$/.match(text.substring(Std.int(Math.max(0, where.pos - 12)), where.pos));
					if(defined || (before.length > 0 && !before.endsWith('game.') && !before.endsWith('instance.'))) continue;
					add(BREAKS, '$name()', Language.getPhrase('compat_function_effect', 'Vortex-only function: on other engines the script stops with an error here.'), lineOf(where.pos));
				}
			}

			for (name in CALLBACKS)
				eachMatch(new EReg('function\\s+' + name + '\\s*\\(', 'g'), text, function(pos)
					add(DIFFERS, '$name()', Language.getPhrase('compat_callback_effect', 'Only Vortex calls it: on other engines this part of the script never runs.'), lineOf(pos)));

			for (name in VARIABLES)
				eachMatch(new EReg('(?<![\\w"\'])' + name + '\\b(?!\\s*\\()', 'g'), text, function(pos)
				{
					if(isLua) add(NOTE, name, Language.getPhrase('compat_variable_lua', 'Vortex-only variable: elsewhere it is nil, as if it were off.'), lineOf(pos));
					else add(DIFFERS, name, Language.getPhrase('compat_variable_hx', 'Vortex-only variable: in HScript, reading one that does not exist is an error (use try/catch, see scripts.txt).'), lineOf(pos));
				});

			var propertyEffect:String = Language.getPhrase('compat_property_effect', 'Vortex-only property: elsewhere it does nothing or gives an error.');
			for (name in PROPERTIES)
			{
				var reg:EReg = isLua ? new EReg('(?:set|get)Property\\s*\\(\\s*[\'"]' + name + '(?=[\'".\\[])', 'g')
					: new EReg('(?:\\bgame|PlayState\\.instance)\\.' + name + '\\b', 'g');
				eachMatch(reg, text, function(pos) add(DIFFERS, name, propertyEffect, lineOf(pos)));
			}
			var groupReg:EReg = isLua ? ~/PropertyFromGroup\s*\(\s*['"](laneUnderlays|grpHoldCovers)['"]/g : ~/\bgame\.(laneUnderlays|grpHoldCovers)\b/g;
			eachMatch(groupReg, text, function(pos) add(DIFFERS, groupReg.matched(1), propertyEffect, lineOf(pos)));
			var playableReg:EReg = isLua ? ~/PropertyFromGroup\s*\(\s*['"](?:notes|unspawnNotes)['"]\s*,[^,\n]*,\s*['"]playable['"]/g : ~/\b(?:note|daNote)\.playable\b/g;
			eachMatch(playableReg, text, function(pos) add(DIFFERS, 'note.playable', propertyEffect, lineOf(pos)));
			var iconReg:EReg = ~/iconP[12]\.(autoUpdate|isAnimated|hasWinningIcon)\b/g;
			eachMatch(iconReg, text, function(pos) add(DIFFERS, 'iconP1/iconP2.' + iconReg.matched(1), propertyEffect, lineOf(pos)));

			var optionEffect:String = Language.getPhrase('compat_option_effect', 'Vortex option: elsewhere it reads as nothing (null or the default).');
			var optionReg:EReg = new EReg('\\bdata\\.(' + OPTIONS.join('|') + ')\\b', 'g');
			eachMatch(optionReg, text, function(pos)
			{
				var line:String = lineText(text, lines, pos);
				if(line.contains('ClientPrefs')) add(NOTE, 'ClientPrefs.data.' + optionReg.matched(1), optionEffect, lineOf(pos));
			});
			var changerReg:EReg = new EReg('getGameplaySetting\\s*\\(\\s*[\'"](' + CHANGERS.join('|') + ')[\'"]', 'g');
			eachMatch(changerReg, text, function(pos) add(NOTE, 'getGameplaySetting("' + changerReg.matched(1) + '")', optionEffect, lineOf(pos)));

			var blendEffect:String = Language.getPhrase('compat_blend_effect', 'Only Vortex draws this blend mode on Lua sprites: elsewhere it looks plain.');
			var blendReg:EReg = new EReg('setBlendMode\\s*\\([^,\\n]+,\\s*[\'"](' + BLENDS.join('|') + ')[\'"]', 'gi');
			eachMatch(blendReg, text, function(pos) add(DIFFERS, 'setBlendMode("' + blendReg.matched(1).toLowerCase() + '")', blendEffect, lineOf(pos)));
			eachMatch(~/\.cameraBlends\b/g, text, function(pos) add(DIFFERS, 'cameraBlends', blendEffect, lineOf(pos)));
		}

		for (name in order) report.findings.push(found.get(name));
		report.findings.sort(function(a, b) return (a.level != b.level) ? a.level - b.level : Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
		#end
		return report;
	}

	#if (MODS_ALLOWED && sys)
	// Every file of the mod, by its path inside it
	static function listFiles(root:String, folder:String):Array<String>
	{
		var files:Array<String> = [];
		var path:String = root + folder;
		for (name in FileSystem.readDirectory(path))
		{
			var inside:String = folder + name;
			if(FileSystem.isDirectory(root + inside))
			{
				var lower:String = name.toLowerCase();
				if(lower == 'sounds' || lower == 'music' || lower == 'songs' || lower == 'videos' || lower == 'fonts') continue;
				files = files.concat(listFiles(root, inside + '/'));
			}
			else files.push(inside);
		}
		return files;
	}

	static function read(path:String):String
	{
		try
		{
			if(FileSystem.stat(path).size > MAX_FILE_SIZE) return null;
			return File.getContent(path);
		}
		catch(e:Dynamic) {}
		return null;
	}
	#end

	static function eachMatch(reg:EReg, text:String, found:Int->Void):Void
	{
		var pos:Int = 0;
		while(pos < text.length && reg.matchSub(text, pos))
		{
			var where = reg.matchedPos();
			found(where.pos);
			pos = where.pos + Std.int(Math.max(1, where.len));
		}
	}

	// Comments become spaces (the lines stay where they are), so what's written in them isn't counted
	static function stripComments(text:String, isLua:Bool):String
	{
		var buf:StringBuf = new StringBuf();
		var i:Int = 0;
		var len:Int = text.length;
		inline function blank(from:Int, to:Int)
		{
			for (j in from...to)
			{
				var c:Int = StringTools.fastCodeAt(text, j);
				buf.addChar((c == '\n'.code || c == '\r'.code) ? c : ' '.code);
			}
		}

		while(i < len)
		{
			var c:Int = StringTools.fastCodeAt(text, i);
			var next:Int = (i + 1 < len) ? StringTools.fastCodeAt(text, i + 1) : 0;
			if(isLua && c == '-'.code && next == '-'.code)
			{
				var end:Int;
				if(text.substr(i + 2, 2) == '[[' || text.substr(i + 2, 3) == '[=[')
				{
					end = text.indexOf(text.substr(i + 2, 2) == '[[' ? ']]' : ']=]', i + 4);
					end = (end < 0) ? len : end + 2;
				}
				else
				{
					end = text.indexOf('\n', i);
					if(end < 0) end = len;
				}
				blank(i, end);
				i = end;
			}
			else if(!isLua && c == '/'.code && next == '/'.code)
			{
				var end:Int = text.indexOf('\n', i);
				if(end < 0) end = len;
				blank(i, end);
				i = end;
			}
			else if(!isLua && c == '/'.code && next == '*'.code)
			{
				var end:Int = text.indexOf('*/', i + 2);
				end = (end < 0) ? len : end + 2;
				blank(i, end);
				i = end;
			}
			else
			{
				buf.addChar(c);
				i++;
			}
		}
		return buf.toString();
	}

	static function lineStarts(text:String):Array<Int>
	{
		var starts:Array<Int> = [0];
		var pos:Int = text.indexOf('\n');
		while(pos >= 0)
		{
			starts.push(pos + 1);
			pos = text.indexOf('\n', pos + 1);
		}
		return starts;
	}

	static function lineAt(starts:Array<Int>, pos:Int):Int
	{
		var low:Int = 0;
		var high:Int = starts.length - 1;
		while(low < high)
		{
			var mid:Int = (low + high + 1) >> 1;
			if(starts[mid] <= pos) low = mid;
			else high = mid - 1;
		}
		return low + 1;
	}

	static function lineText(text:String, starts:Array<Int>, pos:Int):String
	{
		var line:Int = lineAt(starts, pos) - 1;
		var end:Int = (line + 1 < starts.length) ? starts[line + 1] : text.length;
		return text.substring(starts[line], end);
	}
}
