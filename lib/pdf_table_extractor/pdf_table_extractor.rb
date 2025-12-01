# frozen_string_literal: true

require "pdf-reader"

  class PdfTableExtractor
    attr_reader :rows, :merged_rows, :options
    # CONSTRAINTS:
    # 1. No single row tables: such candidates are joined into single cell before further processing.
    # 2. First row of a table can not have empty cells.
    # 3. If a multi cell row is followed by a row with fewer cells but with cell positions that are a subset of the previous row's cell positions,
    # they are considered part of the same table. This can lead to incorrect identification.
    # Example: row1 structure: [{position: p1}, {position: p2}, {position: p3}], row2 structure: [{position: p1}, {position: p2}]
    # Row 2 is shown in the pdf as a start of a new table but will be considered part of the same table as row 1.
    # 4. Trailing rows of a multi cell table that have content only for the first cell will be treated as new single cell tables.

    # Options:
    # :remove_page_headers - whether to remove common leading lines across pages (default: true)
    # :remove_page_footers - whether to remove common trailing lines across pages (default: true)
    # :remove_pagination_from_header - whether to remove page numbers from headers/footers (default: false). If the value is Integer, it represents number of the line from top to be removed; if the value is boolean, first 5 lines are tested.
    # :remove_pagination_from_footer - whether to remove page numbers from headers/footers (default: false). If the value is Integer, it represents number of the line from bottom to be removed; if the value is boolean, last 5 lines are tested.
    # :remove_empty_lines - whether to remove empty lines from the extracted
    def initialize(pdf_path = nil, reader: nil, options: {})
      @reader = reader || PDF::Reader.new(pdf_path)
      @options = options
      @options[:remove_page_headers] = true unless @options.key?(:remove_page_headers)
      @options[:remove_page_footers] = true unless @options.key?(:remove_page_footers)
      @options[:remove_pagination_from_header] = false unless @options.key?(:remove_pagination_from_header)
      @options[:remove_pagination_from_footer] = false unless @options.key?(:remove_pagination_from_footer)
      @options[:remove_empty_lines] = true unless @options.key?(:remove_empty_lines)
      @options[:position_tolerance] = 2 unless @options.key?(:position_tolerance)
      @merged_rows = []
    end

    # Extracts tables from the PDF and stores them in @merged_rows
    def extract_tables
      pages = all_pages

      pages = remove_pagination(pages) if @options[:remove_pagination_from_header] || @options[:remove_pagination_from_footer]

      pages = remove_common_leading_lines(pages) if @options[:remove_page_headers]
      pages = remove_common_trailing_lines(pages) if @options[:remove_page_footers]

      lines = pages&.flatten
      lines = lines&.reject { |l| l.strip.empty? } if @options[:remove_empty_lines]

      @rows = lines&.map&.with_index do |line, index|
        cells, positions = parse_line_to_cells(line)
        PdfTableExtractorRow.new(self, cells, positions, index)
      end
      process_rows
    end

    def result
      @merged_rows.map(&:cells)
    end

    private

    def all_pages
      all_pages_texts.map { |page_text| page_text.lines.map(&:chomp) }
    end

    def all_pages_texts
      @reader.pages.map { |page| page.text }
    end

    def remove_pagination(pages)
      return pages if pages.empty? || pages.length == 1

      if @options[:remove_pagination_from_header]
        if @options[:remove_pagination_from_header].is_a?(Integer)
          index = @options[:remove_pagination_from_header] - 1
          pages.each do |lines|
            if lines.length > index && is_pagination?(lines[index])
              lines.delete_at(index)
            end
          end
        else
          [1..5].each do |index|
            if pages.all? { |lines| lines.length > index && is_pagination?(lines[index - 1]) }
              pages.each { |lines| lines.delete_at(index - 1) }
              break
            end
          end
        end
      end

      if @options[:remove_pagination_from_footer]
        if @options[:remove_pagination_from_footer].is_a?(Integer)
          index = @options[:remove_pagination_from_footer]
          pages.each do |lines|
            if lines.length > index && is_pagination?(lines[-index])
              lines.delete_at(-index)
            end
          end
        else
          [1..5].each do |index|
            if pages.all? { |lines| lines.length > index && is_pagination?(lines[-index]) }
              pages.each { |lines| lines.delete_at(-index) }
              break
            end
          end
        end
      end
      pages
    end

    def remove_common_leading_lines(pages)
      return pages if pages.empty? || pages.length == 1
      pages.each(&:shift) while same_leading_line?(pages)
      pages
    end

    def remove_common_trailing_lines(pages)
      return pages if pages.empty? || pages.length == 1
      pages.each(&:pop) while same_trailing_line?(pages)
      pages
    end

    def parse_line_to_cells(line)
      if has_consecutive_spaces?(line)
        cells = []
        position = 0
        positions = []

        line.split(/(\s{2,})/).each do |text|
          if has_consecutive_spaces?(text)
            position += text.length
          elsif !text.empty?
            cells << {text:, position:}
            positions << position
            position += text.length
          end
        end

        [cells, positions]
      else
        [[{text: line.strip, position: 0}], [0]]
      end
    end

    def process_rows
      @merged_rows = []

      @rows.each do |row|
        row.transform_to_single_cell! if row.incongruent_with_neighbours?

        if @merged_rows.empty? || !row.congruent_with_last_merged?
          @merged_rows << PdfTableExtractorRow.new(self, row.cells, row.positions, nil, true)
        else
          @merged_rows.last.merge!(row)
        end
      end
    end

    def same_leading_line?(pages)
      pages.all? { |lines| lines.any? } && pages.all? { |lines| lines[0] == pages[0][0] }
    end

    def same_trailing_line?(pages)
      pages.all? { |lines| lines.any? } && pages.all? { |lines| lines[-1] == pages[0][-1] }
    end

    def has_consecutive_spaces?(text)
      text.match?(/\s{2,}/)
    end

    def is_pagination?(line)
      line&.strip&.match?(/^.*\d+$/)
    end
  end
