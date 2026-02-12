# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/constants"

module ElasticGraph
  module SchemaDefinition
    module Mixins
      # Used to verify the validity of the name of GraphQL schema elements.
      #
      # @note This mixin is designed to be used via `prepend`, so it can add a constructor override that enforces
      # the GraphQL name pattern as the object is built.
      module VerifiesGraphQLName
        # @private
        def initialize(*args, **kwargs)
          if RUBY_ENGINE == "jruby"
            # On JRuby, convert keyword args to positional args to avoid splat forwarding bug
            if kwargs.any? && args.empty?
              positional_args = self.class.members.map { |member| kwargs.fetch(member) }
              __skip__ = super(*positional_args) # __skip__ tells Steep to ignore this
            else
              # Already positional args
              __skip__ = super(*args) # __skip__ tells Steep to ignore this
            end
          else
            # On MRI, use normal forwarding
            __skip__ = super(...) # __skip__ tells Steep to ignore this
          end

          VerifiesGraphQLName.verify_name!(name)
        end

        # Raises if the provided name is invalid.
        #
        # @param name [String] name of GraphQL schema element
        # @return [void]
        # @raise [Errors::InvalidGraphQLNameError] if the name is invalid
        def self.verify_name!(name)
          return if GRAPHQL_NAME_PATTERN.match?(name)
          raise Errors::InvalidGraphQLNameError, "Not a valid GraphQL name: `#{name}`. #{GRAPHQL_NAME_VALIDITY_DESCRIPTION}"
        end
      end
    end
  end
end
