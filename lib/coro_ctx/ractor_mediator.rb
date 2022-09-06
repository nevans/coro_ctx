# frozen_string_literal: true

module CoroCtx

  # An interface between different ractors, a registry of shared ctxs, and
  # signals between them.
  class RactorMediator

    class << self
      def started? = !!$_coro_ctx_ractor_mediator_ # rubocop:disable Style/GlobalVars

      def initial_ctx = ractor_get_ctx Ractor.current

      def ractor_set_ctx(...)  = send(__method__, ...)
      def ractor_get_ctx(...)  = send(__method__, ...)
      def ctx_subscribe(...)   = send(__method__, ...)
      def ctx_unsubscribe(...) = send(__method__, ...)
      def ctx_publish(...)     = send(__method__, ...)
      def ctx_done(...)        = send(__method__, ...)
      def ractor_done(...)     = send(__method__, ...)

      private

      def send(method, ...)
        unless instance_methods.include?(method)
          raise NoMethodError, "cannot delegate #{method}"
        end
        delegator.send(method, ...)
      end

      # rubocop:disable Style
      def delegator = ($_coro_ctx_ractor_)
    end

    $_coro_ctx_ractor_ ||= RactorDelegator.new(self, name:)
    # rubocop:enable Style

    # Stores any unread notifications for each ractor.
    # Each mbox is cleared when its notifications are retreived.
    attr_reader :ractor_mboxes
    attr_reader :ractor_ctxs
    attr_reader :ractor_subs

    # Stores any mboxes with subscriptions to each context
    attr_reader :context_subs

    def initialize
      @ractor_ctxs   = {}
      @ractor_mboxes = Hash.new {|h, ractor| h[ractor] = [] }
      @ractor_subs   = Hash.new {|h, ctx| h[ctx] = Set.new.compare_by_identity }
      @context_subs  = Hash.new {|h, ctx| h[ctx] = Set.new.compare_by_identity }
    end

    def ractor_set_ctx(ractor, ctx) ractor_ctxs[ractor] = ctx end
    def ractor_get_ctx(ractor)      ractor_ctxs.delete ractor end

    def ractor_done(ractor, result = {ok: nil})
      # all relevant ctx_done should already have been called (... or?)
      # so, shouldn't need to clean out context_subs
      ractor_subs.each do |ctx| ctx_unsubscribe ractor, ctx end
      ractor_subs.delete ractor
      ractor_ctxs.delete ractor
      ractor_mboxes.delete ractor # too late for unread notifications
    end

    def ctx_done(context, result)
      publish context, {context:, result:}
      context_subs.delete context
      nil
    end

    def ctx_subscribe(ctx, ractor)
      context_subs[ctx] << ractor_mboxes[ractor]
    end

    # n.b. this doesn't read any signals
    def ctx_unsubscribe(ctx, ractor)
      return unless (subs = context_subs.fetch(ctx, nil))
      return unless (mbox = ractor_mboxes.fetch(ractor, nil))
      subs.delete?(mbox)
    end

    def ctx_publish(ctx, payload)
      return unless context_subs.key? ctx
      context_subs[ctx].each do |sub| sub << payload end
      true
    end

  end
end
