# frozen_string_literal: true

# This spec provides overview examples, so some rubocop rules don't apply.
# rubocop:disable RSpec/DescribedClass, RSpec/MultipleExpectations
# rubocop:disable RSpec/ExampleLength

RSpec.describe CoroCtx do
  it "has a version number" do
    expect(CoroCtx::VERSION).not_to be_nil
  end

  using CoroCtx

  it "provides dynamically scoped global variables" do
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([nil, nil])
    retval = with_ctx_values(foo: :foo) {
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:foo, nil])
      foo_bar_baz_quux_hoge_fuga do
        expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:quux, :fuga])
      end
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:foo, nil])
      :executed_block
    }
    expect(retval).to equal(:executed_block)
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([nil, nil])
  end

  # these methods demonstrate that context values follow stack-frames
  # rubocop:disable Metrics/AbcSize
  def foo_bar_baz_quux_hoge_fuga(&)
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:foo, nil])
    with_ctx_values foo: :bar, hoge: :hoge do
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:bar, :hoge])
      bar_baz_quux_fuga(&)
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:bar, :hoge])
    end
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:foo, nil])
  end

  def bar_baz_quux_fuga(&)
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:bar, :hoge])
    with_ctx_values foo: :baz, hoge: nil do
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:baz, nil])
      baz_quux_fuga(&)
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:baz, nil])
    end
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:bar, :hoge])
  end

  def baz_quux_fuga
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:baz, nil])
    with_ctx_values foo: :quux, hoge: :fuga do
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:quux, :fuga])
      yield
      expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:quux, :fuga])
    end
    expect([CoroCtx[:foo], CoroCtx[:hoge]]).to eq([:baz, nil])
  end

  # rubocop:enable Metrics/AbcSize

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

# rubocop:enable RSpec/DescribedClass, RSpec/MultipleExpectations
# rubocop:enable RSpec/ExampleLength
