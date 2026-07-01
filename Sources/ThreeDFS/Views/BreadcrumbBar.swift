import SwiftUI

struct BreadcrumbBar: View {
    @ObservedObject var navigator: FileNavigator

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(navigator.path.enumerated()), id: \.offset) { index, node in
                    Button {
                        guard index < navigator.path.count - 1 else { return }
                        let i = index
                        Task { await navigator.navigateBack(toIndex: i) }
                    } label: {
                        Text(node.name)
                            .font(.system(
                                size: 12,
                                weight: index == navigator.path.count - 1 ? .semibold : .regular
                            ))
                            .foregroundStyle(
                                index == navigator.path.count - 1
                                    ? AnyShapeStyle(.primary)
                                    : AnyShapeStyle(.secondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(index == navigator.path.count - 1)
                    .help(node.url.path)

                    if index < navigator.path.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        #if os(visionOS)
        .background(.regularMaterial, in: .rect)
        #else
        .glassEffect(.regular, in: .rect)
        #endif
    }
}

#Preview {
    BreadcrumbBar(navigator: FileNavigator())
        .frame(width: 400)
}
