package funkin.audio.visualize.dsp;

// (V-Slice's own imports, from its funkin/import.hx: this file is V-Slice's)
#if !macro
import funkin.util.Constants;
import funkin.Assets;
import funkin.Paths;
import funkin.Preferences;
import flixel.FlxG;
import haxe.ds.Option;

using Lambda;
using StringTools;
using thx.Arrays;
using funkin.util.tools.ArraySortTools;
using funkin.util.tools.ArrayTools;
using funkin.util.tools.FloatTools;
using funkin.util.tools.Int64Tools;
using funkin.util.tools.IntTools;
using funkin.util.tools.IteratorTools;
using funkin.util.tools.MapTools;
using funkin.util.tools.SongEventDataArrayTools;
using funkin.util.tools.SongNoteDataArrayTools;
using funkin.util.tools.StringTools;
using funkin.util.AnsiUtil;
#end

/**
 * Complex number representation.
 */
@:forward(real, imag) @:notNull @:pure @:nullSafety
abstract Complex({
  final real:Float;
  final imag:Float;
})
{
  public inline function new(real:Float, imag:Float) this = {real: real, imag: imag};

  /**
   * Makes a Complex number with the given Float as its real part and a zero imag part.
   */
  @:from
  public static inline function fromReal(r:Float) return new Complex(r, 0);

  /**
   * Complex argument, in radians.
   */
  public var angle(get, never):Float;

  inline function get_angle() return Math.atan2(this.imag, this.real);

  /**
   * Complex module.
   */
  public var magnitude(get, never):Float;

  inline function get_magnitude() return Math.sqrt(this.real * this.real + this.imag * this.imag);

  @:op(A + B)
  public inline function add(rhs:Complex):Complex return new Complex(this.real + rhs.real, this.imag + rhs.imag);

  @:op(A - B)
  public inline function sub(rhs:Complex):Complex return new Complex(this.real - rhs.real, this.imag - rhs.imag);

  @:op(A * B)
  public inline function mult(rhs:Complex):Complex return new Complex(this.real * rhs.real - this.imag * rhs.imag, this.real * rhs.imag + this.imag * rhs.real);

  /**
   * Returns the complex conjugate, does not modify this object.
   */
  public inline function conj():Complex return new Complex(this.real, -this.imag);

  /**
   * Multiplication by a real factor, does not modify this object.
   */
  public inline function scale(k:Float):Complex return new Complex(this.real * k, this.imag * k);

  public inline function copy():Complex return new Complex(this.real, this.imag);

  /**
   * The imaginary unit.
   */
  public static final im = new Complex(0, 1);

  /**
   * The complex zero.
   */
  public static final zero = new Complex(0, 0);

  /**
   * Computes the complex exponential `e^(iw)`.
   */
  public static inline function exp(w:Float) return new Complex(Math.cos(w), Math.sin(w));
}
