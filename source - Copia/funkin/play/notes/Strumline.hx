package funkin.play.notes;

import objects.StrumNote;

/**
 * One side's receptors as V-Slice scripts know them, around the group Psych keeps them on.
 */
class Strumline
{
	public var isPlayer(default, null):Bool;

	var game(get, never):states.PlayState;
	inline function get_game():states.PlayState
		return states.PlayState.instance;

	var hidden:Bool = false;
	var alphas:Array<Null<Float>> = [];

	public function new(isPlayer:Bool)
	{
		this.isPlayer = isPlayer;
	}

	/**
	 * The receptors themselves.
	 */
	public var strumlineNotes(get, never):FlxTypedGroup<StrumNote>;
	function get_strumlineNotes():FlxTypedGroup<StrumNote>
		return (game == null) ? null : (isPlayer ? game.playerStrums : game.opponentStrums);

	// (the receptors, for the engine's own use)
	var strums(get, never):Array<StrumNote>;
	function get_strums():Array<StrumNote>
		return (strumlineNotes != null) ? strumlineNotes.members : [];

	/**
	 * V-Slice's strumline is a group of groups (its background, the receptors, the long notes, the notes, the hold covers and the
	 * splashes, in that order), and scripts hide a whole side by going through them: `for (part in opponentStrumline.members)
	 * part.visible = false` takes its notes off the screen too, not only its receptors (Blazin, the LE SSERAFIM stage...).
	 * Each one here does what its own does: the receptors' hides the receptors, the notes' the notes...
	 */
	public var members(get, never):Array<Dynamic>;
	function get_members():Array<Dynamic>
	{
		var receptors:NoteList = new NoteList([for (strum in strums) strum], () -> alpha, (value:Float) -> alpha = value);
		receptors.readVisible = function() return Lambda.exists(strums, (strum) -> strum != null && strum.visible);
		receptors.writeVisible = function(value:Bool)
		{
			for (strum in strums)
				if(strum != null) strum.visible = value;
		};
		return [new NoteList([]), receptors, holdNotes, new NoteList([]), notes, new NoteList([]), noteHoldCovers, noteSplashes];
	}

	/**
	 * This side's notes that are on the screen, in a list that's used like the group V-Slice has them in.
	 */
	public var notes(get, never):Dynamic;
	function get_notes():Dynamic
	{
		var found:Array<NoteSprite> = [];
		if(game != null && game.notes != null)
			for (note in game.notes.members)
				if(note != null && !note.isSustainNote && note.mustPress == isPlayer)
					found.push(NoteSprite.get(note));
		return new NoteList(found, () -> noteAlpha, function(value:Float)
		{
			noteAlpha = value;
			applyNoteAlpha(false);
		});
	}

	// V-Slice keeps the notes, the long notes, the splashes and the sparks of a side in a group each, and scripts fade them one by one.
	// Psych's notes take the alpha of their receptor times one of their own, which is what the groups' alphas are here
	var noteAlpha:Float = 1;
	var holdAlpha:Float = 1;
	var splashAlpha:Float = 1;
	var coverAlpha:Float = 1;

	function applyNoteAlpha(sustains:Bool):Void
	{
		if(hidden || game == null || game.notes == null) return;

		for (note in game.notes.members)
			if(note != null && note.mustPress == isPlayer && note.isSustainNote == sustains)
				note.multAlpha = sustains ? holdAlpha : noteAlpha;
	}

	/**
	 * Takes a note off the screen, its long note with it (V-Slice's `killNote()`). Scripts do it with the notes whose hit they
	 * cancelled to have someone else sing them: they aren't hit, missed or seen anymore.
	 */
	public function killNote(sprite:Dynamic):Void
	{
		var note:objects.Note = Std.downcast(sprite, objects.Note);
		if(note == null)
		{
			var facade:NoteSprite = Std.downcast(sprite, NoteSprite);
			if(facade != null) note = facade.note;
		}
		if(note == null || game == null) return;

		for (piece in [note].concat(note.tail))
		{
			if(piece == null) continue;
			piece.extraData.set('vsliceKilled', true);
			piece.ignoreNote = true;
			piece.hitCausesMiss = false;
			piece.multAlpha = 0;
		}

		// (taken out of the game after this frame: it's being gone through by whatever hit it right now)
		var playState:states.PlayState = game;
		FlxG.signals.postUpdate.addOnce(function()
		{
			if(states.PlayState.instance != playState || playState.notes == null) return;
			for (piece in [note].concat(note.tail))
				if(piece != null && piece.exists && playState.notes.members.contains(piece))
					playState.invalidateNote(piece);
		});
	}

