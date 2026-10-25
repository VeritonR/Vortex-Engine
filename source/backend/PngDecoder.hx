package backend;

import haxe.io.Bytes;
import haxe.io.BytesData;

/**
 * Reads PNG files without lime, for the loading threads (see `states.LoadingState`): lime's own decoder can't run on two threads
 * at once, and if it's used on one while the game's thread uses lime too, the whole game can freeze forever.
 * This only uses Haxe and the zlib of hxcpp, which are safe on any thread.
 *
 * The pixels come out the way the game keeps them (blue, green, red, alpha, with the colors multiplied by the alpha), the same
 * bytes lime gives: the image is made out of them without any more work (see `toBitmapData()`).
 * Interlaced files and broken ones give null: those are left to lime, on the game's thread.
 */
class PngDecoder
{
	static final SIGNATURE:Array<Int> = [137, 80, 78, 71, 13, 10, 26, 10];

	public static function decode(file:Bytes):PngPixels
	{
		try
		{
			return read(file);
		}
		catch(e:Dynamic)
		{
			return null;
		}
	}

	/**
	 * The image of decoded pixels. On the game's thread: it's what lime's objects are made of, and those aren't for other threads.
	 */
	public static function toBitmapData(png:PngPixels):openfl.display.BitmapData
	{
		var buffer:lime.graphics.ImageBuffer = new lime.graphics.ImageBuffer(lime.utils.UInt8Array.fromBytes(png.pixels), png.width, png.height, 32, lime.graphics.PixelFormat.BGRA32);
		buffer.premultiplied = true;
		buffer.transparent = true;
		return openfl.display.BitmapData.fromImage(new lime.graphics.Image(buffer), true);
	}

	static function read(file:Bytes):PngPixels
	{
		if(file == null || file.length < 8) return null;
		for (i in 0...8)
			if(file.get(i) != SIGNATURE[i]) return null;

		var width:Int = 0;
		var height:Int = 0;
		var depth:Int = 0;
		var colorType:Int = -1;
		var palette:Bytes = null;
		var paletteAlpha:Bytes = null;
		var transparent:Bytes = null;
		// where the compressed pixels are (they can be split in many chunks), put together after
		var chunks:Array<Int> = [];
		var compressedSize:Int = 0;

		var pos:Int = 8;
		while(pos + 8 <= file.length)
		{
			var length:Int = readInt(file, pos);
			var type:String = file.getString(pos + 4, 4);
			var start:Int = pos + 8;
			if(length < 0 || start + length > file.length) return null;

			switch(type)
			{
				case 'IHDR':
					width = readInt(file, start);
					height = readInt(file, start + 4);
					depth = file.get(start + 8);
					colorType = file.get(start + 9);
					if(file.get(start + 12) != 0) return null; //interlaced
				case 'PLTE':
					palette = file.sub(start, length);
				case 'tRNS':
					if(colorType == 3) paletteAlpha = file.sub(start, length);
					else transparent = file.sub(start, length);
				case 'IDAT':
					chunks.push(start);
					chunks.push(length);
					compressedSize += length;
				case 'IEND':
					break;
			}
			pos = start + length + 4; //(and its CRC)
		}
		if(width <= 0 || height <= 0) return null;

		var channels:Int = switch(colorType)
		{
			case 0: 1;
			case 2: 3;
			case 3: 1;
			case 4: 2;
			case 6: 4;
			default: return null;
		}
		if(colorType == 3 && palette == null) return null;
		if(depth != 1 && depth != 2 && depth != 4 && depth != 8 && depth != 16) return null;

		var bitsPerPixel:Int = channels * depth;
		var stride:Int = (width * bitsPerPixel + 7) >> 3;
		var distance:Int = (bitsPerPixel + 7) >> 3; //(the bytes of one pixel, at least one: how far back the filters look)
		var time:Float = Sys.time();
		// (copied whole: Haxe's BytesBuffer, and so `Uncompress.run()`, copy a byte at a time, which took longer than all the rest)
		var compressed:Bytes = Bytes.alloc(compressedSize);
		var at:Int = 0;
		var i:Int = 0;
		while(i < chunks.length)
		{
			compressed.blit(at, file, chunks[i], chunks[i + 1]);
			at += chunks[i + 1];
			i += 2;
		}

		var size:Int = height * (stride + 1);
		var raw:Bytes = Bytes.alloc(size);
		var inflater:haxe.zip.Uncompress = new haxe.zip.Uncompress();
		inflater.setFlushMode(FINISH);
		var result = inflater.execute(compressed, 0, raw, 0);
		inflater.close();
		if(result.write < size) return null;
		inflateTime += Sys.time() - time;

		time = Sys.time();
		unfilter(raw, height, stride, distance);
		unfilterTime += Sys.time() - time;
		time = Sys.time();
		var pixels:Bytes = toPixels(raw, width, height, stride, depth, colorType, palette, paletteAlpha, transparent);
		pixelsTime += Sys.time() - time;
		return {width: width, height: height, pixels: pixels};
	}

