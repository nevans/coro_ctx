# frozen_string_literal: true

module CoroCtx

  # enables CoroCtx inheritance by new Fibers. Threads, and Ractors.
  module Inheritance

    # handles fibers created by CAPI
    def self.fiber_switch_trace
      @fiber_switch_trace ||= TracePoint.new(:fiber_switch) do |tp|
        thr = Thread.current
        if (fvar = thr[CURRENT_CTX_VAR_NAME])
          # This handles e.g. fibers that were suspended and resumed.
          thr.thread_variable_set(CURRENT_CTX_VAR_NAME, fvar)
        elsif (tvar = thr.thread_variable_get(CURRENT_CTX_VAR_NAME))
          # This handles new fibers, including Enumerator fibers that are
          # implicitly created.
          thr[CURRENT_CTX_VAR_NAME] = tvar
        end
      end
    end
    private_class_method :fiber_switch_trace

    fiber_switch_trace.enable

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

    ::Fiber.singleton_class.instance_exec  { prepend FiberNewInheritance }
    ::Thread.singleton_class.instance_exec { prepend ThreadNewInheritance }

  end
end
