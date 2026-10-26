package backend;

#if sys
import sys.net.Socket;
import sys.net.Host;
import sys.thread.Thread;
import sys.thread.Mutex;
#end

/**
 * The online match: one player hosts (waits for the other on port `PORT`), the other joins with the host's IP.
 * The messages are lines of text ("NAME|value|value"); a thread of its own reads them as they come and the game picks them up
 * every frame (`getNewMessages()`). The connection is kept between songs, until a player leaves the lobby or it's lost.
 */
class NetworkManager {
    public static inline var PORT:Int = 8888;

    #if sys
    public static var socket:Socket;
    #else
    public static var socket:Dynamic;
    #end
    public static var isHost:Bool = false;
    public static var connected:Bool = false;
    /** Waiting for the other player to join (hosting) or for the host to answer (joining). */
    public static var busy(default, null):Bool = false;

    public static var statusString:String = "Disconnected";

    // ---> VARIÁVEIS DE NICKNAME <---
    public static var myNickname:String = "Player";
    public static var opponentNickname:String = "Opponent";

    /** Test runs (see DirectPlay): what goes on with the connection is written on the game's output, and botplay stays on. */
    public static var testLog:Bool = false;
    public static var testBotplay:Bool = false;
    /** Test runs: every message is read this many milliseconds after it got here (plus up to `testJitter` more), like over a slow network. */
    public static var testDelay:Float = 0;
    public static var testJitter:Float = 0;

    public static function log(text:String) {
        if (testLog) Sys.println('[ONLINE ' + Std.int(haxe.Timer.stamp() * 1000) + '] ' + text);
    }

    /** Half of the time a message takes to go and come back, in milliseconds (how late the other player sees what this one does). */
    public static var latency:Float = 0;
    static var recentPings:Array<Float> = [];
    static var lastDelivery:Float = 0;

    #if sys
    public static var incomingMessages:Array<String> = [];
    // O Mutex impede que o jogo crashe se a Thread da rede e a Thread do jogo mexerem nas mensagens ao mesmo tempo
    static var mutex:Mutex = new Mutex();
    // (the reading thread answers pings by itself, while the game sends its own things)
    static var sendMutex:Mutex = new Mutex();

    // The one waiting for players (only while hosting) and the one being connected with (only while joining)
    static var server:Socket = null;
    static var connecting:Socket = null;

    // Goes up with every connection made or dropped: a thread of an older one knows it's not the current one anymore
    static var session:Int = 0;
    #end

    // Where the host's song was, with the moment each one got here (see `takeTimeSamples()`)
    static var timeSamples:Array<{time:Float, arrival:Float}> = [];

    /**
     * The host's song positions that came since the last time (`SYNC_TIME`), each with the moment it got here (`haxe.Timer.stamp()`).
     */
    public static function takeTimeSamples():Array<{time:Float, arrival:Float}> {
        var samples:Array<{time:Float, arrival:Float}> = [];
        #if sys
        mutex.acquire();
        if (timeSamples.length > 0) {
            samples = timeSamples;
            timeSamples = [];
        }
        mutex.release();
        #end
        return samples;
    }

    // A song the host asked for, kept until the lobby takes it (whatever screen this player is on when it comes)
    static var pendingLoadSong:String = null;

    // ==========================================
    // CRIAR O SERVIDOR (HOST)
    // ==========================================
    public static function hostServer() {
        #if sys
        if (busy || connected) return;
        busy = true;
        startPinging();
        statusString = "Aguardando Jogador 2...";
        var mySession:Int = session;

        Thread.create(function() {
            var listener:Socket = null;
            try {
                listener = new Socket();
                listener.bind(new Host("0.0.0.0"), PORT); // Abre a porta 8888
                listener.listen(1);
                server = listener;

                var client:Socket = listener.accept(); // O código fica pausado aqui até alguém entrar!

                // Só um jogador entra: a porta é fechada (e pode ser aberta de novo na próxima vez)
                closeQuietly(listener);
                server = null;
                if (mySession != session) { closeQuietly(client); return; } // cancelado enquanto esperava

                // ---> ANTI-LAG: DESLIGA O ALGORITMO DE NAGLE (TCP_NODELAY) <---
                client.setFastSend(true);
                statusString = "Jogador 2 Conectado!";
                log('hosting: player 2 connected');
                startSession(client, true); // (fica escutando aqui até a conexão acabar)
            } catch(e:Dynamic) {
                closeQuietly(listener);
                server = null;
                busy = false;
                if (mySession == session) statusString = "Erro ao criar servidor (a porta " + PORT + " pode estar em uso).";
            }
        });
        #end
    }

