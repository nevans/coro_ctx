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

    # Because the tracepoint blocks are (or should be) ractor shareable, these
    # traces *should* automatically run in all ractors.
    module TraceFuncs # :nodoc:
      def self.enable = all_traces.map(&:enable)

      class << self
        private

        def all_traces = [fiber_switch, thread_begin, thread_end]

        # To handle fibers created by the C API bypassing Fiber.new—e.g.
        # implicit Enumerator fibers—we use a thread variable as backup and use
        # +fiber_switch+ to synchronize with the fiber local variable.
        def fiber_switch
          @fiber_switch ||= TracePoint.new(
            :fiber_switch,
            &Ractor.make_shareable(->(_) {
              Fiber.__synchronize_current_coro_ctx__!
            })
          )
        end

        # primarily used to detect new ractors
        def thread_begin
          @thread_begin ||= TracePoint.new(
            :thread_begin,
            &Ractor.make_shareable(->(_) { Ractor.__init_current_coro_ctx__ })
          )
        end

        # primarily used to detect ractors ending
        def thread_end
          @thread_end ||= TracePoint.new(
            :thread_end,
            &Ractor.make_shareable(->(_) { Ractor.__done_current_coro_ctx__ })
          )
        end
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
        TraceFuncs.enable
        RactorMediator.start!
        RactorMediator.ping => :pong # sanity check
        Fiber.singleton_class.instance_exec  { prepend FiberNewInheritance }
        Thread.singleton_class.instance_exec { prepend ThreadNewInheritance }
        Ractor.singleton_class.instance_exec { prepend RactorNewInheritance }
      end

    end

  end
end
