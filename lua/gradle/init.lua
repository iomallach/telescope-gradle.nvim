-- Telescope stuff
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

-- Async stuff
local Job = require("plenary.job")

local M = {}
local opts = {
  split = "vsplit",
}

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

local function on_stderr(_, data)
  if data then
    vim.notify(data, vim.log.levels.ERROR)
  end
end

local function async_cache_gradle_tasks()
  Job:new({
    command = "./gradlew",
    args = { "tasks", "--no-rebuild", "--console", "plain" },
    on_exit = function(j, return_val)
      local result = table.concat(j:result(), "\r\n")
      M.tasks = parse_gradle_tasks(result)
      vim.notify("Gradle: Cached tasks!")
    end,
    on_stderr = on_stderr,
  }):start()
end

local function async_spawn_gradle_daemon()
  Job:new({
    command = "./gradlew",
    args = { "--daemon" },
    on_exit = function(j, return_val)
      if return_val == 0 then
        vim.notify("Successfully spawned gradle daemon", vim.log.levels.INFO)
        async_cache_gradle_tasks()
      end
      vim.notify("Skipping caching tasks on " .. j)
    end,
    on_stderr = on_stderr,
  }):start()
end

local function async_prepare_gradle_daemon()
  Job:new({
    command = "./gradlew",
    args = { "--status" },
    on_exit = function(j, return_val)
      local result = table.concat(j:result(), "\n")
      if string.match(result, "No gradle daemons are running") then
        vim.notify("Spawning gradle daemon")
        async_spawn_gradle_daemon()
      end
      vim.notify("Not spawning gradle daemon on " .. j)
    end,
    on_stderr = on_stderr,
  }):start()
end

M.run_gradle_task = function(args)
  vim.cmd(opts.split .. " | term ./gradlew " .. args.args)
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

local function list_gradle_tasks()
  if is_gradle_daemon_running() then
    return parse_gradle_tasks(run_gradle_list())
  else
    spawn_gradle_daemon()
    return parse_gradle_tasks(run_gradle_list())
  end
end

M.refresh_cache = function()
  async_cache_gradle_tasks()
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
        -- results = list_gradle_tasks(),
        results = M.tasks,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          M.run_gradle_task({ args = ":" .. selection[1] })
        end)
        return true
      end,
    })
    :find()
end

M.setup = function(external_opts)
  opts = vim.tbl_deep_extend("force", opts, external_opts)
  async_prepare_gradle_daemon()
end

return M
