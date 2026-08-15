import "../../"
import "../../service"
import QtQuick

Item {
    id: root

    readonly property var sortingOptions: [
        {
            "label": qsTr("Relevance"),
            "value": "relevance"
        },
        {
            "label": qsTr("Date added"),
            "value": "date_added"
        },
        {
            "label": qsTr("Random"),
            "value": "random"
        },
        {
            "label": qsTr("Most viewed"),
            "value": "views"
        },
        {
            "label": qsTr("Most favorited"),
            "value": "favorites"
        },
        {
            "label": qsTr("Toplist"),
            "value": "toplist"
        }
    ]
    readonly property var topRangeOptions: [
        {
            "label": qsTr("1d"),
            "value": "1d"
        },
        {
            "label": qsTr("3d"),
            "value": "3d"
        },
        {
            "label": qsTr("1w"),
            "value": "1w"
        },
        {
            "label": qsTr("1m"),
            "value": "1M"
        },
        {
            "label": qsTr("3m"),
            "value": "3M"
        },
        {
            "label": qsTr("6m"),
            "value": "6M"
        },
        {
            "label": qsTr("1y"),
            "value": "1y"
        }
    ]

    signal closeRequested
    signal filterChanged
    signal hotRequested

    implicitHeight: WallhavenService.sorting === "toplist" ? 198 : 150
    implicitWidth: 340

    Column {
        anchors.fill: parent
        spacing: 8

        Grid {
            columns: 2
            spacing: 6

            Repeater {
                model: root.sortingOptions

                delegate: WallhavenChoiceButton {
                    required property var modelData

                    height: 30
                    label: modelData.label
                    selected: WallhavenService.sorting === modelData.value
                    width: 167

                    onClicked: {
                        WallhavenService.sorting = modelData.value;
                        if (modelData.value !== "toplist")
                            root.closeRequested();

                        root.filterChanged();
                    }
                }
            }
        }
        WallhavenChoiceButton {
            external: true
            height: 30
            label: qsTr("Hot on Wallhaven")
            width: 340

            onClicked: root.hotRequested()
        }
        Column {
            spacing: 6
            visible: WallhavenService.sorting === "toplist"

            Text {
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.DemiBold
                text: qsTr("Toplist period")
            }
            Row {
                spacing: 5

                Repeater {
                    model: root.topRangeOptions

                    delegate: WallhavenChoiceButton {
                        required property var modelData

                        height: 28
                        label: modelData.label
                        selected: WallhavenService.topRange === modelData.value
                        selectedTextColor: Config.md3.on_primary_container
                        width: 44

                        onClicked: {
                            WallhavenService.topRange = modelData.value;
                            root.filterChanged();
                            root.closeRequested();
                        }
                    }
                }
            }
        }
    }
}
