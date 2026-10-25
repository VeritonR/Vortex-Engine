package funkin.util;

using StringTools;

/**
 * V-Slice's shortcuts to write a date down, for the scripts that use them.
 */
class DateUtil
{
	// "2026-10-12-21-05-33"
	public static function generateTimestamp(?date:Date):String
	{
		if(date == null) date = Date.now();

		return date.getFullYear() + '-' + Std.string(date.getMonth() + 1).lpad('0', 2) + '-' + Std.string(date.getDate()).lpad('0', 2)
			+ '-' + Std.string(date.getHours()).lpad('0', 2) + '-' + Std.string(date.getMinutes()).lpad('0', 2) + '-' + Std.string(date.getSeconds()).lpad('0', 2);
	}

	// "October 12, 2026 at 09:05 PM"
	public static function generateCleanTimestamp(?date:Date):String
	{
		if(date == null) date = Date.now();

		return DateTools.format(date, '%B %d, %Y') + ' at ' + DateTools.format(date, '%I:%M %p');
	}
}
