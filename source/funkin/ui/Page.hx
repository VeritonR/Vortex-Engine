package funkin.ui;

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

import flixel.group.FlxGroup;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.util.FlxSignal;
import funkin.input.Controls;
import funkin.audio.FunkinSound;

/**
 * A page in a menu system.
 *
 * You can use it on it's own, or handle it with a `Codex`
 */
class Page<T:PageName> extends FlxGroup
{
  public var onSwitch(default, null) = new FlxTypedSignal<T->Void>();
  public var onExit(default, null) = new FlxSignal();
  public var enabled(default, set) = true;
  public var canExit = true;
  public var codex:Codex<T>;

  var controls(get, never):Controls;

  inline function get_controls() return PlayerSettings.player1.controls;

  var subState:FlxSubState;

  inline function switchPage(name:T)
  {
    onSwitch.dispatch(name);
  }

  function exit()
  {
    onExit.dispatch();
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);

    if (enabled) updateEnabled(elapsed);
  }

  function updateEnabled(elapsed:Float)
  {
    if (canExit && controls.BACK_P)
    {
      exit();
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
    }
  }

  function set_enabled(value:Bool)
  {
    return this.enabled = value;
  }

  function openPrompt(prompt:Prompt, onClose:Void->Void)
  {
    // (the engine's Prompt is a group of sprites with its own answers: it's put on the screen, and these close it)
    enabled = false;
    var whenYes = prompt.onYes;
    var whenNo = prompt.onNo;
    function closed()
    {
      enabled = true;
      if (onClose != null) onClose();
    }
    prompt.onYes = function()
    {
      if (whenYes != null) whenYes();
      closed();
    }
    prompt.onNo = function()
    {
      if (whenNo != null) whenNo();
      closed();
    }
    FlxG.state.add(prompt);
  }

  override function destroy()
  {
    super.destroy();
    onSwitch.removeAll();
  }
}

/**
 * For you to fill in your own page name stuff, see OptionsState.hx and it's OptionsMenuPageName
 */
enum abstract PageName(String) from String to String
{
}
