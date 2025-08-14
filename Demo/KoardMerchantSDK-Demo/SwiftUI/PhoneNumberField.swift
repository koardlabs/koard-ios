import PhoneNumberKit
import SwiftUI
import UIKit

public struct PhoneNumberField: UIViewRepresentable {
    private var phoneNumber: Binding<String>
    private let textField = PhoneNumberTextField()
    private let placeholder: String
    private let font: UIFont

    public init(
        phoneNumber: Binding<String>,
        placeholder: String = "Phone Number",
        font: UIFont = .systemFont(ofSize: 12)
    ) {
        self.phoneNumber = phoneNumber
        self.placeholder = placeholder
        self.font = font
    }

    public func makeUIView(context: Context) -> PhoneNumberTextField {
        textField.withFlag = false
        textField.withPrefix = true
        textField.withDefaultPickerUI = false
        textField.textContentType = .telephoneNumber
        textField.placeholder = placeholder
        textField.font = font
        textField.textColor = .koardGreen
        textField.addTarget(context.coordinator, action: #selector(Coordinator.onTextUpdate), for: .editingChanged)
        PhoneNumberKit.CountryCodePicker.forceModalPresentation = true
        return textField
    }

    public func updateUIView(_ textField: PhoneNumberTextField, context: Context) {
        textField.text = phoneNumber.wrappedValue
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UITextFieldDelegate {
        var control: PhoneNumberField

        init(_ control: PhoneNumberField) {
            self.control = control
        }

        @objc func onTextUpdate(textField: UITextField) {
            control.phoneNumber.wrappedValue = textField.text!
        }
    }
}
