local telescope = require('telescope')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local make_entry = require('telescope.make_entry')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')


local jira = function(opts)
    opts = opts or {}
    opts.entry_maker = make_entry.gen_from_file(opts)
    opts.search_dirs = { "~/Jira/myTickets" }
    pickers.new(opts, {
        prompt_title = "My Jira Tickets",
        finder = finders.new_oneshot_job({"ls", vim.fn.expand("~/Jira/myTickets")}, opts),
        previewer = conf.file_previewer(opts),
        sorter = conf.file_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local current_line = action_state.get_current_line()
                print(selection.path)
                if (selection ~= nil) then
                    local handle = io.popen("head -n1 " .. selection.path)
                    local result = handle:read("*a")
                    handle:close()
                    io.popen("open -na Google\\ Chrome.app " .. result)
                end
                -- actions.close(prompt_bufnr)
            end)
            return true
        end,
    }):find()
end

return telescope.register_extension({ exports = { jira = jira } })
