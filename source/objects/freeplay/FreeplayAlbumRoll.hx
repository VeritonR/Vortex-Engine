package objects.freeplay;

import backend.FreeplayData;

import objects.freeplay.ExitMovers;

/**
 * The album the selected song is from on the V-Slice Freeplay menu, with its title and the stars of the song's difficulty.
 * Songs without an album don't show any of it.
 */
class FreeplayAlbumRoll extends FlxSpriteGroup
{
	static inline final ALBUM_ART_SYMBOL:String = 'album art placeholder';
	static inline final DEFAULT_OST_NAME:String = 'OFFICIAL OST';

	/**
	 * Album to show, null for none. The current mod has to be the one of the song it's being set for.
	 */
	public var albumId(default, set):String = null;

	var newAlbumArt:FreeplayAtlas;
	var albumTitle:FlxSprite = null;
	var difficultyStars:FreeplayStars;
	var albumData:FreeplayAlbum = null;

	var exitMovers:ExitMoverData = null;
	var exitMoversCharSel:ExitMoverData = null;
	var introTimer:FlxTimer = null;

	public function new()
	{
		super();

		// its animations come in from the right side of the screen
		newAlbumArt = new FreeplayAtlas(631.5, 351.5, 'freeplay/albumRoll/freeplayAlbum');
		for (label in ['intro', 'switch', 'idle'])
			newAlbumArt.addLabelAnim(label, label);
		newAlbumArt.onAnimFinish = function(name:String)
		{
			if(name != 'idle') newAlbumArt.playAnim('idle', true);
		}
		newAlbumArt.visible = false;

		difficultyStars = new FreeplayStars(FlxG.width - 330, 209);
		difficultyStars.visible = false;

		add(newAlbumArt);
		add(difficultyStars);

		buildAlbumTitle('freeplay/albumRoll/volume1-text', [0, 0]);
		albumTitle.visible = false;
	}

	function set_albumId(value:String):String
	{
		if(albumId != value || value == null)
		{
			albumId = value;
			updateAlbum();
		}
		return value;
	}

	function updateAlbum():Void
	{
		albumData = FreeplayData.getAlbum(albumId);
		if(albumData == null)
		{
			visible = false;
			return;
		}
		visible = true;

		if(Paths.fileExists('images/${albumData.artAsset}.png', IMAGE))
			newAlbumArt.replaceSymbolGraphic(ALBUM_ART_SYMBOL, Paths.image(albumData.artAsset));

		buildAlbumTitle(albumData.titleAsset, albumData.titleOffsets);
	}

	function buildAlbumTitle(assetKey:String, titleOffsets:Array<Float>):Void
	{
		var wasVisible:Bool = (albumTitle != null && albumTitle.visible);
		if(albumTitle != null)
		{
			if(exitMovers != null) removeMover(exitMovers, albumTitle);
			if(exitMoversCharSel != null) removeMover(exitMoversCharSel, albumTitle);
			remove(albumTitle, true);
			albumTitle.destroy();
		}

		albumTitle = new FlxSprite(FlxG.width - 355 + titleOffsets[0], 500 + titleOffsets[1]);
		albumTitle.antialiasing = ClientPrefs.data.antialiasing;
		if(Paths.fileExists('images/$assetKey.png', IMAGE) && Paths.fileExists('images/$assetKey.xml', TEXT))
		{
			albumTitle.frames = Paths.getSparrowAtlas(assetKey);
			albumTitle.animation.addByPrefix('idle', 'idle0', 24, true);
			albumTitle.animation.addByPrefix('switch', 'switch0', 24, false);
			albumTitle.animation.finishCallback = function(name:String)
			{
				if(name == 'switch') albumTitle.animation.play('idle');
			}
			albumTitle.animation.play('idle');
		}
		else albumTitle.makeGraphic(1, 1, FlxColor.TRANSPARENT);

		albumTitle.visible = wasVisible;
		add(albumTitle);

		applyTitleMovers();
	}

	static function removeMover(movers:ExitMoverData, sprite:FlxSprite):Void
	{
		for (sprites in movers.keys())
		{
			if(sprites.length == 1 && sprites[0] == sprite)
			{
				movers.remove(sprites);
				return;
			}
		}
	}

	function applyTitleMovers():Void
	{
		if(exitMovers != null) exitMovers.set([albumTitle], {
			x: FlxG.width,
			speed: 0.4,
			wait: 0
		});

		if(exitMoversCharSel != null) exitMoversCharSel.set([albumTitle], {
			y: -190,
			speed: 0.8,
			wait: 0.1
		});
	}

