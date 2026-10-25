package backend;

import haxe.Json;
import haxe.ds.ArraySort;

using StringTools;

/**
 * Converts parsed V-Slice (Polymod mods) JSON data to the formats Psych Engine already knows how to load.
 *
 * Everything in here only deals with plain JSON objects and has no engine references on purpose,
 * the file access/caching part lives in `PolymodCompat`.
 */
class VSliceConvert
{
	// ------------------------------------------------------------------------------------------
	// Names
	// ------------------------------------------------------------------------------------------

	/**
	 * Base game stages are named differently on Psych.
	 * Only used when the mod doesn't bring its own stage file with that name.
	 */
	public static function psychStageName(stage:String):String
	{
		if(stage == null) return 'stage';

		return switch(stage)
		{
			case 'mainStage' | 'mainStageErect': 'stage';
			case 'spookyMansion' | 'spookyMansionErect': 'spooky';
			case 'phillyTrain' | 'phillyTrainErect': 'philly';
			case 'limoRide' | 'limoRideErect': 'limo';
			case 'mallXmas' | 'mallXmasErect': 'mall';
			case 'schoolErect': 'school';
			case 'schoolEvilErect': 'schoolEvil';
			case 'tankmanBattlefield' | 'tankmanBattlefieldErect': 'tank';
			case 'phillyStreetsErect': 'phillyStreets';
			default: stage;
		}
	}

	static function psychNoteType(kind:String):String
	{
		return switch(kind)
		{
			case 'alt': 'Alt Animation';
			case 'hey': 'Hey!';
			case 'hurt': 'Hurt Note';
			default: kind;
		}
	}

	/**
	 * "shared:characters/bf" -> "characters/bf"
	 */
	public static function stripLibrary(path:String):String
	{
		if(path == null) return '';

		var colon:Int = path.indexOf(':');
		return (colon > -1) ? path.substr(colon + 1) : path;
	}

	static final difficultyOrder:Array<String> = ['easy', 'normal', 'hard', 'erect', 'nightmare'];

	/**
	 * Sorts difficulties like the base game shows them, unknown ones keep their order at the end.
	 */
	public static function sortDifficulties(diffs:Array<String>):Array<String>
	{
		var known:Array<String> = [for (diff in difficultyOrder) if(diffs.contains(diff)) diff];
		for (diff in diffs)
			if(!known.contains(diff))
				known.push(diff);
		return known;
	}

	/**
	 * "hard" -> "Hard", only for display, the file names are always compared lower cased.
	 */
	public static function difficultyDisplayName(diff:String):String
	{
		return (diff.length > 0) ? diff.charAt(0).toUpperCase() + diff.substr(1) : diff;
	}

	// ------------------------------------------------------------------------------------------
	// Chart
	// ------------------------------------------------------------------------------------------

