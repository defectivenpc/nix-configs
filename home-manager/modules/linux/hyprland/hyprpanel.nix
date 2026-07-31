{ ... }:

{
  programs.hyprpanel = {

    enable = true;

    settings = {

      # The option id is `bar.layouts` (configuration/modules/config/bar
      # exports `layouts`). Wrapping it in a top-level `layout` namespace makes
      # the lookup miss and hyprpanel silently falls back to its built-in
      # layout — which is why the bar showed dashboard/workspaces/windowtitle
      # regardless of what was configured here.
      bar.layouts = {
        # Valid names come from getCoreWidgets() in
        # components/bar/layout/coreWidgets.tsx — an unknown name is silently
        # dropped rather than erroring.
        "*" = {
          left = [
            "workspaces"
            "windowtitle"
          ];
          middle = [
            "media"
            "clock"
          ];
          # System readouts grouped together, ahead of the interactive
          # controls so they do not shift around as the tray populates.
          right = [
            "cpu"
            "cputemp"
            "ram"
            "storage"
            "netstat"
            "separator"
            "volume"
            "network"
            "bluetooth"
            "systray"
            "notifications"
          ];
        };
      };

      bar.launcher.autoDetectIcon = true;
      bar.workspaces = {
        show_numbered = true;
      };

      #bar.customModules.cpuTemp.sensor = "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon1/temp1_input";
      #bar.customModules.cpuTemp.sensor = "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon2/temp1_input";

      # Pinned rather than left on auto-detect: docker0, a bridge and seven
      # veth pairs are up on this box, so autodetect has plenty of wrong
      # answers to choose from. enp18s0 carries the default route.
      bar.customModules.netstat = {
        networkInterface = "enp18s0";
        rateUnit = "auto";
        labelType = "full";
      };

      # Root only. /mnt/extra1 is a separate 1.8T disk; adding it here would
      # aggregate both into a single figure rather than showing them apart.
      bar.customModules.storage = {
        paths = [ "/" ];
        labelType = "percentage";
        round = true;
      };

      bar.customModules.ram.labelType = "percentage";

      menus.clock = {
        time = {
          military = false;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };

      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = true;

      # hyprpanel resolves options by dotted path (configManager
      # _navigateToValue). These keys are already fully qualified, so nesting
      # them under a `theme` attrset made it look for `theme.theme.*` and
      # silently fall back to the bundled catppuccin default.
      "theme.bar.menus.menu.notifications.scrollbar.color" = "#7daea3";
      "theme.bar.menus.menu.notifications.pager.label" = "#928374";
      "theme.bar.menus.menu.notifications.pager.button" = "#7daea3";
      "theme.bar.menus.menu.notifications.pager.background" = "#1d2021";
      "theme.bar.menus.menu.notifications.switch.puck" = "#45403c";
      "theme.bar.menus.menu.notifications.switch.disabled" = "#3c3837";
      "theme.bar.menus.menu.notifications.switch.enabled" = "#7daea3";
      "theme.bar.menus.menu.notifications.clear" = "#ea6962";
      "theme.bar.menus.menu.notifications.switch_divider" = "#45403d";
      "theme.bar.menus.menu.notifications.border" = "#3c3836";
      "theme.bar.menus.menu.notifications.card" = "#282828";
      "theme.bar.menus.menu.notifications.background" = "#1d2021";
      "theme.bar.menus.menu.notifications.no_notifications_label" = "#3c3836";
      "theme.bar.menus.menu.notifications.label" = "#7daea3";
      "theme.bar.menus.menu.power.buttons.sleep.icon" = "#232322";
      "theme.bar.menus.menu.power.buttons.sleep.text" = "#89b482";
      "theme.bar.menus.menu.power.buttons.sleep.icon_background" = "#89b482";
      "theme.bar.menus.menu.power.buttons.sleep.background" = "#282828";
      "theme.bar.menus.menu.power.buttons.logout.icon" = "#232322";
      "theme.bar.menus.menu.power.buttons.logout.text" = "#a9b665";
      "theme.bar.menus.menu.power.buttons.logout.icon_background" = "#a9b665";
      "theme.bar.menus.menu.power.buttons.logout.background" = "#282828";
      "theme.bar.menus.menu.power.buttons.restart.icon" = "#232322";
      "theme.bar.menus.menu.power.buttons.restart.text" = "#e78a4e";
      "theme.bar.menus.menu.power.buttons.restart.icon_background" = "#e78a4e";
      "theme.bar.menus.menu.power.buttons.restart.background" = "#282828";
      "theme.bar.menus.menu.power.buttons.shutdown.icon" = "#232322";
      "theme.bar.menus.menu.power.buttons.shutdown.text" = "#ea6962";
      "theme.bar.menus.menu.power.buttons.shutdown.icon_background" = "#ea6961";
      "theme.bar.menus.menu.power.buttons.shutdown.background" = "#282828";
      "theme.bar.menus.menu.power.border.color" = "#3c3836";
      "theme.bar.menus.menu.power.background.color" = "#1d2021";
      "theme.bar.menus.menu.dashboard.monitors.disk.label" = "#d3869b";
      "theme.bar.menus.menu.dashboard.monitors.disk.bar" = "#d3869c";
      "theme.bar.menus.menu.dashboard.monitors.disk.icon" = "#d3869b";
      "theme.bar.menus.menu.dashboard.monitors.gpu.label" = "#a9b665";
      "theme.bar.menus.menu.dashboard.monitors.gpu.bar" = "#a9b666";
      "theme.bar.menus.menu.dashboard.monitors.gpu.icon" = "#a9b665";
      "theme.bar.menus.menu.dashboard.monitors.ram.label" = "#d8a657";
      "theme.bar.menus.menu.dashboard.monitors.ram.bar" = "#d8a656";
      "theme.bar.menus.menu.dashboard.monitors.ram.icon" = "#d8a657";
      "theme.bar.menus.menu.dashboard.monitors.cpu.label" = "#c14a4a";
      "theme.bar.menus.menu.dashboard.monitors.cpu.bar" = "#c14a4b";
      "theme.bar.menus.menu.dashboard.monitors.cpu.icon" = "#c14a4a";
      "theme.bar.menus.menu.dashboard.monitors.bar_background" = "#45403d";
      "theme.bar.menus.menu.dashboard.directories.right.bottom.color" = "#7daea3";
      "theme.bar.menus.menu.dashboard.directories.right.middle.color" = "#b16286";
      "theme.bar.menus.menu.dashboard.directories.right.top.color" = "#8ec07c";
      "theme.bar.menus.menu.dashboard.directories.left.bottom.color" = "#c14a4a";
      "theme.bar.menus.menu.dashboard.directories.left.middle.color" = "#d8a657";
      "theme.bar.menus.menu.dashboard.directories.left.top.color" = "#d3869b";
      "theme.bar.menus.menu.dashboard.controls.input.text" = "#232322";
      "theme.bar.menus.menu.dashboard.controls.input.background" = "#d3869b";
      "theme.bar.menus.menu.dashboard.controls.volume.text" = "#232322";
      "theme.bar.menus.menu.dashboard.controls.volume.background" = "#c14a4a";
      "theme.bar.menus.menu.dashboard.controls.notifications.text" = "#232322";
      "theme.bar.menus.menu.dashboard.controls.notifications.background" = "#d8a657";
      "theme.bar.menus.menu.dashboard.controls.bluetooth.text" = "#232322";
      "theme.bar.menus.menu.dashboard.controls.bluetooth.background" = "#89b482";
      "theme.bar.menus.menu.dashboard.controls.wifi.text" = "#232322";
      "theme.bar.menus.menu.dashboard.controls.wifi.background" = "#b16286";
      "theme.bar.menus.menu.dashboard.controls.disabled" = "#504945";
      "theme.bar.menus.menu.dashboard.shortcuts.recording" = "#a9b665";
      "theme.bar.menus.menu.dashboard.shortcuts.text" = "#232322";
      "theme.bar.menus.menu.dashboard.shortcuts.background" = "#7daea3";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.button_text" = "#1d2020";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.deny" = "#ea6962";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.confirm" = "#a9b665";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.body" = "#d4be98";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.label" = "#7daea3";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.border" = "#3c3836";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.background" = "#1d2021";
      "theme.bar.menus.menu.dashboard.powermenu.confirmation.card" = "#282828";
      "theme.bar.menus.menu.dashboard.powermenu.sleep" = "#89b482";
      "theme.bar.menus.menu.dashboard.powermenu.logout" = "#a9b665";
      "theme.bar.menus.menu.dashboard.powermenu.restart" = "#e78a4e";
      "theme.bar.menus.menu.dashboard.powermenu.shutdown" = "#ea6962";
      "theme.bar.menus.menu.dashboard.profile.name" = "#d3869b";
      "theme.bar.menus.menu.dashboard.border.color" = "#3c3836";
      "theme.bar.menus.menu.dashboard.background.color" = "#1d2021";
      "theme.bar.menus.menu.dashboard.card.color" = "#282828";
      "theme.bar.menus.menu.clock.weather.hourly.temperature" = "#d3869b";
      "theme.bar.menus.menu.clock.weather.hourly.icon" = "#d3869b";
      "theme.bar.menus.menu.clock.weather.hourly.time" = "#d3869b";
      "theme.bar.menus.menu.clock.weather.thermometer.extremelycold" = "#89b482";
      "theme.bar.menus.menu.clock.weather.thermometer.cold" = "#83a598";
      "theme.bar.menus.menu.clock.weather.thermometer.moderate" = "#7daea3";
      "theme.bar.menus.menu.clock.weather.thermometer.hot" = "#e78a4e";
      "theme.bar.menus.menu.clock.weather.thermometer.extremelyhot" = "#ea6962";
      "theme.bar.menus.menu.clock.weather.stats" = "#d3869b";
      "theme.bar.menus.menu.clock.weather.status" = "#8ec07c";
      "theme.bar.menus.menu.clock.weather.temperature" = "#d4be98";
      "theme.bar.menus.menu.clock.weather.icon" = "#d3869b";
      "theme.bar.menus.menu.clock.calendar.contextdays" = "#504945";
      "theme.bar.menus.menu.clock.calendar.days" = "#d4be98";
      "theme.bar.menus.menu.clock.calendar.currentday" = "#d3869b";
      "theme.bar.menus.menu.clock.calendar.paginator" = "#d3869a";
      "theme.bar.menus.menu.clock.calendar.weekdays" = "#d3869b";
      "theme.bar.menus.menu.clock.calendar.yearmonth" = "#8ec07c";
      "theme.bar.menus.menu.clock.time.timeperiod" = "#8ec07c";
      "theme.bar.menus.menu.clock.time.time" = "#d3869b";
      "theme.bar.menus.menu.clock.text" = "#d4be98";
      "theme.bar.menus.menu.clock.border.color" = "#3c3836";
      "theme.bar.menus.menu.clock.background.color" = "#1d2021";
      "theme.bar.menus.menu.clock.card.color" = "#282828";
      "theme.bar.menus.menu.battery.slider.puck" = "#665c54";
      "theme.bar.menus.menu.battery.slider.backgroundhover" = "#45403d";
      "theme.bar.menus.menu.battery.slider.background" = "#504946";
      "theme.bar.menus.menu.battery.slider.primary" = "#d8a657";
      "theme.bar.menus.menu.battery.icons.active" = "#d8a657";
      "theme.bar.menus.menu.battery.icons.passive" = "#928374";
      "theme.bar.menus.menu.battery.listitems.active" = "#d8a657";
      "theme.bar.menus.menu.battery.listitems.passive" = "#d4be97";
      "theme.bar.menus.menu.battery.text" = "#d4be98";
      "theme.bar.menus.menu.battery.label.color" = "#d8a657";
      "theme.bar.menus.menu.battery.border.color" = "#3c3836";
      "theme.bar.menus.menu.battery.background.color" = "#1d2021";
      "theme.bar.menus.menu.battery.card.color" = "#282828";
      "theme.bar.menus.menu.systray.dropdownmenu.divider" = "#282828";
      "theme.bar.menus.menu.systray.dropdownmenu.text" = "#d4be98";
      "theme.bar.menus.menu.systray.dropdownmenu.background" = "#1d2021";
      "theme.bar.menus.menu.bluetooth.iconbutton.active" = "#89b482";
      "theme.bar.menus.menu.bluetooth.iconbutton.passive" = "#d4be98";
      "theme.bar.menus.menu.bluetooth.icons.active" = "#89b482";
      "theme.bar.menus.menu.bluetooth.icons.passive" = "#928374";
      "theme.bar.menus.menu.bluetooth.listitems.active" = "#89b481";
      "theme.bar.menus.menu.bluetooth.listitems.passive" = "#d4be98";
      "theme.bar.menus.menu.bluetooth.switch.puck" = "#45403c";
      "theme.bar.menus.menu.bluetooth.switch.disabled" = "#3c3837";
      "theme.bar.menus.menu.bluetooth.switch.enabled" = "#89b482";
      "theme.bar.menus.menu.bluetooth.switch_divider" = "#45403d";
      "theme.bar.menus.menu.bluetooth.status" = "#665c54";
      "theme.bar.menus.menu.bluetooth.text" = "#d4be98";
      "theme.bar.menus.menu.bluetooth.label.color" = "#89b482";
      "theme.bar.menus.menu.bluetooth.scroller.color" = "#89b482";
      "theme.bar.menus.menu.bluetooth.border.color" = "#3c3836";
      "theme.bar.menus.menu.bluetooth.background.color" = "#1d2021";
      "theme.bar.menus.menu.bluetooth.card.color" = "#282828";
      "theme.bar.menus.menu.network.iconbuttons.active" = "#b16286";
      "theme.bar.menus.menu.network.iconbuttons.passive" = "#d4be98";
      "theme.bar.menus.menu.network.icons.active" = "#b16286";
      "theme.bar.menus.menu.network.icons.passive" = "#928374";
      "theme.bar.menus.menu.network.listitems.active" = "#b16285";
      "theme.bar.menus.menu.network.listitems.passive" = "#d4be98";
      "theme.bar.menus.menu.network.status.color" = "#665c54";
      "theme.bar.menus.menu.network.text" = "#d4be98";
      "theme.bar.menus.menu.network.label.color" = "#b16286";
      "theme.bar.menus.menu.network.scroller.color" = "#b16286";
      "theme.bar.menus.menu.network.border.color" = "#3c3836";
      "theme.bar.menus.menu.network.background.color" = "#1d2021";
      "theme.bar.menus.menu.network.card.color" = "#282828";
      "theme.bar.menus.menu.volume.input_slider.puck" = "#504945";
      "theme.bar.menus.menu.volume.input_slider.backgroundhover" = "#45403d";
      "theme.bar.menus.menu.volume.input_slider.background" = "#504946";
      "theme.bar.menus.menu.volume.input_slider.primary" = "#c14a4a";
      "theme.bar.menus.menu.volume.audio_slider.puck" = "#504945";
      "theme.bar.menus.menu.volume.audio_slider.backgroundhover" = "#45403d";
      "theme.bar.menus.menu.volume.audio_slider.background" = "#504946";
      "theme.bar.menus.menu.volume.audio_slider.primary" = "#c14a4a";
      "theme.bar.menus.menu.volume.icons.active" = "#c14a4a";
      "theme.bar.menus.menu.volume.icons.passive" = "#928374";
      "theme.bar.menus.menu.volume.iconbutton.active" = "#c14a4a";
      "theme.bar.menus.menu.volume.iconbutton.passive" = "#d4be98";
      "theme.bar.menus.menu.volume.listitems.active" = "#c14a49";
      "theme.bar.menus.menu.volume.listitems.passive" = "#d4be98";
      "theme.bar.menus.menu.volume.text" = "#d4be98";
      "theme.bar.menus.menu.volume.label.color" = "#c14a4a";
      "theme.bar.menus.menu.volume.border.color" = "#3c3836";
      "theme.bar.menus.menu.volume.background.color" = "#1d2021";
      "theme.bar.menus.menu.volume.card.color" = "#282828";
      "theme.bar.menus.menu.media.slider.puck" = "#665c54";
      "theme.bar.menus.menu.media.slider.backgroundhover" = "#45403d";
      "theme.bar.menus.menu.media.slider.background" = "#504946";
      "theme.bar.menus.menu.media.slider.primary" = "#d3869b";
      "theme.bar.menus.menu.media.buttons.text" = "#1d2021";
      "theme.bar.menus.menu.media.buttons.background" = "#7daea4";
      "theme.bar.menus.menu.media.buttons.enabled" = "#8ec07b";
      "theme.bar.menus.menu.media.buttons.inactive" = "#504945";
      "theme.bar.menus.menu.media.border.color" = "#3c3836";
      "theme.bar.menus.menu.media.card.color" = "#282828";
      "theme.bar.menus.menu.media.background.color" = "#1d2021";
      "theme.bar.menus.menu.media.album" = "#d3869c";
      "theme.bar.menus.menu.media.timestamp" = "#d4be98";
      "theme.bar.menus.menu.media.artist" = "#8ec07d";
      "theme.bar.menus.menu.media.song" = "#7daea4";
      "theme.bar.menus.tooltip.text" = "#d4be98";
      "theme.bar.menus.tooltip.background" = "#1d2021";
      "theme.bar.menus.dropdownmenu.divider" = "#282828";
      "theme.bar.menus.dropdownmenu.text" = "#d4be98";
      "theme.bar.menus.dropdownmenu.background" = "#1d2021";
      "theme.bar.menus.slider.puck" = "#665c54";
      "theme.bar.menus.slider.backgroundhover" = "#45403d";
      "theme.bar.menus.slider.background" = "#504946";
      "theme.bar.menus.slider.primary" = "#7daea3";
      "theme.bar.menus.progressbar.background" = "#45403d";
      "theme.bar.menus.progressbar.foreground" = "#7daea3";
      "theme.bar.menus.iconbuttons.active" = "#7daea4";
      "theme.bar.menus.iconbuttons.passive" = "#d4be97";
      "theme.bar.menus.buttons.text" = "#232322";
      "theme.bar.menus.buttons.disabled" = "#504946";
      "theme.bar.menus.buttons.active" = "#d3869a";
      "theme.bar.menus.buttons.default" = "#7daea3";
      "theme.bar.menus.check_radio_button.active" = "#7daea4";
      "theme.bar.menus.check_radio_button.background" = "#45403d";
      "theme.bar.menus.switch.puck" = "#45403c";
      "theme.bar.menus.switch.disabled" = "#3c3837";
      "theme.bar.menus.switch.enabled" = "#7daea3";
      "theme.bar.menus.icons.active" = "#7daea3";
      "theme.bar.menus.icons.passive" = "#504945";
      "theme.bar.menus.listitems.active" = "#7daea2";
      "theme.bar.menus.listitems.passive" = "#d4be98";
      "theme.bar.menus.popover.border" = "#232322";
      "theme.bar.menus.popover.background" = "#232322";
      "theme.bar.menus.popover.text" = "#7daea3";
      "theme.bar.menus.label" = "#7daea3";
      "theme.bar.menus.feinttext" = "#3c3836";
      "theme.bar.menus.dimtext" = "#504945";
      "theme.bar.menus.text" = "#d4be98";
      "theme.bar.menus.border.color" = "#3c3836";
      "theme.bar.menus.cards" = "#282828";
      "theme.bar.menus.background" = "#1d2021";
      "theme.bar.buttons.modules.power.icon_background" = "#ea6962";
      "theme.bar.buttons.modules.power.icon" = "#ea6962";
      "theme.bar.buttons.modules.power.background" = "#32302f";
      "theme.bar.buttons.modules.power.border" = "#ea6962";
      "theme.bar.buttons.modules.weather.icon_background" = "#7daea3";
      "theme.bar.buttons.modules.weather.icon" = "#7daea3";
      "theme.bar.buttons.modules.weather.text" = "#7daea3";
      "theme.bar.buttons.modules.weather.background" = "#32302f";
      "theme.bar.buttons.modules.weather.border" = "#7daea3";
      "theme.bar.buttons.modules.updates.icon_background" = "#b16286";
      "theme.bar.buttons.modules.updates.icon" = "#b16286";
      "theme.bar.buttons.modules.updates.text" = "#b16286";
      "theme.bar.buttons.modules.updates.background" = "#32302f";
      "theme.bar.buttons.modules.updates.border" = "#b16286";
      "theme.bar.buttons.modules.kbLayout.icon_background" = "#89b482";
      "theme.bar.buttons.modules.kbLayout.icon" = "#89b482";
      "theme.bar.buttons.modules.kbLayout.text" = "#89b482";
      "theme.bar.buttons.modules.kbLayout.background" = "#32302f";
      "theme.bar.buttons.modules.kbLayout.border" = "#89b482";
      "theme.bar.buttons.modules.netstat.icon_background" = "#a9b665";
      "theme.bar.buttons.modules.netstat.icon" = "#a9b665";
      "theme.bar.buttons.modules.netstat.text" = "#a9b665";
      "theme.bar.buttons.modules.netstat.background" = "#32302f";
      "theme.bar.buttons.modules.netstat.border" = "#a9b665";
      "theme.bar.buttons.modules.storage.icon_background" = "#d3869b";
      "theme.bar.buttons.modules.storage.icon" = "#d3869b";
      "theme.bar.buttons.modules.storage.text" = "#d3869b";
      "theme.bar.buttons.modules.storage.background" = "#32302f";
      "theme.bar.buttons.modules.storage.border" = "#d3869b";
      "theme.bar.buttons.modules.cpu.icon_background" = "#ea6962";
      "theme.bar.buttons.modules.cpu.icon" = "#ea6962";
      "theme.bar.buttons.modules.cpu.text" = "#ea6962";
      "theme.bar.buttons.modules.cpu.background" = "#32302f";
      "theme.bar.buttons.modules.cpu.border" = "#ea6962";
      "theme.bar.buttons.modules.ram.icon_background" = "#d8a657";
      "theme.bar.buttons.modules.ram.icon" = "#d8a657";
      "theme.bar.buttons.modules.ram.text" = "#d8a657";
      "theme.bar.buttons.modules.ram.background" = "#32302f";
      "theme.bar.buttons.modules.ram.border" = "#d8a657";
      "theme.bar.buttons.notifications.total" = "#7daea3";
      "theme.bar.buttons.notifications.icon_background" = "#7daea3";
      "theme.bar.buttons.notifications.icon" = "#7daea3";
      "theme.bar.buttons.notifications.background" = "#32302f";
      "theme.bar.buttons.notifications.border" = "#7daea3";
      "theme.bar.buttons.clock.icon_background" = "#d3869b";
      "theme.bar.buttons.clock.icon" = "#d3869b";
      "theme.bar.buttons.clock.text" = "#d3869b";
      "theme.bar.buttons.clock.background" = "#32302f";
      "theme.bar.buttons.clock.border" = "#d3869b";
      "theme.bar.buttons.battery.icon_background" = "#d8a657";
      "theme.bar.buttons.battery.icon" = "#d8a657";
      "theme.bar.buttons.battery.text" = "#d8a657";
      "theme.bar.buttons.battery.background" = "#32302f";
      "theme.bar.buttons.battery.border" = "#d8a657";
      "theme.bar.buttons.systray.background" = "#32302f";
      "theme.bar.buttons.systray.border" = "#7daea3";
      "theme.bar.buttons.systray.customIcon" = "#d4be98";
      "theme.bar.buttons.bluetooth.icon_background" = "#88b482";
      "theme.bar.buttons.bluetooth.icon" = "#89b482";
      "theme.bar.buttons.bluetooth.text" = "#89b482";
      "theme.bar.buttons.bluetooth.background" = "#32302f";
      "theme.bar.buttons.bluetooth.border" = "#89b482";
      "theme.bar.buttons.network.icon_background" = "#b06286";
      "theme.bar.buttons.network.icon" = "#b16286";
      "theme.bar.buttons.network.text" = "#b16286";
      "theme.bar.buttons.network.background" = "#32302f";
      "theme.bar.buttons.network.border" = "#b16286";
      "theme.bar.buttons.volume.icon_background" = "#c14a4a";
      "theme.bar.buttons.volume.icon" = "#c14a4a";
      "theme.bar.buttons.volume.text" = "#c14a4a";
      "theme.bar.buttons.volume.background" = "#32302f";
      "theme.bar.buttons.volume.border" = "#c14a4a";
      "theme.bar.buttons.media.icon_background" = "#7daea3";
      "theme.bar.buttons.media.icon" = "#7daea3";
      "theme.bar.buttons.media.text" = "#7daea3";
      "theme.bar.buttons.media.background" = "#32302f";
      "theme.bar.buttons.media.border" = "#7daea3";
      "theme.bar.buttons.windowtitle.icon_background" = "#d3869b";
      "theme.bar.buttons.windowtitle.icon" = "#d3869b";
      "theme.bar.buttons.windowtitle.text" = "#d3869b";
      "theme.bar.buttons.windowtitle.border" = "#d3869b";
      "theme.bar.buttons.windowtitle.background" = "#32302f";
      "theme.bar.buttons.workspaces.numbered_active_underline_color" = "#d3869b";
      "theme.bar.buttons.workspaces.numbered_active_highlighted_text_color" = "#232323";
      "theme.bar.buttons.workspaces.hover" = "#d3869b";
      "theme.bar.buttons.workspaces.active" = "#d3869b";
      "theme.bar.buttons.workspaces.occupied" = "#ebdbb2";
      "theme.bar.buttons.workspaces.available" = "#89b482";
      "theme.bar.buttons.workspaces.border" = "#d3869b";
      "theme.bar.buttons.workspaces.background" = "#32302f";
      "theme.bar.buttons.dashboard.icon" = "#d8a657";
      "theme.bar.buttons.dashboard.border" = "#d8a657";
      "theme.bar.buttons.dashboard.background" = "#32302f";
      "theme.bar.buttons.icon" = "#7daea3";
      "theme.bar.buttons.text" = "#7daea3";
      "theme.bar.buttons.hover" = "#45403d";
      "theme.bar.buttons.icon_background" = "#32302f";
      "theme.bar.buttons.background" = "#32302f";
      "theme.bar.buttons.borderColor" = "#7daea3";
      "theme.bar.buttons.style" = "default";
      "theme.bar.background" = "#1d2021";
      "theme.osd.label" = "#7daea4";
      "theme.osd.icon" = "#1d2021";
      "theme.osd.bar_overflow_color" = "#ea6961";
      "theme.osd.bar_empty_color" = "#3c3836";
      "theme.osd.bar_color" = "#7daea4";
      "theme.osd.icon_container" = "#7daea4";
      "theme.osd.bar_container" = "#1d2021";
      "theme.notification.close_button.label" = "#1d2021";
      "theme.notification.close_button.background" = "#ea6961";
      "theme.notification.labelicon" = "#7daea3";
      "theme.notification.text" = "#d4be98";
      "theme.notification.time" = "#7c6f63";
      "theme.notification.border" = "#3c3835";
      "theme.notification.label" = "#7daea3";
      "theme.notification.actions.text" = "#232323";
      "theme.notification.actions.background" = "#7daea2";
      "theme.notification.background" = "#232324";
      "theme.bar.buttons.modules.submap.icon" = "#8ec07c";
      "theme.bar.buttons.modules.submap.background" = "#32302f";
      "theme.bar.buttons.modules.submap.icon_background" = "#32302f";
      "theme.bar.buttons.modules.submap.text" = "#8ec07c";
      "theme.bar.buttons.modules.submap.border" = "#8ec07c";
      "theme.bar.menus.menu.network.switch.enabled" = "#b16286";
      "theme.bar.menus.menu.network.switch.disabled" = "#3c3837";
      "theme.bar.menus.menu.network.switch.puck" = "#45403c";
      "theme.bar.border.color" = "#7daea3";
      "theme.bar.buttons.modules.hyprsunset.icon" = "#e78a4e";
      "theme.bar.buttons.modules.hyprsunset.background" = "#32302f";
      "theme.bar.buttons.modules.hyprsunset.icon_background" = "#32302f";
      "theme.bar.buttons.modules.hyprsunset.text" = "#e78a4e";
      "theme.bar.buttons.modules.hyprsunset.border" = "#d3869b";
      "theme.bar.buttons.modules.hypridle.icon" = "#d3869b";
      "theme.bar.buttons.modules.hypridle.background" = "#32302f";
      "theme.bar.buttons.modules.hypridle.icon_background" = "#d3869b";
      "theme.bar.buttons.modules.hypridle.text" = "#d3869b";
      "theme.bar.buttons.modules.hypridle.border" = "#d3869b";
      "theme.bar.buttons.modules.cava.text" = "#8ec07c";
      "theme.bar.buttons.modules.cava.background" = "#32302f";
      "theme.bar.buttons.modules.cava.icon_background" = "#32302f";
      "theme.bar.buttons.modules.cava.icon" = "#8ec07c";
      "theme.bar.buttons.modules.cava.border" = "#8ec07c";
      "theme.bar.buttons.modules.worldclock.text" = "#d3869b";
      "theme.bar.buttons.modules.worldclock.background" = "#32302f";
      "theme.bar.buttons.modules.worldclock.icon_background" = "#d3869b";
      "theme.bar.buttons.modules.worldclock.icon" = "#d3869b";
      "theme.bar.buttons.modules.worldclock.border" = "#d3869b";
      "theme.bar.buttons.modules.microphone.border" = "#a9b665";
      "theme.bar.buttons.modules.microphone.background" = "#32302f";
      "theme.bar.buttons.modules.microphone.text" = "#a9b665";
      "theme.bar.buttons.modules.microphone.icon" = "#a9b665";
      "theme.bar.buttons.modules.microphone.icon_background" = "#32302f";
    };
  };
}
