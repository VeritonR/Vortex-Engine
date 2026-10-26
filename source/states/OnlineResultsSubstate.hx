package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import backend.NetworkManager;
import objects.HealthIcon;

/**
 * One player's numbers at the end of an online song, the way they're sent ("FINAL_STATS|score|misses|accuracy|rating|sick|good|bad|
 * shit|max combo") and compared (see `NetworkManager.compareResults()`). Accuracy below 0 is no note played at all.
 */
typedef OnlineStats = {
	score:Int,
	misses:Int,
	accuracy:Float,
	rating:String,
	?sick:Null<Int>,
	?good:Null<Int>,
	?bad:Null<Int>,
	?shit:Null<Int>,
	?maxCombo:Null<Int>
}

/**
 * The end of an online song where nobody was knocked out: both players' numbers side by side (the dad's side on the left, the
 * boyfriend's on the right, like on the stage), and who won by the match's condition (`NetworkManager.winCondition`).
 *
 * Each player sends their numbers when their song ends and waits a moment for the other's (the last ones they sent during the song
 * are used if they don't come). Each one goes back to the lobby when they want.
 */
class OnlineResultsSubstate extends MusicBeatSubstate
{
	static inline final WAIT_TIME:Float = 8; // seconds the other player's numbers are waited for
	static inline final CARD_WIDTH:Int = 440;
	static inline final CARD_HEIGHT:Int = 410;

	var game:PlayState;
	var mine:OnlineStats;
	var other:OnlineStats;
	var otherIsFinal:Bool = false;
	var otherKnockedOut:Bool = false;
	var otherLeft:Bool = false;

	var waited:Float = 0;
	var shown:Bool = false;
	var shownTime:Float = 0;
	var leaving:Bool = false;

	var dim:FlxSprite;
	var waitText:FlxText;
	var noticeText:FlxText;
	var hintText:FlxText;

	public static function parseStats(data:Array<String>):OnlineStats
	{
		function int(index:Int):Null<Int>
			return (data != null && data.length > index) ? Std.parseInt(data[index]) : null;

		var accuracy:Float = (data != null && data.length > 3) ? Std.parseFloat(data[3]) : -1;
		if (Math.isNaN(accuracy)) accuracy = -1;
		var score:Null<Int> = int(1);
		var misses:Null<Int> = int(2);
		return {
			score: (score != null) ? score : 0,
			misses: (misses != null) ? misses : 0,
			accuracy: accuracy,
			rating: (data != null && data.length > 4) ? data[4] : '',
			sick: int(5),
			good: int(6),
			bad: int(7),
			shit: int(8),
			maxCombo: int(9)
		};
	}

	public function new(mine:OnlineStats)
	{
		super();
		this.mine = mine;
	}

	override function create()
	{
		game = PlayState.instance;
		cameras = [game.camOther];

		// what the other one sent while the song was still going for this one
		other = game.otherOnlineStats;
		if (game.otherFinalStats != null)
		{
			other = parseStats(game.otherFinalStats);
			otherIsFinal = true;
		}

		dim = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		dim.scale.set(FlxG.width, FlxG.height);
		dim.updateHitbox();
		dim.alpha = 0;
		add(dim);
		FlxTween.tween(dim, {alpha: 0.7}, 0.5);

		waitText = makeText(0, FlxG.height / 2 - 20, FlxG.width, "Waiting for " + NetworkManager.opponentNickname + "'s results...", 32, FlxColor.CYAN, CENTER);
		noticeText = makeText(0, FlxG.height - 76, FlxG.width, '', 20, 0xFFBBBBBB, CENTER);
		hintText = makeText(0, FlxG.height - 44, FlxG.width, '', 24, FlxColor.WHITE, CENTER);

		super.create();
	}