	/**
	 * Builds a `SwagSong` (psych_v1 format) from a V-Slice metadata + chart file for a single difficulty.
	 * Returns null if the chart has no notes entry for that difficulty.
	 */
	public static function convertChart(metadata:Dynamic, chart:Dynamic, difficulty:String):Dynamic
	{
		if(metadata == null || chart == null || chart.notes == null) return null;

		var rawNotes:Dynamic = Reflect.field(chart.notes, difficulty);
		if(rawNotes == null) return null;

		var notes:Array<Dynamic> = list(rawNotes).copy();
		ArraySort.sort(notes, sortByTime);

		var events:Array<Dynamic> = list(chart.events).copy();
		ArraySort.sort(events, sortByTime);

		var timeChanges:Array<Dynamic> = list(metadata.timeChanges).copy();
		ArraySort.sort(timeChanges, sortByTime);

		var songBpm:Float = (timeChanges.length > 0) ? validBpm(timeChanges[0].bpm) : 100;

		var endTime:Float = 0;
		for (note in notes) endTime = Math.max(endTime, num(note.t, 0) + num(note.l, 0));
		for (event in events) endTime = Math.max(endTime, num(event.t, 0));

		// Psych moves the camera per section, so only simple "focus on this character" events can be kept
		// Psych moves the camera by sections, which is enough when all a chart does is go from one character to another.
		// With anything else (offsets, positions, tweens) every camera event is also kept as an event, for `VSliceScripts` to do them as they are
		var keepFocusEvents:Bool = false;
		for (event in events)
		{
			if(event != null && event.e == 'FocusCamera' && !isPlainFocus(event))
			{
				keepFocusEvents = true;
				break;
			}
		}

		var focusEvents:Array<Dynamic> = [];
		var psychEvents:Array<Dynamic> = [];
		for (event in events)
		{
			var focus:Int = focusCharacter(event);
			if(focus > -1) focusEvents.push({t: num(event.t, 0), char: focus});

			if(focus < 0 || keepFocusEvents)
			{
				var converted:Array<Dynamic> = convertEvent(event, songBpm);
				if(converted != null) psychEvents.push([num(event.t, 0), [converted]]);
			}
		}

		var sections:Array<Dynamic> = [];
		var sectionTimes:Array<Float> = [];

		var bpm:Float = songBpm;
		var lastBpm:Float = songBpm;
		var nextChange:Int = 1;
		var nextFocus:Int = 0;
		var focused:Int = 1; //the base game starts on the opponent
		var time:Float = 0;
		do
		{
			while(nextChange < timeChanges.length && num(timeChanges[nextChange].t, 0) <= time + 1)
				bpm = validBpm(timeChanges[nextChange++].bpm);

			var sectionLength:Float = 240000 / bpm; //4 beats

			// events placed in the middle of a section snap to the closest section start
			while(nextFocus < focusEvents.length && focusEvents[nextFocus].t < time + sectionLength / 2)
				focused = focusEvents[nextFocus++].char;

			var section:Dynamic = {
				sectionNotes: [],
				sectionBeats: 4,
				mustHitSection: (focused == 0)
			};
			if(focused == 2) section.gfSection = true;
			if(bpm != lastBpm)
			{
				section.changeBPM = true;
				section.bpm = bpm;
				lastBpm = bpm;
			}

			sections.push(section);
			sectionTimes.push(time);
			time += sectionLength;
		}
		while(time <= endTime);

		var curSection:Int = 0;
		for (note in notes)
		{
			var strumTime:Float = num(note.t, 0);
			while(curSection + 1 < sectionTimes.length && sectionTimes[curSection + 1] <= strumTime)
				curSection++;

			// psych_v1 notes: 0-3 is always the player and 4-7 the opponent, same as V-Slice
			var psychNote:Array<Dynamic> = [strumTime, Std.int(num(note.d, 0)), num(note.l, 0)];

			// what scripted note kinds read from their notes goes along as a fifth value, Psych only looks at the first four
			var params:Array<Dynamic> = (Std.isOfType(note.p, Array) && note.p.length > 0) ? note.p : null;

			var kind:String = str(note.k, '');
			if(kind.length > 0 && kind != 'normal') psychNote.push(psychNoteType(kind));
			else if(params != null) psychNote.push('');
			if(params != null) psychNote.push(params);

			sections[curSection].sectionNotes.push(psychNote);
		}

		var speed:Float = 1;
		if(chart.scrollSpeed != null)
		{
			if(isNum(chart.scrollSpeed)) speed = chart.scrollSpeed;
			else speed = num(Reflect.field(chart.scrollSpeed, difficulty), num(Reflect.field(chart.scrollSpeed, 'default'), 1));
		}

		// "ScrollSpeed" events with absolute values need the final chart speed
		for (event in psychEvents)
		{
			var data:Array<Dynamic> = event[1][0];
			if(data[0] == 'Change Scroll Speed' && data.length > 3)
			{
				data[1] = Std.string(Std.parseFloat(data[1]) / speed);
				data.pop();
			}
		}

		var playData:Dynamic = (metadata.playData != null) ? metadata.playData : {};
		var characters:Dynamic = (playData.characters != null) ? playData.characters : {};

		var song:Dynamic = {
			song: str(metadata.songName, 'Unknown'),
			notes: sections,
			events: psychEvents,
			bpm: songBpm,
			needsVoices: true, //V-Slice simply checks if the files are there
			speed: speed,
			offset: 0,

			player1: str(characters.player, 'bf'),
			player2: str(characters.opponent, 'dad'),
			gfVersion: str(characters.girlfriend, ''),
			stage: str(playData.stage, 'mainStage'),
			format: 'psych_v1_convert'
		};
		song.artist = str(metadata.artist, 'Unknown');
		song.charter = str(metadata.charter, 'Unknown');
		return song;
	}

	/**
	 * Returns 0 (player), 1 (opponent) or 2 (girlfriend) if the event is a simple camera focus, -1 otherwise.
	 */
	static function focusCharacter(event:Dynamic):Int
	{
		if(event == null || event.e != 'FocusCamera' || event.v == null) return -1;

		var char:Dynamic = isNum(event.v) ? event.v : event.v.char;
		if(!isNum(char)) return -1;

		var value:Int = Std.int(char);
		return (value >= 0 && value <= 2) ? value : -1;
	}

	// A camera event that only says which character to look at
	static function isPlainFocus(event:Dynamic):Bool
	{
		if(focusCharacter(event) < 0) return false;
		if(isNum(event.v)) return true;

		var ease:String = str(event.v.ease, 'CLASSIC');
		return num(event.v.x, 0) == 0 && num(event.v.y, 0) == 0 && (ease == 'CLASSIC' || ease.length < 1);
	}

	/**
	 * Returns `[name, value1, value2]`.
	 * Events without an equivalent keep their name and get their values as a JSON string on value1,
	 * they do nothing on their own but scripts can still read them.
	 */
	static function convertEvent(event:Dynamic, bpm:Float):Array<Dynamic>
	{
		var name:String = str(event.e, '');
		if(name.length < 1) return null;

		var values:Dynamic = event.v;
		switch(name)
		{
			case 'PlayAnimation':
				if(values != null)
				{
					var target:String = switch(str(values.target, '').toLowerCase())
					{
						case 'bf' | 'boyfriend' | 'player': 'bf';
						case 'dad' | 'opponent': 'dad';
						case 'gf' | 'girlfriend': 'gf';
						default: null; //stage props
					}

					var anim:String = str(values.anim, '');
					if(target != null && anim.length > 0)
						return ['Play Animation', anim, target];
				}

			case 'ScrollSpeed':
				if(values != null && isNum(values.scroll))
				{
					var steps:Float = (str(values.ease, '').toUpperCase() == 'INSTANT') ? 0 : num(values.duration, 4);
					var seconds:Float = steps * 15 / bpm;

					// the 4th value flags an absolute speed, which is turned into a multiplier once the chart speed is known
					var converted:Array<Dynamic> = ['Change Scroll Speed', Std.string(num(values.scroll, 1)), Std.string(seconds)];
					if(values.absolute == true) converted.push(true);
					return converted;
				}
		}

		// an event of Psych that was saved on a V-Slice chart, by this engine or by Psych's own exporter
		if(values != null && !Std.isOfType(values, String) && !isNum(values) && !Std.isOfType(values, Bool) && !Std.isOfType(values, Array))
		{
			var fields:Array<String> = Reflect.fields(values);
			if(fields.length > 0 && fields.length <= 2 && fields.contains('value1') && (fields.length == 1 || fields.contains('value2')))
				return [name, (values.value1 != null) ? Std.string(values.value1) : '', (values.value2 != null) ? Std.string(values.value2) : ''];
		}

		var raw:String = '';
		if(values != null) raw = Std.isOfType(values, String) ? values : Json.stringify(values);
		return [name, raw, ''];
	}

