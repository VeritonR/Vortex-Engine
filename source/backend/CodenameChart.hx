package backend;

import backend.Song.SwagSong;
import backend.Song.SwagSection;

/**
 * Vortex Engine: Codename Engine charts ("codenameChart": true, notes in "strumLines"), turned into a Psych chart with Vortex's
 * extra characters when one is read (`Song.parseJSON()`): from a song's folder (data/<song>/<song>-<difficulty>.json) or loaded
 * in the chart editor. Only the chart: the song's audio, characters and stage are the engine's (Psych's files).
 *
 * - The first opponent and player strumlines are the opponent and the player; strumline 2, if it's an "additional" one, is the
 *   girlfriend (as Codename has it). Every other strumline, and the other characters of a strumline, are extra characters.
 * - The BPM comes from "meta.json" (next to the chart, or in the folder above it, as Codename keeps it in "songs/<song>/"),
 *   or from the chart's own "meta". Its "events.json" is read too.
 * - BPM and time signature changes become sections; events become the engine's ones that do the same (see `convertEvent()`),
 *   and the ones the engine doesn't have are kept with their name, for scripts (onEvent).
 * - Strumlines that aren't visible sing notes nobody sees (the "hidden" singer, see `objects.ExtraCharacter`).
 */
class CodenameChart
{
	// (Codename's old charts gave events a number instead of a name)
	static final OLD_EVENT_NAMES:Map<Int, String> = [-1 => 'HScript Call', 0 => 'Unknown', 1 => 'Camera Movement', 2 => 'BPM Change', 3 => 'Alt Animation Toggle'];

	/**
	 * If the last chart read (`Song.parseJSON()`) was a Codename one. Saving it as it was read would put a Psych chart over the
	 * Codename file: the chart editor asks where to save it instead.
	 */
	public static var lastWasCodename:Bool = false;

	public static function isCodename(json:Dynamic):Bool
	{
		if(json == null || Type.typeof(json) != TObject) return false;
		var flag:Dynamic = Reflect.field(json, 'codenameChart');
		if(flag == true || flag == 'true') return true;
		return Std.isOfType(Reflect.field(json, 'strumLines'), Array) && !Reflect.hasField(json, 'notes');
	}

