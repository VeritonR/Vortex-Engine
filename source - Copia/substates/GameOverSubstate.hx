package substates;

import backend.WeekData;

import objects.Character;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxPoint;

import states.StoryMenuState;
import states.FreeplayState;
import states.FreeplayStateVslice;

class GameOverSubstate extends MusicBeatSubstate
{
	public var boyfriend:Character;
	var camFollow:FlxObject;

	var stagePostfix:String = "";

	// ---> TIMER DO MULTIPLAYER <---
	var multiplayerDeathTimer:Float = 0;

	public static var characterName:String = 'bf-dead';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'Flipped-Up';
	public static var endSoundName:String = 'Flipped-Up-RETRY';
	public static var deathDelay:Float = 0;

	public static var instance:GameOverSubstate;
	public function new(?playStateBoyfriend:Character = null)
	{
		if(playStateBoyfriend != null && playStateBoyfriend.curCharacter == characterName) //Avoids spawning a second boyfriend cuz animate atlas is laggy
		{
			this.boyfriend = playStateBoyfriend;
		}
		// V-Slice's characters are the ones that die, with the death animations of their own file ("bf-dead" is what's there when nothing chose another)
		else if(playStateBoyfriend != null && playStateBoyfriend.isVSlice && characterName == 'bf-dead' && playStateBoyfriend.hasAnimation('firstDeath'))
		{
			this.boyfriend = playStateBoyfriend;
			characterName = playStateBoyfriend.curCharacter;
		}
		super();
	}

	public static function resetVariables() {
		characterName = 'bf-dead';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'Flipped-Up';
		endSoundName = 'Flipped-Up-RETRY';
		deathDelay = 0;

		var _song = PlayState.SONG;
		if(_song != null)
		{
			if(_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) characterName = _song.gameOverChar;
			if(_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) deathSoundName = _song.gameOverSound;
			if(_song.gameOverLoop != null && _song.gameOverLoop.trim().length > 0) loopSoundName = _song.gameOverLoop;
			if(_song.gameOverEnd != null && _song.gameOverEnd.trim().length > 0) endSoundName = _song.gameOverEnd;
		}
	}

	/**
	 * If the line the one who died gets to hear was already played (or looked for).
	 */
	public var deathQuotePlayed:Bool = false;

	/**
	 * V-Slice characters can have a line said to them when they die: their script picks the sound (`getDeathQuote()`,
	 * which is how the base game has Tankman making fun of whoever lost to him). It's played once, over the music turned down.
	 * Returns false if there was none to play.
	 */
	public function playDeathQuote():Bool
	{
		if(deathQuotePlayed) return false;
		deathQuotePlayed = true;

		#if HSCRIPT_ALLOWED
		var quote:openfl.media.Sound = backend.VSliceScripts.getDeathQuote(boyfriend);
		if(quote == null) return false;

		coolStartDeath(0.2);
		FlxG.sound.play(quote, 1, false, null, true, function() {
			if(!isEnding && FlxG.sound.music != null) FlxG.sound.music.fadeIn(4, 0.2, 1);
		});
		return true;
		#else
		return false;
		#end
	}

