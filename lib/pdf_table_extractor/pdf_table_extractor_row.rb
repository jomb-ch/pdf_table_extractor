# frozen_string_literal: true

  class PdfTableExtractorRow
    attr_reader :positions, :index, :cells, :merged
    def initialize(extractor, cells, positions, index, merged = false)
      @extractor = extractor
      @cells = cells
      @index = index
      @merged = merged
      @positions = positions
    end

    # has to have a single cell and that cell has to be in position 0
    # has to be either preceded with single cell (or nil) or has to have length larger than the length of previous first column
    def single_cell?(against = :previous)
      other_row = (against == :previous) ? prev : last_merged unless @merged
      @positions == [0] && (@merged || @index == 0 || other_row.single_cell? || @cells.first[:text].length > other_row.positions.second.to_i - 2)
    end

    def prev
      return nil if @index == 0
      @extractor.rows[@index - 1]
    end

    def nxt
      return nil if @index == @extractor.rows.length - 1
      @extractor.rows[@index + 1]
    end

    # either both are single or positions are subset of previous positions
    def congruent_with_previous?
      single_cell? == prev&.single_cell? && positions_match_with?(prev)
    end

    def congruent_with_last_merged?
      single_cell?(:last_merged) == last_merged&.single_cell? && positions_match_with?(last_merged)
    end

    def incongruent_with_neighbours?
      !single_cell? && !(prev && congruent_with_previous?) && !nxt&.congruent_with_previous?
    end

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

    def transform_to_single_cell!
      @cells = [{
        text: @cells.sort_by { |c| c[:position] }.map { |c| c[:text] }.join(" ").gsub(/\s+/, " ").strip,
        position: 0
      }]
      @positions = [0]
    end

    def merge!(row)
      @cells.each do |cell|
        r_cell = row.cells.find { |c| c[:position] == cell[:position] }
        cell[:text] += "\s#{r_cell[:text]}" if r_cell
      end
    end

    private

    def last_merged
      @extractor.merged_rows.last
    end
  end