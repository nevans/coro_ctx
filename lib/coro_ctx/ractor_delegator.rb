# frozen_string_literal: true

module CoroCtx

  # creates a ractor, instantiates an object in that ractor, and delegates calls
  # to it.
  class RactorDelegator
    attr_reader :klass, :ractor, :delegated_methods

    def initialize(klass, delegated_methods)
      @delegated_methods = delegated_methods.map { _1 => Symbol; _1 }.freeze
      @klass  = klass
      @ractor = Ractor.new do RactorDelegator.run Ractor.receive end
      freeze
      ractor.send self # ractor can't reference self before freeze
    end

    # depends on #ractor, which must return the remote ractor
    def send(action, *args)
      delegated_methods.include?(action) or raise ArgumentError
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
      allowed = delegator.delegated_methods
      current = Ractor.current
      loop do
        Ractor.receive => :call, Ractor => sender, ^allowed => action, *args
        sender.send result_for { object.public_send(action, *args) }
      rescue => error
        warn "Error in %p: [%s] %s" % [current, error.class, error]
      end
    end

    def result_for
      [:ok,    Ractor.current, yield]
    rescue Exception => ex # rubocop:disable Lint/RescueException
      [:error, Ractor.current, ex] # assumes ex can be shared...
    end

  end
end
