# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "delegate"
require "elastic_graph/errors"
require "elastic_graph/schema_definition/mixins/has_indices"
require "elastic_graph/schema_definition/mixins/has_readable_to_s_and_inspect"
require "elastic_graph/schema_definition/mixins/implements_interfaces"
require "elastic_graph/schema_definition/schema_elements/type_with_subfields"

module ElasticGraph
  module SchemaDefinition
    module SchemaElements
      # {include:API#object_type}
      #
      # @example Define an object type
      #   ElasticGraph.define_schema do |schema|
      #     schema.object_type "Money" do |t|
      #       # in the block, `t` is an ObjectType
      #     end
      #   end
      class ObjectType < DelegateClass(TypeWithSubfields)
        # DelegateClass(TypeWithSubfields) provides the following methods:
        # @dynamic name, type_ref, to_sdl, derived_graphql_types, to_indexing_field_type, current_sources, index_field_runtime_metadata_tuples, graphql_only?, relay_pagination_type
        include Mixins::SupportsFilteringAndAggregation

        # `include HasIndices` provides the following methods:
        # @dynamic runtime_metadata, derived_indexed_types, indices, root_document_type?, abstract?, directly_queryable?
        include Mixins::HasIndices

        # `include ImplementsInterfaces` provides the following methods:
        # @dynamic verify_graphql_correctness!
        include Mixins::ImplementsInterfaces
        include Mixins::HasReadableToSAndInspect.new { |t| t.name }

        # @return [Hash<String, Field>] fields that will be indexed, including __typename for mixed-type indices (types
        # that inherit an index from an abstract supertype)
        # @private
        def indexing_fields_by_name_in_index
          return super if has_own_index_def?
          return super unless root_document_type?

          super.merge("__typename" => schema_def_state.factory.new_field(name: "__typename", type: "String", parent_type: self))
        end

        # @return [Boolean] true if this type was declared via {API#namespace_type} and groups root query fields.
        def namespace?
          @namespace == true
        end

        # @private
        def __mark_as_namespace_type!
          @namespace = true
          schema_def_state.after_user_definition_complete { auto_wire_namespace_subfields }
        end

        # @private
        def initialize(schema_def_state, name)
          field_factory = schema_def_state.factory.method(:new_field)
          schema_def_state.factory.new_type_with_subfields(:type, name, wrapping_type: self, field_factory: field_factory) do |type|
            __skip__ = super(type) do
              yield self
            end
          end
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
            next unless return_type.is_a?(ObjectType) && return_type.namespace?

            field.resolve_with :constant_value, value: {}
          end
        end
      end
    end
  end
end
