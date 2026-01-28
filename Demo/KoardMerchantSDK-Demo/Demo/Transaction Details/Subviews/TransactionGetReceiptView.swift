import KoardSDK
import PhoneNumberKit
import SwiftUI

struct TransactionGetReceiptView: View {
    @State private var viewModel: TransactionDetailsViewModel
    @Namespace private var animation
    @State private var inputText: String = ""
    @State private var selectedRegion = PhoneNumberUtility.Region(regionCode: "US")
    @State private var shouldShowCountryPickerSheet: Bool = false
    @State private var regionSearchQuery: String = ""
    @State var selectedCountry: String?

    private var allRegions: [PhoneNumberUtility.Region] {
        guard !regionSearchQuery.isEmpty else { return PhoneNumberUtility.allRegions }
        let query = regionSearchQuery.uppercased().filter { !$0.isWhitespace }
        return PhoneNumberUtility.allRegions.filter { region in
            region.countryName.uppercased().filter { !$0.isWhitespace }.contains(query)
        }
    }

    init(viewModel: TransactionDetailsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Text("Would you like to get a receipt?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.koardDarkGray)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer().frame(maxHeight: 16)

            switch viewModel.receiptContent {
            case .selection:
                VStack(spacing: 12) {
                    TransactionGetReceiptSelectionButton(
                        buttonTitle: "Send Email",
                        buttonImage: "envelope"
                    ) {
                        viewModel.receiptContent = .email
                    }
                    .matchedGeometryEffect(id: "EmailButton", in: animation)

                    TransactionGetReceiptSelectionButton(
                        buttonTitle: "Send SMS",
                        buttonImage: "message"
                    ) {
                        viewModel.receiptContent = .phoneNumber
                    }
                    .matchedGeometryEffect(id: "SMSButton", in: animation)
                }
            case .email:
                TransactionGetReceiptEmailInputView(
                    inputText: $inputText,
                    isLoading: $viewModel.isLoading,
                    actionSend: { email in
                        viewModel.sendReceipt(email: email)
                        inputText = ""
                    },
                    actionCancel: {
                        inputText = ""
                        viewModel.receiptContent = .selection
                    },
                    validation: { emailString in
                        emailString.isValidEmail
                    }
                )
                .matchedGeometryEffect(id: "EmailButton", in: animation)

                Button {
                    viewModel.receiptContent = .selection
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.koardGreen)
                }
                .padding(.vertical, 16)
            case .phoneNumber:
                TransactionGetReceiptSMSInputView(
                    inputText: $inputText,
                    selectedRegion: $selectedRegion,
                    isLoading: $viewModel.isLoading,
                    shouldShowCountryPickerSheet: $shouldShowCountryPickerSheet,
                    actionSend: { phoneNumber in
                        let fullPhone = "+\(selectedRegion.countryCode)" + phoneNumber
                        viewModel.sendReceipt(phoneNumber: fullPhone)
                        inputText = ""
                    },
                    actionCancel: {
                        inputText = ""
                        viewModel.receiptContent = .selection
                    },
                    validation: { phoneString in
                        phoneString.isPhoneNumber()
                    }
                )
                .matchedGeometryEffect(id: "SMSButton", in: animation)

                Button {
                    viewModel.receiptContent = .selection
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.koardGreen)
                }
                .padding(.vertical, 16)
            case .sending:
                TransactionReceiptLoadingView()
            case .sentSuccessfully:
                TransactionReceiptStatusView(isSuccess: true, message: viewModel.responseMessage)
            case .sentError:
                TransactionReceiptStatusView(isSuccess: false, message: viewModel.responseMessage)
            }
        }
        .fullScreenCover(isPresented: $shouldShowCountryPickerSheet) {
            VStack {
                HStack {
                    Spacer()

                    Button {
                        shouldShowCountryPickerSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.primary)
                    }
                }

                HStack(alignment: .center, spacing: 0) {
                    TextField("Search", text: $regionSearchQuery)
                        .padding(.vertical, 20)
                        .padding(.leading, 16)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if !regionSearchQuery.isEmpty {
                        Button {
                            regionSearchQuery = ""
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 16)
                    }
                }
                .padding(.horizontal, 16)
                .animation(.default, value: regionSearchQuery.isEmpty)

                if !regionSearchQuery.isEmpty,
                   allRegions.isEmpty {
                    Text("No Results for \"\(regionSearchQuery).\"")
                        .padding(.top, 16)
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }

                List {
                    ForEach(Array(allRegions), id: \.self) { region in
                        HStack {
                            HStack {
                                Text(region.flagUnicode)

                                Text("+\(region.countryCode)")
                                    .foregroundStyle(.gray)

                                Spacer()
                            }
                            .frame(width: 90)

                            Text(region.countryName)
                                .font(.system(size: 16))
                        }
                        .padding(.vertical, 8)
                        .onTapGesture {
                            selectedRegion = region
                            inputText = ""
                            shouldShowCountryPickerSheet = false
                        }
                    }
                    .listRowSeparator(.hidden, edges: .all)
                }
                .listStyle(.plain)
            }
            .padding(8)
        }
        .animation(.default, value: viewModel.receiptContent)
    }
}

