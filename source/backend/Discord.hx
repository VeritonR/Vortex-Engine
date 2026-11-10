package backend;

#if DISCORD_ALLOWED
import Sys.sleep;
import sys.thread.Thread;
import lime.app.Application;

import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;

import flixel.util.FlxStringUtil;

class DiscordClient
{
	public static var isInitialized:Bool = false;
	private inline static final _defaultID:String = "1566477304652234862";
	public static var clientID(default, set):String = _defaultID;
	private static var presence:DiscordPresence = new DiscordPresence();
	// hides this field from scripts and reflection in general
	@:unreflective private static var __thread:Thread;

	public static function check()
	{
		if(ClientPrefs.data.discordRPC) initialize();
		else if(isInitialized) shutdown();
	}
	
	public static function prepare()
	{
		if (!isInitialized && ClientPrefs.data.discordRPC)
			initialize();

		Application.current.window.onClose.add(function() {
			if(isInitialized) shutdown();
		});
	}

	public dynamic static function shutdown()
	{
		isInitialized = false;
		Discord.Shutdown();
	}
	
	private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		final user = cast (request[0].username, String);
		final discriminator = cast (request[0].discriminator, String);

		var message = '(Discord) Connected to User ';
		if (discriminator != '0') //Old discriminators
			message += '($user#$discriminator)';
		else //New Discord IDs/Discriminator system
			message += '($user)';

