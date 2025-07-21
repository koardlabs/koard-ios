Pod::Spec.new do |s|
  s.name             = 'KoardSDK'
  s.version          = '1.0.4'
  s.summary          = 'A modern Tap to Pay and merchant transaction SDK for iOS'
  s.description      = <<-DESC
    KoardSDK enables merchants to authenticate, process transactions,
    interact with card readers, and manage their payment lifecycle with
    fallback links, location context, and receipt delivery.
  DESC

  s.homepage         = 'https://www.koard.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Koard Labs' => 'support@koardlabs.com' }
  s.source           = { :git => 'https://github.com/koardlabs/koard-sdk.git', :tag => s.version.to_s }

  s.swift_version    = '5.9'
  s.ios.deployment_target = '17.0'

  s.vendored_frameworks     = 'KoardSDK.xcframework'
end
