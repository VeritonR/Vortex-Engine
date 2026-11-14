package funkin.api.discord;

// (V-Slice's DiscordClient is the engine's, scripts get the same one)
typedef DiscordClient = funkin.api.discord.DiscordClient.DiscordClientSandboxed;

/**
 * V-Slice's Discord client as scripts get it (`import funkin.api.discord.DiscordClient;` is this one there too): the presence
 * they set goes to the engine's Rich Presence (backend.DiscordClient).
 */
class DiscordClientSandboxed
{
	/**
	 * @param params 	`state` (first line under the game's name), `details` (second one), `largeImageKey`, `smallImageKey`.
	 */
	public static function setPresence(params:Dynamic):Void
	{
		#if DISCORD_ALLOWED
		if(params == null) return;
		var state:String = Reflect.field(params, 'state');
		var details:String = Reflect.field(params, 'details');
		var large:String = Reflect.field(params, 'largeImageKey');
		var small:String = Reflect.field(params, 'smallImageKey');
		// (V-Slice's first line is its `state`, the engine's is its `details`)
		backend.Discord.DiscordClient.changePresence((state != null) ? state : '', details, small, null, null, (large != null) ? large : 'icon');
		#end
	}

	public static function shutdown():Void
	{
		#if DISCORD_ALLOWED
		backend.Discord.DiscordClient.shutdown();
		#end
	}
}
