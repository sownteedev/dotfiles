import QtQuick 6.8
import QtQuick.Effects 6.8
import SddmComponents
import "sessions.js" as Sessions

Item {
    property int currentSessionID: sessionModel.lastIndex
    property int sessionNameRole: Qt.UserRole + 4
    property var sessionIcons: Sessions.sessionIcons
    property string sessionName: sessionModel.data(
        sessionModel.index(currentSessionID, 0),
        sessionNameRole
    )
    property string sessionIconPath: ""
    property var filterSessions: JSON.parse(config.FilterSessions)

    /**
    * @param direction 1 for next, -1 for previous
    */
    function getNextEntry(direction)
    {
        let initEntryID = currentSessionID;
        let entryID = currentSessionID;
        do {
            currentSessionID = (currentSessionID + direction + sessionModel.count) % sessionModel.count;
        } while (
            filterSessions && sessionIcons[sessionName] == undefined & 
            //Avoid infinite loops when no entry present
            initEntryID != currentSessionID
        );
    }

    function updateIconSource() {
        let iconPath = sessionIcons[sessionName]?.icon;
        if (iconPath === undefined)
        {
            sessionIcon.active = false;
            return;
        }

        sessionIcon.active = true;
        sessionIconPath = iconPath;
    }

    onSessionNameChanged: updateIconSource()
    Component.onCompleted: { // Set initial session
        if(filterSessions && sessionIcons[sessionName] === undefined) {
            getNextEntry(1);
        }
        updateIconSource();
    }

    Keys.onPressed: (event) => {
        if(event.key != Qt.Key_Alt) return;
        getNextEntry(event.modifiers & Qt.ShiftModifier ? -1 : 1);
    }

    width: row.implicitWidth
    height: row.height
    Row {
        id: row
        spacing: 10
        height: config.iconSize

        Loader {
            id: sessionIcon

            width: item ? item.width : 0
            sourceComponent: Image {
                height: row.height
                width: height
                source: sessionIconPath
                //scale of the svg
                sourceSize {
                    width: 32
                    height: 32
                }
                smooth: true
            }
        }

        Text {
            id: sessionNameText
            color: "white"

            text: (sessionIcons[sessionName]?.alias)
                    ? sessionIcons[sessionName].alias
                    : sessionName

            font {
                family: primaryFont.name
                pointSize: config.fontSize
            }
            renderType: Text.QtRendering

            anchors {
                verticalCenter: parent.verticalCenter
            }
        }
    }
}
