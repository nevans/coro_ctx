# frozen_string_literal: true

module CoroCtx

  # An interface between different ractors, a registry of shared ctxs, and
  # signals between them.
  class RactorMediator

    ACTIONS = %i[
      init_ctx
      new_ractor
    ].freeze

    class << self
      def started? = !!$_coro_ctx_ractor_mediator_ # rubocop:disable Style/GlobalVars
      def new_ractor(...) = delegator.send(__method__, ...)
      def init_ctx(...)   = delegator.send(__method__, ...)

      private

      def delegator(...)
        $_coro_ctx_ractor_ ||= RactorDelegator.new self, ACTIONS # rubocop:disable Style/GlobalVars
      end
    end

    def initialize
      @root_ctxs = {}
    end

    def new_ractor(ractor, ctx) @root_ctxs[ractor] = ctx end
    def ctx_for(ractor)         @root_ctxs.fetch ractor end

  end
end
