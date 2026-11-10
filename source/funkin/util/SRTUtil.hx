package funkin.util;

import flixel.math.FlxMath;

using StringTools;

/**
 * V-Slice's subtitle files (.srt): ported from V-Slice's `funkin.util.SRTUtil`.
 */
class SubtitleEntry
{
	public var id:Int;
	public var start:Float; // ms
	public var end:Float; // ms
	public var text:String;

	public function new(number:Int = 0, start:Float = 0, end:Float = 0, text:String = "")
	{
		this.id = number;
		this.start = start;
		this.end = end;
		this.text = text;
	}

	public function toString():String
		return 'SubtitleEntry($id, $start -> $end, $text)';
}

class SRTParser
{
	/**
	 * If true, the `{` and `}` of the text become `<` and `>` (the text is HTML).
	 */
	public static var convertBracesToAngles:Bool = true;

	static final timeArrowPatterns = ["-->", "->", "—>", "–>"];

	public static function parseFromString(s:String):Array<SubtitleEntry>
	{
		if(s == null) return [];
		var normalized = s.replace("\r\n", "\n").replace("\r", "\n");
		if(normalized.length > 0 && normalized.charCodeAt(0) == 0xFEFF) normalized = normalized.substr(1);

		final out:Array<SubtitleEntry> = [];
		for (block in normalized.split("\n\n"))
		{
			var trimmed = block.trim();
			if(trimmed.length == 0) continue;
			var lines = trimmed.split("\n");

			var idx = 0;
			var number = 0;
			if(lines.length > 0 && SubtitleUtils.isNumeric(lines[0]))
			{
				number = Std.parseInt(lines[0]);
				idx = 1;
			}
			if(idx >= lines.length) continue;

			var times = null;
			try times = parseTimeLine(lines[idx]) catch(e:Dynamic) {}
			if(times == null) continue;

			var text = lines.slice(idx + 1).join("\n");
			if(convertBracesToAngles) text = text.replace("{", "<").replace("}", ">");
			out.push(new SubtitleEntry(number, times.start, times.end, text));
		}

		out.sort(SubtitleUtils.sortLines);
		return out;
	}

	public static function parseFromFile(name:String, ?library:String, ?dir:String):Array<SubtitleEntry>
	{
		var raw:String = null;
		try raw = funkin.Assets.getText(funkin.Paths.srt(name, library, dir)) catch(e:Dynamic) trace(e);
		return parseFromString(raw);
	}

	/**
	 * A line like: 00:01:23,456 --> 00:01:25,678
	 */
	public static function parseTimeLine(line:String):{start:Float, end:Float}
	{
		for (arrow in timeArrowPatterns)
		{
			var parts = line.split(arrow);
			if(parts.length != 2) continue;

			var start = parseTimecode(parts[0]);
			var end = parseTimecode(parts[1]);
			return (start < 0 || end < 0) ? null : {start: start, end: end};
		}
		return null;
	}

	/**
	 * A time like 01:02:03,456 or 01:02:03.456, in milliseconds.
	 */
	public static function parseTimecode(t:String):Float
	{
		var parts = t.trim().replace(",", ".").split(":");
		if(parts.length != 3) throw "Invalid timecode: " + t;
		var secParts = parts[2].split(".");
		var ms = 0;
		if(secParts.length > 1)
		{
			var frac = secParts[1];
			if(frac.length > 3) frac = frac.substr(0, 3);
			while(frac.length < 3) frac += "0";
			ms = Std.parseInt(frac);
		}
		return (Std.parseInt(parts[0]) * 3600 + Std.parseInt(parts[1]) * 60 + Std.parseInt(secParts[0])) * 1000 + ms;
	}
}

class SubtitleUtils
{
	public static function findActive(list:Array<SubtitleEntry>, time:Float):SubtitleEntry
	{
		for (s in list)
			if(time >= s.start && time <= s.end) return s;
		return null;
	}

	public static function findActiveIndex(list:Array<SubtitleEntry>, time:Float):Int
	{
		var lo = 0;
		var hi = list.length - 1;
		while(lo <= hi)
		{
			var mid = (lo + hi) >> 1;
			var s = list[mid];
			if(time < s.start) hi = mid - 1;
			else if(time > s.end) lo = mid + 1;
			else return mid;
		}
		return -1;
	}

	public static function isNumeric(s:String):Bool
	{
		if(s == null) return false;
		var t = s.trim();
		if(t.length == 0) return false;
		for (i in 0...t.length)
		{
			var code = t.charCodeAt(i);
			if(code < '0'.code || code > '9'.code) return false;
		}
		return true;
	}

	public static function sortLines(line1:SubtitleEntry, line2:SubtitleEntry):Int
		return FlxMath.numericComparison(line1.id, line2.id);
}
