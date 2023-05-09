local telescope = require('telescope')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local make_entry = require('telescope.make_entry')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local actions = require "telescope.actions"
local finders = require "telescope.finders"
local previewers = require "telescope.previewers"
local sorters = require "telescope.sorters"
local utils = require "telescope.utils"
local conf = require("telescope.config").values
local log = require "telescope.log"
local flatten = vim.tbl_flatten
local filter = vim.tbl_filter


local opts_contain_invert = function(args)
    local invert = false
    local files_with_matches = false

    for _, v in ipairs(args) do
        if v == "--invert-match" then
            invert = true
        elseif v == "--files-with-matches" or v == "--files-without-match" then
            files_with_matches = true
        end

        if #v >= 2 and v:sub(1, 1) == "-" and v:sub(2, 2) ~= "-" then
            local non_option = false
            for i = 2, #v do
                local vi = v:sub(i, i)
                if vi == "=" then -- ignore option -g=xxx
                    break
                elseif vi == "g" or vi == "f" or vi == "m" or vi == "e" or vi == "r" or vi == "t" or vi == "T" then
                    non_option = true
                elseif non_option == false and vi == "v" then
                    invert = true
                elseif non_option == false and vi == "l" then
                    files_with_matches = true
                end
            end
        end
    end
    return invert, files_with_matches
end


local get_open_filelist = function(grep_open_files, cwd)
    if not grep_open_files then
        return nil
    end

    local bufnrs = filter(function(b)
        if 1 ~= vim.fn.buflisted(b) then
            return false
        end
        return true
    end, vim.api.nvim_list_bufs())
    if not next(bufnrs) then
        return
    end

    local filelist = {}
    for _, bufnr in ipairs(bufnrs) do
        local file = vim.api.nvim_buf_get_name(bufnr)
        table.insert(filelist, Path:new(file):make_relative(cwd))
    end
    return filelist
end


local live_grep_files = function(opts)
    local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
    local search_dirs = opts.search_dirs
    local grep_open_files = opts.grep_open_files
    opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

    local filelist = get_open_filelist(grep_open_files, opts.cwd)
    if search_dirs then
        for i, path in ipairs(search_dirs) do
            search_dirs[i] = vim.fn.expand(path)
        end
    end

    local additional_args = {}
    if opts.additional_args ~= nil then
        if type(opts.additional_args) == "function" then
            additional_args = opts.additional_args(opts)
        elseif type(opts.additional_args) == "table" then
            additional_args = opts.additional_args
        end
    end

    if opts.type_filter then
        additional_args[#additional_args + 1] = "--type=" .. opts.type_filter
    end

    if type(opts.glob_pattern) == "string" then
        additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern
    elseif type(opts.glob_pattern) == "table" then
        for i = 1, #opts.glob_pattern do
            additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern[i]
        end
    end

    local args = flatten { vimgrep_arguments, additional_args }
    opts.__inverted, opts.__matches = opts_contain_invert(args)

    local find_command = function(prompt)
        if not prompt or prompt == "" then
            return nil
        end

        local search_list = {}

        if grep_open_files then
            search_list = filelist
        elseif search_dirs then
            search_list = search_dirs
        end
        
        local search_file_content = {"rg", "--color=never", "--with-filename", "-l",  "---hidden", "--follow", "--glob", "'!.git'", prompt, search_list}
        local search_file_name = {"rg", "--color=never", "--files", "--hidden", "--follow", "-l", "--glob", "'!.git'","|", "rg", "--color=always", "-l", prompt, search_list}
        local search_command = flatten {{"("}, search_file_content, {";"}, search_file_name, {")","|", "sort", "-u"} }
        print (search_command)
        -- return flatten { { "rg", "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case", "-l"}, "--", prompt, search_list }
        return search_command
    end

    pickers
        .new(opts, {
            prompt_title = "Live Grep Files",
            finder = finders.new_job(find_command, make_entry.gen_from_file(opts), opts.max_results, opts.cwd),
            previewer = conf.grep_previewer(opts),
            -- TODO: It would be cool to use `--json` output for this
            -- and then we could get the highlight positions directly.
            sorter = sorters.highlighter_only(opts),

            attach_mappings = function(_, map)
                map("i", "<c-space>", actions.to_fuzzy_refine)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    local current_line = action_state.get_current_line()
                    if (selection ~= nil) then
                        local handle = io.popen("head -n1 " .. selection.path)
                        local result = handle:read("*a")
                        handle:close()
                        if (opts.os == "macos") then
                            if (opts.browser == "chrome") then
                                opts.command = "open -a Google\\ Chrome.app"
                            else
                                opts.command = "open -a Safari.app"
                            end
                        end
                        io.popen(opts.command .. " " .. result)
                    end
                    -- actions.close(prompt_bufnr)
                end)
                return true
            end,
        })
        :find()
    end