	// ------------------------------------------------------------------------------------------
	// Audio
	// ------------------------------------------------------------------------------------------

	/**
	 * Finds which audio files (without extension) a song variation uses, following the same rules the base game does.
	 * `exists` receives a file name like "Voices-bf-erect" and tells if it's inside the song's folder.
	 */
	public static function resolveAudio(metadata:Dynamic, variation:String, exists:String->Bool):{inst:String, playerVoices:String, opponentVoices:String, voices:String}
	{
		var suffix:String = (variation != null && variation.length > 0 && variation != 'default') ? '-$variation' : '';

		var characters:Dynamic = (metadata != null && metadata.playData != null && metadata.playData.characters != null) ? metadata.playData.characters : {};

		var inst:String = 'Inst';
		var instId:String = str(characters.instrumental, '');
		for (name in [(instId.length > 0) ? 'Inst-$instId' : null, 'Inst$suffix'])
		{
			if(name != null && exists(name))
			{
				inst = name;
				break;
			}
		}

		var playerIds:Array<Dynamic> = list(characters.playerVocals);
		var opponentIds:Array<Dynamic> = list(characters.opponentVocals);

		var player:String = resolveVoices((playerIds.length > 0) ? Std.string(playerIds[0]) : str(characters.player, ''), suffix, exists);
		var opponent:String = resolveVoices((opponentIds.length > 0) ? Std.string(opponentIds[0]) : str(characters.opponent, ''), suffix, exists);
		if(opponent == player) opponent = null;

		var voices:String = null;
		for (name in ['Voices$suffix', 'Voices'])
		{
			if(exists(name))
			{
				voices = name;
				break;
			}
		}

		return {inst: inst, playerVoices: player, opponentVoices: opponent, voices: voices};
	}

	// "Voices-bf-car-erect" -> "Voices-bf-erect" -> "Voices-bf-car" -> "Voices-bf"
	static function resolveVoices(charId:String, suffix:String, exists:String->Bool):String
	{
		var suffixes:Array<String> = (suffix.length > 0) ? [suffix, ''] : [''];
		for (curSuffix in suffixes)
		{
			var id:String = charId;
			while(id.length > 0)
			{
				var name:String = 'Voices-$id$curSuffix';
				if(exists(name)) return name;

				var split:Int = id.lastIndexOf('-');
				id = (split > 0) ? id.substr(0, split) : '';
			}
		}
		return null;
	}

	// ------------------------------------------------------------------------------------------
	// Stage
	// ------------------------------------------------------------------------------------------

	/**
	 * Builds a Psych `StageFile` out of a V-Slice stage, props become entries of the stage's object list.
	 *
	 * The character positions keep the V-Slice meaning (bottom center of the character instead of its top left corner),
	 * the `vslice` field tells PlayState to place them that way.
	 */
	public static function convertStage(stage:Dynamic, pixelUI:Bool = false, hideGirlfriend:Bool = false):Dynamic
	{
		if(stage == null) return null;

		var characters:Dynamic = (stage.characters != null) ? stage.characters : {};
		var bf:Dynamic = (characters.bf != null) ? characters.bf : {};
		var dad:Dynamic = (characters.dad != null) ? characters.dad : {};
		var gf:Dynamic = (characters.gf != null) ? characters.gf : {};

		var entries:Array<{zIndex:Float, order:Int, data:Dynamic}> = [];
		var usedNames:Array<String> = ['gf', 'gfGroup', 'dad', 'dadGroup', 'boyfriend', 'boyfriendGroup'];

		// the layer of each thing, for what scripts add to the stage later
		var propLayers:Dynamic = {};

		var props:Array<Dynamic> = list(stage.props);
		for (num => prop in props)
		{
			var data:Dynamic = convertProp(prop, num, usedNames);
			if(data == null) continue;

			entries.push({zIndex: VSliceConvert.num(prop.zIndex, 0), order: num, data: data});
			Reflect.setField(propLayers, data.name, VSliceConvert.num(prop.zIndex, 0));
		}

		entries.push({zIndex: num(gf.zIndex, 0), order: props.length, data: {type: 'gf'}});
		entries.push({zIndex: num(dad.zIndex, 0), order: props.length + 1, data: {type: 'dad'}});
		entries.push({zIndex: num(bf.zIndex, 0), order: props.length + 2, data: {type: 'boyfriend'}});

		ArraySort.sort(entries, function(a, b)
		{
			if(a.zIndex != b.zIndex) return (a.zIndex < b.zIndex) ? -1 : 1;
			return a.order - b.order;
		});

		// Psych already adds (150, -100) to the opponent's camera and (-100, -100) to the player's one
		var bfCamera:Array<Float> = pair(bf.cameraOffsets, -100, -100);
		var dadCamera:Array<Float> = pair(dad.cameraOffsets, 150, -100);
		var gfCamera:Array<Float> = pair(gf.cameraOffsets, 0, 0);

		return {
			directory: str(stage.directory, 'shared'),
			defaultZoom: num(stage.cameraZoom, 1),
			stageUI: pixelUI ? 'pixel' : 'normal',

			boyfriend: pair(bf.position, 0, 0),
			girlfriend: pair(gf.position, 0, 0),
			opponent: pair(dad.position, 0, 0),
			hide_girlfriend: hideGirlfriend,

			camera_boyfriend: [bfCamera[0] + 100, bfCamera[1] + 100],
			camera_opponent: [dadCamera[0] - 150, dadCamera[1] + 100],
			camera_girlfriend: gfCamera,
			camera_speed: 1,

			objects: [for (entry in entries) entry.data],
			vslice: {
				name: str(stage.name, ''),
				gfScroll: pair(gf.scroll, 1, 1),
				characters: {
					bf: {scale: num(bf.scale, 1), scroll: pair(bf.scroll, 1, 1), alpha: num(bf.alpha, 1), angle: num(bf.angle, 0)},
					dad: {scale: num(dad.scale, 1), scroll: pair(dad.scroll, 1, 1), alpha: num(dad.alpha, 1), angle: num(dad.angle, 0)},
					gf: {scale: num(gf.scale, 1), scroll: pair(gf.scroll, 1, 1), alpha: num(gf.alpha, 1), angle: num(gf.angle, 0)}
				},
				layers: {
					gf: num(gf.zIndex, 0),
					dad: num(dad.zIndex, 0),
					boyfriend: num(bf.zIndex, 0),
					props: propLayers
				}
			}
		};
	}

