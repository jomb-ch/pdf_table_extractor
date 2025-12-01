# PDF Table Extractor

A Ruby gem for extracting tables from PDF files by analyzing text spacing and positions. It parses PDF pages, removes headers/footers and pagination if configured, splits lines into cells based on multiple-space runs, and merges rows into table-like structures.

- Source: https://github.com/jomb-ch/pdf_table_extractor
- License: MIT

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pdf_table_extractor'
```

Then install:

```bash
bundle install
```

Or install it yourself:

```bash
gem install pdf_table_extractor
```

## Usage

### Basic usage

```ruby
require 'pdf_table_extractor'

# Initialize with a PDF file path
extractor = PdfTableExtractor.new('path/to/file.pdf')

# Extract tables
extractor.extract_tables

# Get results: array of rows, each row is an array of cells
rows = extractor.result
# rows => [[{ text: 'Cell 1', position: 0 }, { text: 'Cell 2', position: 20 }], ...]
```

### Advanced usage with options

```ruby
extractor = PdfTableExtractor.new('path/to/file.pdf', options: {
  remove_page_headers: true,          # Remove common leading lines across pages (default: true)
  remove_page_footers: true,          # Remove common trailing lines across pages (default: true)
  remove_pagination_from_header: false, # true or Integer (line number from top) to remove pagination; if true, tests first 5 lines (default: false)
  remove_pagination_from_footer: false, # true or Integer (line number from bottom) to remove pagination; if true, tests last 5 lines (default: false)
  remove_empty_lines: true,           # Filter out empty lines (default: true)
  position_tolerance: 2               # Tolerance for matching column positions, allowing indentation within columns (default: 2)
})

extractor.extract_tables
rows = extractor.result
```

### Using with PDF::Reader

```ruby
require 'pdf-reader'
require 'pdf_table_extractor'

reader = PDF::Reader.new('path/to/file.pdf')
extractor = PdfTableExtractor.new(reader: reader)
extractor.extract_tables
rows = extractor.result
```

## How it works

The gem uses several heuristics to identify table-like structures:

- Text Positioning: splits lines into cells using multiple spaces as separators and tracks each cell's starting position
- Row Congruence: considers rows to belong to the same table if their cell positions match (or are a subset) within a given tolerance
- Header/Footer Removal: optionally removes common leading/trailing lines across pages
- Pagination Handling: optionally removes page numbers from headers/footers

### Constraints

- Single-row tables are joined into a single cell before further processing
- The first row of a table cannot have empty cells
- Multi-cell rows followed by rows with fewer cells (but matching positions) are considered part of the same table
- Trailing rows of multi-cell tables with content only in the first cell are treated as new single-cell tables if the content length is larger than the position of the second column minus 2

## Development

Set up the project:

```bash
bundle install
```

Run tests:

```bash
bundle exec rspec
```

Run linters:

```bash
bundle exec standardrb
bundle exec rubocop --parallel
```

Generate API docs (YARD):

```bash
bundle exec yard doc
open doc/index.html
```

Release a new version:

1. Update the version number in `lib/pdf_table_extractor/version.rb`
2. Build and release:

```bash
bundle exec rake release
```

## CI

GitHub Actions workflow runs StandardRB, RuboCop, RSpec, and generates YARD docs on pushes and pull requests. Docs are uploaded as an artifact.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jomb-ch/pdf_table_extractor

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
