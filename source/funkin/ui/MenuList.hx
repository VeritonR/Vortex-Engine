package funkin.ui;

import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxSignal.FlxTypedSignal;
import funkin.audio.FunkinSound;
import funkin.ui.AtlasMenuItem.MenuListItem;

/**
 * V-Slice's menus made of a list of items (`TextMenuList`, the options pages, the main menu's): UP/DOWN (or LEFT/RIGHT) to move,
 * ENTER to pick. The picked item flickers for a second and then does what it does, unless it's `fireInstantly`.
 * Ported from V-Slice (funkin.ui.MenuList) for the mods that make menus of their own with it. Touch input isn't here.
 */
class MenuTypedList<T:MenuListItem> extends FlxTypedGroup<T>
{
	public static var pauseInput:Bool = false;

	public var selectedIndex(default, null):Int = 0;
	public var selectedItem(get, never):T;

	/** Called when another item is highlighted. */
	public var onChange(default, null) = new FlxTypedSignal<T->Void>();

	/** Called when an item is picked. */
	public var onAcceptPress(default, null) = new FlxTypedSignal<T->Void>();

	public var navControls:NavControls;

	/** Set to false to stop moving through it. */
	public var enabled:Bool = true;

	public var wrapMode:WrapMode = Both;

	public var byName(default, null):Map<String, T> = new Map<String, T>();

	/** While an item that was picked flickers. */
	public var busy:Bool = false;

	public function new(?navControls:NavControls, ?wrapMode:WrapMode)
	{
		this.navControls = (navControls != null) ? navControls : Vertical;
		if(wrapMode != null) this.wrapMode = wrapMode;
		else
		{
			this.wrapMode = switch(this.navControls)
			{
				case Horizontal: Horizontal;
				case Vertical: Vertical;
				default: Both;
			}
		}
		super();
	}

	public function addItem(name:String, item:T):T
	{
		if(length == selectedIndex) item.select();
		byName.set(name, item);
		return add(item);
	}

	public function resetItem(oldName:String, newName:String, ?callback:Void->Void):T
	{
		var item:T = byName.get(oldName);
		if(item == null) throw 'No item named: $oldName';
		byName.remove(oldName);
		byName.set(newName, item);
		item.setItem(newName, callback);
		return item;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(enabled && !busy && !pauseInput) updateControls();
	}

	function updateControls():Void
	{
		var controls:backend.Controls = PlayerSettings.player1.controls;
		var wrapX:Bool = (wrapMode == Horizontal || wrapMode == Both);
		var wrapY:Bool = (wrapMode == Vertical || wrapMode == Both);

		var up:Bool = controls.UI_UP_P;
		var down:Bool = controls.UI_DOWN_P;
		var left:Bool = controls.UI_LEFT_P;
		var right:Bool = controls.UI_RIGHT_P;

		var newIndex:Int = switch(navControls)
		{
			case Vertical: navList(up, down, wrapY);
			case Horizontal: navList(left, right, wrapX);
			case Both: navList(left || up, right || down, wrapMode != None);
			case Columns(num): navGrid(num, left, right, wrapX, up, down, wrapY);
			case Rows(num): navGrid(num, up, down, wrapY, left, right, wrapX);
		};

		if(newIndex != selectedIndex)
		{
			FunkinSound.playOnce(backend.Paths.sound('scrollMenu'), 0.4);
			selectItem(newIndex);
		}

		if(controls.ACCEPT) accept();
	}

	function navAxis(index:Int, size:Int, prev:Bool, next:Bool, allowWrap:Bool):Int
	{
		if(prev == next) return index;
		if(prev)
		{
			if(index > 0) index--;
			else if(allowWrap) index = size - 1;
		}
		else
		{
			if(index < size - 1) index++;
			else if(allowWrap) index = 0;
		}
		return index;
	}

	inline function navList(prev:Bool, next:Bool, allowWrap:Bool):Int
		return navAxis(selectedIndex, length, prev, next, allowWrap);

