import SwiftUI
import HermesKit

struct ChatView: View {
    @Environment(ChatModel.self) private var model

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                transcript
                QueueChipsView()
                StatusCapsuleView()
                ComposerView(model: model)
            }
            .padding(.horizontal, 10)
            .navigationTitle("⚕ hermes-agent")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    BannerCard()
                    ForEach(model.store.transcript) { row in
                        TranscriptRowView(row: row)
                            .id(row.id)
                    }
                    if let streaming = model.store.streamingText {
                        StreamingBlock(text: streaming)
                    }
                    ForEach(model.store.tools.filter { $0.isRunning }) { tool in
                        ToolCard(tool: tool)
                    }
                    Color.clear.frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: model.store.transcript.count) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}
