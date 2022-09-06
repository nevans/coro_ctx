# frozen_string_literal: true

module CoroCtx

  # Defines the "current" CoroCtx, with accessor methods to query and update it.
  #
  module Current
    CTX_VAR_NAME = :__CORO_CTX_CURRENT_CTX_VAR_NAME__
    private_constant :CTX_VAR_NAME

    # :nodoc:
    module Impl
      refine Fiber.singleton_class do
        # TODO: fallback for non-main ractors
        def current_coro_ctx
          thr = Thread.current
          thr[CTX_VAR_NAME] ||=
            thr.thread_variable_get(CTX_VAR_NAME) ||
            RactorMediator.initial_ctx ||
            EMPTY
        end

        def __current_coro_ctx__=(ctx)
          thr = Thread.current
          thr[CTX_VAR_NAME] = ctx
          thr.thread_variable_set(CTX_VAR_NAME, ctx)
        end
      end

      # TODO: linked-list context object; not just a hash
      refine Hash do
        def with_values(**named_elements, &)
          ctx = merge(named_elements).freeze
          return ctx unless block_given?
          ctx.__exec__(&)
        end

        def __exec__
          prior = Fiber.current_coro_ctx
          Fiber.__current_coro_ctx__ = self
          yield
        ensure
          Fiber.__current_coro_ctx__ = prior
        end
      end
    end
    private_constant :Impl
    using Impl

    def self.[](...)   = Fiber.current_coro_ctx.[](...)
    def self.to_h(...) = Fiber.current_coro_ctx.to_h(...)

    module_function

    def with_values(...) = Fiber.current_coro_ctx.with_values(...)

    # TODO: how to re-establish trace in new ractors?
    def self.extend_core!
      ::Fiber.singleton_class.instance_exec  { prepend FiberNewInheritance }
      ::Thread.singleton_class.instance_exec { prepend ThreadNewInheritance }
      ::Ractor.singleton_class.instance_exec { prepend RactorNewInheritance }
      fiber_switch_trace
    end

    # To handle fibers created by the C API bypassing Fiber.new—e.g.
    # implicit Enumerator fibers—we use a thread variable as backup and use
    # +fiber_switch+ to synchronize with the fiber local variable.
    def self.fiber_switch_trace # rubocop:disable Metrics
      Ractor.current[:coro_ctx_trace] ||= TracePoint.new(:fiber_switch) do |tp|
        thr = Thread.current
        if (fvar = thr[CTX_VAR_NAME])
          # This handles e.g. fibers that were suspended and resumed.
          thr.thread_variable_set(CTX_VAR_NAME, fvar)
        elsif (tvar = thr.thread_variable_get(CTX_VAR_NAME))
          # This handles fibers that were created bypassing Fiber.new, e.g.
          # implicit Enumerator fibers.
          thr[CTX_VAR_NAME] = tvar
        elsif Ractor.current.main?
          Fiber.__current_coro_ctx__ = EMPTY
          # TODO: how to start tracing on new ractors?
        elsif (rvar = RactorMediator.initial_ctx)
          Fiber.__current_coro_ctx__ = rvar
        end
      end
    end
    private_class_method :fiber_switch_trace

    # When created via Fiber.new, we want the context from *definition*, not
    # from the first resume (as a +fiber_switch+ implementation would do).
    module FiberNewInheritance
      def new(ctx: {}, **fiber_opts, &block)
        prior_ctx = Thread.current[CTX_VAR_NAME] || EMPTY
        super(**fiber_opts) { CoroCtx.with_values(**prior_ctx, **ctx, &block) }
      end
    end

    # When created via Thread.new, we'll get the context from *definition*.
    module ThreadNewInheritance
      def new(*args, **kwargs, &block)
        ctx = Thread.current[CTX_VAR_NAME] || EMPTY
        super() { CoroCtx.with_values(**ctx) { block.call(*args, **kwargs) } }
      end
    end

    # registers the initial context for all new ractors
    module RactorNewInheritance
      def new(...)
        ctx = Thread.current[CTX_VAR_NAME]
        raise Ractor::Error, "Unshareable CoroCtx" unless Ractor.shareable?(ctx)
        return super unless RactorMediator.started?
        super.tap do |r| RactorMediator.new_ractor r, ctx end
      end
    end

  end
end
