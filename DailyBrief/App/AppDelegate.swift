import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let viewModel = DailyBriefViewModel()
    private let launchAtLoginController = LaunchAtLoginController()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        launchAtLoginController.enableByDefaultIfNeeded()
        configurePopover()
        configureStatusItem()
        configureHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.saveImmediately()
        hotKeyManager?.unregister()
    }

    func popoverDidClose(_ notification: Notification) {
        viewModel.saveImmediately()
    }

    @objc private func togglePopoverFromStatusItem() {
        togglePopover()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 560)
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarPanelView(viewModel: viewModel))
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.sunriseNote()
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopoverFromStatusItem)
        statusItem = item
    }

    private func configureHotKey() {
        let manager = HotKeyManager { [weak self] in
            DispatchQueue.main.async {
                self?.togglePopover()
            }
        }
        manager.register()
        hotKeyManager = manager
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else {
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
