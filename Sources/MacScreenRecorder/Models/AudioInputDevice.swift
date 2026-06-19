import Foundation

struct AudioInputDevice: Identifiable, Hashable {
    let id: String
    let name: String

    static let systemDefault = AudioInputDevice(id: "", name: "Systemstandard")
}
