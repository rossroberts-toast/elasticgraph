# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/errors"
require "elastic_graph/schema_definition/schema_elements/object_type"

module ElasticGraph
  module SchemaDefinition
    module SchemaElements
      # {include:API#namespace_type}
      #
      # A namespace type is an {ObjectType} that exists purely to group fields on `Query` (or on
      # another namespace type) under a shared path. It cannot be indexed, and fields on a namespace
      # type whose return type is another namespace type are auto-wired to the built-in
      # `:constant_value` resolver.
      #
      # @example Define a namespace type
      #   ElasticGraph.define_schema do |schema|
      #     schema.namespace_type "OlapQuery" do |t|
      #       # in the block, `t` is a NamespaceType
      #     end
      #   end
      class NamespaceType < ObjectType
        # @private
        def initialize(schema_def_state, name)
          super(schema_def_state, name) do |type|
            type.resolve_fields_with nil
            yield type if block_given?
          end
          schema_def_state.after_user_definition_complete { auto_wire_namespace_subfields }
        end

        # @return [Boolean] always `true` for a namespace type.
        def namespace?
          true
        end

        # Namespace types cannot be indexed.
        # @raise [Errors::SchemaError] always
        # @private
        def index(name, **settings, &block)
          raise Errors::SchemaError, "`#{self.name}` cannot be both an indexed type and a namespace type."
        end

        private

        # Auto-assigns `:constant_value` to fields on this namespace type whose return type is itself a namespace
        # type, as long as the field has no arguments and no explicitly assigned resolver. This spares the schema
        # author from wiring a trivial resolver on every intermediate namespace field.
        def auto_wire_namespace_subfields
          graphql_fields_by_name.each_value do |field|
            next unless field.args.empty?
            next unless field.resolver.nil?

            return_type_name = field.type.fully_unwrapped.name
            return_type = schema_def_state.object_types_by_name[return_type_name]
            next unless return_type.is_a?(NamespaceType)

            field.resolve_with :constant_value, value: {}
          end
        end
      end
    end
  end
end