	static function convertProp(prop:Dynamic, index:Int, usedNames:Array<String>):Dynamic
	{
		if(prop == null) return null;

		var assetPath:String = str(prop.assetPath, '');
		if(assetPath.length < 1) return null;

		var name:String = str(prop.name, '');
		if(name.length < 1) name = 'prop$index';
		while(usedNames.contains(name)) name += '_';
		usedNames.push(name);

		var position:Array<Float> = pair(prop.position, 0, 0);
		var data:Dynamic = {
			name: name,
			x: position[0],
			y: position[1],
			scale: pair(prop.scale, 1, 1),
			scroll: pair(prop.scroll, 1, 1),
			alpha: num(prop.alpha, 1),
			angle: num(prop.angle, 0),
			color: 'FFFFFF',
			filters: 3 //low + high quality
		};

		var blend:String = str(prop.blend, '');
		if(blend.length > 0) data.blend = blend;

		// "#RRGGBB" as asset means a solid color rectangle, with its size as scale
		if(assetPath.startsWith('#'))
		{
			data.type = 'square';
			data.color = assetPath.substr(1);
			return data;
		}

		var animType:String = str(prop.animType, 'sparrow').toLowerCase();
		var animations:Array<Dynamic> = list(prop.animations);

		data.image = stripLibrary(assetPath);
		data.color = str(prop.color, '#FFFFFF').replace('#', '');
		data.antialiasing = (prop.isPixel != true);
		data.flipX = (prop.flipX == true);
		data.flipY = (prop.flipY == true);

		// Texture atlases. Their animations are frame labels of the atlas' timeline, or whole symbols of it
		if(animType == 'animateatlas')
		{
			data.type = 'atlas';
			data.applyStageMatrix = (prop.atlasSettings != null && prop.atlasSettings.applyStageMatrix == true);

			var atlasAnims:Array<Dynamic> = [];
			for (anim in animations)
			{
				var animName:String = str(anim.name, '');
				if(animName.length < 1) continue;

				atlasAnims.push({
					anim: animName,
					name: str(anim.prefix, animName),
					symbol: (str(anim.animType, 'framelabel').toLowerCase() == 'symbol'),
					loop: (anim.looped == true),
					indices: list(anim.frameIndices)
				});
			}
			data.animations = atlasAnims;
			data.firstAnimation = str(prop.startingAnimation, '');

			var danceEvery:Float = num(prop.danceEvery, 0);
			if(danceEvery > 0) data.danceEvery = danceEvery;
			return data;
		}

		if(animations.length < 1)
		{
			data.type = 'sprite';
			return data;
		}

		data.type = 'animatedSprite';
		data.vsliceOffsets = true; //(see `ModchartSprite.vsliceOffsets`)

		var psychAnims:Array<Dynamic> = [];
		var firstAnim:String = str(prop.startingAnimation, '');
		var hasFirstAnim:Bool = false;
		var hasIdle:Bool = false;
		for (anim in animations)
		{
			var animName:String = str(anim.name, '');
			if(animName.length < 1) continue;

			var psychAnim:Dynamic = {
				anim: animName,
				name: str(anim.prefix, animName),
				fps: Std.int(num(anim.frameRate, 24)),
				loop: (anim.looped == true),
				indices: list(anim.frameIndices)
			};

			// without offsets the sprite keeps the ones from its hitbox, which is what a scaled prop needs
			var offsets:Array<Float> = pair(anim.offsets, 0, 0);
			if(offsets[0] != 0 || offsets[1] != 0) psychAnim.offsets = offsets;

			if(animName == firstAnim) hasFirstAnim = true;
			if(animName == 'idle') hasIdle = true;
			psychAnims.push(psychAnim);
		}
		if(psychAnims.length < 1)
		{
			data.type = 'sprite';
			return data;
		}

		data.animations = psychAnims;
		data.firstAnimation = hasFirstAnim ? firstAnim : (hasIdle ? 'idle' : psychAnims[0].anim);

		var danceEvery:Float = num(prop.danceEvery, 0);
		if(danceEvery > 0) data.danceEvery = danceEvery;
		return data;
	}

