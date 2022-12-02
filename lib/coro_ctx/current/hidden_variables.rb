# frozen_string_literal: true

module CoroCtx
  module Current
    module HiddenVariables # :nodoc:
      EMPTY = {}.freeze
      private_constant :EMPTY

      CTX_VAR_NAME = :__CORO_CTX_CURRENT_CTX_VAR_NAME__
      private_constant :CTX_VAR_NAME

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

        def __synchronize_current_coro_ctx__!
          # warn [Ractor.current, Thread.current, self, __method__].join(" ")
          thr = Thread.current
          if (fvar = thr[CTX_VAR_NAME])
            # This handles e.g. fibers that were suspended and resumed.
            thr.thread_variable_set(CTX_VAR_NAME, fvar)
          elsif (tvar = thr.thread_variable_get(CTX_VAR_NAME))
            # This handles fibers that were created bypassing Fiber.new, e.g.
            # implicit Enumerator fibers.
            thr[CTX_VAR_NAME] = tvar
          elsif (rvar = RactorMediator.initial_ctx)
            Fiber.__current_coro_ctx__ = rvar
          end
        end
      end

      refine Ractor.singleton_class do
        def __init_current_coro_ctx__
          # warn [Ractor.current, Thread.current, self, __method__].join(" ")
        end

        def __done_current_coro_ctx__
          # warn [Ractor.current, Thread.current, self, __method__].join(" ")
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

    private_constant :HiddenVariables

  end
end
