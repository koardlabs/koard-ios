import SwiftUI

struct KoardBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.gray.opacity(0.1),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .koardGreen.opacity(0.1),
                                .koardGreen.opacity(0.05),
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .position(x: 100, y: 150)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.gray.opacity(0.3),
                                .koardGreen.opacity(0.1),
                            ],
                            center: .center,
                            startRadius: 80,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .position(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.height / 2)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .koardGreen.opacity(0.15),
                                Color.gray.opacity(0.4),
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 45)
                    .position(x: UIScreen.main.bounds.width / 3, y: UIScreen.main.bounds.height - 100)
            }
        }
    }
}

#Preview {
    KoardBackgroundView()
}
