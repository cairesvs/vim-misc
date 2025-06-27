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

  -- Additional import-related mappings for Python files
  if vim.bo[bufnr].filetype == 'python' then
    buf_set_keymap('n', ';oi', '<cmd>lua _G.organize_imports()<CR>', opts)
    buf_set_keymap('n', ';rf', '<cmd>lua _G.fix_and_organize_imports()<CR>', opts)
  end
end

-- Utility functions for import handling
_G.organize_imports = function()
  -- Try different possible Ruff commands for organizing imports
  local commands_to_try = {
    "ruff.applyOrganizeImports",
    "ruff-lsp.organizeImports",
    "source.organizeImports.ruff",
    "source.organizeImports"
  }

  for _, cmd in ipairs(commands_to_try) do
    local success = pcall(vim.lsp.buf.execute_command, {
      command = cmd,
      arguments = { { uri = vim.uri_from_bufnr(0) } },
    })
    if success then
      return
    end
  end

  -- Fallback: use LSP formatting with source.organizeImports
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" } },
    apply = true,
  })
end

_G.fix_and_organize_imports = function()
  -- First try to organize imports
  _G.organize_imports()

  -- Then try autofix
  vim.defer_fn(function()
    local autofix_commands = {
      "ruff.applyAutofix",
      "ruff-lsp.autofix"
    }

    for _, cmd in ipairs(autofix_commands) do
      local success = pcall(vim.lsp.buf.execute_command, {
        command = cmd,
        arguments = { { uri = vim.uri_from_bufnr(0) } },
      })
      if success then
        return
      end
    end

    -- Fallback: use code action for fixes
    vim.lsp.buf.code_action({
      context = { only = { "source.fixAll" } },
      apply = true,
    })
  end, 200)
end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { "gopls" }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup { on_attach = on_attach }
end

-- For python, we use pyright with ruff as the linter/formatter/organise imports.
nvim_lsp.ruff_lsp.setup {
  on_attach = function(client, bufnr)
    -- Disable Ruff's hover to avoid conflicts with Pyright
    client.server_capabilities.hoverProvider = false
    client.server_capabilities.renameProvider = false
    client.server_capabilities.definitionProvider = false
    client.server_capabilities.referencesProvider = false

    -- Call the standard on_attach
    on_attach(client, bufnr)
  end,
  init_options = {
    settings = {
      -- Configure Ruff for import organization and linting
      args = {
        "--select=I,F401,F403,F405,E,W", -- Import + basic linting rules
        "--fix",
      },
    }
  },
}

nvim_lsp.pyright.setup {
  on_attach = function(client, bufnr)
    -- Enable auto-import completion resolution
    client.server_capabilities.completionProvider.resolveProvider = true

    -- Call the standard on_attach
    on_attach(client, bufnr)
  end,
  settings = {
    pyright = {
      -- Let Ruff handle import organization, but keep Pyright's import suggestions
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        -- FIXED: Remove the ignore = { '*' } to enable import suggestions
        -- Keep Pyright active for import suggestions and type checking
        autoImportCompletions = true,
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly", -- Better performance
        typeCheckingMode = "basic",

        -- Enable import-related features
        reportMissingImports = true,
        reportMissingTypeStubs = false,
      },
    },
  },
}

-- Auto-organize imports on save for Python files
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.py",
  callback = function()
    -- Use the same organize function
    _G.organize_imports()
  end,
})

-- Custom commands for import management
vim.api.nvim_create_user_command('PyImportMissing', function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return action.kind == 'quickfix' or
             string.match(action.title:lower(), 'import') or
             string.match(action.title:lower(), 'add')
    end,
    apply = true,
  })
end, { desc = 'Apply import fixes' })

vim.api.nvim_create_user_command('PyOrganizeImports', function()
  _G.organize_imports()
end, { desc = 'Organize imports with Ruff' })

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
