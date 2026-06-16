-- =====================
-- Lazy.nvim bootstrap
-- =====================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Disable netrw in favour of nvim-tree (must be set before plugins load).
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- =====================
-- Plugins
-- =====================
require("lazy").setup({
  -- GitHub Copilot. Run :Copilot setup once to authenticate.
  {
    "github/copilot.vim",
    event = "InsertEnter",
    init = function()
      -- Use a dedicated accept key instead of <Tab> (Tab is used by nvim-cmp).
      vim.g.copilot_no_tab_map = true
    end,
  },
  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
  },

  -- VimTeX
  {
    "lervag/vimtex",
    ft = "tex",
    init = function()
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.maplocalleader = ","
    end,
  },

  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    config = function()
      vim.cmd("colorscheme catppuccin")
    end,
  },

  -- Completion: nvim-cmp with the goat key source (auto-popup inside
  -- \goatlookup{} / \goatdefine{}). Pure Lua, native snippets, no extra deps.
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function()
      local cmp = require("cmp")
      local goat = dofile(vim.fn.expand("~/projects/goat/tools/nvim/goat.lua"))
      cmp.register_source("goat", goat.cmp_source())
      cmp.setup({
        snippet = { expand = function(args) vim.snippet.expand(args.body) end },
        completion = { keyword_length = 0 },
        sources = { { name = "goat" } },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
        }),
      })
    end,
  },

  -- Minimap: VSCode-style scaled, syntax-colored code overview. Renders with
  -- braille, so it needs a terminal font that has Braille Patterns — the
  -- Alacritty config uses IosevkaTerm Nerd Font for exactly this.
  {
    "Isrothy/neominimap.nvim",
    version = "v3.*.*",
    lazy = false,
    init = function()
      vim.g.neominimap = {
        auto_enable = true,
      }
      -- Command aliases for muscle memory.
      vim.api.nvim_create_user_command("Minimap", "Neominimap toggle", {})
      vim.api.nvim_create_user_command("MinimapToggle", "Neominimap toggle", {})
    end,
  },

  -- File explorer sidebar, VSCode-like.
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = { width = 32 },
        renderer = { group_empty = true },
        update_focused_file = { enable = true },
        hijack_directories = { enable = true, auto_open = true },
      })
    end,
  },
})

-- =====================
-- Treesitter setup
-- =====================
require('nvim-treesitter').setup {
  ensure_installed = { "lua", "python", "latex" },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}

-- =====================
-- VimTeX: single-file mainfile detection & auto-compile
-- =====================
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*.tex",
  callback = function()
    if vim.fn.exists(":VimtexCompile") == 2 then
      vim.g.vimtex_mainfile = vim.api.nvim_buf_get_name(0)
      vim.cmd("VimtexCompile")
    end
  end,
})

-- =====================
-- General settings
-- =====================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

vim.opt.updatetime = 300
vim.opt.timeoutlen = 500

vim.cmd([[autocmd FileType qf resize 10]])
vim.cmd([[autocmd FileType qf wincmd J]])
vim.g.vimtex_quickfix_open_on_warning = 0
vim.g.vimtex_quickfix_height = 10



vim.cmd("syntax enable")
vim.cmd("filetype plugin indent on")

-- =====================
-- Keymaps
-- =====================
vim.g.mapleader = " "
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<leader>w", ":w<CR>", opts)
keymap("n", "<leader>q", ":q<CR>", opts)
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)
keymap("n", "<leader>h", ":nohlsearch<CR>", opts)
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "x", '"_x', opts)


-- Copilot keymaps (insert mode):
--   <C-J> accept suggestion, <C-]> dismiss, Alt-] / Alt-[ cycle suggestions.
vim.api.nvim_set_keymap("i", "<C-J>", 'copilot#Accept("\\<CR>")', { silent = true, expr = true, replace_keycodes = false })
vim.api.nvim_set_keymap("i", "<M-]>", "copilot#Next()", { silent = true, expr = true })
vim.api.nvim_set_keymap("i", "<M-[>", "copilot#Previous()", { silent = true, expr = true })


-- Fold functions in code
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99

vim.opt.foldlevelstart = 0
vim.opt.foldenable = true


-- Minimap toggle (neominimap). VSCode-style colored code overview.
vim.keymap.set("n", "<leader>m", "<cmd>Neominimap toggle<cr>",
  { noremap = true, silent = true, desc = "toggle minimap" })


-- =====================
-- File explorer (nvim-tree)
--   <leader>e toggles the sidebar. Starting `nvim <dir>` (e.g. `nvim .`)
--   opens the tree automatically, like `code .`.
-- =====================
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { noremap = true, silent = true })

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function(data)
    -- Only when nvim was opened on a directory argument.
    if vim.fn.isdirectory(data.file) ~= 1 then return end
    vim.cmd.cd(data.file)
    require("nvim-tree.api").tree.open()
  end,
})


-- =====================
-- Goat library: key completion for \goatlookup{} / \goatdefine{}
--   In a .tex buffer: inside \goatlookup{ or \goatdefine{ press <C-x><C-u> to
--   search keys, or run :GoatPick. (pcall-guarded so a missing file is harmless.)
-- =====================
pcall(function()
  dofile(vim.fn.expand('~/projects/goat/tools/nvim/goat.lua')).setup()
end)