		trace(message);
		// (what was already asked for, the game may have been on a song by the time Discord answered)
		if(presence.details != null) updatePresence();
		else changePresence();
	}

	private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord: Error ($errorCode: ${cast(message, String)})');
	}

	private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace('Discord: Disconnected ($errorCode: ${cast(message, String)})');
	}

	public static function initialize()
	{
		var discordHandlers:DiscordEventHandlers = DiscordEventHandlers.create();
		discordHandlers.ready = cpp.Function.fromStaticFunction(onReady);
		discordHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
		discordHandlers.errored = cpp.Function.fromStaticFunction(onError);
		Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), 1, null);

		if(!isInitialized) trace("Discord Client initialized");

		if (__thread == null)
		{
			__thread = Thread.create(() ->
			{
				while (true)
				{
					if (isInitialized)
					{
						#if DISCORD_DISABLE_IO_THREAD
						Discord.UpdateConnection();
						#end
						Discord.RunCallbacks();
					}

					// Wait 1 second until the next loop...
					Sys.sleep(1.0);
				}
			});
		}
		isInitialized = true;
	}

	/**
	 * The engine's site, where the pictures of its status are (Discord shows pictures from a link: the engine's app has none of its own).
	 */
	public static final SITE:String = 'https://veritonr.github.io/Vortex-Engine/';
	public static final SERVER:String = 'https://discord.gg/QKjMSpeHW';
	static final PICTURES:String = SITE + 'img/rpc/';

	/**
	 * The small pictures of what's being done, by their name: 'playing', 'paused', 'menu', 'freeplay', 'editor', 'online', 'gameover'
	 * and 'results'. 'icon' (or 'logo') is the engine's logo. Any other name is one of the pictures of a mod's own Discord app
	 * (`loadModRPC()`), and a link is shown as it is.
	 */
	public static final PICTURE_NAMES:Array<String> = ['playing', 'paused', 'menu', 'freeplay', 'editor', 'online', 'gameover', 'results'];

	static function pictureOf(key:String):String
	{
		if(key == null || key.length < 1) return null;
		if(key.startsWith('https://') || key.startsWith('http://') || key.startsWith('mp:')) return key;
		var ownApp:Bool = (clientID == _defaultID);
		if(key == 'icon' || key == 'logo') return ownApp ? PICTURES + 'logo.png' : key;
		if(PICTURE_NAMES.contains(key)) return PICTURES + key + '.png';
		// (the engine's app has no pictures by name: a character's icon name, which Psych sent, would show an empty spot)
		return ownApp ? null : key;
	}

	/**
	 * What the status says, with the small picture of what's being done (`PICTURE_NAMES`) and what its tooltip says.
	 * Times are counted from now; `endTimestamp` (milliseconds from now) shows the time left.
	 */
	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, largeImageKey:String = 'icon', ?smallImageText:String)
	{
		var startTimestamp:Float = 0;
		if (hasStartTimestamp) startTimestamp = Date.now().getTime();
		if (endTimestamp > 0) endTimestamp = startTimestamp + endTimestamp;

		pending = null;

		// a menu or an editor that doesn't say which small picture it has
		if(smallImageKey == null && details != null)
			smallImageKey = (details.indexOf('Editor') > -1 || details.indexOf('Editing') > -1 || details.indexOf('Playtesting') > -1) ? 'editor' : 'menu';

		presence.setParty(nextParty != null ? nextParty[0] : 0, nextParty != null ? nextParty[1] : 0);
		nextParty = null;

		// (kept here too: the status only points at its texts)
		keptTexts = [details, state, pictureOf(smallImageKey), pictureOf(largeImageKey), smallImageText];
		presence.state = clip(state);
		presence.details = clip(details);
		presence.smallImageKey = keptTexts[2];
		presence.smallImageText = clip(smallImageText);
		presence.largeImageKey = keptTexts[3];
		if(largeText == null) largeText = 'Vortex Engine v' + states.MainMenuState.vortexEngineVersion;
		presence.largeImageText = largeText;
		// Obtained times are in milliseconds so they are divided so Discord can use it
		presence.startTimestamp = Std.int(startTimestamp / 1000);
		presence.endTimestamp = Std.int(endTimestamp / 1000);
		updatePresence();

		//trace('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp, $largeImageKey');
	}

	static var modNames:Map<String, String> = [];

	/**
	 * The name of a mod for the status: its "pack.json" (or V-Slice metadata) name, or its folder. Null for none and for the content
	 * that comes with the engine.
	 */
	public static function modName(folder:String):String
	{
		#if MODS_ALLOWED
		if(folder == null || folder.length < 1 || folder == PolymodCompat.BASE_MOD) return null;
		if(modNames.exists(folder)) return modNames.get(folder);

		var name:String = folder;
		try
		{
			var pack:Dynamic = Mods.getPack(folder);
			if(pack != null && pack.name != null && Std.string(pack.name).trim().length > 0) name = Std.string(pack.name).trim();
		}
		catch(e:Dynamic) {}
		modNames.set(folder, name);
		return name;
		#else
		return null;
		#end
	}

	static var pending:Array<String> = null;
	static var pendingAt:Float = 0;
	static var listening:Bool = false;

	/**
	 * The same as `changePresence()`, a moment later and only if nothing else was asked for since: for what's selected on a menu,
	 * which changes many times while scrolling (Discord only takes a few changes every 20 seconds).
	 */
	public static function changePresenceSoon(details:String, ?state:String, ?smallImageKey:String, ?smallImageText:String):Void
	{
		pending = [details, state, smallImageKey, smallImageText];
		pendingAt = haxe.Timer.stamp() + 1.2;
		if(listening) return;
		listening = true;
		FlxG.signals.postUpdate.add(function()
		{
			if(pending == null || haxe.Timer.stamp() < pendingAt) return;
			var next:Array<String> = pending;
			changePresence(next[0], next[1], next[2], null, null, 'icon', next[3]);
		});
	}

	/**
	 * If a script of the song changed the status itself (Psych's `changeDiscordPresence()`): the song doesn't put its own back with the
	 * score every few seconds then. Set back to false when a song starts.
	 */
	public static var scriptPresence:Bool = false;

	static var keptTexts:Array<String> = [];
	static var largeText:String = null;

	// Discord takes texts of 2 to 128 characters
	static function clip(text:String):String
	{
		if(text == null || text.length < 2) return (text != null && text.length == 1) ? text + ' ' : null;
		if(text.length > 128) text = text.substr(0, 127) + '…';
		keptTexts.push(text);
		return text;
	}

	/**
	 * The players of an online match (shown as "(1 of 2)"), 0 when not playing online. Discord shows either this or the
	 * buttons to the engine's site and server.
	 */
	public static function setParty(size:Int, max:Int):Void
	{
		nextParty = [size, max];
	}
	static var nextParty:Array<Int> = null; //(for the next change only: the status of a menu after an online match has no players)

	public static function updatePresence()
	{
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence.__presence));
	}
	
	inline public static function resetClientID()
	{
		clientID = _defaultID;
	}

	private static function set_clientID(newID:String)
	{
		var change:Bool = (clientID != newID);
		clientID = newID;

		if(change && isInitialized)
		{
			shutdown();
			initialize();
			updatePresence();
		}
		return newID;
	}

	#if MODS_ALLOWED
	public static function loadModRPC()
	{
		var pack:Dynamic = Mods.getPack();
		if(pack != null && pack.discordRPC != null && pack.discordRPC != clientID)
		{
			clientID = pack.discordRPC;
			//trace('Changing clientID! $clientID, $_defaultID');
		}
	}
	#end

	#if LUA_ALLOWED
	public static function addLuaCallbacks(lua:State)
	{
		Lua_helper.add_callback(lua, "changeDiscordPresence", function(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, largeImageKey:String = 'icon', ?smallImageText:String) {
			scriptPresence = true;
			changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp, largeImageKey, smallImageText);
		});
		Lua_helper.add_callback(lua, "changeDiscordClientID", function(?newID:String) {
			if(newID == null) newID = _defaultID;
			clientID = newID;
		});
	}
	#end
}

