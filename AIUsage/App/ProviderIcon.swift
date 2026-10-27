import SwiftUI

struct ProviderIcon: View {
    let name: String
    var side: CGFloat = 16

    var body: some View {
        Group {
            switch name {
            case "Cursor":
                Image("CursorAppIcon")
                    .resizable()
                    .scaledToFit()
            case "Claude":
                Image(systemName: "sparkles")
                    .font(.system(size: side * 0.78, weight: .medium))
            default:
                Image("CodexAppIcon")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: side, height: side)
    }
}