	/**
	 * @param path  The chart's file, to find its "meta.json" and "events.json" (null: only the chart's own meta)
	 * @param name  The song's name if its meta doesn't have one
	 */
	public static function toPsych(chart:Dynamic, ?path:String, ?name:String):SwagSong
	{
		lastWasCodename = true;
		var meta:Dynamic = findMeta(chart, path);
		var bpm:Float = number(field(meta, 'bpm'), 0);
		if(bpm <= 0)
		{
			trace('Codename chart: no BPM (no meta.json next to it): 100 is used');
			bpm = 100;
		}
		var measure:Float = number(field(meta, 'beatsPerMeasure'), 4);

		// ---------------------------------------------------------------- strumlines and who is who
		var lines:Array<Dynamic> = Std.isOfType(chart.strumLines, Array) ? chart.strumLines : [];
		var opponent:Int = -1, player:Int = -1, girlfriend:Int = -1;
		for (i => line in lines)
		{
			var type:Int = Std.int(number(line.type, 0));
			if(type == 1 && player < 0) player = i;
			else if(type == 0 && opponent < 0) opponent = i;
		}
		// (the girlfriend is strumline 2 for Codename; an "additional" one standing where she does is taken too)
		if(lines.length > 2 && Std.int(number(lines[2].type, 0)) == 2) girlfriend = 2;
		else for (i => line in lines)
			if(i != opponent && i != player && Std.int(number(line.type, 0)) == 2 && (line.position == null || line.position == 'girlfriend'))
			{
				girlfriend = i;
				break;
			}

		var song:SwagSong = {
			// (the song's folder: its music is found by it. "displayName" is only what Codename shows)
			song: Std.string(firstOf([songFolderOf(path), field(meta, 'name'), field(meta, 'displayName'), name, 'song'])),
			notes: [],
			events: [],
			bpm: bpm,
			needsVoices: field(meta, 'needsVoices') != false,
			speed: number(chart.scrollSpeed, 1),
			offset: 0,
			player1: characterOf(lines, player, 'bf'),
			player2: characterOf(lines, opponent, 'dad'),
			gfVersion: characterOf(lines, girlfriend, 'gf'),
			stage: (chart.stage != null) ? Std.string(chart.stage) : 'stage',
			format: 'psych_v1'
		};
		var keys:Int = (player >= 0) ? Std.int(number(lines[player].keyCount, 4)) : 4;
		if(keys != 4) Reflect.setField(song, 'keyCount', keys);
		// (no strumline for her: Codename's song has no girlfriend)
		if(girlfriend < 0) song.hideGirlfriend = true;

		// Where the receptors of the opponent and the player are, if their strumlines say (see `strumLayout`)
		var layout:Dynamic = {};
		for (role => index in ['opponent' => opponent, 'player' => player])
		{
			if(index < 0) continue;
			var place:Dynamic = strumLayout(lines[index], keys, true);
			if(place != null) Reflect.setField(layout, role, place);
		}
		if(Reflect.fields(layout).length > 0) song.vortexStrumlines = layout;

		// The extra characters: the other characters of each strumline, and every character of the strumlines that aren't one
		// of the three. Each strumline's notes say who sings them (see `singersOf`)
		var extras:Array<Dynamic> = [];
		var lineTags:Array<Array<String>> = [for (_ in lines) []];
		var taken:Array<String> = [];
		var perSide:Map<String, Int> = []; //(how many already stand on each side, to put the next one further out)
		for (i => line in lines)
		{
			var chars:Array<String> = [for (char in (Std.isOfType(line.characters, Array) ? (line.characters : Array<Dynamic>) : [])) Std.string(char)];
			var main:Bool = (i == opponent || i == player || i == girlfriend);
			var side:String = sideOf(line, i == girlfriend);
			for (k => char in chars)
			{
				if(main && k == 0) continue;
				var tag:String = char;
				var count:Int = 2;
				while(taken.contains(tag) || tag == objects.ExtraCharacter.MAIN || tag == objects.ExtraCharacter.ALL || tag == 'gf' || tag == 'hidden') tag = char + (count++);
				taken.push(tag);
				lineTags[i].push(tag);
				// (next to the main character of their side, further out the more there are: the player's to the right, others left)
				var placed:Int = perSide.exists(side) ? perSide.get(side) + 1 : 1;
				perSide.set(side, placed);
				var extra:Dynamic = {tag: tag, character: char, side: side, x: ((side == 'player') ? 250 : -250) * placed, y: 0, singsAll: main, behind: true};
				// (a strumline of its own that can be seen: its receptors are its own, where Codename puts them. One that can't is
				// sung in the background, see singersOf)
				if(!main && line.visible != false)
				{
					var place:Dynamic = strumLayout(line, keys, false);
					extra.ownStrum = true;
					extra.strumX = place.x;
					if(place.y != null) extra.strumY = place.y;
				}
				extras.push(extra);
			}
		}
		if(extras.length > 0) song.vortexCharacters = extras;

		// ---------------------------------------------------------------- the song's tempo, measures and camera over time
		var rawEvents:Array<Dynamic> = Std.isOfType(chart.events, Array) ? (chart.events : Array<Dynamic>).copy() : [];
		for (event in globalEvents(path)) rawEvents.push(event);
		for (event in rawEvents)
			if(event.name == null && event.type != null) event.name = OLD_EVENT_NAMES.get(Std.int(number(event.type, 0)));
		rawEvents.sort(function(a, b) return Reflect.compare(number(a.time, 0), number(b.time, 0)));

		var tempo:Array<{time:Float, bpm:Float}> = [{time: 0, bpm: bpm}];
		var signatures:Array<{time:Float, beats:Float}> = [{time: 0, beats: measure}];
		var cameras:Array<{time:Float, line:Int}> = [{time: -1, line: (opponent >= 0) ? opponent : 0}];
		for (event in rawEvents)
		{
			var params:Array<Dynamic> = paramsOf(event);
			var time:Float = number(event.time, 0);
			if(!isBuiltIn(event)) continue;
			switch(event.name)
			{
				case 'BPM Change':
					var value:Float = number(params[0], 0);
					if(value > 0) tempo.push({time: time, bpm: value});
				case 'Continuous BPM Change':
					// (the tempo changes little by little: a step of it on each beat, over its length in steps)
					var target:Float = number(params[0], 0);
					var steps:Float = Math.max(1, number(params[1], 4));
					if(target <= 0) continue;
					var from:Float = bpmAt(tempo, time);
					var beats:Int = Std.int(Math.max(1, Math.ceil(steps / 4)));
					var at:Float = time;
					for (k in 1...beats + 1)
					{
						var value:Float = from + (target - from) * (k / beats);
						tempo.push({time: at, bpm: value});
						at += 60000 / value * Math.min(1, (steps - (k - 1) * 4) / 4);
					}
				case 'Time Signature Change':
					var value:Float = number(params[0], 0);
					if(value > 0) signatures.push({time: time, beats: value});
				case 'Camera Movement':
					cameras.push({time: time, line: Std.int(number(params[0], 0))});
				default:
			}
		}

		// ---------------------------------------------------------------- the notes
		var noteTypes:Array<Dynamic> = Std.isOfType(chart.noteTypes, Array) ? chart.noteTypes : [];
		var altTimes:Array<Array<{time:Float, on:Bool}>> = [for (_ in lines) []];
		for (event in rawEvents)
			if(event.name == 'Alt Animation Toggle' && isBuiltIn(event))
			{
				var params:Array<Dynamic> = paramsOf(event);
				var line:Int = Std.int(number(params[2], 0));
				if(line >= 0 && line < lines.length) altTimes[line].push({time: number(event.time, 0), on: params[0] == true});
			}

		var notes:Array<Array<Dynamic>> = [];
		var lastTime:Float = 0;
		for (i => line in lines)
		{
			var visible:Bool = (line.visible != false);
			var playable:Bool = (Std.int(number(line.type, 0)) == 1) && visible; //(a hidden one of the player is sung by the computer)
			var singers:String = singersOf(i, visible, opponent, player, girlfriend, lineTags[i]);
			if(!Std.isOfType(line.notes, Array)) continue;
			for (note in (line.notes : Array<Dynamic>))
			{
				var time:Float = number(note.time, 0);
				var column:Int = Std.int(number(note.id, 0)) % keys;
				if(column < 0) continue;
				var typeId:Int = Std.int(number(note.type, 0));
				var noteType:String = (typeId > 0 && typeId - 1 < noteTypes.length) ? Std.string(noteTypes[typeId - 1]) : '';
				if(noteType == 'Default Note') noteType = '';
				if(noteType == '' && altOn(altTimes[i], time)) noteType = 'Alt Animation';
				var length:Float = Math.max(0, number(note.sLen, 0));

				var data:Array<Dynamic> = [time, playable ? column : column + keys, length, noteType];
				if(singers != null) data.push(singers);
				notes.push(data);
				lastTime = Math.max(lastTime, time + length);
			}
		}
		for (event in rawEvents) lastTime = Math.max(lastTime, number(event.time, 0));
		notes.sort(function(a, b) return Reflect.compare(a[0], b[0]));

		// ---------------------------------------------------------------- sections: a measure each, cut where the tempo changes
		var time:Float = 0;
		var currentBpm:Float = bpm;
		var lastBpm:Float = bpm;
		var beats:Float = measure;
		var noteIndex:Int = 0;
		var guard:Int = 0;
		while((time <= lastTime || song.notes.length < 1) && guard++ < 100000)
		{
			for (change in tempo) if(change.time <= time + 0.5) currentBpm = change.bpm;
			for (change in signatures) if(change.time <= time + 0.5) beats = change.beats;

			var crochet:Float = 60000 / currentBpm;
			var end:Float = time + beats * crochet;
			for (change in tempo) if(change.time > time + 0.5 && change.time < end - 0.5) end = Math.min(end, change.time);
			for (change in signatures) if(change.time > time + 0.5 && change.time < end - 0.5) end = Math.min(end, change.time);

			var section:SwagSection = {
				sectionNotes: [],
				sectionBeats: (end - time) / crochet,
				mustHitSection: cameraLine(cameras, time, opponent) == player && player >= 0
			};
			if(currentBpm != lastBpm)
			{
				section.changeBPM = true;
				section.bpm = currentBpm;
				lastBpm = currentBpm;
			}
			while(noteIndex < notes.length && notes[noteIndex][0] < end - 0.001) section.sectionNotes.push(notes[noteIndex++]);
			song.notes.push(section);
			time = end;
		}
		while(noteIndex < notes.length) song.notes[song.notes.length - 1].sectionNotes.push(notes[noteIndex++]);

		// ---------------------------------------------------------------- the events
		var speed:Float = song.speed;
		var byTime:Map<String, Array<Dynamic>> = [];
		var times:Array<Float> = [];
		for (event in rawEvents)
		{
			var eventTime:Float = number(event.time, 0);
			var stepSeconds:Float = 60 / bpmAt(tempo, eventTime) / 4;
			// (a mod's own event with the name of one of Codename's is the mod's: kept as it is, for its scripts)
			var converted:Array<Dynamic> = isBuiltIn(event)
				? convertEvent(event.name, paramsOf(event), stepSeconds, speed, song.speed, measure,
					function(line:Int) return targetOf(line, opponent, player, girlfriend, lineTags))
				: [keptEvent(event.name, paramsOf(event))];
			if(event.name == 'Scroll Speed Change' && converted != null && converted.length > 0)
				speed = song.speed * number(converted[0][1], 1);
			for (one in converted)
			{
				var key:String = Std.string(eventTime);
				if(!byTime.exists(key)) { byTime.set(key, []); times.push(eventTime); }
				byTime.get(key).push(one);
			}
		}
		times.sort(Reflect.compare);
		for (eventTime in times) song.events.push([eventTime, byTime.get(Std.string(eventTime))]);

		trace('Codename chart converted: ${lines.length} strumlines, ${notes.length} notes, ${song.events.length} events, ${extras.length} extra characters');
		return song;
	}

