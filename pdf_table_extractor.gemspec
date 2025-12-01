Gem::Specification.new do |spec|
  spec.name          = "pdf_table_extractor"
  spec.version       = "0.1.0"
  spec.summary       = "PDF table extractor"
  spec.authors       = ["Marko Boskovic"]
  spec.email         = ["marko@jomb.ch"]
  spec.files         = Dir["lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.homepage      = "https://github.com/jomb-ch/app-backend"
  spec.license       = "MIT"

  spec.add_runtime_dependency "pdf-reader", "~> 2.8"
end
