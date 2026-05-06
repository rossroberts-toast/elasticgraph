# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

module ElasticGraph
  class GraphQL
    module Resolvers
      # Returns a configured constant value for a field, regardless of its inputs. Primarily used for
      # namespace fields (e.g. `Query.olap`), which must return a non-null object but carry no data of
      # their own — their child fields have their own resolvers.
      class ConstantValue
        def initialize(elasticgraph_graphql:, config:)
          @value = config.fetch(:value)
        end

        def resolve(field:, object:, args:, context:)
          @value
        end
      end
    end
  end
end
