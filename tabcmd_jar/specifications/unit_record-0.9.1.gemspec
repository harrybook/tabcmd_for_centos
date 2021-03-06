# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "unit_record"
  s.version = "0.9.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dan Manges"]
  s.autorequire = "unit_record"
  s.date = "2009-04-21"
  s.description = "UnitRecord enables unit testing without hitting the database."
  s.email = "daniel.manges@gmail.com"
  s.files = ["lib/active_record/connection_adapters/unit_record_adapter.rb", "lib/unit_record.rb", "lib/unit_record/disconnected_active_record.rb", "lib/unit_record/disconnected_test_case.rb", "lib/unit_record/column_extension.rb", "lib/unit_record/disconnected_fixtures.rb", "lib/unit_record/association_stubbing.rb", "test/test_helper.rb", "test/active_record/connection_adapters/unit_record_adapter_test.rb", "test/db/schema.rb", "test/sample_spec.rb", "test/unit_record/disconnected_test_case_test.rb", "test/unit_record/column_test.rb", "test/unit_record/column_cacher_test.rb", "test/unit_record/unit_record_test.rb", "test/unit_record/disconnected_active_record_test.rb", "test/unit_record/association_stubbing_test.rb", "test/unit_record/controller_test.rb", "test/unit_record/column_extension_test.rb", "test/unit_record/disconnected_fixtures_test.rb", "vendor/dust-0.1.6/rakefile.rb", "vendor/dust-0.1.6/test/test_helper.rb", "vendor/dust-0.1.6/test/passing_unit_test.rb", "vendor/dust-0.1.6/test/failing_with_helper_unit_test.rb", "vendor/dust-0.1.6/test/failing_with_setup_unit_test.rb", "vendor/dust-0.1.6/test/passing_with_setup_unit_test.rb", "vendor/dust-0.1.6/test/all_tests.rb", "vendor/dust-0.1.6/test/passing_with_helpers_unit_test.rb", "vendor/dust-0.1.6/test/passing_with_helper_unit_test.rb", "vendor/dust-0.1.6/test/functional_test.rb", "vendor/dust-0.1.6/lib/dust.rb", "vendor/dust-0.1.6/lib/definition_error.rb", "vendor/dust-0.1.6/lib/object_extension.rb", "vendor/dust-0.1.6/lib/string_extension.rb", "vendor/dust-0.1.6/lib/array_extension.rb", "vendor/dust-0.1.6/lib/symbol_extension.rb", "vendor/dust-0.1.6/lib/test_case_extension.rb", "vendor/dust-0.1.6/lib/nil_extension.rb", "CHANGELOG", "LICENSE", "README.markdown", "Rakefile"]
  s.homepage = "http://unit-test-ar.rubyforge.org"
  s.require_paths = ["lib"]
  s.rubyforge_project = "unit-test-ar"
  s.rubygems_version = "1.8.15"
  s.summary = "UnitRecord enables unit testing without hitting the database."

  if s.respond_to? :specification_version then
    s.specification_version = 2

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
