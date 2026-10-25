package backend;

#if sys
import sys.io.File;
import sys.io.FileOutput;
#end

/**
 * Writes what the game is about to do to "last_steps.txt", next to the game, one line at a time and right away.
 * It's for when the game stops answering: nothing can be shown then, but the last line of the file tells where it was.
 *
 * Only for things that happen a few times per song (loading, a song starting or ending...), never for what happens every frame.
 */
class StepLog
{
	public static inline var PATH:String = 'last_steps.txt';

	static var started:Bool = false;
	static var lines:Int = 0;
	#if sys
	// the loading threads write here too
	static var lock:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	public static function add(text:String):Void
	{
		#if sys
		lock.acquire();
		try
		{
			// starts over every time the game is opened, and when it's getting too big to be of use
			if(lines >= 3000)
			{
				started = false;
				lines = 0;
			}
			var output:FileOutput = started ? File.append(PATH, false) : File.write(PATH, false);
			started = true;
			lines++;

			output.writeString('[' + Date.now().toString() + '] ' + text + '\n');
			output.close();
		}
		catch(e:Dynamic) {}
		lock.release();
		#end
	}
}
