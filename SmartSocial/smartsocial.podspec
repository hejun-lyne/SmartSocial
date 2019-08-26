Pod::Spec.new do |spec|
  spec.name         = 'smartsocial'
  spec.version      = '1.0.0'
  spec.license      = { :type => 'BSD' }
  spec.authors      = { 'Li Hejun' => 'lihejun@yy.com' }
  spec.summary      = 'Social services'
  spec.homepage     = 'https://github.com/hejun-lyne'
  spec.source       = { :git => 'https://github.com/hejun-lyne/SmartSocial.git' }

  spec.ios.deployment_target = '9.0'
  spec.static_framework = true
  spec.default_subspec = 'All'
  spec.public_header_files = 'SmartSocial/SSInterfaces.h'

  spec.subspec 'All' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'smartsocial/Wechat'
    ss.dependency 'smartsocial/QQ'
    ss.dependency 'smartsocial/Weibo'
    ss.dependency 'smartsocial/Google'
    ss.dependency 'smartsocial/Facebook'
    ss.dependency 'smartsocial/Twitter'
    ss.dependency 'smartsocial/Instagram'
    ss.dependency 'smartsocial/VKontakte'
    ss.dependency 'smartsocial/Twitch'
    ss.dependency 'smartsocial/WhatsApp'
    ss.dependency 'smartsocial/Line'
    ss.dependency 'smartsocial/Reddit'
  end

  spec.subspec 'Core' do |ss|
    ss.source_files = 'SmartSocial/Core/*.{h,m}','SmartSocial/Helper/*.{h,m}','SmartSocial/Platform/*.{h,m}', 'SmartSocial/SSInterfaces.h'
  end

  spec.subspec 'Wechat' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'WechatOpenSDK', '~> 1.8.0'
    ss.source_files = 'SmartSocial/Platform/Wechat/*.{h,m}'
  end

  spec.subspec 'QQ' do |ss|
    ss.dependency 'smartsocial/Core'
    # QQ has no cocoa pods, need manual add 'TencentOpenAPI.framework'
    ss.vendored_frameworks = 'SmartSocial/Platform/QQ/TencentOpenAPI.framework'
    ss.source_files = 'SmartSocial/Platform/QQ/*.{h,m}'
  end

  spec.subspec 'Weibo' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'Weibo_SDK', '~> 3.2.0'
    ss.source_files = 'SmartSocial/Platform/Weibo/*.{h,m}'
  end

  spec.subspec 'Google' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'GoogleSignIn', '~> 4.1.0'
    ss.source_files = 'SmartSocial/Platform/Google/*.{h,m}'
  end

  spec.subspec 'Facebook' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'FBSDKLoginKit', '~> 4.33.0'
    ss.dependency 'FBSDKShareKit', '~> 4.33.0'
    ss.source_files = 'SmartSocial/Platform/Facebook/*.{h,m}'
  end

  spec.subspec 'Twitter' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.source_files = 'ATHSocial/Platform/Twitter/*.{h,m}'
  end

  spec.subspec 'Instagram' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.source_files = 'SmartSocial/Platform/Instagram/*.{h,m}'
  end


  spec.subspec 'VKontakte' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'VK-ios-sdk', '~> 1.4.0'
    ss.source_files = 'SmartSocial/Platform/VK/*.{h,m}'
  end

  spec.subspec 'Twitch' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.source_files = 'SmartSocial/Platform/Twitch/*.{h,m}'
  end

  spec.subspec 'WhatsApp' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.source_files = 'SmartSocial/Platform/WhatsApp/*.{h,m}'
  end
  
  spec.subspec 'Line' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.dependency 'LineSDK', '~> 5.0.0'
    ss.source_files = 'SmartSocial/Platform/Line/*.{h,m}'
  end

  spec.subspec 'Reddit' do |ss|
    ss.dependency 'smartsocial/Core'
    ss.source_files = 'SmartSocial/Platform/Reddit/*.{h,m}'
  end
end
