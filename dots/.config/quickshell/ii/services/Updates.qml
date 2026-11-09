pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Official repos are counted on Arch only (checkupdates),
 * the AUR through the configured helper, and Flatpak on any distro.
 */
Singleton {
    id: root

    property bool hasCheckupdates: false
    property bool hasFlatpak: false
    readonly property string aurHelper: hasCheckupdates ? Config.options.updates.aurHelper : ""
    readonly property bool includeFlatpak: hasFlatpak && Config.options.updates.includeFlatpak

    readonly property bool available: hasCheckupdates || includeFlatpak
    property alias checking: checkUpdatesProc.running
    property bool refreshPending: false
    property int count: 0
    
    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    // Built from the same sources as countCommand, so the count drops to 0 after updating.
    // A customized apps.update always wins: it was set on purpose and may do more than this.
    readonly property string updateCommand: {
        const customized = Config.options.apps.update !== Config.defaultUpdateCommand;
        if (customized || (!aurHelper && !includeFlatpak)) return Config.options.apps.update;
        let steps = [];
        if (hasCheckupdates) steps.push(aurHelper ? `${aurHelper} -Syu` : "sudo pacman -Syu");
        if (includeFlatpak) steps.push("flatpak update");
        steps.push("read -rsn1 -p 'Press any key to close'");
        return `${Config.options.apps.terminal} -e bash -c '${StringUtils.shellSingleQuoteEscape(steps.join("; "))}'`;
    }
    readonly property string countCommand: {
        let sources = [];
        if (hasCheckupdates) sources.push("checkupdates");
        if (aurHelper) sources.push(`${aurHelper} -Qua`);
        if (includeFlatpak) sources.push("flatpak remote-ls --updates --columns=application");
        return `{ ${sources.map(source => `${source} 2>/dev/null`).join("; ")}; } | wc -l`;
    }

    function load() {}
    function refresh() {
        if (!available) return;
        if (checking) {
            // A check that started mid-transaction would report a stale count
            refreshPending = true;
            return;
        }
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Connections {
        target: Config.options.updates
        function onAurHelperChanged() { root.refresh(); }
        function onIncludeFlatpakChanged() { root.refresh(); }
    }

    // Count again once a transaction settles, wherever it was run from: the timer
    // alone leaves the indicator stale for up to checkInterval after updating.
    // preload is off so the log is watched without being read.
    FileView {
        path: "/var/log/pacman.log"
        preload: false
        watchChanges: root.hasCheckupdates
        onFileChanged: transactionSettleTimer.restart()
    }
    FileView {
        path: "/var/lib/flatpak/.changed"
        preload: false
        watchChanges: root.includeFlatpak
        onFileChanged: transactionSettleTimer.restart()
    }
    FileView {
        path: FileUtils.trimFileProtocol(`${Directories.home}/.local/share/flatpak/.changed`)
        preload: false
        watchChanges: root.includeFlatpak
        onFileChanged: transactionSettleTimer.restart()
    }
    Timer {
        id: transactionSettleTimer
        interval: 3000
        onTriggered: root.refresh()
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Process {
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["bash", "-c", "for c in checkupdates flatpak; do command -v $c > /dev/null && echo $c; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n");
                root.hasCheckupdates = found.includes("checkupdates");
                root.hasFlatpak = found.includes("flatpak");
                root.refresh();
            }
        }
    }

    Process {
        id: checkUpdatesProc
        command: ["bash", "-c", root.countCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                root.count = parseInt(text.trim());
            }
        }
        onExited: {
            if (!root.refreshPending) return;
            root.refreshPending = false;
            root.refresh();
        }
    }
}
