package objects.freeplay;

import backend.FreeplayData;

import flixel.addons.effects.FlxTrail;
import flixel.math.FlxRect;

import objects.HealthIcon;

import openfl.display.BlendMode;
import openfl.filters.BitmapFilterQuality;
import openfl.filters.GlowFilter;

import shaders.FreeplayShaders.GaussianBlurShader;

/**
 * A song of the V-Slice Freeplay menu: the capsule with its name, icon, BPM, difficulty rating, rank and favorite heart.
 *
 * The menu only keeps the capsules that fit on the screen and gives them other songs as the list scrolls,
 * instead of having one for every song like V-Slice does: with a lot of mods that would be thousands of sprites.
 */
class FreeplayCapsule extends FlxSpriteGroup
{
	public static inline final REAL_SCALE:Float = 0.8;

	public var capsule:FlxSprite;

	/**
	 * The song being shown, null for the "Random" option.
	 */
	public var song(default, null):FreeplaySong = null;

	// The same, by the name V-Slice scripts know it
	public var freeplayData(get, never):FreeplaySong;
	function get_freeplayData():FreeplaySong return song;

	/**
	 * Position on the menu's list, 0 being "Random".
	 */
	public var songIndex:Int = -1;

	public var selected(default, set):Bool = false;

	public var favIconBlurred:FlxSprite;
	public var favIcon:FlxSprite;
	public var ranking:CapsuleRank;
	public var blurredRanking:CapsuleRank;
	public var fakeRanking:CapsuleRank;
	public var fakeBlurredRanking:CapsuleRank;
	public var sparkle:FlxSprite;
	public var newText:FlxSprite;

	public var targetPos:FlxPoint = new FlxPoint();
	public var doLerp:Bool = false;
	public var doJumpIn:Bool = false;
	public var doJumpOut:Bool = false;
	public var hasTrail:Bool = false;

	/**
	 * The menu's selected position, the capsule finds its place from it when it jumps in.
	 */
	public var curSelected:Int = 0;

	var songText:CapsuleText;
	var pixelIcon:FlxSprite;
	var healthIcon:HealthIcon;
	var curIcon:String = null;

	var bpmText:FlxSprite;
	var difficultyText:FlxSprite;
	var weekText:FlxText;
	var difficultyNumbers:Array<CapsuleNumber> = []; //the big ones
	var bpmNumbers:Array<CapsuleNumber> = []; //the small ones

	var hideGroup:Array<FlxSprite> = []; //what shows up a bit after the capsule itself when it jumps in
	var iconVisible:Bool = false;

	var sparkleTimer:FlxTimer = null;
	var jumpTimers:Array<FlxTimer> = [];
	var impactThing:FlxSprite = null;
	var evilTrail:FlxTrail = null;

