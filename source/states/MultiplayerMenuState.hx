package states;

import backend.NetworkManager;
import backend.Highscore;
import backend.Song;
import backend.ClientPrefs;
import backend.WeekData;
import backend.Difficulty;
import objects.HealthIcon;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.events.KeyboardEvent;

class MultiplayerMenuState extends MusicBeatState
{
    var titleText:FlxText;
    var statusText:FlxText;

    var connectionMenu:flixel.group.FlxGroup.FlxTypedGroup<Alphabet>;
    var connOptions:Array<String> = ['Host Game', 'Join Game'];
    var curConnSelected:Int = 0;

    var hostLobby:flixel.group.FlxGroup.FlxTypedGroup<Alphabet>;
    var songList:Array<String> = [];
    // the week and the mod folder of each song of the list, to find the same one on the other PC
    var songWeeks:Array<String> = [];
    var songFolders:Array<String> = [];
    var iconArray:Array<HealthIcon> = [];
    var curSongSelected:Int = 0;

    var diffText:FlxText;
    var curDifficulty:Int = 1;

    var nicknameText:FlxText;
    var hostRoleText:FlxText;
    var hostRoleHintText:FlxText;
    var currentRole:String = 'bf';

    var clientWaitText:FlxText;
    var inLobby:Bool = false;

    var typingIP:Bool = false;
    var typedIP:String = "";
    var typingNickname:Bool = false;
    var typedNickname:String = "";
    var promptText:FlxText;

    // Test runs (see DirectPlay): the host picks this song as soon as the other player is there
    public static var testSong:String = null;
    public static var testDifficulty:String = null;
    public static var testRole:String = 'bf';
    public static var testRounds:Int = 1;

    // a message for a few seconds under the status (a song that couldn't be opened...)
    var noticeTime:Float = 0;
    var notice:String = null;

