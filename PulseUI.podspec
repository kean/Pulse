Pod::Spec.new do |s|

s.name          = "PulseLoggerUI"
s.version       = "2.1.3"
s.summary       = "Pulse is a powerful logging system for Apple Platforms. Native. Built with SwiftUI."
s.swift_version = "5.6"

s.description  = <<-DESC
Pulse is a powerful logging system for Apple Platforms. Native. Built with SwiftUI.
DESC

s.homepage     = "https://github.com/kean/Pulse"
s.license      = "MIT"
s.author       = { "kean" => "https://github.com/kean" }
s.authors      = { "kean" => "https://github.com/kean" }
s.source       = { :git => "git@github.com:kean/Pulse.git", :tag => "#{s.version}" }
s.social_media_url = "https://kean.blog/"

s.ios.deployment_target = "13.0"
s.tvos.deployment_target = "13.0"
s.macos.deployment_target = "11.0"
s.watchos.deployment_target = "7.0"

s.source_files = "Sources/PulseUI/**/*.swift"

s.dependency "Pulse"
end
