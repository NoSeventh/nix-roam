-- path:.config/wezterm/config/ui.lua
local wezterm = require("wezterm")
local c_init = require("colors.init")
local colors = c_init["flexoki"]
local fonts = { "FiraCode Nerd Font", "Fira Code", "Source Code Pro", "JetBrains Mono" }

return {
	animation_fps = 60,
	max_fps = 120,
	front_end = "WebGpu",
	font = wezterm.font(fonts[4], { weight = "Bold", italic = true }), -- 字体
	font_size = 12,
	webgpu_power_preference = "HighPerformance",
	webgpu_preferred_adapter = wezterm.gui.enumerate_gpus()[1],
	colors = colors, -- 主题配色
	hide_tab_bar_if_only_one_tab = false,
	-- scrollbar
	enable_scroll_bar = false, -- 是否显示滚动条
	-- tab bar
	enable_tab_bar = false, -- 是否显示标签
	use_fancy_tab_bar = true,
	tab_max_width = 25,
	show_tab_index_in_tab_bar = false, -- 是否显示tab标签数
	switch_to_last_active_tab_when_closing_tab = true,
	background = {
		{
			source = { Color = colors.background },
			height = "100%",
			width = "100%",
			opacity = 0.95, -- 背景透明度
		},
	},
	-- window
	initial_cols = 140, -- 默认打开宽高
	initial_rows = 40,
	line_height = 1.06, -- 默认上下间距
	window_padding = { -- 四周padding，为0消除边框间距
		left = 10,
		right = 10,
		top = 10,
		bottom = 7,
	},
	window_close_confirmation = "NeverPrompt",
	inactive_pane_hsb = {
		saturation = 0.9,
		brightness = 0.65,
	},
	window_decorations = "NONE",
	default_cursor_style = "BlinkingBar", -- 改变光标形状
}
