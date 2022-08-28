# frozen_string_literal: true

module CoroCtx

  # enables CoroCtx inheritance by new Fibers. Threads, and Ractors.
  module Inheritance

    # TODO: how to re-establish trace in new ractors?
    def self.extend_core!
      fiber_switch_trace.enable
      ::Fiber.singleton_class.instance_exec  { prepend FiberNewInheritance }
      ::Thread.singleton_class.instance_exec { prepend ThreadNewInheritance }
      ::Ractor.singleton_class.instance_exec { prepend RactorNewInheritance }
    end

    # To handle fibers created by the C API bypassing Fiber.new—e.g.
    # implicit Enumerator fibers—we use a thread variable as backup and use
    # +fiber_switch+ to synchronize with the fiber local variable.
    def self.fiber_switch_trace
      @fiber_switch_trace ||= TracePoint.new(:fiber_switch) do |tp|
        thr = Thread.current
        if (fvar = thr[CURRENT_CTX_VAR_NAME])
          # This handles e.g. fibers that were suspended and resumed.
          thr.thread_variable_set(CURRENT_CTX_VAR_NAME, fvar)
        elsif (tvar = thr.thread_variable_get(CURRENT_CTX_VAR_NAME))
          # This handles fibers that were created bypassing Fiber.new, e.g.
          # implicit Enumerator fibers.
          thr[CURRENT_CTX_VAR_NAME] = tvar
        end
      end
    end
    private_class_method :fiber_switch_trace

    # When created via Fiber.new, we want the context from *definition*, not
    # from the first resume (as a +fiber_switch+ implementation would do).
    module FiberNewInheritance
      def new(ctx: {}, **fiber_opts, &block)
        prior_ctx = Thread.current[CURRENT_CTX_VAR_NAME] || EMPTY
        super(**fiber_opts) { CoroCtx.with_values(**prior_ctx, **ctx, &block) }
      end
    end

    # When created via Thread.new, we'll get the context from *definition*.
    module ThreadNewInheritance
      def new(*args, **kwargs, &block)
        ctx = Thread.current[CURRENT_CTX_VAR_NAME] || EMPTY
        super() { CoroCtx.with_values(**ctx) { block.call(*args, **kwargs) } }
      end
    end

    # registers the initial context for all new ractors
    module RactorNewInheritance
      def new(...)
        ctx = Thread.current[CURRENT_CTX_VAR_NAME]
        raise Ractor::Error, "Unshareable CoroCtx" unless Ractor.shareable?(ctx)
        return super unless RactorMediator.started?
        super.tap do |r| RactorMediator.new_ractor r, ctx end
      end
    end

  end
end