	public function applyExitMovers(exitMovers:ExitMoverData, exitMoversCharSel:ExitMoverData):Void
	{
		this.exitMovers = exitMovers;
		this.exitMoversCharSel = exitMoversCharSel;

		// the album's position is the middle of its file, not its corner, it has to end up as far as the rest
		exitMovers.set([newAlbumArt], {
			x: newAlbumArt.x + 360,
			speed: 0.4,
			wait: 0
		});

		exitMovers.set([difficultyStars], {
			x: FlxG.width,
			speed: 0.4,
			wait: 0
		});

		exitMoversCharSel.set([newAlbumArt, difficultyStars], {
			y: -175,
			speed: 0.8,
			wait: 0.1
		});

		applyTitleMovers();
	}

	/**
	 * The album rolls into the screen, then its title and the stars show up.
	 */
	public function playIntro():Void
	{
		visible = true; //this shows everything in the group, what shouldn't be seen yet is hidden again below
		albumTitle.visible = false;
		newAlbumArt.visible = true;
		newAlbumArt.playAnim('intro');

		difficultyStars.visible = false;

		if(introTimer != null) introTimer.cancel();
		introTimer = new FlxTimer().start(0.75, function(_)
		{
			showTitle();
			showStars();
			if(albumTitle.animation.exists('switch')) albumTitle.animation.play('switch');
		});
	}

	public function skipIntro():Void
	{
		if(introTimer != null) introTimer.cancel();
		if(albumData == null) return;

		visible = true;
		newAlbumArt.playAnim('switch');
		showTitle();
		if(albumTitle.animation.exists('switch')) albumTitle.animation.play('switch');
	}

	public function showTitle():Void
	{
		albumTitle.visible = true;
	}

	public function showStars():Void
	{
		difficultyStars.visible = true;
		difficultyStars.flameCheck();
	}

	public function setDifficultyStars(difficulty:Int):Void
	{
		difficultyStars.difficulty = difficulty;
	}

	/**
	 * Name to show for the soundtrack of the selected song, on the top of the menu.
	 */
	public function getOSTName():String
	{
		return (albumData != null && albumData.ostName != null) ? albumData.ostName : DEFAULT_OST_NAME;
	}

	override function destroy():Void
	{
		if(introTimer != null) introTimer.cancel();
		super.destroy();
	}
}

/**
 * Stars of the song's difficulty, from 0 to 15. Above 10 they start to catch fire.
 */
class FreeplayStars extends FlxSpriteGroup
{
	public var difficulty(default, set):Int = 1;

	var stars:FreeplayAtlas;
	var flames:Array<FlxSprite> = [];
	var flameTimers:Array<FlxTimer> = [];
	var flameCount:Int = 0;

	// The file has 100 frames for each amount of stars from 1 to 15, and a last one with no stars at all
	var curSection:Int = 0;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		for (i in 0...5)
		{
			var flame:FlxSprite = new FlxSprite(-37 + (29 * i), -118 + (6 * i));
			flame.frames = Paths.getSparrowAtlas('freeplay/freeplayFlame');
			flame.animation.addByPrefix('flame', 'fire loop full instance 1', FlxG.random.int(23, 25), false);
			flame.animation.play('flame');
			flame.animation.finishCallback = function(_) flame.animation.play('flame', true, false, 2);
			flame.antialiasing = ClientPrefs.data.antialiasing;
			flame.visible = false;
			flames.push(flame);
			add(flame);
		}

		// the stars' file has them far from its corner, this puts their own corner on the group's position
		stars = new FreeplayAtlas(-815.55, -180.53, 'freeplay/freeplayStars');
		stars.playMain(true);
		add(stars);

		difficulty = 0;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// keeps the stars on the part of the animation that has the right amount of them
		if(curSection < 15 && stars.loaded && stars.anim.curFrame >= (curSection + 1) * 100)
			stars.anim.curFrame = curSection * 100;
	}

	function set_difficulty(value:Int):Int
	{
		difficulty = Std.int(FlxMath.bound(value, 0, 15));
		curSection = (difficulty <= 0) ? 15 : difficulty - 1;

		if(stars.loaded)
		{
			if(curSection == 15)
			{
				stars.playMain(true, 1500);
				stars.anim.pause();
			}
			else stars.playMain(true, curSection * 100);
		}

		flameCheck();
		return difficulty;
	}

	public function flameCheck():Void
	{
		setFlameCount((difficulty > 10) ? difficulty - 10 : 0);
	}

	function setFlameCount(value:Int):Void
	{
		for (timer in flameTimers)
			timer.cancel();
		flameTimers = [];

		flameCount = value;

		// each new flame lights up a bit after the one before
		var newFlames:Int = 0;
		for (i in 0...flames.length)
		{
			var flame:FlxSprite = flames[i];
			if(i >= flameCount)
			{
				flame.visible = false;
				continue;
			}
			if(flame.visible) continue;

			flameTimers.push(new FlxTimer().start(0.25 * newFlames, function(_)
			{
				if(i >= flameCount) return;

				flame.animation.play('flame', true);
				flame.visible = true;
			}));
			newFlames++;
		}
	}

	override function destroy():Void
	{
		for (timer in flameTimers)
			timer.cancel();
		super.destroy();
	}
}
