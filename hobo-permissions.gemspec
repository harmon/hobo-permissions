# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hobo-permissions}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Grant"]
  s.date = %q{2009-11-12}
  s.description = %q{Extracted out Permissions module from the Rails framework-helper, Hobo.}
  s.email = %q{adam.jgrant@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README",
     "README.rdoc"
  ]
  s.files = [
    "LICENSE",
     "README",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "hobo-permissions.gemspec",
     "lib/hobo/association_permissions.rb",
     "lib/hobo/permissions.rb",
     "lib/hobo_permissions.rb",
     "test/helper.rb",
     "test/test_gem.rb"
  ]
  s.homepage = %q{http://github.com/harmon/hobo-permissions}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Extracted out Permissions module from the Rails framework-helper, Hobo.}
  s.test_files = [
    "test/test_gem.rb",
     "test/helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

