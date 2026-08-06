pragma Singleton
import Quickshell.Services.Mpris
import QtQuick

QtObject {
    id: root

    readonly property var activePlayer: {
        var available = root.players;
        if (!available || available.length === 0)
            return null;

        if (root.preferredPlayerName !== "") {
            for (var preferredIndex = 0; preferredIndex < available.length; ++preferredIndex) {
                var preferred = available[preferredIndex];
                if (preferred && preferred.dbusName === root.preferredPlayerName)
                    return preferred;
            }
        }
        var selected = null;
        var selectedScore = -1000;
        for (var index = 0; index < available.length; ++index) {
            var player = available[index];
            if (!player)
                continue;

            var identity = (player.identity || "").toLowerCase();
            var score = player.playbackState === MprisPlaybackState.Playing ? 100 : player.playbackState === MprisPlaybackState.Paused ? 20 : 0;

            if ((player.trackTitle || "").trim() === "")
                score -= 30;
            if (player.canControl !== undefined && !player.canControl)
                score -= 30;

            if (identity.indexOf("spotify") !== -1)
                score += 15;
            else if (identity.indexOf("music") !== -1)
                score += 10;
            else if (identity.indexOf("youtube") !== -1 || identity.indexOf("soundcloud") !== -1)
                score += 5;

            if (score > selectedScore) {
                selected = player;
                selectedScore = score;
            }
        }
        return selected;
    }
    readonly property string artist: activePlayer ? (activePlayer.trackArtist || activePlayer.trackAlbumArtist || activePlayer.identity || "Unknown artist") : ""
    readonly property int playerCount: players ? players.length : 0
    readonly property var players: {
        var all = Mpris.players ? Mpris.players.values : [];
        var filtered = [];
        for (var i = 0; i < all.length; ++i) {
            var p = all[i];
            if (!p)
                continue;

            // 1. Must be able to play or pause at minimum
            if (!p.canPlay && !p.canPause)
                continue;

            var title = (p.trackTitle || "").trim();
            var identity = (p.identity || "").toLowerCase();
            var isBrowser = identity.indexOf("chrome") !== -1 || identity.indexOf("firefox") !== -1 || identity.indexOf("brave") !== -1 || identity.indexOf("edge") !== -1 || identity.indexOf("chromium") !== -1;

            // 2. Filter out closed/ghost browser tabs (no title and not playing)
            if (isBrowser && title === "" && p.playbackState !== MprisPlaybackState.Playing)
                continue;

            // 3. Invalid D-Bus registration
            if ((p.dbusName || "").trim() === "")
                continue;

            filtered.push(p);
        }
        return filtered;
    }
    readonly property bool playing: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    // A player chosen from the Music page remains selected until it disappears.
    // Keeping only its DBus name avoids retaining a destroyed MprisPlayer object.
    property string preferredPlayerName: ""
    readonly property string title: activePlayer ? (activePlayer.trackTitle || activePlayer.identity || "Unknown title") : ""

    function isSelected(player) {
        return !!player && player === activePlayer;
    }
    function selectNextPlayer() {
        if (!players || players.length <= 1)
            return;
        var currentIndex = players.indexOf(activePlayer);
        var nextIndex = (currentIndex + 1) % players.length;
        selectPlayer(players[nextIndex]);
    }
    function selectPlayer(player) {
        if (player)
            preferredPlayerName = player.dbusName || "";
    }
    function selectPrevPlayer() {
        if (!players || players.length <= 1)
            return;
        var currentIndex = players.indexOf(activePlayer);
        var prevIndex = (currentIndex - 1 + players.length) % players.length;
        selectPlayer(players[prevIndex]);
    }
}
