import SwiftUI

struct FilesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Workspace files",
                systemImage: "folder.badge.gearshape",
                description: Text(
                    "The workspace browser lands in Phase 3, gated on backend file capabilities."
                )
            )
            .navigationTitle("Files")
        }
    }
}
