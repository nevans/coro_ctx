# frozen_string_literal: true

module CoroCtx

  # creates a ractor, instantiates an object in that ractor, and delegates calls
  # to it.
  #
  # TODO... basic ractor signals:
  #     signal        => [signame, sender, receiver, sigrel, sigargs]
  #
  #     ractor_var    => [:setvar, sender, receiver, :parent, Hash[Symbol, val]]
  #     set_init_ctx  => [:setvar, sender, receiver, :parent, {init_ctx:}]
  #
  #     exit_signal   => [:exit, sender, receiver, relation, reason]
  #     relation      => :parent | :child | :link | nil
  #     reason        => [:ok, value]
  #                    | [:cancel, value]
  #                    | [:raise, Exception | [klass, message, backtrace]]
  #                    | :kill
  #                    | :killed
  class RactorDelegator
    attr_reader :klass, :ractor

    def initialize(klass, name: RactorDelegator.name)
      @klass  = klass
      @ractor = Ractor.new(name:) do RactorDelegator.run Ractor.receive end
      freeze
      ractor.send self # ractor can't reference self before freeze
    end

    def cast(method, *args) = ractor.send [:cast, method, args]

    # depends on #ractor, which must return the remote ractor
    def call(method, *args, timeout: nil)
      resp = Responder.new(Ractor.current)
      ractor.send [:call, resp, Ractor.current, method, args, timeout]
      receive_reply(resp)
    end

    def self.run(delegator)
      object = delegator.klass.new
      while true # rubocop:disable Style/InfiniteLoop
        case Ractor.receive
        in :call, Responder => resp, Ractor, method, args, _timeout
          resp.returning { object.public_send(method, *args) }
        end
      end
    end

    private

    def receive_reply(resp)
      while true # rubocop:disable Style/InfiniteLoop
        case Ractor.receive_if { _1 in Symbol, Responder, Result }
        in :return, ^resp, Result(value:) then return value
        in :return, ^resp, Result(error:) then raise  error
        in :return, *                     then :drop_return
        end
      end
    end

    # extend a class with this, then call "delegate_to_ractor :method"
    #
    module DelegatedClassMethods
      attr_reader :ractor_delegator

      def started? = !!ractor_delegator

      def start!
        raise "already started" if started?
        @ractor_delegator = RactorDelegator.new(self, name:)
      end

      private

      def guard_cast!(method)
        raise "bad send" if Ractor.current == ractor_delegator
        raise "unstarted" unless started?
        unless instance_methods.include?(method)
          raise NoMethodError, "cannot delegate #{method}"
        end
      end

      def cast(method, ...)
        guard_cast!(method)
        ractor_delegator.send(method, ...)
      end

      def call(method, ...)
        guard_cast!(method)
        ractor_delegator.call(method, ...)
      end
    end

    class Responder # :nodoc:
      attr_reader :sender

      def initialize(sender)
        sender => Ractor
        @sender = sender
        freeze
      end

      def returning(&) = sender.send [:return, self, Result.new(&)]
    end

    class Result # :nodoc:
      attr_reader :value, :error

      def initialize(copy_value: true, copy_error: true, match: Exception)
        @value = Ractor.make_shareable(yield, copy: copy_value)
      rescue match => error
        @error = wrap_error(error, copy_error)
      ensure
        freeze
      end

      def deconstruct = error ? [:error, error] : [:value, value]
      def deconstruct_keys(...) = error ? {error:} : {value:}

      private

      def wrap_error(error, copy)
        Ractor.make_shareable(error, copy:)
      rescue
        RuntimeError.new("[%s] %s" % [error.class, error.message])
          .tap  do _1.set_backtrace error.backtrace end
          .then do Ractor.make_shareable _1 end
        @error = error
      end
    end

  end
end