	/**
	 * A Codename event as the engine's events that do the same ([name, value 1, value 2] each). The ones the engine handles with
	 * sections (BPM, time signature) give none; the ones it has nothing for keep their name, for scripts.
	 */
	static function convertEvent(name:String, params:Array<Dynamic>, stepSeconds:Float, currentSpeed:Float, songSpeed:Float, measure:Float, target:Int->String):Array<Dynamic>
	{
		inline function text(value:Dynamic):String return (value == null) ? '' : Std.string(value);
		switch(name)
		{
			case 'BPM Change' | 'Continuous BPM Change' | 'Time Signature Change':
				return []; //(the sections have them)

			case 'Alt Animation Toggle':
				// (the sing poses are the notes' "Alt Animation" type; the idle one is Psych's event)
				var who:String = target(Std.int(number(params[2], 0)));
				return (who != null && (who == 'dad' || who == 'bf' || who == 'gf')) ? [['Alt Idle Animation', who, (params[1] == true) ? '-alt' : '']] : [];

			case 'Camera Movement':
				// [strumline, tween?, steps, ease, ease type, offset x, offset y]
				var who:String = target(Std.int(number(params[0], 0)));
				if(who == null) return [];
				return [['Camera Target', who, cameraMove(params[1], params[2], params[3], params[4], params[5], params[6], stepSeconds)]];

			case 'Camera Position':
				// [x, y, tween?, steps, ease, ease type, offset from where it is?]
				var spot:String = (params[6] == true)
					? '+' + number(params[0], 0) + ', +' + number(params[1], 0)
					: number(params[0], 0) + ', ' + number(params[1], 0);
				return [['Camera Target', spot, cameraMove(params[2], params[3], params[4], params[5], 0, 0, stepSeconds)]];

			case 'Add Camera Zoom':
				var amount:String = text(number(params[0], 0.05));
				return (params[1] == 'camHUD') ? [['Add Camera Zoom', '0', amount]] : [['Add Camera Zoom', amount, '0']];

			case 'Camera Bop':
				var amount:String = text(number(params[0], 0.1));
				return [['Add Camera Zoom', amount, amount]];

			case 'Camera Zoom':
				var zoom:Float = number(params[1], 1);
				if(params[2] == 'camHUD')
				{
					// (the HUD's own zoom, which stays: "Set Camera Zoom" with ", hud")
					var hudSeconds:Float = (params[0] != false) ? number(params[3], 4) * stepSeconds : 0;
					var hudEase:String = easeOf(params[4], params[5]);
					return [['Set Camera Zoom', text(zoom), hudSeconds + ', ' + ((hudEase != null) ? hudEase : 'quadOut') + ', hud']];
				}
				// "stage": times the stage's zoom ("*1.2" for Set Camera Zoom), "direct": as it is
				var value:String = (params[6] == 'stage') ? '*' + zoom : text(zoom);
				var tween:Bool = (params[0] != false);
				var ease:String = easeOf(params[4], params[5]);
				var seconds:Float = tween ? number(params[3], 4) * stepSeconds : 0;
				if(tween && ease == null) { ease = 'quadOut'; seconds = Math.max(seconds, 0.5); } //(CLASSIC: the camera eases into it)
				return [['Set Camera Zoom', value, (seconds > 0) ? seconds + ', ' + ease : '']];

			case 'Camera Modulo Change':
				var interval:Float = number(params[0], 4);
				var every:Float = switch(text(params[2]))
				{
					case 'MEASURE': interval * measure;
					case 'STEP': Math.max(1, Math.round(interval / 4));
					default: interval;
				}
				return [['Camera Bop', text(Std.int(Math.max(1, every))), text(number(params[1], 1))]];

			case 'Camera Flash':
				var color:String = text(params[1]).replace('#', '');
				if(color.length < 1) color = 'FFFFFF';
				var seconds:Float = number(params[2], 4) * stepSeconds;
				var camera:String = (params[3] == 'camHUD') ? 'hud' : 'game';
				// (reversed: the screen goes to that color)
				if(params[0] == true) return [['Fade Screen', '$color, 1', '$seconds, linear']];
				return [['Flash Camera', '$color, $seconds', camera]];

			case 'Scroll Speed Change':
				var newSpeed:Float = number(params[1], 1);
				if(params[5] == true) newSpeed *= currentSpeed;
				var seconds:Float = (params[0] != false) ? number(params[2], 4) * stepSeconds : 0;
				return [['Change Scroll Speed', text(newSpeed / Math.max(0.01, songSpeed)), text(seconds)]];

			case 'Play Animation':
				var who:String = target(Std.int(number(params[0], 0)));
				return (who != null) ? [['Play Animation', text(params[1]), who]] : [];

			default:
				// (kept for scripts: the first value, and the others separated by commas)
				var rest:Array<String> = [for (i in 1...params.length) text(params[i])];
				return [[(name != null) ? name : 'Unknown', text(params[0]), rest.join(', ')]];
		}
	}

