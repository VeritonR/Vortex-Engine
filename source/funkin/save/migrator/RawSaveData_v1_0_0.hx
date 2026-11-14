package funkin.save.migrator;

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

import thx.semver.Version;

typedef RawSaveData_v1_0_0 =
{
  var seenVideo:Bool;
  var mute:Bool;
  var volume:Float;
  var sessionId:String;
  var songCompletion:Map<String, Float>;
  var songScores:Map<String, Int>;
  var ?controls:
    {
      ?p1:SavePlayerControlsData_v1_0_0,
      ?p2:SavePlayerControlsData_v1_0_0
    };
  var enabledMods:Array<String>;
  var weeksUnlocked:Array<Bool>;
  var windowSettings:Array<Bool>;
}

typedef SavePlayerControlsData_v1_0_0 =
{
  var keys:SaveControlsData_v1_0_0;
  var pad:SaveControlsData_v1_0_0;
};

typedef SaveControlsData_v1_0_0 =
{
  var ?ACCEPT:Array<Int>;
  var ?BACK:Array<Int>;
  var ?CUTSCENE_ADVANCE:Array<Int>;
  var ?NOTE_DOWN:Array<Int>;
  var ?NOTE_LEFT:Array<Int>;
  var ?NOTE_RIGHT:Array<Int>;
  var ?NOTE_UP:Array<Int>;
  var ?PAUSE:Array<Int>;
  var ?RESET:Array<Int>;
  var ?UI_DOWN:Array<Int>;
  var ?UI_LEFT:Array<Int>;
  var ?UI_RIGHT:Array<Int>;
  var ?UI_UP:Array<Int>;
  var ?VOLUME_DOWN:Array<Int>;
  var ?VOLUME_MUTE:Array<Int>;
  var ?VOLUME_UP:Array<Int>;
};
