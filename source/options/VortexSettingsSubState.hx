package options;

/**
 * What Vortex Engine adds to the game, all in one place (the V-Slice menus and the graphics options are on their own pages).
 */
class VortexSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('vortex_menu', 'Vortex Engine Settings');
		rpcTitle = 'Vortex Engine Settings Menu';

		// Gameplay
		var option:Option = new Option('Break Timer',
			"If checked, a countdown will appear when there is a long gap between your notes.",
			'breakTimer',
			BOOL);
		addOption(option);

		var option:Option = new Option('Ghost Notes',
			"Ghost will appear if double notes are pressed.",
			'ghostNotes',
			BOOL);
		addOption(option);

		var option:Option = new Option('Lane Underlay',
			'If checked, a dark background is added behind your notes
making them easier to see.',
			'laneUnderlay',
			BOOL);
		addOption(option);

		var option:Option = new Option('Sustain Wiggle',
			"If checked, long notes will wave like a snake to the beat of the music.",
			'sustainWiggle',
			BOOL);
		addOption(option);

		// HUD
		var option:Option = new Option('Score Camera:',
			"Where should the Ratings and Combo numbers appear?",
			'scoreCamera',
			STRING,
			['HUD', 'Game']);
		addOption(option);

		var option:Option = new Option('Smooth Health Bar',
			'If checked, health bar colors and icons transition smoothly.',
			'smoothHealthBar',
			BOOL);
		addOption(option);

		var option:Option = new Option('Icon Bop',
			"If checked, the character icons will tilt back and forth to the beat.",
			'iconBop',
			BOOL);
		addOption(option);

		var option:Option = new Option('Song Credits Card',
			"If checked, a card with the song's name, its composer and its charter
slides in when a song starts.",
			'songCredits',
			BOOL);
		addOption(option);

		super();
	}
}
