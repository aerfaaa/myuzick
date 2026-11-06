import SwiftUI

struct RootView: View {
    var body: some View {
        LibraryView()
            .preferredColorScheme(.dark)\n            .environment(\.font, AppFont.font(size: 17))
    }
}
