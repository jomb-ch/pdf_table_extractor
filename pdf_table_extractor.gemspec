# frozen_string_literal: true

require_relative "lib/pdf_table_extractor/version"

Gem::Specification.new do |spec|
  spec.name = "pdf_table_extractor"
  spec.version = PdfTableExtractor::VERSION
  spec.summary = "PDF table extractor"
  spec.description = "Extracts tables from PDF text using spacing and position heuristics."
  spec.authors = ["Marko Boskovic"]
  spec.email = ["marko@jomb.ch"]
  spec.files = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.homepage = "https://github.com/jomb-ch/pdf_table_extractor"
  spec.license = "MIT"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/jomb-ch/pdf_table_extractor",
    "changelog_uri" => "https://github.com/jomb-ch/pdf_table_extractor/releases"
  }

  spec.add_dependency "pdf-reader", "~> 2.8"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.64"
  spec.add_development_dependency "standard", "~> 1.36"
  spec.add_development_dependency "yard", "~> 0.9"

  spec.required_ruby_version = ">= 3.1"
end
