package com.veriton.vortexengine;

import android.app.Activity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;

import java.lang.reflect.Field;

/**
 * The game drawn at a lower resolution than the phone's screen, and stretched to it by the phone itself (the screen's own
 * scaler, which costs nothing): a phone's screen has many more pixels than the game's 1280x720, and drawing all of them is what
 * slows its graphics card down. See backend.MobileGraphics.
 *
 * Lime's activity (SDL's) is reached by reflection, so this doesn't depend on its classes.
 */
public class RenderScale
{
	private static int fixedWidth = 0;
	private static int fixedHeight = 0;
	private static boolean listening = false;

	/**
	 * Draws the game at that many lines (0: the screen's own), keeping the screen's shape.
	 */
	public static void setLines(final int lines)
	{
		final Activity activity = activity();
		final SurfaceView surface = surface();
		if (activity == null || surface == null) return;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				// (the view keeps covering the whole screen: given a fixed size, a SurfaceView makes itself that size unless its
				// layout says otherwise, and the game would be drawn small in a corner instead of stretched)
				ViewGroup.LayoutParams params = surface.getLayoutParams();
				if (params != null && (params.width != ViewGroup.LayoutParams.MATCH_PARENT || params.height != ViewGroup.LayoutParams.MATCH_PARENT))
				{
					params.width = ViewGroup.LayoutParams.MATCH_PARENT;
					params.height = ViewGroup.LayoutParams.MATCH_PARENT;
					surface.setLayoutParams(params);
				}

				View parent = (View) surface.getParent();
				int viewWidth = (parent != null && parent.getWidth() > 0) ? parent.getWidth() : surface.getWidth();
				int viewHeight = (parent != null && parent.getHeight() > 0) ? parent.getHeight() : surface.getHeight();
				if (viewWidth <= 0 || viewHeight <= 0) return;

				SurfaceHolder holder = surface.getHolder();
				if (lines <= 0 || lines >= viewHeight)
				{
					fixedWidth = 0;
					fixedHeight = 0;
					holder.setSizeFromLayout();
				}
				else
				{
					fixedHeight = lines;
					fixedWidth = Math.round(viewWidth * (lines / (float) viewHeight));
					holder.setFixedSize(fixedWidth, fixedHeight);
				}
				listenToTouches(surface);
			}
		});
	}

	// SDL turns a touch into the game's coordinates dividing it by the size of what's drawn (its "mWidth" and "mHeight"), which
	// isn't the screen's anymore: those are given back the screen's size after every time SDL sets them (when what's drawn changes
	// size). A listener of the touches of its own wouldn't do: SDL sets its own again every time the game comes back to the front
	private static void listenToTouches(final SurfaceView surface)
	{
		if (!listening)
		{
			listening = true;
			surface.getHolder().addCallback(new SurfaceHolder.Callback()
			{
				@Override public void surfaceCreated(SurfaceHolder holder) {}
				@Override public void surfaceDestroyed(SurfaceHolder holder) {}
				@Override public void surfaceChanged(SurfaceHolder holder, int format, int width, int height)
				{
					fixTouchSize(surface);
				}
			});
		}
		fixTouchSize(surface);
	}

	private static void fixTouchSize(SurfaceView surface)
	{
		if (fixedWidth <= 0 || fixedHeight <= 0) return;
		View parent = (View) surface.getParent();
		int width = (parent != null && parent.getWidth() > 0) ? parent.getWidth() : surface.getWidth();
		int height = (parent != null && parent.getHeight() > 0) ? parent.getHeight() : surface.getHeight();
		if (width <= 0 || height <= 0) return;
		try
		{
			Class<?> type = surface.getClass();
			while (type != null && !type.getName().equals("org.libsdl.app.SDLSurface")) type = type.getSuperclass();
			if (type == null) return;
			Field widthField = type.getDeclaredField("mWidth");
			Field heightField = type.getDeclaredField("mHeight");
			widthField.setAccessible(true);
			heightField.setAccessible(true);
			widthField.setFloat(surface, (float) width);
			heightField.setFloat(surface, (float) height);
		}
		catch (Throwable error) {}
	}

	private static Object field(String name)
	{
		try
		{
			Class<?> sdl = Class.forName("org.libsdl.app.SDLActivity");
			Field field = sdl.getDeclaredField(name);
			field.setAccessible(true);
			return field.get(null);
		}
		catch (Throwable error)
		{
			return null;
		}
	}

	private static Activity activity()
	{
		Object value = field("mSingleton");
		return (value instanceof Activity) ? (Activity) value : null;
	}

	private static SurfaceView surface()
	{
		Object value = field("mSurface");
		return (value instanceof SurfaceView) ? (SurfaceView) value : null;
	}
}
