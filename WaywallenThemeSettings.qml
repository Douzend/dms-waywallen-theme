
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "waywallenTheme"

    StyledText {
        width: parent.width
        text: I18n.trFor("waywallenTheme", "Waywallen Theme Sync")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "applyWallpaper"
        label: I18n.trFor("waywallenTheme", "Set wallpaper")
        description: I18n.trFor("waywallenTheme", "When off, only the colors are synced")
        defaultValue: false
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("waywallenTheme",
            "Warning: Scene wallpapers may look soft or zoomed")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "framePercent"
        label: I18n.trFor("waywallenTheme", "Position")
        description: I18n.trFor("waywallenTheme", "Percentage of the animation used to build the color palette")
        defaultValue: 5
        minimum: 0
        maximum: 100
        unit: "%"
    }

}
