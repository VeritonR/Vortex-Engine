package funkin.ui.transition.stickers;

#if HSCRIPT_ALLOWED
import funkin.modding.base.ScriptedClasses;

/*
 * V-Slice's "Scripted" class of the sticker packs, see funkin.modding.base.ScriptedClasses.
 */
class ScriptedStickerPack
{
	public static var init:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) return ScriptedClasses.make(StickerPack, args));
	public static function listScriptClasses():Array<String> return ScriptedClasses.list(StickerPack);
}
#end
