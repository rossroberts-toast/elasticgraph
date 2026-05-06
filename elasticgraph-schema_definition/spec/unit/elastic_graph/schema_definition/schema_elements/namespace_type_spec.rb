# Copyright 2024 - 2026 Block, Inc.
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "elastic_graph/errors"
require "elastic_graph/spec_support/schema_definition_helpers"

module ElasticGraph
  module SchemaDefinition
    RSpec.describe "#namespace_type" do
      include_context "SchemaDefinitionHelpers"

      it "registers the type as a NamespaceType (which is an ObjectType)" do
        results = define_schema(schema_element_name_form: "snake_case") do |schema|
          schema.namespace_type "OlapQuery"
        end

        type = results.state.object_types_by_name.fetch("OlapQuery")
        expect(type).to be_a(SchemaElements::NamespaceType)
        expect(type).to be_a(SchemaElements::ObjectType)
        expect(type.namespace?).to be true
        expect(type.directly_queryable?).to be false
      end

      it "is not marked as a namespace for a regular `object_type`" do
        results = define_schema(schema_element_name_form: "snake_case") do |schema|
          schema.object_type "Plain" do |t|
            t.field "id", "ID"
          end
        end

        plain = results.state.object_types_by_name.fetch("Plain")
        expect(plain).not_to be_a(SchemaElements::NamespaceType)
        expect(plain.namespace?).to be false
      end

      it "yields the type to a block for further customization (documentation, directives, fields)" do
        results = define_schema(schema_element_name_form: "snake_case") do |schema|
          schema.namespace_type "OlapQuery" do |t|
            t.documentation "Namespace for OLAP query fields."
          end
        end

        type = results.state.object_types_by_name.fetch("OlapQuery")
        expect(type.doc_comment).to eq "Namespace for OLAP query fields."
      end

      it "disallows calling `index` on a namespace type" do
        expect {
          define_schema(schema_element_name_form: "snake_case") do |schema|
            schema.namespace_type "OlapQuery" do |t|
              t.field "id", "ID"
              t.index "olap_queries"
            end
          end
        }.to raise_error(Errors::SchemaError, /cannot be both an indexed type and a namespace type/)
      end

      context "auto-wiring of `:constant_value` for fields that return a namespace type" do
        def resolver_for(type_name, field_name, &schema_block)
          results = define_schema(schema_element_name_form: "snake_case", &schema_block)
          metadata = results.runtime_metadata.object_types_by_name.fetch(type_name)
          metadata.graphql_fields_by_name.fetch(field_name).resolver
        end

        it "auto-wires a no-arg, no-resolver field on a namespace type that returns another namespace type" do
          resolver = resolver_for("OlapQuery", "domain") do |schema|
            schema.namespace_type "OlapQuery" do |t|
              t.field "domain", "DomainQuery"
            end
            schema.namespace_type "DomainQuery"
          end

          expect(resolver).to have_attributes(name: :constant_value, config: {value: {}})
        end

        it "auto-wires a no-arg, no-resolver field on `Query` that returns a namespace type" do
          resolver = resolver_for("Query", "olap") do |schema|
            schema.namespace_type "OlapQuery"
            schema.on_root_query_type do |t|
              t.field "olap", "OlapQuery!"
            end
          end

          expect(resolver).to have_attributes(name: :constant_value, config: {value: {}})
        end

        it "auto-wires a no-arg, no-resolver field on a regular `object_type` that returns a namespace type" do
          resolver = resolver_for("Regular", "domain") do |schema|
            schema.namespace_type "DomainQuery"
            schema.object_type "Regular" do |t|
              t.resolve_fields_with :get_record_field_value
              t.field "id", "ID"
              t.field "domain", "DomainQuery"
              t.index "regulars"
            end
          end

          expect(resolver).to have_attributes(name: :constant_value, config: {value: {}})
        end

        it "does not auto-wire a field whose return type is a regular object type" do
          expect {
            resolver_for("OlapQuery", "plain") do |schema|
              schema.object_type "Plain" do |t|
                t.field "id", "ID"
              end
              schema.namespace_type "OlapQuery" do |t|
                t.field "plain", "Plain"
              end
            end
          }.to raise_error(Errors::SchemaError, /`OlapQuery\.plain` needs a resolver/)
        end

        it "does not override an explicit resolver" do
          resolver = resolver_for("OlapQuery", "domain") do |schema|
            schema.namespace_type "OlapQuery" do |t|
              t.field "domain", "DomainQuery" do |f|
                f.resolve_with :get_record_field_value
              end
            end
            schema.namespace_type "DomainQuery"
          end

          expect(resolver).to have_attributes(name: :get_record_field_value)
        end

        it "does not auto-wire a field that takes arguments" do
          expect {
            resolver_for("OlapQuery", "domain") do |schema|
              schema.namespace_type "OlapQuery" do |t|
                t.field "domain", "DomainQuery" do |f|
                  f.argument "key", "String!"
                end
              end
              schema.namespace_type "DomainQuery"
            end
          }.to raise_error(Errors::SchemaError, /`OlapQuery\.domain` needs a resolver/)
        end
      end
    end
  end
end
