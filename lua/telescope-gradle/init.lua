local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

M.run_gradle_task = function(args)
  vim.cmd("split | term ./gradlew " .. args.args)
end

local function is_gradle_daemon_running()
  local gradle_status = vim.fn.system("./gradlew --status")
  if string.match(gradle_status, "No gradle daemons are running") then
    return true
  else
    return false
  end
end

local function spawn_gradle_daemon()
  vim.fn.system("./gradlew --daemon")
end

local function run_gradle_list()
  local out = vim.fn.system("./gradlew tasks --no-rebuild --console plain")
  return out
end

local function parse_gradle_tasks(output)
  local tasks = {}

  for line in output:gmatch("[^\r\n]+") do
    local task = line:match("^%s*([%w%-]+)%s+%-")

    if task then
      table.insert(tasks, task)
    end
  end

  return tasks
end

local function list_gradle_tasks()
  if is_gradle_daemon_running() then
    return parse_gradle_tasks(run_gradle_list())
  else
    spawn_gradle_daemon()
    return parse_gradle_tasks(run_gradle_list())
  end
end

M.telescope_find_gradle_tasks = function(opts)
  local path_to_gradlew = vim.fn.getcwd() .. "/gradlew"
  local is_gradlew_there = vim.fn.filereadable(path_to_gradlew)
  if is_gradlew_there == 0 then
    vim.notify("Couldn't find gradle binary", vim.log.levels.ERROR)
    return
  end

  opts = opts or {}
  pickers
    .new(opts, {
      prompt_title = "Gradle tasks",
      finder = finders.new_table({
        results = list_gradle_tasks(),
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.notify(vim.inspect(selection))
          M.run_gradle_task({ args = ":" .. selection[1] })
        end)
        return true
      end,
    })
    :find()
end
return M