	/**
	 * A note of this side that just showed up: it gets the alpha its group was left with.
	 */
	public function noteSpawned(note:objects.Note):Void
	{
		if(note == null || note.extraData.exists('vsliceKilled')) return;

		if(hidden) note.multAlpha = 0;
		else if(note.isSustainNote && holdAlpha != 1) note.multAlpha = holdAlpha;
		else if(!note.isSustainNote && noteAlpha != 1) note.multAlpha = noteAlpha;
	}

	/**
	 * The splashes of the notes that were hit just right. They're all on one group here, the ones of both sides.
	 */
	public var noteSplashes(get, never):Dynamic;
	function get_noteSplashes():Dynamic
	{
		var found:Array<Dynamic> = [];
		if(game != null && game.grpNoteSplashes != null)
			for (splash in game.grpNoteSplashes.members)
				if(splash != null) found.push(splash);

		return new NoteList(found, () -> splashAlpha, function(value:Float)
		{
			splashAlpha = value;
			if(game != null && game.grpNoteSplashes != null)
				for (splash in game.grpNoteSplashes.members)
					if(splash != null) splash.alpha = value;
		});
	}

	/**
	 * The sparks on the receptors while a long note is held, like the splashes.
	 */
	public var noteHoldCovers(get, never):Dynamic;
	function get_noteHoldCovers():Dynamic
	{
		var found:Array<Dynamic> = [];
		if(game != null && game.grpHoldCovers != null)
			for (cover in game.grpHoldCovers.members)
				if(cover != null) found.push(cover);

		return new NoteList(found, () -> coverAlpha, function(value:Float)
		{
			coverAlpha = value;
			if(game != null && game.grpHoldCovers != null)
				for (cover in game.grpHoldCovers.members)
					if(cover != null) Reflect.setProperty(cover, 'alpha', value);
		});
	}

	// Psych's notes follow the alpha of their receptor, so hiding a side is done with it and the notes go along
	public var visible(get, set):Bool;
	function get_visible():Bool return !hidden;
	function set_visible(value:Bool):Bool
	{
		hidden = !value;
		apply();
		return value;
	}

	/**
	 * The receptors are only made when the countdown starts, what was asked before that is done again then.
	 */
	public function apply():Void
	{
		// the notes that are already on the screen go along
		if(game != null && game.notes != null)
			for (note in game.notes.members)
				if(note != null && note.mustPress == isPlayer && (note.multAlpha == 0) != hidden)
					note.multAlpha = hidden ? 0 : (note.isSustainNote ? holdAlpha : noteAlpha);

		for (i => strum in strums)
		{
			if(strum == null) continue;

			if(hidden)
			{
				// the receptors fade in when the countdown starts, which would bring the notes back.
				// Caught in the middle of that their alpha isn't the one to go back to later
				FlxTween.cancelTweensOf(strum, ['alpha']);

				if(strum.visible) alphas[i] = (strum.alpha > 0.3) ? strum.alpha : 1;
				strum.visible = false;
				strum.alpha = 0;
			}
			else if(!strum.visible)
			{
				strum.visible = true;
				strum.alpha = (alphas[i] != null) ? alphas[i] : 1;
			}
		}
	}

	// The engine's options make one side see-through (middlescroll) or hide it: the scripts' alpha is on top of that, like on V-Slice
	// (which has neither) a strumline at 1 is one that looks the way the player has it
	public var alpha(get, set):Float;
	function get_alpha():Float
	{
		var alpha:Float = (strums.length > 0 && strums[0] != null) ? strums[0].alpha : 1;
		var base:Float = baseAlpha();
		return (base > 0) ? alpha / base : alpha;
	}
	function set_alpha(value:Float):Float
	{
		var base:Float = baseAlpha();
		for (strum in strums)
			if(strum != null) strum.alpha = value * base;
		return value;
	}
	inline function baseAlpha():Float return (game != null) ? game.strumAlphaFor(isPlayer ? 1 : 0) : 1;

