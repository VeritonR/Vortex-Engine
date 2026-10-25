package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;


#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT'];
	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					//trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			//trace('check...');
			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null)
				{
					protectedGfx.push(gfx);
					//trace('gfx added to the list successfully!');
				}
			}
			//catch(haxe.Exception) {}

			// A sprite's frames can come from more images than its own graphic: texture atlases split in pages, multi atlases,
			// and atlases that had one of their sprites swapped (the album of the V-Slice Freeplay). Drawing a frame of a destroyed image crashes the game
			if(spr != null)
			{
				var spriteFrames:Dynamic = Reflect.getProperty(spr, 'frames');
				if(spriteFrames != null && Std.isOfType(spriteFrames, flixel.graphics.frames.FlxFramesCollection))
				{
					var frames:flixel.graphics.frames.FlxFramesCollection = cast spriteFrames;
					if(frames.frames == null) return;

					var lastParent:FlxGraphic = null;
					for (frame in frames.frames)
					{
						if(frame == null || frame.parent == null || frame.parent == lastParent) continue;

						lastParent = frame.parent;
						if(!protectedGfx.contains(lastParent)) protectedGfx.push(lastParent);
					}
				}
			}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if(FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var customFile:String = file;
			if (parentfolder != null) customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		if (parentfolder != null)
			return getFolderPath(file, parentfolder);

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = getFolderPath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		var sharedPath:String = getSharedPath(file);
		#if sys
		// Not there: one of the game's other libraries may have it (a V-Slice mod's stage that uses the base game's "stageback"
		// of week 1 without saying which library it's in). Only looked for when it's nowhere else, and only once for each file
		if (!OpenFlAssets.exists(sharedPath, type) && !FileSystem.exists(sharedPath))
		{
			var found:String = libraryFallbacks.get(file);
			if (found == null)
			{
				found = '';
				for (library in listLibraries())
				{
					var libraryPath:String = getFolderPath(file, library);
					if (FileSystem.exists(libraryPath)) { found = libraryPath; break; }
				}
				libraryFallbacks.set(file, found);
			}
			if (found.length > 0) return found;
		}
		#end
		return sharedPath;
	}

	#if sys
	static var libraryFallbacks:Map<String, String> = [];
	static var libraries:Array<String> = null;

	// The folders of "assets" that are libraries of the game (the weeks), "shared" and the engine's own ones left out
	static function listLibraries():Array<String>
	{
		if (libraries != null) return libraries;
		libraries = [];
		if (FileSystem.exists('assets') && FileSystem.isDirectory('assets'))
			for (name in FileSystem.readDirectory('assets'))
				if (!['shared', 'base_game', 'fonts', 'videos', 'embed', 'translations'].contains(name) && FileSystem.isDirectory('assets/$name'))
					libraries.push(name);
		libraries.sort((a, b) -> (a < b) ? -1 : ((a > b) ? 1 : 0));
		return libraries;
	}
	#end

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	static public function video(key:String)
	{
		// The name can come with its extension, and the videos of V-Slice aren't all of the same kind
		var names:Array<String> = ['$key.$VIDEO_EXT'];
		var dot:Int = key.lastIndexOf('.');
		if(dot > 0 && ['mp4', 'mkv', 'mov', 'webm', 'avi'].contains(key.substr(dot + 1).toLowerCase())) names = [key];
		else names = names.concat(['$key.mkv', '$key.mov', '$key.webm']);

		#if MODS_ALLOWED
		for (name in names)
		{
			var file:String = modFolders('videos/$name');
			if(FileSystem.exists(file)) return file;
		}
		#end
		#if sys
		for (name in names)
			if(FileSystem.exists('assets/videos/$name'))
				return 'assets/videos/$name';
		#end
		return 'assets/videos/${names[0]}';
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', modsAllowed);

	/**
	 * Where the instrumental of a song is inside of the "songs" folder, without its extension: what `returnSound()` is given to load it.
	 */
	static public function instKey(song:String):String
	{
		#if MODS_ALLOWED
		var vslice:Dynamic = PolymodCompat.getSongAudio(song);
		if(vslice != null) return vslice.inst;
		#end
		return '${formatToSongPath(song)}/Inst';
	}

	static public function inst(song:String, ?modsAllowed:Bool = true):Sound
	{
		return returnSound(instKey(song), 'songs', modsAllowed);
	}

	/**
	 * Where a vocals track of a song is inside of the "songs" folder, null if the song is known not to have it.
	 */
	static public function voicesKey(song:String, postfix:String = null):String
	{
		#if MODS_ALLOWED
		// V-Slice songs name their vocals after the characters (Voices-bf-erect...), the chart loader already found the right files.
		// The postfix here is either "Player", "Opponent" or a character's "vocals_file", anything but "Opponent" is taken as the player's track
		var vslice:Dynamic = PolymodCompat.getSongAudio(song);
		if(vslice != null) return (postfix == null) ? vslice.voices : ((postfix == 'Opponent') ? vslice.opponentVoices : vslice.playerVoices);
		#end

		var songKey:String = '${formatToSongPath(song)}/Voices';
		if(postfix != null) songKey += '-' + postfix;
		return songKey;
	}

	static public function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true):Sound
	{
		var songKey:String = voicesKey(song, postfix);
		return (songKey != null) ? returnSound(songKey, 'songs', modsAllowed, false) : null;
	}

	/**
	 * A vocal track of a song for one of its characters. A character can have a track of its own (the "vocals_file" of its file,
	 * which is what the track's name ends with): a song that doesn't have that one is sung with the usual track of the character's side,
	 * "Voices-Player" or "Voices-Opponent". Null if the song has neither.
	 */
	static public function characterVoices(song:String, vocalsFile:String, opponent:Bool):Sound
	{
		var usual:String = opponent ? 'Opponent' : 'Player';
		if(vocalsFile != null && vocalsFile.length > 0 && vocalsFile != usual)
		{
			var own:Sound = voices(song, vocalsFile);
			if(own != null) return own;
		}
		return voices(song, usual);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		key = Language.getFileTranslation('images/$key') + '.png';
		var bitmap:BitmapData = null;
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return cacheBitmap(key, parentFolder, bitmap, allowGPU);
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);
			#if MODS_ALLOWED
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, !ignoreMods);
		#if sys
		var text:String = (FileSystem.exists(path)) ? File.getContent(path) : null;
		#if MODS_ALLOWED
		// what V-Slice mods add to the file ("_append" and "_merge" folders), see PolymodMerge
		if(text != null && !ignoreMods) text = PolymodMerge.apply(key, text);
		#end
		return text;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end
	}

	inline static public function font(key:String)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if MODS_ALLOWED
		var file:String = modFolders(folderKey);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if(!ignoreMods)
		{
			var modKey:String = key;
			if(parentFolder == 'songs') modKey = 'songs/$key';

			for(mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$modKey')))
					return true;

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + modKey)) || FileSystem.exists(mods(modKey)))
				return true;

			if (PolymodCompat.findInLibraries(Mods.currentModDirectory, modKey) != null)
				return true;
		}
		#end
		return (OpenFlAssets.exists(getPath(key, type, parentFolder, false)));
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
		if(OpenFlAssets.exists(myXml) #if MODS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
		{
			#if MODS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? File.getContent(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
			if(OpenFlAssets.exists(myJson) #if MODS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
			{
				#if MODS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? File.getContent(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}
		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
		if(keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if(extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		if(key.contains('psychic')) trace(key, parentFolder, allowGPU);
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;

		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? File.getContent(xml) : getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if(FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? File.getContent(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if MODS_ALLOWED
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if(FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? File.getContent(json) : getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		#end
	}

	inline static public function formatToSongPath(path:String) {
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true)
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);

		//trace('precaching sound: $file');
		if(!currentTrackedSounds.exists(file))
		{
			#if sys
			if(FileSystem.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			#else
			if(OpenFlAssets.exists(file, SOUND))
				currentTrackedSounds.set(file, OpenFlAssets.getSound(file));
			#end
			else if(beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSound('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if MODS_ALLOWED
	static public function mods(key:String = ''):String
	{
		// The base game's own V-Slice content is found like a mod's, but it's inside of the game's assets (see PolymodCompat.BASE_MOD)
		var base:String = PolymodCompat.BASE_MOD;
		if(key.startsWith(base) && (key.length == base.length || key.fastCodeAt(base.length) == '/'.code))
			return PolymodCompat.BASE_FOLDER + key.substr(base.length);

		return 'mods/' + key;
	}

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;

			// Polymod (V-Slice) mods keep most of their assets inside library folders: shared/, week1/...
			fileToCheck = PolymodCompat.findInLibraries(Mods.currentModDirectory, key);
			if(fileToCheck != null)
				return fileToCheck;
		}

		for(mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		// A V-Slice mod is made on top of the base game: the images and sounds it uses and doesn't have are the base game's
		// (a character with the base game's death animations, for one), which is the V-Slice content that comes with the engine.
		// Only those: data files are found by what they are, each mod's and the base game's, somewhere else
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0 && Mods.currentModDirectory != PolymodCompat.BASE_MOD
			&& (key.startsWith('images/') || key.startsWith('sounds/') || key.startsWith('music/')) && PolymodCompat.isPolymod(Mods.currentModDirectory))
		{
			var fileToCheck:String = PolymodCompat.findFile(PolymodCompat.BASE_MOD, key);
			if(fileToCheck != null) return fileToCheck;
		}
		return 'mods/' + key;
	}
	#end

	#if flxanimate
	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;
		
		if(spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(spriteJson);
		}

		if(animationJson != null) 
		{
			changedAnimJson = true;
			animationJson = File.getContent(animationJson);
		}

		// spritemap2, spritemap3... of atlases that didn't fit in a single image
		var extraPagesFolder:String = null;
		var extraPagesStart:Int = 0;

		// is folder or image path
		if(Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;
			for (i in 0...10)
			{
				var st:String = '$i';
				if(i == 0) st = '';

				if(!changedAtlasJson)
				{
					spriteJson = getTextFromFile('images/$originalPath/spritemap$st.json');
					if(spriteJson != null)
					{
						//trace('found Sprite Json');
						changedImage = true;
						changedAtlasJson = true;
						folderOrImg = image('$originalPath/spritemap$st');
						extraPagesFolder = originalPath;
						extraPagesStart = i + 1;
						break;
					}
				}
				else if(fileExists('images/$originalPath/spritemap$st.png', IMAGE))
				{
					//trace('found Sprite PNG');
					changedImage = true;
					folderOrImg = image('$originalPath/spritemap$st');
					break;
				}
			}

			if(!changedImage)
			{
				//trace('Changing folderOrImg to FlxGraphic');
				changedImage = true;
				folderOrImg = image(originalPath);
			}

			if(!changedAnimJson)
			{
				//trace('found Animation Json');
				changedAnimJson = true;
				animationJson = getTextFromFile('images/$originalPath/Animation.json');
			}
		}

		//trace(folderOrImg);
		//trace(spriteJson);
		//trace(animationJson);
		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);

		if(extraPagesFolder != null)
		{
			for (i in extraPagesStart...10)
			{
				var pageJson:String = getTextFromFile('images/$extraPagesFolder/spritemap$i.json');
				if(pageJson == null) break;

				var pageImage:FlxGraphic = image('$extraPagesFolder/spritemap$i');
				if(pageImage != null) spr.addSpriteMap(pageImage, pageJson);
			}
		}
	}
	#end
}
