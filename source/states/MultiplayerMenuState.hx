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
    // A text of the online menus in the game's language (English if it has no translation: see "online_" in the .lang files)
    public static function t(key:String, english:String, ?values:Array<Dynamic>):String
        return Language.getPhrase('online_' + key, english, values);

    var titleText:FlxText;
    var statusText:FlxText;

    var connectionMenu:flixel.group.FlxGroup.FlxTypedGroup<Alphabet>;
    var connOptions:Array<String> = [t('host_game', 'Host Game'), t('join_game', 'Join Game')];
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
    public static var testWinCondition:String = null;

    // The match's setup, after the host picks a song: how it's won and who plays which side. The one who joined sees it as the
    // host changes it ("LOBBY_VIEW" says if it's open and the condition)
    var setupPanel:flixel.group.FlxGroup;
    var setupTitle:FlxText;
    var setupSong:FlxText;
    var setupCondition:FlxText;
    var setupConditionInfo:FlxText;
    var setupSide:FlxText;
    var setupHint:FlxText;
    var configuring:Bool = false;
    var setupRow:Int = 0;
    var winCondition:String = 'score';
    // (the one who joined: if the host has the setup open)
    var hostConfiguring:Bool = false;

    // What the host has selected, sent to the other player as it changes ("LOBBY_VIEW|song|mod folder|difficulty|host's side"):
    // the one who joined watches the host choose. The last one sent, to not send the same again
    var lastLobbyView:String = null;
    // (the one who joined: if a view of the host's list came already)
    var gotLobbyView:Bool = false;

    // a message for a few seconds under the status (a song that couldn't be opened...)
    var noticeTime:Float = 0;
    var notice:String = null;

    override function create()
    {
        // what the player had before the match (see NetworkManager.applyMatchSettings())
        NetworkManager.restoreSettings();

        if(!NetworkManager.connected && !NetworkManager.busy && NetworkManager.statusString == "Disconnected")
            NetworkManager.statusString = Language.getPhrase('online_status_disconnected', "Disconnected");

        if(FlxG.save.data.multiplayerNickname != null) {
            NetworkManager.myNickname = NetworkManager.cleanNickname(FlxG.save.data.multiplayerNickname);
        }

        var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        bg.color = 0xFF5a5a5a;
        bg.screenCenter();
        add(bg);

        titleText = new FlxText(0, 20, FlxG.width, t('lobby', "LOBBY"), 48);
        titleText.setFormat(Paths.font("vcr.ttf"), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(titleText);

        statusText = new FlxText(0, 80, FlxG.width, NetworkManager.statusString, 32);
        statusText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        add(statusText);

        diffText = new FlxText(FlxG.width - 400, 20, 380, "< HARD >", 36);
        diffText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        diffText.visible = false;
        add(diffText);

        nicknameText = new FlxText(FlxG.width - 400, 70, 380, t('nick', "Nick: {1}\n[TAB] To Change", [NetworkManager.myNickname]), 24);
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

        clientWaitText = new FlxText(0, 400, FlxG.width, t('waiting_host', "Waiting for Host...\n\n(ESC to leave)"), 32);
        clientWaitText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.CYAN, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        clientWaitText.visible = false;
        add(clientWaitText);

        hostRoleText = new FlxText(0, FlxG.height - 100, FlxG.width, t('playing_right', t('playing_right', "< Playing with: Right Side (BF) >")), 32);
        hostRoleText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.LIME, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        hostRoleText.visible = false;
        add(hostRoleText);

        hostRoleHintText = new FlxText(0, FlxG.height - 60, FlxG.width, t('shift_hint', "(Press SHIFT to change character)"), 20);
        hostRoleHintText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        hostRoleHintText.visible = false;
        add(hostRoleHintText);

        makeSetupPanel();

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
            status += t('vs', "  (vs {1})", [NetworkManager.opponentNickname]);
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
                        if (testWinCondition != null) winCondition = NetworkManager.validCondition(testWinCondition);
                        NetworkManager.winCondition = winCondition;
                        var chosen:String = songList[curSongSelected];
                        var diffName:String = Difficulty.list[curDifficulty];
                        var role:String = currentRole;
                        var condition:String = winCondition;
                        // (a moment for the other player to be in the lobby too)
                        new flixel.util.FlxTimer().start(1, function(_) {
                            forceLoadSong(curSongSelected, curDifficulty, (role == 'dad'), function() {
                                NetworkManager.log('asking for ' + chosen + ' (' + diffName + ')');
                                NetworkManager.sendLoadSong(chosen, curDifficulty, role, diffName, songFolders[curSongSelected], condition);
                            });
                        });
                    }
                }
                sendLobbyView();
            } else {
                clientWaitText.visible = true;
                gotLobbyView = false;
                // (the host answers with what it has selected, see sendLobbyView())
                NetworkManager.send("LOBBY_ASK");
            }
        }

        if (inLobby && hostLobby.visible && !typingNickname) {
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
                // (the ones going up fade away before they get to the title and the status, and the ones going down before the
                // texts of the sides at the bottom)
                item.alpha = ((item.targetY == 0) ? 1 : 0.6) * FlxMath.bound((item.y - 120) / 70, 0, 1)
                    * FlxMath.bound((FlxG.height - 170 - item.y) / 70, 0, 1);

                if (icon != null) {
                    icon.visible = true;
                    icon.alpha = item.alpha;
                    icon.x = item.x + item.width + 10;
                    icon.y = item.y - 15;
                }
            }
        }

        if (NetworkManager.connected) {
            // (the messages of the match that was just played, which nobody needs anymore, are skipped)
            var lobbyView:String = null;
            for (msg in NetworkManager.getNewMessages()) {
                if (msg == "LOBBY_ASK" && NetworkManager.isHost && inLobby) {
                    lastLobbyView = null;
                    sendLobbyView();
                }
                else if (StringTools.startsWith(msg, "LOBBY_VIEW|") && !NetworkManager.isHost) lobbyView = msg;
            }
            if (lobbyView != null && inLobby) showLobbyView(lobbyView);

            var loadMsg:String = NetworkManager.takePendingLoadSong();
            if (loadMsg != null && !NetworkManager.isHost) {
                var data = loadMsg.split("|");
                var songName = data[1];
                var difficulty:Null<Int> = Std.parseInt(data[2]);
                var receivedHostRole = data[3];
                var diffName:String = (data.length > 4) ? data[4] : "";
                var folder:String = (data.length > 5) ? data[5] : "";
                NetworkManager.winCondition = NetworkManager.validCondition((data.length > 6) ? data[6] : null);

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
                    showNotice(t('cant_open_mod', "Couldn't open \"{1}\" (is the mod installed?)", [songName]));
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
            promptText.text = t('type_nick', "Type your nickname:\n\n{1}\n\n(Press ENTER to save or ESC to cancel)", [typedNickname + cursor]);
            promptText.visible = true;
            connectionMenu.visible = false;
            clientWaitText.visible = false;
            if (hostLobby != null) hostLobby.visible = false;
            if (setupPanel != null) setupPanel.visible = false;
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
                nicknameText.text = t('nick', "Nick: {1}\n[TAB] To Change", [typedNickname]);
                FlxG.sound.play(Paths.sound('confirmMenu'));

                if (NetworkManager.connected) NetworkManager.send("NICK_EXCHANGE|" + typedNickname);
            }
            return; // TRAVA a função inteira! O enter não vai vazar pras músicas.
        }
        else if (typingIP)
        {
            var cursor = (Math.floor(FlxG.game.ticks / 500) % 2 == 0) ? "_" : "";
            promptText.text = t('type_ip', "Type HOST IP (Radmin/Hamachi):\n\n{1}\n\n(Press ENTER to connect or ESC to back)", [typedIP + cursor]);
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
        else if (inLobby && NetworkManager.isHost && configuring)
        {
            updateSetup();
        }
        else if (inLobby && NetworkManager.isHost)
        {
            if (controls.UI_UP_P) changeSongSelection(-1);
            if (controls.UI_DOWN_P) changeSongSelection(1);
            if (controls.UI_LEFT_P) changeDifficulty(-1);
            if (controls.UI_RIGHT_P) changeDifficulty(1);

            if (FlxG.keys.justPressed.SHIFT || FlxG.keys.justPressed.CONTROL) {
                FlxG.sound.play(Paths.sound('scrollMenu'));
                setRole((currentRole == 'bf') ? 'dad' : 'bf');
                sendLobbyView();
            }

            // the song is picked: how the match is won is set up before it starts
            if (controls.ACCEPT) {
                FlxG.sound.play(Paths.sound('scrollMenu'));
                openSetup(true);
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
        else if (NetworkManager.isHost || gotLobbyView) hostLobby.visible = true;
        else clientWaitText.visible = true;
        setupPanel.visible = inLobby && (configuring || hostConfiguring);
    }

    // ------------------------------------------------------------------------------------------
    // The match's setup
    // ------------------------------------------------------------------------------------------

    function makeSetupPanel() {
        if (FlxG.save.data.multiplayerWinCondition != null)
            winCondition = NetworkManager.validCondition(FlxG.save.data.multiplayerWinCondition);

        setupPanel = new flixel.group.FlxGroup();
        setupPanel.visible = false;
        add(setupPanel);

        var width:Int = 860;
        var height:Int = 360;
        var bg:FlxSprite = new FlxSprite(0, 175).makeGraphic(width, height, FlxColor.TRANSPARENT, true);
        flixel.util.FlxSpriteUtil.drawRoundRect(bg, 2, 2, width - 4, height - 4, 24, 24, 0xEE141414, {thickness: 3, color: 0xFF8844DD});
        bg.screenCenter(X);
        setupPanel.add(bg);

        function text(y:Float, size:Int, color:FlxColor):FlxText {
            var t:FlxText = new FlxText(0, y, FlxG.width, "", size);
            t.setFormat(Paths.font("vcr.ttf"), size, color, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            setupPanel.add(t);
            return t;
        }
        setupTitle = text(bg.y + 18, 40, FlxColor.YELLOW);
        setupSong = text(bg.y + 72, 28, FlxColor.WHITE);
        setupCondition = text(bg.y + 130, 34, FlxColor.WHITE);
        setupConditionInfo = text(bg.y + 172, 20, 0xFFBBBBBB);
        setupSide = text(bg.y + 220, 30, FlxColor.WHITE);
        setupHint = text(bg.y + height - 50, 18, 0xFFBBBBBB);
    }

    // The host opens it (or closes it, back to the songs)
    function openSetup(open:Bool) {
        configuring = open;
        setupRow = 0;
        setupPanel.visible = open;
        refreshSetup();
        sendLobbyView();
    }

    function refreshSetup() {
        var host:Bool = NetworkManager.isHost;
        var condition:String = host ? winCondition : NetworkManager.winCondition;
        var role:String = host ? currentRole : clientViewRole;
        var diffName:String = host ? Difficulty.list[curDifficulty] : clientViewDifficulty;

        setupTitle.text = host ? t('setup_title', "MATCH SETUP") : t('setup_title_client', "THE HOST IS SETTING UP THE MATCH");
        setupSong.text = (songList.length > 0 ? songList[curSongSelected] : "?") + "  -  " + (diffName != null ? diffName.toUpperCase() : "?");
        setupCondition.text = (host ? "< " : "") + t('win_by', "Win by: {1}", [NetworkManager.winConditionName(condition).toUpperCase()]) + (host ? " >" : "");
        setupConditionInfo.text = NetworkManager.winConditionInfo(condition) + t('knockout_loses', "  (being knocked out always loses)");

        var hostSide:String = (role == 'dad') ? t('left_dad', "Left (DAD)") : t('right_bf', "Right (BF)");
        var otherSide:String = (role == 'dad') ? t('right_bf', "Right (BF)") : t('left_dad', "Left (DAD)");
        setupSide.text = host ? "< " + t('your_side', "Your side: {1}", [hostSide]) + " >" : t('sides', "Host: {1}  |  You: {2}", [hostSide, otherSide]);
        setupSide.color = ((role == 'dad') == host) ? 0xFFFF6666 : FlxColor.LIME;

        setupCondition.color = (host && setupRow == 0) ? FlxColor.YELLOW : FlxColor.WHITE;
        if (host && setupRow == 1) setupSide.color = FlxColor.YELLOW;

        setupHint.text = host ? t('setup_hint', "UP/DOWN: choose   LEFT/RIGHT: change   ENTER: start   ESC: back")
            : t('setup_hint_client', "Waiting for the host to start the match... (ESC to leave)");
    }

    function updateSetup() {
        if (controls.UI_UP_P || controls.UI_DOWN_P) {
            setupRow = (setupRow + 1) % 2;
            FlxG.sound.play(Paths.sound('scrollMenu'));
            refreshSetup();
        }

        if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
            FlxG.sound.play(Paths.sound('scrollMenu'));
            if (setupRow == 0) {
                var conditions:Array<String> = NetworkManager.WIN_CONDITIONS;
                var index:Int = conditions.indexOf(winCondition) + (controls.UI_LEFT_P ? -1 : 1);
                if (index < 0) index = conditions.length - 1;
                if (index >= conditions.length) index = 0;
                winCondition = conditions[index];
                FlxG.save.data.multiplayerWinCondition = winCondition;
                FlxG.save.flush();
            }
            else setRole((currentRole == 'bf') ? 'dad' : 'bf');
            refreshSetup();
            sendLobbyView();
        }

        if (controls.ACCEPT) startMatch();

        if (controls.BACK) {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            openSetup(false);
        }
    }

    function setRole(role:String) {
        currentRole = role;
        hostRoleText.text = (role == 'dad') ? t('playing_left', "< Playing with: Left Side (DAD) >") : t('playing_right', "< Playing with: Right Side (BF) >");
        hostRoleText.color = (role == 'dad') ? FlxColor.RED : FlxColor.LIME;
    }

    // The host starts the song it picked, the way it was set up
    function startMatch() {
        var chosenSong = songList[curSongSelected];
        var diffName:String = Difficulty.list[curDifficulty];
        var condition:String = winCondition;
        NetworkManager.winCondition = condition;
        // The host's chart has to load before the other player is asked for it (or both would wait for each other)
        if (forceLoadSong(curSongSelected, curDifficulty, (currentRole == 'dad'), function() {
            NetworkManager.log('asking for ' + chosenSong + ' (' + diffName + '), won by ' + condition);
            NetworkManager.sendLoadSong(chosenSong, curDifficulty, currentRole, diffName, songFolders[curSongSelected], condition);
        })) {
            FlxG.sound.play(Paths.sound('confirmMenu'));
        } else {
            showNotice(t('cant_open_diff', "Couldn't open \"{1}\" on this difficulty.", [chosenSong]));
            FlxG.sound.play(Paths.sound('cancelMenu'));
            openSetup(false);
        }
    }

    // The host: tells the other player what it has selected
    function sendLobbyView() {
        if (!NetworkManager.connected || !NetworkManager.isHost || !inLobby || songList.length == 0) return;

        var diffName:String = Difficulty.list[curDifficulty];
        var view:String = "LOBBY_VIEW|" + songList[curSongSelected] + "|" + songFolders[curSongSelected] + "|"
            + (diffName != null ? diffName : "") + "|" + currentRole + "|" + (configuring ? "1" : "0") + "|" + winCondition;
        if (view == lastLobbyView) return;
        lastLobbyView = view;
        NetworkManager.send(view);
    }

    // The one who joined: shows the host's list on what the host has selected
    function showLobbyView(msg:String) {
        var data:Array<String> = msg.split("|");
        if (data.length < 5) return;

        var songName:String = data[1];
        var diffName:String = data[3];
        var hostRole:String = data[4];
        clientViewRole = hostRole;
        clientViewDifficulty = diffName;
        hostConfiguring = (data.length > 5 && data[5] == "1");
        if (data.length > 6) NetworkManager.winCondition = NetworkManager.validCondition(data[6]);

        var first:Bool = !gotLobbyView;
        if (first) {
            gotLobbyView = true;
            clientWaitText.visible = false;
            hostLobby.visible = !typingNickname;
            diffText.visible = true;
            hostRoleText.visible = true;
            hostRoleHintText.visible = true;
        }

        var index:Int = findSong(songName, data[2]);
        if (index > -1 && (index != curSongSelected || first)) {
            if (!first) FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
            curSongSelected = index;
            for (i in 0...hostLobby.length) {
                var item = hostLobby.members[i];
                item.targetY = i - curSongSelected;
                item.alpha = (item.targetY == 0) ? 1 : 0.6;
            }
        }

        diffText.text = '< ' + (diffName.length > 0 ? diffName.toUpperCase() : '?') + ' >';
        diffText.x = FlxG.width - diffText.width - 20;

        if (hostRole == 'dad') {
            hostRoleText.text = t('sides_full', "Host: {1}  |  You: {2}", [t('left_side', "Left Side (DAD)"), t('right_side', "Right Side (BF)")]);
            hostRoleText.color = FlxColor.LIME;
        } else {
            hostRoleText.text = t('sides_full', "Host: {1}  |  You: {2}", [t('right_side', "Right Side (BF)"), t('left_side', "Left Side (DAD)")]);
            hostRoleText.color = FlxColor.RED;
        }
        hostRoleHintText.text = (index > -1) ? t('host_choosing', "The host is choosing the song... (ESC to leave)")
            : t('host_missing_song', "The host is on \"{1}\", which isn't installed here! (ESC to leave)", [songName]);

        // the host's setup of the match, as it changes
        setupPanel.visible = hostConfiguring && !typingNickname;
        if (hostConfiguring) refreshSetup();
    }

    // (the one who joined: the side and the difficulty the host has, from its last "LOBBY_VIEW")
    var clientViewRole:String = 'bf';
    var clientViewDifficulty:String = '';

    // Back to choosing to host or to join (the connection is gone)
    function leaveLobby() {
        NetworkManager.log('left the lobby: ' + NetworkManager.statusString);
        inLobby = false;
        hostLobby.visible = false;
        diffText.visible = false;
        hostRoleText.visible = false;
        hostRoleHintText.visible = false;
        hostRoleHintText.text = t('shift_hint', "(Press SHIFT to change character)");
        hostRoleText.text = (currentRole == 'dad') ? t('playing_left', "< Playing with: Left Side (DAD) >") : t('playing_right', "< Playing with: Right Side (BF) >");
        hostRoleText.color = (currentRole == 'dad') ? FlxColor.RED : FlxColor.LIME;
        clientWaitText.visible = false;
        gotLobbyView = false;
        lastLobbyView = null;
        configuring = false;
        hostConfiguring = false;
        setupPanel.visible = false;
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
        sendLobbyView();
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
