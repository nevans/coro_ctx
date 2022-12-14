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

  it "is inherited by new fibers" do
    ran = 0
    mkfiber = -> {
      Fiber.new do
        Fiber.yield CoroCtx[:a]
        Fiber.yield(Fiber.new { CoroCtx[:b] }.resume)
      end
    }
    fiber = nil
    with_ctx_values a: "this is a" do
      fiber = mkfiber[]
      ran += 1
    end
    expect(fiber.resume).to eq "this is a"
    expect(fiber.resume).to be_nil
    with_ctx_values b: "inheriting :b" do
      fiber = mkfiber[]
      ran += 1
    end
    expect(fiber.resume).to be_nil
    expect(fiber.resume).to eq "inheriting :b"
    expect(ran).to eq 2
  end

  # ...to ensure that this isn't only a monkeypatched Fiber.new, and will even
  # work with code that uses the CAPI to create fibers.
  it "is inherited by enumerator fibers" do
    ran = 0
    enum = Enumerator.new do |y|
      y.yield CoroCtx[:a]
      y.yield Enumerator.new {|y2| y2.yield CoroCtx[:b] }.next
    end
    with_ctx_values a: "this is a" do
      expect(enum.next).to eq "this is a"
      ran += 1
    end
    expect(enum.next).to be_nil # enum inherits context when fiber is created
    with_ctx_values b: "inheriting :b" do
      enum.rewind
      expect(enum.next).to be_nil
      ran += 1
    end
    expect(enum.next).to eq "inheriting :b"
    expect(ran).to eq 2
  end

  it "is inherited by new threads" do
    ran = 0
    q = Queue.new
    mkthread = -> {
      Thread.new do |y|
        q << CoroCtx[:a]
        q << Thread.new { CoroCtx[:b] }.value
      end
    }
    with_ctx_values a: "this is a" do
      mkthread[]
      ran += 1
    end
    expect(q.pop).to eq "this is a"
    expect(q.pop).to be_nil
    with_ctx_values b: "inheriting :b" do
      mkthread[]
      ran += 1
    end
    expect(q.pop).to be_nil
    expect(q.pop).to eq "inheriting :b"
    expect(ran).to eq 2
  end

  context "with multiple ractors" do
    context "when its elements aren't all ractor-sharable" do
      it "raises an exception for new ractors" do
        with_ctx_values foo: Object.new do
          expect { Ractor.new { :unreachable }.take }
            .to raise_error(Ractor::Error)
        end
      end
    end

    context "when its elements are all ractor-sharable" do
      it "is inherited by new ractors" do
        with_ctx_values foo: :bar, hoge: :fuga do
          r = Ractor.new do
            Ractor.yield CoroCtx[:foo]
            Ractor.yield Ractor.new { CoroCtx[:hoge] }.take
          end
          expect(r.take).to eq :bar
          expect(r.take).to eq :fuga
        end

        with_ctx_values foo: :bar, hoge: :fuga do
          r = Ractor.new do
            Ractor.yield CoroCtx[:foo]
            Ractor.yield Ractor.new { CoroCtx[:hoge] }.take
          end
          expect(r.take).to eq :bar
          expect(r.take).to eq :fuga
        end

        nested = with_ctx_values(a: "etc") {
          with_ctx_values(a: :testing) {
            Fiber.new do
              Ractor.new do
                Thread.new do
                  enum = Enumerator.new do |y|
                    r2 = Ractor.new { with_ctx_values(a: :r2) { CoroCtx[:a] } }
                    r3 = with_ctx_values(a: :r3) { Ractor.new { CoroCtx[:a] } }
                    y.yield(Ractor.new { CoroCtx[:a] }.take)
                    y.yield(Fiber.new { r2.take }.resume)
                    y.yield(Enumerator.new { _1.yield r3.take }.next)
                    y.yield(CoroCtx[:a])
                  end
                  e1 = with_ctx_values(a: :enum)     { enum.next }
                  e2 = with_ctx_values(a: :ignored1) { enum.next }
                  e3 = with_ctx_values(a: :ignored2) { enum.next }
                  e4 = with_ctx_values(a: :enum)     { enum.next }
                  {e1:, e2:, e3:, e4:}
                end.value
              end.take
            end.resume
          }
        }
        expect(nested).to eq e1: :enum, e2: :r2, e3: :r3, e4: :enum
      end
    end
  end

end

# rubocop:enable RSpec/DescribedClass, RSpec/MultipleExpectations
# rubocop:enable RSpec/ExampleLength
