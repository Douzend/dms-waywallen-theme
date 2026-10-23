import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string db: home + "/.local/share/waywallen/waywallen-v2.db"
    readonly property string dir: home + "/.cache/waywallen-theme"
    readonly property string dmsBin: Quickshell.env("DMS_EXECUTABLE") || "dms"
    readonly property int percent: Math.min(100, Math.max(0, Math.round(pluginData.framePercent ?? 5)))
    readonly property bool makeWallpaper: pluginData.applyWallpaper !== false
    readonly property int outHeight: {
        const s = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        return s ? Math.round(s.height * (s.devicePixelRatio || 1)) : 1080;
    }
    readonly property int outWidth: {
        const s = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        return s ? Math.round(s.width * (s.devicePixelRatio || 1)) : 1920;
    }

    property string lastId: ""
    property bool busy: false
    property string warnedId: ""

    FileView {
        id: cfg
        path: root.home + "/.config/waywallen/config.toml"
        watchChanges: true
        onLoaded: root.sync()
        onFileChanged: debounce.restart()
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.sync()
    }

    Timer {
        // Waywallen replaces config.toml atomically, which kills the file watch,
        // so poll it. A 3 s read is cheap and keeps the sync responsive.
        interval: 3000
        repeat: true
        running: true
        onTriggered: cfg.reload()
    }

    Connections {
        target: SessionData
        function onIsLightModeChanged() {
            root.lastId = "";
            root.sync();
        }
    }

    onPercentChanged: {
        root.lastId = "";
        root.sync();
    }

    onOutHeightChanged: {
        root.lastId = "";
        root.sync();
    }

    onOutWidthChanged: {
        root.lastId = "";
        root.sync();
    }

    onMakeWallpaperChanged: {
        root.lastId = "";
        root.sync();
    }

    function sync() {
        if (busy || !cfg.text())
            return;
        const m = cfg.text().match(/^last_wallpaper\s*=\s*"([^"]+)"/m);
        if (!m || !/^\d+$/.test(m[1]) || m[1] === lastId)
            return;
        lastId = m[1];
        busy = true;
        Proc.runCommand("ww.db", ["sqlite3", "-separator", "|", "file:" + db + "?mode=ro",
            "SELECT i.type, i.path, COALESCE(i.preview_path,''), l.path FROM item i " +
            "JOIN library l ON l.id = i.library_id WHERE i.id = " + m[1] + " LIMIT 1;"],
            (out, code) => {
                if (code !== 0 || !out.trim())
                    return root.fail("Wallpaper not found in the Waywallen library", m[1]);
                const f = out.trim().split("|");
                const abs = p => p.startsWith("/") ? p : f[3] + "/" + p;
                const isVideo = f[0] === "video";
                const src = (isVideo || f[0] === "image") ? abs(f[1]) : (f[2] ? abs(f[2]) : "");
                if (!src)
                    return root.fail("This wallpaper has no preview to sample", m[1]);
                root.grab(m[1], src, root.percent);
            });
    }

    function grab(id, src, pct) {
        const out = dir + "/frame-" + id + "-" + pct + ".png";
        Proc.runCommand("ww.mkdir", ["mkdir", "-p", dir], () => {});
        Proc.runCommand("ww.probe", ["ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "csv=p=0", src], (durText) => {
            const dur = parseFloat(durText) || 0;
            const sec = dur > 0.2 ? (dur * Math.min(pct, 98) / 100).toFixed(3) : "";
            const args = ["ffmpeg", "-v", "error", "-y"];
            if (sec) args.push("-ss", sec);
            args.push("-i", src, "-frames:v", "1",
                "-vf", "scale=" + outWidth + ":" + outHeight +
                      ":force_original_aspect_ratio=increase:flags=lanczos," +
                      "crop=" + outWidth + ":" + outHeight, out);
            Proc.runCommand("ww.ff", args, (o, code) => {
                if (code !== 0) return root.fail("ffmpeg could not extract the frame", id);
                Proc.runCommand("ww.check", ["test", "-s", out], (t, tc) =>
                    tc === 0 ? root.apply(out, id)
                             : root.fail("ffmpeg could not extract the frame", id));
            });
        });
    }

    function apply(frame, id) {
        if (makeWallpaper) {
            Proc.runCommand("ww.wall", [dmsBin, "ipc", "call", "wallpaper", "set", frame],
                () => root.clean(id));
        } else {
            Theme.setDesiredTheme("image", frame, SessionData.isLightMode,
                SettingsData.iconTheme || "System Default",
                SettingsData.matugenScheme || "scheme-tonal-spot");
            root.clean(id);
        }
        lastId = id;
        busy = false;
        warnedId = "";
    }

    function clean(id) {
        const args = ["find", dir, "-name", "frame-*.png",
                      "!", "-name", "frame-" + id + "-*.png"];
        // In wallpaper mode the old frame is no longer displayed, so it can go now.
        // In colors-only mode DMS may still show it, so only drop files older than a day.
        if (!makeWallpaper)
            args.push("-mmin", "+1440");
        args.push("-delete");
        Proc.runCommand("ww.clean", args, () => {});
    }

    function fail(msg, id) {
        busy = false;
        lastId = id;
        if (warnedId === id)
            return;
        warnedId = id;
        ToastService.showError(I18n.trFor("waywallenTheme", "Theme sync failed"),
                               I18n.trFor("waywallenTheme", msg));
    }

    IpcHandler {
        target: "waywallenTheme"
        function sync(): string { root.lastId = ""; root.sync(); return "ok"; }
    }
}
