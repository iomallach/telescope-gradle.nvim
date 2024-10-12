local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("nvim-telescope/telescope.nvim not found")
end

local telescope_gradle = require("gradle")

return telescope.register_extension({
  setup = function(ext_config)
    telescope_gradle.setup(ext_config)
  end,
  exports = { gradle = telescope_gradle.telescope_find_gradle_tasks },
})
