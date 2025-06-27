-- Use only a single global status line. When using this, make sure to
-- also set WinSeparator in your color theme so that the splits aren't
-- chonky.
vim.opt.laststatus = 3

--[[
-- Notes:
--
-- When updating TreeSitter, you'll want to update the parsers using
-- :TSUpdate manually. Or, you can call :TSInstall to install new parsers.
-- Run :checkhealth nvim_treesitter to see what parsers are setup.
--]]
---------------------------------------------------------------------
-- LSP Clients
---------------------------------------------------------------------
local nvim_lsp = require('lspconfig')

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', ';wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', ';wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', ';wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', ';D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', ';rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', ';ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', ';e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', ';q', '<cmd>lua vim.diagnostic.setloclist()<CR>', opts)
  buf_set_keymap("n", ";f", "<cmd>lua vim.lsp.buf.format()<CR>", opts)

  -- Python-specific mappings
  if vim.bo[bufnr].filetype == 'python' then
    -- Organize imports using none-ls
    buf_set_keymap('n', ';oi', '<cmd>lua vim.lsp.buf.format({ name = "null-ls", filter = function(c) return c.name == "null-ls" end })<CR>', opts)
  end
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { "gopls" }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup { on_attach = on_attach }
end

---------------------------------------------------------------------
-- None-ls (null-ls successor) for Python tooling
---------------------------------------------------------------------
local null_ls = require("null-ls")

null_ls.setup({
  sources = {
    -- Ruff for linting with comprehensive configuration
    null_ls.builtins.diagnostics.ruff.with({
      extra_args = {
        -- Rule selection
        "--select=E,W,F,I,UP,B,C4",  -- pycodestyle, pyflakes, isort, pyupgrade, bugbear, comprehensions

        -- Ignore specific rules
        "--ignore=E501",  -- line too long

        -- Line length
        "--line-length=88",

        -- Target Python version
        "--target-version=py38",

        -- Import sorting configuration
        "--isort-combine-as-imports",
        "--isort-force-sort-within-sections",
        "--isort-lines-after-imports=2",

        -- Per-file ignores
        "--per-file-ignores=__init__.py:F401,test_*.py:F401,test_*.py:F811,tests/*.py:F401,tests/*.py:F811",
      },
    }),

    -- Ruff for formatting and import organization
    null_ls.builtins.formatting.ruff.with({
      extra_args = {
        -- Focus on import organization and basic fixes
        "--select=I,F401,F403,F405",
        "--fix",

        -- Line length
        "--line-length=88",

        -- Import sorting settings
        "--isort-combine-as-imports",
        "--isort-force-sort-within-sections",
        "--isort-lines-after-imports=2",

        -- You can specify your first-party packages here
        -- "--isort-known-first-party=your_package_name",
      },
    }),

    -- Ruff format for code formatting (optional, if you want ruff's formatter)
    null_ls.builtins.formatting.ruff_format.with({
      extra_args = {
        "--line-length=88",
      },
    }),
  },

  on_attach = function(client, bufnr)
    -- Enable format on save for Python files
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          if vim.bo[bufnr].filetype == 'python' then
            vim.lsp.buf.format({
              filter = function(c)
                return c.name == "null-ls"
              end,
              bufnr = bufnr
            })
          end
        end,
      })
    end
  end,
})

-- Create autogroup for formatting
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

---------------------------------------------------------------------
-- Pyright for type checking and auto-imports
---------------------------------------------------------------------
nvim_lsp.pyright.setup {
  on_attach = on_attach,
  settings = {
    python = {
      analysis = {
        -- Enable auto-import completions
        autoImportCompletions = true,
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "basic",

        -- Import-related settings
        reportMissingImports = true,
        reportMissingTypeStubs = false,
        reportOptionalMemberAccess = false,

        -- Additional include/exclude paths (customize as needed)
        include = {"src", "tests", "."},
        exclude = {"**/__pycache__", "build", "dist", ".venv", "node_modules"},

        -- Enable auto-import features
        autoImportCompletions = true,
      },
    },
  },
}

---------------------------------------------------------------------
-- Python-specific commands and keymaps
---------------------------------------------------------------------

-- Custom command to organize imports
vim.api.nvim_create_user_command('PyOrganizeImports', function()
  vim.lsp.buf.format({
    filter = function(client)
      return client.name == "null-ls"
    end
  })
end, { desc = 'Organize Python imports' })

-- Custom command for missing import fixes
vim.api.nvim_create_user_command('PyFixImports', function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return action.kind and (
        action.kind:find("quickfix") or
        action.kind:find("source") or
        action.title:lower():find("import")
      )
    end,
    apply = true,
  })
end, { desc = 'Fix missing Python imports' })

-- Global keymap for quick access (outside of LSP on_attach)
vim.keymap.set('n', '<leader>pi', ':PyFixImports<CR>', { desc = 'Fix missing Python imports' })
vim.keymap.set('n', '<leader>po', ':PyOrganizeImports<CR>', { desc = 'Organize Python imports' })

---------------------------------------------------------------------
-- Treesitter
---------------------------------------------------------------------
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
}

---------------------------------------------------------------------
-- Comment.nvim
---------------------------------------------------------------------
require('Comment').setup()
