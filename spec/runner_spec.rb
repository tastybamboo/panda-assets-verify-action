require "spec_helper"
require "panda/assets/runner"

RSpec.describe Panda::Assets::Runner do
  let(:dummy_root) { File.expand_path("fixtures/dummy", __dir__) }

  it "runs full pipeline and writes reports" do
    runner = described_class.new(dummy_root:)
    runner.run_all!

    html = File.join(dummy_root, "tmp", "panda_assets_report.html")
    json = File.join(dummy_root, "tmp", "panda_assets_summary.json")

    expect(File).to exist(html)
    expect(File).to exist(json)

    parsed = JSON.parse(File.read(json))
    expect(parsed["prepare"]).to be_a(Hash)
    expect(parsed["verify"]).to be_a(Hash)
  end
end