	public function new(style:FreeplayStyle, blurShader:GaussianBlurShader)
	{
		super(0, 0);

		var antialias:Bool = ClientPrefs.data.antialiasing;

		capsule = new FlxSprite();
		capsule.frames = Paths.getSparrowAtlas(style.capsuleAsset);
		capsule.animation.addByPrefix('selected', 'mp3 capsule w backing0', 24);
		capsule.animation.addByPrefix('unselected', 'mp3 capsule w backing NOT SELECTED', 24);
		capsule.animation.play('unselected');
		capsule.antialiasing = antialias;
		add(capsule);

		bpmText = new FlxSprite(144, 87).loadGraphic(Paths.image('freeplay/freeplayCapsule/bpmtext'));
		bpmText.setGraphicSize(Std.int(bpmText.width * 0.9));
		bpmText.antialiasing = antialias;
		add(bpmText);

		difficultyText = new FlxSprite(414, 87).loadGraphic(Paths.image('freeplay/freeplayCapsule/difficultytext'));
		difficultyText.setGraphicSize(Std.int(difficultyText.width * 0.9));
		difficultyText.antialiasing = antialias;
		add(difficultyText);

		weekText = new FlxText(291, 88, 0, '', 20);
		weekText.setFormat(Paths.font('YoureGone-Regular.otf'), 20, 0xFF21242E);
		weekText.scale.set(0.9, 0.9);
		weekText.antialiasing = antialias;
		weekText.visible = false;
		weekText.active = false;
		add(weekText);

		// "NEW" on the songs whose script says so (V-Slice's `Song.isSongNew()`)
		newText = new FlxSprite(454, 9);
		newText.frames = Paths.getSparrowAtlas('freeplay/freeplayCapsule/new');
		newText.animation.addByPrefix('newAnim', 'NEW notif', 24, true);
		newText.animation.play('newAnim', true);
		newText.setGraphicSize(Std.int(newText.width * 0.9));
		newText.antialiasing = antialias;
		newText.visible = false;
		add(newText);

		for (i in 0...2)
		{
			var number:CapsuleNumber = new CapsuleNumber(466 + (i * 30), 32, true);
			add(number);
			difficultyNumbers.push(number);
		}

		for (i in 0...3)
		{
			var number:CapsuleNumber = new CapsuleNumber(185 + (i * 11), 88.5, false);
			add(number);
			bpmNumbers.push(number);
		}

		fakeRanking = new CapsuleRank(420, 41);
		add(fakeRanking);

		fakeBlurredRanking = new CapsuleRank(fakeRanking.x, fakeRanking.y);
		fakeBlurredRanking.shader = blurShader;
		add(fakeBlurredRanking);

		ranking = new CapsuleRank(420, 41);
		add(ranking);

		blurredRanking = new CapsuleRank(ranking.x, ranking.y);
		blurredRanking.shader = blurShader;
		add(blurredRanking);

		sparkle = new FlxSprite(ranking.x, ranking.y);
		sparkle.frames = Paths.getSparrowAtlas('freeplay/sparkle');
		sparkle.animation.addByPrefix('sparkle', 'sparkle Export0', 24, false);
		sparkle.animation.play('sparkle', true);
		sparkle.scale.set(0.8, 0.8);
		sparkle.blend = BlendMode.ADD;
		sparkle.antialiasing = antialias;
		sparkle.visible = false;
		sparkle.alpha = 0.7;
		add(sparkle);

		songText = new CapsuleText(capsule.width * 0.26, 45, 'Random', Std.int(40 * REAL_SCALE), blurShader);
		songText.applyStyle(style);
		add(songText);
		hideGroup.push(songText);

		pixelIcon = new FlxSprite(160, 35);
		pixelIcon.makeGraphic(32, 32, FlxColor.TRANSPARENT);
		pixelIcon.antialiasing = false;
		pixelIcon.visible = false;
		add(pixelIcon);

		// for the songs whose opponent doesn't have a pixel icon
		healthIcon = new HealthIcon('face');
		healthIcon.scrollFactor.set(1, 1);
		healthIcon.scale.set(0.6, 0.6);
		healthIcon.setPosition(35, -13);
		healthIcon.visible = false;
		add(healthIcon);

		favIconBlurred = makeHeart();
		favIconBlurred.shader = blurShader;
		add(favIconBlurred);

		favIcon = makeHeart();
		add(favIcon);

		setVisibleGroup(false);
	}

	function makeHeart():FlxSprite
	{
		var heart:FlxSprite = new FlxSprite(380, 40);
		heart.frames = Paths.getSparrowAtlas('freeplay/favHeart');
		heart.animation.addByPrefix('fav', 'favorite heart', 24, false);
		heart.animation.play('fav');
		heart.setGraphicSize(50, 50);
		heart.blend = BlendMode.ADD;
		heart.antialiasing = ClientPrefs.data.antialiasing;
		heart.visible = false;
		return heart;
	}

	// ------------------------------------------------------------------------------------------
	// Song data
	// ------------------------------------------------------------------------------------------

