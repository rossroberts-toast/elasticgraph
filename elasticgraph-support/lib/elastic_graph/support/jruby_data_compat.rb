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
# both args and kwargs are provided causes issues, and kwargs order is not preserved.
#
# This patch wraps Data.define to make the new method more flexible.

if RUBY_ENGINE == "jruby"
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
        data_class.define_singleton_method(:new) do |*args, **kwargs|
          # Get reference to the data class (self in this context)
          klass = self

          # Case 1: Only positional args (normal case)
          if kwargs.empty?
            return original_new.bind(klass).call(*args)
          end

          # Case 2: Only keyword args
          # Pass through as kwargs - let the original Data class and custom initialize handle it
          if args.empty?
            return original_new.bind(klass).call(**kwargs)
          end

          # Case 3: Both positional and keyword args (merge them)
          # This is the problematic case in JRuby
          # Assume positional args come first, then fill remaining with kwargs
          merged_args = args.dup

          # Add missing members from kwargs
          remaining_members = klass.members[args.size..-1] || []
          remaining_members.each do |member|
            merged_args << kwargs[member] if kwargs.key?(member)
          end

          return original_new.bind(klass).call(*merged_args)
        end

        data_class
      end
    end
  end
end
