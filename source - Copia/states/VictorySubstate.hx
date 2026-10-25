package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.NetworkManager;

class VictorySubstate extends MusicBeatSubstate {
    
    var leaving:Bool = false;

    override function create() {
        
        // ---> CORREÇÃO DA CÂMERA <---
        this.cameras = [PlayState.instance.camOther];

        if (FlxG.sound.music != null) FlxG.sound.music.stop();
        if (PlayState.instance.vocals != null) PlayState.instance.vocals.stop();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.6;
        add(bg);

        var winText = new FlxText(0, 0, 0, "VITORIA!\nO Oponente foi Nocauteado!", 64);
        winText.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        winText.screenCenter();
        add(winText);

        var hintText = new FlxText(0, FlxG.height - 100, 0, "Aperte ENTER para sair", 32);
        hintText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        hintText.screenCenter(X);
        add(hintText);
        
        super.create();
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        
        // ---> LÊ SE O PERDEDOR INICIOU A SAÍDA <---
        if (!NetworkManager.connected && !leaving) {
            // o oponente fechou o jogo: não tem por que esperar por ele
            leaveToLobby();
            return;
        }
        if (NetworkManager.connected && !leaving) {
            var msgs = NetworkManager.getNewMessages();
            for (msg in msgs) {
                if (msg == "RETURN_TO_LOBBY") {
                    leaveToLobby();
                }
            }
        }

        // ---> AVISA O PERDEDOR SE O GANHADOR APERTAR ENTER <---
        if (controls.ACCEPT && !leaving) {
            if (NetworkManager.connected) {
                NetworkManager.send("RETURN_TO_LOBBY");
            }
            leaveToLobby();
        }
    }

    function leaveToLobby() {
        leaving = true;
        // (a conexão continua: os dois voltam pro lobby e o Host escolhe a próxima música)
        FlxG.sound.playMusic(Paths.music('freakyMenu'));

        // ---> CORREÇÃO: Usa a transição nativa de state do V-Slice <---
        backend.StickerTransition.prepare(); 
        backend.StickerTransition.switchState(new states.MultiplayerMenuState());
    }
}