	/**
	 * Gives the capsule another song to show.
	 */
	public function init(song:FreeplaySong, songIndex:Int, difficulty:String):Void
	{
		this.song = song;
		this.songIndex = songIndex;

		clearUpTrail();
		hasTrail = false;
		fakeRanking.visible = false;
		fakeBlurredRanking.visible = false;
		angle = 0;

		favIcon.animation.play('fav', true);
		favIconBlurred.animation.play('fav', true);
		favIcon.animation.finish();
		favIconBlurred.animation.finish();

		// (each capsule's "NEW" is a little further along than the one above, like on V-Slice)
		if(newText.animation.curAnim != null && newText.animation.curAnim.numFrames > 0)
			newText.animation.curAnim.curFrame = (45 - ((songIndex * 4) % 45)) % newText.animation.curAnim.numFrames;

		refreshDisplay(difficulty);
	}

	public function refreshDisplay(difficulty:String, updateRank:Bool = true):Void
	{
		// "Random" is just the capsule and its name
		var hasSong:Bool = (song != null);
		bpmText.visible = hasSong;
		difficultyText.visible = hasSong;
		for (number in bpmNumbers) number.visible = hasSong;
		for (number in difficultyNumbers) number.visible = hasSong;

		if(song == null)
		{
			songText.text = 'Random';
			pixelIcon.visible = false;
			healthIcon.visible = false;
			weekText.visible = false;
			favIcon.visible = false;
			favIconBlurred.visible = false;
			newText.visible = false;
			if(updateRank) updateScoringRank(null);
		}
		else
		{
			songText.text = song.displayName;
			setIcon(song);
			updateBPM(Std.int(song.bpm));
			updateDifficultyRating(song.rating);
			if(updateRank) updateScoringRank(song.getRank(difficulty));

			weekText.text = song.levelName;
			weekText.visible = (song.levelName.length > 0);
			weekText.clipRect = (weekText.width > 130) ? new FlxRect(0, 0, 130, weekText.height) : null;

			favIcon.visible = song.isFavorite();
			favIconBlurred.visible = favIcon.visible;
			newText.visible = song.isNew(difficulty);
			checkClip();
		}
		updateSelected();
	}

	function setIcon(song:FreeplaySong):Void
	{
		var key:String = song.folder + ':' + song.opponent + ':' + song.icon;
		if(key != curIcon)
		{
			curIcon = key;
			FreeplayData.withMod(song.folder, function()
			{
				loadIcon(song);
				return null;
			});
		}

		// the song's text and icon stay hidden for a moment when the capsule jumps in
		pixelIcon.visible = (iconVisible && pixelIcon.ID == 1);
		healthIcon.visible = (iconVisible && pixelIcon.ID == 0);
	}

	function loadIcon(song:FreeplaySong):Void
	{
		// Same search V-Slice does: "freeplay/icons/(character)pixel", trying the character's name without its last parts too
		var iconName:String = '';
		var validName:String = null;
		var character:String = (song.opponent == 'parents') ? 'parents-christmas' : song.opponent;
		var parts:Array<String> = character.split('-');
		for (i in 0...parts.length)
		{
			iconName += parts[i];
			if(Paths.fileExists('images/freeplay/icons/${iconName}pixel.png', IMAGE)) validName = iconName;
			if(i < parts.length - 1) iconName += '-';
		}

		if(validName == null)
		{
			// no pixel icon, the opponent's health icon is used instead
			pixelIcon.ID = 0;
			healthIcon.changeIcon(song.icon);
			healthIcon.scale.set(0.6, 0.6);
			return;
		}

		pixelIcon.ID = 1;

		var path:String = 'freeplay/icons/${validName}pixel';
		var isAnimated:Bool = Paths.fileExists('images/$path.xml', TEXT);
		if(isAnimated) pixelIcon.frames = Paths.getSparrowAtlas(path);
		else pixelIcon.loadGraphic(Paths.image(path));

		pixelIcon.scale.set(2, 2);
		pixelIcon.origin.x = switch(character)
		{
			case 'parents-christmas': 140;
			case 'sserafim-kazuha': 195;
			default: 100;
		}

		pixelIcon.active = isAnimated;
		if(isAnimated)
		{
			pixelIcon.animation.addByPrefix('idle', 'idle0', 10, true);
			pixelIcon.animation.addByPrefix('confirm', 'confirm0', 10, false);
			pixelIcon.animation.addByPrefix('confirm-hold', 'confirm-hold0', 10, true);
			pixelIcon.animation.finishCallback = function(name:String)
			{
				if(name == 'confirm' && pixelIcon.animation.exists('confirm-hold')) pixelIcon.animation.play('confirm-hold');
			}
			pixelIcon.animation.play('idle');
		}
	}

