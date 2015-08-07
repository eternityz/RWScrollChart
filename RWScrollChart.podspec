Pod::Spec.new do |s|

  s.name         = "RWScrollChart"
  s.version      = "1.0.0"
  s.summary      = ""

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/eternityz/RWScrollChart"

  s.license      = 'MIT'

  s.author             = { "eternityz" => "id@zhangbin.cc" }
  s.social_media_url = "http://twitter.com/eternity1st"

  s.platform     = :ios, '7.0'

  s.ios.deployment_target = '7.0'

  s.source       = { :git => "https://github.com/eternityz/RWScrollChart.git", :tag => "1.0.0" }

  s.source_files  = 'RWScrollChart', 'RWScrollChart/**/*.swift'

  s.requires_arc = true

end
