
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local actions = require('telescope.actions')

local function word_search_picker(prompt)
  local word_list = {}
  for word in string.gmatch(prompt, "%S+") do
    table.insert(word_list, word)
  end

  local grep_string = table.concat(word_list, "\\|")

  pickers.new({}, {
    prompt_title = 'Word Search',
    finder = finders.new_oneshot_job(
      { "grep", "-ril", grep_string },
      {
        cwd = ".",
        entry_maker = function(line)
          local count = 0
          for _, word in ipairs(word_list) do
            if string.find(line, word) then
              count = count + 1
            end
          end
          return {
            valid = true,
            value = line,
            ordinal = count .. line,
            display = count .. " : " .. line,
          }
        end,
      }
    ),
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(_, map)
      map('i', '<CR>', actions.select_default)
      map('n', '<CR>', actions.select_default)
      return true
    end
  }):find()
end

return {
  word_search_picker = word_search_picker,
}