	/**
	 * Clips the song's name so it doesn't go under the rank and the heart when they're there.
	 */
	public function checkClip():Void
	{
		var clipSize:Int = 290;
		var clipType:Int = 0;

		if(ranking.visible || fakeRanking.visible)
		{
			favIconBlurred.x = this.x + 370;
			favIcon.x = favIconBlurred.x;
			clipType++;
		}
		else favIconBlurred.x = favIcon.x = this.x + 405;

		if(favIcon.visible) clipType++;

		switch(clipType)
		{
			case 2: clipSize = 210;
			case 1: clipSize = 245;
		}
		songText.clipWidth = clipSize;
	}

	function updateBPM(newBPM:Int):Void
	{
		if(newBPM < 0) newBPM = 0;
		if(newBPM > 999) newBPM = 999;

		var shiftX:Float = (Math.floor(newBPM / 100) == 1) ? 186 : 191;
		var tempShift:Float = 0;

		for (i in 0...bpmNumbers.length)
		{
			bpmNumbers[i].x = this.x + (shiftX + (i * 11));
			switch(i)
			{
				case 0:
					bpmNumbers[i].digit = Math.floor(newBPM / 100) % 10;
				case 1:
					bpmNumbers[i].digit = Math.floor(newBPM / 10) % 10;
					if(newBPM >= 10 && Math.floor(newBPM / 10) % 10 == 1) tempShift = -4;
				default:
					bpmNumbers[i].digit = newBPM % 10;
					if(newBPM % 10 == 1) tempShift -= 4;
			}
			bpmNumbers[i].x += tempShift;
		}
	}

	function updateDifficultyRating(newRating:Int):Void
	{
		if(newRating < 0) newRating = 0;
		if(newRating > 99) newRating = 99;

		difficultyNumbers[0].digit = Math.floor(newRating / 10);
		difficultyNumbers[1].digit = newRating % 10;
	}

	function updateScoringRank(newRank:Null<FreeplayRank>):Void
	{
		if(sparkleTimer != null) sparkleTimer.cancel();
		sparkle.visible = false;

		ranking.rank = newRank;
		blurredRanking.rank = newRank;

		if(newRank != null && newRank == FreeplayRank.PERFECT_GOLD)
		{
			sparkleTimer = new FlxTimer().start(1, sparkleEffect);
			sparkle.visible = true;
		}
	}

	function sparkleEffect(timer:FlxTimer):Void
	{
		sparkle.setPosition(FlxG.random.float(ranking.x - 20, ranking.x + 3), FlxG.random.float(ranking.y - 29, ranking.y + 4));
		sparkle.animation.play('sparkle', true);
		sparkleTimer = new FlxTimer().start(FlxG.random.float(1.2, 4.5), sparkleEffect);
	}

	// ------------------------------------------------------------------------------------------
	// Rank animation
	// ------------------------------------------------------------------------------------------