    // ==========================================
    // ENTRAR EM UM SERVIDOR (CLIENT)
    // ==========================================
    public static function joinServer(ip:String) {
        #if sys
        if (busy || connected) return;
        busy = true;
        startPinging();
        statusString = "Conectando a " + ip + "...";
        var mySession:Int = session;

        Thread.create(function() {
            var attempt:Socket = new Socket();
            connecting = attempt;
            try {
                attempt.connect(new Host(ip), PORT);
                connecting = null;
                if (mySession != session) { closeQuietly(attempt); return; } // cancelado enquanto conectava

                // ---> ANTI-LAG: DESLIGA O ALGORITMO DE NAGLE (TCP_NODELAY) <---
                attempt.setFastSend(true);
                statusString = "Conectado ao Host!";
                log('joined the host');
                startSession(attempt, false); // (fica escutando aqui até a conexão acabar)
            } catch(e:Dynamic) {
                connecting = null;
                closeQuietly(attempt);
                busy = false;
                if (mySession == session) statusString = "Falha ao conectar no IP.";
            }
        });
        #end
    }

    /**
     * Stops hosting or joining before the other player was found.
     */
    public static function cancel() {
        #if sys
        if (!busy || connected) return;
        session++;
        busy = false;
        closeQuietly(server);
        closeQuietly(connecting);
        server = null;
        connecting = null;
        statusString = "Disconnected";
        #end
    }

    /**
     * Ends the match: the other player is told, and both go back to choosing to host or join.
     */
    public static function disconnect(?reason:String) {
        #if sys
        if (connected) sendNow("BYE");
        session++;
        connected = false;
        busy = false;
        closeQuietly(socket);
        closeQuietly(server);
        closeQuietly(connecting);
        socket = null;
        server = null;
        connecting = null;
        mutex.acquire();
        incomingMessages = [];
        mutex.release();
        #end
        pendingLoadSong = null;
        latency = 0;
        statusString = (reason != null) ? reason : "Disconnected";
        restoreSettings();
    }

    #if sys
    // The connection is there: everything about it is set before it counts as connected (other code reads `isHost` once it is)
    static function startSession(client:Socket, host:Bool) {
        session++;
        var mySession:Int = session;
        mutex.acquire();
        incomingMessages = [];
        timeSamples = [];
        mutex.release();
        pendingLoadSong = null;
        latency = 0;
        recentPings = [];

        socket = client;
        isHost = host;
        busy = false;
        connected = true;
        listenToSocket(client, mySession);
    }

    static function closeQuietly(target:Socket) {
        if (target == null) return;
        try { target.close(); } catch(e:Dynamic) {}
    }
    #end

    // ==========================================
    // SISTEMA DE ESCUTA INVISÍVEL
    // ==========================================
    #if sys
    // On the thread of the connection, with the connection itself: a newer one never gets read by this one
    static function listenToSocket(client:Socket, mySession:Int) {
        while (mySession == session) {
            var msg:String = null;
            try {
                msg = client.input.readLine(); // Fica escutando...
            } catch(e:Dynamic) {
                if (mySession == session) {
                    connected = false;
                    statusString = "Conexao Perdida.";
                }
                break;
            }
            if (msg == null || mySession != session) continue;
            msg = StringTools.replace(msg, "\r", "");

            if (testDelay > 0) {
                // (in order, like a real connection: one late message doesn't get passed by the next one)
                var deliverAt:Float = haxe.Timer.stamp() + (testDelay + Math.random() * testJitter) / 1000;
                if (deliverAt < lastDelivery) deliverAt = lastDelivery;
                lastDelivery = deliverAt;
                var wait:Float = deliverAt - haxe.Timer.stamp();
                if (wait > 0) Sys.sleep(wait);
            }

            // what's answered right here, or kept for whichever screen asks for it
            var name:String = msg.split("|")[0];
            switch (name) {
                case "PING":
                    sendNow("PONG|" + msg.substr(5));
                case "PONG":
                    var sent:Float = Std.parseFloat(msg.substr(5));
                    if (!Math.isNaN(sent)) {
                        // the lowest of the last few: a ping that came late because a game was busy (loading...) isn't the network
                        recentPings.push(Math.max(0, (haxe.Timer.stamp() * 1000 - sent) / 2));
                        if (recentPings.length > 5) recentPings.shift();
                        var lowest:Float = recentPings[0];
                        for (ping in recentPings) if (ping < lowest) lowest = ping;
                        latency = lowest;
                    }
                case "NICK_EXCHANGE":
                    var nick:String = msg.substr(name.length + 1);
                    if (nick.length > 0) opponentNickname = nick;
                case "SYNC_TIME":
                    // where the host's song was, and when that got here (the game reads it a frame later, or more)
                    var hostTime:Float = Std.parseFloat(msg.substr(10));
                    if (!Math.isNaN(hostTime)) {
                        mutex.acquire();
                        timeSamples.push({time: hostTime, arrival: haxe.Timer.stamp()});
                        if (timeSamples.length > 16) timeSamples.shift();
                        mutex.release();
                    }
                case "LOADSONG":
                    pendingLoadSong = msg;
                    log('received ' + msg);
                case "BYE":
                    connected = false;
                    statusString = "O outro jogador saiu.";
                    break;
                default:
                    mutex.acquire();
                    incomingMessages.push(msg); // Guarda a mensagem para o jogo ler no Update()
                    mutex.release();
            }
        }
        closeQuietly(client);
    }
    #end

