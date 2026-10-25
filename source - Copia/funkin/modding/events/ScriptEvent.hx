package funkin.modding.events;

import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongNoteData;
import funkin.play.notes.NoteSprite;

// The events V-Slice scripts receive, same classes and fields as V-Slice's.
// They're made by `backend.VSliceScripts` out of what happens on Psych's PlayState.

class ScriptEvent
{
	public var cancelable(default, null):Bool;
	public var type(default, null):String;
	public var shouldPropagate(default, null):Bool = true;
	public var eventCanceled(default, null):Bool = false;

	public function new(type:String, cancelable:Bool = false)
	{
		this.type = type;
		this.cancelable = cancelable;
	}

	public function cancelEvent():Void
	{
		if(cancelable) eventCanceled = true;
	}

	public function cancel():Void
	{
		cancelEvent();
	}

	public function stopPropagation():Void
	{
		shouldPropagate = false;
	}

	public function toString():String
	{
		return 'ScriptEvent(type=$type, cancelable=$cancelable)';
	}
}

class NoteScriptEvent extends ScriptEvent
{
	public var note(default, null):NoteSprite;
	public var comboCount(default, null):Int;
	public var playSound:Bool = true;
	public var healthChange:Float;

	public function new(type:String, note:NoteSprite, healthChange:Float, comboCount:Int = 0, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.note = note;
		this.comboCount = comboCount;
		this.healthChange = healthChange;
	}
}

class HitNoteScriptEvent extends NoteScriptEvent
{
	public var judgement:String;
	public var score:Float;
	public var isComboBreak:Bool = false;
	public var hitDiff:Float = 0;
	public var doesNotesplash:Bool = false;

	public function new(note:NoteSprite, healthChange:Float, score:Float, judgement:String, isComboBreak:Bool, comboCount:Int = 0, hitDiff:Float = 0, doesNotesplash:Bool = false)
	{
		super(ScriptEventType.NOTE_HIT, note, healthChange, comboCount, true);
		this.score = score;
		this.judgement = judgement;
		this.isComboBreak = isComboBreak;
		this.doesNotesplash = doesNotesplash;
		this.hitDiff = hitDiff;
	}
}

class GhostMissNoteScriptEvent extends ScriptEvent
{
	public var dir(default, null):Int;
	public var hasPossibleNotes(default, null):Bool;
	public var healthChange:Float;
	public var scoreChange:Float;
	public var playSound:Bool = true;
	public var playAnim:Bool = true;

	public function new(dir:Int, hasPossibleNotes:Bool, healthChange:Float, scoreChange:Float)
	{
		super(ScriptEventType.NOTE_GHOST_MISS, true);
		this.dir = dir;
		this.hasPossibleNotes = hasPossibleNotes;
		this.healthChange = healthChange;
		this.scoreChange = scoreChange;
	}
}

class HoldNoteScriptEvent extends NoteScriptEvent
{
	public var holdNote:NoteSprite;
	public var score:Float;
	public var isComboBreak:Bool = false;
	public var hitDiff:Float = 0;
	public var doesNotesplash:Bool = false;

	public function new(type:String, holdNote:NoteSprite, healthChange:Float, score:Float, isComboBreak:Bool, comboCount:Int = 0, cancelable:Bool = false)
	{
		super(type, null, healthChange, comboCount, true);
		this.holdNote = holdNote;
		this.score = score;
		this.isComboBreak = isComboBreak;
	}
}

class SongEventScriptEvent extends ScriptEvent
{
	public var eventData(default, null):SongEventData;

	public function new(eventData:SongEventData)
	{
		super(ScriptEventType.SONG_EVENT, true);
		this.eventData = eventData;
	}
}

class UpdateScriptEvent extends ScriptEvent
{
	public var elapsed(default, null):Float;

	public function new(elapsed:Float)
	{
		super(ScriptEventType.UPDATE, false);
		this.elapsed = elapsed;
	}
}

class SongTimeScriptEvent extends ScriptEvent
{
	public var beat(default, null):Int;
	public var step(default, null):Int;

	public function new(type:String, beat:Int, step:Int)
	{
		super(type, true);
		this.beat = beat;
		this.step = step;
	}
}

class CountdownScriptEvent extends ScriptEvent
{
	/**
	 * "BEFORE", "THREE", "TWO", "ONE", "GO" or "AFTER".
	 */
	public var step(default, null):String;

	public function new(type:String, step:String, cancelable:Bool = true)
	{
		super(type, cancelable);
		this.step = step;
	}
}

class SongLoadScriptEvent extends ScriptEvent
{
	public var notes:Array<SongNoteData>;
	public var events:Array<SongEventData>;
	public var id(default, null):String;
	public var difficulty(default, null):String;

	public function new(id:String, difficulty:String, notes:Array<SongNoteData>, events:Array<SongEventData>)
	{
		super(ScriptEventType.SONG_LOADED, false);
		this.id = id;
		this.difficulty = difficulty;
		this.notes = notes;
		this.events = events;
	}
}

class SongRetryEvent extends ScriptEvent
{
	public var difficulty(default, null):String;

	public function new(difficulty:String)
	{
		super(ScriptEventType.SONG_RETRY, false);
		this.difficulty = difficulty;
	}
}

/**
 * A state or a substate being opened or closed. Here it's only sent for the menus V-Slice mods change, like the results screen.
 */
class StateChangeScriptEvent extends ScriptEvent
{
	public var targetState(default, null):Dynamic;

	public function new(type:String, targetState:Dynamic, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.targetState = targetState;
	}
}

class SubStateScriptEvent extends StateChangeScriptEvent {}

/**
 * Something about a song of the Freeplay menu: it was moved to, its difficulty was changed or it was picked to be played.
 */
class CapsuleScriptEvent extends ScriptEvent
{
	/**
	 * The song's capsule on the list, its `freeplayData` has what's known about the song (null for "Random").
	 */
	public var capsule(default, null):Dynamic;
	public var difficultyId(default, null):String;
	public var variationId(default, null):String;

	public function new(type:String, capsule:Dynamic, difficultyId:String, variationId:String)
	{
		super(type, false);
		this.capsule = capsule;
		this.difficultyId = difficultyId;
		this.variationId = variationId;
	}
}

class FreeplayScriptEvent extends ScriptEvent
{
	public function new(type:String)
	{
		super(type, false);
	}
}

class CharacterSelectScriptEvent extends ScriptEvent
{
	public var characterId(default, null):String;

	public function new(type:String, characterId:String)
	{
		super(type, false);
		this.characterId = characterId;
	}
}

/**
 * What's going on with a dialogue: it started, the next line was asked for, the line being typed was asked to be shown whole,
 * the whole thing was skipped, or it ended. The ones that are something being asked for can be cancelled.
 */
class DialogueScriptEvent extends ScriptEvent
{
	public var conversation(default, null):Dynamic;

	public function new(type:String, conversation:Dynamic, cancelable:Bool = true)
	{
		super(type, cancelable);
		this.conversation = conversation;
	}
}

class FocusScriptEvent extends ScriptEvent
{
	public function new(type:String)
	{
		super(type, false);
	}
}

class KeyboardInputScriptEvent extends ScriptEvent
{
	public var event(default, null):openfl.events.KeyboardEvent;

	public function new(type:String, event:openfl.events.KeyboardEvent)
	{
		super(type, false);
		this.event = event;
	}
}

class PauseScriptEvent extends ScriptEvent
{
	public var gitaroo:Bool;

	public function new(gitaroo:Bool)
	{
		super(ScriptEventType.PAUSE, true);
		this.gitaroo = gitaroo;
	}
}
