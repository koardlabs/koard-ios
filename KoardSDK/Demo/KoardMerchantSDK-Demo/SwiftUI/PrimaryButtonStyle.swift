import SwiftUI

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle {
        PrimaryButtonStyle()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ContentView(configuration: configuration)
    }

    private struct ContentView: View {
        @Environment(\.isEnabled) private var isEnabled: Bool
        private let configuration: Configuration

        private var backgroundColor: Color {
            switch (isEnabled, configuration.isPressed) {
            case (false, _):
                return .koardGreen.opacity(0.2)
            case (true, false):
                return .koardGreen
            case (true, true):
                return .koardGreen.opacity(0.7)
            }
        }

        private var foregroundColor: Color {
            .white
        }

        fileprivate init(configuration: PrimaryButtonStyle.Configuration) {
            self.configuration = configuration
        }

        fileprivate var body: some View {
            configuration
                .label
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .clipShape(Capsule())
                .shadow(
                    color: .black.opacity(configuration.isPressed ? 0.1 : 0.2),
                    radius: 10,
                    x: 0,
                    y: 5
                )
        }
    }
}

#Preview("Default State") {
    Button {
    } label: {
        Text("Primary Button")
    }
    .buttonStyle(.primary)
}


#Preview("Disabled State") {
    Button {
    } label: {
        Text("Primary Button")
    }
    .buttonStyle(.primary)
    .disabled(true)
}
