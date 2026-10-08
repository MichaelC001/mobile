import SwiftUI

enum Brand {
    static let background = Color(red: 0.043, green: 0.039, blue: 0.063)
    static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let blue = Color(red: 0.310, green: 0.549, blue: 0.941)
    static let violet = Color(red: 0.757, green: 0.478, blue: 0.859)
    static let pink = Color(red: 0.925, green: 0.282, blue: 0.600)
    static let text = Color.white
    static let muted = Color(red: 0.663, green: 0.639, blue: 0.741)
    static let gradient = LinearGradient(colors: [cyan, blue, violet, pink], startPoint: .leading, endPoint: .trailing)
    static let glow = LinearGradient(colors: [cyan, violet, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
}
