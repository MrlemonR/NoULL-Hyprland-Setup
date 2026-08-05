local keymap = vim.keymap.set

-- Leader tanımlama init.lua'da yapıldı, burada kullanabiliriz

-- <leader>e: Neo-tree açıksa kapat/odaklan, kapalıysa aç (Toggle)
keymap("n", "<leader>e", function()
  require("neo-tree.command").execute({ toggle = true, reveal = true })
end, { desc = "Neo-tree Toggle / Focus" })

-- <leader>E (Shift + e): Neo-tree'yi doğrudan aç veya odaklan
keymap("n", "<leader>E", "<cmd>Neotree focus<cr>", { desc = "Neo-tree Focus" })

-- Neo-tree'yi doğrudan kapatmak için ekstra kısayol istersen:
keymap("n", "<leader>ec", "<cmd>Neotree close<cr>", { desc = "Neo-tree Close" })

keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
keymap("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>")
keymap("n", "<leader>gg", "<cmd>LazyGit<cr>")
keymap("n", "<leader>tt", "<cmd>ToggleTerm direction=float<cr>")

-- LSP (global — aktif LSP istemcisi olan bufferlarda çalışır)
keymap("n", "<leader>rn", vim.lsp.buf.rename, { desc = "LSP Rename" })
keymap({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP Code Action" })

-- Pencereler arası
keymap("n", "<C-h>", "<C-w>h")
keymap("n", "<C-j>", "<C-w>j")
keymap("n", "<C-k>", "<C-w>k")
keymap("n", "<C-l>", "<C-w>l")

-- Buffer
keymap("n", "H", "<cmd>bprevious<cr>")
keymap("n", "L", "<cmd>bnext<cr>")

-- Format file

keymap("n", "<leader>cf", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format File" })
