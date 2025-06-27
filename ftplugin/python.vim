if has("nvim")
    " Format prior to save using LSP
    autocmd BufWritePre *.py lua vim.lsp.buf.formatting_sync(nil, 1000)
endif
