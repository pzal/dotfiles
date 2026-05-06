vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.background = "light"


vim.cmd.colorscheme("shine")


vim.g.mapleader = " "


vim.pack.add({
  "https://github.com/ibhagwan/fzf-lua",
})


vim.keymap.set("n", "<leader>e", ":Explore<CR>", {
  desc = "Open netrw file explorer",
})

vim.keymap.set("n", "<leader>e", ":Explore<CR>", {
  desc = "Open netrw file explorer",
})

vim.keymap.set("n", "<leader>f", function()
  require("fzf-lua").files()
end, { desc = "Fuzzy find files" })

vim.keymap.set("n", "<leader>g", function()
  require("fzf-lua").live_grep()
end, { desc = "Live grep" })

vim.keymap.set("n", "<leader>b", function()
  require("fzf-lua").buffers()
end, { desc = "Find buffers" })
