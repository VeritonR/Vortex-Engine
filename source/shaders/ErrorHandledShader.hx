package shaders;

import flixel.system.FlxAssets.FlxShader;
import flixel.addons.display.FlxRuntimeShader;
import lime.graphics.opengl.GLProgram;
import lime.app.Application;

class ErrorHandledShader extends FlxShader implements IErrorHandler
{
	public var shaderName:String = '';
	public dynamic function onError(error:Dynamic):Void {}
	public function new(?shaderName:String)
	{
		this.shaderName = shaderName;
		super();
	}

	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
		try
		{
			final res = super.__createGLProgram(vertexSource, fragmentSource);
			return res;
		}
		catch (error)
		{
			ErrorHandledShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
	
	public static function crashSave(shaderName:String, error:Dynamic, onError:Dynamic) // prevent the app from dying immediately
	{
		if(shaderName == null) shaderName = 'unnamed';
		var alertTitle:String = 'Error on Shader: "$shaderName"';

		trace(error);

		#if !debug
		// Save a crash log on Release builds
		var errMsg:String = "";
		var dateNow:String = Date.now().toString().replace(" ", "_").replace(":", "'");

		if (!FileSystem.exists('./crash/'))
			FileSystem.createDirectory('./crash/');

		var crashLogPath:String = './crash/shader_${shaderName}_${dateNow}.txt';
		File.saveContent(crashLogPath, error);
		Application.current.window.alert('Error log saved at: $crashLogPath', alertTitle);
		#else
		Application.current.window.alert('Error logs aren\'t created on debug builds, check the trace log instead.', alertTitle);
		#end

		onError(error);
	}
}

class ErrorHandledRuntimeShader extends FlxRuntimeShader implements IErrorHandler
{
	public var shaderName:String = '';
	public dynamic function onError(error:Dynamic):Void {}
	public function new(?shaderName:String, ?fragmentSource:String, ?vertexSource:String)
	{
		this.shaderName = shaderName;
		super(fragmentSource, vertexSource);
		fillEmptySamplers();
	}

	/**
	 * An empty image for the images of a shader nobody gave one (V-Slice's rain has a mask and a blurred screen its stage never sets).
	 * When a shader is drawn on a camera OpenFL doesn't unbind an image that isn't there: it reads whatever the last thing drawn left
	 * in its place (the Freeplay DJ, coming from Freeplay: the whole screen was a "puddle" reflecting it upside down on 2Hot). Empty is
	 * what V-Slice's shaders read there. Setting one later replaces it, as usual.
	 */
	static var emptyImage:openfl.display.BitmapData = null;
	function fillEmptySamplers():Void
	{
		try
		{
			if (__glFragmentSource == null || data == null) return;
			for (name in Reflect.fields(data))
			{
				if (name == 'bitmap') continue;
				var input:Dynamic = Reflect.field(data, name);
				if (!Std.isOfType(input, openfl.display.ShaderInput) || input.input != null) continue;

				if (emptyImage == null) emptyImage = new openfl.display.BitmapData(1, 1, true, 0);
				input.input = emptyImage;
			}
		}
		catch (e:Dynamic) {}
	}

	override function __createGLProgram(vertexSource:String, fragmentSource:String):GLProgram
	{
		try
		{
			final res = super.__createGLProgram(vertexSource, fragmentSource);
			return res;
		}
		catch (error)
		{
			ErrorHandledShader.crashSave(this.shaderName, error, onError);
			return null;
		}
	}
}

interface IErrorHandler
{
	public var shaderName:String;
	public dynamic function onError(error:Dynamic):Void;
}