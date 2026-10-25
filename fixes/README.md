# Fixes to libraries

Files of the libraries the engine is built with that needed a fix, kept here instead of changing the library itself (which is
installed for the whole computer and shared with other projects). Each folder is named after the library and the version its file
came from, and `Project.xml` adds it to the build right after the library, so the file here is the one that gets used.

**When a library is updated, its folder here has to go** (and its line in `Project.xml`): the file would otherwise replace the new
version's with the old one. Every change is marked with `VORTEX ENGINE` on the file.

## hxvlc-2.0.1

`hxvlc/openfl/Video.hx`, the video player. The game closed in the middle of videos without any error: always on the same spot,
inside of OpenAL's mixer (`lime.ndll`), which is what plays the video's audio. It was the `.mkv` cutscenes of V-Slice (Ugh, Guns,
Stress) that did it, on most of the times they were played, while the `.mp4` ones were fine.

Three changes, of which the first is the one that stopped it (measured on the Stress cutscene: it closed on 11 of 15 plays without
it, with or without the other two, and on none of the plays with it):

1. **The audio goes to OpenAL in pieces of a single size.** LibVLC hands the audio over in pieces of whatever size the format uses,
   and each was given to OpenAL as it came, on buffers that are used over and over. AAC (`.mp4`) always has the same size, so a
   buffer never changed size. Vorbis (`.mkv`) has a different one each time, so every buffer was made again at another size each
   time it was used, while the mixer was playing the ones next to it. Now the pieces are put together into ones of 2048 samples
   before being handed over (`AL_CHUNK_FRAMES`). What it costs: the audio is up to 1/20 of a second later than it was.

2. **The threads LibVLC calls from tell the garbage collector where their stack starts.** It's done with the address of a variable
   (`int base = 99; hx::SetTopOfStack(&base, true);`), and the library had the number itself as if it were the address
   (`hx::SetTopOfStack((int *)99, true)`) on all 13 of its functions. hxcpp takes that as a stack with nothing on it, so what those
   functions were using wasn't kept alive by them.

3. **The buffers are kept on a list while they play.** Nothing held the ones that were playing, so the collector kept trying to
   delete them (OpenAL refused each time: "Deleting in-use buffer", hundreds of them over a video).
