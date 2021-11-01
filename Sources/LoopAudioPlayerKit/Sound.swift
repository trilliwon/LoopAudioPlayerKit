import Foundation

public protocol Sound: AnyObject {
    var isPlaying: Bool { get set }
    var title: String { get }
    var id: String { get }
    var fileURL: URL? { get }
}
