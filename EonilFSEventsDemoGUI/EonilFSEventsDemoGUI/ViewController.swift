//
//  ViewController.swift
//  EonilFSEventsDemoGUI
//
//  Created by Henry on 2018/12/27.
//

import Cocoa
import EonilFSEvents

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  private var items = [EonilFSEventsEvent]()
  private func process(fileSystemEvent e: EonilFSEventsEvent) {
    guard let v = tableView else { return }
    self.items.append(e)
    let a = v.numberOfRows
    let b = self.items.count
    let c = a..<b
    let idxs = IndexSet(integersIn: c)
    v.insertRows(at: idxs, withAnimation: [])
    v.scrollRowToVisible(self.items.count - 1)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    try? EonilFSEvents.startWatching(
      paths: [NSHomeDirectory()],
      for: ObjectIdentifier(self),
      with: { [weak self] e in self?.process(fileSystemEvent: e) }
    )
  }

  override func viewDidDisappear() {
    EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
  }

  deinit {
    EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
  }

  ////

  @IBOutlet var tableView: NSTableView?
  @IBOutlet var nameTableColumn: NSTableColumn?
  @IBOutlet var actionsTableColumn: NSTableColumn?

  func numberOfRows(in _: NSTableView) -> Int {
    self.items.count
  }

  func tableView(
    _ tableView: NSTableView,
    viewFor tableColumn: NSTableColumn?,
    row: Int
  ) -> NSView? {
    guard let c = tableColumn else { return nil }
    let v = tableView.makeView(withIdentifier: c.identifier, owner: self) as! NSTableCellView
    let item = self.items[row]
    v.identifier = c.identifier
    switch c.identifier {
    case self.nameTableColumn?.identifier:
      v.imageView?.image = NSWorkspace.shared.icon(forFile: item.path)
      v.textField?.stringValue = item.path
    case self.actionsTableColumn?.identifier:
      v.textField?.stringValue = item.flag?.description ?? ""
    default:
      break
    }
    return v
  }
//    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int)
//    -> Any? {
//        guard let tableColumn = tableColumn else { return nil }
//        let item = items[row]
//        switch tableColumn.identifier {
//        case nameTableColumn?.identifier:       return item.path
//        case actionsTableColumn?.identifier:    return item.flag
//        default:                                return nil
//        }
//    }
}

// extension EonilFSEventsEventFlags {
//    var description: String {
//        let all = [
//            .historyDone:           ".historyDone",
//            .idsWrapped:            ".idsWrapped",
//            .itemChangeOwner:       ".itemChangeOwner",
//            .itemCreated:           ".itemCreated",
//            .itemFinderInfoMod:     ".itemFinderInfoMod",
//            .itemInodeMetaMod:      ".itemInodeMetaMod",
//            .itemIsDir:             ".itemIsDir",
//            .itemIsFile:            ".itemIsFile",
//            .itemIsHardlink:        ".itemIsHardlink",
//            .itemIsLastHardlink:    ".itemIsLastHardlink",
//            .itemIsSymlink:         ".itemIsSymlink",
//            .itemModified:          ".itemModified",
//            .itemRemoved:           ".itemRemoved",
//            .itemRenamed:           ".itemRenamed",
//            .itemXattrMod:          ".itemXattrMod",
//            .kernelDropped:         ".kernelDropped",
//            .mount:                 ".mount",
//            .mustScanSubDirs:       ".mustScanSubDirs",
//            .none:                  ".none",
//            .ownEvent:              ".ownEvent",
//            .rootChanged:           ".rootChanged",
//            .unmount:               ".unmount",
//            .userDropped:           ".userDropped",
//            ] as [EonilFSEventsEventFlags: String]
//        var s = [String]()
//        for (k,n) in all {
//            if contains(k) {
//                s.append(n)
//            }
//        }
//        return s.joined(separator: ", ")
//    }
// }
