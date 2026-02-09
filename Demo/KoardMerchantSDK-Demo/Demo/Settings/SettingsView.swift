import SwiftUI
import KoardSDK

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Location Section
                if let location = viewModel.selectedLocation {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Location")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(location.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.address.streetLine1)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !location.address.streetLine2.isEmpty {
                                    Text(location.address.streetLine2)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(location.address.city), \(location.address.state) \(location.address.zip)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.25))
                        )
                    }
                }

                Spacer()

                // Logout Button
                Button {
                    viewModel.logout()
                } label: {
                    Text("Logout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Settings")
            .background {
                KoardBackgroundView()
                    .ignoresSafeArea()
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}

#Preview {
    SettingsView(
        viewModel: .init(
            koardMerchantService: .mockMerchantService,
            onLogout: {}
        )
    )
}
