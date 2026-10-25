package funkin.graphics;

import flxanimate.animate.FlxElement;

/**
 * A sprite that's put inside of the frames of a texture atlas, to be drawn along with them wherever those frames show up:
 * V-Slice's `animate.internal.elements.FlxSpriteElement`. It's how the LE SSERAFIM characters get their mouths: the atlas has
 * an empty symbol where the mouth goes, and a sprite that follows the song is put on that symbol's frames.
 *
 *     var element = new FlxSpriteElement(sprite);
 *     for (frame in character.getFramesWithKeyword('mouth')) frame.add(element);
 *
 * The sprite is drawn on the coordinates of the symbol it was put in, with its own position, offset, scale, angle and flip
 * (see `flxanimate.PsychFlxAnimate.drawPlacedSprite()`). It isn't updated by the atlas: whoever made it does that.
 */
class SpriteElement extends FlxElement
{
	public var sprite:Dynamic;

	public function new(?sprite:Dynamic)
	{
		super();
		this.sprite = sprite;
	}
}
