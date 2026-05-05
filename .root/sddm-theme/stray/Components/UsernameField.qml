import QtQuick 6.8
import QtQuick.Controls 6.8

Item {
    property int currentUserID: userModel.lastIndex
    property int userNameRole: Qt.UserRole + 1
    property int userRealNameRole: Qt.UserRole + 2
    property var user: userModel.data(
        userModel.index(currentUserID, 0),
        userNameRole
    )
    property var realName: userModel.data(
        userModel.index(currentUserID, 0),
        userRealNameRole
    )

    property alias font: inner.font
    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Tab:
            currentUserID = (currentUserID + 1) % userModel.count;
            break;
        case Qt.Key_Backtab:
            currentUserID = (currentUserID - 1 + userModel.count) % userModel.count;
            break;
        }
    }

    Text {
        id: inner
        anchors.fill: parent
        renderType: Text.QtRendering
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        text: realName ? realName : user

        font {
            family: primaryFont.name
        }

    }

}
