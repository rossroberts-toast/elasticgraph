# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/graphql/resolvers/constant_value"

module ElasticGraph
  class GraphQL
    module Resolvers
      RSpec.describe ConstantValue do
        it "returns the configured `:value` regardless of the field, object, args, or context" do
          resolver = ConstantValue.new(elasticgraph_graphql: nil, config: {value: {}})

          result = resolver.resolve(field: :unused, object: :unused, args: :unused, context: :unused)

          expect(result).to eq({})
        end

        it "returns whatever object is passed as `:value`" do
          sentinel = ::Object.new
          resolver = ConstantValue.new(elasticgraph_graphql: nil, config: {value: sentinel})

          expect(resolver.resolve(field: :f, object: :o, args: :a, context: :c)).to be(sentinel)
        end

        it "raises when `:value` is missing from `config`" do
          expect {
            ConstantValue.new(elasticgraph_graphql: nil, config: {})
          }.to raise_error(KeyError, /value/)
        end
      end
    end
  end
end