	var charX:Float = 0;
	var charY:Float = 0;

	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	override function create()
	{
		instance = this;

		Conductor.songPosition = 0;

		if(boyfriend == null)
		{
			boyfriend = new Character(PlayState.instance.boyfriend.getScreenPosition().x, PlayState.instance.boyfriend.getScreenPosition().y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0] - PlayState.instance.boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - PlayState.instance.boyfriend.positionArray[1];
		}
		boyfriend.skipDance = true;
		add(boyfriend);

		FlxG.sound.play(Paths.sound(deathSoundName));
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		boyfriend.playAnim('firstDeath');

		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0], boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]);
		FlxG.camera.focusOn(new FlxPoint(FlxG.camera.scroll.x + (FlxG.camera.width / 2), FlxG.camera.scroll.y + (FlxG.camera.height / 2)));
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		add(camFollow);
		
		PlayState.instance.setOnScripts('inGameOver', true);
		PlayState.instance.callOnScripts('onGameOverStart', []);
		FlxG.sound.music.loadEmbedded(Paths.music(loopSoundName), true);

		if(characterName == 'pico-dead')
		{
			overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
			overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
			overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
			overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
			overlay.antialiasing = ClientPrefs.data.antialiasing;
			overlayConfirmOffsets.set(250, 200);
			overlay.visible = false;
			add(overlay);

			boyfriend.animation.callback = function(name:String, frameNumber:Int, frameIndex:Int)
			{
				switch(name)
				{
					case 'firstDeath':
						if(frameNumber >= 36 - 1)
						{
							overlay.visible = true;
							overlay.animation.play('deathLoop');
							boyfriend.animation.callback = null;
						}
					default:
						boyfriend.animation.callback = null;
				}
			}

			if(PlayState.instance.gf != null && PlayState.instance.gf.curCharacter == 'nene')
			{
				var neneKnife:FlxSprite = new FlxSprite(boyfriend.x - 450, boyfriend.y - 250);
				neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
				neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
				neneKnife.antialiasing = ClientPrefs.data.antialiasing;
				neneKnife.animation.finishCallback = function(_)
				{
					remove(neneKnife);
					neneKnife.destroy();
				}
				insert(0, neneKnife);
				neneKnife.animation.play('anim', true);
			}
		}

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (!boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished())
		{
			boyfriend.playAnim('deathLoop');
			if(overlay != null && overlay.animation.exists('deathLoop'))
			{
				overlay.visible = true;
				overlay.animation.play('deathLoop');
			}
			justPlayedLoop = true;
		}

		if(!isEnding)
		{

			// ---> TIMER E SINAIS DO MULTIPLAYER <---
			if (backend.NetworkManager.connected) {
				multiplayerDeathTimer += elapsed;
				
				// Se o ganhador apertou ENTER lá na tela dele, a gente sai!
				var msgs = backend.NetworkManager.getNewMessages();
				for (msg in msgs) {
					if (msg == "RETURN_TO_LOBBY") {
						endBullshit();
					}
				}

				// Se passar de 10 segundos, força o fechamento automático
				if (multiplayerDeathTimer >= 10) {
					endBullshit(); 
				}
			}
			// ---------------------------

			if (controls.ACCEPT)
			{
				endBullshit();
			}
			else if (controls.BACK)
			{
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
				FlxG.camera.visible = false;
				FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = false;
				PlayState.chartingMode = false;

				// ---> AVISA O GANHADOR E LIMPA A REDE <---
				var wasMultiplayer:Bool = false;
				if (backend.NetworkManager.connected) {
					wasMultiplayer = true;
					backend.NetworkManager.send("RETURN_TO_LOBBY"); // <--- AVISA O GANHADOR AQUI (a conexão continua, para a próxima música)
				}
				// -----------------------------------------
	
				backend.StickerTransition.prepare();
				Mods.loadTopMod();
				
				// Se era Multiplayer, volta pro Lobby. Senão, segue o jogo normal.
				if (wasMultiplayer)
				{
					backend.StickerTransition.switchState(new states.MultiplayerMenuState());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else if (PlayState.isStoryMode)
				{
					backend.StickerTransition.switchState(new StoryMenuState());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else if (ClientPrefs.data.freeplayStyle == 'V-Slice')
				{
					FreeplayStateVslice.playerDied = true;
					backend.StickerTransition.switchState(new FreeplayStateVslice());
				}
				else
				{
					backend.StickerTransition.switchState(new FreeplayState());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
	
				PlayState.instance.callOnScripts('onGameOverConfirm', [false]);
			}
			else if (justPlayedLoop && playDeathQuote())
			{
				// (a V-Slice character had something to say: see playDeathQuote())
			}
			else if (justPlayedLoop)
			{
				switch(PlayState.SONG.stage)
				{
					case 'tank':
						coolStartDeath(0.2);
						
						var exclude:Array<Int> = [];
						//if(!ClientPrefs.cursing) exclude = [1, 3, 8, 13, 17, 21];
	
						FlxG.sound.play(Paths.sound('jeffGameover/jeffGameover-' + FlxG.random.int(1, 25, exclude)), 1, false, null, true, function() {
							if(!isEnding)
							{
								FlxG.sound.music.fadeIn(0.2, 1, 4);
							}
						});

					default:
						coolStartDeath();
				}
			}
			
			if (FlxG.sound.music.playing)
			{
				Conductor.songPosition = FlxG.sound.music.time;
			}
		}
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
	}

	var isEnding:Bool = false;
	function coolStartDeath(?volume:Float = 1):Void
	{
		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;
	}

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			if(boyfriend.hasAnimation('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			else if(boyfriend.hasAnimation('deathLoop'))
				boyfriend.playAnim('deathLoop', true);

			if(overlay != null && overlay.animation.exists('deathConfirm'))
			{
				overlay.visible = true;
				overlay.animation.play('deathConfirm');
				overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
			}
			FlxG.sound.music.stop();
			FlxG.sound.play(Paths.music(endSoundName));
			
			// ---> VERIFICA SE É MULTIPLAYER PARA FECHAR A REDE ANTES DE SAIR <---
			var wasMultiplayer:Bool = false;
			if (backend.NetworkManager.connected) {
				wasMultiplayer = true;
				backend.NetworkManager.send("RETURN_TO_LOBBY"); // <--- AVISA O GANHADOR AQUI TAMBÉM (a conexão continua)
			}
			// --------------------------------------------------------------------

			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					if (wasMultiplayer) {
						// O jogador perdeu no online, então ele volta pro Lobby
						backend.StickerTransition.prepare();
						MusicBeatState.switchState(new states.MultiplayerMenuState());
						FlxG.sound.playMusic(Paths.music('freakyMenu'));
					} else {
						// O jogador perdeu sozinho, reinicia a música
						MusicBeatState.resetState();
					}
				});
			});
			PlayState.instance.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