    // ==========================================
    // ENVIAR DADOS
    // ==========================================
    public static function send(msg:String) {
        #if sys
        if (connected && socket != null) sendNow(msg);
        #end
    }

    #if sys
    static function sendNow(msg:String) {
        var target:Socket = socket;
        if (target == null) return;
        sendMutex.acquire();
        try {
            target.output.writeString(msg + "\n");
            target.output.flush(); // Empurra a mensagem pela rede instantaneamente
        } catch(e:Dynamic) {}
        sendMutex.release();
    }
    #end

    // Pega as mensagens para o jogo rodar (e limpa a fila)
    public static function getNewMessages():Array<String> {
        var msgs:Array<String> = [];
        #if sys
        mutex.acquire();
        if (incomingMessages.length > 0) {
            msgs = incomingMessages;
            incomingMessages = [];
        }
        mutex.release();
        #end
        return msgs;
    }

    /**
     * The song the host asked for ("LOADSONG|..."), if one came and the lobby didn't take it yet. Taking it clears it.
     */
    public static function takePendingLoadSong():String {
        var msg:String = pendingLoadSong;
        pendingLoadSong = null;
        return msg;
    }

    // A ping every couple of seconds while connected, to know the latency (see `latency`). On the game's thread
    static var pinging:Bool = false;
    static var lastPing:Float = 0;
    static function startPinging() {
        if (pinging) return;
        pinging = true;
        flixel.FlxG.signals.preUpdate.add(function() {
            if (!connected) return;
            var now:Float = haxe.Timer.stamp();
            if (now - lastPing < 2) return;
            lastPing = now;
            send("PING|" + (now * 1000));
        });
    }

    /**
     * A nickname that can go in a message: without the separator, and not empty.
     */
    public static function cleanNickname(name:String):String {
        if (name == null) return "Player";
        name = StringTools.trim(StringTools.replace(StringTools.replace(name, "|", ""), "\n", ""));
        return (name.length > 0) ? name : "Player";
    }

    /**
     * A number that came in a message, or null if it isn't one (or isn't within `min`...`max`).
     */
    public static function readInt(value:String, min:Int = 0, max:Int = 3):Null<Int> {
        var number:Null<Int> = (value != null) ? Std.parseInt(value) : null;
        return (number != null && number >= min && number <= max) ? number : null;
    }

    // ==========================================
    // SINCRONIZAÇÃO DE PLAYSTATE
    // ==========================================

    // O Host envia a música, a dificuldade (o número e o nome), se ele quer ser o 'bf' ou o 'dad', a pasta do mod da música e
    // como se ganha a partida (see `winCondition`)
    public static function sendLoadSong(songName:String, difficulty:Int, hostRole:String, ?difficultyName:String, ?folder:String, ?condition:String) {
        // Exemplo: LOADSONG|Bopeebo|1|dad|Normal||score
        send("LOADSONG|" + songName + "|" + difficulty + "|" + hostRole + "|" + (difficultyName != null ? difficultyName : "") + "|" + (folder != null ? folder : "")
            + "|" + (condition != null ? condition : winCondition));
    }

    // ==========================================
    // COMO SE GANHA A PARTIDA
    // ==========================================
    /**
     * How the match is won when nobody is knocked out (being knocked out always loses): "score" (the most points wins), "misses"
     * (the one who misses the most loses) or "accuracy" (the most accurate wins). The host picks it, it comes with the song.
     */
    public static var winCondition:String = 'score';
    public static final WIN_CONDITIONS:Array<String> = ['score', 'misses', 'accuracy'];

