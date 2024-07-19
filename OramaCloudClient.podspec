Pod::Spec.new do |spec|
  spec.name        = "OramaCloudClient"
  spec.module_name = "OramaCloudClient"
  spec.version      = "0.0.3"
  spec.summary      = "Orama Cloud API Client written in Swift."
  spec.homepage     = "https://github.com/askorama/oramacloud-client-swift"
  spec.license      = { :type => "Apache 2.0", :file => "LICENSE.md" }
  spec.author       = { 'Orama' => 'info@oramasearch.com'  }
  spec.documentation_url = "https://docs.orama.com/cloud"
  spec.platforms = { :ios => "16.0", :osx => "13.0" }
  spec.swift_version = "5.1"
  spec.source = { :git => 'https://github.com/askorama/oramacloud-client-swift.git', :branch => 'main' }
  spec.source_files  = "Sources/oramacloud-client/**/*.swift"
  spec.resource_bundles = { 'OramaCloudClient' => ['PrivacyInfo.xcprivacy']}
end