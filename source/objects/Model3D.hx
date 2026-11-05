package objects;

import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.ColorTransform;

/**
 * Vortex Engine: a 3D model (a ".obj" file, with a picture for its texture) on the stage or the HUD, made by Lua with
 * makeLuaModel and changed like a sprite: x / y (where its center is), z, angleX / angleY / angle (turned), modelScale, alpha,
 * color, cameras, scroll factor.
 *
 * It's drawn with flixel's triangles, the far ones first (no depth buffer): fine for models of up to a few thousand triangles.
 * `lighting` shades each triangle by how much it faces the light, `cullBack` skips the ones facing away.
 */
@:access(flixel.FlxSprite)
class Model3D extends FlxSprite
{
	public var angleX:Float = 0;
	public var angleY:Float = 0;
	public var z:Float = 0;
	/** Pixels per unit of the model. Made so its biggest side is 200 pixels when it's loaded. */
	public var modelScale:Float = 1;
	/** Shades each triangle by how much it faces the light (from the front, a little from above and the left). */
	public var lighting:Bool = true;
	/** How dark the side away from the light gets, 0 to 1 (1: no shading). */
	public var ambient:Float = 0.35;
	/** Triangles facing away aren't drawn (closed models look right and draw faster). Off for flat or open models. */
	public var cullBack:Bool = true;

	/** If the model was read. */
	public var loaded(default, null):Bool = false;
	public var triangleCount(get, never):Int;
	inline function get_triangleCount():Int return Std.int(faces.length / 3);

	// The model: positions (x, y, z), texture coordinates (u, v) and, for each triangle, 3 corners of [position, uv]
	var positions:Array<Float> = [];
	var texCoords:Array<Float> = [];
	var faces:Array<Int> = [];
	var faceUVs:Array<Int> = [];

	/**
	 * The materials of the model ("usemtl" in the .obj), in the order they show up. Each one has a color: the "Kd" of its .mtl file
	 * if there is one, white otherwise, and `setMaterialColor()` changes it (a tree's "Bark" brown and "Leaves" green). It's mixed with
	 * the texture, the model's `color` and the lighting.
	 */
	public var materials(default, null):Array<String> = [];
	var materialColors:Array<FlxColor> = [];
	var faceMaterials:Array<Int> = []; //(one per triangle, -1: none)

	// (the turned and projected corners of each frame, kept to not make new arrays every frame)
	var projected:Array<Float> = [];
	var order:Array<Int> = [];
	var depths:Array<Float> = [];
	var shades:Array<Float> = [];
	var points:DrawData<Float> = new DrawData<Float>(6, true);
	var cornerUVs:DrawData<Float> = new DrawData<Float>(6, true);
	var corners:DrawData<Int> = {
		var list:DrawData<Int> = new DrawData<Int>(3, true);
		list[0] = 0; list[1] = 1; list[2] = 2;
		list;
	};
	var shadeTransform:ColorTransform = new ColorTransform();
	// (white: flixel wants colors for the corners whenever the color is changed, even if it only uses the transform's)
	var cornerColors:DrawData<Int> = {
		var list:DrawData<Int> = new DrawData<Int>(3, true);
		for (i in 0...3) list[i] = 0xFFFFFFFF;
		list;
	};

	/**
	 * @param objText   What the ".obj" file has
	 * @param texture   The picture it's painted with (null: plain white, colored with `color` and the materials)
	 * @param mtlText   What its ".mtl" file has (the materials' colors), if it has one
	 */
	public function new(x:Float = 0, y:Float = 0, objText:String, ?texture:flixel.graphics.FlxGraphic, ?mtlText:String)
	{
		super(x, y);
		if(texture != null) loadGraphic(texture);
		else makeGraphic(4, 4, FlxColor.WHITE);
		antialiasing = ClientPrefs.data.antialiasing;
		if(objText != null) readObj(objText);
		// (a model painted with a texture keeps it as it is: the colors of a .mtl go with models that have none, they're usually
		// a plain grey when there's a texture)
		if(mtlText != null && texture == null) readMtl(mtlText);
	}

