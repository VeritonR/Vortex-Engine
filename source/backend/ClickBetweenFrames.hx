package backend;

/**
 * "Click Between Frames" (the option of the same name, like Geometry Dash's mod): the game only sees a key when a frame starts, so a
 * press made in the middle of a frame was judged as if it came at the start of the next one, up to a whole frame late. A thread of
 * its own looks at the keyboard about every millisecond and writes down when each key went down; the song then judges the press at
 * that moment (see `states.PlayState.keyPressed()`).
 *
 * Windows only (it reads the keyboard with `GetAsyncKeyState`); elsewhere every press counts as made right now, like before.
 * The thread is native code that never touches Haxe objects, so it can't get in the way of the garbage collector or of lime.
 */
#if (windows && cpp)
@:cppFileCode('
#include <windows.h>
#include <thread>
#include <atomic>
#pragma comment(lib, "winmm.lib")

static std::atomic<long long> cbf_pressedAt[256];
static std::atomic<bool> cbf_watched[256];
static std::atomic<bool> cbf_running(false);
static std::atomic<bool> cbf_started(false);

static long long cbf_now()
{
	LARGE_INTEGER t;
	QueryPerformanceCounter(&t);
	return t.QuadPart;
}

static double cbf_frequency()
{
	LARGE_INTEGER f;
	QueryPerformanceFrequency(&f);
	return (double)f.QuadPart;
}

// (only while one of this game\'s windows is the one in use: the keys typed elsewhere aren\'t the player\'s)
static bool cbf_focused()
{
	DWORD process = 0;
	HWND window = GetForegroundWindow();
	if (window == NULL) return false;
	GetWindowThreadProcessId(window, &process);
	return process == GetCurrentProcessId();
}

static void cbf_loop()
{
	bool down[256] = {};
	bool fast = false;
	int focusCheck = 0;
	bool focused = true;
	while (true)
	{
		// (between songs it only waits, and gives the Windows timer back its usual speed)
		if (!cbf_running.load())
		{
			if (fast) { timeEndPeriod(1); fast = false; }
			for (int key = 0; key < 256; key++) down[key] = false;
			Sleep(50);
			continue;
		}
		if (!fast) { timeBeginPeriod(1); fast = true; }

		if (--focusCheck <= 0) { focused = cbf_focused(); focusCheck = 20; }
		for (int key = 1; key < 256; key++)
		{
			if (!cbf_watched[key].load(std::memory_order_relaxed)) { down[key] = false; continue; }
			bool now = focused && (GetAsyncKeyState(key) & 0x8000) != 0;
			if (now && !down[key]) cbf_pressedAt[key].store(cbf_now());
			down[key] = now;
		}
		Sleep(1);
	}
}
')
#end
class ClickBetweenFrames
{
	/** A press further back than this is not the one the game is seeing now (a key sent by a program, a press the thread missed). */
	static inline var MAX_DELAY:Float = 0.1;

	public static var running(default, null):Bool = false;

	/**
	 * Starts watching these keys (the song's note keys, as OpenFL key codes: the same numbers as Windows' for letters, digits,
	 * arrows, numpad, F keys and space). Stops watching the ones that aren't in the list.
	 */
	public static function start(keys:Array<Int>):Void
	{
		#if (windows && cpp)
		var list:Array<Bool> = [for (i in 0...256) false];
		for (key in keys)
			if (key > 0 && key < 256) list[key] = true;
		for (i in 0...256)
		{
			var watched:Bool = list[i];
			untyped __cpp__('cbf_watched[{0}].store({1}); cbf_pressedAt[{0}].store(0)', i, watched);
		}
		untyped __cpp__('cbf_running = true; if (!cbf_started.exchange(true)) std::thread(cbf_loop).detach()');
		running = true;
		#end
	}

	public static function stop():Void
	{
		#if (windows && cpp)
		untyped __cpp__('cbf_running = false');
		running = false;
		#end
	}

	/**
	 * How long ago (in seconds) the key went down, for the press the game is handling now. 0 when it isn't known.
	 * Each press is only given once.
	 */
	public static function delayOf(key:Int):Float
	{
		#if (windows && cpp)
		if (!running || key <= 0 || key >= 256) return 0;
		var pressedAt:Float = untyped __cpp__('(double)cbf_pressedAt[{0}].exchange(0)', key);
		if (pressedAt <= 0) return 0;
		var now:Float = untyped __cpp__('(double)cbf_now()');
		var frequency:Float = untyped __cpp__('cbf_frequency()');
		var delay:Float = (now - pressedAt) / frequency;
		return (delay > 0 && delay <= MAX_DELAY) ? delay : 0;
		#else
		return 0;
		#end
	}
}
