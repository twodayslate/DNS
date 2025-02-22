import Foundation

// TODO: replace by sockaddr_storage

/// Undefined for LE
func htonl(_ value: UInt32) -> UInt32 {
    return value.byteSwapped
}
let ntohl = htonl

public protocol IP: CustomDebugStringConvertible {
    init?(networkBytes: Data)
    init?(_ presentation: String)
    var presentation: String { get }

    /// network-byte-order bytes
    var bytes: Data { get }
}

extension IP {
    public var debugDescription: String {
        return presentation
    }
}

// IPv4 address, wraps `in_addr`. This type is used to convert between
// human-readable presentation format and bytes in both host order and
// network order.
public struct IPv4: IP {
    /// IPv4 address in network-byte-order
    public let address: in_addr

    public init(address: in_addr) {
        self.address = address
    }

    public init?(_ presentation: String) {
        var address = in_addr()
        guard inet_pton(AF_INET, presentation, &address) == 1 else {
            return nil
        }
        self.address = address
    }

    /// network order
    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<UInt32>.size else {
            return nil
        }
        self.address = in_addr(s_addr: UInt32(bytes: bytes.reversed()))
    }

    /// host order
    public init(_ address: UInt32) {
        self.address = in_addr(s_addr: htonl(address))
    }

    /// Format this IPv4 address using common `a.b.c.d` notation.
    public var presentation: String {
        var output = Data(count: Int(INET_ADDRSTRLEN))
        var address = self.address
        #if swift(>=5.0)
        guard let presentationBytes = output.withUnsafeMutableBytes({ (rawBufferPointer: UnsafeMutableRawBufferPointer) -> UnsafePointer<Int8>? in
            let unsafeBufferPointer = rawBufferPointer.bindMemory(to: Int8.self)
            guard let base = unsafeBufferPointer.baseAddress else { return nil }
            let mutableBase = UnsafeMutablePointer(mutating: base)
            return inet_ntop(AF_INET, &address, mutableBase, socklen_t(INET_ADDRSTRLEN))
        }) else {
            return "Invalid IPv4 address"
        }
        #else
        guard let presentationBytes = output.withUnsafeMutableBytes({
            inet_ntop(AF_INET, &address, $0, socklen_t(INET_ADDRSTRLEN))
        }) else {
            return "Invalid IPv4 address"
        }
        #endif
        return String(cString: presentationBytes)
    }

    public var bytes: Data {
        return htonl(address.s_addr).bytes
    }
}

extension IPv4: Hashable {
    // MARK: Conformance to `Hashable`

    public static func == (lhs: IPv4, rhs: IPv4) -> Bool {
        return lhs.address.s_addr == rhs.address.s_addr
    }

    #if swift(>=4.2)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Int(address.s_addr))
    }
    #else
    public var hashValue: Int {
        return Int(address.s_addr)
    }
    #endif
}

extension IPv4: ExpressibleByIntegerLiteral {
    // MARK: Conformance to `ExpressibleByIntegerLiteral`
    public init(integerLiteral value: UInt32) {
        self.init(value)
    }
}

public struct IPv6: IP {
    public let address: in6_addr

    public init(address: in6_addr) {
        self.address = address
    }

    public init?(_ presentation: String) {
        var address = in6_addr()
        guard inet_pton(AF_INET6, presentation, &address) == 1 else {
            return nil
        }
        self.address = address
    }

    public init?(networkBytes bytes: Data) {
        guard bytes.count == MemoryLayout<in6_addr>.size else {
            return nil
        }
        #if swift(>=5.0)
        address = bytes.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> in6_addr? in
            return rawBufferPointer.bindMemory(to: in6_addr.self).baseAddress?.pointee
        })!
        #else
        address = bytes.withUnsafeBytes { (bytesPointer: UnsafePointer<UInt8>) -> in6_addr in
            bytesPointer.withMemoryRebound(to: in6_addr.self, capacity: 1) { $0.pointee }
        }
        #endif
    }

    /// Format this IPv6 address using common `a:b:c:d:e:f:g:h` notation.
    public var presentation: String {
        var output = Data(count: Int(INET6_ADDRSTRLEN))
        var address = self.address
        #if swift(>=5.0)
        guard let presentationBytes = output.withUnsafeMutableBytes({ (rawBufferPointer: UnsafeMutableRawBufferPointer) -> UnsafePointer<Int8>? in
            let unsafeBufferPointer = rawBufferPointer.bindMemory(to: Int8.self)
            guard let base = unsafeBufferPointer.baseAddress else { return nil }
            let mutableBase = UnsafeMutablePointer(mutating: base)
            return inet_ntop(AF_INET6, &address, mutableBase, socklen_t(INET6_ADDRSTRLEN))
        }) else {
            return "Invalid IPv6 address"
        }
        #else
        guard let presentationBytes = output.withUnsafeMutableBytes({
            inet_ntop(AF_INET6, &address, $0, socklen_t(INET6_ADDRSTRLEN))
        }) else {
            return "Invalid IPv6 address"
        }
        #endif
        return String(cString: presentationBytes)
    }

    public var bytes: Data {
        #if os(Linux)
            return
                htonl(address.__in6_u.__u6_addr32.0).bytes +
                htonl(address.__in6_u.__u6_addr32.1).bytes +
                htonl(address.__in6_u.__u6_addr32.2).bytes +
                htonl(address.__in6_u.__u6_addr32.3).bytes
        #else
            return
                htonl(address.__u6_addr.__u6_addr32.0).bytes +
                htonl(address.__u6_addr.__u6_addr32.1).bytes +
                htonl(address.__u6_addr.__u6_addr32.2).bytes +
                htonl(address.__u6_addr.__u6_addr32.3).bytes
        #endif
    }
}

extension IPv6: Hashable {
    // MARK: Conformance to `Hashable`

    public static func == (lhs: IPv6, rhs: IPv6) -> Bool {
        return lhs.presentation == rhs.presentation
    }

    #if swift(>=4.2)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(presentation)
    }
    #else
    public var hashValue: Int {
        return presentation.hashValue
    }
    #endif
}
