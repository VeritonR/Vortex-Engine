package funkin.api.newgrounds;

// (V-Slice's NewgroundsClient is the engine's, scripts get the same one)
typedef NewgroundsClient = funkin.api.newgrounds.NewgroundsClient.NewgroundsClientSandboxed;

/**
 * V-Slice's Newgrounds client as scripts get it. The engine doesn't log in to Newgrounds.
 */
class NewgroundsClientSandboxed
{
	public static function isLoggedIn():Bool return false;
}