	static inline function readInt(bytes:Bytes, pos:Int):Int
		return (bytes.get(pos) << 24) | (bytes.get(pos + 1) << 16) | (bytes.get(pos + 2) << 8) | bytes.get(pos + 3);

	// Undoes the filter of each row, in place: each row starts with the number of its filter, the row before is already undone
	static function unfilter(raw:Bytes, height:Int, stride:Int, distance:Int):Void
	{
		var rd:BytesData = raw.getData();
		for (y in 0...height)
		{
			var row:Int = y * (stride + 1);
			var filter:Int = get(rd, row);
			var at:Int = row + 1;
			var above:Int = at - (stride + 1); //(nothing above the first row: counts as zeros)
			var first:Bool = (y == 0);

			switch(filter)
			{
				case 0:
				case 1:
					for (i in distance...stride)
						set(rd, at + i, get(rd, at + i) + get(rd, at + i - distance));
				case 2:
					if(!first)
						for (i in 0...stride)
							set(rd, at + i, get(rd, at + i) + get(rd, above + i));
				case 3:
					for (i in 0...stride)
					{
						var left:Int = (i >= distance) ? get(rd, at + i - distance) : 0;
						var up:Int = first ? 0 : get(rd, above + i);
						set(rd, at + i, get(rd, at + i) + ((left + up) >> 1));
					}
				case 4:
					for (i in 0...stride)
					{
						var left:Int = (i >= distance) ? get(rd, at + i - distance) : 0;
						var up:Int = first ? 0 : get(rd, above + i);
						var upLeft:Int = (!first && i >= distance) ? get(rd, above + i - distance) : 0;

						var guess:Int = left + up - upLeft;
						var toLeft:Int = guess > left ? guess - left : left - guess;
						var toUp:Int = guess > up ? guess - up : up - guess;
						var toUpLeft:Int = guess > upLeft ? guess - upLeft : upLeft - guess;
						var near:Int = (toLeft <= toUp && toLeft <= toUpLeft) ? left : (toUp <= toUpLeft ? up : upLeft);
						set(rd, at + i, get(rd, at + i) + near);
					}
				default:
					throw 'unknown filter $filter';
			}
		}
	}

