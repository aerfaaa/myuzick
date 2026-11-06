import SwiftUI

struct RootView: View {
    var body: some View {
        LibraryView()
            .preferredColorScheme(.dark)
            .environment(\.font, AppFont.font(size: 17))
    }
}
