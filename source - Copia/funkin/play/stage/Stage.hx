package funkin.play.stage;

import flixel.FlxBasic;
import objects.Character;

#if HSCRIPT_ALLOWED
import hxc.HxcRuntime;
#end

/**
 * The stage as V-Slice scripts know it, and what V-Slice stage scripts extend.
 * The stage itself is still made by Psych out of the mod's stage file, this only gives its things the names scripts look for.
 */
@:access(states.PlayState)
class Stage extends funkin.modding.ScriptedBase
{
	public var id(default, null):String;
	public var stageName:String = null;

	/**
	 * The characters by their kind ("bf", "dad" and "gf").
	 */
	public var characters(default, null):Map<String, Character> = [];

	// Layers of the stage file's things, what scripts add goes behind the ones with a bigger layer
	var layers:Array<{object:FlxBasic, zIndex:Float}> = null;
	var characterLayers:Map<String, Float> = ['gf' => 100, 'dad' => 200, 'bf' => 300];

	var game(get, never):states.PlayState;
	inline function get_game():states.PlayState
		return states.PlayState.instance;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
	}

	// ------------------------------------------------------------------------------------------
	// Stages other than the song's (V-Slice scripts change the stage in the middle of a song)
	// ------------------------------------------------------------------------------------------

	/**
	 * What the stage's file has, as it's written (V-Slice's `_data`: `props`, `directory`, `cameraZoom`...).
	 */
	public var _data(get, never):Dynamic;
	var __data:Dynamic = null;
	function get__data():Dynamic
	{
		if(__data == null) __data = funkin.data.stage.StageRegistry.instance.parseEntryData(id);
		return __data;
	}

	public var alive(default, null):Bool = true;

	// The sprites this stage made when it was built while a song was going on (the song's own stage has them made by PlayState)
	var builtProps:Array<FlxBasic> = null;

	/**
	 * If this is the stage the song was started with, which PlayState makes out of the stage's file (see `backend.VSliceScripts`).
	 */
	@:allow(backend.VSliceScripts)
	var madeForSong:Bool = false;

	// If this is the stage PlayState made for the song, instead of one built after
	inline function isSongStage():Bool return builtProps == null;

	/**
	 * The stage's sprites, without the characters: what scripts go through to take a stage off (`for (sprite in stage.group)`).
	 */
	public var group(get, never):StagePropList;
	function get_group():StagePropList
	{
		var list:Array<FlxBasic> = [];
		if(!isSongStage())
		{
			for (prop in builtProps)
				if(prop != null) list.push(prop);
		}
		else if(game != null)
		{
			for (name in propNames())
			{
				var prop:Dynamic = getNamedProp(name);
				if(Std.isOfType(prop, FlxBasic) && !list.contains(prop)) list.push(prop);
			}
		}
		return new StagePropList(list);
	}

	// Names of the sprites of the stage's file
	function propNames():Array<String>
	{
		var names:Array<String> = [];
		try
		{
			var file:Dynamic = backend.StageData.getStageFile(id);
			var objects:Array<Dynamic> = (file != null && file.vslice != null) ? file.objects : null;
			if(objects != null)
				for (object in objects)
					if(object != null && object.name != null && !backend.StageData.reservedNames.contains(Std.string(object.name)))
						names.push(Std.string(object.name));
		}
		catch(e:Dynamic) {}
		return names;
	}

	/**
	 * Makes the stage's sprites, when it's not the one the song started with: on the stage's file's places and layers, with the
	 * characters' places, the camera's zoom and its offsets of this stage. The characters themselves are the scripts' to change.
	 */
	function buildOtherStage():Void
	{
		if(game == null || builtProps != null) return;
		builtProps = [];

		var file:Dynamic = backend.StageData.getStageFile(id);
		if(file == null)
		{
			trace('The stage "$id" does not exist');
			return;
		}

		// the characters' groups go where the new stage's file puts them, among its sprites (the old stage's are gone by now)
		var place:Int = -1;
		for (group in [game.gfGroup, game.dadGroup, game.boyfriendGroup])
		{
			var index:Int = game.members.indexOf(group);
			if(index > -1 && (place < 0 || index < place)) place = index;
		}
		for (group in [game.gfGroup, game.dadGroup, game.boyfriendGroup])
			game.remove(group, true);

		var made:FlxTypedGroup<FlxBasic> = new FlxTypedGroup<FlxBasic>();
		var hideGirlfriend:Bool = (file.hide_girlfriend == true);
		var objects:Array<Dynamic> = file.objects;
		var list:Map<String, FlxSprite> = [];
		if(objects != null && objects.length > 0)
			list = backend.StageData.addObjectsToState(objects, hideGirlfriend ? null : game.gfGroup, game.dadGroup, game.boyfriendGroup, made);
		else
		{
			if(!hideGirlfriend) made.add(game.gfGroup);
			made.add(game.dadGroup);
			made.add(game.boyfriendGroup);
		}
		if(!made.members.contains(game.gfGroup)) made.add(game.gfGroup); //(hidden, but still where its character is kept)
		game.gfGroup.visible = !hideGirlfriend;

		if(place < 0) place = game.members.length;
		for (object in made.members.copy())
		{
			made.remove(object, true);
			game.insert(place++, object);
			if(object != game.gfGroup && object != game.dadGroup && object != game.boyfriendGroup) builtProps.push(object);
		}

		for (name => sprite in list)
			if(!backend.StageData.reservedNames.contains(name))
				game.variables.set(name, sprite);
		if(file.vslice != null && objects != null) game.setupVSliceProps(objects, list);

		// where the characters stand, and how much they move with the camera
		game.boyfriendGroup.setPosition(file.boyfriend[0], file.boyfriend[1]);
		game.dadGroup.setPosition(file.opponent[0], file.opponent[1]);
		game.gfGroup.setPosition(file.girlfriend[0], file.girlfriend[1]);
		if(file.vslice != null && file.vslice.characters != null)
		{
			var places:Dynamic = file.vslice.characters;
			game.vsliceStagePlaces = places;
			game.boyfriendGroup.scrollFactor.set(places.bf.scroll[0], places.bf.scroll[1]);
			game.dadGroup.scrollFactor.set(places.dad.scroll[0], places.dad.scroll[1]);
			if(file.vslice.gfScroll != null) game.gfGroup.scrollFactor.set(file.vslice.gfScroll[0], file.vslice.gfScroll[1]);
		}

		// the camera
		game.defaultCamZoom = file.defaultZoom;
		var facade:funkin.play.PlayState = funkin.play.PlayState.instance;
		if(facade != null) facade.stageZoom = file.defaultZoom;
		game.boyfriendCameraOffset = (file.camera_boyfriend != null) ? file.camera_boyfriend : [0, 0];
		game.opponentCameraOffset = (file.camera_opponent != null) ? file.camera_opponent : [0, 0];
		game.girlfriendCameraOffset = (file.camera_girlfriend != null) ? file.camera_girlfriend : [0, 0];
		if(file.camera_speed != null) game.cameraSpeed = file.camera_speed;

		layers = null;
	}

	/**
	 * On V-Slice this is what makes the stage's sprites, scripts override it to add their own after calling `super.buildStage()`.
	 * Here it's called when the stage and the characters already exist.
	 *
	 * V-Slice puts each sprite of the stage's file on the stage with `addProp()`, which scripts replace to do things to them as they come
	 * (a shader for everything, a blend mode for the lights...): a script that has its own is given each of those sprites here.
	 */
	public function buildStage():Void
	{
		// a stage other than the one PlayState made for the song (even of the same id: a script going back to the song's stage
		// after taking it off makes it again), that a script is putting in its place
		if(game != null && !madeForSong) buildOtherStage();

		#if HSCRIPT_ALLOWED
		var script = HxcRuntime.getInstance(this);
		if(script == null || game == null || !script.hasMethod('addProp')) return;

		var names:Array<String> = propNames();

		announcingProps = true;
		for (name in names)
		{
			var prop:Dynamic = getNamedProp(name);
			if(Std.isOfType(prop, FlxBasic)) HxcRuntime.call(this, 'addProp', [prop, name]);
		}
		announcingProps = false;
		#end
	}

	// While the sprites the stage already has are being given to the script's `addProp()`: its `super.addProp()` has nothing left to add
	var announcingProps:Bool = false;

	public function fetchAssetPaths():Array<String> return [];

	/**
	 * A sprite of the stage file by its name.
	 */
	public function getNamedProp(name:String):Dynamic
	{
		if(game == null) return null;

		var prop:Dynamic = game.variables.get(name);
		if(prop == null) prop = game.getLuaObject(name);
		return prop;
	}

	/**
	 * Tells the stage about the characters of the song, once they and the scripts made for them exist.
	 * On V-Slice it's the stage that puts the characters on their places, with `addCharacter()`: stage scripts override it to do things to them.
	 */
	public function setupCharacters():Void
	{
		if(game == null) return;
		if(layers == null) loadLayers();

		var list:Array<Character> = [game.gf, game.dad, game.boyfriend];
		var types:Array<String> = ['gf', 'dad', 'bf'];
		for (index => character in list)
		{
			if(character == null || list.indexOf(character) != index) continue;

			character.characterType = types[index];
			character.zIndex = Std.int(characterLayers.get(types[index]));
			character.homePosition = FlxPoint.get(character.x, character.y);

			#if HSCRIPT_ALLOWED
			HxcRuntime.call(this, 'addCharacter', [character, types[index]]);
			#else
			addCharacter(character, types[index]);
			#end
		}
	}

	/**
	 * Called with each character of the song. A character made by a script (`CharacterDataParser.fetchCharacter()`)
	 * is put on the stage where the song's character of that kind is.
	 */
	/**
	 * The characters scripts made and put on the stage, besides the three of the song. The game treats them like those:
	 * they dance to the beat and sing the notes of the side they're on (see `backend.VSliceScripts`).
	 */
	public var extraCharacters(default, null):Array<Character> = [];

	public function addCharacter(character:Character, charType:String):Void
	{
		if(character == null) return;
		if(charType == null) charType = 'other';

		character.characterType = charType;
		characters.set(charType, character);
		// (the health icon becomes the one of the character that's added as the player or the opponent, like on V-Slice: mods add
		// the characters of their "Change Character" events ahead of time and give the song's ones back after, counting on it)
		if(charType == 'bf') character.initHealthIcon(false);
		else if(charType == 'dad') character.initHealthIcon(true);
		if(game == null || (songTypeOf(character) != null && inItsGroup(character)))
		{
			#if HSCRIPT_ALLOWED
			backend.VSliceScripts.characterAdded(character);
			#end
			return;
		}

		// The song's character of that kind was taken off the stage (`remove()`) or killed (`kill()`): this one is the song's now.
		// It's how the mods' "Change Character" events work, they take one out and add another
		var current:Character = songCharacter(charType);
		if(groupOf(charType) != null && (current == null || !inItsGroup(current) || !current.exists))
		{
			replaceSongCharacter(character, charType);
			return;
		}

		var group:FlxSpriteGroup = switch(charType)
		{
			case 'bf': game.boyfriendGroup;
			case 'gf': game.gfGroup;
			default: game.dadGroup;
		}

		// the player's side faces the other way, which characters only find out when they're made
		if(charType == 'bf' && !character.isPlayer)
		{
			character.isPlayer = true;
			character.changeCharacter(character.curCharacter);
		}

		if(group != null)
		{
			character.setPosition(group.x, group.y);
			game.startCharacterPos(character, charType == 'dad');
			character.scrollFactor.copyFrom(group.scrollFactor);
		}

		if(layers == null) loadLayers();
		if(characterLayers.exists(charType)) character.zIndex = Std.int(characterLayers.get(charType));
		character.homePosition = FlxPoint.get(character.x, character.y);
		character.dance();
		add(character);
		if(!extraCharacters.contains(character)) extraCharacters.push(character);

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.characterAdded(character);
		#end
	}

	// The group the song's character of a kind is kept in, null for the kinds that aren't one of the three
	function groupOf(charType:String):FlxSpriteGroup
	{
		if(game == null) return null;
		return switch(charType)
		{
			case 'bf': game.boyfriendGroup;
			case 'gf': game.gfGroup;
			case 'dad': game.dadGroup;
			default: null;
		}
	}

	function songCharacter(charType:String):Character
	{
		if(game == null) return null;
		return switch(charType)
		{
			case 'bf': game.boyfriend;
			case 'gf': game.gf;
			case 'dad': game.dad;
			default: null;
		}
	}

	// Which of the song's three a character is ("bf", "dad" or "gf"), null if it's none of them
	function songTypeOf(character:FlxBasic):String
	{
		if(game == null || character == null) return null;
		if(character == game.boyfriend) return 'bf';
		if(character == game.dad) return 'dad';
		if(character == game.gf) return 'gf';
		return null;
	}

	function inItsGroup(character:FlxBasic):Bool
	{
		var group:FlxSpriteGroup = groupOf(songTypeOf(character));
		return group != null && group.members.contains(cast character);
	}

	// One of the song's characters that's put on the stage again (scripts take one out and put it back to change its layer:
	// `remove(char)` and then `insert(index, char)`): it goes back into its group, which is what has its place and its layer here
	function backIntoGroup(object:FlxBasic):Void
	{
		var group:FlxSpriteGroup = groupOf(songTypeOf(object));
		if(group == null || group.members.contains(cast object)) return;

		game.remove(object, true);
		group.add(cast object);
	}

	// Makes a character the song's one of a kind: on its place, with the notes, the camera and the icon of that side
	function replaceSongCharacter(character:Character, charType:String):Void
	{
		var group:FlxSpriteGroup = groupOf(charType);
		var old:Character = songCharacter(charType);
		if(old != null && old != character && group.members.contains(old)) group.remove(old, true);

		// (from wherever a script had it waiting)
		game.remove(character, true);
		extraCharacters.remove(character);
		if(layers != null)
			for (entry in layers)
				if(entry.object == character)
				{
					layers.remove(entry);
					break;
				}

		if(charType == 'bf' && !character.isPlayer)
		{
			character.isPlayer = true;
			character.changeCharacter(character.curCharacter);
		}

		// (who it is first: where it's put depends on that)
		switch(charType)
		{
			case 'bf': game.boyfriend = character;
			case 'gf': game.gf = character;
			default: game.dad = character;
		}
		#if HSCRIPT_ALLOWED
		if(old != null && old != character) backend.VSliceScripts.characterRemoved(old);
		#end

		character.scrollFactor.copyFrom(group.scrollFactor);
		character.setPosition(0, 0);
		game.startCharacterPos(character, charType == 'dad');
		if(!group.members.contains(character)) group.add(character);

		if(layers == null) loadLayers();
		if(characterLayers.exists(charType)) character.zIndex = Std.int(characterLayers.get(charType));
		character.homePosition = FlxPoint.get(character.x, character.y);
		character.dance();

		// the side's icon is the character's, like V-Slice's own `addCharacter()` leaves it
		if(charType == 'bf' && game.iconP1 != null) game.iconP1.changeIcon(character.healthIcon);
		if(charType == 'dad' && game.iconP2 != null) game.iconP2.changeIcon(character.healthIcon);
		if(charType != 'gf') game.reloadHealthBarColors();

		#if HSCRIPT_ALLOWED
		backend.VSliceScripts.characterAdded(character);
		#end
	}

	// Where the stage's file puts each character (their feet, on V-Slice stages)
	public function getBoyfriendPosition():FlxPoint
		return (game != null && game.boyfriendGroup != null) ? new FlxPoint(game.boyfriendGroup.x, game.boyfriendGroup.y) : new FlxPoint();
	public function getDadPosition():FlxPoint
		return (game != null && game.dadGroup != null) ? new FlxPoint(game.dadGroup.x, game.dadGroup.y) : new FlxPoint();
	public function getGirlfriendPosition():FlxPoint
		return (game != null && game.gfGroup != null) ? new FlxPoint(game.gfGroup.x, game.gfGroup.y) : new FlxPoint();

	public function getBoyfriend(?pop:Bool):Character return (game != null) ? game.boyfriend : null;
	public function getPlayer(?pop:Bool):Character return getBoyfriend();
	public function getDad(?pop:Bool):Character return (game != null) ? game.dad : null;
	public function getOpponent(?pop:Bool):Character return getDad();
	public function getGirlfriend(?pop:Bool):Character return (game != null) ? game.gf : null;

	public function getCharacter(id:String):Character
	{
		return switch(id)
		{
			case 'bf', 'boyfriend', 'player': getBoyfriend();
			case 'dad', 'opponent': getDad();
			case 'gf', 'girlfriend': getGirlfriend();
			default: null;
		}
	}

	// (the song's characters are inside of a group each here: to scripts they're on the stage themselves, where their groups are)
	// The stage is part of PlayState here: what's on the stage is what PlayState has on the game's camera, without the HUD and
	// what scripts put on the other cameras (a black screen for a cutscene), which on V-Slice are PlayState's and not the stage's
	public var members(get, never):Array<FlxBasic>;
	function get_members():Array<FlxBasic>
	{
		if(game == null) return [];
		return [for (member in allMembers()) if(member != null && onGameCamera(member)) member];
	}

	function onGameCamera(member:FlxBasic):Bool
	{
		var cameras:Array<FlxCamera> = null;
		try
		{
			cameras = member.cameras;
		}
		catch(e:Dynamic) {}
		return cameras == null || cameras.contains(game.camGame);
	}

	function allMembers():Array<FlxBasic>
	{
		var list:Array<FlxBasic> = game.members;
		var copied:Bool = false;
		for (charType in ['gf', 'dad', 'bf'])
		{
			var group:FlxSpriteGroup = groupOf(charType);
			var character:Character = songCharacter(charType);
			var index:Int = (group != null) ? list.indexOf(group) : -1;
			if(index < 0 || character == null || !group.members.contains(character)) continue;

			if(!copied)
			{
				list = list.copy();
				copied = true;
			}
			list[index] = character;
		}
		return list;
	}

	// The layer something has: `zIndex` is a variable of everything on V-Slice, here only some classes have it and scripts keep it on the side for the rest
	static function getLayer(object:FlxBasic):Null<Float>
	{
		var value:Dynamic = null;
		#if HSCRIPT_ALLOWED
		value = HxcRuntime.getValue(object, 'zIndex');
		#else
		try
		{
			value = Reflect.getProperty(object, 'zIndex');
		}
		catch(e:Dynamic) {}
		#end
		return Std.isOfType(value, Float) ? value : null;
	}

	// The characters and the sprites of the stage file, with the layers the file gives them
	function loadLayers():Void
	{
		layers = [];
		if(game == null) return;

		var gfLayer:Float = 100;
		var dadLayer:Float = 200;
		var bfLayer:Float = 300;

		var data:Dynamic = null;
		try
		{
			var file:Dynamic = backend.StageData.getStageFile(id);
			data = (file != null && file.vslice != null) ? file.vslice.layers : null;
		}
		catch(e:Dynamic) {}

		if(data != null)
		{
			if(data.gf != null) gfLayer = data.gf;
			if(data.dad != null) dadLayer = data.dad;
			if(data.boyfriend != null) bfLayer = data.boyfriend;

			if(data.props != null)
			{
				for (name in Reflect.fields(data.props))
				{
					var prop:Dynamic = getNamedProp(name);
					if(!Std.isOfType(prop, FlxBasic)) continue;

					var layer:Float = Reflect.field(data.props, name);
					layers.push({object: prop, zIndex: layer});

					// Scripts read it from the prop itself, to put their own things right behind or in front of it
					// (`thing.zIndex = getNamedProp('santa').zIndex - 1`): without it that's the layer -1, behind the whole stage
					#if HSCRIPT_ALLOWED
					if(HxcRuntime.getValue(prop, 'zIndex') == null || HxcRuntime.getValue(prop, 'zIndex') == 0)
					{
						if(HxcRuntime.hasNativeField(prop, 'zIndex')) Reflect.setProperty(prop, 'zIndex', Std.int(layer));
						else HxcRuntime.setExtra(prop, 'zIndex', layer);
					}
					#end
				}
			}
		}

		if(game.gfGroup != null) layers.push({object: game.gfGroup, zIndex: gfLayer});
		if(game.dadGroup != null) layers.push({object: game.dadGroup, zIndex: dadLayer});
		if(game.boyfriendGroup != null) layers.push({object: game.boyfriendGroup, zIndex: bfLayer});

		characterLayers.set('gf', gfLayer);
		characterLayers.set('dad', dadLayer);
		characterLayers.set('bf', bfLayer);

		// The characters have their layer from here on: stage scripts sort everything before the stage is told about its characters,
		// and they'd all be on the layer 0 for it, behind the whole stage
		var names:Array<String> = ['gf', 'dad', 'bf'];
		for (index => character in [game.gf, game.dad, game.boyfriend])
			if(character != null && character.zIndex == 0) character.zIndex = Std.int(characterLayers.get(names[index]));
	}

	/**
	 * Adds something to the stage. Things with a `zIndex` go behind what has a bigger one, like on V-Slice, the rest go in front of everything.
	 */
	public function add(object:FlxBasic):FlxBasic
	{
		if(game == null || object == null) return object;
		if(songTypeOf(object) != null)
		{
			backIntoGroup(object);
			return object;
		}

		var layer:Null<Float> = getLayer(object);
		if(layer == null) return game.add(object);

		if(layers == null) loadLayers();

		// right behind the first thing that's on a layer above it
		var position:Int = -1;
		for (entry in layers)
		{
			if(entry.zIndex <= layer) continue;

			var index:Int = game.members.indexOf(entry.object);
			if(index > -1 && (position < 0 || index < position)) position = index;
		}
		layers.push({object: object, zIndex: layer});

		if(position > -1) game.insert(position, object);
		else game.add(object);
		return object;
	}

	public function remove(object:FlxBasic, splice:Bool = false):FlxBasic
	{
		// one of the song's characters: out of its group, which stays where it is for whoever comes next (see `addCharacter()`)
		if(songTypeOf(object) != null && inItsGroup(object))
		{
			groupOf(songTypeOf(object)).remove(cast object, true);
			return object;
		}

		if(layers != null)
			for (entry in layers)
				if(entry.object == object)
				{
					layers.remove(entry);
					break;
				}
		return (game != null) ? game.remove(object, splice) : object;
	}

	public function insert(position:Int, object:FlxBasic):FlxBasic
	{
		if(songTypeOf(object) != null)
		{
			backIntoGroup(object);
			return object;
		}
		return (game != null) ? game.insert(gamePosition(position), object) : object;
	}

	// Where a place of `members` (which only has what's on the stage, scripts find their places in it) is in PlayState's own list:
	// right where the thing at that place is, after the last one for a place past the end
	function gamePosition(position:Int):Int
	{
		var list:Array<FlxBasic> = members;
		if(list.length < 1) return game.members.length;
		if(position < 0) position = 0;

		var after:Bool = position >= list.length;
		var index:Int = game.members.indexOf(gameObjectOf(list[after ? list.length - 1 : position]));
		if(index < 0) return game.members.length;
		return after ? index + 1 : index;
	}

	// What's in PlayState's list for something of `members`: a song's character is there as its group
	function gameObjectOf(member:FlxBasic):FlxBasic
	{
		var type:String = songTypeOf(member);
		return (type != null && inItsGroup(member)) ? groupOf(type) : member;
	}

	// The layer something is on right now: scripts change it and ask for everything to be sorted again
	function currentLayer(object:FlxBasic, known:Float):Float
	{
		// the characters are inside of a group each, which is what's on the stage
		for (group in [game.gfGroup, game.dadGroup, game.boyfriendGroup])
		{
			if(group != object || group == null) continue;

			for (member in group.members)
			{
				// (0 is a character nothing gave a layer to yet)
				var character:objects.Character = Std.downcast(member, objects.Character);
				if(character != null && character.visible && character.zIndex != 0) return character.zIndex;
			}
			return known;
		}

		var layer:Null<Float> = getLayer(object);
		return (layer != null) ? layer : known;
	}

	/**
	 * Sorts what's on the stage by layer again, for the scripts that change the `zIndex` of something that's already on it.
	 * Only what has a layer moves, and only to the places things with a layer take: the rest stays where it was put.
	 */
	public function refresh():Void
	{
		if(game == null) return;
		if(layers == null) loadLayers();

		// things that were given a layer after being added
		for (member in game.members)
		{
			if(member == null || getLayer(member) == null) continue;

			var known:Bool = false;
			for (entry in layers)
				if(entry.object == member)
				{
					known = true;
					break;
				}
			if(!known) layers.push({object: member, zIndex: getLayer(member)});
		}

		var sorted:Array<{object:FlxBasic, zIndex:Float, index:Int}> = [];
		for (entry in layers)
		{
			var index:Int = game.members.indexOf(entry.object);
			if(index < 0) continue;

			entry.zIndex = currentLayer(entry.object, entry.zIndex);
			sorted.push({object: entry.object, zIndex: entry.zIndex, index: index});
		}
		if(sorted.length < 2) return;

		var places:Array<Int> = [for (entry in sorted) entry.index];
		places.sort((a, b) -> a - b);

		// (the ones on the same layer keep the order they had)
		sorted.sort(function(a, b)
		{
			if(a.zIndex != b.zIndex) return (a.zIndex < b.zIndex) ? -1 : 1;
			return a.index - b.index;
		});

		for (i => entry in sorted)
			game.members[places[i]] = entry.object;
	}

	/**
	 * Adds something to the stage under a name, for `getNamedProp()` to find it.
	 */
	public function addProp(prop:FlxBasic, ?name:String):Void
	{
		if(prop == null || announcingProps) return;

		if(name != null && game != null)
		{
			game.variables.set(name, prop);
			#if HSCRIPT_ALLOWED
			HxcRuntime.setExtra(prop, 'name', name);
			#end
		}
		add(prop);
	}

	// (the ones that dance are told about the beat by the engine when they come from the stage's file, a script's own does it itself)
	public function addBopper(bopper:FlxBasic, ?name:String):Void
	{
		addProp(bopper, name);
	}

	/**
	 * Gives a shader to everything the stage has: its sprites and the characters.
	 */
	public function setShader(shader:Dynamic):Void
	{
		if(game == null) return;

		for (member in game.members)
		{
			var sprite:FlxSprite = Std.downcast(member, FlxSprite);
			if(sprite != null && sprite.alive && sprite.cameras.contains(game.camGame) && !Std.isOfType(sprite, flixel.group.FlxSpriteGroup)) sprite.shader = shader;
		}
		for (character in [getBoyfriend(), getDad(), getGirlfriend()])
			if(character != null) character.shader = shader;
	}

	public var camZoom(get, never):Float;
	function get_camZoom():Float return (game != null) ? game.defaultCamZoom : 1;

	/**
	 * Puts the characters back where the stage has them.
	 */
	public function resetStage():Void
	{
		for (character in [getBoyfriend(), getDad(), getGirlfriend()])
			if(character != null) character.resetCharacter(true);
	}

	public function pause():Void {}
	public function resume():Void {}

	// On V-Slice the stage is a group of sprites, killed when the song is left: scripts replace these to clean up after themselves
	/**
	 * Takes the stage's sprites off (a script changing the stage): they're gone for good, a stage is built again if it comes back.
	 */
	public function kill():Void
	{
		alive = false;
		if(game == null) return;

		for (prop in group)
		{
			if(prop == null) continue;
			prop.kill();
			game.remove(prop, true);
		}
		if(builtProps != null) builtProps = [];
	}

	public function revive():Void alive = true;
	public function draw():Void {}

	public function toString():String
	{
		return 'Stage($id)';
	}
}

class ScriptedStage extends Stage {}

/**
 * The sprites of a stage, for scripts: `for (sprite in stage.group)`, `length`, `members` and `remove()`.
 */
@:keep
class StagePropList
{
	public var members:Array<FlxBasic>;
	public var length(get, never):Int;
	function get_length():Int return members.length;

	public function new(members:Array<FlxBasic>)
	{
		this.members = members;
	}

	public function iterator():Iterator<FlxBasic> return members.copy().iterator();

	public function forEach(func:FlxBasic->Void, recurse:Bool = false):Void
	{
		for (member in members.copy())
			if(member != null)
				func(member);
	}

	public function remove(object:FlxBasic, splice:Bool = false):FlxBasic
	{
		members.remove(object);
		var game:states.PlayState = states.PlayState.instance;
		if(game != null && object != null) game.remove(object, true);
		return object;
	}
}