	static function toPixels(raw:Bytes, width:Int, height:Int, stride:Int, depth:Int, colorType:Int, palette:Bytes, paletteAlpha:Bytes,
			transparent:Bytes):Bytes
	{
		var out:Bytes = Bytes.alloc(width * height * 4);
		var rd:BytesData = raw.getData();
		var od:BytesData = out.getData();
		var multiplied:BytesData = getMultiplied();
		var max:Int = (1 << depth) - 1;
		// the one color that's see-through, on files without alpha (as it's written: with all its bits)
		var clearGray:Int = (transparent != null && colorType == 0 && transparent.length >= 2) ? (transparent.get(0) << 8) | transparent.get(1) : -1;
		var clearR:Int = -1, clearG:Int = -1, clearB:Int = -1;
		if(transparent != null && colorType == 2 && transparent.length >= 6)
		{
			clearR = (transparent.get(0) << 8) | transparent.get(1);
			clearG = (transparent.get(2) << 8) | transparent.get(3);
			clearB = (transparent.get(4) << 8) | transparent.get(5);
		}
		var paletteSize:Int = (palette != null) ? Std.int(palette.length / 3) : 0;
		var alphaSize:Int = (paletteAlpha != null) ? paletteAlpha.length : 0;

		var o:Int = 0;
		// almost every image of the game: colors and alpha of 8 bits, on a loop of its own
		if(colorType == 6 && depth == 8)
		{
			for (y in 0...height)
			{
				var p:Int = y * (stride + 1) + 1;
				for (x in 0...width)
				{
					var a:Int = get(rd, p + 3);
					if(a == 255)
					{
						set(od, o, get(rd, p + 2));
						set(od, o + 1, get(rd, p + 1));
						set(od, o + 2, get(rd, p));
						set(od, o + 3, 255);
					}
					else if(a != 0)
					{
						var row:Int = a << 8;
						set(od, o, get(multiplied, row | get(rd, p + 2)));
						set(od, o + 1, get(multiplied, row | get(rd, p + 1)));
						set(od, o + 2, get(multiplied, row | get(rd, p)));
						set(od, o + 3, a);
					}
					else
					{
						set(od, o, 0);
						set(od, o + 1, 0);
						set(od, o + 2, 0);
						set(od, o + 3, 0);
					}
					p += 4;
					o += 4;
				}
			}
			return out;
		}

		for (y in 0...height)
		{
			var at:Int = y * (stride + 1) + 1;
			for (x in 0...width)
			{
				var r:Int = 0, g:Int = 0, b:Int = 0, a:Int = 255;
				switch(colorType)
				{
					case 6:
						if(depth == 8)
						{
							var p:Int = at + x * 4;
							r = get(rd, p); g = get(rd, p + 1); b = get(rd, p + 2); a = get(rd, p + 3);
						}
						else
						{
							var p:Int = at + x * 8;
							r = wide(rd, p); g = wide(rd, p + 2); b = wide(rd, p + 4); a = wide(rd, p + 6);
						}
					case 2:
						if(depth == 8)
						{
							var p:Int = at + x * 3;
							r = get(rd, p); g = get(rd, p + 1); b = get(rd, p + 2);
							if(r == clearR && g == clearG && b == clearB) a = 0;
						}
						else
						{
							var p:Int = at + x * 6;
							if(((get(rd, p) << 8) | get(rd, p + 1)) == clearR && ((get(rd, p + 2) << 8) | get(rd, p + 3)) == clearG
								&& ((get(rd, p + 4) << 8) | get(rd, p + 5)) == clearB) a = 0;
							r = wide(rd, p); g = wide(rd, p + 2); b = wide(rd, p + 4);
						}
					case 4:
						if(depth == 8)
						{
							var p:Int = at + x * 2;
							r = g = b = get(rd, p); a = get(rd, p + 1);
						}
						else
						{
							var p:Int = at + x * 4;
							r = g = b = wide(rd, p); a = wide(rd, p + 2);
						}
					case 0:
						var value:Int = sample(rd, at, x, depth);
						if(value == clearGray) a = 0;
						r = g = b = (depth == 16) ? ((value * 255 + 32895) >> 16) : (depth == 8 ? value : Std.int(value * 255 / max));
					case 3:
						var index:Int = sample(rd, at, x, depth);
						if(index < paletteSize)
						{
							r = palette.get(index * 3); g = palette.get(index * 3 + 1); b = palette.get(index * 3 + 2);
						}
						if(index < alphaSize) a = paletteAlpha.get(index);
				}

				if(a == 0)
				{
					r = g = b = 0;
				}
				else if(a != 255)
				{
					// about color * alpha / 255, the way lime does it
					var row:Int = a << 8;
					r = get(multiplied, row | r);
					g = get(multiplied, row | g);
					b = get(multiplied, row | b);
				}
				set(od, o, b);
				set(od, o + 1, g);
				set(od, o + 2, r);
				set(od, o + 3, a);
				o += 4;
			}
		}
		return out;
	}

	// What each color comes out as for each alpha (alpha * 256 + color): about color * alpha / 255, the way lime does it.
	// Made once, by whichever thread needs it first (two making it at once make the same thing)
	static var multipliedTable:BytesData = null;

	// (seconds spent on each part, for `--checkpng`)
	public static var inflateTime:Float = 0;
	public static var unfilterTime:Float = 0;
	public static var pixelsTime:Float = 0;
	static function getMultiplied():BytesData
	{
		if(multipliedTable != null) return multipliedTable;

		var table:Bytes = Bytes.alloc(65536);
		for (a in 0...256)
			for (c in 0...256)
				table.set((a << 8) | c, (c * ((a + 1) * 257)) >> 16); //(lime's own numbers: `RGBA.h`, `__alpha16`)
		multipliedTable = table.getData();
		return multipliedTable;
	}

	// Bytes without checking where they are (the sizes are checked before): the checks made reading a big image several times slower
	static inline function get(data:BytesData, pos:Int):Int
		return #if cpp cpp.NativeArray.unsafeGet(data, pos) #else Bytes.ofData(data).get(pos) #end;

	static inline function set(data:BytesData, pos:Int, value:Int):Void
		#if cpp cpp.NativeArray.unsafeSet(data, pos, cast(value & 0xFF)) #else Bytes.ofData(data).set(pos, value) #end;

	// A value of 16 bits made into one of 8, rounded like lime does (libpng's `png_set_scale_16`)
	static inline function wide(data:BytesData, pos:Int):Int
		return ((((get(data, pos) << 8) | get(data, pos + 1)) * 255) + 32895) >> 16;

	// One value of a row, of any size up to 16 bits
	static inline function sample(raw:BytesData, at:Int, x:Int, depth:Int):Int
	{
		return switch(depth)
		{
			case 8: get(raw, at + x);
			case 16: (get(raw, at + x * 2) << 8) | get(raw, at + x * 2 + 1);
			default:
				var bit:Int = x * depth;
				(get(raw, at + (bit >> 3)) >> (8 - depth - (bit & 7))) & ((1 << depth) - 1);
		}
	}
}

typedef PngPixels = {width:Int, height:Int, pixels:Bytes};