local live_grep = function(opts)
    local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
    local search_dirs = opts.search_dirs
    local grep_open_files = opts.grep_open_files
    opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

    local filelist = get_open_filelist(grep_open_files, opts.cwd)
    if search_dirs then
        for i, path in ipairs(search_dirs) do
            search_dirs[i] = vim.fn.expand(path)
        end
    end

    local additional_args = {}
    if opts.additional_args ~= nil then
        if type(opts.additional_args) == "function" then
            additional_args = opts.additional_args(opts)
        elseif type(opts.additional_args) == "table" then
            additional_args = opts.additional_args
        end
    end

    if opts.type_filter then
        additional_args[#additional_args + 1] = "--type=" .. opts.type_filter
    end

    if type(opts.glob_pattern) == "string" then
        additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern
    elseif type(opts.glob_pattern) == "table" then
        for i = 1, #opts.glob_pattern do
            additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern[i]
        end
    end

    local args = flatten { vimgrep_arguments, additional_args }
    opts.__inverted, opts.__matches = opts_contain_invert(args)

    local live_grepper = finders.new_job(function(prompt)
        if not prompt or prompt == "" then
            return nil
        end

        local search_list = {}

        if grep_open_files then
            search_list = filelist
        elseif search_dirs then
            search_list = search_dirs
        end

        return flatten { args, "--", prompt, search_list }
    end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd)

    pickers
        .new(opts, {
            prompt_title = "Live Grep",
            finder = live_grepper,
            previewer = conf.grep_previewer(opts),
            -- TODO: It would be cool to use `--json` output for this
            -- and then we could get the highlight positions directly.
            sorter = sorters.highlighter_only(opts),

            attach_mappings = function(_, map)
                map("i", "<c-space>", actions.to_fuzzy_refine)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    local current_line = action_state.get_current_line()
                    if (selection ~= nil) then
                        local handle = io.popen("head -n1 " .. selection.path)
                        local result = handle:read("*a")
                        handle:close()
                        if (opts.os == "macos") then
                            if (opts.browser == "chrome") then
                                opts.command = "open -a Google\\ Chrome.app"
                            else
                                opts.command = "open -a Safari.app"
                            end
                        end
                        io.popen(opts.command .. " " .. result)
                    end
                    -- actions.close(prompt_bufnr)
                end)
                return true
            end,
        })
        :find()
end

