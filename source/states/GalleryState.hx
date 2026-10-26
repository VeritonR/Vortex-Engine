package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Paths;
import backend.ClientPrefs;
import backend.MusicBeatState;
import states.MainMenuState;

#if sys
import sys.FileSystem;
#end

class GalleryState extends MusicBeatState
{
    var imagesList:Array<{name:String, path:String}> = [];
    var curSelected:Int = 0;

    var bgWhite:FlxSprite;
    var bgImage:FlxSprite;
    var imageSprite:FlxSprite;

    var topBar:FlxSprite;
    var bottomBar:FlxSprite;
    var titleText:FlxText;
    var creatorText:FlxText;
    var infoText:FlxText;

    var isFullscreen:Bool = false;

    var isDragging:Bool = false;
    var lastMouseX:Float = 0;
    var lastMouseY:Float = 0;

    override function create()
    {
        super.create();

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Gallery", null);
        #end

        bgWhite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
        add(bgWhite);

        bgImage = new FlxSprite();
        bgImage.alpha = 0.5;
        bgImage.antialiasing = ClientPrefs.data.antialiasing;
        add(bgImage);

        imageSprite = new FlxSprite();
        imageSprite.antialiasing = ClientPrefs.data.antialiasing;
        add(imageSprite);

        topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xFF826DB3);
        add(topBar);

        bottomBar = new FlxSprite(0, FlxG.height - 130).makeGraphic(FlxG.width, 130, 0xFF826DB3);
        add(bottomBar);