	// The most values each of Codename's own events has: one with more is a mod's event that has the same name (Gorefield's "Camera
	// Bop", [beats, strength]), and it's left as it is
	static final BUILT_IN_PARAMS:Map<String, Int> = [
		'HScript Call' => 2, 'Camera Movement' => 7, 'Camera Position' => 7, 'Add Camera Zoom' => 2, 'Camera Bop' => 1,
		'Camera Zoom' => 8, 'Camera Modulo Change' => 4, 'Camera Flash' => 4, 'BPM Change' => 1, 'Continuous BPM Change' => 2,
		'Time Signature Change' => 3, 'Scroll Speed Change' => 6, 'Alt Animation Toggle' => 3, 'Play Animation' => 4
	];

	static function isBuiltIn(event:Dynamic):Bool
	{
		var name:String = event.name;
		return name != null && BUILT_IN_PARAMS.exists(name) && paramsOf(event).length <= BUILT_IN_PARAMS.get(name);
	}

	// An event the engine has nothing for: its name, the first value, and the others separated by commas (scripts get it in onEvent)
	static function keptEvent(name:String, params:Array<Dynamic>):Array<Dynamic>
	{
		var rest:Array<String> = [for (i in 1...params.length) (params[i] == null) ? '' : Std.string(params[i])];
		return [(name != null) ? name : 'Unknown', (params.length > 0 && params[0] != null) ? Std.string(params[0]) : '', rest.join(', ')];
	}