	// ------------------------------------------------------------------------------------------
	// Character
	// ------------------------------------------------------------------------------------------

	/**
	 * Builds a Psych `CharacterFile` out of a V-Slice character.
	 * `position` holds the character's global offsets, as V-Slice characters are placed by their feet.
	 */
	public static function convertCharacter(char:Dynamic, id:String, isPlayer:Bool):Dynamic
	{
		if(char == null) return null;

		var scale:Float = num(char.scale, 1);
		var globalOffsets:Array<Float> = pair(char.offsets, 0, 0);
		var isAtlas:Bool = str(char.renderType, 'sparrow').toLowerCase().contains('animateatlas');

		var images:Array<String> = [];
		var mainImage:String = stripLibrary(str(char.assetPath, ''));
		if(mainImage.length > 0) images.push(mainImage);

		var animations:Array<Dynamic> = [];
		for (anim in list(char.animations))
		{
			var animName:String = str(anim.name, '');
			if(animName.length < 1) continue;

			// "multi" characters split their animations between several spritesheets, or several texture atlases.
			// The spritesheets are all loaded as one. An atlas can't be joined to another: the animation says which one it's on,
			// and the character gets an atlas for each (see `Character.getExtraAtlas()`)
			var extraImage:String = stripLibrary(str(anim.assetPath, ''));
			var otherAtlas:String = null;
			if(extraImage.length > 0 && extraImage != mainImage)
			{
				if(isAtlas)
				{
					// (a spritesheet on a texture atlas character can't be shown: the character is drawn by its atlas)
					if(str(anim.renderType, '').toLowerCase() == 'sparrow') continue;
					otherAtlas = extraImage;
				}
				else if(!images.contains(extraImage)) images.push(extraImage);
			}

			// V-Slice scales the animation offsets along with the character.
			// It also uses the character's own offsets twice: once on its position (which is where the camera looks at, see PlayState)
			// and once more when drawing it, moving every animation by them. Characters are made with that in mind, so it has to be the same here
			var offsets:Array<Float> = pair(anim.offsets, 0, 0);
			var psychAnim:Dynamic = {
				anim: animName,
				name: str(anim.prefix, animName),
				fps: Std.int(num(anim.frameRate, 24)),
				loop: (anim.looped == true),
				indices: list(anim.frameIndices),
				offsets: [Math.round((offsets[0] - globalOffsets[0]) * scale), Math.round((offsets[1] - globalOffsets[1]) * scale)]
			};

			// an animation can be mirrored on its own (on top of the character being mirrored or not)
			if(anim.flipX == true) psychAnim.flipX = true;
			if(anim.flipY == true) psychAnim.flipY = true;

			// atlas animations are frame labels of the main timeline unless told otherwise
			if(isAtlas && str(anim.animType, 'framelabel').toLowerCase() != 'symbol') psychAnim.frameLabel = true;
			if(otherAtlas != null) psychAnim.atlas = otherAtlas;
			animations.push(psychAnim);
		}

		var icon:String = id;
		if(char.healthIcon != null) icon = str(char.healthIcon.id, id);

		// Psych subtracts the X of the camera position when the character is the player
		var camera:Array<Float> = pair(char.cameraOffsets, 0, 0);
		if(isPlayer) camera[0] = -camera[0];

		return {
			animations: animations,
			image: images.join(','),
			scale: scale,
			// V-Slice stops the singing after `singTime` steps, Psych after `sing_duration` times 1.1 steps
			sing_duration: num(char.singTime, 8) / 1.1,
			healthicon: icon,

			position: pair(char.offsets, 0, 0),
			camera_position: camera,

			flip_x: (char.flipX == true),
			no_antialiasing: (char.isPixel == true),
			healthbar_colors: isPlayer ? [102, 255, 51] : [255, 0, 0], //V-Slice characters don't have a health bar color
			vocals_file: '',

			// What the character is drawn with is what its file says, like on V-Slice: the engine guesses it from what files there are,
			// and a spritesheet called like a texture atlas of the base game ("characters/BF" and its "bf" folder) was taken for it
			vsliceAtlas: isAtlas,

			// texture atlases put where their file has them on Adobe Animate's stage
			applyStageMatrix: (isAtlas && char.atlasSettings != null && char.atlasSettings.applyStageMatrix == true),
			// ...and drawn whole on a texture of their own before going on the screen
			useRenderTexture: (isAtlas && char.atlasSettings != null && char.atlasSettings.useRenderTexture == true)
		};
	}

	// ------------------------------------------------------------------------------------------
	// Helpers
	// ------------------------------------------------------------------------------------------

	public static inline function isNum(value:Dynamic):Bool
		return value != null && (Std.isOfType(value, Float) || Std.isOfType(value, Int));

	// ------------------------------------------------------------------------------------------
	// Saving a chart back
	// ------------------------------------------------------------------------------------------

