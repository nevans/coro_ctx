# frozen_string_literal: true

require_relative "current/hidden_variables"

module CoroCtx

  # Defines the "current" CoroCtx, with accessor methods to query and update it.
  #
  module Current
    using HiddenVariables

    # When created via Fiber.new, we want the context from *definition*, not
    # from the first resume (as a +fiber_switch+ implementation would do).
    module FiberNewInheritance
      def new(ctx: {}, **fiber_opts, &block)
        prior_ctx = Fiber.current_coro_ctx
        super(**fiber_opts) { CoroCtx.with_values(**prior_ctx, **ctx, &block) }
      end
    end

    # When created via Thread.new, we'll get the context from *definition*.
    module ThreadNewInheritance
      def new(*args, **kwargs, &block)
        ctx = Fiber.current_coro_ctx
        super() { CoroCtx.with_values(**ctx) { block.call(*args, **kwargs) } }
      end
    end

    # registers the initial context for all new ractors
    #
    # Ractor.new isolation is different from Ractor.make_sharable(proc)?
    module RactorNewInheritance
      def new(...)
        ctx = Fiber.current_coro_ctx
        raise Ractor::Error, "Unshareable CoroCtx" unless Ractor.shareable?(ctx)
        super.tap do |r| RactorMediator.ractor_set_ctx r, ctx end
      end
    end

    def self.[](...)   = Fiber.current_coro_ctx.[](...)
    def self.to_h(...) = Fiber.current_coro_ctx.to_h(...)

    module_function

    def with_values(...) = Fiber.current_coro_ctx.with_values(...)

    class << self
      # TODO: create new cancel ctx, call ractor_done, etc
      # TODO: how to re-establish tracepoint in new ractors?
      def extend_core!
        fiber_switch_trace.enable
        RactorMediator.start!
        RactorMediator.ping => :pong # sanity check
        Fiber.singleton_class.instance_exec  { prepend FiberNewInheritance }
        Thread.singleton_class.instance_exec { prepend ThreadNewInheritance }
        Ractor.singleton_class.instance_exec { prepend RactorNewInheritance }
      end

      private

      # To handle fibers created by the C API bypassing Fiber.new—e.g.
      # implicit Enumerator fibers—we use a thread variable as backup and use
      # +fiber_switch+ to synchronize with the fiber local variable.
      #
      # Because the tracepoint block should be ractor shareable, it should
      # automatically run in all ractors.
      def fiber_switch_trace
        @fiber_switch_trace ||= TracePoint.new(:fiber_switch) do
          Fiber.__synchronize_current_coro_ctx__!
        end
      end
    end

  end
end
