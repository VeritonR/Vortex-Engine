package options;

class VortexSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Vortex Engine Settings';
		rpcTitle = 'Vortex Engine Settings Menu';

		var option:Option = new Option('Song Credits Card',
			"If checked, a card with the song's name, its composer and its charter\nslides in when a song starts.",
			'songCredits',
			BOOL);
		addOption(option);

		super();
	}
}
