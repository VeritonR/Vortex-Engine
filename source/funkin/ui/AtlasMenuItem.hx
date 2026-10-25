package funkin.ui;

import flixel.graphics.frames.FlxAtlasFrames;

/**
 * An item of a menu of V-Slice, made of the frames "(name) idle" and "(name) selected" of a sprite sheet. Scripts make them to add
 * options to V-Slice's menus.
 */
class AtlasMenuItem extends MenuListItem
{
	var atlas:FlxAtlasFrames;

	public var centered:Bool = false;

	public function new(x:Float = 0, y:Float = 0, name:String, atlas:FlxAtlasFrames, callback:Void->Void, available:Bool = true)
	{
		this.atlas = atlas;
		super(x, y, name, callback, available);
	}

	override function setData(name:String, ?callback:Void->Void, available:Bool):Void
	{
		if(atlas != null) frames = atlas;
		animation.addByPrefix('idle', '$name idle', 24);
		animation.addByPrefix('selected', '$name selected', 24);

		super.setData(name, callback, available);
	}

	public function changeAnim(animName:String):Void
	{
		if(!animation.exists(animName)) return;
		animation.play(animName);
		updateHitbox();

		if(centered)
		{
			// position by center
			centerOrigin();
			offset.copyFrom(origin);
		}
	}

	override public function idle():Void changeAnim('idle');
	override public function select():Void changeAnim('selected');

	override function get_selected():Bool
	{
		return animation.curAnim != null && animation.curAnim.name == 'selected';
	}

	override public function destroy():Void
	{
		super.destroy();
		atlas = null;
	}
}

/**
 * An item of a menu of V-Slice: a sprite with a name and what it does when it's picked.
 */
class MenuListItem extends FlxSprite
{
	public var callback:Void->Void;
	public var name:String;
	public var available:Bool;

	/**
	 * Set to true for things like opening URLs, which can get blocked otherwise.
	 */
	public var fireInstantly:Bool = false;

	public var selected(get, never):Bool;
	function get_selected():Bool return alpha == 1.0;

	public function new(x:Float = 0, y:Float = 0, name:String, callback:Void->Void, available:Bool = true)
	{
		super(x, y);
		this.name = name;
		this.callback = callback;
		this.available = available;
		setData(name, callback, available);
		idle();
	}

	function setData(name:String, ?callback:Void->Void, available:Bool):Void
	{
		this.name = name;
		if(callback != null) this.callback = callback;
		this.available = available;
	}

	public function setItem(name:String, ?callback:Void->Void):Void
	{
		setData(name, callback, available);
		if(selected) select();
		else idle();
	}

	public function idle():Void alpha = 0.6;
	public function select():Void alpha = 1.0;
}
