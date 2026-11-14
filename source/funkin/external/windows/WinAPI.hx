package funkin.external.windows;

#if (windows && cpp)
/**
 * V-Slice's Windows functions (its `WinAPI`, made with code of its own in C++): the same code, written here.
 */
@:buildXml('
<target id="haxe">
	<lib name="psapi.lib" if="windows"/>
</target>
')
@:cppFileCode('
#include <windows.h>
#include <psapi.h>
')
class WinAPI
{
	/**
	 * Turns off the "Report to Microsoft" window that shows up when the game crashes.
	 */
	@:functionCode('SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);')
	public static function disableErrorReporting():Void {}

	/**
	 * Keeps Windows from marking the window as "Not Responding" while it's busy.
	 */
	@:functionCode('DisableProcessWindowsGhosting();')
	public static function disableWindowsGhosting():Void {}

	/**
	 * The memory the game is using (its working set), in bytes.
	 */
	@:functionCode('
		PROCESS_MEMORY_COUNTERS_EX pmc;
		if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) return (double)pmc.WorkingSetSize;
		return 0;
	')
	public static function getProcessMemoryWorkingSetSize():Float return 0;
}
#end