	function navGrid(latSize:Int, latPrev:Bool, latNext:Bool, latAllowWrap:Bool, prev:Bool, next:Bool, allowWrap:Bool):Int
	{
		var size:Int = Math.ceil(length / latSize);
		var index:Int = Math.floor(selectedIndex / latSize);
		var latIndex:Int = selectedIndex % latSize;

		latIndex = navAxis(latIndex, latSize, latPrev, latNext, latAllowWrap);
		index = navAxis(index, size, prev, next, allowWrap);
		return Std.int(Math.min(length - 1, index * latSize + latIndex));
	}

	public function accept():Void
	{
		var menuItem:T = members[selectedIndex];
		if(menuItem == null || !menuItem.available) return;

		onAcceptPress.dispatch(menuItem);
		if(menuItem.fireInstantly)
		{
			if(menuItem.callback != null) menuItem.callback();
		}
		else
		{
			busy = true;
			FunkinSound.playOnce(backend.Paths.sound('confirmMenu'));
			FlxFlicker.flicker(menuItem, 1, 0.06, true, false, function(_)
			{
				busy = false;
				if(menuItem.callback != null) menuItem.callback();
			});
		}
	}

	public function cancelAccept():Void
	{
		if(members[selectedIndex] != null) FlxFlicker.stopFlickering(members[selectedIndex]);
		busy = false;
	}

	/**
	 * Highlights an item, or the next one that can be picked if that one can't.
	 */
	public function selectItem(index:Int):Void
	{
		if(index < 0 || index >= members.length) return;
		if(members[selectedIndex] != null) members[selectedIndex].idle();

		if(!members[index].available)
		{
			if(index < selectedIndex)
			{
				var other:Int = (index - 1 < 0) ? index + 1 : index - 1;
				if(other != index && other != selectedIndex) selectItem(other);
				return;
			}
			else if(index > selectedIndex)
			{
				var other:Int = (index + 1 >= members.length) ? index - 1 : index + 1;
				if(other != index && other != selectedIndex) selectItem(other);
				return;
			}
		}

		selectedIndex = index;
		var selectedMenuItem:T = members[selectedIndex];
		selectedMenuItem.select();
		onChange.dispatch(selectedMenuItem);
	}

	public function has(name:String):Bool return byName.exists(name);
	public function getItem(name:String):T return byName.get(name);

	override function destroy():Void
	{
		super.destroy();
		byName.clear();
		onChange.removeAll();
		onAcceptPress.removeAll();
	}

	inline function get_selectedItem():T return members[selectedIndex];
}

/**
 * An item of a menu with something drawn over it (its label: a text, a sprite).
 */
class MenuTypedItem<T:FlxSprite> extends MenuListItem
{
	public var label(default, set):T;

	public function new(x:Float = 0, y:Float = 0, label:T, name:String, callback:Void->Void, available:Bool = true)
	{
		super(x, y, name, callback, available);
		this.label = label; //(after super: the setters need the item made)
	}

	/**
	 * Only the label is seen.
	 */
	public function setEmptyBackground():Void
	{
		var oldWidth:Float = width;
		var oldHeight:Float = height;
		makeGraphic(1, 1, 0x0);
		width = oldWidth;
		height = oldHeight;
	}

	function set_label(value:T):T
	{
		if(value != null)
		{
			value.x = x;
			value.y = y;
			value.alpha = alpha;
		}
		return this.label = value;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if(label != null) label.update(elapsed);
	}

	override function draw()
	{
		super.draw();
		if(label != null)
		{
			label.cameras = cameras;
			label.scrollFactor.copyFrom(scrollFactor);
			label.draw();
		}
	}

	override function set_alpha(value:Float):Float
	{
		super.set_alpha(value);
		if(label != null) label.alpha = alpha;
		return alpha;
	}

	override function set_x(value:Float):Float
	{
		super.set_x(value);
		if(label != null) label.x = x;
		return x;
	}

	override function set_y(value:Float):Float
	{
		super.set_y(value);
		if(label != null) label.y = y;
		return y;
	}
}

enum NavControls
{
	Horizontal;
	Vertical;
	Both;
	Columns(num:Int);
	Rows(num:Int);
}

enum WrapMode
{
	Horizontal;
	Vertical;
	Both;
	None;
}