	function clearUpTrail():Void
	{
		if(impactThing != null)
		{
			FlxTween.cancelTweensOf(impactThing);
			FlxTween.cancelTweensOf(impactThing.scale);
			remove(impactThing, true);
			impactThing.destroy();
			impactThing = null;
		}
		if(evilTrail != null)
		{
			FlxTween.cancelTweensOf(evilTrail);
			remove(evilTrail, true);
			evilTrail.destroy();
			evilTrail = null;
		}
	}

	/**
	 * The capsule's shape bursting out of it with the rank's color.
	 */
	public function fadeAnim(rank:Null<FreeplayRank>):FlxColor
	{
		clearUpTrail();
		hasTrail = true;

		var color:FlxColor = (rank != null) ? rank.getColor() : FlxColor.WHITE;

		impactThing = new FlxSprite(0, 0);
		impactThing.frames = capsule.frames;
		impactThing.frame = capsule.frame;
		impactThing.updateHitbox();
		impactThing.alpha = 0;
		impactThing.antialiasing = capsule.antialiasing;
		insert(0, impactThing);
		FlxTween.tween(impactThing.scale, {x: 2.5, y: 2.5}, 0.5);

		evilTrail = new FlxTrail(impactThing, null, 15, 2, 0.35, 0.025);
		evilTrail.blend = BlendMode.ADD;
		evilTrail.color = color;
		insert(0, evilTrail);
		FlxTween.tween(evilTrail, {alpha: 0}, 0.6, {
			ease: FlxEase.quadOut,
			onComplete: function(_)
			{
				clearUpTrail();
				hasTrail = false;
			}
		});
		return color;
	}

	// ------------------------------------------------------------------------------------------
	// Movement
	// ------------------------------------------------------------------------------------------

	function textAppear():Void
	{
		songText.scale.x = 1.7;
		songText.scale.y = 0.2;

		jumpTimers.push(new FlxTimer().start(1 / 24, function(_)
		{
			songText.scale.x = 0.4;
			songText.scale.y = 1.4;
			jumpTimers.push(new FlxTimer().start(2 / 24, function(_) songText.scale.x = songText.scale.y = 1));
		}));
	}

	function setVisibleGroup(value:Bool):Void
	{
		for (sprite in hideGroup)
			sprite.visible = value;

		iconVisible = value;
		pixelIcon.visible = (value && song != null && pixelIcon.ID == 1);
		healthIcon.visible = (value && song != null && pixelIcon.ID == 0);

		textAppear();
		updateSelected();
	}

	function cancelJumpTimers():Void
	{
		for (timer in jumpTimers)
			timer.cancel();
		jumpTimers = [];
	}

	static final xFrames:Array<Float> = [1.7, 1.8, 0.85, 0.85, 0.97, 0.97, 1];
	static final xPosOutLerp:Array<Float> = [0.245, 0.75, 0.98, 0.98, 1.2];

	var frameInTicker:Float = 0;
	var frameInTypeBeat:Int = 0;
	var frameOutTicker:Float = 0;
	var frameOutTypeBeat:Int = 0;

	/**
	 * Makes the capsule jump into its place from the right, stretching on the way.
	 *
	 * @param force 	Show the song's name right away instead of a bit later.
	 */
	public function initJumpIn(force:Bool = false):Void
	{
		cancelJumpTimers();
		frameInTypeBeat = 0;
		frameInTicker = 0;
		frameOutTypeBeat = 0;
		doJumpOut = false;
		doJumpIn = true;
		doLerp = true;

		visible = true;
		capsule.alpha = force ? 1 : 0.5;

		if(force) setVisibleGroup(true);
		else
		{
			setVisibleGroup(false);
			jumpTimers.push(new FlxTimer().start((xFrames.length / 24) * 2.5, function(_)
			{
				visible = true;
				capsule.alpha = 1;
				setVisibleGroup(true);
			}));
		}
	}

