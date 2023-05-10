
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local conf = require('telescope.config').values

local function word_search_picker(opts)
  opts = opts or {}

  pickers.new(opts, {
    prompt_title = 'Word Search',
    finder = finders.new_job(function(prompt)
      if not prompt or prompt == "" then return end

      -- Split the prompt into words
      local words = {}
      for word in string.gmatch(prompt, "%S+") do
        table.insert(words, word)
      end

      local rg = vim.fn.executable("rg") == 1

      -- Check if the word is in the file or in the filename.
      for _, word in ipairs(words) do
        if rg then
          return { "rg", "--files", "--no-ignore", "--hidden", "-g", "*" .. word .. "*" }
        else
          return { "find", ".", "-type", "f", "-iname", "*" .. word .. "*" }
        end
      end
    end),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        local filename = selection.value:match("^(.-):")
        vim.cmd('edit ' .. filename)
      end)

      return true
    end,
  }):find()
end

return {
  word_search_picker = word_search_picker,
}