        infoText = new FlxText(0, 10, FlxG.width, "Press F for Fullscreen | Scroll = Zoom In/Out | Drag = Move | R = Reset", 18);
        infoText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER);
        infoText.antialiasing = ClientPrefs.data.antialiasing;
        add(infoText);

        creatorText = new FlxText(20, bottomBar.y + 20, FlxG.width - 40, "", 24);
        creatorText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
        creatorText.antialiasing = ClientPrefs.data.antialiasing;
        add(creatorText);

        titleText = new FlxText(20, creatorText.y + 40, FlxG.width - 40, "", 36);
        titleText.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, LEFT);
        titleText.antialiasing = ClientPrefs.data.antialiasing;
        add(titleText);

        #if sys
        var directoriesToCheck:Array<String> = [
            'assets/shared/images/gallery/',
            'mods/images/gallery/'
        ];

        // The mods that are turned on. V-Slice mods are left out: their "images/gallery" is the menu of a gallery of their own (its
        // background, its logo, its spritesheets), not pictures for this one
        #if MODS_ALLOWED
        for (folder in backend.Mods.parseList().enabled) {
            if (backend.PolymodCompat.isPolymod(folder)) continue;
            directoriesToCheck.push('mods/' + folder + '/images/gallery/');
        }
        #end

        for (path in directoriesToCheck) {
            if (FileSystem.exists(path)) {
                for (file in FileSystem.readDirectory(path)) {
                    // (a spritesheet has its frames' file beside it: it's part of a menu, not a picture)
                    var base:String = path + file.substr(0, file.length - 4);
                    if (StringTools.endsWith(file, '.png') && !FileSystem.exists(base + '.xml') && !FileSystem.exists(base + '.json') && !FileSystem.exists(base + '.txt')) {
                        var imageName:String = StringTools.replace(file, '.png', '');
                        var fullPath:String = path + file;
                        
                        var exists:Bool = false;
                        for (item in imagesList) {
                            if (item.name == imageName) {
                                exists = true;
                                break;
                            }
                        }

                        if (!exists) {
                            imagesList.push({name: imageName, path: fullPath});
                        }
                    }
                }
            }
        }
        #end

        if (imagesList.length > 0) {
            changeImage(0);
        } else {
            titleText.text = "PASTA VAZIA!";
            creatorText.text = "Nenhuma imagem em images/gallery/";
            titleText.color = FlxColor.RED;
        }

        FlxG.mouse.visible = true;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (imagesList.length > 0)
        {
            if (!isFullscreen)
            {
                if (controls.UI_LEFT_P) changeImage(-1);
                if (controls.UI_RIGHT_P) changeImage(1);
            }

            if (FlxG.keys.justPressed.F)
            {
                isFullscreen = !isFullscreen;
                FlxG.sound.play(Paths.sound('scrollMenu'));
                
                topBar.visible = !isFullscreen;
                bottomBar.visible = !isFullscreen;
                titleText.visible = !isFullscreen;
                creatorText.visible = !isFullscreen;
                infoText.visible = !isFullscreen;

                updateImageScale();
            }

            if (FlxG.keys.justPressed.R)
            {
                updateImageScale();
            }

            if (FlxG.mouse.wheel != 0)
            {
                var zoomFactor:Float = FlxG.mouse.wheel * 0.15;
                var newScale:Float = imageSprite.scale.x + (imageSprite.scale.x * zoomFactor);

                if (newScale < 0.1) newScale = 0.1;
                if (newScale > 15) newScale = 15;

                var oldMidX = imageSprite.x + imageSprite.width / 2;
                var oldMidY = imageSprite.y + imageSprite.height / 2;

                imageSprite.scale.set(newScale, newScale);
                imageSprite.updateHitbox();

                imageSprite.x = oldMidX - imageSprite.width / 2;
                imageSprite.y = oldMidY - imageSprite.height / 2;
            }

            if (FlxG.mouse.justPressed)
            {
                isDragging = true;
                lastMouseX = FlxG.mouse.screenX;
                lastMouseY = FlxG.mouse.screenY;
            }

            if (isDragging && FlxG.mouse.pressed)
            {
                var dx = FlxG.mouse.screenX - lastMouseX;
                var dy = FlxG.mouse.screenY - lastMouseY;
                
                imageSprite.x += dx;
                imageSprite.y += dy;
                
                lastMouseX = FlxG.mouse.screenX;
                lastMouseY = FlxG.mouse.screenY;
            }

            if (FlxG.mouse.justReleased)
            {
                isDragging = false;
            }
        }

        if (controls.BACK)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            FlxG.mouse.visible = false; 
            MusicBeatState.switchState(new MainMenuState());
        }
    }

    function changeImage(change:Int = 0)
    {
        if (change != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

        curSelected += change;

        if (curSelected >= imagesList.length) curSelected = 0;
        if (curSelected < 0) curSelected = imagesList.length - 1;

        var item = imagesList[curSelected];
        var imgName = item.name;
        var imgPath = item.path;
        
        // no manual graphic.destroy() here: both sprites share one graphic and flixel already destroys it
        // once nothing uses it anymore, destroying it first left them drawing a dead graphic if the new file failed to load
        #if sys
        var graphic = openfl.display.BitmapData.fromFile(imgPath);
        if (graphic != null) {
            imageSprite.loadGraphic(graphic);
            bgImage.loadGraphic(graphic);
        }
        #else
        var graphic = Paths.image('gallery/' + imgName);
        imageSprite.loadGraphic(graphic);
        bgImage.loadGraphic(graphic);
        #end

        var splitName:Array<String> = imgName.split('_'); 
        
        titleText.text = splitName[0];
        
        if (splitName.length > 1) {
            creatorText.text = splitName[1];
        } else {
            creatorText.text = "Criador Desconhecido"; 
        }
        
        updateImageScale();
    }

    function updateImageScale()
    {
        if (imageSprite.graphic == null || bgImage.graphic == null) return;

        bgImage.scale.set(1, 1);
        bgImage.updateHitbox();
        var bgRatio = Math.max(FlxG.width / bgImage.width, FlxG.height / bgImage.height);
        bgImage.scale.set(bgRatio, bgRatio);
        bgImage.updateHitbox();
        bgImage.screenCenter();

        imageSprite.scale.set(1, 1);
        imageSprite.updateHitbox();

        var startY:Float = isFullscreen ? 0 : topBar.height;
        var availHeight:Float = isFullscreen ? FlxG.height : (bottomBar.y - topBar.height);
        var availWidth:Float = FlxG.width;

        var fgRatio:Float = Math.min(availWidth / imageSprite.width, availHeight / imageSprite.height);
        imageSprite.scale.set(fgRatio, fgRatio);
        imageSprite.updateHitbox();
        
        imageSprite.screenCenter(X);
        imageSprite.y = startY + (availHeight - imageSprite.height) / 2;
    }
}