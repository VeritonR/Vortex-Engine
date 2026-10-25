package funkin.modding.events;

/**
 * Names of the events scripts receive. On V-Slice this is an enum of texts, here they're regular variables so scripts can read them.
 */
class ScriptEventType
{
	public static var CREATE:String = 'CREATE';
	public static var DESTROY:String = 'DESTROY';
	public static var ADDED:String = 'ADDED';
	public static var UPDATE:String = 'UPDATE';
	public static var PAUSE:String = 'PAUSE';
	public static var RESUME:String = 'RESUME';
	public static var SONG_BEAT_HIT:String = 'BEAT_HIT';
	public static var SONG_STEP_HIT:String = 'STEP_HIT';
	public static var NOTE_INCOMING:String = 'NOTE_INCOMING';
	public static var NOTE_HIT:String = 'NOTE_HIT';
	public static var NOTE_MISS:String = 'NOTE_MISS';
	public static var NOTE_HOLD_DROP:String = 'NOTE_HOLD_DROP';
	public static var NOTE_GHOST_MISS:String = 'NOTE_GHOST_MISS';
	public static var SONG_EVENT:String = 'SONG_EVENT';
	public static var SONG_START:String = 'SONG_START';
	public static var SONG_END:String = 'SONG_END';
	public static var COUNTDOWN_START:String = 'COUNTDOWN_START';
	public static var COUNTDOWN_STEP:String = 'COUNTDOWN_STEP';
	public static var COUNTDOWN_END:String = 'COUNTDOWN_END';
	public static var GAME_OVER:String = 'GAME_OVER';
	public static var SONG_RETRY:String = 'SONG_RETRY';
	public static var SONG_LOADED:String = 'SONG_LOADED';
	public static var STATE_CHANGE_BEGIN:String = 'STATE_CHANGE_BEGIN';
	public static var STATE_CHANGE_END:String = 'STATE_CHANGE_END';
	public static var SUBSTATE_OPEN_BEGIN:String = 'SUBSTATE_OPEN_BEGIN';
	public static var SUBSTATE_OPEN_END:String = 'SUBSTATE_OPEN_END';
	public static var SUBSTATE_CLOSE_BEGIN:String = 'SUBSTATE_CLOSE_BEGIN';
	public static var SUBSTATE_CLOSE_END:String = 'SUBSTATE_CLOSE_END';
	public static var FOCUS_LOST:String = 'FOCUS_LOST';
	public static var FOCUS_GAINED:String = 'FOCUS_GAINED';
	public static var STATE_CREATE:String = 'STATE_CREATE';
	public static var KEY_DOWN:String = 'KEY_DOWN'; //(V-Slice has these two and never sends them either)
	public static var KEY_UP:String = 'KEY_UP';

	// Dialogues
	public static var DIALOGUE_START:String = 'DIALOGUE_START';
	public static var DIALOGUE_LINE:String = 'DIALOGUE_LINE';
	public static var DIALOGUE_COMPLETE_LINE:String = 'DIALOGUE_COMPLETE_LINE';
	public static var DIALOGUE_SKIP:String = 'DIALOGUE_SKIP';
	public static var DIALOGUE_END:String = 'DIALOGUE_END';

	// The Freeplay menu and Character Select
	public static var CAPSULE_SELECTED:String = 'CAPSULE_SELECTED';
	public static var DIFFICULTY_SWITCH:String = 'DIFFICULTY_SWITCH';
	public static var SONG_SELECTED:String = 'SONG_SELECTED';
	public static var FREEPLAY_INTRO:String = 'FREEPLAY_INTRO';
	public static var FREEPLAY_OUTRO:String = 'FREEPLAY_OUTRO';
	public static var FREEPLAY_CLOSE:String = 'FREEPLAY_CLOSE';
	public static var CHARACTER_SELECTED:String = 'CHARACTER_SELECTED';
	public static var CHARACTER_DESELECTED:String = 'CHARACTER_DESELECTED';
	public static var CHARACTER_CONFIRMED:String = 'CHARACTER_CONFIRMED';

	/**
	 * Function of a scripted class that receives each event.
	 */
	public static var callbacks:Map<String, String> = [
		'CREATE' => 'onCreate',
		'ADDED' => 'onAdd',
		'DESTROY' => 'onDestroy',
		'UPDATE' => 'onUpdate',
		'PAUSE' => 'onPause',
		'RESUME' => 'onResume',
		'BEAT_HIT' => 'onBeatHit',
		'STEP_HIT' => 'onStepHit',
		'NOTE_INCOMING' => 'onNoteIncoming',
		'NOTE_HIT' => 'onNoteHit',
		'NOTE_MISS' => 'onNoteMiss',
		'NOTE_HOLD_DROP' => 'onNoteHoldDrop',
		'NOTE_GHOST_MISS' => 'onNoteGhostMiss',
		'SONG_EVENT' => 'onSongEvent',
		'SONG_START' => 'onSongStart',
		'SONG_END' => 'onSongEnd',
		'COUNTDOWN_START' => 'onCountdownStart',
		'COUNTDOWN_STEP' => 'onCountdownStep',
		'COUNTDOWN_END' => 'onCountdownEnd',
		'GAME_OVER' => 'onGameOver',
		'SONG_RETRY' => 'onSongRetry',
		'SONG_LOADED' => 'onSongLoaded',
		'STATE_CHANGE_BEGIN' => 'onStateChangeBegin',
		'STATE_CHANGE_END' => 'onStateChangeEnd',
		'SUBSTATE_OPEN_BEGIN' => 'onSubStateOpenBegin',
		'SUBSTATE_OPEN_END' => 'onSubStateOpenEnd',
		'SUBSTATE_CLOSE_BEGIN' => 'onSubStateCloseBegin',
		'SUBSTATE_CLOSE_END' => 'onSubStateCloseEnd',
		'STATE_CREATE' => 'onStateCreate',
		'FOCUS_LOST' => 'onFocusLost',
		'FOCUS_GAINED' => 'onFocusGained',
		'KEY_DOWN' => 'onKeyDown',
		'KEY_UP' => 'onKeyUp',
		'DIALOGUE_START' => 'onDialogueStart',
		'DIALOGUE_LINE' => 'onDialogueLine',
		'DIALOGUE_COMPLETE_LINE' => 'onDialogueCompleteLine',
		'DIALOGUE_SKIP' => 'onDialogueSkip',
		'DIALOGUE_END' => 'onDialogueEnd',
		'CAPSULE_SELECTED' => 'onCapsuleSelected',
		'DIFFICULTY_SWITCH' => 'onDifficultySwitch',
		'SONG_SELECTED' => 'onSongSelected',
		'FREEPLAY_INTRO' => 'onFreeplayIntroDone',
		'FREEPLAY_OUTRO' => 'onFreeplayOutro',
		'FREEPLAY_CLOSE' => 'onFreeplayClose',
		'CHARACTER_SELECTED' => 'onCharacterSelect',
		'CHARACTER_DESELECTED' => 'onCharacterDeselect',
		'CHARACTER_CONFIRMED' => 'onCharacterConfirm'
	];
}
