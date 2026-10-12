{ ... }:
{
  programs.nixvim = {
    # ==================== 9. 额外 Lua 配置 ====================
    extraConfigLua = ''
      -- 设置透明背景（覆盖主题设置）
      vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
      vim.api.nvim_set_hl(0, "NeoTreeNormal", { bg = "none" })
      vim.api.nvim_set_hl(0, "NeoTreeNormalNC", { bg = "none" })

      -- 禁用某些内置插件
      local disabled_built_ins = {
        "gzip",
        "zip",
        "zipPlugin",
        "tar",
        "tarPlugin",
        "getscript",
        "getscriptPlugin",
        "vimball",
        "vimballPlugin",
        "2html_plugin",
        "logipat",
        "rrhelper",
        "spellfile_plugin",
        "matchit"
      }

      for _, plugin in pairs(disabled_built_ins) do
        vim.g["loaded_" .. plugin] = 1
      end
    '';
  };
}
