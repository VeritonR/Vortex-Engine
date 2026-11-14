package funkin.play.notes;

// (V-Slice's own imports, from its funkin/import.hx: this file is V-Slice's)
#if !macro
import funkin.util.Constants;
import funkin.Assets;
import funkin.Paths;
import funkin.Preferences;
import flixel.FlxG;
import haxe.ds.Option;

using Lambda;
using StringTools;
using thx.Arrays;
using funkin.util.tools.ArraySortTools;
using funkin.util.tools.ArrayTools;
using funkin.util.tools.FloatTools;
using funkin.util.tools.Int64Tools;
using funkin.util.tools.IntTools;
using funkin.util.tools.IteratorTools;
using funkin.util.tools.MapTools;
using funkin.util.tools.SongEventDataArrayTools;
using funkin.util.tools.SongNoteDataArrayTools;
using funkin.util.tools.StringTools;
using funkin.util.AnsiUtil;
#end

import funkin.util.HapticUtil;
import funkin.util.HapticUtil.HapticsMode;

/**
 * Handles vibrations on note presses.
 */
class NoteVibrationsHandler
{
  /**
   * Left note's status.
   */
  var leftNoteStatus:NoteStatus;

  /**
   * Down note's status.
   */
  var downNoteStatus:NoteStatus;

  /**
   * Up note's status.
   */
  var upNoteStatus:NoteStatus;

  /**
   * Right note's status.
   */
  var rightNoteStatus:NoteStatus;

  /**
   * An array of each note status.
   * Made for use in other classes.
   */
  public var noteStatuses:Array<NoteStatus>;

  /**
   * Creates a new NoteVibrationsHandler instance.
   */
  public function new()
  {
    noteStatuses = [leftNoteStatus, downNoteStatus, upNoteStatus, rightNoteStatus];
  }

  /**
   * Checks if any note status is equal to NoteStatus.isJustPressed.
   * If yes, then vibration is being triggered, amplitude value is stacked depending on how much notes are pressed.
   */
  public function tryNoteVibration():Void
  {
    if (noteStatuses == null || !HapticUtil.hapticsAvailable) return;

    var stackingAmplitude:Float = 0;

    for (currentNoteStatus in noteStatuses)
    {
      if (currentNoteStatus != NoteStatus.confirm) continue;

      stackingAmplitude += Constants.MAX_VIBRATION_AMPLITUDE / 4;
    }

    if (stackingAmplitude > Constants.MAX_VIBRATION_AMPLITUDE) stackingAmplitude = Constants.MAX_VIBRATION_AMPLITUDE;

    if (stackingAmplitude > 0) HapticUtil.vibrate(0, 0.01, stackingAmplitude * 2.5, 1, [HapticsMode.ALL, HapticsMode.NOTES_ONLY]);
  }

  /**
   * Checks if any note status is equal to NoteStatus.isHoldNotePressed.
   * If yes, then vibration is being triggered, amplitude value is stacked depending on how much hold notes are pressed.
   */
  public function tryHoldNoteVibration(holdNoteEnded:Bool = false):Void
  {
    if (noteStatuses == null || !HapticUtil.hapticsAvailable) return;

    var stackingAmplitude:Float = 0;

    for (currentNoteStatus in noteStatuses)
    {
      if (currentNoteStatus != NoteStatus.holdConfirm) continue;

      var amplitudeDivider:Float = holdNoteEnded ? 4 : 10;
      stackingAmplitude += Constants.MAX_VIBRATION_AMPLITUDE / amplitudeDivider;
    }

    if (stackingAmplitude > Constants.MAX_VIBRATION_AMPLITUDE) stackingAmplitude = Constants.MAX_VIBRATION_AMPLITUDE;

    if (stackingAmplitude > 0) HapticUtil.vibrate(0, 0.01, stackingAmplitude * 2.5, 1, [HapticsMode.ALL, HapticsMode.NOTES_ONLY]);

    for (currentNoteStatus in noteStatuses)
    {
      if (currentNoteStatus == NoteStatus.holdConfirm && holdNoteEnded) currentNoteStatus == NoteStatus.pressed;
    }
  }
}

/**
 * An abstract that represents the note status for NoteVibrationsHandler.
 */
enum abstract NoteStatus(Int) from Int to Int
{
  public var idle = 0;
  public var pressed = 1;
  public var confirm = 2;
  public var holdConfirm = 3;
}
