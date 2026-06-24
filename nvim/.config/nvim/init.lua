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

-- Leader MUST be set before lazy.setup so plugin <leader> mappings (telescope,
-- bufferline) bind to Space rather than the default backslash.
vim.g.mapleader = " "

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
  -- Treesitter on the `main` branch (the rewrite) — required for Neovim 0.11+.
  -- On main, parsers are installed via install() and highlighting is started
  -- per-buffer with vim.treesitter.start() (there is no `highlight` module).
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter")
      if ok and ts.install then
        ts.install({ "lua", "python", "c", "cpp", "java", "json", "markdown", "bash" })
      end
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "lua", "python", "c", "cpp", "java", "json", "markdown", "bash", "sh" },
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,
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

  -- Completion: nvim-cmp with LSP, buffer, path, snippets, and the goat source.
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()  -- friendly-snippets
      local goat = dofile(vim.fn.expand("~/projects/goat/tools/nvim/goat.lua"))
      cmp.register_source("goat", goat.cmp_source())
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        completion = { keyword_length = 0 },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "goat" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
        }),
      })
    end,
  },

  -- Minimap (code overview on the right). Pure Lua, renders with block
  -- characters that any monospace font (incl. FiraCode Nerd Font) has — no
  -- external binary, no braille font dependency.
  {
    "echasnovski/mini.map",
    version = false,
    config = function()
      local map = require("mini.map")
      map.setup({
        symbols = {
          encode = map.gen_encode_symbols.block("2x2"),
          scroll_line = "█",
          scroll_view = "┃",
        },
        window = {
          width = 12,
          winblend = 0,
          show_integration_count = false,
        },
        integrations = {
          map.gen_integration.builtin_search(),
          map.gen_integration.diagnostic(),
        },
      })
      -- Command aliases for muscle memory (mini.map is keymap-driven by default).
      vim.api.nvim_create_user_command("Minimap", function() map.toggle() end, {})
      vim.api.nvim_create_user_command("MinimapToggle", function() map.toggle() end, {})
    end,
  },

  -- File explorer sidebar, VSCode-like.
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = { width = 24 },
        renderer = { group_empty = false },  -- show single-child folders normally
        update_focused_file = { enable = true },
        hijack_directories = { enable = true, auto_open = true },
        -- Show everything: dotfiles and files ignored by git (e.g. build PDFs).
        filters = {
          dotfiles = false,
          git_ignored = false,
        },
        -- Don't prompt "Which window?" — open directly / in a fresh split.
        actions = {
          open_file = {
            window_picker = { enable = false },
          },
        },
      })
    end,
  },

  -- Telescope: fuzzy finder (files, live grep, buffers). live_grep needs the
  -- `ripgrep` binary; the dotfiles installer provides it.
  {
    "nvim-telescope/telescope.nvim",
    -- master (not 0.1.x): the stable branch calls nvim-treesitter's removed
    -- ft_to_lang; master uses the modern treesitter API.
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      local opts = { noremap = true, silent = true }
      vim.keymap.set("n", "<leader>f", builtin.find_files, vim.tbl_extend("force", opts, { desc = "find files" }))
      vim.keymap.set("n", "<leader>/", builtin.live_grep,  vim.tbl_extend("force", opts, { desc = "live grep" }))
      vim.keymap.set("n", "<leader>b", builtin.buffers,    vim.tbl_extend("force", opts, { desc = "open buffers" }))
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, vim.tbl_extend("force", opts, { desc = "help tags" }))
      -- Vertical layout = results span the full window width (preview on top),
      -- and line_width="full" stops the message being truncated to a narrow column.
      vim.keymap.set("n", "<leader>fd", function()
        builtin.diagnostics({
          line_width = "full",
          layout_strategy = "vertical",
          layout_config = { width = 0.9, height = 0.9, preview_height = 0.4 },
        })
      end, vim.tbl_extend("force", opts, { desc = "diagnostics (all warnings/errors)" }))
      -- Git history / status — run in the CURRENT FILE's directory so it uses
      -- that file's repo (handles a non-git parent folder with git subprojects).
      local function git_cwd()
        local f = vim.api.nvim_buf_get_name(0)
        return (f ~= "" and vim.fn.fnamemodify(f, ":h")) or vim.loop.cwd()
      end
      -- Wrap a git picker so that, outside a repo, we show a tidy notification
      -- instead of telescope's raw "not a git directory" stack traceback.
      local function git_picker(fn)
        return function()
          local cwd = git_cwd()
          vim.fn.system({ "git", "-C", cwd, "rev-parse", "--is-inside-work-tree" })
          if vim.v.shell_error ~= 0 then
            vim.notify("Not a git repository: " .. cwd, vim.log.levels.WARN)
            return
          end
          fn({ cwd = cwd })
        end
      end
      vim.keymap.set("n", "<leader>gc", git_picker(builtin.git_commits),
        vim.tbl_extend("force", opts, { desc = "git commits (repo history)" }))
      vim.keymap.set("n", "<leader>gf", git_picker(builtin.git_bcommits),
        vim.tbl_extend("force", opts, { desc = "git file history" }))
      vim.keymap.set("n", "<leader>gs", git_picker(builtin.git_status),
        vim.tbl_extend("force", opts, { desc = "git status" }))
    end,
  },

  -- Bufferline: VSCode-style tabs across the top for open buffers.
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          numbers = "ordinal",            -- show 1,2,3… matching <leader>1-9
          diagnostics = false,            -- no LSP wired up yet
          show_buffer_close_icons = true,
          show_close_icon = false,
          offsets = {
            { filetype = "NvimTree", text = "File Explorer", separator = true },
          },
        },
      })
      -- Cycle buffers (vim-unimpaired style; clicking a tab also works).
      local o = { noremap = true, silent = true }
      vim.keymap.set("n", "]b", "<cmd>BufferLineCycleNext<cr>", o)
      vim.keymap.set("n", "[b", "<cmd>BufferLineCyclePrev<cr>", o)
      -- Jump straight to tab N (like Alt+1..9 in a browser).
      for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", o)
      end
    end,
  },

  -- LSP: mason installs the servers, lspconfig + the native vim.lsp API wire
  -- them up. Java (jdtls) is intentionally left out — it wants nvim-jdtls.
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      require("mason").setup()
      local caps = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("*", { capabilities = caps })
      require("mason-lspconfig").setup({
        ensure_installed = { "clangd", "lua_ls", "pyright" },
      })
      -- Buffer-local keymaps once a server attaches.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local o = { buffer = ev.buf, silent = true }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, o)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, o)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, o)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, o)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, o)
          -- Jump to prev/next diagnostic AND pop up its message (float = true).
          vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, o)
          vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, o)
          -- Show the diagnostic(s) on the current line in a float. focus=false
          -- keeps the cursor in the buffer, so any motion dismisses the popup
          -- (and a second <leader>d won't trap focus inside the float).
          vim.keymap.set("n", "<leader>d", function()
            vim.diagnostic.open_float({ focus = false, scope = "line" })
          end, vim.tbl_extend("force", o, { desc = "Show diagnostic (float)" }))
        end,
      })
    end,
  },

  -- Git signs in the gutter + hunk navigation.
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    config = function()
      require("gitsigns").setup({
        on_attach = function(buf)
          local gs = require("gitsigns")
          local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
          end
          map("]c", function() gs.nav_hunk("next") end, "Next hunk")
          map("[c", function() gs.nav_hunk("prev") end, "Previous hunk")
          map("<leader>ga", gs.stage_hunk, "Stage hunk")
          map("<leader>gp", gs.preview_hunk, "Preview hunk")
          map("<leader>gb", gs.blame_line, "Blame line")
        end,
      })
    end,
  },

  -- which-key: shows available keybindings as you type the leader.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = { spec = { { "<leader>g", group = "git" } } },
  },

  -- gcc / gc to (un)comment.
  { "numToStr/Comment.nvim", opts = {} },

  -- Auto-close brackets/quotes.
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

  -- Format on save (uses LSP as fallback when no formatter is configured).
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        java = { "google-java-format" },
      },
      format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
    },
  },

  -- Statusline (mode, git branch, diagnostics, position).
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto", globalstatus = true } },
  },
})

