{ lib, ... }:
let
  # 配置中使用的变量和函数
  width = 64; # 第二列的宽度, 可自由调整
  labelWidth = 22;
  leftColumnWidth = labelWidth + 4;
  esc = builtins.fromJSON ''"\u001b"'';
  line = lib.strings.replicate width "─";
  leftLine = lib.strings.replicate leftColumnWidth "─";
  forward = count: "${esc}[${builtins.toJSON count}C";
  backward = count: "${esc}[${builtins.toJSON count}D";
  padRight = text:
    let
      padding = labelWidth - lib.strings.stringLength text;
    in
    if padding > 0 then text + lib.strings.replicate padding " " else text;
  mkTop = color: nameColor: name: {
    type = "custom";
    key = "{#${color}}╭${leftLine}┬${line}╮${backward (width + leftColumnWidth - 1)}{#keys}";
    "format" = "{#${nameColor}}${name} ";
  };
  mkEntry = color: name: type: {
    inherit type;
    key = "{#${color}}│ {icon}  ${padRight name}│${forward width}│${backward (width + 1)}{#keys}";
  };
  mkFoot = color: {
    type = "custom";
    key = "{#${color}}╰${leftLine}┴${line}╯";
  };
in
{
  programs = {
    fastfetch = {
      enable = true;
      settings = {
        "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
        logo = {
          type = "none";
        };
        display = {
          # 分隔符
          separator = " ";
          size = {
            # 使用 KB/MB/GB
            binaryPrefix = "si";
            # 显示小数位数
            ndigits = 1;
          };
          percent = {
            # 百分比显示模式
            type = 2;
          };
          bar = {
            # 已用部分字符
            char.elapsed = "■";
            # 未用部分字符
            char.total = " ";
          };
        };
        modules = [
          # 系统
          (mkTop "blue" "bright_blue" "System")
          (mkEntry "blue" "Operating System" "os")
          (mkEntry "blue" "Kernel" "kernel")
          (mkEntry "blue" "Packages" "packages")
          (mkEntry "blue" "Locale" "locale")
          (
            mkEntry "blue" "Operating System Age" "disk"
            // {
              condition = {
                "!system" = "macOS";
              };
              keyIcon = "";
              folders = "/";
              format = "{create-time:10} [{days} days]";
            }
          )
          (
            mkEntry "blue" "Operating System Age" "disk"
            // {
              condition = {
                system = "macOS";
              };
              keyIcon = "";
              folders = "/System/Volumes/VM";
              format = "{create-time:10} [{days} days]";
            }
          )
          (mkFoot "blue")
          # 硬件
          (mkTop "cyan" "bright_cyan" "Hardware")
          (mkEntry "cyan" "Hostname" "host")
          (mkEntry "cyan" "Chassis" "chassis")
          (mkEntry "cyan" "Processor" "cpu" // { showPeCoreCount = true; })
          (mkEntry "cyan" "Graphics Processor" "gpu")
          (mkEntry "cyan" "Memory" "memory")
          (mkEntry "cyan" "Disk" "disk")
          (mkEntry "cyan" "Swap" "swap")
          (mkEntry "cyan" "Sound" "sound")
          (mkEntry "cyan" "Battery" "battery")
          (mkEntry "cyan" "Power Adapter" "poweradapter")
          (mkEntry "cyan" "Display" "display")
          (mkEntry "cyan" "Brightness" "brightness")
          (mkEntry "cyan" "Bluetooth" "bluetooth")
          (mkEntry "cyan" "Gamepad" "gamepad")
          (mkFoot "cyan")
          # 终端
          (mkTop "yellow" "bright_yellow" "Terminal")
          (mkEntry "yellow" "Shell" "shell")
          (mkEntry "yellow" "Terminal" "terminal")
          (mkEntry "yellow" "Editor" "editor")
          (mkEntry "yellow" "Terminal Theme" "terminaltheme")
          (mkEntry "yellow" "Terminal Font" "terminalfont")
          (mkFoot "yellow")
          # 桌面
          (mkTop "green" "bright_green" "Desktop")
          (mkEntry "green" "Graphics Driver" "gpu" // { format = "{driver}"; })
          (mkEntry "green" "Login Manager" "lm")
          (mkEntry "green" "Desktop Environment" "de")
          (mkEntry "green" "Window Manager" "wm")
          (mkEntry "green" "Desktop Theme" "theme")
          (mkEntry "green" "Window Manager Theme" "wmtheme")
          (mkEntry "green" "Icons" "icons")
          (mkEntry "green" "Cursor" "cursor")
          (mkEntry "green" "Wallpaper" "wallpaper")
          (mkFoot "green")
          # 状态
          (mkTop "magenta" "bright_magenta" "Status")
          (mkEntry "magenta" "Uptime" "uptime")
          (mkEntry "magenta" "Users" "users" // { myselfOnly = true; })
          (mkEntry "magenta" "Media Session" "media")
          (mkEntry "magenta" "Wireless Network" "wifi" // { format = "{ssid}"; })
          (mkEntry "magenta" "Local IP Address" "localip")
          (mkEntry "magenta" "Public IP Address" "publicip")
          (mkFoot "magenta")
        ];
      };
    };
  };
}
