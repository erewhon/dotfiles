local wezterm = require 'wezterm'
return {
	-- color_scheme = 'termnial.sexy',
    --color_scheme = 'Dark Violet (base16)',
    --color_scheme = 'BlueBerryPie', -- Almost too dark...
    --color_scheme = 'C64',
	color_scheme = 'Catppuccin Mocha',
    --color_scheme = 'purplepeter',
	enable_tab_bar = false,
	font_size = 16.0,
	font = wezterm.font('JetBrainsMono Nerd Font'),
	-- macos_window_background_blur = 40,
	macos_window_background_blur = 30,

    default_cursor_style = "BlinkingBar",
    cursor_blink_rate = 500,
    -- cursor_blink_ease_in = "Linear",
    -- cursor_blink_ease_out = "Linear",
    -- cursor_thickness = 2,

    window_background_gradient = {
      -- Can be "Vertical" or "Horizontal".  Specifies the direction
      -- in which the color gradient varies.  The default is "Horizontal",
      -- with the gradient going from left-to-right.
      -- Linear and Radial gradients are also supported; see the other
      -- examples below
      orientation = 'Vertical',

      -- Specifies the set of colors that are interpolated in the gradient.
      -- Accepts CSS style color specs, from named colors, through rgb
      -- strings and more
      colors = {
        '#0f0c29',
        '#302b63',
        '#24243e',
      },

      -- Instead of specifying `colors`, you can use one of a number of
      -- predefined, preset gradients.
      -- A list of presets is shown in a section below.
      -- preset = "Warm",
      --preset = 'Viridis',

      -- Specifies the interpolation style to be used.
      -- "Linear", "Basis" and "CatmullRom" as supported.
      -- The default is "Linear".
      interpolation = 'Linear',

      -- How the colors are blended in the gradient.
      -- "Rgb", "LinearRgb", "Hsv" and "Oklab" are supported.
      -- The default is "Rgb".
      blend = 'Rgb',

      -- To avoid vertical color banding for horizontal gradients, the
      -- gradient position is randomly shifted by up to the `noise` value
      -- for each pixel.
      -- Smaller values, or 0, will make bands more prominent.
      -- The default value is 64 which gives decent looking results
      -- on a retina macbook pro display.
      -- noise = 64,

      -- By default, the gradient smoothly transitions between the colors.
      -- You can adjust the sharpness by specifying the segment_size and
      -- segment_smoothness parameters.
      -- segment_size configures how many segments are present.
      -- segment_smoothness is how hard the edge is; 0.0 is a hard edge,
      -- 1.0 is a soft edge.

      -- segment_size = 11,
      -- segment_smoothness = 0.0,
    },

	-- window_background_image = '/Users/omerhamerman/Downloads/3840x1080-Wallpaper-041.jpg',
	-- window_background_image_hsb = {
	-- 	brightness = 0.01,
	-- 	hue = 1.0,
	-- 	saturation = 0.5,
	-- },
	window_background_opacity = 0.85,
	window_decorations = 'RESIZE | MACOS_FORCE_ENABLE_SHADOW',
	keys = {
		{
			key = 'f',
			mods = 'CMD',
			action = wezterm.action.ToggleFullScreen,
		},
		--{
		--	key = '\'',
		--	mods = 'CTRL',
		--	action = wezterm.action.ClearScrollback 'ScrollbackAndViewport',
		--},
	},
	--mouse_bindings = {
	--  -- Ctrl-click will open the link under the mouse cursor
	--  {
	--    event = { Up = { streak = 1, button = 'Left' } },
	--    mods = 'CTRL',
	--    action = wezterm.action.OpenLinkAtMouseCursor,
	--  },
	--},
}
