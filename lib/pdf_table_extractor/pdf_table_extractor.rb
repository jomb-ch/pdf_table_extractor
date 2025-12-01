# frozen_string_literal: true

require 'pdf-reader'

# PdfTableExtractor extracts tables from PDF text using spacing and position heuristics.
#
# @!attribute [r] rows
#   @return [Array<PdfTableExtractorRow>] raw rows parsed from text
# @!attribute [r] merged_rows
#   @return [Array<PdfTableExtractorRow>] rows merged into tables
# @!attribute [r] options
#   @return [Hash] configuration options
class PdfTableExtractor
  attr_reader :rows, :merged_rows, :options

  # @param pdf_path [String, nil] Path to the PDF file (optional when reader is provided)
  # @param reader [PDF::Reader, nil] Pre-initialized PDF::Reader instance
  # @param options [Hash] Configuration options
  # @option options [Boolean] :remove_page_headers (true) Remove common leading lines across pages
  # @option options [Boolean] :remove_page_footers (true) Remove common trailing lines across pages
  # @option options [Boolean, Integer] :remove_pagination_from_header (false) true or line number from top
  # @option options [Boolean, Integer] :remove_pagination_from_footer (false) true or line number from bottom
  # @option options [Boolean] :remove_empty_lines (true) Remove empty lines from the extracted text
  # @option options [Integer] :position_tolerance (2) Tolerance for matching column positions
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
  # @return [void]
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

  # Returns the extracted cells as arrays per merged row.
  # @return [Array<Array<Hash>>] Array of rows, each row is an array of cells with :text and :position
  def result
    @merged_rows.map(&:cells)
  end

  private

  # @return [Array<Array<String>>] Array of pages, each page is an array of lines
  def all_pages
    all_pages_texts.map { |page_text| page_text.lines.map(&:chomp) }
  end

  # @return [Array<String>] Array of page texts
  def all_pages_texts
    @reader.pages.map { |page| page.text }
  end

  # Remove pagination lines from headers and footers.
  # @param pages [Array<Array<String>>]
  # @return [Array<Array<String>>]
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

  # Remove common leading lines across pages.
  # @param pages [Array<Array<String>>]
  # @return [Array<Array<String>>]
  def remove_common_leading_lines(pages)
    return pages if pages.empty? || pages.length == 1
    pages.each(&:shift) while same_leading_line?(pages)
    pages
  end

  # Remove common trailing lines across pages.
  # @param pages [Array<Array<String>>]
  # @return [Array<Array<String>>]
  def remove_common_trailing_lines(pages)
    return pages if pages.empty? || pages.length == 1
    pages.each(&:pop) while same_trailing_line?(pages)
    pages
  end

  # Parse a line into cells using runs of multiple spaces as separators.
  # @param line [String]
  # @return [Array<(Array<Hash>, Array<Integer>)>] cells and positions
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

  # Process parsed rows into merged table rows.
  # @return [void]
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

  # @param pages [Array<Array<String>>]
  # @return [Boolean]
  def same_leading_line?(pages)
    pages.all? { |lines| lines.any? } && pages.all? { |lines| lines[0] == pages[0][0] }
  end

  # @param pages [Array<Array<String>>]
  # @return [Boolean]
  def same_trailing_line?(pages)
    pages.all? { |lines| lines.any? } && pages.all? { |lines| lines[-1] == pages[0][-1] }
  end

  # @param text [String]
  # @return [Boolean]
  def has_consecutive_spaces?(text)
    text.match?(/\s{2,}/)
  end

  # @param line [String, nil]
  # @return [Boolean]
  def is_pagination?(line)
    line&.strip&.match?(/^.*\d+$/)
  end
end
