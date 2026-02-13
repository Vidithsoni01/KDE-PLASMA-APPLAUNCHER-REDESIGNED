/*
 * SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras

BasePage {
    id: root

    // 👇 Compact, fixed sidebar width
    sideBarComponent: KickoffListView {
        id: sideBar

        // --- Sidebar width customization ---
        implicitWidth: Kirigami.Units.gridUnit * 10
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.maximumWidth: Kirigami.Units.gridUnit * 10
        // -----------------------------------

        focus: true // needed for Loaders
        model: kickoff.rootModel

        // Disable automatic section headers (cleaner look)
        section.property: ""

        delegate: KickoffListDelegate {
            width: view.availableWidth
            isCategoryListItem: true
            background: PlasmaExtras.Highlight {
                anchors.fill: parent
                active: false
                hovered: parent.mouseArea.containsMouse
                visible: !Plasmoid.configuration.switchCategoryOnHover
                    && !parent.isSeparator && !parent.ListView.isCurrentItem
                    && hovered
            }
        }

        spacing: Kirigami.Units.smallSpacing
        leftPadding: Kirigami.Units.smallSpacing
        rightPadding: Kirigami.Units.smallSpacing
    }

    // Main app area
    contentAreaComponent: VerticalStackView {
        id: stackView

        // --- Animations ---
        popEnter: Transition {
            NumberAnimation { property: "x"; from: 0.5 * root.width; to: 0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        pushEnter: Transition {
            NumberAnimation { property: "x"; from: -0.5 * root.width; to: 0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
        // ------------------

        readonly property string preferredFavoritesViewObjectName: Plasmoid.configuration.favoritesDisplay === 0 ? "favoritesGridView" : "favoritesListView"
        readonly property Component preferredFavoritesViewComponent: Plasmoid.configuration.favoritesDisplay === 0 ? favoritesGridViewComponent : favoritesListViewComponent
        readonly property string preferredAllAppsViewObjectName: Plasmoid.configuration.applicationsDisplay === 0 ? "listOfGridsView" : "applicationsListView"
        readonly property Component preferredAllAppsViewComponent: Plasmoid.configuration.applicationsDisplay === 0 ? listOfGridsViewComponent : applicationsListViewComponent
        readonly property string preferredAppsViewObjectName: Plasmoid.configuration.applicationsDisplay === 0 ? "applicationsGridView" : "applicationsListView"
        readonly property Component preferredAppsViewComponent: Plasmoid.configuration.applicationsDisplay === 0 ? applicationsGridViewComponent : applicationsListViewComponent

        property int appsModelRow: 0
        readonly property Kicker.AppsModel appsModel: kickoff.rootModel.modelForRow(appsModelRow)

        Connections {
            target: kickoff.rootModel
            function onRefreshed() { stackView.appsModelRowChanged() }
        }

        focus: true
        initialItem: preferredFavoritesViewComponent

        function showSectionView(sectionName: string, parentView: KickoffListView): void {
            stackView.push(applicationsSectionViewComponent, {
                currentSection: sectionName,
                parentView,
            });
        }

        // --- View Components ---
        Component {
            id: favoritesListViewComponent
            DropAreaListView {
                id: favoritesListView
                objectName: "favoritesListView"
                mainContentView: true
                focus: true
                model: kickoff.rootModel.favoritesModel
            }
        }

        Component {
            id: favoritesGridViewComponent
            DropAreaGridView {
                id: favoritesGridView
                objectName: "favoritesGridView"
                focus: true
                model: kickoff.rootModel.favoritesModel
            }
        }

        Component {
            id: applicationsListViewComponent
            KickoffListView {
                id: applicationsListView
                objectName: "applicationsListView"
                mainContentView: true
                model: stackView.appsModel
                section.property: model && model.description === "KICKER_ALL_MODEL" ? "group" : "_unset"
                section.criteria: ViewSection.FirstCharacter
                hasSectionView: stackView.appsModelRow === 1

                onShowSectionViewRequested: sectionName => {
                    stackView.showSectionView(sectionName, this);
                }
            }
        }

        Component {
            id: applicationsSectionViewComponent
            SectionView {
                id: sectionView
                model: stackView.appsModel.sections

                onHideSectionViewRequested: index => {
                    stackView.pop();
                    stackView.currentItem.view.positionViewAtIndex(index, ListView.Beginning);
                    stackView.currentItem.currentIndex = index;
                }
            }
        }

        Component {
            id: applicationsGridViewComponent
            KickoffGridView {
                id: applicationsGridView
                objectName: "applicationsGridView"
                model: stackView.appsModel
            }
        }

        Component {
            id: listOfGridsViewComponent
            ListOfGridsView {
                id: listOfGridsView
                objectName: "listOfGridsView"
                mainContentView: true
                gridModel: stackView.appsModel

                onShowSectionViewRequested: sectionName => {
                    stackView.showSectionView(sectionName, this);
                }
            }
        }
        // --- End Views ---

        // --- Behavior for switching ---
        onPreferredFavoritesViewComponentChanged: {
            if (root.sideBarItem && root.sideBarItem.currentIndex === 0) {
                stackView.replace(stackView.preferredFavoritesViewComponent)
            }
        }
        onPreferredAllAppsViewComponentChanged: {
            if (root.sideBarItem && root.sideBarItem.currentIndex === 1) {
                stackView.replace(stackView.preferredAllAppsViewComponent)
            }
        }
        onPreferredAppsViewComponentChanged: {
            if (root.sideBarItem && root.sideBarItem.currentIndex > 1) {
                stackView.replace(stackView.preferredAppsViewComponent)
            }
        }

        Connections {
            target: root.sideBarItem
            function onCurrentIndexChanged() {
                if (root.sideBarItem.currentIndex > 0) {
                    stackView.appsModelRow = root.sideBarItem.currentIndex
                }

                if (root.sideBarItem.currentIndex === 0
                    && stackView.currentItem.objectName !== stackView.preferredFavoritesViewObjectName) {
                    stackView.replace(stackView.preferredFavoritesViewComponent)
                } else if (root.sideBarItem.currentIndex === 1
                    && stackView.currentItem.objectName !== stackView.preferredAllAppsViewObjectName) {
                    stackView.replace(stackView.preferredAllAppsViewComponent)
                } else if (root.sideBarItem.currentIndex > 1
                    && stackView.currentItem.objectName !== stackView.preferredAppsViewObjectName) {
                    stackView.replace(stackView.preferredAppsViewComponent)
                }
            }
        }

        Connections {
            target: kickoff
            function onExpandedChanged() {
                if (!kickoff.expanded && kickoff.contentArea.currentItem) {
                    kickoff.contentArea.currentItem.forceActiveFocus()
                }
            }
        }
    }

    // --- Bindings ---
    Binding {
        target: kickoff
        property: "sideBar"
        value: root.sideBarItem
        when: root.T.StackView.status === T.StackView.Active && root.visible
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        target: kickoff
        property: "contentArea"
        value: root.contentAreaItem.currentItem
        when: root.T.StackView.status === T.StackView.Active && root.visible
        restoreMode: Binding.RestoreBinding
    }
}
