package funkin.play;

/**
 * The pause menu as V-Slice scripts know it. The menu itself is the engine's, scripts only pick its music here.
 */
class PauseSubState
{
	/**
	 * Suffix of the pause music: "breakfast(suffix)", which is how V-Slice gives each character theirs ("-pixel", "-pico").
	 * It's looked for the way V-Slice keeps it ("music/breakfast-pico/breakfast-pico"), on the music folder itself and with Psych's names ("breakfast-(pico)").
	 * When there's none the pause menu plays what's chosen on the options, like on any other song.
	 */
	public static var musicSuffix(default, set):String = '';
	static function set_musicSuffix(value:String):String
	{
		if(value == null) value = '';

		var found:String = null;
		if(value.length > 0)
		{
			var plain:String = value.startsWith('-') ? value.substr(1) : value;
			for (name in ['breakfast$value/breakfast$value', 'breakfast$value', 'breakfast-($plain)'])
			{
				if(backend.Paths.fileExists('music/$name.${backend.Paths.SOUND_EXT}', MUSIC))
				{
					found = name;
					break;
				}
			}
		}
		substates.PauseSubState.songName = found;
		return musicSuffix = value;
	}

	public static function reset():Void
	{
		if(musicSuffix.length > 0) musicSuffix = '';
	}
}
