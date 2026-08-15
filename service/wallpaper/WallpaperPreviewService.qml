pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool active: false
    property var activeJob: null
    readonly property string cacheDir: Config.cacheRoot + "/wallpaper-preview"
    property bool commitApplyColors: false
    property string commitKey: ""
    property int commitToken: 0
    property string currentKey: ""
    readonly property int maxPaletteCacheEntries: 16
    property var originalColors: null
    property var paletteCache: ({})
    property var paletteCacheOrder: []
    property var pendingJob: null
    property var preloadQueue: []
    property Process worker: Process {
        stdout: StdioCollector {
            id: workerOutput
        }

        onExited: (exitCode, exitStatus) => {
            var job = root.activeJob;
            root.activeJob = null;

            if (job && exitCode === 0) {
                try {
                    var palette = null;
                    if (Config.matugenEnabled && job.mode === ThemeService.colorMode) {
                        palette = root.paletteFromMatugen(JSON.parse(workerOutput.text.trim()));
                        root.storePalette(job.key, palette);
                    }

                    // A slow, stale job must never recolor the wallpaper which
                    // is currently focused in the selector.
                    if (palette && root.active && job.key === root.currentKey)
                        ThemeService.applyColors(palette, true);

                    if (root.commitKey === job.key)
                        root.finishCommit(job, palette);
                } catch (error) {
                    console.warn("[WallpaperPreviewService] Invalid Matugen palette:", error);
                    // The full theme generator can still use the prepared
                    // thumbnail. Remove only the broken palette cache so the
                    // next preview can regenerate it.
                    Quickshell.execDetached(["rm", "-f", job.palette]);
                    if (root.commitKey === job.key)
                        root.finishCommit(job, null);
                }
            } else if (job) {
                console.warn("[WallpaperPreviewService] Could not prepare preview for", job.path);
                if (root.commitKey === job.key)
                    root.finishCommit(job, null, job.path);
            }

            root.processNext();
        }
    }

    signal themeSourceReady(string sourcePath, string thumbnailPath, int requestToken)

    function accept(path, modified, applyColorsNow, requestToken) {
        if (!path)
            return;

        var key = cacheKey(path, modified);
        active = false;
        originalColors = null;
        currentKey = "";
        commitKey = key;
        commitToken = Number(requestToken || 0);
        commitApplyColors = applyColorsNow === true;

        if (Config.matugenEnabled && paletteCache[key] !== undefined) {
            touchPalette(key);
            finishCommit(makeJob(path, modified, commitToken), paletteCache[key]);
            return;
        }

        queue(path, modified);
    }
    function begin() {
        active = true;
        currentKey = "";
        commitKey = "";
        commitToken = 0;
        commitApplyColors = false;
        originalColors = cloneColors(ThemeService.activeColors);
    }
    function cacheKey(path, modified) {
        return WallpaperService.stableHash(thumbnailKey(path, modified) + "|" + ThemeService.colorMode);
    }
    function cancel() {
        currentKey = "";
        commitKey = "";
        commitToken = 0;
        commitApplyColors = false;

        if (active && originalColors)
            ThemeService.applyColors(originalColors, true);

        active = false;
        originalColors = null;
        pendingJob = null;
        preloadQueue = [];
    }
    function cloneColors(colors) {
        if (!colors)
            return null;
        try {
            return JSON.parse(JSON.stringify(colors));
        } catch (error) {
            return colors;
        }
    }
    function finishCommit(job, palette, fallbackPath) {
        if (palette && commitApplyColors)
            ThemeService.applyColors(palette, true);
        commitApplyColors = false;
        commitKey = "";
        themeSourceReady(job.path, fallbackPath || job.thumbnail, Number(job.requestToken || 0));
        commitToken = 0;
    }
    function makeJob(path, modified, requestToken) {
        var key = cacheKey(path, modified);
        return {
            "key": key,
            "mode": ThemeService.colorMode,
            "palette": palettePath(key),
            "path": path,
            "requestToken": Number(requestToken || 0),
            "thumbnail": thumbnailPath(thumbnailKey(path, modified))
        };
    }
    function paletteFromMatugen(output) {
        var result = {
            "md3": {},
            "palette": {},
            "base16": {}
        };
        var colors = output && output.colors ? output.colors : {};
        var palettes = output && output.palettes ? output.palettes : {};
        var base16 = output && output.base16 ? output.base16 : {};

        for (var colorName in colors) {
            var color = colors[colorName];
            if (color && color.default && color.default.color)
                result.md3[colorName] = color.default.color;
        }
        for (var paletteName in palettes) {
            var tones = palettes[paletteName];
            for (var shade in tones) {
                var tone = tones[shade];
                if (tone && tone.color)
                    result.palette[paletteName + shade] = tone.color;
            }
        }
        for (var baseName in base16) {
            var base = base16[baseName];
            if (base && base.default && base.default.color)
                result.base16[baseName] = base.default.color;
        }

        if (!result.md3.primary || !result.md3.on_surface)
            throw new Error("Missing Material colors");
        return result;
    }
    function palettePath(key) {
        return cacheDir + "/" + key + ".json";
    }
    function preload(path, modified) {
        if (!Config.matugenEnabled || !active || !path)
            return;

        var key = cacheKey(path, modified);
        if (paletteCache[key] !== undefined || activeJob && activeJob.key === key || pendingJob && pendingJob.key === key)
            return;

        for (var i = 0; i < preloadQueue.length; ++i) {
            if (preloadQueue[i].key === key)
                return;
        }

        preloadQueue = preloadQueue.concat([makeJob(path, modified)]);
        processNext();
    }
    function preview(path, modified) {
        if (!Config.matugenEnabled || !active || !path)
            return;

        var key = cacheKey(path, modified);
        currentKey = key;
        var cached = paletteCache[key];
        if (cached !== undefined) {
            touchPalette(key);
            ThemeService.applyColors(cached, true);
            return;
        }

        queue(path, modified);
    }
    function processNext() {
        if (worker.running || activeJob)
            return;

        // The newest focused/committed wallpaper always has priority over
        // speculative neighbour preloads.
        if (pendingJob) {
            activeJob = pendingJob;
            pendingJob = null;
        } else if (preloadQueue.length > 0) {
            activeJob = preloadQueue[0];
            preloadQueue = preloadQueue.slice(1);
        } else {
            return;
        }

        var job = activeJob;
        var matugenRunner = Config.quickshellDir + "/scripts/matugen-auto-scheme.sh";
        worker.command = ["sh", "-c", "mkdir -p \"$4\"; " + "if [ ! -s \"$2\" ]; then " + "rm -f \"$2.tmp.jpg\"; " + "if command -v magick >/dev/null 2>&1 && magick \"$1\" -auto-orient -thumbnail '256x256>' -strip \"$2.tmp.jpg\"; then :; " + "else rm -f \"$2.tmp.jpg\" && ffmpeg -hide_banner -loglevel error -y -i \"$1\" -frames:v 1 -vf 'scale=256:256:force_original_aspect_ratio=decrease' \"$2.tmp.jpg\"; fi && " + "mv \"$2.tmp.jpg\" \"$2\"; fi; " + "if [ \"$5\" = true ]; then " + "if [ ! -s \"$3\" ]; then \"$6\" --mode \"$7\" --dry-run --json hex --quiet \"$2\" > \"$3.tmp\" && mv \"$3.tmp\" \"$3\"; fi; " + "cat \"$3\"; else printf '{}'; fi", "wallpaper-preview", job.path, job.thumbnail, job.palette, cacheDir, Config.matugenEnabled ? "true" : "false", matugenRunner, job.mode];
        worker.running = true;
    }
    function queue(path, modified) {
        if (!path)
            return;

        var key = cacheKey(path, modified);
        if (activeJob && activeJob.key === key) {
            if (commitKey === key)
                activeJob.requestToken = commitToken;
            return;
        }
        if (pendingJob && pendingJob.key === key) {
            if (commitKey === key)
                pendingJob.requestToken = commitToken;
            return;
        }

        var filteredPreloads = [];
        for (var i = 0; i < preloadQueue.length; ++i) {
            if (preloadQueue[i].key !== key)
                filteredPreloads.push(preloadQueue[i]);
        }
        preloadQueue = filteredPreloads;
        pendingJob = makeJob(path, modified, commitToken);
        processNext();
    }
    function resetPreloads() {
        preloadQueue = [];
    }
    function storePalette(key, palette) {
        var nextCache = Object.assign({}, paletteCache);
        nextCache[key] = palette;
        paletteCache = nextCache;
        touchPalette(key);
    }
    function thumbnailKey(path, modified) {
        return WallpaperService.stableHash(String(path || "") + "|" + LiveWallpaperService.modifiedKey(modified));
    }
    function thumbnailPath(key) {
        return cacheDir + "/" + key + ".jpg";
    }
    function touchPalette(key) {
        var nextOrder = [];
        for (var i = 0; i < paletteCacheOrder.length; ++i) {
            if (paletteCacheOrder[i] !== key)
                nextOrder.push(paletteCacheOrder[i]);
        }
        nextOrder.push(key);

        var nextCache = Object.assign({}, paletteCache);
        while (nextOrder.length > maxPaletteCacheEntries) {
            var expiredKey = nextOrder.shift();
            delete nextCache[expiredKey];
        }
        paletteCache = nextCache;
        paletteCacheOrder = nextOrder;
    }
}