	/** The "mtllib" file an .obj names (where its materials' colors are), null if none. */
	public static function mtlFileOf(objText:String):String
	{
		for (line in objText.split('\n'))
		{
			line = StringTools.trim(line);
			if(StringTools.startsWith(line, 'mtllib ')) return StringTools.trim(line.substr(7));
		}
		return null;
	}

	/**
	 * Changes the color of one of its materials. False if it has no material with that name.
	 */
	public function setMaterialColor(material:String, value:FlxColor):Bool
	{
		var index:Int = materials.indexOf(material);
		if(index < 0) return false;
		materialColors[index] = value;
		return true;
	}

	function readMtl(text:String):Void
	{
		var current:Int = -1;
		for (line in text.split('\n'))
		{
			var parts:Array<String> = [for (part in ~/\s+/g.split(StringTools.trim(line))) if(part.length > 0) part];
			if(parts.length < 2) continue;
			switch(parts[0])
			{
				case 'newmtl':
					current = materials.indexOf(parts[1]);
				case 'Kd' if(current >= 0 && parts.length >= 4):
					materialColors[current] = FlxColor.fromRGBFloat(Math.min(1, number(parts[1])), Math.min(1, number(parts[2])), Math.min(1, number(parts[3])));
				default:
			}
		}
	}

	function readObj(text:String):Void
	{
		var lines:Array<String> = text.split('\n');
		var material:Int = -1;
		for (line in lines)
		{
			line = StringTools.trim(line);
			if(line.length < 2 || line.charAt(0) == '#') continue;
			var parts:Array<String> = [for (part in ~/\s+/g.split(line)) if(part.length > 0) part];
			switch(parts[0])
			{
				case 'v' if(parts.length >= 4):
					for (i in 1...4) positions.push(number(parts[i]));
				case 'usemtl' if(parts.length >= 2):
					material = materials.indexOf(parts[1]);
					if(material < 0)
					{
						materials.push(parts[1]);
						materialColors.push(FlxColor.WHITE);
						material = materials.length - 1;
					}
				case 'vt' if(parts.length >= 3):
					texCoords.push(number(parts[1]));
					texCoords.push(number(parts[2]));
				case 'f' if(parts.length >= 4):
					// a face of more than 3 corners is made of triangles from its first corner
					var vertexCount:Int = Std.int(positions.length / 3);
					var uvCount:Int = Std.int(texCoords.length / 2);
					var ids:Array<Int> = [];
					var uvIds:Array<Int> = [];
					for (i in 1...parts.length)
					{
						var refs:Array<String> = parts[i].split('/');
						ids.push(objIndex(refs[0], vertexCount));
						uvIds.push((refs.length > 1 && refs[1].length > 0) ? objIndex(refs[1], uvCount) : -1);
					}
					for (i in 1...ids.length - 1)
					{
						if(ids[0] < 0 || ids[i] < 0 || ids[i + 1] < 0) continue;
						faces.push(ids[0]); faces.push(ids[i]); faces.push(ids[i + 1]);
						faceUVs.push(uvIds[0]); faceUVs.push(uvIds[i]); faceUVs.push(uvIds[i + 1]);
						faceMaterials.push(material);
					}
				default:
			}
		}

		// centered on its middle, and 200 pixels on its biggest side
		if(positions.length < 3 || faces.length < 3) return;
		var min:Array<Float> = [positions[0], positions[1], positions[2]];
		var max:Array<Float> = min.copy();
		var i:Int = 0;
		while(i < positions.length)
		{
			for (axis in 0...3)
			{
				min[axis] = Math.min(min[axis], positions[i + axis]);
				max[axis] = Math.max(max[axis], positions[i + axis]);
			}
			i += 3;
		}
		i = 0;
		while(i < positions.length)
		{
			for (axis in 0...3) positions[i + axis] -= (min[axis] + max[axis]) / 2;
			i += 3;
		}
		var biggest:Float = Math.max(max[0] - min[0], Math.max(max[1] - min[1], max[2] - min[2]));
		modelScale = (biggest > 0) ? 200 / biggest : 1;
		loaded = true;
	}

	static inline function number(text:String):Float
	{
		var value:Float = Std.parseFloat(text);
		return Math.isNaN(value) ? 0 : value;
	}