	static function vsliceNoteKind(type:String):String
	{
		return switch(type)
		{
			case 'Alt Animation': 'alt';
			case 'Hey!': 'hey';
			case 'Hurt Note': 'hurt';
			default: type;
		}
	}

	/**
	 * The name V-Slice gives to a stage of the base game, for the ones Psych calls something else.
	 */
	public static function vsliceStageName(stage:String):String
	{
		return switch(stage)
		{
			case 'stage': 'mainStage';
			case 'spooky': 'spookyMansion';
			case 'philly': 'phillyTrain';
			case 'limo': 'limoRide';
			case 'mall': 'mallXmas';
			case 'tank': 'tankmanBattlefield';
			default: stage;
		}
	}

	/**
	 * Puts what was changed on a chart that came from `convertChart()` back on the V-Slice files it came from.
	 *
	 * The conversion loses things (Psych has no place for everything V-Slice files have), so nothing is written out of the converted chart
	 * unless it was changed: each part of the edited chart is compared with a new conversion of the files as they are,
	 * and only the parts that are different are made again. Whatever else the files have stays as it is.
	 *
	 * @param metadata 		The song's metadata file, parsed. It's changed in place.
	 * @param chart 		The song's chart file, parsed. It's changed in place.
	 * @param difficulty 	Difficulty of the chart file the edited chart is.
	 * @param fresh 		What the files turn into right now, the way they were loaded to be edited.
	 * @param edited 		The chart with the changes.
	 * @return Which of the two files changed, and what changed on them.
	 */
	public static function updateChart(metadata:Dynamic, chart:Dynamic, difficulty:String, fresh:Dynamic, edited:Dynamic):{chartChanged:Bool, metadataChanged:Bool, changes:Array<String>}
	{
		var result = {chartChanged: false, metadataChanged: false, changes: []};
		if(metadata == null || chart == null || fresh == null || edited == null) return result;

		// ---- Notes
		var oldNotes:Array<Array<Dynamic>> = flattenNotes(fresh.notes);
		var newNotes:Array<Array<Dynamic>> = flattenNotes(edited.notes);
		if(!sameRows(oldNotes, newNotes))
		{
			// the notes that are still where they were keep whatever else the file has about them
			var originals:Map<String, Array<Dynamic>> = [];
			if(chart.notes == null) chart.notes = {};
			for (raw in list(Reflect.field(chart.notes, difficulty)))
			{
				if(raw == null) continue;

				var key:String = noteKey(num(raw.t, 0), Std.int(num(raw.d, 0)));
				if(!originals.exists(key)) originals.set(key, []);
				originals.get(key).push(raw);
			}

			var rebuilt:Array<Dynamic> = [];
			for (note in newNotes)
			{
				var time:Float = note[0];
				var data:Int = note[1];
				var length:Float = note[2];
				var type:String = note[3];

				var same:Array<Dynamic> = originals.get(noteKey(time, data));
				var raw:Dynamic = (same != null && same.length > 0) ? same.shift() : null;
				var entry:Dynamic = (raw != null) ? Reflect.copy(raw) : {};

				entry.t = time;
				entry.d = data;

				if(length > 0) entry.l = length;
				else if(Reflect.hasField(entry, 'l')) entry.l = 0;

				// the kind it had is kept if it's still the same thing for Psych
				var rawKind:String = (raw != null) ? str(raw.k, '') : '';
				var rawType:String = (rawKind.length > 0 && rawKind != 'normal') ? psychNoteType(rawKind) : '';
				if(type != rawType)
				{
					if(type.length > 0) entry.k = vsliceNoteKind(type);
					else Reflect.deleteField(entry, 'k');
				}

				rebuilt.push(entry);
			}
			Reflect.setField(chart.notes, difficulty, rebuilt);

			result.chartChanged = true;
			result.changes.push('notes');
		}

		// ---- Scroll speed
		if(Math.abs(num(edited.speed, 1) - num(fresh.speed, 1)) > 0.0001)
		{
			// a single number is the speed of every difficulty, which stays being so for the others
			if(chart.scrollSpeed == null || isNum(chart.scrollSpeed))
			{
				var general:Dynamic = chart.scrollSpeed;
				chart.scrollSpeed = {};
				if(isNum(general)) Reflect.setField(chart.scrollSpeed, 'default', general);
			}
			Reflect.setField(chart.scrollSpeed, difficulty, num(edited.speed, 1));

			result.chartChanged = true;
			result.changes.push('scroll speed');
		}

		// ---- Events and camera
		var rawEvents:Array<Dynamic> = list(chart.events).copy();
		ArraySort.sort(rawEvents, sortByTime);

		// with these the camera is moved by the events themselves, and every one of them is an event on the converted chart too
		var keepFocusEvents:Bool = false;
		for (event in rawEvents)
		{
			if(event != null && event.e == 'FocusCamera' && !isPlainFocus(event))
			{
				keepFocusEvents = true;
				break;
			}
		}

		var oldEvents:Array<Array<Dynamic>> = flattenEvents(fresh.events);
		var newEvents:Array<Array<Dynamic>> = flattenEvents(edited.events);
		var eventsChanged:Bool = !sameRows(oldEvents, newEvents);
		var cameraChanged:Bool = !keepFocusEvents && !sameRows(focusChanges(fresh), focusChanges(edited));

		if(eventsChanged || cameraChanged)
		{
			var songBpm:Float = validBpm(edited.bpm);

			// the ones that are the sections' camera, and the ones that are events on the converted chart (in the same order as there)
			var sectionFocus:Array<Dynamic> = [];
			var converted:Array<Dynamic> = [];
			var leftAlone:Array<Dynamic> = [];
			for (event in rawEvents)
			{
				if(event == null) continue;

				if(focusCharacter(event) > -1 && !keepFocusEvents) sectionFocus.push(event);
				else if(str(event.e, '').length > 0) converted.push(event);
				else leftAlone.push(event); //nothing was made out of these
			}

			var others:Array<Dynamic> = converted;
			if(eventsChanged)
			{
				// each event of the files by what it turned into, so the ones that weren't touched go back exactly as they were
				var originals:Map<String, Array<Dynamic>> = [];
				for (num => row in oldEvents)
				{
					if(num >= converted.length) break;

					var key:String = Json.stringify(row);
					if(!originals.exists(key)) originals.set(key, []);
					originals.get(key).push(converted[num]);
				}

				others = [];
				for (row in newEvents)
				{
					var same:Array<Dynamic> = originals.get(Json.stringify(row));
					if(same != null && same.length > 0) others.push(same.shift());
					else others.push(unconvertEvent(row[0], row[1], row[2], row[3], songBpm));
				}
				result.changes.push('events');
			}

			if(cameraChanged)
			{
				sectionFocus = [for (change in focusChanges(edited)) {t: change[0], e: 'FocusCamera', v: {char: change[1]}}];
				result.changes.push('camera');
			}

			var all:Array<Dynamic> = others.concat(sectionFocus).concat(leftAlone);
			ArraySort.sort(all, sortByTime);
			chart.events = all;
			result.chartChanged = true;
		}

		// ---- BPM
		var newBpms:Array<Array<Dynamic>> = bpmChanges(edited);
		if(!sameRows(bpmChanges(fresh), newBpms))
		{
			var old:Array<Dynamic> = list(metadata.timeChanges).copy();
			ArraySort.sort(old, sortByTime);

			var timeChanges:Array<Dynamic> = [];
			for (num => change in newBpms)
			{
				// time signatures and whatever else the first one has go with all of them
				var entry:Dynamic = (old.length > 0 && old[0] != null) ? Reflect.copy(old[0]) : {};
				if(num > 0) Reflect.deleteField(entry, 'b');
				entry.t = change[0];
				entry.bpm = change[1];
				timeChanges.push(entry);
			}
			metadata.timeChanges = timeChanges;

			result.metadataChanged = true;
			result.changes.push('BPM');
		}

		// ---- Characters, stage and name
		if(metadata.playData == null) metadata.playData = {};
		var playData:Dynamic = metadata.playData;

		var characterFields:Array<Array<String>> = [['player1', 'player'], ['player2', 'opponent'], ['gfVersion', 'girlfriend']];
		for (fields in characterFields)
		{
			var value:String = str(Reflect.field(edited, fields[0]), '');
			if(value == str(Reflect.field(fresh, fields[0]), '')) continue;

			if(playData.characters == null) playData.characters = {};
			Reflect.setField(playData.characters, fields[1], value);

			result.metadataChanged = true;
			result.changes.push(fields[1]);
		}

		if(str(edited.stage, '') != str(fresh.stage, '') && str(edited.stage, '').length > 0)
		{
			playData.stage = vsliceStageName(edited.stage);
			result.metadataChanged = true;
			result.changes.push('stage');
		}

		if(str(edited.song, '') != str(fresh.song, '') && str(edited.song, '').length > 0)
		{
			metadata.songName = edited.song;
			result.metadataChanged = true;
			result.changes.push('song name');
		}

		return result;
	}

