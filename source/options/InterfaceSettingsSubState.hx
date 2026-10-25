package options;

class InterfaceSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'V-Slice Settings';
		rpcTitle = 'V-Slice Settings Menu';

		var option:Option = new Option('Freeplay Style',
			'Choose the visual style for the Freeplay Menu.',
			'freeplayStyle',
			STRING,
			['Standard', 'V-Slice']);
		addOption(option);

		var option:Option = new Option('Results Screen',
			"If checked, the score, the tallies and the rank of what you played\nare shown after a song on Freeplay and after a week on Story Mode.",
			'resultsScreen',
			BOOL);
		addOption(option);

		var option:Option = new Option('Sticker Transition',
			"If checked, going from a song back to the menus covers the screen\nwith stickers instead of fading to black.",
			'stickerTransition',
			BOOL);
		addOption(option);

		var option:Option = new Option('Hold Note Covers',
			"If checked, holding a long note makes sparks on its receptor,\nthat burst when it's held to the end.",
			'holdCovers',
			BOOL);
		addOption(option);

		var option:Option = new Option('Naughtyness',
			"If unchecked, the Results Screen shows the tamer version\nof the animations that have one.",
			'naughtyness',
			BOOL);
		addOption(option);

		super();
	}
}