	/**
	 * Where the strumline is, like V-Slice's: a place of its own, that scripts move the receptors from (`Constants.STRUMLINE_X_OFFSET`...).
	 * Moving one receptor doesn't move it (scripts spread them out to make room for a lane of their own, and put things in that room
	 * from here). It's worked out from where the receptors are the first time it's needed: the middle of each, where it'd be on V-Slice.
	 */
	public var x(get, set):Float;
	var placeX:Null<Float> = null;
	function get_x():Float
	{
		if(placeX == null) placeX = averagePlace(true);
		return (placeX != null) ? placeX : 0;
	}
	function set_x(value:Float):Float
	{
		if(placeMiddlescroll(value)) return value;

		var change:Float = value - x;
		for (strum in strums)
			if(strum != null) strum.x += change;
		if(strums.length > 0) placeX = value;
		return value;
	}

	// Middlescroll is the engine's, V-Slice has none: its mods' scripts put the strumlines where they go on V-Slice, which for the
	// strumline's own starting place means where middlescroll has it (the player's in the middle, the other one at the sides).
	// The side that isn't played has its receptors split in two there, which only stays that way close to its place: one taken
	// somewhere else (the sides swapped) has them next to each other, like on V-Slice, instead of half of them under the other side's.
	var middleHome:Null<Float> = null;
	var middleOffsets:Array<Float> = null;

	function placeMiddlescroll(value:Float):Bool
	{
		if(!ClientPrefs.data.middleScroll || strums.length < 1 || game == null) return false;

		if(middleHome == null)
		{
			middleHome = x;
			middleOffsets = [for (strum in strums) (strum != null) ? strum.x - middleHome : 0];
		}

		var vsliceStart:Float = funkin.util.Constants.STRUMLINE_X_OFFSET;
		if(isPlayer) vsliceStart += FlxG.width / 2;
		if(Math.abs(value - vsliceStart) < 0.5) value = middleHome;

		var played:Bool = (isPlayer != game.playAsOpponent);
		var split:Bool = !played && Math.abs(value - middleHome) < NOTE_SPACING;
		for (index => strum in strums)
		{
			if(strum == null) continue;
			if(split || played) strum.x = value + ((index < middleOffsets.length) ? middleOffsets[index] : index * NOTE_SPACING);
			else strum.x = value + MIDDLE_X + index * NOTE_SPACING - strum.width / 2;
		}
		placeX = value;
		return true;
	}

	public var y(get, set):Float;
	var placeY:Null<Float> = null;
	function get_y():Float
	{
		if(placeY == null) placeY = averagePlace(false);
		return (placeY != null) ? placeY : 0;
	}
	function set_y(value:Float):Float
	{
		var change:Float = value - y;
		for (strum in strums)
			if(strum != null) strum.y += change;
		if(strums.length > 0) placeY = value;
		return value;
	}

	// The place the receptors' middles say the strumline is at (the average of them, so receptors spread out evenly don't change it)
	function averagePlace(horizontal:Bool):Null<Float>
	{
		var total:Float = 0;
		var count:Int = 0;
		for (index => strum in strums)
		{
			if(strum == null) continue;
			total += horizontal ? (strum.x + strum.width / 2 - index * NOTE_SPACING - MIDDLE_X) : (strum.y + strum.height / 2 - MIDDLE_Y);
			count++;
		}
		return (count > 0) ? total / count : null;
	}

	public function getByIndex(index:Int):StrumNote
	{
		return strums[index];
	}

	public static final KEY_COUNT:Int = 4;
	public static final DIRECTIONS:Array<Int> = [0, 1, 2, 3];
	public static final STRUMLINE_SIZE:Int = 104;
	public static final NOTE_SPACING:Int = 112;
	public static final INITIAL_OFFSET:Float = -0.275 * STRUMLINE_SIZE;

	// V-Slice's receptor is 235x230 at 0.7 (its first frame) from `INITIAL_OFFSET` to the right of its place: where its middle is.
	// (after the values it's made from: the static values are set in the order they're written, before them it's 0)
	static final MIDDLE_X:Float = INITIAL_OFFSET + 235 * 0.7 / 2;
	static final MIDDLE_Y:Float = 230 * 0.7 / 2;

	public var width(get, never):Float;
	function get_width():Float return KEY_COUNT * NOTE_SPACING;

