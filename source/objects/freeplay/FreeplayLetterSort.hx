package objects.freeplay;

/**
 * The letters above the songs of the V-Slice Freeplay menu, used to only show the songs that start with them.
 * Besides the letters there's "ALL", "#" for the ones that start with a number and the heart for the favorites.
 */
class FreeplayLetterSort extends FlxSpriteGroup
{
	public var letters:Array<FreeplayLetter> = [];

	/**
	 * Called with the new filter: "ALL", "fav", "#" or a range of letters like "A-B" and "S".
	 */
	public var changeSelectionCallback:String->Void = null;

	// starts on the third one, which is "ALL"
	var curSelection:Int = 2;

	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var grpSeperators:FlxSpriteGroup;
	var timers:Array<FlxTimer> = [];

	public function new(x:Float, y:Float)
	{
		super(x, y);

		var antialias:Bool = ClientPrefs.data.antialiasing;

		grpSeperators = new FlxSpriteGroup();
		add(grpSeperators);

		leftArrow = new FlxSprite(-20, 15).loadGraphic(Paths.image('freeplay/miniArrow'));
		leftArrow.flipX = true;
		leftArrow.antialiasing = antialias;
		add(leftArrow);

		rightArrow = new FlxSprite(380, 15).loadGraphic(Paths.image('freeplay/miniArrow'));
		rightArrow.antialiasing = antialias;
		add(rightArrow);

		for (i in 0...5)
		{
			var letter:FreeplayLetter = new FreeplayLetter(i * 80, -10, i, curSelection);
			add(letter);
			letters.push(letter);

			if(i != 2) letter.scale.x = letter.scale.y = 0.8;

			// the further from the middle, the darker
			var darkness:Float = Math.max(Math.abs(i - 2) / 6, 0.01);
			letter.color = letter.color.getDarkened(darkness);

			if(i == 4) continue; //nothing after the last one

			var separator:FlxSprite = new FlxSprite((i * 80) + 60, 20).loadGraphic(Paths.image('freeplay/seperator'));
			separator.color = letter.color.getDarkened(darkness);
			separator.antialiasing = antialias;
			grpSeperators.add(separator);
		}

		changeSelection(0);
	}

	public function changeSelection(change:Int = 0, playSound:Bool = true):Void
	{
		doLetterChangeAnims(change);

		// the arrow of the side it's going to gets nudged
		var direction:Float = (change > 0) ? 1 : -1;
		var arrowToMove:FlxSprite = (change < 0) ? leftArrow : rightArrow;
		arrowToMove.offset.x = 3 * direction;
		startTimer(2 / 24, function() arrowToMove.offset.x = 0);

		if(playSound && change != 0) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function startTimer(time:Float, onComplete:Void->Void):Void
	{
		timers.push(new FlxTimer().start(time, function(timer:FlxTimer)
		{
			timers.remove(timer);
			onComplete();
		}));
	}

	// Everything slides a bit to the side and comes back, frame by frame
	function doLetterChangeAnims(change:Int):Void
	{
		var positions:Array<Float> = [-10, -22, 2, 0];
		var direction:Float = (change > 0) ? 1 : -1;

		for (separator in grpSeperators.members)
		{
			separator.offset.x = positions[0] * direction;
			for (frame in 1...4)
				startTimer(frame / 24, function() separator.offset.x = positions[frame] * direction);
		}

		for (index => letter in letters)
		{
			letter.offset.x = positions[0] * direction;

			startTimer(1 / 24, function()
			{
				letter.offset.x = positions[1] * direction;
				if(index == 0) letter.visible = false;
			});

			startTimer(2 / 24, function()
			{
				letter.offset.x = positions[2] * direction;
				if(index == 0) letter.visible = true;
			});

			startTimer(3 / 24, function() letter.offset.x = (index == 2) ? 0 : positions[3] * direction);
		}

		var total:Int = FreeplayLetter.regexLetters.length;
		curSelection = FlxMath.wrap(curSelection + change, 0, total - 1);

		for (letter in letters)
			letter.changeLetter(change, curSelection);

		if(changeSelectionCallback != null) changeSelectionCallback(FreeplayLetter.regexLetters[letters[2].curLetter]);
	}

	override function destroy():Void
	{
		for (timer in timers)
			timer.cancel();
		timers = [];
		super.destroy();
	}
}

/**
 * One of the letters, each a symbol of the "sortedLetters" texture atlas.
 */
class FreeplayLetter extends FreeplayAtlas
{
	/**
	 * What each option is filtered by, a range of letters ("A-B") or one of the special ones.
	 */
	public static final regexLetters:Array<String> = ['#', 'fav', 'ALL', 'A-B', 'C-D', 'E-H', 'I-L', 'M-N', 'O-R', 'S', 'T', 'U-Z'];

	// Area each symbol takes around its own origin, the art isn't centered on it: left, top, right, bottom
	static final symbolBounds:Map<String, Array<Float>> = [
		'# move' => [-55.09, -67, 1.16, 4.35],
		'fav move' => [-55.09, -63.69, 0.05, 1.04],
		'ALL move' => [-58.4, -64.8, 2.26, 3.24],
		'AB move' => [-57.3, -68.11, 1.16, 5.45],
		'CD move' => [-56.19, -67, 1.16, 5.45],
		'EH move' => [-56.19, -65.9, 1.16, 3.24],
		'IL move' => [-56.19, -67, 1.16, 5.45],
		'MN move' => [-58.4, -65.9, 2.26, 3.24],
		'OR move' => [-56.19, -64.8, 1.16, 2.14],
		'S move' => [-52.89, -64.8, -3.26, 2.14],
		'T move' => [-53.99, -62.59, 0.05, 1.04],
		'UZ move' => [-57.3, -65.9, 2.26, 4.35]
	];
	static final defaultBounds:Array<Float> = [-56, -66, 1, 4];

	/**
	 * Position on `regexLetters` of what this one is showing.
	 */
	public var curLetter:Int = 0;

	var curBounds:Array<Float> = [0, 0, 0, 0];

	/**
	 * The position is where the top left corner of the letter goes.
	 */
	public function new(x:Float, y:Float, letterIndex:Int, curSelected:Int)
	{
		super(x, y, 'freeplay/sortedLetters');

		for (letter in regexLetters)
		{
			var symbol:String = letter.replace('-', '') + ' move';
			addSymbolAnim(symbol, symbol);
		}

		curLetter = letterIndex;
		showLetter(curSelected);
	}

	/**
	 * Goes to the letter before or after the current one, bouncing if it's the selected one.
	 */
	public function changeLetter(change:Int = 0, curSelection:Int):Void
	{
		curLetter = FlxMath.wrap(curLetter + change, 0, regexLetters.length - 1);
		showLetter(curSelection);
	}

	function showLetter(curSelection:Int):Void
	{
		var symbol:String = regexLetters[curLetter].replace('-', '') + ' move';
		if(!playAnim(symbol, true)) return;

		if(curSelection != curLetter) anim.pause();

		// keeps the top left corner where it was, and makes it get scaled from its middle
		var bounds:Array<Float> = symbolBounds.exists(symbol) ? symbolBounds.get(symbol) : defaultBounds;
		x += curBounds[0] - bounds[0];
		y += curBounds[1] - bounds[1];
		origin.set((bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2);
		curBounds = bounds;
	}
}
