# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

# JRuby compatibility layer for Ruby Data class
#
# Problem: JRuby 10.0.2.0's Data class doesn't handle splat args with keyword args
# the same way as MRI Ruby 3.4. Specifically, calling new(*args, **kwargs) where
# both args and kwargs are provided causes issues. Additionally, the Data#initialize
# method also has issues with keyword arguments.
#
# This patch wraps Data.define to make both new and initialize methods work correctly
# by always using positional arguments internally.

if RUBY_ENGINE == "jruby"
  puts "[JRuby Compatibility] Loading Data class compatibility layer..."

  # Store original Data.define
  class Data
    class << self
      alias_method :jruby_original_define, :define

      def define(*member_names, &block)
        # Call original define
        data_class = jruby_original_define(*member_names, &block)

        # Get the original new as an unbound method to preserve class context
        original_new = data_class.singleton_class.instance_method(:new)

        # Override new to handle both positional and keyword arguments flexibly
        # Always convert to positional args to avoid JRuby bugs
        data_class.define_singleton_method(:new) do |*args, **kwargs|
          # Get reference to the data class (self in this context)
          klass = self

          # Case 1: Only positional args (normal case) - pass through
          if kwargs.empty?
            return original_new.bind_call(klass, *args)
          end

          # Case 2: Only keyword args - pass through as kwargs
          # The JRuby bug is specifically with mixed positional+keyword args, not pure kwargs.
          # Pure kwargs need to pass through so that custom initialize can merge defaults.
          if args.empty?
            return original_new.bind_call(klass, **kwargs)
          end

          # Case 3: Both positional and keyword args (merge them)
          # Assume positional args come first, then fill remaining with kwargs
          merged_args = args.dup

          # Add missing members from kwargs
          remaining_members = klass.members[args.size..] || []
          remaining_members.each do |member|
            merged_args << kwargs[member] if kwargs.key?(member)
          end

          original_new.bind_call(klass, *merged_args)
        end

        data_class
      end
    end
  end

  puts "[JRuby Compatibility] Data class patched successfully"
end
