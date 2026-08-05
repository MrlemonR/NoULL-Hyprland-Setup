pragma Singleton

import QtQuick
import Quickshell

// Başlatıcının beyni: sekmeler, sorgu dağıtımı ve sonuç birleştirme.
Singleton {
    id: root

    property string query: ""
    property int selectedIndex: 0
    property string activeTab: "apps"

    readonly property var providers: [appsProvider, filesProvider, favoritesProvider, systemProvider]

    readonly property int maxResults: 60

    readonly property var activeProvider: {
        for (let i = 0; i < root.providers.length; i++) {
            if (root.providers[i].providerId === root.activeTab)
                return root.providers[i]
        }
        return root.providers[0]
    }

    readonly property var results: {
        const p = root.activeProvider
        if (!p)
            return []

        if (root.query.trim().length === 0 && !p.showsEmptyQuery)
            return []

        const items = p.results || []
        return items.slice(0, root.maxResults)
    }

    readonly property var selectedItem: root.results[root.selectedIndex] || null

    function reset() {
        root.query = ""
        root.selectedIndex = 0
        root.activeTab = "apps"
    }

    function setTab(tabId) {
        if (root.activeTab === tabId)
            return
        root.activeTab = tabId
        root.selectedIndex = 0
    }

    function nextTab(delta) {
        const count = root.providers.length
        let index = 0
        for (let i = 0; i < count; i++) {
            if (root.providers[i].providerId === root.activeTab)
                index = i
        }
        root.setTab(root.providers[((index + delta) % count + count) % count].providerId)
    }

    function move(delta) {
        const count = root.results.length
        if (count === 0)
            return
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count
    }

    function activateSelected() {
        const item = root.selectedItem
        if (!item)
            return false
        return root.activeProvider.activate(item) !== false
    }

    // Apps/Favorites sekmesinde sağ tık: favoriye ekle / çıkar
    function toggleFavorite(item) {
        if (!item || !item.data || !item.data.id)
            return
        favoritesProvider.toggle(item.data.id)
    }

    onQueryChanged: {
        root.selectedIndex = 0
        for (let i = 0; i < root.providers.length; i++)
            root.providers[i].query = root.query
    }

    LauncherAppsProvider { id: appsProvider }
    LauncherFilesProvider { id: filesProvider }
    LauncherFavoritesProvider { id: favoritesProvider }
    LauncherSystemProvider { id: systemProvider }
}