	/**
	 * Puts the capsule on its place without any animation.
	 */
	public function forcePosition():Void
	{
		cancelJumpTimers();
		visible = true;
		capsule.alpha = 1;
		doLerp = true;
		doJumpIn = false;
		doJumpOut = false;

		frameInTypeBeat = xFrames.length;
		frameOutTypeBeat = 0;

		capsule.scale.set(REAL_SCALE, REAL_SCALE);

		x = targetPos.x;
		y = targetPos.y;

		setVisibleGroup(true);
	}

	public function jumpOut():Void
	{
		cancelJumpTimers();
		doJumpIn = false;
		doLerp = false;
		doJumpOut = true;
		frameOutTypeBeat = 0;
		frameOutTicker = 0;
	}

	override function update(elapsed:Float):Void
	{
		if(impactThing != null) impactThing.angle = capsule.angle;

		if(doJumpIn)
		{
			frameInTicker += elapsed;

			if(frameInTicker >= 1 / 24 && frameInTypeBeat < xFrames.length)
			{
				frameInTicker = 0;

				capsule.scale.x = xFrames[frameInTypeBeat] * REAL_SCALE;
				capsule.scale.y = (1 / xFrames[frameInTypeBeat]) * REAL_SCALE;
				targetPos.x = intendedX(songIndex + 1 - curSelected);

				frameInTypeBeat++;
			}
			else if(frameInTypeBeat >= xFrames.length) doJumpIn = false;
		}

		if(doJumpOut)
		{
			frameOutTicker += elapsed;

			if(frameOutTicker >= 1 / 24 && frameOutTypeBeat < xFrames.length)
			{
				frameOutTicker = 0;

				capsule.scale.x = xFrames[frameOutTypeBeat] * REAL_SCALE;
				capsule.scale.y = (1 / xFrames[frameOutTypeBeat]) * REAL_SCALE;
				x = FlxG.width * xPosOutLerp[Std.int(Math.min(frameOutTypeBeat, xPosOutLerp.length - 1))];

				frameOutTypeBeat++;
			}
			else if(frameOutTypeBeat >= xFrames.length) doJumpOut = false;
		}

		if(doLerp)
		{
			x = smoothLerp(x, targetPos.x, elapsed, 0.256);
			y = smoothLerp(y, targetPos.y, elapsed, 0.192);
		}

		super.update(elapsed);
	}

	// Gets within 1% of the target in `duration` seconds, no matter the framerate
	inline static function smoothLerp(base:Float, target:Float, elapsed:Float, duration:Float):Float
	{
		return (elapsed <= 0 || base == target) ? base : FlxMath.lerp(target, base, Math.pow(1 / 100, elapsed / duration));
	}

	/**
	 * Plays the animations of when the song is picked.
	 */
	public function confirm():Void
	{
		textAppear();
		songText.flickerText();

		if(pixelIcon.visible && pixelIcon.animation.exists('confirm')) pixelIcon.animation.play('confirm');
	}

	// The list bends a little, like a wave
	public static function intendedX(index:Float):Float
	{
		return 270 + (60 * FlxMath.fastSin(index));
	}

	public function intendedY(index:Float):Float
	{
		return (index * ((capsule.height * REAL_SCALE) + 10)) + 120;
	}

	function set_selected(value:Bool):Bool
	{
		var wasSelected:Bool = selected;
		selected = value;
		if(wasSelected != value) updateSelected();
		return value;
	}

	public function updateSelected():Void
	{
		songText.alpha = selected ? 1 : 0.6;
		songText.blurredText.visible = selected;
		capsule.offset.x = selected ? 0 : -5;
		capsule.animation.play(selected ? 'selected' : 'unselected');
		ranking.alpha = selected ? 1 : 0.7;
		favIcon.alpha = selected ? 1 : 0.6;
		favIconBlurred.alpha = selected ? 1 : 0;
		ranking.color = selected ? 0xFFFFFFFF : 0xFFAAAAAA;

		if(songText.tooLong) songText.resetText();
		if(selected && songText.tooLong) songText.initMove();
	}