	public var height(get, never):Float;
	function get_height():Float
	{
		var top:Float = Math.POSITIVE_INFINITY;
		var bottom:Float = Math.NEGATIVE_INFINITY;
		for (strum in strums)
		{
			if(strum == null) continue;
			top = Math.min(top, strum.y);
			bottom = Math.max(bottom, strum.y + strum.height);
		}
		return (bottom > top) ? bottom - top : STRUMLINE_SIZE;
	}

	/**
	 * Called with each note of this side when it shows up, for scripts to change it.
	 */
	public var onNoteIncoming(default, null):flixel.util.FlxSignal.FlxTypedSignal<NoteSprite->Void> = new flixel.util.FlxSignal.FlxTypedSignal<NoteSprite->Void>();

	public var length(get, never):Int;
	function get_length():Int return strums.length;

	public function forEach(callback:StrumNote->Void):Void
	{
		for (strum in strums)
			if(strum != null) callback(strum);
	}

	// The receptor of a direction: 0 to 3, or its name
	public function getByDirection(direction:Dynamic):StrumNote
	{
		var index:Int = Std.isOfType(direction, Int) ? direction : ['left', 'down', 'up', 'right'].indexOf(Std.string(direction).toLowerCase());
		return (index >= 0) ? strums[index % KEY_COUNT] : null;
	}

	public var isDownscroll(get, never):Bool;
	function get_isDownscroll():Bool return ClientPrefs.data.downScroll;

	// (V-Slice has one for each side, Psych a single one for the song)
	public var scrollSpeed(get, set):Float;
	function get_scrollSpeed():Float return (game != null) ? game.songSpeed : 1;
	function set_scrollSpeed(value:Float):Float
	{
		if(game != null) game.songSpeed = value;
		return value;
	}

	/**
	 * The long notes of this side that are on the screen, like `notes`.
	 */
	/**
	 * This side's long notes on the screen, one for each whole hold like on V-Slice (Psych makes them out of many pieces).
	 */
	public var holdNotes(get, never):Dynamic;
	function get_holdNotes():Dynamic
	{
		var found:Array<SustainTrail> = [];
		if(game != null && game.notes != null)
			for (note in game.notes.members)
				if(note != null && note.isSustainNote && note.mustPress == isPlayer && note.parent != null)
				{
					var trail:SustainTrail = SustainTrail.get(note.parent);
					if(!found.contains(trail)) found.push(trail);
				}
		return new NoteList(found, () -> holdAlpha, function(value:Float)
		{
			holdAlpha = value;
			applyNoteAlpha(true);
		});
	}

