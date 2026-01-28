import SwiftUI

struct DottedLine: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let y = geometry.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundColor(.gray)
        }
    }
}

#Preview {
    HStack(alignment: .bottom) {
        Text("Label")
        DottedLine()
        Text("Value")
    }
    .padding()
}
