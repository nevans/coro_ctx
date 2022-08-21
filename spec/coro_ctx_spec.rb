# frozen_string_literal: true

RSpec.describe CoroCtx do
  it "has a version number" do
    expect(CoroCtx::VERSION).not_to be_nil
  end

  it "provides dynamically scoped global variables"

  it "is inherited by enumerator fibers"
  it "is inherited by new fibers"
  it "is inherited by new threads"

  context "when its elements aren't all ractor-sharable" do
    it "raises an exception for new ractors"
  end

  context "when its elements are all ractor-sharable" do
    it "is ractor sharable"
    it "is inherited by new ractors"
  end
end
