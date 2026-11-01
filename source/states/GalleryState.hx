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

    // "Save a copy": the picture saved anywhere, without looking for it in the game's folders
    var saveButton:FlxSprite;
    var saveText:FlxText;
    var file:openfl.net.FileReference = null;

    // The look: a frame and a shadow around the picture, a shade over the background, a counter, arrows on the sides
    var frame:FlxSprite;
    var shadow:FlxSprite;
    var shade:FlxSprite;
    var galleryTitle:FlxText;
    var counterText:FlxText;
    var leftArrow:FlxText;
    var rightArrow:FlxText;
    var topLine:FlxSprite;
    var bottomLine:FlxSprite;
    var slideOffset:Float = 0; //(the picture comes in from the side it was changed to)

    // The pictures ready to be shown (made into graphics already), by their path, and the ones a thread is decoding.
    // Changing pictures used to read and decode the PNG right then, on the game's thread (a big screenshot froze it for a moment)
    var graphics:Map<String, flixel.graphics.FlxGraphic> = [];
    var cacheOrder:Array<String> = [];
    static inline var CACHE_SIZE:Int = 5;
    #if sys
    var decoded:Map<String, backend.PngDecoder.PngPixels> = [];
    var decoding:Map<String, Bool> = [];
    var decodeMutex:sys.thread.Mutex = new sys.thread.Mutex();
    #end

    override function create()
    {
        super.create();

        #if DISCORD_ALLOWED
        DiscordClient.changePresence("In the Gallery", null);
        #end

        bgWhite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF120820);
        add(bgWhite);

        bgImage = new FlxSprite();
        bgImage.alpha = 0.35;
        bgImage.antialiasing = ClientPrefs.data.antialiasing;
        add(bgImage);

        // (darker at the top and the bottom, a purple tint all over)
        shade = flixel.util.FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xEE120820, 0x8836164F, 0x5536164F, 0xEE120820]);
        add(shade);
        var pattern:flixel.addons.display.FlxBackdrop = new flixel.addons.display.FlxBackdrop(Paths.image('mainmenu/othermenus/bficom'));
        pattern.velocity.set(20, 20);
        pattern.spacing.set(50, 50);
        pattern.alpha = 0.05;
        pattern.antialiasing = ClientPrefs.data.antialiasing;
        add(pattern);

        shadow = new FlxSprite().makeGraphic(1, 1, 0x88000000);
        add(shadow);
        frame = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
        add(frame);

        imageSprite = new FlxSprite();
        imageSprite.antialiasing = ClientPrefs.data.antialiasing;
        add(imageSprite);

        topBar = new FlxSprite(0, 0).makeGraphic(FlxG.width, 40, 0xE21C0A30);
        add(topBar);
        topLine = new FlxSprite(0, 40).makeGraphic(FlxG.width, 3, 0xFFFF5FC8);
        add(topLine);

        bottomBar = new FlxSprite(0, FlxG.height - 130).makeGraphic(FlxG.width, 130, 0xE21C0A30);
        add(bottomBar);
        bottomLine = new FlxSprite(0, FlxG.height - 133).makeGraphic(FlxG.width, 3, 0xFFFF5FC8);
        add(bottomLine);

        galleryTitle = new FlxText(160, 8, 0, Language.getPhrase('gallery_title', "GALLERY"), 22);
        galleryTitle.setFormat(Paths.font("vcr.ttf"), 22, 0xFFFF8FD8, LEFT);
        add(galleryTitle);
        counterText = new FlxText(FlxG.width - 216, 8, 200, "", 22);
        counterText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, RIGHT);
        add(counterText);

        leftArrow = new FlxText(14, 0, 0, "<", 64);
        leftArrow.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, LEFT, OUTLINE, 0xFF36164F);
        leftArrow.borderSize = 3;
        leftArrow.screenCenter(Y);
        add(leftArrow);
        rightArrow = new FlxText(FlxG.width - 50, 0, 0, ">", 64);
        rightArrow.setFormat(Paths.font("vcr.ttf"), 64, FlxColor.WHITE, LEFT, OUTLINE, 0xFF36164F);
        rightArrow.borderSize = 3;
        rightArrow.screenCenter(Y);
        add(rightArrow);

        infoText = new FlxText(0, 10, FlxG.width, Language.getPhrase('gallery_hint', "Press F for Fullscreen | Scroll = Zoom In/Out | Drag = Move | R = Reset"), 18);
        infoText.setFormat(Paths.font("vcr.ttf"), 18, 0xFFE7D8FF, CENTER);
        infoText.antialiasing = ClientPrefs.data.antialiasing;
        add(infoText);

        creatorText = new FlxText(20, bottomBar.y + 20, FlxG.width - 300, "", 24);
        creatorText.setFormat(Paths.font("vcr.ttf"), 24, 0xFFFF8FD8, LEFT);
        creatorText.antialiasing = ClientPrefs.data.antialiasing;
        add(creatorText);

        saveButton = new FlxSprite(FlxG.width - 300, bottomBar.y + 35).makeGraphic(280, 60, 0xFFD43FA8);
        add(saveButton);
        saveText = new FlxText(saveButton.x, saveButton.y + 19, saveButton.width, Language.getPhrase("gallery_save", "SAVE A COPY (S)"), 20);
        saveText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
        add(saveText);

        titleText = new FlxText(20, creatorText.y + 40, FlxG.width - 400, "", 36);
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
            titleText.text = Language.getPhrase('gallery_empty', "EMPTY FOLDER!");
            creatorText.text = Language.getPhrase('gallery_empty_info', "No pictures in images/gallery/");
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
                saveButton.visible = saveText.visible = !isFullscreen;
                topLine.visible = bottomLine.visible = galleryTitle.visible = counterText.visible = !isFullscreen;

                updateImageScale();
            }

            if (FlxG.keys.justPressed.R)
            {
                updateImageScale();
            }

            if (!isFullscreen && FlxG.mouse.justPressed)
            {
                if (FlxG.mouse.overlaps(leftArrow)) changeImage(-1);
                else if (FlxG.mouse.overlaps(rightArrow)) changeImage(1);
            }
            for (arrow in [leftArrow, rightArrow])
            {
                arrow.visible = !isFullscreen && imagesList.length > 1;
                arrow.alpha = FlxG.mouse.overlaps(arrow) ? 1 : 0.6;
            }

            var overSave:Bool = saveButton.visible && FlxG.mouse.overlaps(saveButton);
            saveButton.color = overSave ? 0xFFB0A0E0 : FlxColor.WHITE;
            if (FlxG.keys.justPressed.S || (overSave && FlxG.mouse.justPressed)) saveCopy();

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

            if (FlxG.mouse.justPressed && !(saveButton.visible && FlxG.mouse.overlaps(saveButton)) && !(leftArrow.visible && (FlxG.mouse.overlaps(leftArrow) || FlxG.mouse.overlaps(rightArrow))))
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

        updateFrame(elapsed);

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
        slideOffset = (change > 0) ? 60 : ((change < 0) ? -60 : 0);
        imageSprite.alpha = (change != 0) ? 0 : 1;

        curSelected += change;

        if (curSelected >= imagesList.length) curSelected = 0;
        if (curSelected < 0) curSelected = imagesList.length - 1;

        var item = imagesList[curSelected];
        var imgName = item.name;
        var imgPath = item.path;
        
        // no manual graphic.destroy() here: both sprites share one graphic and flixel already destroys it
        // once nothing uses it anymore, destroying it first left them drawing a dead graphic if the new file failed to load
        #if sys
        var graphic:flixel.graphics.FlxGraphic = graphicOf(imgPath);
        if (graphic != null) {
            imageSprite.loadGraphic(graphic);
            bgImage.loadGraphic(graphic);
        }
        preloadAround();
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
            creatorText.text = Language.getPhrase('gallery_unknown_creator', "Unknown creator");
        }

        updateImageScale();
        imageSprite.x += slideOffset; //(starts to the side, see updateFrame())
    }

    // ------------------------------------------------------------------------------------------
    // Pictures ready before they're shown
    // ------------------------------------------------------------------------------------------

    // The graphic of a picture: ready already, from pixels a thread decoded, or read right now
    function graphicOf(path:String):flixel.graphics.FlxGraphic
    {
        if (graphics.exists(path)) return graphics.get(path);

        var bitmap:openfl.display.BitmapData = null;
        #if sys
        decodeMutex.acquire();
        var pixels = decoded.get(path);
        decoded.remove(path);
        decodeMutex.release();
        if (pixels != null) bitmap = backend.PngDecoder.toBitmapData(pixels);
        #end
        if (bitmap == null) bitmap = openfl.display.BitmapData.fromFile(path);
        if (bitmap == null) return null;

        // (kept while the gallery is open: flixel would destroy a graphic nothing shows, and its picture with it)
        var graphic:flixel.graphics.FlxGraphic = flixel.graphics.FlxGraphic.fromBitmapData(bitmap, false, 'gallery:' + path, false);
        graphic.persist = true;
        graphic.destroyOnNoUse = false;
        graphics.set(path, graphic);
        cacheOrder.push(path);
        trimCache();
        return graphic;
    }

    // The oldest ones go, but the one on the screen
    function trimCache()
    {
        var showing:String = (imagesList.length > 0) ? imagesList[curSelected].path : null;
        var index:Int = 0;
        while (cacheOrder.length > CACHE_SIZE && index < cacheOrder.length)
        {
            var path:String = cacheOrder[index];
            if (path == showing || isNeighbor(path)) { index++; continue; }
            cacheOrder.splice(index, 1);
            var graphic = graphics.get(path);
            graphics.remove(path);
            if (graphic != null) graphic.destroy();
        }
    }

    function isNeighbor(path:String):Bool
    {
        if (imagesList.length < 2) return false;
        var next:Int = (curSelected + 1) % imagesList.length;
        var previous:Int = (curSelected - 1 + imagesList.length) % imagesList.length;
        return imagesList[next].path == path || imagesList[previous].path == path;
    }

    // The pictures next to this one are read and decoded on a thread of their own, for the arrows to show them at once
    function preloadAround()
    {
        #if sys
        if (imagesList.length < 2) return;
        for (change in [1, -1])
        {
            var path:String = imagesList[(curSelected + change + imagesList.length) % imagesList.length].path;
            decodeMutex.acquire();
            var busy:Bool = graphics.exists(path) || decoded.exists(path) || decoding.exists(path);
            if (!busy) decoding.set(path, true);
            decodeMutex.release();
            if (busy) continue;

            sys.thread.Thread.create(function() {
                var pixels = null;
                try pixels = backend.PngDecoder.decode(sys.io.File.getBytes(path)) catch (e:Dynamic) {}
                decodeMutex.acquire();
                decoding.remove(path);
                if (pixels != null) decoded.set(path, pixels);
                decodeMutex.release();
            });
        }
        #end
    }

    // ------------------------------------------------------------------------------------------
    // Saving a copy
    // ------------------------------------------------------------------------------------------

    function saveCopy()
    {
        #if sys
        if (file != null || imagesList.length < 1) return;
        var item = imagesList[curSelected];
        var bytes:haxe.io.Bytes = null;
        try bytes = sys.io.File.getBytes(item.path) catch (e:Dynamic) {}
        if (bytes == null) return;

        FlxG.sound.play(Paths.sound('scrollMenu'));
        file = new openfl.net.FileReference();
        file.addEventListener(openfl.events.Event.SELECT, onSaveEnd);
        file.addEventListener(openfl.events.Event.CANCEL, onSaveEnd);
        file.addEventListener(openfl.events.IOErrorEvent.IO_ERROR, onSaveEnd);
        file.save(openfl.utils.ByteArray.fromBytes(bytes), item.name + '.png');
        #end
    }

    function onSaveEnd(_)
    {
        if (file == null) return;
        file.removeEventListener(openfl.events.Event.SELECT, onSaveEnd);
        file.removeEventListener(openfl.events.Event.CANCEL, onSaveEnd);
        file.removeEventListener(openfl.events.IOErrorEvent.IO_ERROR, onSaveEnd);
        file = null;
    }

    override function destroy()
    {
        // (the pictures kept for the gallery: nothing else uses them)
        imageSprite.loadGraphic(new openfl.display.BitmapData(1, 1, true, 0));
        bgImage.loadGraphic(new openfl.display.BitmapData(1, 1, true, 0));
        for (graphic in graphics) graphic.destroy();
        graphics.clear();
        super.destroy();
    }

    // The frame and the shadow around the picture (it can be zoomed and dragged), the picture sliding in after a change
    function updateFrame(elapsed:Float)
    {
        if (slideOffset != 0)
        {
            var before:Float = slideOffset;
            slideOffset = FlxMath.lerp(0, slideOffset, Math.exp(-elapsed * 14));
            if (Math.abs(slideOffset) < 0.5) slideOffset = 0;
            imageSprite.x -= before - slideOffset; //(back to the middle, a bit each frame)
        }
        if (imageSprite.alpha < 1) imageSprite.alpha = Math.min(1, imageSprite.alpha + elapsed * 6);

        var show:Bool = imageSprite.graphic != null && imagesList.length > 0 && !isFullscreen;
        frame.visible = shadow.visible = show;
        if (!show) return;
        frame.setGraphicSize(Std.int(imageSprite.width + 8), Std.int(imageSprite.height + 8));
        frame.updateHitbox();
        frame.setPosition(imageSprite.x - 4, imageSprite.y - 4);
        frame.alpha = imageSprite.alpha;
        shadow.setGraphicSize(Std.int(imageSprite.width + 8), Std.int(imageSprite.height + 8));
        shadow.updateHitbox();
        shadow.setPosition(imageSprite.x + 6, imageSprite.y + 10);
        shadow.alpha = imageSprite.alpha;
        if (counterText != null) counterText.text = (curSelected + 1) + ' / ' + imagesList.length;
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

        var margin:Float = isFullscreen ? 0 : 40;
        var fgRatio:Float = Math.min((availWidth - margin * 3) / imageSprite.width, (availHeight - margin) / imageSprite.height);
        imageSprite.scale.set(fgRatio, fgRatio);
        imageSprite.updateHitbox();
        
        imageSprite.screenCenter(X);
        imageSprite.y = startY + (availHeight - imageSprite.height) / 2;
    }
}