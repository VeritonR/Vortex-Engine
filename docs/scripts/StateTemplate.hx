// Vortex Engine - State Script template
// Copy this file to your mod's "states" folder and rename it after the screen it's for
// (MainMenuState.hx, TitleState.hx, LoadingState.hx, FreeplayState.hx... or Global.hx for every screen).
// Every function is optional: delete the ones you don't need. Full guide: docs/STATE_SCRIPTS.md

// The screen was opened, before it makes its things
function onCreate()
{
}

// The screen made its things: add, hide, move or replace them here
function onCreatePost()
{
}

// Every frame, before the screen updates
function onUpdate(elapsed:Float)
{
}

// Every frame, after the screen updated
function onUpdatePost(elapsed:Float)
{
}

// Each step and beat of the music that's playing (curStep / curBeat)
function onStepHit()
{
}

function onBeatHit()
{
}

// A substate opened over the screen (name: "PauseSubState", "OptionsMenu"...) / was closed
function onOpenSubState(name:String)
{
}

function onCloseSubState()
{
}

// The screen is being left
function onDestroy()
{
}

// ---- Only on the loading screen (LoadingState.hx) ----

// Something more was loaded (percent: 0 to 1)
function onLoadingProgress(loaded:Int, total:Int, percent:Float)
{
}

// Everything is loaded. Return Function_Stop to keep the screen on, then call finishLoading() to go on to the song
function onFinishedLoading()
{
	return Function_Continue;
}
