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
        var selectedScore = -1;
        for (var index = 0; index < available.length; ++index) {
            var player = available[index];
            if (!player)
                continue;

            var identity = (player.identity || "").toLowerCase();
            var score = player.playbackState === MprisPlaybackState.Playing ? 100 : player.playbackState === MprisPlaybackState.Paused ? 20 : 0;
            if (identity.indexOf("spotify") !== -1)
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
    readonly property var players: Mpris.players ? Mpris.players.values : []
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