@:allow(backend.DiscordClient)
private final class DiscordPresence
{
	public var state(get, set):String;
	public var details(get, set):String;
	public var smallImageKey(get, set):String;
	public var largeImageKey(get, set):String;
	public var largeImageText(get, set):String;
	public var startTimestamp(get, set):Int;
	public var endTimestamp(get, set):Int;

	public var smallImageText(get, set):String;

	@:noCompletion private var __presence:DiscordRichPresence;

	function new()
	{
		__presence = DiscordRichPresence.create();
		__presence.type = DiscordActivityType_Playing;
		showButtons(true);
	}

	// Two buttons under the status, for whoever sees it (not for the one playing, Discord doesn't show them their own)
	function showButtons(show:Bool):Void
	{
		__presence.buttons[0].label = show ? 'Get Vortex Engine' : '';
		__presence.buttons[0].url = show ? DiscordClient.SITE : '';
		__presence.buttons[1].label = show ? 'Discord Server' : '';
		__presence.buttons[1].url = show ? DiscordClient.SERVER : '';
	}

	function setParty(size:Int, max:Int):Void
	{
		var online:Bool = size > 0 && max > 0;
		showButtons(!online);
		__presence.partyId = online ? 'vortex-online' : '';
		__presence.partySize = online ? size : 0;
		__presence.partyMax = online ? max : 0;
	}

	@:noCompletion inline function get_smallImageText():String
	{
		return __presence.smallImageText;
	}

	@:noCompletion inline function set_smallImageText(value:String):String
	{
		return __presence.smallImageText = value;
	}

	public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("state", state),
			LabelValuePair.weak("details", details),
			LabelValuePair.weak("smallImageKey", smallImageKey),
			LabelValuePair.weak("largeImageKey", largeImageKey),
			LabelValuePair.weak("largeImageText", largeImageText),
			LabelValuePair.weak("startTimestamp", startTimestamp),
			LabelValuePair.weak("endTimestamp", endTimestamp)
		]);
	}

	@:noCompletion inline function get_state():String
	{
		return __presence.state;
	}

	@:noCompletion inline function set_state(value:String):String
	{
		return __presence.state = value;
	}

	@:noCompletion inline function get_details():String
	{
		return __presence.details;
	}

	@:noCompletion inline function set_details(value:String):String
	{
		return __presence.details = value;
	}

	@:noCompletion inline function get_smallImageKey():String
	{
		return __presence.smallImageKey;
	}

	@:noCompletion inline function set_smallImageKey(value:String):String
	{
		return __presence.smallImageKey = value;
	}

	@:noCompletion inline function get_largeImageKey():String
	{
		return __presence.largeImageKey;
	}
	
	@:noCompletion inline function set_largeImageKey(value:String):String
	{
		return __presence.largeImageKey = value;
	}

	@:noCompletion inline function get_largeImageText():String
	{
		return __presence.largeImageText;
	}

	@:noCompletion inline function set_largeImageText(value:String):String
	{
		return __presence.largeImageText = value;
	}

	@:noCompletion inline function get_startTimestamp():Int
	{
		return __presence.startTimestamp;
	}

	@:noCompletion inline function set_startTimestamp(value:Int):Int
	{
		return __presence.startTimestamp = value;
	}

	@:noCompletion inline function get_endTimestamp():Int
	{
		return __presence.endTimestamp;
	}

	@:noCompletion inline function set_endTimestamp(value:Int):Int
	{
		return __presence.endTimestamp = value;
	}
}
#end
