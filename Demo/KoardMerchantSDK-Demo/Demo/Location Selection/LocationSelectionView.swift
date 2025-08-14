import KoardSDK
import SwiftUI

struct LocationSelectionView: View {
    @State private var viewModel: LocationSelectionViewModel

    init(viewModel: LocationSelectionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            if viewModel.showProgress {
                ProgressView()
                    .padding(.top, 44)

            } else {
                List(viewModel.locations) { location in
                    Button {
                        viewModel.locationSelected(location: location)
                    } label: {
                        Text(location.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.koardGreen)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.clear)
            }

            Spacer()
        }
        .task {
            await viewModel.fetchLocations()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KoardBackgroundView())
    }
}

#Preview {
    LocationSelectionView(
        viewModel: .init(
            koardMerchantService: .mockMerchantService,
            delegate: .init(
                onLocationSelected: { _ in
                }
            )
        )
    )
}
