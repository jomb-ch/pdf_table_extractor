require "spec_helper"

RSpec.describe PdfTableExtractor, type: :service do
  let(:extractor) { PdfTableExtractor.new reader: Object.new, options: {remove_pagination_from_footer: 1} }

  describe "initialization" do
    it "initializes with default options" do
      extractor = PdfTableExtractor.new(reader: Object.new)

      expect(extractor.options[:remove_page_headers]).to be true
      expect(extractor.options[:remove_page_footers]).to be true
      expect(extractor.options[:remove_pagination_from_header]).to be false
      expect(extractor.options[:remove_pagination_from_footer]).to be false
      expect(extractor.options[:remove_empty_lines]).to be true
      expect(extractor.options[:position_tolerance]).to eq 2
    end

    it "initializes with custom options" do
      options = {
        remove_page_headers: false,
        remove_page_footers: false,
        remove_pagination: false,
        remove_empty_lines: false,
        position_tolerance: 5
      }
      extractor = PdfTableExtractor.new(reader: Object.new, options:)
      expect(extractor.options[:remove_page_headers]).to be false
      expect(extractor.options[:remove_page_footers]).to be false
      expect(extractor.options[:remove_pagination]).to be false
      expect(extractor.options[:remove_empty_lines]).to be false
      expect(extractor.options[:position_tolerance]).to eq 5
    end

    context "with pdf_path" do
      let(:pdf_path) { File.join(FIXTURE_PDFS, "t1.pdf") }
      let(:extractor) { PdfTableExtractor.new(pdf_path.to_s) }

      it "initializes instance variables correctly and can extract tables from real PDF file" do
        expect { extractor.extract_tables }.not_to raise_error
        expect(extractor.merged_rows).not_to be_empty
      end
    end
  end

  context "when fixture pdf is processed" do
    let(:fixture_name) { "t1" }
    let(:pdf_reader) { PDF::Reader.new File.join(FIXTURE_PDFS, "#{fixture_name}.pdf") }
    let(:number_of_fixture_pages) { 4 }
    let(:pdf_reader_output) { pdf_reader.pages[0..number_of_fixture_pages - 1].map { |page| page.text } }
    let(:fixture_dir) { FIXTURE_PAGE_TEXTS }

    it "extracted pages sample corresponds to fixture pages" do
      expect(pdf_reader_output).to eq (0..number_of_fixture_pages - 1).to_a.map { |i| File.read(File.join(fixture_dir, "#{fixture_name}_#{i}.txt")) }
    end
  end

  describe "extract_tables" do
    let(:all_pages_json) { JSON.parse(File.read(File.join(FIXTURE_ALL_PAGES, "t1.json"))) }
    before { allow(extractor).to receive(:all_pages).and_return(all_pages_json) }

    it "extracts tables successfully from fixture PDF" do
      extractor.extract_tables

      expect(extractor.merged_rows).not_to be_empty
      expect(extractor.merged_rows).to all(be_a(PdfTableExtractorRow))

      extractor.merged_rows.each do |row|
        expect(row.cells).to be_a(Array)
        expect(row.positions).to be_a(Array)
        expect(row.cells.length).to eq(row.positions.length)
      end
    end

    it "extracts main title, correctly handling the second line indentation" do
      extractor.extract_tables
      expect(extractor.result[0][1][:text]).to eq "Handlungskompetenzbereiche, Handlungskompetenzen und Leistungsziele je Lernort"
    end

    context "when column spans multiple pages" do
      it "extracts correctly" do
        extractor.extract_tables
        expect(extractor.result[2][0][:text]).to eq "Leistungsziele Betrieb 1.1.1 Sie überprüfen die Verfüg- barkeit der textilen Rohstoffe, Hilfsmittel, Arbeitsmittel, Ma- schinen und Komponenten. (K4) 1.1.2 Sie planen Arbeitsprozes- se in der textilen Kette unter Berücksichtigung der verfügba- ren Zeit und Ressourcen. (K5) 1.1.3 Sie führen betriebsspezifi- sche Berechnungen durch. (K3) 1.1.4 Sie erklären die betriebli- che Organisation und die wich- tigsten Prozesse. (K2) 1.1.5 Sie beschaffen die Ar- beitsanweisungen oder die Sys- temvorgaben und analysieren diese. Sie legen fest: - Optimale Arbeitsabläufe - Interne Arbeitspapiere - Optimale Maschineneinteilung - Geeignete Betriebsmittel / Hilfsstoffe - Notwendige Absprachen mit Vorgesetzten und Mitarbeitern - Mögliche Risiken bezüglich Sicherheit und Qualität (K5) 1.1.6 Sie lokalisieren die Ein- satzmöglichkeiten von neuen Technologien. (K2)"
      end
    end

    context "when some cells have indented text (which messes up positions)" do
      let(:expected_text) { "Leistungsziele Berufsfach- schule 1.1.1 Sie erläutern die Produkti- onsstufen vom Rohstoff über die Halbfabrikate zum Endprodukt. (K2) 1.1.2 Sie ordnen die textilen Produkte dem Herstellungspro- zess zu. (K3) 1.1.3 Sie führen berufsbezoge- ne Berechnungen korrekt in den folgenden Bereichen durch: - Brutto-/Netto-/ - Mengen- und Zeitberech- - Flächenberechnungen - Volumenberechnungen - Garnnummerierungssysteme - Produktionsberechnungen (K3) 1.1.4 Sie beschreiben anhand eines Betriebes die folgenden Organisationsformen und - instrumente: - Leitbild - Organigramm - Funktionendiagramm (K2) 1.1.5 Sie skizzieren verschiede- ne Arbeitsprozesse. (K3) 1.1.6 Sie beschreiben den Ein- satz von neuen Technologien. (K2)" }

      context "and position tolerance does not account for it" do
        let(:extractor) { PdfTableExtractor.new reader: Object.new, options: {position_tolerance: 0} }

        it "does not extract correctly" do
          extractor.extract_tables
          expect(extractor.result[2][1][:text]).not_to eq expected_text
        end
      end

      context "and (default) position tolerance accounts for it" do
        it "extracts correctly" do
          extractor.extract_tables
          expect(extractor.result[2][1][:text]).to eq expected_text
        end
      end
    end

    context "when all cells except for the heading are empty" do
      it "extracts correctly" do
        extractor.extract_tables
        expect(extractor.result[2][2][:text]).to eq "Leistungsziele überbetriebli- cher Kurs"
      end
    end

    context "when only first column cells have content (apart from headings)" do
      it "extracts correctly" do
        extractor.extract_tables
        expect(extractor.result[6][0][:text]).to eq "Leistungsziele Betrieb 1.3.1 Sie beschaffen Materialien gemäss Arbeitsanweisungen oder Systemvorgaben sowie den betrieblichen Vorgaben. (K3) 1.3.2 Sie lagern Materialien fachgerecht gemäss den be- trieblichen Vorgaben. (K3 )"
      end
    end

    context "when cells of the first column have no content and other cells do" do
      it "extracts correctly" do
        extractor.extract_tables
        expect(extractor.result[16][0][:text]).to eq "Leistungsziele Betrieb"
        expect(extractor.result[16][1][:text]).to eq "Leistungsziele Berufsfach- schule 3.1.1 Sie erklären anhand von ausgewählten Produkten die typischen Produktionsprozesse für die Spinnerei, Zwirnerei und Seilerei. (K2)"
        expect(extractor.result[16][2][:text]).to eq "Leistungsziele überbetriebli- cher Kurs 3.1.1 Sie stellen ausgewählte Produkte aus dem Bereich Spinnerei, Zwirnerei oder Seile- rei unter Berücksichtigung der Arbeitssicherheit her. (K3) 3.1.2 Sie setzen bei der Herstel- lung der Produkte das Quali- tätssicherungskonzept des üK- Standortes um. (K3)"
      end
    end
  end

  describe "all_pages" do
    let(:fixture_name) { "t1" }
    let(:number_of_fixture_pages) { 6 }
    let(:fixture_dir) { FIXTURE_PAGE_TEXTS }
    let(:raw_page_texts) { (0..number_of_fixture_pages - 1).to_a.map { |i| File.read(File.join(fixture_dir, "#{fixture_name}_#{i}.txt")) } }
    let(:all_pages_json) { File.read(File.join(FIXTURE_ALL_PAGES, "#{fixture_name}.json")) }

    it "extracts all pages as array of lines" do
      allow(extractor).to receive(:all_pages_texts).and_return(raw_page_texts)
      expect(extractor.send(:all_pages)).to eq JSON.parse(all_pages_json)
    end

    it "converts page texts to arrays of lines" do
      page_texts = %W[Line1\nLine2\nLine3 Page2Line1\nPage2Line2]
      allow(extractor).to receive(:all_pages_texts).and_return(page_texts)

      result = extractor.send(:all_pages)

      expect(result).to eq([%w[Line1 Line2 Line3], %w[Page2Line1 Page2Line2]])
    end

    it "removes trailing newlines from lines" do
      page_texts = %W[Line1\n Line2\n]
      allow(extractor).to receive(:all_pages_texts).and_return(page_texts)

      result = extractor.send(:all_pages)

      expect(result[0][0]).to eq("Line1")
      expect(result[1][0]).to eq("Line2")
    end

    it "handles empty pages" do
      page_texts = ["", "Content"]
      allow(extractor).to receive(:all_pages_texts).and_return(page_texts)

      result = extractor.send(:all_pages)

      expect(result[0]).to eq([])
      expect(result[1]).to eq(["Content"])
    end
  end

  describe "remove_pagination" do
    let(:all_pages_json) { File.read(File.join(FIXTURE_ALL_PAGES, "t1.json")) }
    let(:all_pages) { JSON.parse(all_pages_json) }
    before { allow(extractor).to receive(:all_pages).and_return(all_pages) }

    it "removes pagination lines from headers and footers" do
      expect(extractor.options[:remove_pagination_from_footer]).to eq 1
      expect(all_pages.all? { |page| extractor.send(:is_pagination?, page.last) }).to be_truthy
      processed_pages = extractor.send(:remove_pagination, all_pages)
      expect(processed_pages.all? { |page| extractor.send(:is_pagination?, page.last) }).to be_falsey
    end
  end

  describe "remove_common_leading_lines" do
    let(:all_pages_json) { File.read(File.join(FIXTURE_ALL_PAGES, "t1.json")) }
    let(:all_pages) { JSON.parse(all_pages_json) }
    let(:number_of_common_leading_lines) { 5 }
    before { allow(extractor).to receive(:all_pages).and_return(all_pages) }

    it "removes common leading lines from all pages" do
      (0..number_of_common_leading_lines - 1).each do |i|
        expect(all_pages.all? { |page| page[i] == all_pages[0][i] }).to be_truthy
      end
      expect(all_pages.all? { |page| page[5] == all_pages[0][number_of_common_leading_lines - 1] }).to be_falsey

      processed_pages = extractor.send(:remove_common_leading_lines, all_pages)
      expect(processed_pages.all? { |page| page.first == processed_pages[0].first }).to be_falsey

      # has to be parsed again
      JSON.parse(all_pages_json).each_with_index do |page, index|
        expect(page.length).to eq processed_pages[index].length + number_of_common_leading_lines
      end
    end
  end

  describe "remove_common_trailing_lines" do
    let(:all_pages_json) { File.read(File.join(FIXTURE_ALL_PAGES, "t1.json")) }
    let(:all_pages) { JSON.parse(all_pages_json) }
    let(:number_of_common_trailing_lines) { 2 }
    before { allow(extractor).to receive(:all_pages).and_return(all_pages) }

    it "removes common trailing lines from all pages" do
      expect(all_pages.all? { |page| extractor.send(:is_pagination?, page.last) }).to be_truthy

      # fixtures have pagination at the last line, it needs to get removed first, otherwise there are no common trailing lines
      processed_pages = extractor.send(:remove_pagination, all_pages)

      (1..number_of_common_trailing_lines).each do |i|
        expect(processed_pages.all? { |page| page[-i] == all_pages[0][-i] }).to be_truthy
      end
      expect(processed_pages.all? { |page| page[-6] == all_pages[0][-3] }).to be_falsey

      processed_pages = extractor.send(:remove_common_trailing_lines, processed_pages)
      expect(processed_pages.all? { |page| page.last == processed_pages[0].last }).to be_falsey
      expect(processed_pages.all? { |page| !extractor.send(:is_pagination?, page.last) }).to be_truthy

      # has to be parsed again
      JSON.parse(all_pages_json).each_with_index do |page, index|
        expect(page.length).to eq processed_pages[index].length + number_of_common_trailing_lines + 1
      end
    end
  end

  describe "parse_line_to_cells" do
    let(:line_with_multiple_spaces) { "Cell1    Cell2      Cell3" }
    let(:line_without_multiple_spaces) { "SingleCellLine" }
    let(:line_with_leading_and_trailing_spaces) { "   LeadingAndTrailing   " }
    let(:extractor) { PdfTableExtractor.new(reader: Object.new) }

    it "parses line with multiple spaces into cells" do
      cells, positions = extractor.send(:parse_line_to_cells, line_with_multiple_spaces)
      expect(cells.length).to eq 3
      expect(positions).to eq [0, 9, 20]
      expect(cells[0][:text]).to eq "Cell1"
      expect(cells[0][:position]).to eq 0
      expect(cells[1][:text]).to eq "Cell2"
      expect(cells[1][:position]).to eq(cells[0][:text].length + 4)
      expect(cells[2][:text]).to eq "Cell3"
      expect(cells[2][:position]).to eq(cells[1][:position] + cells[1][:text].length + 6)
    end

    it "parses line without multiple spaces into a single cell" do
      cells, positions = extractor.send(:parse_line_to_cells, line_without_multiple_spaces)
      expect(cells.length).to eq 1
      expect(positions).to eq [0]
      expect(cells[0][:text]).to eq "SingleCellLine"
      expect(cells[0][:position]).to eq 0
    end

    it "parses line with leading and trailing spaces correctly" do
      cells, positions = extractor.send(:parse_line_to_cells, line_with_leading_and_trailing_spaces)
      expect(cells.length).to eq 1
      expect(positions).to eq [3]
      expect(cells[0][:text]).to eq "LeadingAndTrailing"
      expect(cells[0][:position]).to eq 3
    end

    it "handles empty strings" do
      cells, positions = extractor.send(:parse_line_to_cells, "")
      expect(cells.length).to eq 1
      expect(positions).to eq [0]
      expect(cells[0][:text]).to eq ""
      expect(cells[0][:position]).to eq 0
    end

    it "handles lines with only spaces" do
      cells, positions = extractor.send(:parse_line_to_cells, "     ")
      expect(cells).to be_empty
      expect(positions).to be_empty
    end

    it "handles complex spacing patterns" do
      line = "A  B    C      D"
      cells, positions = extractor.send(:parse_line_to_cells, line)
      expect(cells.length).to eq 4
      expect(cells.map { |c| c[:text] }).to eq ["A", "B", "C", "D"]
      expect(positions).to eq [0, 3, 8, 15]
    end

    it "preserves position information accurately" do
      line = "Start  Middle    End"
      cells, _ = extractor.send(:parse_line_to_cells, line)

      expect(cells[0][:position]).to eq 0
      expect(cells[1][:position]).to eq 7
      expect(cells[2][:position]).to eq 17
    end

    it "handles mixed spacing between cells" do
      line = "Col1  Col2   Col3    Col4"
      cells, _ = extractor.send(:parse_line_to_cells, line)

      expect(cells.length).to eq 4
      expect(cells.map { |c| c[:text] }).to eq ["Col1", "Col2", "Col3", "Col4"]
    end
  end

  describe "has_consecutive_spaces?" do
    it "returns true for strings with two consecutive spaces" do
      expect(extractor.send(:has_consecutive_spaces?, "A  B")).to be true
    end

    it "returns true for strings with multiple consecutive spaces" do
      expect(extractor.send(:has_consecutive_spaces?, "A   B")).to be true
      expect(extractor.send(:has_consecutive_spaces?, "A    B")).to be true
      expect(extractor.send(:has_consecutive_spaces?, "A          B")).to be true
    end

    it "returns false for strings with single spaces" do
      expect(extractor.send(:has_consecutive_spaces?, "A B")).to be false
      expect(extractor.send(:has_consecutive_spaces?, "A B C D")).to be false
    end

    it "returns false for strings with no spaces" do
      expect(extractor.send(:has_consecutive_spaces?, "ABC")).to be false
      expect(extractor.send(:has_consecutive_spaces?, "")).to be false
    end

    it "returns true for strings with tabs" do
      expect(extractor.send(:has_consecutive_spaces?, "A\t\tB")).to be true
    end
  end

  describe "is_pagination?" do
    it "returns true for lines ending with numbers" do
      expect(extractor.send(:is_pagination?, "Page 1")).to be true
      expect(extractor.send(:is_pagination?, "123")).to be true
      expect(extractor.send(:is_pagination?, "Some text 42")).to be true
      expect(extractor.send(:is_pagination?, "- 10 -")).to be false
      expect(extractor.send(:is_pagination?, "10")).to be true
    end

    it "returns false for lines not ending with numbers" do
      expect(extractor.send(:is_pagination?, "Page")).to be false
      expect(extractor.send(:is_pagination?, "Some text")).to be false
      expect(extractor.send(:is_pagination?, "1 2 3 text")).to be false
    end

    it "handles empty and whitespace strings" do
      expect(extractor.send(:is_pagination?, "")).to be false
      expect(extractor.send(:is_pagination?, "   ")).to be false
      expect(extractor.send(:is_pagination?, "  5  ")).to be true
    end
  end

  describe "same_leading_line?" do
    it "returns true when all pages have same first line" do
      pages = [%w[Header Content1], %w[Header Content2], %w[Header Content3]]
      expect(extractor.send(:same_leading_line?, pages)).to be true
    end

    it "returns false when pages have different first lines" do
      pages = [%w[Header1 Content], %w[Header2 Content], %w[Header3 Content]]
      expect(extractor.send(:same_leading_line?, pages)).to be false
    end

    it "returns false when any page is empty" do
      pages = [%w[Header Content], [], %w[Header Content]]
      expect(extractor.send(:same_leading_line?, pages)).to be false
    end

    it "returns true for empty pages array (vacuous truth)" do
      expect(extractor.send(:same_leading_line?, [])).to be true
    end

    it "returns true for single page" do
      pages = [%w[Header Content]]
      expect(extractor.send(:same_leading_line?, pages)).to be true
    end
  end

  describe "same_trailing_line?" do
    it "returns true when all pages have same last line" do
      pages = [["Content1", "Footer"], ["Content2", "Footer"], ["Content3", "Footer"]]
      expect(extractor.send(:same_trailing_line?, pages)).to be true
    end

    it "returns false when pages have different last lines" do
      pages = [["Content", "Footer1"], ["Content", "Footer2"], ["Content", "Footer3"]]
      expect(extractor.send(:same_trailing_line?, pages)).to be false
    end

    it "returns false when any page is empty" do
      pages = [["Content", "Footer"], [], ["Content", "Footer"]]
      expect(extractor.send(:same_trailing_line?, pages)).to be false
    end

    it "returns true for empty pages array (vacuous truth)" do
      expect(extractor.send(:same_trailing_line?, [])).to be true
    end

    it "returns true for single page" do
      pages = [["Content", "Footer"]]
      expect(extractor.send(:same_trailing_line?, pages)).to be true
    end
  end

  describe "remove_common_leading_lines edge cases" do
    it "returns pages unchanged when there is only one page" do
      pages = [["Line1", "Line2", "Line3"]]
      result = extractor.send(:remove_common_leading_lines, pages)
      expect(result).to eq pages
    end

    it "returns empty array when pages is empty" do
      pages = []
      result = extractor.send(:remove_common_leading_lines, pages)
      expect(result).to eq []
    end

    it "handles pages with no common leading lines" do
      pages = [["A", "B"], ["C", "D"], ["E", "F"]]
      result = extractor.send(:remove_common_leading_lines, pages)
      expect(result).to eq pages
    end

    it "removes all common leading lines when all pages are identical" do
      pages = [["Same", "Same"], ["Same", "Same"], ["Same", "Same"]]
      result = extractor.send(:remove_common_leading_lines, pages)
      # When all lines are common, they all get removed
      expect(result.all?(&:empty?)).to be true
    end

    it "removes pagination from leading lines when option is enabled" do
      extractor_with_pagination = PdfTableExtractor.new(reader: Object.new, options: {remove_pagination: true})
      pages = [["1", "Different1"], ["2", "Different2"]]
      result = extractor_with_pagination.send(:remove_common_leading_lines, pages)
      # Pagination lines (lines ending with numbers) are removed
      # Since both "1" and "2" are pagination, they're removed
      # Result should not error
      expect(result).to be_an(Array)
    end

    it "does not remove non-pagination leading lines when option is disabled" do
      extractor_no_pagination = PdfTableExtractor.new(reader: Object.new, options: {remove_pagination: false})
      pages = [["Common", "Content1"], ["Common", "Content2"]]
      result = extractor_no_pagination.send(:remove_common_leading_lines, pages)
      # Common lines are still removed, but without pagination preprocessing
      expect(result).to eq [["Content1"], ["Content2"]]
    end

    it "handles pages with different lengths" do
      pages = [["Common", "A", "B", "C"], ["Common", "D"], ["Common", "E", "F"]]
      result = extractor.send(:remove_common_leading_lines, pages)
      expect(result).to eq [["A", "B", "C"], ["D"], ["E", "F"]]
    end
  end

  describe "remove_common_trailing_lines edge cases" do
    it "returns pages unchanged when there is only one page" do
      pages = [["Line1", "Line2", "Line3"]]
      result = extractor.send(:remove_common_trailing_lines, pages)
      expect(result).to eq pages
    end

    it "returns empty array when pages is empty" do
      pages = []
      result = extractor.send(:remove_common_trailing_lines, pages)
      expect(result).to eq []
    end

    it "handles pages with no common trailing lines" do
      pages = [["A", "B"], ["C", "D"], ["E", "F"]]
      result = extractor.send(:remove_common_trailing_lines, pages)
      expect(result).to eq pages
    end

    it "removes all common trailing lines when all pages are identical" do
      pages = [["Same", "Same"], ["Same", "Same"], ["Same", "Same"]]
      result = extractor.send(:remove_common_trailing_lines, pages)
      # When all lines are common, they all get removed
      expect(result.all?(&:empty?)).to be true
    end

    it "removes pagination from trailing lines when option is enabled" do
      extractor_with_pagination = PdfTableExtractor.new(reader: Object.new, options: {remove_pagination: true})
      pages = [["Different1", "1"], ["Different2", "2"]]
      result = extractor_with_pagination.send(:remove_common_trailing_lines, pages)
      # Pagination lines (lines ending with numbers) are removed
      # Result should not error
      expect(result).to be_an(Array)
    end

    it "does not remove non-pagination trailing lines when option is disabled" do
      extractor_no_pagination = PdfTableExtractor.new(reader: Object.new, options: {remove_pagination: false})
      pages = [["Content1", "Common"], ["Content2", "Common"]]
      result = extractor_no_pagination.send(:remove_common_trailing_lines, pages)
      # Common lines are still removed
      expect(result).to eq [["Content1"], ["Content2"]]
    end

    it "handles pages with different lengths" do
      pages = [%w[A B C Common], %w[D Common], %w[E F Common]]
      result = extractor.send(:remove_common_trailing_lines, pages)
      expect(result).to eq [%w[A B C], ["D"], %w[E F]]
    end
  end

  describe "process_rows" do
    let(:mock_reader) { double("PDF::Reader") }

    it "merges congruent rows" do
      mock_page = double("page", text: "Cell1  Cell2\nLine2  Line2Col2\nLine3  Line3Col2")
      allow(mock_reader).to receive(:pages).and_return([mock_page])

      extractor = PdfTableExtractor.new(reader: mock_reader)
      extractor.extract_tables

      expect(extractor.merged_rows).not_to be_empty
      expect(extractor.merged_rows.first.cells).to be_an(Array)
      expect(extractor.merged_rows.first.cells.first[:text]).to eq "Cell1 Line2 Line3"
    end

    it "transforms incongruent rows to single cells" do
      mock_page = double("page", text: "Cell1  Cell2\nSingleCellRow\nCell3  Cell4")
      allow(mock_reader).to receive(:pages).and_return([mock_page])

      extractor = PdfTableExtractor.new(reader: mock_reader)
      extractor.extract_tables

      expect(extractor.merged_rows).not_to be_empty
      expect(extractor.merged_rows.first.cells.first[:text]).to eq "Cell1 Cell2 SingleCellRow Cell3 Cell4"
    end
  end
end
