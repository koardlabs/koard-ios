import SwiftUI

struct AsyncButton<Label: View>: View {
    let action: () async -> Void
    let label: () -> Label

    init(action: @escaping () async -> Void,
         @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            label()
        }
    }
}

#Preview {
    AsyncButton {
    } label: {
        Text("Async Button")
    }
}