    public static function winConditionName(condition:String):String {
        return switch (condition) {
            case 'misses': 'Misses';
            case 'accuracy': 'Accuracy';
            default: 'Score';
        }
    }

    public static function winConditionInfo(condition:String):String {
        return switch (condition) {
            case 'misses': 'The one who misses the most loses';
            case 'accuracy': 'The most accurate one wins';
            default: 'The one who scores the most wins';
        }
    }

    public static function validCondition(condition:String):String {
        return (condition != null && WIN_CONDITIONS.contains(condition)) ? condition : 'score';
    }

    /**
     * Who's ahead by the match's condition: 1 if `a` is, -1 if `b` is, 0 if they're even in everything. A tie on the condition is
     * broken by the other two (score, then misses, then accuracy). `decidedBy` says which one decided it.
     * Accuracy is a percent, or less than 0 for someone who hasn't hit a note yet.
     */
    public static function compareResults(a:{score:Int, misses:Int, accuracy:Float}, b:{score:Int, misses:Int, accuracy:Float}, ?condition:String):{result:Int, decidedBy:String} {
        if (condition == null) condition = winCondition;
        var order:Array<String> = switch (condition) {
            case 'misses': ['misses', 'score', 'accuracy'];
            case 'accuracy': ['accuracy', 'score', 'misses'];
            default: ['score', 'misses', 'accuracy'];
        }
        for (what in order) {
            var result:Int = switch (what) {
                case 'misses': (a.misses < b.misses) ? 1 : ((a.misses > b.misses) ? -1 : 0);
                case 'accuracy':
                    // (to the hundredth, the way it's shown)
                    var accA:Int = Math.round(Math.max(a.accuracy, 0) * 100);
                    var accB:Int = Math.round(Math.max(b.accuracy, 0) * 100);
                    (accA > accB) ? 1 : ((accA < accB) ? -1 : 0);
                default: (a.score > b.score) ? 1 : ((a.score < b.score) ? -1 : 0);
            }
            if (result != 0) return {result: result, decidedBy: what};
        }
        return {result: 0, decidedBy: condition};
    }

    public static function prepareToPlay() {
        if (flixel.FlxG.sound.music != null) {
            flixel.FlxG.sound.music.stop();
        }
    }

    public static function sendDeath() {
        send("PLAYER_DIED");
    }

    // ==========================================
    // CONFIGURAÇÕES DA PARTIDA
    // ==========================================
    // Both players play the same song the same way: what changes the song itself (its speed, botplay, practice, health) is
    // the same for both during a match, and goes back to what the player had afterwards. The copy of what they had is also
    // kept on the save, in case the game is closed during a match (see `restoreSettings()`, called when the game starts too).
    static final MATCH_SETTINGS:Map<String, Dynamic> = [
        'songspeed' => 1.0,
        'healthgain' => 1.0,
        'healthloss' => 1.0,
        'instakill' => false,
        'practice' => false,
        'botplay' => false
    ];

    public static function applyMatchSettings(playAsOpponent:Bool) {
        var settings:Map<String, Dynamic> = ClientPrefs.data.gameplaySettings;
        if (flixel.FlxG.save.data.multiplayerSettingsBackup == null) {
            var backup:Dynamic = {};
            for (key in MATCH_SETTINGS.keys()) Reflect.setField(backup, key, settings.get(key));
            Reflect.setField(backup, 'playasopponent', settings.get('playasopponent'));
            flixel.FlxG.save.data.multiplayerSettingsBackup = backup;
            flixel.FlxG.save.flush();
        }
        for (key => value in MATCH_SETTINGS) settings.set(key, value);
        settings.set('playasopponent', playAsOpponent);
        if (testBotplay) settings.set('botplay', true);
    }

    public static function restoreSettings() {
        var backup:Dynamic = flixel.FlxG.save.data.multiplayerSettingsBackup;
        if (backup == null) return;

        var settings:Map<String, Dynamic> = ClientPrefs.data.gameplaySettings;
        for (key in Reflect.fields(backup)) {
            var value:Dynamic = Reflect.field(backup, key);
            if (value != null) settings.set(key, value);
        }
        flixel.FlxG.save.data.multiplayerSettingsBackup = null;
        ClientPrefs.saveSettings();
    }
}