struct TransactionGetReceiptSMSInputView: View {
    @Binding var inputText: String
    @Binding var selectedRegion: PhoneNumberUtility.Region
    @Binding var isLoading: Bool
    @Binding var shouldShowCountryPickerSheet: Bool
    @FocusState private var isTextFieldFocused: Bool

    let actionSend: (String) -> Void
    let actionCancel: () -> Void
    let validation: (String) -> Bool
    @State var isValueValid = false

    var body: some View {
        HStack {
            Button(action: actionCancel) {
                Image(systemName: "message")
                    .foregroundStyle(Color.koardGreen)
            }

            HStack(spacing: 2) {
                Text(selectedRegion.flagUnicode)
                Text("+\(selectedRegion.countryCode)")
                    .font(.system(size: 14))
            }
            .padding(.trailing, 8)
            .frame(height: 34)
            .onTapGesture {
                isTextFieldFocused = false
                shouldShowCountryPickerSheet = true
            }

            PhoneNumberField(
                phoneNumber: $inputText
            )
            .frame(height: 34)
            .onChange(of: inputText) {
                isValueValid = validation(inputText)
            }

            Button {
                if isValueValid && !isLoading {
                    actionSend(inputText)
                }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

            } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane")
                        .foregroundStyle(isValueValid ? .white : .koardDarkGray)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .background((isValueValid && !isLoading) ? .koardGreen : .koardLightGray)
            .disabled(isLoading)
        }
        .padding(.leading)
        .background(.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke().foregroundStyle(isTextFieldFocused ? .koardGreen : .extraLightGray))
    }
}

struct TransactionGetReceiptEmailInputView: View {
    @Binding var inputText: String
    @Binding var isLoading: Bool
    @FocusState private var isTextFieldFocused: Bool
    let actionSend: (String) -> Void
    let actionCancel: () -> Void
    let validation: (String) -> Bool
    @State var isValueValid = false

    var body: some View {
        HStack {
            Button(action: actionCancel) {
                Image(systemName: "envelope")
                    .foregroundStyle(.koardGreen)
            }

            TextField(LocalizedStringKey("Enter Email"), text: $inputText)
                .keyboardType(.emailAddress)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .focused($isTextFieldFocused)
                .onChange(of: inputText) {
                    isValueValid = validation(inputText)
                }
            Button {
                if isValueValid && !isLoading {
                    actionSend(inputText)
                }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

            } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane")
                        .foregroundStyle(isValueValid ? .white : .koardDarkGray)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .background((isValueValid && !isLoading) ? .koardGreen : .koardLightGray)
            .disabled(isLoading)
        }
        .padding(.leading)
        .background(.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke().foregroundStyle(isTextFieldFocused ? .koardGreen : .extraLightGray))
    }
}

struct TransactionGetReceiptSelectionButton: View {
    let buttonTitle: String
    let buttonImage: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: buttonImage)
                Text(buttonTitle)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.koardGreen)
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .inset(by: 0.5)
                .stroke(.koardGreen, lineWidth: 1)
        )
    }
}

struct TransactionReceiptLoadingView: View {
    var body: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .koardGreen))
                .scaleEffect(0.8)
            Text("Sending receipt...")
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.koardGreen)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: 44)
        .background(.extraLightGray)
        .cornerRadius(8)
    }
}

struct TransactionReceiptStatusView: View {
    let isSuccess: Bool
    let message: String

    var body: some View {
        HStack {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isSuccess ? .koardGreen : .red)
            Text(message)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSuccess ? .koardGreen : .red)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: 44)
        .background(isSuccess ? .koardGreen.opacity(0.2) : .extraLightGray)
        .cornerRadius(8)
    }
}

#Preview {
    TransactionGetReceiptView(
        viewModel: .init(
            koardMerchantService: .mockMerchantService,
            transaction: .mockApprovedTransaction,
            delegate: .init(
                onTransactionUpdate: {}
            )
        )
    )
    .padding()
}
