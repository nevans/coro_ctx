# frozen_string_literal: true

require_relative "coro_ctx/version"

# Context values with dynamic scope, inherited by fibers, threads, and even
# ractors.
#
# TODO: documentation...
module CoroCtx
  class Error < StandardError; end

  CURRENT_CTX_VAR_NAME = :__CORO_CTX_CURRENT_CTX_VAR_NAME__
  private_constant :CURRENT_CTX_VAR_NAME

  refine Kernel do
    def with_ctx_values(...) = CoroCtx.with_values(...)
  end

  def self.[](key)
    ctx = Thread.current[CURRENT_CTX_VAR_NAME]
    ctx&.[](key)
  end

  def self.with_values(**named_elements)
    thr = Thread.current
    original_ctx = thr[CURRENT_CTX_VAR_NAME]
    ctx = {**(original_ctx || {}), **named_elements}.freeze
    thr[CURRENT_CTX_VAR_NAME] = ctx
    raise ArgumentError, "expected block" unless block_given?
    yield
  ensure
    thr[CURRENT_CTX_VAR_NAME] = original_ctx
  end

end