import QtQuick 6.8
import QtQuick.Controls 6.8
import QtQuick.Effects 6.8
import "timestamps.js" as Timestamps

Item {
    property int timePosition: 0

    function tryLogin() {
        sddm.login(userPanel.user, userPanel.password, sessionPanel.currentSessionID);
    }

    Keys.forwardTo: [sessionPanel]
    //Poweroff and Reboot
    Keys.onReleased: (event) => {
        switch (event.key) {
        case Qt.Key_P:
            if (event.modifiers & Qt.MetaModifier)
                sddm.powerOff();

            break;
        case Qt.Key_R:
            if (event.modifiers & Qt.MetaModifier)
                sddm.reboot();

            break;
        }
    }
        
    UserPanel {
        id: userPanel

        anchors {
            centerIn: parent
        }
    }

    SessionPanel {
        id: sessionPanel

        anchors {
            bottom: parent.bottom
            bottomMargin: 35
            left: parent.left
            leftMargin: 60
        }

    }

    Text {
        text: `@${sddm.hostName}_____`

        color: "white"
        renderType: Text.QtRendering

        anchors {
            top: parent.top
            topMargin: 15
            right: parent.right
        }

        font {
            family: primaryFont.name
            pointSize: config.fontSize
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {

        colorization: 1.0
        colorizationColor: primaryColor

        readonly property var a: Timestamps.blurInterval[0]
        readonly property var b: Timestamps.blurInterval[1]
        blurEnabled: true
        blurMax: 48
        blur: ((a > b && (timePosition >= a || timePosition <= b)) 
                || (a <= b && timePosition >= a && timePosition <= b))
                ? 1.0 : 0
        shadowEnabled: true
        shadowBlur : 1.0
        shadowColor : primaryColor
    }
}
