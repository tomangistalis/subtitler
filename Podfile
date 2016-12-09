use_frameworks!

target 'Subtitler' do
    pod 'AlamofireXMLRPC', '2.1.0'
    pod 'GZIP', '1.1.1'
end

target 'SubtitlerTests' do

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0.1'
        end
    end
end