	/**
	 * The cameras the receptors are seen on (the HUD's). Psych's group of one side's receptors isn't drawn itself, they're drawn
	 * as part of the notes' group: its own cameras would be the default ones, the game's.
	 */
	public var cameras(get, set):Array<FlxCamera>;
	var customCameras:Array<FlxCamera> = null;
	function get_cameras():Array<FlxCamera>
	{
		if(customCameras != null) return customCameras;
		if(game != null && game.noteGroup != null) return game.noteGroup.cameras;
		return (game != null) ? [game.camHUD] : [];
	}
	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		customCameras = value;
		for (strum in strums)
			if(strum != null) strum.cameras = value;
		return value;
	}

	public var zIndex:Int = 0;

	// What the receptors do when the keys are used
	public function playStatic(direction:Dynamic):Void playOn(direction, 'static');
	public function playPress(direction:Dynamic):Void playOn(direction, 'pressed');
	public function playConfirm(direction:Dynamic):Void playOn(direction, 'confirm');
	public function holdConfirm(direction:Dynamic):Void playOn(direction, 'confirm');

	function playOn(direction:Dynamic, animation:String):Void
	{
		var strum:StrumNote = getByDirection(direction);
		if(strum != null) strum.playAnim(animation, true);
	}

	/**
	 * The receptors showing up one after the other, like when the countdown starts.
	 */
	public function fadeInArrows():Void
	{
		for (i => strum in strums)
		{
			if(strum == null) continue;

			FlxTween.cancelTweensOf(strum, ['alpha', 'y']);
			var restY:Float = strum.y;
			strum.y -= 10;
			strum.alpha = 0;
			FlxTween.tween(strum, {y: restY, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
		}
	}

	public function fadeOutArrows():Void
	{
		for (strum in strums)
		{
			if(strum == null) continue;

			FlxTween.cancelTweensOf(strum, ['alpha']);
			FlxTween.tween(strum, {alpha: 0}, 0.5, {ease: FlxEase.circOut});
		}
	}

	// ------------------------------------------------------------------------------------------
	// Where the receptors go, and what's played on them
	// ------------------------------------------------------------------------------------------

	/**
	 * How far apart the receptors are, times `NOTE_SPACING` (see `setNoteSpacing()`).
	 */
	public var noteSpacingScale(default, null):Float = 1;

	// (what V-Slice makes the receptors smaller with on phones, and its time to tap without a note there: nothing here)
	public var strumlineScale(default, null):FlxPoint = FlxPoint.get(1, 1);
	public var ghostTapTimer:Float = 0;

	function directionIndex(direction:Dynamic):Int
	{
		var index:Int = Std.isOfType(direction, Int) ? direction : ['left', 'down', 'up', 'right'].indexOf(Std.string(direction).toLowerCase());
		return (index >= 0) ? index % KEY_COUNT : 0;
	}

	/**
	 * Where the receptor of a direction goes, from the receptors' place (`strumlineNotes.x`), like V-Slice's.
	 */
	public function getXPos(direction:Dynamic):Float
		return directionIndex(direction) * NOTE_SPACING * noteSpacingScale;

	/**
	 * Puts the receptors that many times `NOTE_SPACING` apart, from their place.
	 */
	public function setNoteSpacing(multiplier:Float = 1):Void
	{
		noteSpacingScale = multiplier;

		var group:objects.StrumGroup = Std.downcast(strumlineNotes, objects.StrumGroup);
		if(group == null) return;
		for (index => strum in strums)
		{
			if(strum == null) continue;
			strum.x = group.x + getXPos(index) + INITIAL_OFFSET;
			strum.y = group.y;
			if(noteStyle != null) noteStyle.applyStrumlineOffsets(strum);
		}
	}

	/**
	 * A splash on the receptor of a direction, of the side's note style.
	 */
	public function playNoteSplash(direction:Dynamic):Void
	{
		var strum:StrumNote = getByDirection(direction);
		if(strum == null || game == null) return;
		if(noteStyle != null && !noteStyle.isNoteSplashEnabled()) return;

		game.spawnNoteSplash(strum.psychX, strum.psychY, strum.noteDirection, null, strum, (noteStyle != null) ? noteStyle.getSplashTexture() : null);
	}

	/**
	 * The cover of a long note being held, on its receptor.
	 */
	public function playNoteHoldCover(holdNote:Dynamic):Void
	{
		var trail:SustainTrail = Std.downcast(holdNote, SustainTrail);
		if(trail == null || game == null || game.grpHoldCovers == null) return;
		game.grpHoldCovers.noteHit(trail.parentNote, getByDirection(trail.noteDirection), isPlayer);
	}

	// ------------------------------------------------------------------------------------------
	// The side's note style
	// ------------------------------------------------------------------------------------------

	/**
	 * The note style of this side's receptors, notes and splashes: the song's, until a script gives it another one (V-Slice's mods
	 * change it in the middle of a song), which gives them its look.
	 */
	public var noteStyle(get, set):funkin.play.notes.notestyle.NoteStyle;
	var currentStyle:funkin.play.notes.notestyle.NoteStyle = null;
	function get_noteStyle():funkin.play.notes.notestyle.NoteStyle
	{
		if(currentStyle == null) currentStyle = songStyle();
		return currentStyle;
	}
	function set_noteStyle(value:funkin.play.notes.notestyle.NoteStyle):funkin.play.notes.notestyle.NoteStyle
	{
		if(value == null || value == currentStyle) return value;
		currentStyle = value;
		applyNoteStyle();
		return value;
	}

	static function songStyle():funkin.play.notes.notestyle.NoteStyle
	{
		var song:backend.Song.SwagSong = states.PlayState.SONG;
		var id:String = (song != null && song.vslice != null && song.vslice.noteStyle != null) ? Std.string(song.vslice.noteStyle) : 'funkin';
		var style:funkin.play.notes.notestyle.NoteStyle = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry(id);
		if(style == null) style = funkin.data.notestyle.NoteStyleRegistry.instance.fetchEntry('funkin');
		return style;
	}

	/**
	 * Gives the side's receptors, its notes (the ones on the screen and the ones to come) and their splashes the look of its note style.
	 * What the style draws like the base game's style keeps the engine's own look.
	 */
	public function applyNoteStyle():Void
	{
		styleReceptors();

		var style:funkin.play.notes.notestyle.NoteStyle = noteStyle;
		if(game == null || style == null) return;

		if(game.grpHoldCovers != null) game.grpHoldCovers.setNoteStyle(isPlayer, style.id);

		var ownNotes:Bool = style.usesEngineLook('note');
		var ownHolds:Bool = style.usesEngineLook('holdNote');
		var splash:String = style.getSplashTexture();
		var splashes:Bool = style.isNoteSplashEnabled();
		for (list in [game.unspawnNotes, (game.notes != null) ? game.notes.members : []])
		{
			for (note in list)
			{
				if(note == null || note.mustPress != isPlayer) continue;

				note.noteSplashData.texture = splash; //(null is the engine's own)

				// (only the splashes a style turned off are turned on again by another)
				if(!splashes && !note.noteSplashData.disabled)
				{
					note.noteSplashData.disabled = true;
					note.extraData.set('styleNoSplash', true);
				}
				else if(splashes && note.extraData.exists('styleNoSplash'))
				{
					note.noteSplashData.disabled = false;
					note.extraData.remove('styleNoSplash');
				}

				// notes of a kind that has a style of its own keep it
				#if HSCRIPT_ALLOWED
				if(backend.VSliceScripts.hasKindStyle(note)) continue;
				#end

				if(note.isSustainNote ? ownHolds : ownNotes) note.restoreEngineLook();
				else style.applyToNote(note);
			}
		}
	}

	/**
	 * Gives the side's receptors the look of its note style.
	 */
	public function styleReceptors():Void
	{
		var style:funkin.play.notes.notestyle.NoteStyle = noteStyle;
		if(style == null) return;

		var own:Bool = style.usesEngineLook('noteStrumline');
		for (strum in strums)
		{
			if(strum == null) continue;
			if(own) strum.restoreEngineLook();
			else style.applyToStrum(strum);
		}
	}

	public function toString():String
	{
		return 'Strumline(' + (isPlayer ? 'player' : 'opponent') + ')';
	}
}

/**
 * A list of notes scripts can use like the group V-Slice keeps them in: `members`, `length`, `for (note in list)`, `forEach()`
 * and an `alpha` for all of them (which is kept by whoever made the list: the list itself is made again every time it's asked for).
 */
@:keep
class NoteList
{
	public var members:Array<Dynamic>;
	public var length(get, never):Int;
	function get_length():Int return members.length;

	var readAlpha:Void->Float;
	var writeAlpha:Float->Void;

	public function new(members:Array<Dynamic>, ?readAlpha:Void->Float, ?writeAlpha:Float->Void)
	{
		this.members = members;
		this.readAlpha = readAlpha;
		this.writeAlpha = writeAlpha;
	}

	public var alpha(get, set):Float;
	function get_alpha():Float return (readAlpha != null) ? readAlpha() : 1;
	function set_alpha(value:Float):Float
	{
		if(writeAlpha != null) writeAlpha(value);
		return value;
	}

	// (a list can have a visibility of its own instead of going by its alpha, like the receptors')
	public var readVisible:Void->Bool = null;
	public var writeVisible:Bool->Void = null;

	public var visible(get, set):Bool;
	function get_visible():Bool return (readVisible != null) ? readVisible() : alpha > 0;
	function set_visible(value:Bool):Bool
	{
		if(writeVisible != null) writeVisible(value);
		else alpha = value ? 1 : 0;
		return value;
	}

	public function iterator():Iterator<Dynamic>
	{
		return members.iterator();
	}

	public function forEach(func:Dynamic->Void, recurse:Bool = false):Void
	{
		for (member in members)
			if(member != null)
				func(member);
	}

	public function forEachAlive(func:Dynamic->Void, recurse:Bool = false):Void
	{
		forEach(func, recurse);
	}

	/**
	 * Takes the splashes and the hold covers of the list off the screen (scripts do it before changing the note style, for new ones
	 * to be made). The notes themselves are left alone.
	 */
	public function clear():Void
	{
		for (member in members)
			if(Std.isOfType(member, flixel.FlxBasic))
				cast(member, flixel.FlxBasic).kill();
	}
}
