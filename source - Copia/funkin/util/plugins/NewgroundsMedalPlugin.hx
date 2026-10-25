package funkin.util.plugins;

/**
 * V-Slice's medals of Newgrounds. The engine has no connection to Newgrounds: there's nothing to show.
 */
class NewgroundsMedalPlugin
{
	public static function play(?points:Dynamic, ?name:String, ?graphic:Dynamic, ?onFinish:Void->Void):Void
	{
		if(onFinish != null) onFinish();
	}
}
