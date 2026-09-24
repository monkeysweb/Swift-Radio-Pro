#!/usr/bin/env ruby
# One-time generator for PirateCat.xcodeproj. Re-run after adding/removing
# source files (git-tracked source files + this script are the source of
# truth; the .xcodeproj is a generated artifact you can safely regenerate).
require 'xcodeproj'

root = File.dirname(__FILE__)
proj_path = File.join(root, 'PirateCat.xcodeproj')
project = Xcodeproj::Project.new(proj_path)

target = project.new_target(:application, 'PirateCat', :ios, '16.0')

group = project.main_group.new_group('PirateCat')
group.path = nil
src_dir = File.join(root, 'PirateCat')

swift_files = Dir.glob(File.join(src_dir, '*.swift')).sort
file_refs = swift_files.map { |path| group.new_reference(path) }
target.add_file_references(file_refs)

assets_ref = group.new_reference(File.join(src_dir, 'Assets.xcassets'))
target.add_resources([assets_ref])

info_plist_ref = group.new_reference(File.join(src_dir, 'Info.plist'))
entitlements_ref = group.new_reference(File.join(src_dir, 'PirateCat.entitlements'))

target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'PirateCat/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'PirateCat/PirateCat.entitlements'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'org.kpcr.piratecat'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1' # iPhone only, matches the MVP scope
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['DEVELOPMENT_TEAM'] = '' # fill in with your Apple Developer Team ID
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
end

project.save

puts "Generated #{proj_path}"
puts "Files: #{swift_files.map { |f| File.basename(f) }.join(', ')}"
