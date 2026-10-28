package;

import haxe.io.Bytes;
import haxe.io.Output;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Makes a .zip of a folder, one file at a time (only one is in memory at once).
 * The names are written as UTF-8, and a file that doesn't get smaller compressed (.ogg, .png...) is stored as it is.
 */
class ZipMaker
{
	public static function folder(folder:String, archive:String)
	{
		var names:Array<String> = Tools.filesIn(folder);
		names.sort(Tools.compare);
		if (names.length > 0xFFFF) Tools.fail('Too many files for a .zip: ${names.length}');

		var out:Output = File.write(archive, true);
		var central = new haxe.io.BytesOutput();
		var offset:Float = 0.0;

		for (name in names)
		{
			var data:Bytes = File.getBytes('$folder/$name');
			var crc:Int = haxe.crypto.Crc32.make(data);
			var stored:Bytes = data;
			var method:Int = 0;
			if (data.length > 0)
			{
				var zlib:Bytes = haxe.zip.Compress.run(data, 6);
				// (zlib's two bytes of header and four of checksum off: a .zip has the deflate data alone)
				if (zlib.length - 6 < data.length)
				{
					stored = zlib.sub(2, zlib.length - 6);
					method = 8;
				}
			}
			var nameBytes:Bytes = Bytes.ofString(name);
			var time:Int = dosTime(FileSystem.stat('$folder/$name').mtime);
			if (offset + 30 + nameBytes.length + stored.length > 4294967295.0) Tools.fail('The .zip would be bigger than 4 GB');

			// the file's own header, then its data
			out.writeInt32(0x04034B50);
			writeCommon(out, method, time, crc, stored.length, data.length, nameBytes.length);
			out.writeUInt16(0); // (no extra fields)
			out.write(nameBytes);
			out.write(stored);

			// and its line in the list at the end
			central.writeInt32(0x02014B50);
			central.writeUInt16(0x0314); // (made by: Unix, version 2.0, so the permissions below are read)
			writeCommon(central, method, time, crc, stored.length, data.length, nameBytes.length);
			central.writeUInt16(0); // extra fields
			central.writeUInt16(0); // comment
			central.writeUInt16(0); // disk
			central.writeUInt16(0); // internal attributes
			central.writeInt32(name.toLowerCase().endsWith('.exe') || !name.contains('.') ? 0x81ED0000 : 0x81A40000); // (rwxr-xr-x / rw-r--r--)
			central.writeInt32(u32(offset));
			central.write(nameBytes);

			offset += 30 + nameBytes.length + stored.length;
		}

		var list:Bytes = central.getBytes();
		out.write(list);
		out.writeInt32(0x06054B50);
		out.writeUInt16(0); // disk
		out.writeUInt16(0); // disk with the list
		out.writeUInt16(names.length);
		out.writeUInt16(names.length);
		out.writeInt32(list.length);
		out.writeInt32(u32(offset));
		out.writeUInt16(0); // comment
		out.close();
	}

	// (a number up to 4 GB, in the 32 bits Haxe's Int has)
	static function u32(value:Float):Int
		return Std.int(value > 2147483647 ? value - 4294967296 : value);

	static function writeCommon(o:Output, method:Int, time:Int, crc:Int, compressedSize:Int, size:Int, nameLength:Int)
	{
		o.writeUInt16(20); // version needed: 2.0
		o.writeUInt16(0x0800); // flags: the name is UTF-8
		o.writeUInt16(method);
		o.writeInt32(time);
		o.writeInt32(crc);
		o.writeInt32(compressedSize);
		o.writeInt32(size);
		o.writeUInt16(nameLength);
	}

	// The date of a file the way a .zip keeps it (time in the low 16 bits, date in the high ones)
	static function dosTime(date:Date):Int
	{
		var year:Int = date.getFullYear();
		if (year < 1980) return (1 << 21) | (1 << 16);
		var day:Int = ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
		var time:Int = (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1);
		return (day << 16) | time;
	}
}
