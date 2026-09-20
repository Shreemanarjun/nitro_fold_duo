#!/usr/bin/env ruby
# Wires the iOS UI-test target Patrol needs into example/ios/Runner.xcodeproj.
#
# Patrol documents a CocoaPods setup; this example uses Swift Package Manager,
# so the RunnerUITests target links Patrol's own SwiftPM package directly. The
# package is resolved from the pub cache rather than from
# Flutter/ephemeral/Packages, which Xcode has not generated yet at the point it
# resolves package dependencies.
#
# Idempotent: run it after `flutter pub get`, or whenever Patrol's version
# changes.
#
#   ruby tool/setup_patrol_ios.rb

require 'json'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT = File.join(ROOT, 'ios', 'Runner.xcodeproj')
APP_TARGET = 'Runner'
UI_TARGET = 'RunnerUITests'
BUNDLE_ID = 'dev.shreeman.nitroFoldDuoExample'

def patrol_package_path
  config = JSON.parse(File.read(File.join(ROOT, '.dart_tool', 'package_config.json')))
  entry = config['packages'].find { |p| p['name'] == 'patrol' }
  abort 'patrol is not in package_config.json — run `flutter pub get` first' unless entry
  root = entry['rootUri'].sub('file://', '')
  root = File.expand_path(root, File.join(ROOT, '.dart_tool')) unless root.start_with?('/')
  path = File.join(root, 'darwin', 'patrol')
  abort "patrol SwiftPM package not found at #{path}" unless Dir.exist?(path)
  path
end

def runner_source
  <<~OBJC
    @import XCTest;
    @import patrol;
    @import ObjectiveC.runtime;

    PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
  OBJC
end

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == APP_TARGET }
abort "no #{APP_TARGET} target" unless app

source_dir = File.join(ROOT, 'ios', UI_TARGET)
Dir.mkdir(source_dir) unless Dir.exist?(source_dir)
File.write(File.join(source_dir, 'RunnerUITests.m'), runner_source)

target = project.targets.find { |t| t.name == UI_TARGET }
unless target
  target = project.new_target(:ui_test_bundle, UI_TARGET, :ios, '13.0', nil, :objc)
  group = project.main_group.find_subpath(UI_TARGET, true)
  group.set_source_tree('<group>')
  group.set_path(UI_TARGET)
  target.source_build_phase.add_file_reference(group.new_reference('RunnerUITests.m'))
  target.add_dependency(app)
  puts "created #{UI_TARGET}"
end

target.build_configurations.each do |config|
  config.build_settings.merge!(
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{BUNDLE_ID}.#{UI_TARGET}",
    'TEST_TARGET_NAME' => APP_TARGET,
    'IPHONEOS_DEPLOYMENT_TARGET' => '13.0',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'CODE_SIGN_STYLE' => 'Automatic'
  )
end

# Patrol already enters the package graph through Flutter's generated plugin
# package, so the UI-test target takes the product from there. Adding a second
# reference to the same sources makes SwiftPM refuse the graph as duplicated.
package_path = patrol_package_path
project.root_object.package_references.dup.each do |ref|
  next unless ref.is_a?(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  next unless ref.relative_path.to_s.include?('patrol')
  project.root_object.package_references.delete(ref)
end

unless target.package_product_dependencies.any? { |d| d.product_name == 'patrol' }
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = 'patrol'
  target.package_product_dependencies << dependency
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

project.save

# The scheme must run the UI tests, or xcodebuild reports zero tests.
scheme_path = File.join(PROJECT, 'xcshareddata', 'xcschemes', 'Runner.xcscheme')
scheme = File.read(scheme_path)
unless scheme.include?("#{UI_TARGET}.xctest")
  testable = <<~XML.chomp
           <TestableReference
              skipped = "NO"
              parallelizable = "YES">
              <BuildableReference
                 BuildableIdentifier = "primary"
                 BlueprintIdentifier = "#{target.uuid}"
                 BuildableName = "#{UI_TARGET}.xctest"
                 BlueprintName = "#{UI_TARGET}"
                 ReferencedContainer = "container:Runner.xcodeproj">
              </BuildableReference>
           </TestableReference>
  XML
  scheme = scheme.sub("      </Testables>", "#{testable}\n      </Testables>")
  File.write(scheme_path, scheme)
  puts 'added RunnerUITests to the Runner scheme'
end

puts "patrol package found at #{package_path}"
