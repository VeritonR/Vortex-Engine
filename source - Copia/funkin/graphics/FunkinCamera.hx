package funkin.graphics;

/**
 * V-Slice's camera, which scripts make for things of their own (`new FunkinCamera('hud2')`). Here it's flixel's,
 * with V-Slice's way of making it and its name.
 */
class FunkinCamera extends flixel.FlxCamera
{
	public var id:String = 'unknown';

	public function new(id:String = 'unknown', x:Int = 0, y:Int = 0, width:Int = 0, height:Int = 0, zoom:Float = 0)
	{
		super(x, y, width, height, zoom);
		this.id = id;
	}

	override public function toString():String return 'FunkinCamera($id)';
}