	static function noteKey(time:Float, data:Int):String
	{
		return Math.round(time * 100) + '_' + data;
	}

	// Every note of a Psych chart as [time, data, length, type], in order
	static function flattenNotes(sections:Dynamic):Array<Array<Dynamic>>
	{
		var rows:Array<Array<Dynamic>> = [];
		for (section in list(sections))
		{
			if(section == null) continue;

			for (note in list(section.sectionNotes))
			{
				var values:Array<Dynamic> = list(note);
				if(values.length < 2) continue;

				rows.push([num(values[0], 0), Std.int(num(values[1], 0)), Math.max(num(values[2], 0), 0), str(values[3], '')]);
			}
		}

		ArraySort.sort(rows, function(a:Array<Dynamic>, b:Array<Dynamic>):Int
		{
			var timeA:Float = a[0];
			var timeB:Float = b[0];
			if(Math.abs(timeA - timeB) > 0.001) return (timeA < timeB) ? -1 : 1;

			var dataA:Int = a[1];
			var dataB:Int = b[1];
			return dataA - dataB;
		});
		return rows;
	}

	// Every event of a Psych chart as [time, name, value 1, value 2], in order
	static function flattenEvents(events:Dynamic):Array<Array<Dynamic>>
	{
		var rows:Array<Array<Dynamic>> = [];
		for (event in list(events))
		{
			var values:Array<Dynamic> = list(event);
			if(values.length < 2) continue;

			for (single in list(values[1]))
			{
				var parts:Array<Dynamic> = list(single);
				if(parts.length < 1) continue;

				rows.push([num(values[0], 0), str(parts[0], ''), (parts[1] != null) ? Std.string(parts[1]) : '', (parts[2] != null) ? Std.string(parts[2]) : '']);
			}
		}

		ArraySort.sort(rows, function(a:Array<Dynamic>, b:Array<Dynamic>):Int
		{
			var timeA:Float = a[0];
			var timeB:Float = b[0];
			return (Math.abs(timeA - timeB) <= 0.001) ? 0 : ((timeA < timeB) ? -1 : 1);
		});
		return rows;
	}