    override function create()
    {
        // what the player had before the match (see NetworkManager.applyMatchSettings())
        NetworkManager.restoreSettings();

        if(FlxG.save.data.multiplayerNickname != null) {
            NetworkManager.myNickname = NetworkManager.cleanNickname(FlxG.save.data.multiplayerNickname);
        }

        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF5a5a5a;
        bg.screenCenter();
        add(bg);

        titleText = new FlxText(0, 20, FlxG.width, "LOBBY", 48);
        titleText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(titleText);

        statusText = new FlxText(0, 80, FlxG.width, NetworkManager.statusString, 32);
        statusText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(statusText);

        diffText = new FlxText(FlxG.width - 400, 20, 380, "< HARD >", 36);
        diffText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        diffText.visible = false;
        add(diffText);

        nicknameText = new FlxText(FlxG.width - 400, 70, 380, "Nick: " + NetworkManager.myNickname + "\n[TAB] To Change", 24);
        nicknameText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.CYAN, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(nicknameText);

        #if MODS_ALLOWED
        var oldModDir:String = backend.Mods.currentModDirectory;
        #end

        WeekData.reloadWeekFiles(false);
        for (i in 0...WeekData.weeksList.length) {
            var week:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
            if (week != null && week.songs != null) {
                #if MODS_ALLOWED
                backend.Mods.currentModDirectory = week.folder;
                #end
                for (j in 0...week.songs.length) {
                    var songName:String = week.songs[j][0];
                    var iconName:String = week.songs[j][1];
                    if (songList.indexOf(songName) == -1) {
                        songList.push(songName);
                        songWeeks.push(WeekData.weeksList[i]);
                        songFolders.push(week.folder != null ? week.folder : "");
                        var icon:HealthIcon = new HealthIcon(iconName);
                        iconArray.push(icon);
                    }
                }
            }
        }

        #if MODS_ALLOWED
        backend.Mods.currentModDirectory = oldModDir;
        #end

        if (songList.length == 0) {
            songList = ['Bopeebo'];
            songWeeks = [""];
            songFolders = [""];
        }

        hostLobby = new flixel.group.FlxGroup.FlxTypedGroup<Alphabet>();
        add(hostLobby);

        for (i in 0...songList.length) {
            var songText:Alphabet = new Alphabet(90, 320, songList[i], true);
            songText.targetY = i;
            hostLobby.add(songText);

            var icon = iconArray[i];
            if (icon != null) {
                add(icon);
                icon.visible = false;
            }
        }

        // As músicas só aparecem no lobby do host
        hostLobby.visible = false;

        connectionMenu = new flixel.group.FlxGroup.FlxTypedGroup<Alphabet>();
        add(connectionMenu);

        for (i in 0...connOptions.length) {
            // (a menu item goes to its start position plus how far it is from the selected one: they all start at the same place)
            var text:Alphabet = new Alphabet(0, 300, connOptions[i], true);
            text.isMenuItem = true;
            text.targetY = i;
            text.screenCenter(X);
            text.startPosition.x = text.x;
            text.snapToPosition();
            connectionMenu.add(text);
        }

        promptText = new FlxText(0, 350, FlxG.width, "", 32);
        promptText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        promptText.visible = false;
        add(promptText);

        clientWaitText = new FlxText(0, 400, FlxG.width, "Waiting for Host...\n\n(ESC to leave)", 32);
        clientWaitText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        clientWaitText.visible = false;
        add(clientWaitText);

        hostRoleText = new FlxText(0, FlxG.height - 100, FlxG.width, "< Playing with: Right Side (BF) >", 32);
        hostRoleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.LIME, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        hostRoleText.visible = false;
        add(hostRoleText);

        hostRoleHintText = new FlxText(0, FlxG.height - 60, FlxG.width, "(Press SHIFT to change character)", 20);
        hostRoleHintText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        hostRoleHintText.visible = false;
        add(hostRoleHintText);

        changeConnSelection(0);
        super.create();

        FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onTextInput);
    }

    override function destroy() {
        FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onTextInput);
        super.destroy();
    }

    // Captura APENAS o texto digitado aqui. Os botões de controle (ENTER, ESC) ficam no update().
    function onTextInput(e:KeyboardEvent) {
        if (typingNickname) {
            if (e.charCode >= 32 && e.charCode <= 126 && e.charCode != 124 && typedNickname.length < 15) { //(124 is "|", which separates the messages)
                typedNickname += String.fromCharCode(e.charCode);
            }
        }
        else if (typingIP) {
            if (((e.charCode >= 48 && e.charCode <= 57) || e.charCode == 46) && typedIP.length < 39) {
                typedIP += String.fromCharCode(e.charCode);
            }
        }
    }

    function showNotice(text:String) {
        notice = text;
        noticeTime = 5;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        var status:String = NetworkManager.statusString;
        if (NetworkManager.connected) {
            status += "  (vs " + NetworkManager.opponentNickname + ")";
            if (NetworkManager.latency > 0) status += "  Ping: " + Math.round(NetworkManager.latency * 2) + "ms";
        }
        if (noticeTime > 0) {
            noticeTime -= elapsed;
            status = notice;
        }
        statusText.text = status;

        // A conexão caiu (ou o outro saiu): de volta à escolha de criar ou entrar
        if (inLobby && !NetworkManager.connected) {
            leaveLobby();
        }

        if (NetworkManager.connected && !inLobby) {
            inLobby = true;
            NetworkManager.log('in the lobby (' + (NetworkManager.isHost ? 'host' : 'client') + '), playing against ' + NetworkManager.opponentNickname);
            connectionMenu.visible = false;
            promptText.visible = false;
            typingIP = false;

            NetworkManager.send("NICK_EXCHANGE|" + NetworkManager.myNickname);

            if (NetworkManager.isHost) {
                hostLobby.visible = true;
                diffText.visible = true;
                hostRoleText.visible = true;
                hostRoleHintText.visible = true;
                changeSongSelection(0);

                if (testSong != null && testRounds > 0) {
                    testRounds--;
                    var index:Int = findSong(testSong, null);
                    for (i in 0...songList.length)
                        if (Paths.formatToSongPath(songList[i]) == Paths.formatToSongPath(testSong)) index = i;
                    if (index > -1) {
                        changeSongSelection(index - curSongSelected);
                        if (testDifficulty != null)
                            for (i in 0...Difficulty.list.length)
                                if (Difficulty.list[i].toLowerCase() == testDifficulty.toLowerCase()) curDifficulty = i;
                        currentRole = testRole;
                        var chosen:String = songList[curSongSelected];
                        var diffName:String = Difficulty.list[curDifficulty];
                        var role:String = currentRole;
                        // (a moment for the other player to be in the lobby too)
                        new flixel.util.FlxTimer().start(1, function(_) {
                            forceLoadSong(curSongSelected, curDifficulty, (role == 'dad'), function() {
                                NetworkManager.log('asking for ' + chosen + ' (' + diffName + ')');
                                NetworkManager.sendLoadSong(chosen, curDifficulty, role, diffName, songFolders[curSongSelected]);
                            });
                        });
                    }
                }
            } else {
                clientWaitText.visible = true;
            }
        }

        if (inLobby && NetworkManager.isHost && !typingNickname) {
            var lerpVal:Float = FlxMath.bound(elapsed * 9.6, 0, 1);
            for (i in 0...hostLobby.length) {
                var item = hostLobby.members[i];
                var icon = iconArray[i];
                var intendedY = 320 + (item.targetY * 130);

                // (only what's near the screen moves: there can be hundreds of songs with mods)
                if (Math.abs(item.targetY) > 6 && (item.y < -400 || item.y > FlxG.height + 400)) {
                    item.y = intendedY;
                    if (icon != null) icon.visible = false;
                    continue;
                }

                item.y = FlxMath.lerp(item.y, intendedY, lerpVal);
                item.x = FlxMath.lerp(item.x, 90 + (Math.abs(item.targetY) * 20), lerpVal);

                if (icon != null) {
                    icon.visible = true;
                    icon.alpha = item.alpha;
                    icon.x = item.x + item.width + 10;
                    icon.y = item.y - 15;
                }
            }
        }

        if (NetworkManager.connected) {
            // (the messages of the match that was just played, which nobody needs anymore)
            NetworkManager.getNewMessages();

            var loadMsg:String = NetworkManager.takePendingLoadSong();
            if (loadMsg != null && !NetworkManager.isHost) {
                var data = loadMsg.split("|");
                var songName = data[1];
                var difficulty:Null<Int> = Std.parseInt(data[2]);
                var receivedHostRole = data[3];
                var diffName:String = (data.length > 4) ? data[4] : "";
                var folder:String = (data.length > 5) ? data[5] : "";

                var index:Int = findSong(songName, folder);
                if (index > -1) selectWeekOf(index);
                else Difficulty.loadFromWeek();

                // (the host's difficulty by its name, the number could be another one here)
                if (diffName.length > 0) {
                    for (i in 0...Difficulty.list.length) {
                        if (Difficulty.list[i].toLowerCase() == diffName.toLowerCase()) {
                            difficulty = i;
                            break;
                        }
                    }
                }
                if (difficulty == null) difficulty = 0;

                var imTheOpponent:Bool = (receivedHostRole == 'bf');
                if (index < 0 || !forceLoadSong(index, difficulty, imTheOpponent)) {
                    NetworkManager.send("LOAD_FAILED|" + songName);
                    showNotice("Nao foi possivel abrir \"" + songName + "\" (o mod esta instalado?)");
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                }
            }
        }

        if (FlxG.keys.justPressed.TAB && !typingIP && !typingNickname) {
            typingNickname = true;
            typedNickname = NetworkManager.myNickname;
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        // =======================================================
        // O CONTROLE BLINDADO DAS CAIXAS DE TEXTO
        // =======================================================
        if (typingNickname)
        {
            var cursor = (Math.floor(FlxG.game.ticks / 500) % 2 == 0) ? "_" : "";
            promptText.text = "Type your nickname:\n\n" + typedNickname + cursor + "\n\n(Press ENTER to save or ESC to cancel)";
            promptText.visible = true;
            connectionMenu.visible = false;
            clientWaitText.visible = false;
            if (hostLobby != null) hostLobby.visible = false;
            for (icon in iconArray) if (icon != null) icon.visible = false; //(the lobby shows them again)

            if (FlxG.keys.justPressed.BACKSPACE && typedNickname.length > 0) {
                typedNickname = typedNickname.substring(0, typedNickname.length - 1);
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }
            else if (FlxG.keys.justPressed.ESCAPE) {
                typingNickname = false;
                restoreScreen();
                FlxG.sound.play(Paths.sound('cancelMenu'));
            }
            else if (FlxG.keys.justPressed.ENTER) {
                typingNickname = false;
                restoreScreen();

                typedNickname = NetworkManager.cleanNickname(typedNickname);
                NetworkManager.myNickname = typedNickname;
                FlxG.save.data.multiplayerNickname = typedNickname;
                FlxG.save.flush();
                nicknameText.text = "Nick: " + typedNickname + "\n[TAB] To Change";
                FlxG.sound.play(Paths.sound('confirmMenu'));

                if (NetworkManager.connected) NetworkManager.send("NICK_EXCHANGE|" + typedNickname);
            }
            return; // TRAVA a função inteira! O enter não vai vazar pras músicas.
        }
        else if (typingIP)
        {
            var cursor = (Math.floor(FlxG.game.ticks / 500) % 2 == 0) ? "_" : "";
            promptText.text = "Type HOST IP (Radmin/Hamachi):\n\n" + typedIP + cursor + "\n\n(Press ENTER to connect or ESC to back)";
            promptText.visible = true;

            if (FlxG.keys.justPressed.BACKSPACE && typedIP.length > 0) {
                typedIP = typedIP.substring(0, typedIP.length - 1);
                FlxG.sound.play(Paths.sound('scrollMenu'));
            }
            else if (FlxG.keys.justPressed.ESCAPE) {
                typingIP = false;
                promptText.visible = false;
                connectionMenu.visible = true;
                FlxG.sound.play(Paths.sound('cancelMenu'));
            }
            else if (FlxG.keys.justPressed.ENTER && typedIP.length > 0) {
                typingIP = false;
                promptText.visible = false;
                connectionMenu.visible = true;
                FlxG.sound.play(Paths.sound('confirmMenu'));
                NetworkManager.joinServer(typedIP);
            }
            return; // TRAVA a função inteira! O enter não vai conectar no Vazio.
        }
        // =======================================================
        else if (!inLobby)
        {
            // Esperando alguém entrar (ou o host responder): ESC cancela
            if (NetworkManager.busy) {
                if (controls.BACK) {
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                    NetworkManager.cancel();
                }
                return;
            }

            if (controls.UI_UP_P) changeConnSelection(-1);
            if (controls.UI_DOWN_P) changeConnSelection(1);

            if (controls.ACCEPT) {
                FlxG.sound.play(Paths.sound('confirmMenu'));
                if (curConnSelected == 0) NetworkManager.hostServer();
                else {
                    typingIP = true;
                    typedIP = "";
                    promptText.visible = true;
                    connectionMenu.visible = false;
                }
            }

            if (controls.BACK) {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                MusicBeatState.switchState(new MainMenuState());
            }
        }
        else if (inLobby && NetworkManager.isHost)
        {
            if (controls.UI_UP_P) changeSongSelection(-1);
            if (controls.UI_DOWN_P) changeSongSelection(1);
            if (controls.UI_LEFT_P) changeDifficulty(-1);
            if (controls.UI_RIGHT_P) changeDifficulty(1);

            if (FlxG.keys.justPressed.SHIFT || FlxG.keys.justPressed.CONTROL) {
                FlxG.sound.play(Paths.sound('scrollMenu'));
                if (currentRole == 'bf') {
                    currentRole = 'dad';
                    hostRoleText.text = "< Playing with: Left Side (DAD) >";
                    hostRoleText.color = FlxColor.RED;
                } else {
                    currentRole = 'bf';
                    hostRoleText.text = "< Playing with: Right Side (BF) >";
                    hostRoleText.color = FlxColor.LIME;
                }
            }

            if (controls.ACCEPT) {
                var chosenSong = songList[curSongSelected];
                var diffName:String = Difficulty.list[curDifficulty];
                // The host's chart has to load before the other player is asked for it (or both would wait for each other)
                if (forceLoadSong(curSongSelected, curDifficulty, (currentRole == 'dad'), function() {
                    NetworkManager.sendLoadSong(chosenSong, curDifficulty, currentRole, diffName, songFolders[curSongSelected]);
                })) {
                    FlxG.sound.play(Paths.sound('confirmMenu'));
                } else {
                    showNotice("Nao foi possivel abrir \"" + chosenSong + "\" nessa dificuldade.");
                    FlxG.sound.play(Paths.sound('cancelMenu'));
                }
            }

            if (controls.BACK) {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                NetworkManager.disconnect();
                MusicBeatState.switchState(new MainMenuState());
            }
        }
        else if (inLobby)
        {
            // O cliente também pode sair do lobby
            if (controls.BACK) {
                FlxG.sound.play(Paths.sound('cancelMenu'));
                NetworkManager.disconnect();
                leaveLobby();
            }
        }
    }

    // What was on the screen before typing a nickname
    function restoreScreen() {
        promptText.visible = false;
        if (!inLobby) connectionMenu.visible = true;
        else if (NetworkManager.isHost) hostLobby.visible = true;
        else clientWaitText.visible = true;
    }

    // Back to choosing to host or to join (the connection is gone)
    function leaveLobby() {
        NetworkManager.log('left the lobby: ' + NetworkManager.statusString);
        inLobby = false;
        hostLobby.visible = false;
        diffText.visible = false;
        hostRoleText.visible = false;
        hostRoleHintText.visible = false;
        clientWaitText.visible = false;
        for (icon in iconArray) if (icon != null) icon.visible = false;
        connectionMenu.visible = !typingNickname;
        NetworkManager.restoreSettings();
    }

    // The song of the list with that name, the one of that mod's folder if there's more than one. -1 if it's not here
    function findSong(songName:String, folder:String):Int {
        var found:Int = -1;
        for (i in 0...songList.length) {
            if (songList[i] != songName) continue;
            if (folder == null || folder.length < 1 || songFolders[i] == folder) return i;
            if (found < 0) found = i;
        }
        return found;
    }

    // The difficulties of the week of a song of the list
    function selectWeekOf(index:Int) {
        var week:WeekData = (songWeeks[index] != null && songWeeks[index].length > 0) ? WeekData.weeksLoaded.get(songWeeks[index]) : null;
        #if MODS_ALLOWED
        backend.Mods.currentModDirectory = songFolders[index];
        #end
        if (week != null) Difficulty.loadFromWeek(week);
        else Difficulty.loadFromWeek();
    }

    function changeSongSelection(change:Int) {
        if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
        curSongSelected += change;
        if (curSongSelected < 0) curSongSelected = songList.length - 1;
        if (curSongSelected >= songList.length) curSongSelected = 0;

        for (i in 0...hostLobby.length) {
            var item = hostLobby.members[i];
            item.targetY = i - curSongSelected;
            item.alpha = (item.targetY == 0) ? 1 : 0.6;
        }

        selectWeekOf(curSongSelected);

        curDifficulty = 0;
        for (i in 0...Difficulty.list.length) {
            if (Difficulty.list[i] == 'Hard') {
                curDifficulty = i;
                break;
            }
        }
        changeDifficulty(0);
    }

    function changeDifficulty(change:Int) {
        if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));
        curDifficulty += change;
        if (curDifficulty < 0) curDifficulty = Difficulty.list.length - 1;
        if (curDifficulty >= Difficulty.list.length) curDifficulty = 0;

        var diffName = Difficulty.list[curDifficulty];
        if (diffName == null) diffName = 'Normal';

        diffText.text = '< ' + diffName.toUpperCase() + ' >';
        diffText.x = FlxG.width - diffText.width - 20;
    }

    /**
     * Opens a song of the list, the way the Freeplay menu does. False if its chart couldn't be read (nothing happens then).
     * `onLoaded` is called once the chart was read, right before going to the song.
     */
    function forceLoadSong(index:Int, diffIndex:Int, playAsOpponent:Bool, ?onLoaded:Void->Void):Bool {
        var songName:String = songList[index];
        selectWeekOf(index);

        var formatSong = Paths.formatToSongPath(songName);
        var poops:String = Highscore.formatSong(formatSong, diffIndex);

        try {
            Song.loadFromJson(poops, formatSong);
        } catch(e:Dynamic) {
            try { Song.loadFromJson(formatSong, formatSong); }
            catch(e2:Dynamic) { trace('Multiplayer: could not load "$songName": $e2'); return false; }
        }
        if (PlayState.SONG == null) return false;

        if (onLoaded != null) onLoaded();

        NetworkManager.prepareToPlay();
        NetworkManager.applyMatchSettings(playAsOpponent);

        PlayState.isStoryMode = false;
        PlayState.storyDifficulty = diffIndex;
        var weekIndex:Int = WeekData.weeksList.indexOf(songWeeks[index]);
        if (weekIndex > -1) PlayState.storyWeek = weekIndex;

        @:privateAccess
        if (PlayState._lastLoadedModDirectory != backend.Mods.currentModDirectory) Paths.freeGraphicsFromMemory();
        LoadingState.prepareToSong();
        LoadingState.loadAndSwitchState(new PlayState());
        return true;
    }

    function changeConnSelection(change:Int) {
        curConnSelected += change;
        if (curConnSelected < 0) curConnSelected = connOptions.length - 1;
        if (curConnSelected >= connOptions.length) curConnSelected = 0;

        for (i in 0...connectionMenu.length) {
            var item = connectionMenu.members[i];
            item.targetY = i - curConnSelected;
            item.alpha = (item.targetY == 0) ? 1 : 0.6;
        }
    }
}
