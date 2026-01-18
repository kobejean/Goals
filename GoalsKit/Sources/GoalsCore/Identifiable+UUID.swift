import Foundation

/// A protocol for entities that have a UUID identifier
public protocol UUIDIdentifiable: Identifiable where ID == UUID {
    var id: UUID { get }
}