	/**
	 * How the camera moves, as "Camera Target"'s value 2: "snap" (no tween), blank (CLASSIC: the camera's own easing), or the
	 * seconds and the ease; then the offset.
	 */
	static function cameraMove(tween:Dynamic, steps:Dynamic, ease:Dynamic, easeType:Dynamic, offsetX:Dynamic, offsetY:Dynamic, stepSeconds:Float):String
	{
		var how:Array<String> = ['', ''];
		var name:String = easeOf(ease, easeType);
		if(tween == false) how = ['snap', ''];
		else if(name != null) how = [Std.string(number(steps, 4) * stepSeconds), name];
		var x:Float = number(offsetX, 0), y:Float = number(offsetY, 0);
		if(x != 0 || y != 0) return how.concat([Std.string(x), Std.string(y)]).join(', ');
		return (how[0].length > 0) ? how.join(', ') : '';
	}

	/**
	 * Where Codename puts a strumline's receptors: "strumPos" x (if it isn't 0) or centered at "strumLinePos" of the screen's width
	 * (0.25 for the opponent, 0.75 for the player), and "strumPos" y. For the main ones, null when it's where the engine puts them anyway.
	 */
	static function strumLayout(line:Dynamic, keys:Int, main:Bool):Dynamic
	{
		var type:Int = Std.int(number(line.type, 0));
		var pos:Array<Dynamic> = Std.isOfType(line.strumPos, Array) ? line.strumPos : null;
		var fraction:Float = number(line.strumLinePos, (type == 1) ? 0.75 : 0.25);
		var x:Null<Float> = null;
		if(pos != null && number(pos[0], 0) != 0) x = number(pos[0], 0);
		else if(!main || line.strumLinePos != null && fraction != ((type == 1) ? 0.75 : 0.25)) x = 1280 * fraction - keys * 112 / 2;
		var y:Null<Float> = (pos != null && number(pos[1], 50) != 50) ? number(pos[1], 50) : null;
		var hidden:Bool = (line.visible == false);
		if(main && x == null && y == null && !hidden) return null;
		var place:Dynamic = {};
		if(x != null) place.x = x;
		if(y != null) place.y = y;
		if(main && hidden) place.visible = false;
		return place;
	}