	override function kill():Void
	{
		super.kill();

		cancelJumpTimers();
		if(sparkleTimer != null) sparkleTimer.cancel();
		songText.resetText();
		clearUpTrail();
		hasTrail = false;
		selected = false;
		doLerp = false;
		doJumpIn = false;
		doJumpOut = false;
	}

	override function destroy():Void
	{
		cancelJumpTimers();
		if(sparkleTimer != null) sparkleTimer.cancel();
		super.destroy();
	}
}

/**
 * The song's name, with a glow around it and scrolling sideways when it's too long to fit.
 */
class CapsuleText extends FlxSpriteGroup
{
	public var blurredText:FlxText;
	public var text(default, set):String;
	public var clipWidth(default, set):Int = 255;
	public var tooLong:Bool = false;

	var whiteText:FlxText;
	var glowColor:FlxColor = 0xFF00CCFF;

	var moveTimer:FlxTimer = new FlxTimer();
	var moveTween:FlxTween = null;
	var flickerTimer:FlxTimer = null;
	var flickerState:Bool = false;

	public function new(x:Float, y:Float, songTitle:String, size:Int, blurShader:GaussianBlurShader)
	{
		super(x, y);

		blurredText = makeText(songTitle, size);
		blurredText.shader = blurShader;
		whiteText = makeText(songTitle, size);
		text = songTitle;

		blurredText.color = glowColor;
		whiteText.color = 0xFFFFFFFF;
		add(blurredText);
		add(whiteText);
	}

	static function makeText(songTitle:String, size:Int):FlxText
	{
		var text:FlxText = new FlxText(0, 0, 0, songTitle, size);
		text.font = Paths.font('5by7.ttf');
		text.antialiasing = ClientPrefs.data.antialiasing;
		return text;
	}

	public function applyStyle(style:FreeplayStyle):Void
	{
		glowColor = style.capsuleTextColors[1];
		blurredText.color = glowColor;
		setGlow(glowColor);
	}

	function setGlow(color:FlxColor):Void
	{
		whiteText.textField.filters = [new GlowFilter(color.to24Bit(), 1, 5, 5, 210, BitmapFilterQuality.MEDIUM)];

		// the filter only shows up when the text is drawn again
		@:privateAccess
		whiteText._regen = true;
	}

	function set_clipWidth(value:Int):Int
	{
		resetText();
		checkClipWidth(value);
		return clipWidth = value;
	}

	function checkClipWidth(?clip:Int):Void
	{
		if(clip == null) clip = clipWidth;
		if(whiteText == null || blurredText == null) return;

		if(whiteText.width > clip)
		{
			tooLong = true;
			blurredText.clipRect = new FlxRect(0, 0, clip, blurredText.height);
			whiteText.clipRect = new FlxRect(0, 0, clip, whiteText.height);
		}
		else
		{
			tooLong = false;
			blurredText.clipRect = null;
			whiteText.clipRect = null;
		}
	}

	function set_text(value:String):String
	{
		if(value == null) return value;
		if(blurredText == null || whiteText == null) return text = value;
		if(value == text) return value;

		blurredText.text = value;
		whiteText.text = value;
		checkClipWidth();
		setGlow(glowColor);

		return text = value;
	}

	/**
	 * Starts scrolling the name from side to side, for names that don't fit.
	 */
	public function initMove():Void
	{
		moveTimer.start(0.6, function(_) moveText(whiteText.width - clipWidth));
	}