	// (indices in a ".obj" start at 1, and negative ones count from the end)
	static function objIndex(text:String, count:Int):Int
	{
		var value:Null<Int> = Std.parseInt(text);
		if(value == null || value == 0) return -1;
		var index:Int = (value > 0) ? value - 1 : count + value;
		return (index >= 0 && index < count) ? index : -1;
	}

	override function draw()
	{
		if(!loaded || alpha == 0 || graphic == null) return;

		var radZ:Float = angle * Math.PI / 180;
		var radX:Float = angleX * Math.PI / 180;
		var radY:Float = angleY * Math.PI / 180;
		var cosZ:Float = Math.cos(radZ), sinZ:Float = Math.sin(radZ);
		var cosX:Float = Math.cos(radX), sinX:Float = Math.sin(radX);
		var cosY:Float = Math.cos(radY), sinY:Float = Math.sin(radY);
		var eye:Float = backend.Perspective3D.eyeDistance;

		// The corners turned: the same order as the 3D sprites (on the screen, forward/back, then left/right). A model's "up" is
		// the screen's up. Kept as x, y, depth in front of the eye
		var count:Int = Std.int(positions.length / 3);
		if(projected.length != count * 3) projected.resize(count * 3);
		for (v in 0...count)
		{
			var px:Float = positions[v * 3] * modelScale * scale.x;
			var py:Float = -positions[v * 3 + 1] * modelScale * scale.y;
			var pz:Float = -positions[v * 3 + 2] * modelScale * scale.x; //(a ".obj" has its front toward +z, the viewer: here +z is away)

			var x1:Float = px * cosZ - py * sinZ;
			var y1:Float = px * sinZ + py * cosZ;
			var y2:Float = y1 * cosX - pz * sinX;
			var z2:Float = y1 * sinX + pz * cosX;
			var x3:Float = x1 * cosY + z2 * sinY;
			var z3:Float = -x1 * sinY + z2 * cosY;
			projected[v * 3] = x3;
			projected[v * 3 + 1] = y2;
			projected[v * 3 + 2] = eye + z + z3;
		}

		for (camera in cameras)
		{
			if(camera == null || !camera.visible || !camera.exists) continue;
			getScreenPosition(_point, camera);
			drawOn(camera, _point.x, _point.y, eye);
		}
	}