	// ------------------------------------------------------------------------------------------

	// The chart's meta: its own "meta", or the meta.json next to it or in the folder above it (Codename's songs/<song>/)
	static function findMeta(chart:Dynamic, path:String):Dynamic
	{
		#if sys
		if(path != null && path.length > 0)
		{
			var folder:String = haxe.io.Path.directory(path);
			var difficulty:String = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(path));
			var dash:Int = difficulty.lastIndexOf('-');
			var shortDifficulty:String = (dash > -1) ? difficulty.substr(dash + 1) : difficulty;
			var parent:String = haxe.io.Path.directory(folder);
			for (file in [
				'$folder/meta-$difficulty.json', '$folder/meta-$shortDifficulty.json', '$folder/meta.json',
				'$parent/meta-$difficulty.json', '$parent/meta-$shortDifficulty.json', '$parent/meta.json'])
			{
				if(!sys.FileSystem.exists(file)) continue;
				try
				{
					var meta:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
					if(meta != null) return meta;
				}
				catch(e:Dynamic) trace('Codename chart: "$file" could not be read: $e');
			}
		}
		#end
		var own:Dynamic = Reflect.field(chart, 'meta');
		return (own != null && Type.typeof(own) == TObject) ? own : {};
	}

	// "events.json" of the song (Codename's events for every difficulty)
	static function globalEvents(path:String):Array<Dynamic>
	{
		#if sys
		if(path == null || path.length < 1) return [];
		var folder:String = haxe.io.Path.directory(path);
		for (file in ['$folder/events.json', haxe.io.Path.directory(folder) + '/events.json'])
		{
			if(!sys.FileSystem.exists(file)) continue;
			try
			{
				var data:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
				if(data != null && Std.isOfType(data.events, Array)) return data.events;
			}
			catch(e:Dynamic) trace('Codename chart: "$file" could not be read: $e');
		}
		#end
		return [];
	}

	// The folder a chart is in (data/<song>/), or the one above it for Codename's songs/<song>/charts/
	static function songFolderOf(path:String):String
	{
		if(path == null || path.length < 1) return null;
		var folder:String = haxe.io.Path.directory(path.replace('\\', '/'));
		if(folder.length < 1) return null;
		var name:String = haxe.io.Path.withoutDirectory(folder);
		if(name.toLowerCase() == 'charts') name = haxe.io.Path.withoutDirectory(haxe.io.Path.directory(folder));
		return (name.length > 0) ? name : null;
	}

	static function characterOf(lines:Array<Dynamic>, index:Int, fallback:String):String
	{
		if(index < 0 || !Std.isOfType(lines[index].characters, Array)) return fallback;
		var chars:Array<Dynamic> = lines[index].characters;
		return (chars.length > 0 && chars[0] != null) ? Std.string(chars[0]) : fallback;
	}

	// Where an extra character of a strumline stands: the spot its strumline asks for ("position"), or the one of its kind
	static function sideOf(line:Dynamic, isGirlfriend:Bool):String
	{
		switch(line.position)
		{
			case 'boyfriend': return 'player';
			case 'girlfriend': return 'gf';
			case 'dad': return 'opponent';
			default:
		}
		if(isGirlfriend) return 'gf';
		return switch(Std.int(number(line.type, 0))) { case 1: 'player'; case 2: 'gf'; default: 'opponent'; }
	}

	// Who sings the notes of a strumline (a note's 5th value, see objects.ExtraCharacter): null is the main character of its side
	static function singersOf(index:Int, visible:Bool, opponent:Int, player:Int, girlfriend:Int, tags:Array<String>):String
	{
		var hidden:String = visible ? '' : ',hidden';
		if(index == opponent || index == player) return visible ? null : 'default' + hidden;
		if(index == girlfriend) return 'main,gf' + hidden;
		return (tags.length > 0) ? tags.join(',') + hidden : 'hidden';
	}

	// Who a strumline is for the events that name one: dad, bf, gf, or its first extra character
	static function targetOf(index:Int, opponent:Int, player:Int, girlfriend:Int, tags:Array<Array<String>>):String
	{
		if(index == opponent) return 'dad';
		if(index == player) return 'bf';
		if(index == girlfriend) return 'gf';
		return (index >= 0 && index < tags.length && tags[index].length > 0) ? tags[index][0] : null;
	}

	static function cameraLine(cameras:Array<{time:Float, line:Int}>, time:Float, fallback:Int):Int
	{
		var line:Int = fallback;
		for (camera in cameras) if(camera.time <= time + 0.5) line = camera.line;
		return line;
	}

	static function bpmAt(tempo:Array<{time:Float, bpm:Float}>, time:Float):Float
	{
		var bpm:Float = tempo[0].bpm;
		for (change in tempo) if(change.time <= time) bpm = change.bpm;
		return bpm;
	}

	static function altOn(changes:Array<{time:Float, on:Bool}>, time:Float):Bool
	{
		var on:Bool = false;
		for (change in changes) if(change.time <= time + 0.5) on = change.on;
		return on;
	}

	// Codename's ease ("quad") and its kind ("In") as the engine's name ("quadIn"); null for CLASSIC (the camera's own easing)
	static function easeOf(ease:Dynamic, type:Dynamic):String
	{
		if(ease == null || ease == 'CLASSIC') return null;
		var name:String = Std.string(ease);
		if(name == 'linear') return 'linear';
		return name + ((type != null) ? Std.string(type) : 'In');
	}

	static function paramsOf(event:Dynamic):Array<Dynamic>
		return Std.isOfType(event.params, Array) ? event.params : [];

	static function field(object:Dynamic, name:String):Dynamic
		return (object != null) ? Reflect.field(object, name) : null;

	static function firstOf(values:Array<Dynamic>):Dynamic
	{
		for (value in values) if(value != null && Std.string(value).length > 0) return value;
		return null;
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if(value == null) return fallback;
		var result:Float = Std.isOfType(value, Float) || Std.isOfType(value, Int) ? value : Std.parseFloat(Std.string(value));
		return Math.isNaN(result) ? fallback : result;
	}
}
