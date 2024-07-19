import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import IOKit
#endif

extension UUID {
    static func deviceUUID() -> String {
        #if os(iOS)
            return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
            if let platformExpert = Optional(IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))),
               let platformUUID = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String
            {
                IOObjectRelease(platformExpert)
                return platformUUID
            }
            return UUID().uuidString
        #else
            return UUID().uuidString
        #endif
    }
}