	// Calls a function with each section of a Psych chart, the time it starts at and the BPM it has
	static function eachSection(song:Dynamic, func:Dynamic->Float->Float->Void):Void
	{
		var bpm:Float = validBpm(song.bpm);
		var time:Float = 0;
		for (section in list(song.notes))
		{
			if(section == null) continue;

			if(section.changeBPM == true && isNum(section.bpm)) bpm = validBpm(section.bpm);
			func(section, time, bpm);
			time += (60000 / bpm) * num(section.sectionBeats, 4);
		}
	}

	// Where the camera of a Psych chart goes from a character to another, as [time, character]
	static function focusChanges(song:Dynamic):Array<Array<Dynamic>>
	{
		var rows:Array<Array<Dynamic>> = [];
		var last:Int = -1;
		eachSection(song, function(section:Dynamic, time:Float, bpm:Float)
		{
			var focus:Int = (section.gfSection == true) ? 2 : ((section.mustHitSection == true) ? 0 : 1);
			if(focus == last) return;

			last = focus;
			rows.push([time, focus]);
		});
		return rows;
	}

	// The BPM of a Psych chart and where it changes, as [time, bpm]
	static function bpmChanges(song:Dynamic):Array<Array<Dynamic>>
	{
		var rows:Array<Array<Dynamic>> = [[0.0, validBpm(song.bpm)]];
		var last:Float = validBpm(song.bpm);
		eachSection(song, function(section:Dynamic, time:Float, bpm:Float)
		{
			if(Math.abs(bpm - last) < 0.0001) return;

			last = bpm;
			if(time <= 0.001) rows[0][1] = bpm;
			else rows.push([time, bpm]);
		});
		return rows;
	}

	// If two lists of rows of numbers and texts say the same thing
	static function sameRows(a:Array<Array<Dynamic>>, b:Array<Array<Dynamic>>):Bool
	{
		if(a.length != b.length) return false;

		for (num => rowA in a)
		{
			var rowB:Array<Dynamic> = b[num];
			if(rowA.length != rowB.length) return false;

			for (index => valueA in rowA)
			{
				var valueB:Dynamic = rowB[index];
				if(isNum(valueA) && isNum(valueB))
				{
					if(Math.abs((valueA : Float) - (valueB : Float)) > 0.001) return false;
				}
				else if(valueA != valueB) return false;
			}
		}
		return true;
	}

	// A V-Slice event out of a Psych one, the other way around of `convertEvent()`
	static function unconvertEvent(time:Float, name:String, value1:String, value2:String, bpm:Float):Dynamic
	{
		switch(name)
		{
			case 'Play Animation':
				var target:String = switch(value2.trim().toLowerCase())
				{
					case 'dad' | 'opponent' | '1': 'dad';
					case 'gf' | 'girlfriend' | '2': 'gf';
					default: 'bf';
				}
				return {t: time, e: 'PlayAnimation', v: {target: target, anim: value1, force: true}};

			case 'Change Scroll Speed':
				var multiplier:Float = Std.parseFloat(value1);
				var seconds:Float = Std.parseFloat(value2);
				if(Math.isNaN(multiplier)) multiplier = 1;
				if(Math.isNaN(seconds) || seconds < 0) seconds = 0;

				var steps:Float = seconds * bpm / 15;
				return {t: time, e: 'ScrollSpeed', v: {scroll: multiplier, duration: steps, ease: (steps > 0) ? 'linear' : 'INSTANT', absolute: false, strumline: 'both'}};
		}

		// Psych's own events keep their two values, the rest have theirs written as they are on V-Slice
		if(value2.length > 0) return {t: time, e: name, v: {value1: value1, value2: value2}};
		if(value1.length < 1) return {t: time, e: name};

		var value:Dynamic = value1;
		try
		{
			value = Json.parse(value1);
		}
		catch(e:Dynamic) {}
		return {t: time, e: name, v: value};
	}

	public static function num(value:Dynamic, defaultValue:Float):Float
		return isNum(value) ? (value : Float) : defaultValue;

	public static function str(value:Dynamic, defaultValue:String):String
		return (value != null && Std.isOfType(value, String)) ? (value : String) : defaultValue;

	public static function list(value:Dynamic):Array<Dynamic>
		return (value != null && Std.isOfType(value, Array)) ? (value : Array<Dynamic>) : [];

	/**
	 * Reads values that can be either a single number or `[x, y]`.
	 */
	public static function pair(value:Dynamic, defaultX:Float, defaultY:Float):Array<Float>
	{
		if(isNum(value)) return [value, value];

		var values:Array<Dynamic> = list(value);
		return [num(values[0], defaultX), num(values[1], defaultY)];
	}

	static function validBpm(value:Dynamic):Float
	{
		var bpm:Float = num(value, 100);
		return (bpm > 0) ? bpm : 100;
	}

	static function sortByTime(a:Dynamic, b:Dynamic):Int
	{
		var timeA:Float = num(a.t, 0);
		var timeB:Float = num(b.t, 0);
		return (timeA < timeB) ? -1 : ((timeA > timeB) ? 1 : 0);
	}
}
