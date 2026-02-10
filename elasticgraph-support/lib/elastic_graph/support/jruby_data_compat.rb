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

        # Store the original initialize to wrap it
        original_initialize = data_class.instance_method(:initialize)

        # Override initialize to reorder kwargs before processing
        data_class.define_method(:initialize) do |*args, **kwargs|
          # JRuby bug: kwargs don't preserve member order, causing wrong field assignment
          # Solution: reorder kwargs to match member order before calling original
          klass = self.class

          if args.empty? && !kwargs.empty?
            # Only kwargs - reorder to match member order
            ordered_kwargs = klass.members.to_h { |member| [member, kwargs.fetch(member)] }
            original_initialize.bind(self).call(**ordered_kwargs)
          elsif !args.empty? && kwargs.empty?
            # Only positional args
            original_initialize.bind(self).call(*args)
          elsif !args.empty? && !kwargs.empty?
            # Both - merge and reorder
            positional_as_kwargs = klass.members[0...args.size].zip(args).to_h
            merged = positional_as_kwargs.merge(kwargs)
            ordered_kwargs = klass.members.to_h { |member| [member, merged.fetch(member)] }
            original_initialize.bind(self).call(**ordered_kwargs)
          else
            # Both empty
            original_initialize.bind(self).call()
          end
        end

        data_class
      end
    end
  end
end