local find_files = function(opts)
    local find_command = (function()
        if opts.find_command then
            if type(opts.find_command) == "function" then
                return opts.find_command(opts)
            end
            return opts.find_command
        elseif 1 == vim.fn.executable "rg" then
            return { "rg", "--files", "--color", "never" }
        elseif 1 == vim.fn.executable "fd" then
            return { "fd", "--type", "f", "--color", "never" }
        elseif 1 == vim.fn.executable "fdfind" then
            return { "fdfind", "--type", "f", "--color", "never" }
        elseif 1 == vim.fn.executable "find" and vim.fn.has "win32" == 0 then
            return { "find", ".", "-type", "f" }
        elseif 1 == vim.fn.executable "where" then
            return { "where", "/r", ".", "*" }
        end
    end)()

    if not find_command then
        utils.notify("builtin.find_files", {
            msg = "You need to install either find, fd, or rg",
            level = "ERROR",
        })
        return
    end

    local command = find_command[1]
    local hidden = opts.hidden
    local no_ignore = opts.no_ignore
    local no_ignore_parent = opts.no_ignore_parent
    local follow = opts.follow
    local search_dirs = opts.search_dirs
    local search_file = opts.search_file

    if search_dirs then
        for k, v in pairs(search_dirs) do
            search_dirs[k] = vim.fn.expand(v)
        end
    end

    if command == "fd" or command == "fdfind" or command == "rg" then
        if hidden then
            find_command[#find_command + 1] = "--hidden"
        end
        if no_ignore then
            find_command[#find_command + 1] = "--no-ignore"
        end
        if no_ignore_parent then
            find_command[#find_command + 1] = "--no-ignore-parent"
        end
        if follow then
            find_command[#find_command + 1] = "-L"
        end
        if search_file then
            if command == "rg" then
                find_command[#find_command + 1] = "-g"
                find_command[#find_command + 1] = "*" .. search_file .. "*"
            else
                find_command[#find_command + 1] = search_file
            end
        end
        if search_dirs then
            if command ~= "rg" and not search_file then
                find_command[#find_command + 1] = "."
            end
            vim.list_extend(find_command, search_dirs)
        end
    elseif command == "find" then
        if not hidden then
            table.insert(find_command, { "-not", "-path", "*/.*" })
            find_command = flatten(find_command)
        end
        if no_ignore ~= nil then
            log.warn "The `no_ignore` key is not available for the `find` command in `find_files`."
        end
        if no_ignore_parent ~= nil then
            log.warn "The `no_ignore_parent` key is not available for the `find` command in `find_files`."
        end
        if follow then
            table.insert(find_command, 2, "-L")
        end
        if search_file then
            table.insert(find_command, "-name")
            table.insert(find_command, "*" .. search_file .. "*")
        end
        if search_dirs then
            table.remove(find_command, 2)
            for _, v in pairs(search_dirs) do
                table.insert(find_command, 2, v)
            end
        end
    elseif command == "where" then
        if hidden ~= nil then
            log.warn "The `hidden` key is not available for the Windows `where` command in `find_files`."
        end
        if no_ignore ~= nil then
            log.warn "The `no_ignore` key is not available for the Windows `where` command in `find_files`."
        end
        if no_ignore_parent ~= nil then
            log.warn "The `no_ignore_parent` key is not available for the Windows `where` command in `find_files`."
        end
        if follow ~= nil then
            log.warn "The `follow` key is not available for the Windows `where` command in `find_files`."
        end
        if search_dirs ~= nil then
            log.warn "The `search_dirs` key is not available for the Windows `where` command in `find_files`."
        end
        if search_file ~= nil then
            log.warn "The `search_file` key is not available for the Windows `where` command in `find_files`."
        end
    end

    if opts.cwd then
        opts.cwd = vim.fn.expand(opts.cwd)
    end

    opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

    pickers
        .new(opts, {
            prompt_title = opts.title,
            finder = finders.new_oneshot_job(find_command, opts),
            previewer = conf.file_previewer(opts),
            sorter = conf.file_sorter(opts),
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    local current_line = action_state.get_current_line()

                    if (selection ~= nil) then
                        local handle = io.popen("head -n1 " .. selection.path)
                        local result = handle:read("*a")
                        handle:close()
                        if (opts.os == "macos") then
                            if (opts.browser == "chrome") then
                                opts.command = "open -a Google\\ Chrome.app"
                            else
                                opts.command = "open -a Safari.app"
                            end
                        end
                        io.popen(opts.command .. " " .. result)
                    end
                    -- actions.close(prompt_bufnr)
                end)
                return true
            end,
        })
        :find()
end


local jira = function(opts)
    if opts.type == "grep" then
        live_grep(opts)
    elseif opts.type=="grep_files" then
        live_grep_files(opts)
    else
        find_files(opts)
    end
end


return telescope.register_extension({ exports = { jira = jira } })
