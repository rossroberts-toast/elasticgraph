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
          # JRuby emits spurious warnings about Struct#initialize when using *args, **kwargs.
          # Suppress warnings during the super call on JRuby only.
          # :nocov: -- JRuby-specific warning suppression
          if RUBY_ENGINE == "jruby"
            verbose, $VERBOSE = $VERBOSE, nil
            begin
              __skip__ = super(*args, **kwargs)
            ensure
              $VERBOSE = verbose
            end
          else
            # :nocov:
            __skip__ = super(*args, **kwargs) # __skip__ tells Steep to ignore this
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
