# frozen_string_literal: true

module CoroCtx

  # creates a ractor, instantiates an object in that ractor, and delegates calls
  # to it.
  class RactorDelegator
    attr_reader :klass, :ractor

    def initialize(klass, name: RactorDelegator.name)
      @klass  = klass
      @ractor = Ractor.new(name:) do RactorDelegator.run Ractor.receive end
      freeze
      ractor.send self # ractor can't reference self before freeze
    end

    # depends on #ractor, which must return the remote ractor
    def send(action, *args)
      r = ractor
      r.send [:call, Ractor.current, action, *args]
      case Ractor.receive
      in :ok,    ^r, value then value
      in :error, ^r, error then raise error
      in unknown then raise "unexpected resp: %p" % unknown
      end
    end

    def self.run(delegator)
      object  = delegator.klass.new
      current = Ractor.current
      loop do
        Ractor.receive => :call, Ractor => sender, Symbol => action, *args
        sender.send result_for { object.public_send(action, *args) }.tap {p _1}
      rescue => error
        warn "processing %s for %p" % [action, sender] if sender && action
        warn "Error in %p: [%s] %s" % [current, error.class, error]
        warn " - %s " % error.backtrace.join("\n - ")
      end
    end

    def self.result_for
      [:ok,    Ractor.current, yield]
    rescue Exception => ex # rubocop:disable Lint/RescueException
      [:error, Ractor.current, ex] # assumes ex can be shared...
    end

  end
end
