import CoreGraphics

enum StoreTarget: String, CaseIterable {
    case iphone
    case ipad
    case androidPhone = "android-phone"
    case androidTablet = "android-tablet"

    var canvas: CGSize {
        switch self {
        case .iphone: CGSize(width: 1320, height: 2868)
        case .ipad: CGSize(width: 2064, height: 2752)
        case .androidPhone: CGSize(width: 1440, height: 2560)
        case .androidTablet: CGSize(width: 1440, height: 2560)
        }
    }

    var device: DeviceKind {
        switch self {
        case .iphone: .iPhone
        case .ipad: .iPad
        case .androidPhone: .pixelPhone
        case .androidTablet: .pixelTablet
        }
    }

    var platformName: String {
        switch self {
        case .iphone: "iPhone"
        case .ipad: "iPad"
        case .androidPhone, .androidTablet: "Android"
        }
    }
}
