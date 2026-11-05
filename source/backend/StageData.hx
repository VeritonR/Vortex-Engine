package backend;

import openfl.utils.Assets;
import haxe.Json;
import backend.Song;
import psychlua.ModchartSprite;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	@:optional var isPixelStage:Null<Bool>;
	var stageUI:String;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;

	@:optional var preload:Dynamic;
	@:optional var objects:Array<Dynamic>;
	@:optional var _editorMeta:Dynamic;

	@:optional var vslice:Dynamic; //Only on stages converted from a V-Slice (Polymod) mod, its character positions are the characters' feet
}

enum abstract LoadFilters(Int) from Int from UInt to Int to UInt
{
	var LOW_QUALITY:Int = (1 << 0);
	var HIGH_QUALITY:Int = (1 << 1);

	var STORY_MODE:Int = (1 << 2);
	var FREEPLAY:Int = (1 << 3);
}

class StageData {
	public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,

			_editorMeta: {
				gf: "gf",
				dad: "dad",
				boyfriend: "bf"
			}
		};
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null)
			stage = SONG.stage;
		else if(Song.loadedSongName != null)
			stage = vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));
		else
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);
		forceNextDirectory = (stageFile != null) ? stageFile.directory : ''; //preventing crashes
	}

	public static function getStageFile(stage:String):StageFile {
		try
		{
			#if MODS_ALLOWED
			var vsliceStage:StageFile = PolymodCompat.getStageFile(stage);
			if(vsliceStage != null) return vsliceStage;
			#end

			var path:String = Paths.getPath('stages/' + stage + '.json', TEXT, null, true);
			#if MODS_ALLOWED
			if(FileSystem.exists(path))
				return cast tjson.TJSON.parse(File.getContent(path));
			#else
			if(Assets.exists(path))
				return cast tjson.TJSON.parse(Assets.getText(path));
			#end
		}
		return dummy();
	}

	/**
	 * The images of the stages a song changes to while it plays (the "ChangeStage" events of V-Slice mods' stage changer), so they're
	 * loaded with the song instead of when each change happens.
	 */
	public static function laterStageImages(song:SwagSong):Array<String>
	{
		var images:Array<String> = [];
		// (only V-Slice's: their stages have no library of their own. The engine's own event loads its stages itself, each from its
		// library, see PlayState.precacheStage())
		for (id in laterStages(song, true))
		{
			var file:StageFile = getStageFile(id);
			if(file == null) continue;
			for (image in stageImages(file))
				if(!images.contains(image)) images.push(image);
		}
		return images;
	}

	/**
	 * The stages a song changes to while it plays: its "Change Stage" events (the engine's, and "ChangeStage" of V-Slice mods' stage
	 * changer), without the one it starts on.
	 */
	public static function laterStages(song:SwagSong, onlyVSlice:Bool = false):Array<String>
	{
		var stages:Array<String> = [];
		if(song == null) return stages;

		function found(value:Dynamic):Void
		{
			var id:String = stageIdOf(value);
			if(id.length > 0 && id != song.stage && !stages.contains(id)) stages.push(id);
		}

		var vslice:Dynamic = song.vslice;
		var vsliceEvents:Array<Dynamic> = (vslice != null) ? vslice.eventValues : null;
		if(vsliceEvents != null)
			for (event in vsliceEvents)
				if(event != null && (event.e == 'ChangeStage' || event.e == 'Change Stage')) found(event.v);

		// Psych's: [time, [[name, value 1, value 2], ...]]
		if(!onlyVSlice && song.events != null)
			for (group in song.events)
			{
				var list:Array<Dynamic> = (group != null && group.length > 1) ? group[1] : null;
				if(list == null) continue;
				for (event in list)
					if(event != null && event.length > 1 && (event[0] == 'Change Stage' || event[0] == 'ChangeStage')) found(event[1]);
			}
		return stages;
	}

	/**
	 * The name of a stage as an event gives it: plain, or written the way V-Slice's events have it ({"stageid": "school"}).
	 */
	public static function stageIdOf(value:Dynamic):String
	{
		if(value == null) return '';
		var data:Dynamic = value;
		if(Std.isOfType(value, String))
		{
			var text:String = StringTools.trim(value);
			if(!StringTools.startsWith(text, '{')) return text;
			try data = Json.parse(text) catch(e:Dynamic) return text;
		}
		for (field in ['stageid', 'stageId', 'stage', 'id', 'value1'])
		{
			var id:Dynamic = Reflect.field(data, field);
			if(id != null) return StringTools.trim(Std.string(id));
		}
		return '';
	}

	/**
	 * The images a stage's file uses: its sprites' and its "preload" list's.
	 */
	public static function stageImages(file:StageFile):Array<String>
	{
		var images:Array<String> = [];
		if(file == null) return images;
		if(file.objects != null)
			for (sprite in file.objects)
				if((sprite.type == 'sprite' || sprite.type == 'animatedSprite') && sprite.image != null
					&& (sprite.filters < 0 || validateVisibility(sprite.filters)) && !images.contains(sprite.image))
					images.push(sprite.image);

		var preload:Dynamic = file.preload;
		if(preload != null)
			for (key in Reflect.fields(preload))
			{
				var filters:Int = Std.int(Reflect.field(preload, key));
				if(StringTools.startsWith(key, 'images/') && (filters < 0 || validateVisibility(filters)))
				{
					var image:String = key.substr('images/'.length);
					if(!images.contains(image)) images.push(image);
				}
			}
		return images;
	}

	/**
	 * The stages the game makes by itself (`states.stages`).
	 */
	public static final HARDCODED_STAGES:Array<String> = ['stage', 'spooky', 'philly', 'limo', 'mall', 'mallEvil', 'school', 'schoolEvil', 'tank',
		'phillyStreets', 'phillyBlazin'];

	/**
	 * If there's a stage of that name: a file of it ("stages/<name>.json", or only its script), a V-Slice one, or one the game makes.
	 */
	public static function stageExists(stage:String):Bool
	{
		if(stage == null || StringTools.trim(stage).length < 1) return false;
		if(HARDCODED_STAGES.contains(stage)) return true;
		#if MODS_ALLOWED
		if(PolymodCompat.getStageFile(stage) != null) return true;
		#end
		for (extension in ['json', 'lua', 'hx'])
		{
			var path:String = Paths.getPath('stages/$stage.$extension', TEXT, null, true);
			#if sys
			if(sys.FileSystem.exists(path)) return true;
			#else
			if(Assets.exists(path)) return true;
			#end
		}
		return false;
	}

	/**
	 * The characters a song changes to while it plays (the character change events of V-Slice mods), to be loaded with the song.
	 */
	public static function laterCharacters(song:SwagSong):Array<String>
	{
		var characters:Array<String> = [];
		var vslice:Dynamic = (song != null) ? song.vslice : null;
		var events:Array<Dynamic> = (vslice != null) ? vslice.eventValues : null;
		if(events == null) return characters;

		var known:Array<String> = [song.player1, song.player2, song.gfVersion];
		for (event in events)
		{
			if(event == null || event.v == null) continue;

			var id:Dynamic = switch(Std.string(event.e))
			{
				case 'CharacterChange+': Reflect.field(event.v, 'newchar');
				case 'Change Character', 'ChangeCharacter': Reflect.field(event.v, 'char');
				default: null;
			}
			if(id == null || Std.string(id).length < 1 || known.contains(Std.string(id)) || characters.contains(Std.string(id))) continue;
			characters.push(Std.string(id));
		}
		return characters;
	}

	public static function vanillaSongStage(songName):String
	{
		switch (songName)
		{
			case 'spookeez' | 'south' | 'monster':
				return 'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				return 'philly';
			case 'milf' | 'satin-panties' | 'high':
				return 'limo';
			case 'cocoa' | 'eggnog':
				return 'mall';
			case 'winter-horrorland':
				return 'mallEvil';
			case 'senpai' | 'roses':
				return 'school';
			case 'thorns':
				return 'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				return 'tank';
		}
		return 'stage';
	}

	public static var reservedNames:Array<String> = ['gf', 'gfGroup', 'dad', 'dadGroup', 'boyfriend', 'boyfriendGroup']; //blocks these names from being used on stage editor's name input text
	public static function addObjectsToState(objectList:Array<Dynamic>, gf:FlxSprite, dad:FlxSprite, boyfriend:FlxSprite, ?group:Dynamic = null, ?ignoreFilters:Bool = false)
	{
		var addedObjects:Map<String, FlxSprite> = [];
		for (num => data in objectList)
		{
			if (addedObjects.exists(data)) continue;

			switch(data.type)
			{
				case 'gf', 'gfGroup':
					if(gf != null)
					{
						gf.ID = num; 
						if (group != null) group.add(gf);
						addedObjects.set('gf', gf);
					}
				case 'dad', 'dadGroup':
					if(dad != null)
					{
						dad.ID = num;
						if (group != null) group.add(dad);
						addedObjects.set('dad', dad);
					}
				case 'boyfriend', 'boyfriendGroup':
					if(boyfriend != null)
					{
						boyfriend.ID = num;
						if (group != null) group.add(boyfriend);
						addedObjects.set('boyfriend', boyfriend);
					}

				case 'square', 'sprite', 'animatedSprite':
					if(!ignoreFilters && !validateVisibility(data.filters)) continue;

					var spr:ModchartSprite = new ModchartSprite(data.x, data.y);
					spr.ID = num;
					spr.vsliceOffsets = (data.vsliceOffsets == true);
					if(data.type != 'square')
					{
						if(data.type == 'sprite')
							spr.loadGraphic(Paths.image(data.image));
						else
							spr.frames = Paths.getAtlas(data.image);
						
						if(data.type == 'animatedSprite' && data.animations != null)
						{
							var anims:Array<objects.Character.AnimArray> = cast data.animations;
							for (key => anim in anims)
							{
								var animFlipX:Bool = (Reflect.field(anim, 'flipX') == true);
								var animFlipY:Bool = (Reflect.field(anim, 'flipY') == true);
								if(anim.indices == null || anim.indices.length < 1)
									spr.animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop, animFlipX, animFlipY);
								else
									spr.animation.addByIndices(anim.anim, anim.name, anim.indices, '', anim.fps, anim.loop, animFlipX, animFlipY);
	
								if(anim.offsets != null)
									spr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
	
								if(spr.animation.curAnim == null || data.firstAnimation == anim.anim)
									spr.playAnim(anim.anim, true);
							}
						}
						for (varName in ['antialiasing', 'flipX', 'flipY'])
						{
							var dat:Dynamic = Reflect.getProperty(data, varName);
							if(dat != null) Reflect.setProperty(spr, varName, dat);
						}
						if(!ClientPrefs.data.antialiasing) spr.antialiasing = false;
					}
					else
					{
						spr.makeGraphic(1, 1, FlxColor.WHITE);
						spr.antialiasing = false;
					}

					if(data.scale != null && (data.scale[0] != 1.0 || data.scale[1] != 1.0))
					{
						spr.scale.set(data.scale[0], data.scale[1]);
						spr.updateHitbox();
					}
					spr.scrollFactor.set(data.scroll[0], data.scroll[1]);
					spr.color = CoolUtil.colorFromString(data.color);
					
					for (varName in ['alpha', 'angle'])
					{
						var dat:Dynamic = Reflect.getProperty(data, varName);
						if(dat != null) Reflect.setProperty(spr, varName, dat);
					}

					if (group != null) group.add(spr);
					addedObjects.set(data.name, spr);

				// Texture atlases, on the stages of V-Slice mods (see VSliceConvert.convertProp())
				case 'atlas':
					if(!ignoreFilters && !validateVisibility(data.filters)) continue;

					var prop:funkin.play.stage.StageProp = new funkin.play.stage.StageProp();
					prop.setPosition(data.x, data.y);
					prop.ID = num;
					prop.name = data.name;
					prop.loadTextureAtlas(data.image, null, {applyStageMatrix: (data.applyStageMatrix == true)});

					if(prop.atlas != null && prop.atlas.loaded)
					{
						var anims:Array<Dynamic> = (data.animations != null) ? data.animations : [];
						for (anim in anims)
						{
							var indices:Array<Int> = anim.indices;
							var hasIndices:Bool = (indices != null && indices.length > 0);
							if(anim.symbol == true)
							{
								if(hasIndices) prop.atlas.player.addBySymbolIndices(anim.anim, anim.name, indices, 0, anim.loop == true);
								else prop.atlas.player.addBySymbol(anim.anim, anim.name, 0, anim.loop == true);
							}
							else if(hasIndices) prop.atlas.player.addByFrameLabelIndices(anim.anim, anim.name, indices, 0, anim.loop == true);
							else prop.atlas.player.addByFrameLabel(anim.anim, anim.name, 0, anim.loop == true);
						}

						var first:String = data.firstAnimation;
						if(first == null || first.length < 1 || !prop.hasAnimation(first)) first = prop.hasAnimation('idle') ? 'idle' : ((anims.length > 0) ? anims[0].anim : '');
						prop.playAnimation(first, true);
					}

					for (varName in ['antialiasing', 'flipX', 'flipY'])
					{
						var dat:Dynamic = Reflect.getProperty(data, varName);
						if(dat != null) Reflect.setProperty(prop, varName, dat);
					}
					if(!ClientPrefs.data.antialiasing) prop.antialiasing = false;

					if(data.scale != null && (data.scale[0] != 1.0 || data.scale[1] != 1.0))
					{
						prop.scale.set(data.scale[0], data.scale[1]);
						prop.updateHitbox();
					}
					prop.scrollFactor.set(data.scroll[0], data.scroll[1]);
					prop.color = CoolUtil.colorFromString(data.color);

					for (varName in ['alpha', 'angle'])
					{
						var dat:Dynamic = Reflect.getProperty(data, varName);
						if(dat != null) Reflect.setProperty(prop, varName, dat);
					}

					if (group != null) group.add(prop);
					addedObjects.set(data.name, prop);

				default:
					var err = '[Stage .JSON file] Unknown sprite type detected: ${data.type}';
					trace(err);
					FlxG.log.error(err);
			}
		}
		return addedObjects;
	}

	public static function validateVisibility(filters:LoadFilters)
	{
		if((filters & STORY_MODE) == STORY_MODE)
			if(!PlayState.isStoryMode) return false;
		else if((filters & FREEPLAY) == FREEPLAY)
			if(PlayState.isStoryMode) return false;

		return ((ClientPrefs.data.lowQuality && (filters & LOW_QUALITY) == LOW_QUALITY) ||
			(!ClientPrefs.data.lowQuality && (filters & HIGH_QUALITY) == HIGH_QUALITY));
	}
}
