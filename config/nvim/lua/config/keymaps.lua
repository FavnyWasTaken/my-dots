-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set

-- 1. Save file
map("n", "<C-o>", "<cmd>w<cr>", { desc = "Save file" })

-- 2. Undo
map("n", "<F11>", "u", { desc = "Undo last action" })

-- 3. Redo
map("n", "<F12>", "<C-r>", { desc = "Redo last action" })

-- 4. Delete current line
map("n", "<C-k>", "dd", { desc = "Delete line" })

-- 5. Quit file
map("n", "<C-x>", "<cmd>q<cr>", { desc = "Quit file" })

-- 6. Copy (yank) selected text to system clipboard
map("v", "<C-c>", '"+y', { desc = "Copy to clipboard" })

-- 7. Paste from system clipboard
map("n", "<C-v>", '"+p', { desc = "Paste from clipboard" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste from clipboard (insert mode)" })
map("v", "<C-v>", '"+p', { desc = "Paste from clipboard (visual mode)" })
