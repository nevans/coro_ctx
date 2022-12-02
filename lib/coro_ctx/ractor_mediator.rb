# frozen_string_literal: true

module CoroCtx

  # An interface between different ractors, a registry of shared ctxs, and
  # signals between them.
  #
  # Used to support:
  # * context inheritence
  # * context signals:
  #   * Context#cancel(reason), Context#raise(*exception)
  # * context completion:
  #   * Context#wait, Context#done?, Context#error?
  #   * Context#result, Context#value, Context#error
  #
  # TODO: handling exits, links, monitors, parents, children all as signals
  class RactorMediator
    extend RactorDelegator::DelegatedClassMethods

    class << self
      def initial_ctx
        return nil if Ractor.current == Ractor.main || !started?
        tries ||= 0
        ractor_get_ctx(Ractor.current)
      rescue KeyError
        raise unless (tries += 1) <= 10
        sleep 0.010
        retry
      end

      def ping(...)            = call(__method__, ...)
      def ractor_set_ctx(...)  = call(__method__, ...)
      def ractor_get_ctx(...)  = call(__method__, ...)
    end

    attr_reader :ractor_ctxs

    def initialize
      @ractor_ctxs   = {}
    end

    def ping = :pong

    def ractor_set_ctx(ractor, ctx)
      ractor_ctxs[ractor] = ctx
    end

    def ractor_get_ctx(ractor)
      ractor_ctxs.fetch(ractor)
    end

  end
end