	function makeText(x:Float, y:Float, width:Float, text:String, size:Int, color:FlxColor, align:FlxTextAlign):FlxText
	{
		var t:FlxText = new FlxText(x, y, width, text, size);
		t.setFormat(Paths.font('vcr.ttf'), size, color, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 1.5;
		add(t);
		return t;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (leaving) return;

		readMessages();

		if (!shown)
		{
			waited += elapsed;
			if (otherIsFinal || otherKnockedOut || waited >= WAIT_TIME || !NetworkManager.connected) show();
			return;
		}

		shownTime += elapsed;
		if (shownTime > 1 && controls.ACCEPT) leave();
	}

	function readMessages():Void
	{
		if (!NetworkManager.connected)
		{
			if (!otherLeft)
			{
				otherLeft = true;
				noticeText.text = NetworkManager.statusString;
			}
			return;
		}

		for (msg in NetworkManager.getNewMessages())
		{
			var data:Array<String> = msg.split('|');
			switch (data[0])
			{
				case 'FINAL_STATS':
					if (!shown)
					{
						other = parseStats(data);
						otherIsFinal = true;
					}
				case 'STATS':
					if (!otherIsFinal) other = parseStats(data);
				case 'PLAYER_DIED':
					if (!shown) otherKnockedOut = true;
				case 'RESULTS_LEFT', 'RETURN_TO_LOBBY':
					otherLeft = true;
					noticeText.text = '${NetworkManager.opponentNickname} went back to the lobby';
			}
		}
	}

	function show():Void
	{
		shown = true;
		waitText.visible = false;
		// (the song's HUD goes away, its numbers are on the cards)
		if (game.camHUD != null) FlxTween.tween(game.camHUD, {alpha: 0}, 0.4);

		var comparison = NetworkManager.compareResults(mine, other, NetworkManager.winCondition);
		var result:Int = otherKnockedOut ? 1 : comparison.result;
		NetworkManager.log('results: ' + (result > 0 ? 'won' : (result < 0 ? 'lost' : 'draw')) + ' by ' + NetworkManager.winCondition
			+ ' (decided by ' + comparison.decidedBy + ') - mine ' + mine.score + '/' + mine.misses + '/' + mine.accuracy
			+ ', theirs ' + other.score + '/' + other.misses + '/' + other.accuracy);

		// the title
		var titleText:String = (result > 0) ? 'VICTORY!' : ((result < 0) ? 'DEFEAT' : 'DRAW');
		var titleColor:FlxColor = (result > 0) ? 0xFFFFD34D : ((result < 0) ? 0xFFFF5C5C : FlxColor.WHITE);
		var title:FlxText = makeText(0, 18, FlxG.width, titleText, 72, titleColor, CENTER);
		title.borderSize = 4;
		title.scale.set(0.2, 0.2);
		FlxTween.tween(title.scale, {x: 1, y: 1}, 0.5, {ease: FlxEase.backOut});

		var subtitle:String = 'Win by ' + NetworkManager.winConditionName(NetworkManager.winCondition);
		if (otherKnockedOut) subtitle = '${NetworkManager.opponentNickname} was knocked out';
		else if (result != 0 && comparison.decidedBy != NetworkManager.winCondition)
			subtitle += '  -  tied, decided by ' + NetworkManager.winConditionName(comparison.decidedBy);
		else if (result == 0) subtitle += '  -  tied in everything';
		if (!otherIsFinal && !otherKnockedOut) subtitle += '  (their last numbers)';
		makeText(0, 104, FlxG.width, subtitle, 22, 0xFFDDDDDD, CENTER);

		// the cards: the dad's side on the left, the boyfriend's on the right
		var iAmDad:Bool = game.playAsOpponent;
		var left:OnlineStats = iAmDad ? mine : other;
		var right:OnlineStats = iAmDad ? other : mine;
		var leftResult:Int = iAmDad ? result : -result;
		makeCard(FlxG.width / 2 - CARD_WIDTH - 24, left, leftResult, game.dad, iAmDad, false, 0);
		makeCard(FlxG.width / 2 + 24, right, -leftResult, game.boyfriend, !iAmDad, true, 0.12);

		// the winner cheers on the stage behind
		var winner:objects.Character = (result == 0) ? null : ((result > 0) == iAmDad ? game.dad : game.boyfriend);
		if (winner != null && winner.hasAnimation('hey'))
		{
			winner.playAnim('hey', true);
			winner.specialAnim = true;
			winner.heyTimer = 2;
		}

		var music:String = (result > 0) ? 'resultsEXCELLENT/resultsEXCELLENT' : ((result < 0) ? 'resultsSHIT/resultsSHIT' : 'resultsNORMAL/resultsNORMAL');
		try
		{
			FlxG.sound.playMusic(Paths.music(music), 0.8, true);
		}
		catch (e:Dynamic) {}

		hintText.text = 'ENTER: back to the lobby';
		hintText.alpha = 0;
		FlxTween.tween(hintText, {alpha: 1}, 0.4, {startDelay: 1});
	}

	function makeCard(x:Float, stats:OnlineStats, result:Int, char:objects.Character, isMe:Bool, isPlayerSide:Bool, delay:Float):Void
	{
		var y:Float = 150;
		var parts:Array<flixel.FlxSprite> = [];

		var border:FlxColor = (result > 0) ? 0xFFFFD34D : ((result < 0) ? 0xFF555555 : 0xFFBBBBBB);
		var card:FlxSprite = new FlxSprite(x, y).makeGraphic(CARD_WIDTH, CARD_HEIGHT, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(card, 2, 2, CARD_WIDTH - 4, CARD_HEIGHT - 4, 26, 26, 0xEE161616, {thickness: (result > 0) ? 5 : 3, color: border});
		add(card);
		parts.push(card);

		var nickColor:FlxColor = FlxColor.WHITE;
		if (char != null && char.healthColorArray != null)
			nickColor = FlxColor.fromRGB(char.healthColorArray[0], char.healthColorArray[1], char.healthColorArray[2]);

		// the character's icon in the corner, the nick beside it
		var icon:HealthIcon = new HealthIcon((char != null) ? char.healthIcon : 'face', isPlayerSide);
		icon.autoUpdate = false;
		icon.scale.set(0.8, 0.8);
		icon.updateHitbox();
		icon.setPosition(x + 14, y + 8);
		icon.playAnimation((result > 0) ? 'winning' : ((result < 0) ? 'losing' : 'idle'));
		add(icon);
		parts.push(icon);

		var nick:String = isMe ? NetworkManager.myNickname + ' (you)' : NetworkManager.opponentNickname;
		var textX:Float = x + 150;
		var nickText:FlxText = makeText(textX, y + 34, CARD_WIDTH - 164, nick, 28, nickColor, LEFT);
		parts.push(nickText);

		var tag:String = (result > 0) ? 'WINNER' : ((result < 0) ? '' : 'DRAW');
		if (tag.length > 0)
		{
			var tagText:FlxText = makeText(textX, y + 72, CARD_WIDTH - 164, tag, 24, (result > 0) ? 0xFFFFD34D : 0xFFBBBBBB, LEFT);
			parts.push(tagText);
		}

		var condition:String = NetworkManager.winCondition;
		var rows:Array<{name:String, value:String, key:String}> = [
			{name: 'Score', value: Std.string(stats.score), key: 'score'},
			{name: 'Misses', value: Std.string(stats.misses), key: 'misses'},
			{name: 'Accuracy', value: (stats.accuracy >= 0) ? Std.string(stats.accuracy) + '%' : '?', key: 'accuracy'},
			{name: 'Rating', value: (stats.rating != null && stats.rating.length > 0) ? stats.rating : '?', key: ''},
			{name: 'Sick / Good / Bad / Shit', value: tally(stats.sick) + ' / ' + tally(stats.good) + ' / ' + tally(stats.bad) + ' / ' + tally(stats.shit), key: ''},
			{name: 'Max Combo', value: tally(stats.maxCombo), key: ''}
		];

		var rowY:Float = y + 146;
		for (row in rows)
		{
			// the condition's row stands out
			if (row.key == condition)
			{
				var mark:FlxSprite = new FlxSprite(x + 14, rowY - 4).makeGraphic(CARD_WIDTH - 28, 34, 0x668844DD);
				add(mark);
				parts.push(mark);
			}
			var small:Bool = row.name.length > 12;
			var nameText:FlxText = makeText(x + 26, rowY + (small ? 5 : 0), CARD_WIDTH - 52, row.name, small ? 16 : 24, 0xFFCCCCCC, LEFT);
			var valueColor:FlxColor = (row.key == condition && result > 0) ? 0xFFFFD34D : FlxColor.WHITE;
			var valueText:FlxText = makeText(x + 26, rowY + (small ? 5 : 0), CARD_WIDTH - 52, row.value, small ? 16 : 24, valueColor, RIGHT);
			parts.push(nameText);
			parts.push(valueText);
			rowY += 42;
		}

		// in from below, one card a little after the other
		for (part in parts)
		{
			var targetY:Float = part.y;
			part.y += FlxG.height;
			FlxTween.tween(part, {y: targetY}, 0.6, {ease: FlxEase.quartOut, startDelay: delay});
		}
	}

	static function tally(value:Null<Int>):String
		return (value != null) ? Std.string(value) : '-';

	function leave():Void
	{
		leaving = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));
		if (NetworkManager.connected) NetworkManager.send('RESULTS_LEFT');

		// (the connection stays: both go back to the lobby, and the host picks the next song)
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		Mods.loadTopMod();
		backend.StickerTransition.prepare();
		backend.StickerTransition.switchState(new states.MultiplayerMenuState());
		FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}
