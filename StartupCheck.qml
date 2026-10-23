import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("waywallenTheme.deps", ["sh", "-c", "command -v ffmpeg && command -v sqlite3"],
            (out, code) => {
                if (code === 0) {
                    done(null);
                    return;
                }
                done({
                    title: "ffmpeg and sqlite3 are required",
                    details: "Install them with your package manager, then enable the plugin again. " +
                             "For example: sudo pacman -S ffmpeg sqlite"
                });
            });
    }
}
