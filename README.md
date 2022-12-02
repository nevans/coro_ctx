# ⚗️  CoroCtx

This is a set of experiments I threw together to demonstrate coroutine context
variables: dynamically scoped, automatically shared across fibers, threads, and
even ractors (WIP).  They can be thought of as safer version of global vars, or
as a way to the most common issues with Thread and Fiber locals.

This particular repo (or at least, this branch) is not an illustration of my
desired API, nor does it represent how I think this could be implemented "For
Real".  It was just something I threw together, mostly on my phone during a long
road trip.

I've written some version of this code at least half a dozen times, and some of
my earlier (simpler, no tracepoint) iterations have been used in production.
This code *has not* been used in production.  Caveat emptor.

At some point in my experimentation, I started playing more with building out
some haphazard tools for working with ractors, and I never did get the ractors
code to work the way I wanted.

## Installation

Don't install this.  Not yet, anyway.  ;P

## Usage

See the specs.

## Development

If you know, you know.

## Contributing

Bug reports are _unwelcome_ at this stage.  It's just a toy experiment! ⚗️

But pull requests and discussion 🙂, they _are_ welcome (at
https://github.com/nevans/coro_ctx).  This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to
the [code of conduct](https://github.com/nevans/coro_ctx/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CoroCtx project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow the [code of
conduct](https://github.com/nevans/coro_ctx/blob/main/CODE_OF_CONDUCT.md).