	function moveText(target:Float):Void
	{
		moveTween = FlxTween.tween(whiteText.offset, {x: target}, 2, {
			ease: FlxEase.sineInOut,
			onUpdate: function(_)
			{
				whiteText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, whiteText.height);
				blurredText.offset.x = whiteText.offset.x;
				blurredText.clipRect = new FlxRect(whiteText.offset.x, 0, clipWidth, blurredText.height);
			},
			onComplete: function(_)
			{
				moveTimer.start(0.3, function(_) moveText((target > 0) ? 0 : whiteText.width - clipWidth));
			}
		});
	}

	public function resetText():Void
	{
		scale.set(1, 1);
		if(moveTween != null) moveTween.cancel();
		if(moveTimer != null) moveTimer.cancel();
		if(whiteText == null || blurredText == null) return;

		whiteText.offset.x = 0;
		blurredText.offset.x = 0;
		if(tooLong)
		{
			whiteText.clipRect = new FlxRect(0, 0, clipWidth, whiteText.height);
			blurredText.clipRect = new FlxRect(0, 0, clipWidth, blurredText.height);
		}
	}

	/**
	 * Flashes the name, for when the song is picked.
	 */
	public function flickerText():Void
	{
		resetText();
		if(flickerTimer != null) flickerTimer.cancel();
		flickerTimer = new FlxTimer().start(1 / 24, flickerProgress, 19);
	}

	function flickerProgress(timer:FlxTimer):Void
	{
		if(flickerState)
		{
			whiteText.blend = BlendMode.ADD;
			blurredText.blend = BlendMode.ADD;
			blurredText.color = 0xFFFFFFFF;
			whiteText.color = 0xFFFFFFFF;
			setGlow(0xFFFFFFFF);
		}
		else
		{
			blurredText.color = glowColor;
			whiteText.color = 0xFFDDDDDD;
			setGlow(0xFFDDDDDD);
		}
		flickerState = !flickerState;
	}

	override function destroy():Void
	{
		if(moveTween != null) moveTween.cancel();
		if(moveTimer != null) moveTimer.cancel();
		if(flickerTimer != null) flickerTimer.cancel();
		super.destroy();
	}
}

/**
 * Badge with the rank the player got on the song.
 */
class CapsuleRank extends FlxSprite
{
	public var rank(default, set):Null<FreeplayRank> = null;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('freeplay/rankbadges');
		animation.addByPrefix('PERFECT', 'PERFECT rank0', 24, false);
		animation.addByPrefix('EXCELLENT', 'EXCELLENT rank0', 24, false);
		animation.addByPrefix('GOOD', 'GOOD rank0', 24, false);
		animation.addByPrefix('PERFECTSICK', 'PERFECT rank GOLD', 24, false);
		animation.addByPrefix('GREAT', 'GREAT rank0', 24, false);
		animation.addByPrefix('LOSS', 'LOSS rank0', 24, false);

		blend = BlendMode.ADD;
		antialiasing = ClientPrefs.data.antialiasing;
		rank = null;

		scale.set(0.9, 0.9);
		updateHitbox();
	}

	function set_rank(value:Null<FreeplayRank>):Null<FreeplayRank>
	{
		rank = value;
		if(value == null)
		{
			visible = false;
			return value;
		}

		visible = true;
		animation.play(value.getAnimation(), true);
		centerOffsets(false);

		if(value == FreeplayRank.GOOD || value == FreeplayRank.GREAT) offset.y -= 8;
		updateHitbox();
		return value;
	}
}

/**
 * A digit of the song's BPM (the small ones) or of its difficulty rating (the big ones).
 */
class CapsuleNumber extends FlxSprite
{
	static final numToString:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];

	public var digit(default, set):Int = 0;

	public function new(x:Float, y:Float, big:Bool = false)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas(big ? 'freeplay/freeplayCapsule/bignumbers' : 'freeplay/freeplayCapsule/smallnumbers');
		for (name in numToString)
			animation.addByPrefix(name, name, 24, false);

		antialiasing = ClientPrefs.data.antialiasing;
		digit = 0;

		setGraphicSize(Std.int(width * 0.9));
		updateHitbox();
	}

	function set_digit(value:Int):Int
	{
		if(value < 0 || value > 9) value = 0;

		animation.play(numToString[value], true, false, 0);
		centerOffsets(false);

		switch(value)
		{
			case 1: offset.x -= 4;
			case 3: offset.x -= 1;
		}
		return digit = value;
	}
}
