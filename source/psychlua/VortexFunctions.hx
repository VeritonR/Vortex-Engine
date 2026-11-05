package psychlua;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end
import objects.Note;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

/**
 * Lua functions only Vortex Engine has (see section 12 of scripts.txt): cameras of the script's own, shaders on whole cameras,
 * the game's window, notes added during the song, extra characters added or taken out during the song, and the clipboard.
 * HScript reaches all of this directly (FlxG.cameras, FlxG.stage.window, game.spawnNote...).
 */
class VortexFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;

		// ------------------------------------------------------------------------------------------
		// Stage
		// ------------------------------------------------------------------------------------------

		// Another stage in the middle of the song, like the "Change Stage" event: changeStage("school", "snap")
		Lua_helper.add_callback(lua, "changeStage", function(name:String, ?flags:String = '') {
			return (PlayState.instance != null) ? PlayState.instance.changeStage(name, flags) : false;
		});

		// ------------------------------------------------------------------------------------------
		// Cameras
		// ------------------------------------------------------------------------------------------

		// A new camera, right over another one ("game", "hud", "other" or one of the script's): sprites go on it with
		// setObjectCamera(sprite, tag), and it's moved, zoomed and tweened by its tag like the song's
		Lua_helper.add_callback(lua, "makeLuaCamera", function(tag:String, ?above:String = 'hud') {
			var variables = MusicBeatState.getVariables();
			tag = LuaUtils.formatVariable(tag);
			if(variables.exists(tag))
			{
				FunkinLua.luaTrace('makeLuaCamera: "$tag" is already used', false, false, FlxColor.RED);
				return false;
			}

			var camera:FlxCamera = new FlxCamera();
			camera.bgColor.alpha = 0;
			var under:FlxCamera = LuaUtils.cameraFromString(above != null ? above : 'hud');
			insertCameraAfter(camera, under);
			variables.set(tag, camera);
			return true;
		});

		Lua_helper.add_callback(lua, "removeLuaCamera", function(tag:String) {
			var variables = MusicBeatState.getVariables();
			var camera:FlxCamera = Std.downcast(variables.get(tag), FlxCamera);
			if(camera == null || isSongCamera(camera)) return false;

			variables.remove(tag);
			if(FlxG.cameras.list.contains(camera)) FlxG.cameras.remove(camera, true);
			else camera.destroy();
			return true;
		});

		Lua_helper.add_callback(lua, "luaCameraExists", function(tag:String) {
			return Std.isOfType(MusicBeatState.getVariables().get(tag), FlxCamera);
		});

		// ------------------------------------------------------------------------------------------
		// Shaders on whole cameras (the ".frag" files of "shaders/", like setSpriteShader). Its values are set with
		// setShaderFloat(tag, ...) and the others, the tag given here
		// ------------------------------------------------------------------------------------------

		funk.addLocalCallback("addCameraShader", function(camera:String, shader:String, ?tag:String) {
			#if (!flash && sys)
			if(!ClientPrefs.data.shaders) return false;
			if(!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader))
			{
				FunkinLua.luaTrace('addCameraShader: Shader $shader is missing!', false, false, FlxColor.RED);
				return false;
			}
			if(tag == null || tag.length < 1) tag = shader;
			tag = LuaUtils.formatVariable(tag);

			var variables = MusicBeatState.getVariables();
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			// (a tag used again: the old shader is taken off first)
			var old:FlxRuntimeShader = Std.downcast(variables.get(tag), FlxRuntimeShader);
			if(old != null) removeShaderFromCameras(old);

			var arr:Array<String> = funk.runtimeShaders.get(shader);
			var made:FlxRuntimeShader = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
			var filters:Array<BitmapFilter> = (cam.filters != null) ? cam.filters.copy() : [];
			filters.push(new ShaderFilter(made));
			cam.filters = filters;
			variables.set(tag, made);
			return true;
			#else
			FunkinLua.luaTrace("addCameraShader: Platform unsupported for Runtime Shaders!", false, false, FlxColor.RED);
			return false;
			#end
		});

		// The shader with that tag, from whatever camera has it. With no tag, every shader of the camera
		Lua_helper.add_callback(lua, "removeCameraShader", function(camera:String, ?tag:String) {
			#if (!flash && sys)
			var variables = MusicBeatState.getVariables();
			if(tag != null && tag.length > 0)
			{
				var shader:FlxRuntimeShader = Std.downcast(variables.get(tag), FlxRuntimeShader);
				if(shader == null) return false;
				removeShaderFromCameras(shader);
				variables.remove(tag);
				return true;
			}

			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(cam.filters == null) return false;
			var kept:Array<BitmapFilter> = [];
			for (filter in cam.filters)
			{
				var shaderFilter:ShaderFilter = Std.downcast(filter, ShaderFilter);
				if(shaderFilter != null && Std.isOfType(shaderFilter.shader, FlxRuntimeShader))
				{
					var tags:Array<String> = [for (key => value in variables) if(value == shaderFilter.shader) key];
					for (key in tags) variables.remove(key);
					continue;
				}
				kept.push(filter);
			}
			cam.filters = kept;
			return true;
			#else
			return false;
			#end
		});

		// Changes a shader value smoothly: tweenShaderFloat('wave', 'strength', 1, 0.5, 'quadOut'). onTweenCompleted(tag) at the end
		Lua_helper.add_callback(lua, "tweenShaderFloat", function(tag:String, shaderTag:String, prop:String, value:Float, duration:Float, ?ease:String = 'linear') {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = ShaderFunctions.getShader(shaderTag);
			if(shader == null) return null;

			var current:Null<Float> = shader.getFloat(prop);
			var from:Float = (current != null && !Math.isNaN(current)) ? current : 0;
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			if(tag != null) LuaUtils.cancelTween(tag);
			var tween:FlxTween = FlxTween.num(from, value, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween) {
					if(originalTag != null)
					{
						variables.remove('tween_' + LuaUtils.formatVariable(originalTag));
						if(PlayState.instance != null) PlayState.instance.callOnLuas('onTweenCompleted', [originalTag, shaderTag]);
					}
				}
			}, function(now:Float) shader.setFloat(prop, now));
			if(tag != null) variables.set('tween_' + LuaUtils.formatVariable(tag), tween);
			return tag;
			#else
			return null;
			#end
		});

		// ------------------------------------------------------------------------------------------
		// The game's window. What a song changes is put back when the song is left (see restoreWindow())
		// ------------------------------------------------------------------------------------------

		Lua_helper.add_callback(lua, "setWindowTitle", function(title:String) {
			keepWindow();
			FlxG.stage.window.title = (title != null) ? title : '';
		});
		Lua_helper.add_callback(lua, "getWindowTitle", function() return FlxG.stage.window.title);
		Lua_helper.add_callback(lua, "setWindowPosition", function(x:Int, y:Int) {
			if(FlxG.stage.window.fullscreen) return false;
			keepWindow();
			FlxG.stage.window.move(x, y);
			return true;
		});
		Lua_helper.add_callback(lua, "getWindowX", function() return FlxG.stage.window.x);
		Lua_helper.add_callback(lua, "getWindowY", function() return FlxG.stage.window.y);
		Lua_helper.add_callback(lua, "setWindowSize", function(width:Int, height:Int) {
			if(FlxG.stage.window.fullscreen || width < 160 || height < 90) return false;
			keepWindow();
			FlxG.stage.window.resize(width, height);
			return true;
		});
		Lua_helper.add_callback(lua, "getWindowWidth", function() return FlxG.stage.window.width);
		Lua_helper.add_callback(lua, "getWindowHeight", function() return FlxG.stage.window.height);
		// (the monitor the window is on)
		Lua_helper.add_callback(lua, "getScreenWidth", function() {
			var display = FlxG.stage.window.display;
			return (display != null) ? Std.int(display.bounds.width) : 0;
		});
		Lua_helper.add_callback(lua, "getScreenHeight", function() {
			var display = FlxG.stage.window.display;
			return (display != null) ? Std.int(display.bounds.height) : 0;
		});
		Lua_helper.add_callback(lua, "isWindowFullscreen", function() return FlxG.stage.window.fullscreen);
		// A message box of the system (the game waits until it's closed)
		Lua_helper.add_callback(lua, "windowAlert", function(message:String, ?title:String) {
			FlxG.stage.window.alert(message != null ? message : '', (title != null) ? title : FlxG.stage.window.title);
		});

		// ------------------------------------------------------------------------------------------
		// Notes and extra characters during the song
		// ------------------------------------------------------------------------------------------

		// spawnNote(time in ms, column, mustPress, hold length in ms, note type, who sings it): a note like the chart's
		Lua_helper.add_callback(lua, "spawnNote", function(strumTime:Float, column:Int, mustPress:Bool, ?sustainLength:Float = 0, ?noteType:String = '', ?singers:String) {
			var game:PlayState = PlayState.instance;
			if(game == null) return false;
			var note:Note = game.spawnNote(strumTime, column, mustPress, sustainLength, noteType, singers);
			if(note == null)
			{
				FunkinLua.luaTrace('spawnNote: there is no column $column (this song has ' + game.totalColumns + ' arrows per side)', false, false, FlxColor.RED);
				return false;
			}
			return true;
		});
		// How many arrows each side has (4 on most songs, 1 to 9 with extra keys)
		Lua_helper.add_callback(lua, "getKeyCount", function() return (PlayState.instance != null) ? PlayState.instance.totalColumns : 4);

		Lua_helper.add_callback(lua, "addExtraCharacter", function(tag:String, character:String, ?side:String = 'opponent', ?x:Float = 0, ?y:Float = 0, ?singsAll:Bool = false, ?behind:Bool = false) {
			var game:PlayState = PlayState.instance;
			if(game == null) return false;
			var done:Bool = game.addExtraCharacter(tag, character, side, x, y, singsAll, behind);
			if(!done) FunkinLua.luaTrace('addExtraCharacter: the tag "$tag" is already used, or there is no character "$character"', false, false, FlxColor.RED);
			return done;
		});
		Lua_helper.add_callback(lua, "removeExtraCharacter", function(tag:String) {
			return (PlayState.instance != null) ? PlayState.instance.removeExtraCharacter(tag) : false;
		});
		Lua_helper.add_callback(lua, "getExtraCharacters", function() {
			var tags:Array<String> = [];
			if(PlayState.instance != null) for (extra in PlayState.instance.extraCharacters) tags.push(extra.tag);
			return tags;
		});

		// ------------------------------------------------------------------------------------------
		// 3D. Lua sprites, receptors and notes are turned with their angleX / angleY / z (setProperty('box.angleY', 45));
		// whole cameras and .obj models with these
		// ------------------------------------------------------------------------------------------

		// A whole camera turned: setCamera3D('hud', 30, 0, 0) tilts the receptors and the notes back. All zero: as it was
		Lua_helper.add_callback(lua, "setCamera3D", function(camera:String, ?angleX:Float = 0, ?angleY:Float = 0, ?z:Float = 0) {
			return backend.Camera3D.set(LuaUtils.cameraFromString(camera), angleX, angleY, z);
		});
		Lua_helper.add_callback(lua, "getCamera3D", function(camera:String) {
			var values:Array<Float> = backend.Camera3D.get(LuaUtils.cameraFromString(camera));
			return {angleX: values[0], angleY: values[1], z: values[2]};
		});
		// The same, little by little: onTweenCompleted(tag, camera) at the end, cancelTween(tag) stops it
		Lua_helper.add_callback(lua, "tweenCamera3D", function(tag:String, camera:String, angleX:Float, angleY:Float, z:Float, duration:Float, ?ease:String = 'linear') {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			var from:Array<Float> = backend.Camera3D.get(cam);
			var variables = MusicBeatState.getVariables();
			var key:String = (tag != null) ? 'tween_' + LuaUtils.formatVariable(tag) : null;
			if(tag != null) LuaUtils.cancelTween(tag);
			var tween:FlxTween = FlxTween.num(0, 1, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween) {
					if(key == null) return;
					variables.remove(key);
					if(PlayState.instance != null) PlayState.instance.callOnLuas('onTweenCompleted', [tag, camera]);
				}
			}, function(progress:Float) {
				backend.Camera3D.set(cam, FlxMath.lerp(from[0], angleX, progress), FlxMath.lerp(from[1], angleY, progress), FlxMath.lerp(from[2], z, progress));
			});
			if(key != null) variables.set(key, tween);
			return tag;
		});
		// How strong the perspective is: the distance from the eye to the screen, in pixels (1000 if not changed; smaller is stronger)
		Lua_helper.add_callback(lua, "setPerspective", function(distance:Float) {
			if(Math.isNaN(distance) || distance < 50) return false;
			backend.Perspective3D.eyeDistance = distance;
			return true;
		});

		// A 3D model: "models/NAME.obj" of the mod, painted with an image of "images/" (optional). Put on the screen with
		// addLuaSprite(tag), changed with setProperty (x, y, z, angleX, angleY, angle, modelScale, lighting, cullBack, alpha...)
		Lua_helper.add_callback(lua, "makeLuaModel", function(tag:String, model:String, ?texture:String, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var path:String = findModel(model);
			if(path == null)
			{
				FunkinLua.luaTrace('makeLuaModel: there is no model "$model" (models/$model.obj)', false, false, FlxColor.RED);
				return false;
			}
			var graphic:flixel.graphics.FlxGraphic = (texture != null && texture.length > 0) ? Paths.image(texture) : null;
			var objText:String = sys.io.File.getContent(path);
			// (the colors of its materials, from the .mtl file the .obj names, next to it)
			var mtlText:String = null;
			var mtlName:String = objects.Model3D.mtlFileOf(objText);
			if(mtlName != null)
			{
				var mtlPath:String = haxe.io.Path.join([haxe.io.Path.directory(path), mtlName]);
				if(sys.FileSystem.exists(mtlPath)) mtlText = sys.io.File.getContent(mtlPath);
			}
			var made:objects.Model3D = new objects.Model3D(x, y, objText, graphic, mtlText);
			if(!made.loaded)
			{
				FunkinLua.luaTrace('makeLuaModel: "$model" has no triangles that could be read', false, false, FlxColor.RED);
				made.destroy();
				return false;
			}
			MusicBeatState.getVariables().set(tag, made);
			return true;
		});

		// The color of one of a model's materials (the parts its .obj names with "usemtl": a tree's trunk and leaves)
		Lua_helper.add_callback(lua, "setModelMaterialColor", function(tag:String, material:String, color:String) {
			var made:objects.Model3D = Std.downcast(MusicBeatState.getVariables().get(tag), objects.Model3D);
			if(made == null)
			{
				FunkinLua.luaTrace('setModelMaterialColor: there is no model "$tag"', false, false, FlxColor.RED);
				return false;
			}
			if(!made.setMaterialColor(material, CoolUtil.colorFromString(color)))
			{
				FunkinLua.luaTrace('setModelMaterialColor: "$tag" has no material "$material" (it has: ' + made.materials.join(', ') + ')', false, false, FlxColor.RED);
				return false;
			}
			return true;
		});
		Lua_helper.add_callback(lua, "getModelMaterials", function(tag:String) {
			var made:objects.Model3D = Std.downcast(MusicBeatState.getVariables().get(tag), objects.Model3D);
			return (made != null) ? made.materials.copy() : [];
		});

		// ------------------------------------------------------------------------------------------
		// Clipboard
		// ------------------------------------------------------------------------------------------

		Lua_helper.add_callback(lua, "setClipboard", function(text:String) lime.system.Clipboard.text = (text != null) ? text : '');
		Lua_helper.add_callback(lua, "getClipboard", function() {
			var text:String = lime.system.Clipboard.text;
			return (text != null) ? text : '';
		});
	}

	// ------------------------------------------------------------------------------------------

	static function isSongCamera(camera:FlxCamera):Bool
	{
		var game:PlayState = PlayState.instance;
		if(game == null) return false;
		return camera == game.camGame || camera == game.camHUD || camera == game.camOther || camera == game.camOverlay;
	}

	// (flixel has no way to put a camera between others: the ones from there on are taken out and put back after it)
	static function insertCameraAfter(camera:FlxCamera, under:FlxCamera):Void
	{
		var index:Int = (under != null) ? FlxG.cameras.list.indexOf(under) : -1;
		if(index < 0)
		{
			FlxG.cameras.add(camera, false);
			return;
		}
		var after:Array<FlxCamera> = FlxG.cameras.list.slice(index + 1);
		@:privateAccess var drawTargets:Array<Bool> = [for (other in after) FlxG.cameras.defaults.contains(other)];
		for (other in after) FlxG.cameras.remove(other, false);
		FlxG.cameras.add(camera, false);
		for (i => other in after) FlxG.cameras.add(other, drawTargets[i]);
	}

	#if (!flash && sys)
	static function removeShaderFromCameras(shader:FlxRuntimeShader):Void
	{
		for (camera in FlxG.cameras.list)
		{
			if(camera == null || camera.filters == null) continue;
			var kept:Array<BitmapFilter> = [for (filter in camera.filters) if(!(Std.isOfType(filter, ShaderFilter) && cast(filter, ShaderFilter).shader == shader)) filter];
			if(kept.length != camera.filters.length) camera.filters = kept;
		}
	}
	#end

	// "models/NAME.obj" (or NAME with its own ".obj" or folder) in the mods, then the game's own
	static function findModel(name:String):String
	{
		if(name == null || name.length < 1) return null;
		var file:String = name.endsWith('.obj') ? name : name + '.obj';
		var keys:Array<String> = file.startsWith('models/') ? [file] : ['models/' + file, file];
		for (key in keys)
		{
			#if MODS_ALLOWED
			var modded:String = Paths.modFolders(key);
			if(sys.FileSystem.exists(modded)) return modded;
			#end
			var shared:String = Paths.getSharedPath(key);
			if(sys.FileSystem.exists(shared)) return shared;
		}
		return null;
	}

	// What the window was before a script changed it, put back when the song is left
	static var windowBefore:{title:String, x:Int, y:Int, width:Int, height:Int} = null;

	static function keepWindow():Void
	{
		if(windowBefore != null) return;
		var window = FlxG.stage.window;
		windowBefore = {title: window.title, x: window.x, y: window.y, width: window.width, height: window.height};
	}

	public static function restoreWindow():Void
	{
		if(windowBefore == null) return;
		var window = FlxG.stage.window;
		window.title = windowBefore.title;
		if(!window.fullscreen)
		{
			if(window.width != windowBefore.width || window.height != windowBefore.height) window.resize(windowBefore.width, windowBefore.height);
			if(window.x != windowBefore.x || window.y != windowBefore.y) window.move(windowBefore.x, windowBefore.y);
		}
		windowBefore = null;
	}
}
