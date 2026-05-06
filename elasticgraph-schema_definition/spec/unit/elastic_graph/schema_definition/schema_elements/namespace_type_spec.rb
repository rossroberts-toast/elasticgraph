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

      context "auto-wiring of `:constant_value` for namespace subfields" do
        it "auto-wires a no-arg, no-resolver field on a namespace type that returns another namespace type" do
          results = define_schema(schema_element_name_form: "snake_case") do |schema|
            schema.namespace_type "OlapQuery" do |t|
              t.field "domain", "DomainQuery"
            end
            schema.namespace_type "DomainQuery"
          end

          olap = results.state.object_types_by_name.fetch("OlapQuery")
          domain_field = olap.graphql_fields_by_name.fetch("domain")
          resolver = domain_field.resolver
          expect(resolver).not_to be_nil
          expect(resolver.name).to eq :constant_value
          expect(resolver.config).to eq({value: {}})
        end

        it "does not auto-wire a field on a namespace type whose return type is a regular object type" do
          results = define_schema(schema_element_name_form: "snake_case") do |schema|
            schema.object_type "Plain" do |t|
              t.field "id", "ID"
            end
            schema.namespace_type "OlapQuery" do |t|
              t.field "plain", "Plain"
            end
          end

          olap = results.state.object_types_by_name.fetch("OlapQuery")
          expect(olap.graphql_fields_by_name.fetch("plain").resolver).to be_nil
        end

        it "does not auto-wire a field that already has an explicit resolver" do
          results = define_schema(schema_element_name_form: "snake_case") do |schema|
            schema.namespace_type "OlapQuery" do |t|
              t.field "domain", "DomainQuery" do |f|
                f.resolve_with :get_record_field_value
              end
            end
            schema.namespace_type "DomainQuery"
          end

          olap = results.state.object_types_by_name.fetch("OlapQuery")
          domain_field = olap.graphql_fields_by_name.fetch("domain")
          resolver = domain_field.resolver
          expect(resolver).not_to be_nil
          expect(resolver.name).to eq :get_record_field_value
        end

        it "does not auto-wire a field that takes arguments" do
          results = define_schema(schema_element_name_form: "snake_case") do |schema|
            schema.namespace_type "OlapQuery" do |t|
              t.field "domain", "DomainQuery" do |f|
                f.argument "key", "String!"
              end
            end
            schema.namespace_type "DomainQuery"
          end

          olap = results.state.object_types_by_name.fetch("OlapQuery")
          expect(olap.graphql_fields_by_name.fetch("domain").resolver).to be_nil
        end

        it "does not auto-wire a field that lives on a non-namespace object type, even if its return type is a namespace type" do
          results = define_schema(schema_element_name_form: "snake_case") do |schema|
            schema.namespace_type "DomainQuery"
            schema.object_type "Regular" do |t|
              t.field "id", "ID"
              t.field "domain", "DomainQuery"
            end
          end

          regular = results.state.object_types_by_name.fetch("Regular")
          expect(regular.graphql_fields_by_name.fetch("domain").resolver).to be_nil
        end
      end
    end
  end
end
