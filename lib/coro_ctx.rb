# frozen_string_literal: true

# Context values with dynamic scope, inherited by fibers, threads, and even
# ractors.
#
# TODO: documentation...
module CoroCtx
  autoload :Current,         "#{__dir__}/coro_ctx/current"
  autoload :RactorDelegator, "#{__dir__}/coro_ctx/ractor_delegator"
  autoload :RactorMediator,  "#{__dir__}/coro_ctx/ractor_mediator"
  autoload :VERSION,         "#{__dir__}/coro_ctx/version"

  class Error < StandardError; end

  refine Kernel do
    module_function

    def with_ctx_values(...) = Current.with_values(...)
  end

  def self.[](...)          = Current.[](...)
  def self.with_values(...) = Current.with_values(...)

end

CoroCtx::Current.extend_core!
