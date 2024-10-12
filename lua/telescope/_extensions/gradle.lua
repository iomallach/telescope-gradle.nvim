local has_telescope, telescope = pcall(require, "telescope")
local setup = function() end

if not has_telescope then
  error("nvim-telescope/telescope.nvim not found")
end

local telescope_gradle = require("gradle")

return telescope.register_extension({
  setup = setup,
  exports = { gradle = telescope_gradle.telescope_find_gradle_tasks },
})