-- Treesitter parser install + highlighting are handled in the plugin's
-- config() above (main branch API). LaTeX intentionally uses vimtex's
-- highlighting rather than a treesitter parser.

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
vim.opt.fillchars:append({ eob = " " })  -- hide the ~ end-of-buffer markers
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
-- (mapleader is set near the top, before lazy.setup.)
local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

keymap("n", "<leader>w", ":w<CR>", { noremap = true, silent = true, desc = "Write" })
keymap("n", "<leader>q", ":q<CR>", { noremap = true, silent = true, desc = "Quit" })
keymap("n", "<leader>x", ":x<CR>", { noremap = true, silent = true, desc = "Write and quit" })
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)
keymap("n", "<leader>h", ":nohlsearch<CR>", opts)
keymap("n", "<C-d>", "<C-d>zz", opts)
keymap("n", "<C-u>", "<C-u>zz", opts)
keymap("n", "x", '"_x', opts)

-- Disable the arrow keys in normal mode to force using hjkl.
keymap("n", "<Up>",    "<Nop>", opts)
keymap("n", "<Down>",  "<Nop>", opts)
keymap("n", "<Left>",  "<Nop>", opts)
keymap("n", "<Right>", "<Nop>", opts)


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


-- Minimap toggle (mini.map). Opens a block-character code overview on the right.
vim.keymap.set("n", "<leader>m", function() require("mini.map").toggle() end,
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

-- When `:x`/`:q` would leave only the nvim-tree window, close the tree too so
-- nvim exits cleanly. Uses QuitPre (fires only on an actual quit command), so
-- it does NOT trigger at startup for `nvim .`.
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local tree_wins = {}
    local wins = vim.api.nvim_list_wins()
    for _, w in ipairs(wins) do
      local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
      if bufname:match("NvimTree_") ~= nil then
        table.insert(tree_wins, w)
      end
    end
    -- Exactly one non-tree window is being quit -> close the tree window(s).
    if #tree_wins == #wins - 1 then
      for _, w in ipairs(tree_wins) do
        vim.api.nvim_win_close(w, true)
      end
    end
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
