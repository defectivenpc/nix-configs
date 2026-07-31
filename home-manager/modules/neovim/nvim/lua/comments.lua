local comment = require("Comment")

local ts_context_commentstring = require("ts_context_commentstring.integrations.comment_nvim")

comment.setup({
	pre_hook = ts_context_commentstring.create_pre_hook(),
})

local todo_comments = require("todo-comments")

local km = vim.keymap

km.set("n", "]t", function()
	todo_comments.jump_next()
end, { desc = "Next todo comment" })

km.set("n", "[t", function()
	todo_comments.jump_prev()
end, { desc = "Previous todo comment" })

todo_comments.setup()
