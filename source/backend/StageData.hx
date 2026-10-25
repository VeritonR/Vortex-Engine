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
		var vslice:Dynamic = (song != null) ? song.vslice : null;
		var events:Array<Dynamic> = (vslice != null) ? vslice.eventValues : null;
		if(events == null) return images;

		var stages:Array<String> = [song.stage];
		for (event in events)
		{
			if(event == null || (event.e != 'ChangeStage' && event.e != 'Change Stage')) continue;

			var value:Dynamic = event.v;
			var id:Dynamic = null;
			if(Std.isOfType(value, String)) id = value;
			else if(value != null)
			{
				for (field in ['stageid', 'stageId', 'stage', 'id'])
				{
					id = Reflect.field(value, field);
					if(id != null) break;
				}
			}
			if(id == null || stages.contains(Std.string(id))) continue;
			stages.push(Std.string(id));

			var file:StageFile = getStageFile(Std.string(id));
			if(file == null || file.objects == null) continue;
			for (sprite in file.objects)
			{
				if((sprite.type == 'sprite' || sprite.type == 'animatedSprite') && sprite.image != null
					&& (sprite.filters < 0 || validateVisibility(sprite.filters)) && !images.contains(sprite.image))
					images.push(sprite.image);
			}
		}
		return images;
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
								if(anim.indices == null || anim.indices.length < 1)
									spr.animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
								else
									spr.animation.addByIndices(anim.anim, anim.name, anim.indices, '', anim.fps, anim.loop);
	
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
