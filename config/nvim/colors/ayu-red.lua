-- Dosya: colors/ayu-red.lua
-- Ayu Red: özel renk paleti şablonu
-- Renkleri burada düzenleyerek temanızı özelleştirebilirsiniz.

local M = {}

-- ── Renk Paleti ──────────────────────────────────────────────────────────────
-- Ayu Red: mor-kahve tabanlı, kırmızı vurgulu palet
local colors = {
  bg        = "#0f1419", -- Ana arka plan (Ayu Dark)
  bg_dark   = "#0a0e12", -- Daha koyu arka plan (statusline, tabline)
  bg_light  = "#192026", -- Yüzen pencereler, popup / CursorLine
  fg        = "#bfbdb6", -- Ana ön plan metni
  fg_dark   = "#5c6773", -- Yorum satırları / Soluk metin
  red       = "#f07178", -- Birincil vurgu (kırmızı)
  red_soft  = "#f07178", -- Yumuşak kırmızı
  orange    = "#ffad66", -- Turuncu vurgu
  yellow    = "#ffd173", -- Uyarı / sabit / Değişkenler
  green     = "#b8cc52", -- Başarı / string
  cyan      = "#73d0ff", -- Bilgi / fonksiyon
  blue      = "#73d0ff", -- Tip / sınıf
  purple    = "#d2a6ff", -- Özel / macro / Keywordler
  pink      = "#b8cc52", -- Operatör
  border    = "#192026", -- Kenarlık rengi
  selection = "#253340", -- Seçim arka planı
  cursor    = "#f07178", -- İmleç rengi
}

-- ── Highlight Grupları ───────────────────────────────────────────────────────
M.colors = colors

