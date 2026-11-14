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
	private static int wantedLines = 0;
	private static int fixedWidth = 0;
	private static int fixedHeight = 0;

	// (the surface the listeners were put on: SDL makes a new one when its activity is made again)
	private static SurfaceView listenedSurface = null;

	/**
	 * Draws the game at that many lines (0: the screen's own), keeping the screen's shape.
	 */
	public static void setLines(final int lines)
	{
		final Activity activity = activity();
		if (activity == null) return;
		wantedLines = lines;

		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				SurfaceView surface = surface();
				if (surface == null) return;
				listenTo(surface);
				fit(surface);
			}
		});
	}

	// The size the game is drawn at, from the size the view has now
	private static void fit(SurfaceView surface)
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

		int viewWidth = viewWidth(surface);
		int viewHeight = viewHeight(surface);
		if (viewWidth <= 0 || viewHeight <= 0) return;

		SurfaceHolder holder = surface.getHolder();
		if (wantedLines <= 0 || wantedLines >= viewHeight)
		{
			if (fixedWidth != 0 || fixedHeight != 0) holder.setSizeFromLayout();
			fixedWidth = 0;
			fixedHeight = 0;
		}
		else
		{
			int width = Math.round(viewWidth * (wantedLines / (float) viewHeight));
			if (width != fixedWidth || wantedLines != fixedHeight)
			{
				fixedWidth = width;
				fixedHeight = wantedLines;
				holder.setFixedSize(fixedWidth, fixedHeight);
			}
		}
		fixTouchSize(surface);
	}

	/*
	 * Kept up to date with what the view does. SDL turns a touch into the game's coordinates dividing it by the size of what's drawn
	 * (its "mWidth" and "mHeight"), which isn't the screen's anymore: those are given back the screen's size every time SDL sets
	 * them (when what's drawn changes size). And the view itself changes size after the game starts on a lot of phones: the
	 * navigation bar goes away when the game takes the whole screen. The size it's drawn at was worked out from the narrower view,
	 * so it was stretched to the wider one, and the touches were still divided by the narrower one: they landed to the right of the
	 * finger, more the more to the right (a song's right arrow only answered when touched to its left)
	 */
	private static void listenTo(final SurfaceView surface)
	{
		if (listenedSurface == surface) return;
		listenedSurface = surface;

		surface.getHolder().addCallback(new SurfaceHolder.Callback()
		{
			@Override public void surfaceCreated(SurfaceHolder holder) {}
			@Override public void surfaceDestroyed(SurfaceHolder holder) {}
			@Override public void surfaceChanged(SurfaceHolder holder, int format, int width, int height)
			{
				fixTouchSize(surface);
			}
		});

		View.OnLayoutChangeListener resized = new View.OnLayoutChangeListener()
		{
			@Override
			public void onLayoutChange(View view, int left, int top, int right, int bottom, int oldLeft, int oldTop, int oldRight, int oldBottom)
			{
				if (right - left == oldRight - oldLeft && bottom - top == oldBottom - oldTop) return;
				if (listenedSurface != surface) return;
				fit(surface);
			}
		};
		surface.addOnLayoutChangeListener(resized);
		View parent = (View) surface.getParent();
		if (parent != null) parent.addOnLayoutChangeListener(resized);
	}

	// (the touches are given in the view's own pixels: what they're divided by is its size)
	private static int viewWidth(SurfaceView surface)
	{
		if (surface.getWidth() > 0) return surface.getWidth();
		View parent = (View) surface.getParent();
		return (parent != null) ? parent.getWidth() : 0;
	}

	private static int viewHeight(SurfaceView surface)
	{
		if (surface.getHeight() > 0) return surface.getHeight();
		View parent = (View) surface.getParent();
		return (parent != null) ? parent.getHeight() : 0;
	}

	private static void fixTouchSize(SurfaceView surface)
	{
		if (fixedWidth <= 0 || fixedHeight <= 0) return;
		int width = viewWidth(surface);
		int height = viewHeight(surface);
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
