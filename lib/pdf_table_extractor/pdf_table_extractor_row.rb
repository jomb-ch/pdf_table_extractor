# frozen_string_literal: true

# Represents a parsed row of cells with positions and supports merging/grouping.
#
# @!attribute [r] positions
#   @return [Array<Integer>] positions of the cells in this row
# @!attribute [r] index
#   @return [Integer, nil] original index when parsed (nil for merged rows)
# @!attribute [r] cells
#   @return [Array<Hash>] cells with :text and :position
# @!attribute [r] merged
#   @return [Boolean] whether this row is a merged row (not original)
class PdfTableExtractorRow
  attr_reader :positions, :index, :cells, :merged

  def initialize(extractor, cells, positions, index, merged = false)
    @extractor = extractor
    @cells = cells
    @index = index
    @merged = merged
    @positions = positions
  end

  # Whether this row is a single-cell row at position 0.
  # @param against [Symbol] :previous or :last_merged
  # @return [Boolean]
  def single_cell?(against = :previous)
    other_row = (against == :previous) ? prev : last_merged unless @merged
    second_pos = other_row&.positions&.[](1).to_i
    @positions == [0] && (
      @merged || @index == 0 || other_row.single_cell? || @cells.first[:text].length > second_pos - 2
    )
  end

  # Previous row in extractor.
  # @return [PdfTableExtractorRow, nil]
  def prev
    return nil if @index.zero?

    @extractor.rows[@index - 1]
  end

  # Next row in extractor.
  # @return [PdfTableExtractorRow, nil]
  def nxt
    return nil if @index == @extractor.rows.length - 1

    @extractor.rows[@index + 1]
  end

  # @return [Boolean] whether positions are congruent with previous row
  def congruent_with_previous?
    single_cell? == prev&.single_cell? && positions_match_with?(prev)
  end

  # @return [Boolean] whether positions are congruent with last merged row
  def congruent_with_last_merged?
    single_cell?(:last_merged) == last_merged&.single_cell? && positions_match_with?(last_merged)
  end

  # @return [Boolean] whether this row is incongruent relative to neighbours
  def incongruent_with_neighbours?
    !single_cell? && !(prev && congruent_with_previous?) && !nxt&.congruent_with_previous?
  end

  # Check if positions match with another row (within tolerance).
  # @param other_row [PdfTableExtractorRow, nil]
  # @return [Boolean]
  def positions_match_with?(other_row)
    @positions.each do |pos|
      if @extractor.options[:position_tolerance].zero?
        return false unless other_row&.positions.to_a.include?(pos)
      elsif ([pos..pos + @extractor.options[:position_tolerance]] - other_row&.positions.to_a).length == @extractor.options[:position_tolerance] + 1
        return false
      end
    end
    true
  end

  # Transform this row into a single-cell row by merging text.
  # @return [void]
  def transform_to_single_cell!
    @cells = [{
      text: @cells.sort_by { |c| c[:position] }.map { |c| c[:text] }.join(" ").gsub(/\s+/, " ").strip,
      position: 0
    }]
    @positions = [0]
  end

  # Merge text into matching cell positions from another row.
  # @param row [PdfTableExtractorRow]
  # @return [void]
  def merge!(row)
    @cells.each do |cell|
      r_cell = row.cells.find { |c| c[:position] == cell[:position] }
      cell[:text] += "\s#{r_cell[:text]}" if r_cell
    end
  end

  private

  # @return [PdfTableExtractorRow, nil]
  def last_merged
    @extractor.merged_rows.last
  end
end