M.setup = function()
  -- Temel UI
  vim.api.nvim_set_hl(0, "Normal",       { fg = colors.fg, bg = colors.bg })
  vim.api.nvim_set_hl(0, "NormalFloat",  { fg = colors.fg, bg = colors.bg_light })
  vim.api.nvim_set_hl(0, "FloatBorder",  { fg = colors.border, bg = colors.bg_light })
  vim.api.nvim_set_hl(0, "Cursor",       { fg = colors.bg, bg = colors.cursor })
  vim.api.nvim_set_hl(0, "CursorLine",   { bg = colors.selection, bold = false })
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = colors.red, bold = true })
  vim.api.nvim_set_hl(0, "LineNr",       { fg = colors.fg_dark })
  vim.api.nvim_set_hl(0, "SignColumn",   { bg = colors.bg })
  vim.api.nvim_set_hl(0, "Visual",       { bg = colors.selection })
  vim.api.nvim_set_hl(0, "Search",      { fg = colors.bg, bg = colors.yellow })
  vim.api.nvim_set_hl(0, "IncSearch",   { fg = colors.bg, bg = colors.red })
  vim.api.nvim_set_hl(0, "MatchParen",  { fg = colors.red, bold = true })
  vim.api.nvim_set_hl(0, "StatusLine",  { fg = colors.fg, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "StatusLineNC",{ fg = colors.fg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "TabLine",     { fg = colors.fg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "TabLineFill", { bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "TabLineSel",  { fg = colors.red, bg = colors.bg })
  vim.api.nvim_set_hl(0, "WinSeparator",{ fg = colors.border })
  vim.api.nvim_set_hl(0, "Pmenu",       { fg = colors.fg, bg = colors.bg_light })
  vim.api.nvim_set_hl(0, "PmenuSel",    { fg = colors.bg, bg = colors.red })
  vim.api.nvim_set_hl(0, "PmenuSbar",   { bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "PmenuThumb",  { bg = colors.red })

  -- Sözdizimi vurgulama
  vim.api.nvim_set_hl(0, "Comment",      { fg = colors.fg_dark, italic = true })
  vim.api.nvim_set_hl(0, "Constant",     { fg = colors.orange })
  vim.api.nvim_set_hl(0, "String",       { fg = colors.green })
  vim.api.nvim_set_hl(0, "Character",    { fg = colors.green })
  vim.api.nvim_set_hl(0, "Number",       { fg = colors.orange })
  vim.api.nvim_set_hl(0, "Boolean",      { fg = colors.orange })
  vim.api.nvim_set_hl(0, "Float",        { fg = colors.orange })
  vim.api.nvim_set_hl(0, "Identifier",   { fg = colors.fg })
  vim.api.nvim_set_hl(0, "Function",     { fg = colors.cyan })
  vim.api.nvim_set_hl(0, "Keyword",      { fg = colors.red, italic = true })
  vim.api.nvim_set_hl(0, "Operator",     { fg = colors.pink })
  vim.api.nvim_set_hl(0, "PreProc",      { fg = colors.purple })
  vim.api.nvim_set_hl(0, "Type",         { fg = colors.blue })
  vim.api.nvim_set_hl(0, "Special",      { fg = colors.red_soft })
  vim.api.nvim_set_hl(0, "Underlined",   { fg = colors.cyan, underline = true })
  vim.api.nvim_set_hl(0, "Error",        { fg = colors.red, bold = true })
  vim.api.nvim_set_hl(0, "WarningMsg",   { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "Todo",         { fg = colors.bg, bg = colors.yellow, bold = true })

  -- Treesitter
  vim.api.nvim_set_hl(0, "@variable",           { fg = colors.fg })
  vim.api.nvim_set_hl(0, "@function",           { fg = colors.cyan })
  vim.api.nvim_set_hl(0, "@function.builtin",   { fg = colors.cyan })
  vim.api.nvim_set_hl(0, "@parameter",          { fg = colors.fg })
  vim.api.nvim_set_hl(0, "@type",              { fg = colors.blue })
  vim.api.nvim_set_hl(0, "@type.builtin",      { fg = colors.blue })
  vim.api.nvim_set_hl(0, "@keyword",            { fg = colors.red, italic = true })
  vim.api.nvim_set_hl(0, "@keyword.operator",  { fg = colors.red })
  vim.api.nvim_set_hl(0, "@string",            { fg = colors.green })
  vim.api.nvim_set_hl(0, "@number",            { fg = colors.orange })
  vim.api.nvim_set_hl(0, "@comment",           { fg = colors.fg_dark, italic = true })
  vim.api.nvim_set_hl(0, "@constant",          { fg = colors.orange })
  vim.api.nvim_set_hl(0, "@constant.builtin",  { fg = colors.orange })
  vim.api.nvim_set_hl(0, "@tag",               { fg = colors.red })
  vim.api.nvim_set_hl(0, "@attribute",         { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "@property",          { fg = colors.fg })
  vim.api.nvim_set_hl(0, "@constructor",       { fg = colors.blue })
  vim.api.nvim_set_hl(0, "@module",            { fg = colors.fg })
  vim.api.nvim_set_hl(0, "@namespace",         { fg = colors.purple })

  -- LSP tanıları
  vim.api.nvim_set_hl(0, "DiagnosticError",   { fg = colors.red })
  vim.api.nvim_set_hl(0, "DiagnosticWarn",    { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "DiagnosticInfo",    { fg = colors.cyan })
  vim.api.nvim_set_hl(0, "DiagnosticHint",    { fg = colors.fg_dark })
  vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = colors.red, bg = "NONE" })
  vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn",  { fg = colors.yellow, bg = "NONE" })
  vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo",  { fg = colors.cyan, bg = "NONE" })
  vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint",  { fg = colors.fg_dark, bg = "NONE" })

  -- Git işaretleri
  vim.api.nvim_set_hl(0, "DiffAdd",    { bg = "#2D3D2D" })
  vim.api.nvim_set_hl(0, "DiffChange", { bg = "#3D352D" })
  vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#3D2D2D" })
  vim.api.nvim_set_hl(0, "GitSignsAdd",    { fg = colors.green })
  vim.api.nvim_set_hl(0, "GitSignsChange", { fg = colors.yellow })
  vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = colors.red })

  -- Neo-tree
  vim.api.nvim_set_hl(0, "NeoTreeNormal",        { fg = colors.fg, bg = colors.bg })
  vim.api.nvim_set_hl(0, "NeoTreeEndOfBuffer",   { fg = colors.bg, bg = colors.bg })
  vim.api.nvim_set_hl(0, "NeoTreeTitleBar",      { fg = colors.fg, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "NeoTreeDirectoryIcon", { fg = colors.cyan })
  vim.api.nvim_set_hl(0, "NeoTreeFileIcon",      { fg = colors.fg })
  vim.api.nvim_set_hl(0, "NeoTreeModified",      { fg = colors.red })
  vim.api.nvim_set_hl(0, "NeoTreeGitAdded",      { fg = colors.green })
  vim.api.nvim_set_hl(0, "NeoTreeGitDeleted",    { fg = colors.red })
  vim.api.nvim_set_hl(0, "NeoTreeGitModified",   { fg = colors.yellow })

  -- Telescope
  vim.api.nvim_set_hl(0, "TelescopeBorder",       { fg = colors.border })
  vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = colors.red })
  vim.api.nvim_set_hl(0, "TelescopeSelection",    { fg = colors.fg, bg = colors.selection })

  -- Bufferline
  vim.api.nvim_set_hl(0, "BufferLineFill",             { bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineBackground",       { fg = colors.fg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineBufferSelected",   { fg = colors.red, bg = colors.bg, bold = true })
  vim.api.nvim_set_hl(0, "BufferLineBufferVisible",    { fg = colors.fg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineSeparator",        { fg = colors.bg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineSeparatorSelected", { fg = colors.bg_dark, bg = colors.bg })
  vim.api.nvim_set_hl(0, "BufferLineSeparatorVisible",  { fg = colors.bg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineModified",         { fg = colors.orange, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineModifiedSelected", { fg = colors.orange, bg = colors.bg })
  vim.api.nvim_set_hl(0, "BufferLineModifiedVisible",  { fg = colors.orange, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineCloseButton",      { fg = colors.fg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineCloseButtonSelected", { fg = colors.red, bg = colors.bg })
  vim.api.nvim_set_hl(0, "BufferLineCloseButtonVisible",  { fg = colors.fg_dark, bg = colors.bg_dark })
  vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", { fg = colors.red, bg = colors.bg })
  vim.api.nvim_set_hl(0, "BufferLineIndicatorVisible",  { fg = colors.bg_dark, bg = colors.bg_dark })

  -- Terminal
  vim.g.terminal_color_0  = colors.bg_dark
  vim.g.terminal_color_1  = colors.red
  vim.g.terminal_color_2  = colors.green
  vim.g.terminal_color_3  = colors.yellow
  vim.g.terminal_color_4  = colors.blue
  vim.g.terminal_color_5  = colors.purple
  vim.g.terminal_color_6  = colors.cyan
  vim.g.terminal_color_7  = colors.fg
  vim.g.terminal_color_8  = colors.fg_dark
  vim.g.terminal_color_9  = colors.red_soft
  vim.g.terminal_color_10 = colors.green
  vim.g.terminal_color_11 = colors.yellow
  vim.g.terminal_color_12 = colors.blue
  vim.g.terminal_color_13 = colors.purple
  vim.g.terminal_color_14 = colors.cyan
  vim.g.terminal_color_15 = "#ffffff"
end

-- colorscheme yükleme giriş noktası
M.setup()
return M
