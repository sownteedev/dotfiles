import { bind, Variable } from "astal"
import { Gtk } from "astal/gtk3"
import Cava from "gi://AstalCava"
import Mpris from "gi://AstalMpris"

export default function MediaCava() {
	const mpris = Mpris.get_default()
    const cava = Cava.get_default()
    
    if (!cava) {
        console.error("Cava not available")
        return <box />
    }

    // Configure cava settings
    cava.bars = 20
    cava.framerate = 60
    cava.active = true
    cava.autosens = true
    cava.stereo = false

    const getActivePlayer = () => {
        const players = mpris.players
        return players.find(player => 
            player.available && 
            player.playbackStatus === Mpris.PlaybackStatus.PLAYING
        ) || players.find(player => player.available) || null
    }

    const currentPlayer = Variable(getActivePlayer())
    
    // Update current player when players change
    mpris.connect("player-added", () => {
        currentPlayer.set(getActivePlayer())
    })
    
    mpris.connect("player-closed", () => {
        currentPlayer.set(getActivePlayer())
    })

    const mediaProgress = bind(currentPlayer).as(player => {
            if (!player || !player.available) {
                return (
                    <circularprogress
                        widthRequest={40}
                        className="progress-media"
                        startAt={0}
                        endAt={1.0}
                        rounded={true}
                        value={0}
                        child={
                            <box 
                                className="cover-art-placeholder"
                                css={`
                                    min-width: 32px;
                                    min-height: 32px;
                                    background-color: rgba(255, 255, 255, 0.1);
                                    border-radius: 50%;
                                `}
                            />
                        }
                    />
                )
            }

            const progress = player.length > 0 ? player.position / player.length : 0
            const coverArt = player.coverArt || ""
            
            return (
                <circularprogress
                    widthRequest={40}
                    className="progress-media"
                    startAt={0}
                    endAt={1.0}
                    rounded={true}
                    value={bind(player, "position").as(pos => {
                        const length = player.length
                        return length > 0 ? pos / length : 0
                    })}
                    child={
                        <box 
                            className="cover-art" 
                            css={bind(player, "coverArt").as(art => `
                                min-width: 32px;
                                min-height: 32px;
                                background-image: url('${art || ""}');
                                background-size: cover;
                                background-position: center;
                                border-radius: 50%;
                                ${!art ? 'background-color: rgba(255, 255, 255, 0.1);' : ''}
                            `)}
                        />
                    }
                />
            )
        })
    }

    const MediaInfo = () => {
        return bind(currentPlayer).as(player => {
            if (!player || !player.available) {
                return <label label="No media playing" className="media-info-idle" />
            }

            const title = player.title || "Unknown"
            const artist = player.artist || "Unknown Artist"
            
            return (
                <box vertical spacing={2} className="media-info">
                    <label 
                        label={title}
                        className="media-title"
                        truncate
                        maxWidthChars={25}
                        xalign={0}
                    />
                    <label 
                        label={artist}
                        className="media-artist"
                        truncate
                        maxWidthChars={25}
                        xalign={0}
                    />
                </box>
            )
        })
    }

    const AudioVisualizer = () => {
        return (
            <box spacing={2} className="audio-visualizer" valign={Gtk.Align.END}>
                {bind(cava, "values").as(values => {
                    if (!values || values.length === 0) {
                        return Array.from({ length: 20 }, (_, i) => (
                            <box 
                                className="visualizer-bar static"
                                css={`
                                    min-height: 2px;
                                    min-width: 3px;
                                    background-color: rgba(255, 255, 255, 0.3);
                                    border-radius: 1px;
                                `}
                            />
                        ))
                    }

                    return values.map((value, index) => {
                        const height = Math.max(2, Math.min(30, value * 30))
                        const opacity = Math.max(0.3, Math.min(1, value + 0.3))
                        
                        return (
                            <box 
                                className="visualizer-bar active"
                                css={`
                                    min-height: ${height}px;
                                    min-width: 3px;
                                    background-color: rgba(255, 255, 255, ${opacity});
                                    border-radius: 1px;
                                    transition: height 0.1s ease-out;
                                `}
                            />
                        )
                    })
                })}
            </box>
        )
    }

    return (
        <box 
            vertical 
            spacing={8} 
            className="media-cava-container"
            css={`
                padding: 8px 12px;
                background-color: rgba(0, 0, 0, 0.8);
                border-radius: 8px;
                min-width: 200px;
            `}
        >
            <AudioVisualizer />
        </box>
    )
}