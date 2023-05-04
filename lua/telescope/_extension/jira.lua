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
    opts.search_dirs = { "~/Jira/myTicktes" }
    pickers.new(opts, {
        prompt_title = "My Jira Tickets",
        finder = finders.new_oneshot_job({"ls", vim.fn.expand("~/Jira/myTicktes")}, opts),
        previewer = conf.file_previewer(opts),
        sorter = conf.file_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                local current_line = action_state.get_current_line()

                if (selection ~= nil) then
                    utils.get_os_command_output({ "ftux_param", selection[1] }, git_root)
                end
                -- actions.close(prompt_bufnr)
            end)
            return true
        end,
    }):find()
end

return telescope.register_extension({ exports = { jira = jira } })
