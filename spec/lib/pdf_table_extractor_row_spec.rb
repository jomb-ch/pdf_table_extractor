# frozen_string_literal: true

require "spec_helper"

RSpec.describe PdfTableExtractorRow, type: :service do
  let(:extractor) { double("extractor", rows: [], merged_rows: []) }
  let(:cells) { [{text: "Test", position: 0}] }
  let(:positions) { [0] }
  let(:index) { 0 }
  let(:merged) { false }
  let(:row) { described_class.new(extractor, cells, positions, index, merged) }

  describe "#initialize" do
    it "initializes with all required attributes" do
      expect(row.cells).to eq(cells)
      expect(row.positions).to eq(positions)
      expect(row.index).to eq(index)
      expect(row.merged).to eq(merged)
    end

    context "when merged is not provided" do
      let(:row) { described_class.new(extractor, cells, positions, index) }

      it "defaults merged to false" do
        expect(row.merged).to be false
      end
    end
  end

  describe "#single_cell?" do
    context "when row has single cell in position 0 at index 0" do
      let(:cells) { [{text: "Test", position: 0}] }
      let(:positions) { [0] }
      let(:index) { 0 }

      it "returns true" do
        expect(row.single_cell?).to be true
      end
    end

    context "when row has single cell in position 0 and is merged" do
      let(:cells) { [{text: "Test", position: 0}] }
      let(:positions) { [0] }
      let(:index) { 5 }
      let(:merged) { true }

      it "returns true" do
        expect(row.single_cell?).to be true
      end
    end

    context "when row has single cell in position 0 and prev is single cell" do
      let(:cells) { [{text: "Test", position: 0}] }
      let(:positions) { [0] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "Prev", position: 0}], [0], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
      end

      it "returns true" do
        expect(row.single_cell?).to be true
      end
    end

    context "when row has single cell in position 0 with long text compared to prev first column" do
      let(:cells) { [{text: "Very long text", position: 0}] }
      let(:positions) { [0] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "S", position: 0}, {text: "Col2", position: 10}], [0, 10], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
      end

      it "returns true when text length is larger than prev first column position - 2" do
        expect(row.single_cell?).to be true
      end
    end

    context "when row has multiple cells" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }

      it "returns false" do
        expect(row.single_cell?).to be false
      end
    end

    context "when row has single cell not in position 0" do
      let(:cells) { [{text: "Test", position: 5}] }
      let(:positions) { [5] }

      it "returns false" do
        expect(row.single_cell?).to be false
      end
    end
  end

  describe "#prev" do
    context "when row is at index 0" do
      let(:index) { 0 }

      it "returns nil" do
        expect(row.prev).to be_nil
      end
    end

    context "when row is not at index 0" do
      let(:index) { 2 }
      let(:prev_row) { described_class.new(extractor, [{text: "Prev", position: 0}], [0], 1) }

      before do
        allow(extractor).to receive(:rows).and_return([nil, prev_row, row])
      end

      it "returns the previous row" do
        expect(row.prev).to eq(prev_row)
      end
    end
  end

  describe "#nxt" do
    context "when row is at last index" do
      let(:index) { 0 }

      before do
        allow(extractor).to receive(:rows).and_return([row])
      end

      it "returns nil" do
        expect(row.nxt).to be_nil
      end
    end

    context "when row is not at last index" do
      let(:index) { 0 }
      let(:next_row) { described_class.new(extractor, [{text: "Next", position: 0}], [0], 1) }

      before do
        allow(extractor).to receive(:rows).and_return([row, next_row])
      end

      it "returns the next row" do
        expect(row.nxt).to eq(next_row)
      end
    end
  end

  describe "#congruent_with_previous?" do
    context "when both rows are single cells" do
      let(:cells) { [{text: "Current", position: 0}] }
      let(:positions) { [0] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "Prev", position: 0}], [0], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns true" do
        expect(row.congruent_with_previous?).to be true
      end
    end

    context "when both rows are multi-cell with same positions" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "P1", position: 0}, {text: "P2", position: 10}], [0, 10], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns true" do
        expect(row.congruent_with_previous?).to be true
      end
    end

    context "when current row positions are subset of previous" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "P1", position: 0}, {text: "P2", position: 10}, {text: "P3", position: 20}], [0, 10, 20], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns true" do
        expect(row.congruent_with_previous?).to be true
      end
    end

    context "when single_cell? differs between rows" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "Prev", position: 0}], [0], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
      end

      it "returns false" do
        expect(row.congruent_with_previous?).to be false
      end
    end

    context "when positions are not a subset of previous" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 15}] }
      let(:positions) { [0, 15] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "P1", position: 0}, {text: "P2", position: 10}], [0, 10], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns false" do
        expect(row.congruent_with_previous?).to be false
      end
    end

    context "when prev is nil" do
      let(:index) { 0 }

      it "returns false" do
        expect(row.congruent_with_previous?).to be false
      end
    end
  end

  describe "#congruent_with_last_merged?" do
    context "when both rows are single cells with same positions" do
      let(:cells) { [{text: "Current", position: 0}] }
      let(:positions) { [0] }
      let(:last_merged_row) { described_class.new(extractor, [{text: "Merged", position: 0}], [0], nil, true) }

      before do
        allow(extractor).to receive(:merged_rows).and_return([last_merged_row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns true" do
        expect(row.congruent_with_last_merged?).to be true
      end
    end

    context "when current row is not single cell" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:last_merged_row) { described_class.new(extractor, [{text: "Merged", position: 0}], [0], nil, true) }

      before do
        allow(extractor).to receive(:merged_rows).and_return([last_merged_row])
      end

      it "returns false" do
        expect(row.congruent_with_last_merged?).to be false
      end
    end

    context "when last_merged is not single cell" do
      let(:cells) { [{text: "Current", position: 0}] }
      let(:positions) { [0] }
      let(:last_merged_row) { described_class.new(extractor, [{text: "M1", position: 0}, {text: "M2", position: 10}], [0, 10], nil, true) }

      before do
        allow(extractor).to receive(:merged_rows).and_return([last_merged_row])
      end

      it "returns false" do
        expect(row.congruent_with_last_merged?).to be false
      end
    end

    context "when positions differ" do
      let(:cells) { [{text: "Current", position: 5}] }
      let(:positions) { [5] }
      let(:last_merged_row) { described_class.new(extractor, [{text: "Merged", position: 0}], [0], nil, true) }

      before do
        allow(extractor).to receive(:merged_rows).and_return([last_merged_row])
      end

      it "returns false" do
        expect(row.congruent_with_last_merged?).to be false
      end
    end

    context "when there are no merged rows" do
      before do
        allow(extractor).to receive(:merged_rows).and_return([])
      end

      it "returns falsey" do
        expect(row.congruent_with_last_merged?).to be_falsey
      end
    end
  end

  describe "#incongruent_with_neighbours?" do
    context "when row is not single cell and not congruent with prev and next not congruent with current" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "Prev", position: 0}], [0], 0) }
      let(:next_row) { described_class.new(extractor, [{text: "Next Next Next Next", position: 0}], [0], 2) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row, next_row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns true" do
        expect(row.incongruent_with_neighbours?).to be true
      end
    end

    context "when row is single cell" do
      let(:cells) { [{text: "Test", position: 0}] }
      let(:positions) { [0] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "Prev", position: 0}], [0], 0) }
      let(:next_row) { described_class.new(extractor, [{text: "Next Next Next Next", position: 0}], [0], 2) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row, next_row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns false" do
        expect(row.incongruent_with_neighbours?).to be false
      end
    end

    context "when row is congruent with previous" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 1 }
      let(:prev_row) { described_class.new(extractor, [{text: "P1", position: 0}, {text: "P2", position: 10}], [0, 10], 0) }

      before do
        allow(extractor).to receive(:rows).and_return([prev_row, row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns false" do
        expect(row.incongruent_with_neighbours?).to be false
      end
    end

    context "when next row is congruent with current" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 0 }
      let(:next_row) { described_class.new(extractor, [{text: "N1", position: 0}, {text: "N2", position: 10}], [0, 10], 1) }

      before do
        allow(extractor).to receive(:rows).and_return([row, next_row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns false" do
        expect(row.incongruent_with_neighbours?).to be false
      end
    end

    context "when prev is nil" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [0, 10] }
      let(:index) { 0 }
      let(:next_row) { described_class.new(extractor, [{text: "Next Next Next Next ", position: 0}], [0], 1) }

      before do
        allow(extractor).to receive(:rows).and_return([row, next_row])
        allow(extractor).to receive(:options).and_return({position_tolerance: 0})
      end

      it "returns true when not congruent with next" do
        expect(row.incongruent_with_neighbours?).to be true
      end
    end
  end

  describe "#transform_to_single_cell!" do
    context "when row has multiple cells" do
      let(:cells) { [{text: "Col1", position: 0}, {text: "Col2", position: 10}, {text: "Col3", position: 20}] }
      let(:positions) { [0, 10, 20] }

      it "merges all cells into a single cell at position 0" do
        row.transform_to_single_cell!

        expect(row.cells.length).to eq(1)
        expect(row.cells.first[:text]).to eq("Col1 Col2 Col3")
        expect(row.cells.first[:position]).to eq(0)
        expect(row.positions).to eq([0])
      end
    end

    context "when cells are not in order" do
      let(:cells) { [{text: "Col3", position: 20}, {text: "Col1", position: 0}, {text: "Col2", position: 10}] }
      let(:positions) { [20, 0, 10] }

      it "sorts cells by position before merging" do
        row.transform_to_single_cell!

        expect(row.cells.first[:text]).to eq("Col1 Col2 Col3")
      end
    end

    context "when cells have extra whitespace" do
      let(:cells) { [{text: "Col1  ", position: 0}, {text: "  Col2  ", position: 10}] }
      let(:positions) { [0, 10] }

      it "normalizes whitespace" do
        row.transform_to_single_cell!

        expect(row.cells.first[:text]).to eq("Col1 Col2")
      end
    end

    context "when row already has single cell" do
      let(:cells) { [{text: "Single", position: 0}] }
      let(:positions) { [0] }

      it "keeps the cell unchanged" do
        row.transform_to_single_cell!

        expect(row.cells.length).to eq(1)
        expect(row.cells.first[:text]).to eq("Single")
      end
    end
  end

  describe "#merge!" do
    let(:cells) { [{text: "Line1", position: 0}, {text: "Col2", position: 10}] }
    let(:positions) { [0, 10] }

    context "when merging row with matching positions" do
      let(:other_row) { described_class.new(extractor, [{text: "Line2", position: 0}, {text: "Extra", position: 10}], [0, 10], 1) }

      it "appends text from matching cells" do
        row.merge!(other_row)

        expect(row.cells[0][:text]).to eq("Line1 Line2")
        expect(row.cells[1][:text]).to eq("Col2 Extra")
      end
    end

    context "when merging row with partial matching positions" do
      let(:other_row) { described_class.new(extractor, [{text: "Line2", position: 0}], [0], 1) }

      it "only merges matching positions" do
        row.merge!(other_row)

        expect(row.cells[0][:text]).to eq("Line1 Line2")
        expect(row.cells[1][:text]).to eq("Col2")
      end
    end

    context "when merging row with no matching positions" do
      let(:other_row) { described_class.new(extractor, [{text: "Other", position: 20}], [20], 1) }

      it "does not modify existing cells" do
        row.merge!(other_row)

        expect(row.cells[0][:text]).to eq("Line1")
        expect(row.cells[1][:text]).to eq("Col2")
      end
    end

    context "when merging multiple rows sequentially" do
      let(:row2) { described_class.new(extractor, [{text: "Line2", position: 0}, {text: "Extra2", position: 10}], [0, 10], 1) }
      let(:row3) { described_class.new(extractor, [{text: "Line3", position: 0}, {text: "Extra3", position: 10}], [0, 10], 2) }

      it "accumulates text from all merged rows" do
        row.merge!(row2)
        row.merge!(row3)

        expect(row.cells[0][:text]).to eq("Line1 Line2 Line3")
        expect(row.cells[1][:text]).to eq("Col2 Extra2 Extra3")
      end
    end
  end
end
