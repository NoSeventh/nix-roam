{ ... }:
{
  programs.nixvim.plugins = {
    # 状态栏
    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "auto";
          globalstatus = true;
          component_separators = { left = " "; right = " "; };
          section_separators = { left = " "; right = " "; };
          disabled_filetypes = {
            statusline = [ "dashboard" "neo-tree" "alpha" ];
            winbar = [ "dashboard" "neo-tree" "alpha" ];
          };
        };
        sections = {
          lualine_a = [ "mode" ];
          lualine_b = [ "branch" "diff" "diagnostics" ];
          lualine_c = [ "filename" ];
          lualine_x = [ "encoding" "fileformat" "filetype" ];
          lualine_y = [ "progress" ];
          lualine_z = [ "location" ];
        };
        inactive_sections = {
          lualine_a = [ ];
          lualine_b = [ ];
          lualine_c = [ "filename" ];
          lualine_x = [ "location" ];
          lualine_y = [ ];
          lualine_z = [ ];
        };
      };
    };

    # 缓冲区标签
    bufferline = {
      enable = true;
      settings = {
        options = {
          mode = "buffers";
          numbers = "ordinal";
          close_command = "bdelete! %d";
          right_mouse_command = "bdelete! %d";
          left_mouse_command = "buffer %d";
          middle_mouse_command = null;
          indicator = {
            style = "icon";
            icon = " ";
          };
          buffer_close_icon = " ";
          modified_icon = "●";
          close_icon = "";
          left_trunc_marker = "«";
          right_trunc_marker = "»";
          max_name_length = 18;
          max_prefix_length = 15;
          tab_size = 18;
          diagnostics = "nvim_lsp";
          diagnostics_update_in_insert = false;
          offsets = [
            {
              filetype = "neo-tree";
              text = "Explorer";
              highlight = "Directory";
              text_align = "left";
            }
          ];
          show_buffer_icons = true;
          show_buffer_close_icons = true;
          show_close_icon = true;
          show_tab_indicators = true;
          separator_style = "thin";
          enforce_regular_tabs = false;
          always_show_bufferline = true;
        };
      };
    };

    # 代码注释
    comment = {
      enable = true;
      settings = {
        opleader = {
          line = "gc";
          block = "gb";
        };
        toggler = {
          line = "gcc";
          block = "gbc";
        };
      };
    };

    # 自动括号
    nvim-autopairs = {
      enable = true;
      settings = {
        check_ts = true;
      };
    };

    # 缩进线
    indent-blankline = {
      enable = true;
      settings = {
        indent = {
          char = "│";
        };
        scope = {
          enabled = true;
        };
      };
    };

    # Git 集成
    gitsigns = {
      enable = true;
      settings = {
        signs = {
          add = { text = "+"; };
          change = { text = "~"; };
          delete = { text = "_"; };
          topdelete = { text = "‾"; };
          changedelete = { text = "~"; };
        };
        on_attach = {
          __raw = ''
            function(bufnr)
              local gs = package.loaded.gitsigns
              local function map(mode, l, r, opts)
                opts = opts or {}
                opts.buffer = bufnr
                vim.keymap.set(mode, l, r, opts)
              end
            ${"  "}
              map('n', ']c', function()
                if vim.wo.diff then return ']c' end
                vim.schedule(function() gs.next_hunk() end)
                return '<Ignore>'
              end, { expr = true, desc = 'Next hunk' })
            ${"  "}
              map('n', '[c', function()
                if vim.wo.diff then return '[c' end
                vim.schedule(function() gs.prev_hunk() end)
                return '<Ignore>'
              end, { expr = true, desc = 'Previous hunk' })
            ${"  "}
              map('n', '<leader>gs', gs.stage_hunk, { desc = 'Stage hunk' })
              map('n', '<leader>gr', gs.reset_hunk, { desc = 'Reset hunk' })
              map('v', '<leader>gs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = 'Stage hunk' })
              map('v', '<leader>gr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end, { desc = 'Reset hunk' })
              map('n', '<leader>gS', gs.stage_buffer, { desc = 'Stage buffer' })
              map('n', '<leader>gu', gs.undo_stage_hunk, { desc = 'Undo stage hunk' })
              map('n', '<leader>gR', gs.reset_buffer, { desc = 'Reset buffer' })
              map('n', '<leader>gp', gs.preview_hunk, { desc = 'Preview hunk' })
              map('n', '<leader>gb', function() gs.blame_line{full=true} end, { desc = 'Blame line' })
              map('n', '<leader>gd', gs.diffthis, { desc = 'Diff this' })
              map('n', '<leader>gD', function() gs.diffthis('~') end, { desc = 'Diff this ~' })
            end
          '';
        };
      };
    };

    # 终端切换
    toggleterm = {
      enable = true;
      settings = {
        open_mapping = "[[<c-\\>]]";
        direction = "float";
        float_opts = {
          border = "curved";
          width = 130;
          height = 30;
        };
        hide_numbers = true;
        start_in_insert = true;
        insert_mappings = true;
        terminal_mappings = true;
        close_on_exit = true;
      };
    };

    # 通知
    notify = {
      enable = true;
      settings = {
        stages = "fade_in_slide_out";
        timeout = 3000;
        max_height = {
          __raw = "function()\n  return math.floor(vim.o.lines * 0.75)\nend";
        };
        max_width = {
          __raw = "function()\n  return math.floor(vim.o.columns * 0.75)\nend";
        };
        on_open = {
          __raw = "function(win)\n  vim.api.nvim_win_set_config(win, { zindex = 100 })\nend";
        };
      };
    };

    # 更好的 UI 选择器
    dressing = {
      enable = true;
    };

    # 彩虹括号
    rainbow-delimiters = {
      enable = true;
    };

    # 光标高亮
    cursorline = {
      enable = true;
    };

    # 大纲
    aerial = {
      enable = true;
      settings = {
        backends = [ "treesitter" "lsp" "markdown" "man" ];
        layout = {
          default_direction = "prefer_right";
          width = 0.2;
        };
        show_guides = true;
        filter_kind = false;
        guides = {
          mid_item = "├ ";
          last_item = "└ ";
          nested_top = "│ ";
          whitespace = "  ";
        };
        keymaps = {
          "[y" = "actions.prev";
          "]y" = "actions.next";
          "[Y" = "actions.prev_up";
          "]Y" = "actions.next_up";
        };
      };
    };

    # 待办事项高亮
    todo-comments = {
      enable = true;
      settings = {
        signs = true;
        keywords = {
          FIX = {
            icon = " ";
            color = "error";
            alt = [ "FIXME" "BUG" "FIXIT" "ISSUE" ];
          };
          TODO = {
            icon = " ";
            color = "info";
          };
          HACK = {
            icon = " ";
            color = "warning";
          };
          WARN = {
            icon = " ";
            color = "warning";
            alt = [ "WARNING" "XXX" ];
          };
          PERF = {
            icon = " ";
            color = "default";
            alt = [ "OPTIM" "PERFORMANCE" "OPTIMIZE" ];
          };
          NOTE = {
            icon = " ";
            color = "hint";
            alt = [ "INFO" ];
          };
          TEST = {
            icon = "⏲ ";
            color = "test";
            alt = [ "TESTING" "PASSED" "FAILED" ];
          };
        };
      };
    };
  };
}
