{ ... }:
{
  programs.nixvim.plugins = {
    # LSP
    lsp = {
      enable = true;
      inlayHints = true;
      keymaps = {
        silent = true;
        lspBuf = {
          gd = {
            action = "definition";
            desc = "Go to definition";
          };
          gD = {
            action = "declaration";
            desc = "Go to declaration";
          };
          gi = {
            action = "implementation";
            desc = "Go to implementation";
          };
          gr = {
            action = "references";
            desc = "Go to references";
          };
          K = {
            action = "hover";
            desc = "Hover documentation";
          };
          "<leader>ca" = {
            action = "code_action";
            desc = "Code action";
          };
          "<leader>cr" = {
            action = "rename";
            desc = "Rename";
          };
          "<leader>cf" = {
            action = "format";
            desc = "Format";
          };
        };
        diagnostic = {
          "<leader>cd" = {
            action = "open_float";
            desc = "Line diagnostics";
          };
          "[d" = {
            action = "goto_prev";
            desc = "Previous diagnostic";
          };
          "]d" = {
            action = "goto_next";
            desc = "Next diagnostic";
          };
        };
      };
      servers = {
        # Nix
        nil_ls = {
          enable = true;
          settings = {
            formatting = {
              command = [ "nixfmt" ];
            };
          };
        };
        # Lua
        lua_ls = {
          enable = true;
          settings = {
            Lua = {
              diagnostics = {
                globals = [ "vim" ];
              };
              workspace = {
                library = {
                  "''\${3rd}/luv/library" = true;
                  "''\${3rd}/love2d/library" = true;
                };
                checkThirdParty = false;
              };
              telemetry = {
                enable = false;
              };
            };
          };
        };
        # Python
        pyright = {
          enable = true;
        };
        # Rust
        rust_analyzer = {
          enable = true;
          installRustc = false;
          installCargo = false;
        };
        # Go
        gopls = {
          enable = true;
        };
        # TypeScript/JavaScript
        ts_ls = {
          enable = true;
        };
        # JSON
        jsonls = {
          enable = true;
        };
        # YAML
        yamlls = {
          enable = true;
        };
        # Bash
        bashls = {
          enable = true;
        };
        # C/C++
        clangd = {
          enable = true;
        };
      };
    };

    # 自动补全
    cmp = {
      enable = true;
      settings = {
        completion = {
          completeopt = "menu,menuone,noinsert";
        };
        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<C-b>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<Tab>" = "cmp.mapping(function(fallback)\n  if cmp.visible() then\n    cmp.select_next_item()\n  else\n    fallback()\n  end\nend, { 'i', 's' })";
          "<S-Tab>" = "cmp.mapping(function(fallback)\n  if cmp.visible() then\n    cmp.select_prev_item()\n  else\n    fallback()\n  end\nend, { 'i', 's' })";
        };
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
        experimental = {
          ghost_text = true;
        };
      };
    };
    cmp-nvim-lsp.enable = true;
    cmp-buffer.enable = true;
    cmp-path.enable = true;
    cmp_luasnip.enable = true;
    luasnip = {
      enable = true;
      fromVscode = [
        { }
      ];
    };
    friendly-snippets.enable = true;
    lspkind = {
      enable = true;
    };
  };
}