	function drawOn(camera:FlxCamera, centerX:Float, centerY:Float, eye:Float):Void
	{
		var viewX:Float = camera.width / 2;
		var viewY:Float = camera.height / 2;
		var triangles:Int = Std.int(faces.length / 3);

		// which triangles are seen, how far they are, and how lit
		order.resize(0);
		if(depths.length != triangles) { depths.resize(triangles); shades.resize(triangles); }
		for (t in 0...triangles)
		{
			var a:Int = faces[t * 3] * 3, b:Int = faces[t * 3 + 1] * 3, c:Int = faces[t * 3 + 2] * 3;
			if(projected[a + 2] <= 1 || projected[b + 2] <= 1 || projected[c + 2] <= 1) continue; //(behind the eye)

			// (its facing, in 3D: toward the eye or away)
			var ux:Float = projected[b] - projected[a], uy:Float = projected[b + 1] - projected[a + 1], uz:Float = projected[b + 2] - projected[a + 2];
			var vx:Float = projected[c] - projected[a], vy:Float = projected[c + 1] - projected[a + 1], vz:Float = projected[c + 2] - projected[a + 2];
			var nx:Float = uy * vz - uz * vy;
			var ny:Float = uz * vx - ux * vz;
			var nz:Float = ux * vy - uy * vx;
			var length:Float = Math.sqrt(nx * nx + ny * ny + nz * nz);
			if(length <= 0) continue;
			nx /= length; ny /= length; nz /= length;

			var toEyeX:Float = -(projected[a] + centerX - viewX), toEyeY:Float = -(projected[a + 1] + centerY - viewY), toEyeZ:Float = -projected[a + 2];
			if(cullBack && nx * toEyeX + ny * toEyeY + nz * toEyeZ <= 0) continue;

			// (the light comes from the eye's side, a little from above and the left; both faces are lit for open models)
			var light:Float = Math.abs(nx * -0.3 + ny * -0.4 + nz * -0.866);
			shades[t] = lighting ? ambient + (1 - ambient) * light : 1;
			depths[t] = projected[a + 2] + projected[b + 2] + projected[c + 2];
			order.push(t);
		}
		order.sort(function(first:Int, second:Int):Int return depths[first] < depths[second] ? 1 : (depths[first] > depths[second] ? -1 : 0));

		// The triangles go to flixel in runs of the same color (each run is one call, with one color for all of it), from the
		// farthest to the closest. (A color per call: see Perspective3D.freshBatch() for why each call is a batch of its own)
		var base:ColorTransform = colorTransform;
		_point.set(0, 0);
		runLength = 0;
		var runRed:Float = -1, runGreen:Float = -1, runBlue:Float = -1;
		for (t in order)
		{
			for (k in 0...3)
			{
				var v:Int = faces[t * 3 + k] * 3;
				var scale:Float = eye / projected[v + 2];
				points[k * 2] = viewX + (centerX + projected[v] - viewX) * scale;
				points[k * 2 + 1] = viewY + (centerY + projected[v + 1] - viewY) * scale;

				var uv:Int = faceUVs[t * 3 + k];
				if(uv >= 0)
				{
					cornerUVs[k * 2] = texCoords[uv * 2];
					cornerUVs[k * 2 + 1] = 1 - texCoords[uv * 2 + 1]; //(a ".obj" counts v from the bottom)
				}
				else
				{
					cornerUVs[k * 2] = 0.5;
					cornerUVs[k * 2 + 1] = 0.5;
				}
			}

			if(!backend.Perspective3D.onCamera(points, camera)) continue; //(off the camera: see Perspective3D.onCamera())

			// (the shading in 64 steps: the eye can't tell them apart, and more triangles end up in a run)
			var shade:Float = Math.round(shades[t] * 64) / 64;
			var material:Int = faceMaterials[t];
			var tint:FlxColor = (material >= 0) ? materialColors[material] : FlxColor.WHITE;
			var red:Float = base.redMultiplier * shade * tint.redFloat;
			var green:Float = base.greenMultiplier * shade * tint.greenFloat;
			var blue:Float = base.blueMultiplier * shade * tint.blueFloat;
			if(runLength > 0 && (red != runRed || green != runGreen || blue != runBlue)) drawRun(camera);
			runRed = red; runGreen = green; runBlue = blue;

			for (k in 0...3)
			{
				runPoints[runLength * 6 + k * 2] = points[k * 2];
				runPoints[runLength * 6 + k * 2 + 1] = points[k * 2 + 1];
				runUVs[runLength * 6 + k * 2] = cornerUVs[k * 2];
				runUVs[runLength * 6 + k * 2 + 1] = cornerUVs[k * 2 + 1];
				runIndices[runLength * 3 + k] = runLength * 3 + k;
				runColors[runLength * 3 + k] = 0xFFFFFFFF; //(white: see cornerColors)
			}
			runLength++;
			shadeTransform.redMultiplier = red;
			shadeTransform.greenMultiplier = green;
			shadeTransform.blueMultiplier = blue;
			shadeTransform.alphaMultiplier = base.alphaMultiplier;
		}
		if(runLength > 0) drawRun(camera);
	}

	// (the run being put together: the corners, texture points and order of its triangles)
	var runPoints:DrawData<Float> = new DrawData<Float>();
	var runUVs:DrawData<Float> = new DrawData<Float>();
	var runIndices:DrawData<Int> = new DrawData<Int>();
	var runColors:DrawData<Int> = new DrawData<Int>();
	var runLength:Int = 0;

	function drawRun(camera:FlxCamera):Void
	{
		runPoints.length = runLength * 6;
		runUVs.length = runLength * 6;
		runIndices.length = runLength * 3;
		runColors.length = runLength * 3;
		backend.Perspective3D.freshBatch(camera, graphic, antialiasing, blend, shadeTransform, shader);
		camera.drawTriangles(graphic, runPoints, runIndices, runUVs, runColors, _point, blend, true, antialiasing, shadeTransform, shader);
		runLength = 0;
	}

	override function destroy()
	{
		positions = texCoords = projected = depths = shades = null;
		faces = faceUVs = order = faceMaterials = null;
		materialColors = null;
		super.destroy();
	}
}
