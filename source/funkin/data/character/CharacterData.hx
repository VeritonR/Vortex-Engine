package funkin.data.character;

// (V-Slice's, for scripts: see the import of it on V-Slice)
/**
 * Describes the available rendering types for a character.
 */
enum abstract CharacterRenderType(String) from String to String
{
	/**
	 * Renders the character using a single spritesheet and XML data.
	 */
	public var Sparrow = 'sparrow';

	/**
	 * Renders the character using a single spritesheet and TXT data.
	 */
	public var Packer = 'packer';

	/**
	 * Renders the character using multiple spritesheets and XML data.
	 */
	public var MultiSparrow = 'multisparrow';

	/**
	 * Renders the character using a single spritesheet of symbols and JSON data.
	 */
	public var AnimateAtlas = 'animateatlas';

	/**
	 * Renders the character using multiple spritesheets of symbols and JSON data.
	 */
	public var MultiAnimateAtlas = 'multianimateatlas';

	/**
	 * Renders the character using a custom method.
	 */
	public var Custom = 'custom';
}
