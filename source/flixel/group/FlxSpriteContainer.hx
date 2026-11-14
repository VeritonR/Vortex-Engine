package flixel.group;

// Flixel 6's containers (groups that take what's added to them out of the one it was in), for V-Slice's classes and scripts made
// with flixel 6: here they're flixel's groups, which the engine is built with.

typedef FlxSpriteContainer = FlxSpriteGroup;
typedef FlxTypedSpriteContainer<T:flixel.FlxSprite> = FlxSpriteGroup.FlxTypedSpriteGroup<T>;
