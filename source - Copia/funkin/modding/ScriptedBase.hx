package funkin.modding;

import funkin.modding.events.ScriptEvent;

#if HSCRIPT_ALLOWED
import hxc.HxcInstance;
import hxc.HxcRuntime.IHxcScripted;
#end

/**
 * What every class V-Slice scripts can extend has in common here: a place for the script and the functions that receive events,
 * which do nothing until a script overrides them (and are what `super.onSomething(event)` runs).
 */
class ScriptedBase #if HSCRIPT_ALLOWED implements IHxcScripted #end
{
	#if HSCRIPT_ALLOWED
	public var __hxc:HxcInstance = null;
	#end

	public function onScriptEvent(event:ScriptEvent):Void {}

	public function onCreate(event:ScriptEvent):Void {}
	public function onDestroy(event:ScriptEvent):Void {}
	public function onUpdate(event:UpdateScriptEvent):Void {}

	public function onStepHit(event:SongTimeScriptEvent):Void {}
	public function onBeatHit(event:SongTimeScriptEvent):Void {}

	public function onPause(event:PauseScriptEvent):Void {}
	public function onResume(event:ScriptEvent):Void {}
	public function onSongLoaded(event:SongLoadScriptEvent):Void {}
	public function onSongStart(event:ScriptEvent):Void {}
	public function onSongEnd(event:ScriptEvent):Void {}
	public function onGameOver(event:ScriptEvent):Void {}
	public function onSongRetry(event:SongRetryEvent):Void {}
	public function onSongEvent(event:SongEventScriptEvent):Void {}

	public function onCountdownStart(event:CountdownScriptEvent):Void {}
	public function onCountdownStep(event:CountdownScriptEvent):Void {}
	public function onCountdownEnd(event:CountdownScriptEvent):Void {}

	public function onNoteIncoming(event:NoteScriptEvent):Void {}
	public function onNoteHit(event:HitNoteScriptEvent):Void {}
	public function onNoteMiss(event:NoteScriptEvent):Void {}
	public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void {}
	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void {}

	// States and substates being opened and closed, sent to the modules for the menus V-Slice mods change
	public function onStateChangeBegin(event:ScriptEvent):Void {}
	public function onStateChangeEnd(event:ScriptEvent):Void {}
	public function onSubStateOpenBegin(event:ScriptEvent):Void {}
	public function onSubStateOpenEnd(event:ScriptEvent):Void {}
	public function onSubStateCloseBegin(event:ScriptEvent):Void {}
	public function onSubStateCloseEnd(event:ScriptEvent):Void {}
	public function onFocusLost(event:ScriptEvent):Void {}
	public function onFocusGained(event:ScriptEvent):Void {}

	// The Freeplay menu and Character Select
	public function onCapsuleSelected(event:CapsuleScriptEvent):Void {}
	public function onDifficultySwitch(event:CapsuleScriptEvent):Void {}
	public function onSongSelected(event:CapsuleScriptEvent):Void {}
	public function onFreeplayIntroDone(event:FreeplayScriptEvent):Void {}
	public function onFreeplayOutro(event:FreeplayScriptEvent):Void {}
	public function onFreeplayClose(event:FreeplayScriptEvent):Void {}
	public function onCharacterSelect(event:CharacterSelectScriptEvent):Void {}
	public function onCharacterDeselect(event:CharacterSelectScriptEvent):Void {}
	public function onCharacterConfirm(event:CharacterSelectScriptEvent):Void {}
}
