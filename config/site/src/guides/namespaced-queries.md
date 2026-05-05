---
layout: markdown
title: Namespaced Queries
permalink: /guides/namespaced-queries/
nav_title: Namespaced Queries
menu_order: 25
---

By default, the root query fields ElasticGraph generates for an indexed type are added directly to
`Query`. For example, an indexed `Widget` type produces `Query.widgets` and `Query.widgetAggregations`.
When ElasticGraph is the only backing service in your GraphQL API, this is usually what you want.

When ElasticGraph is composed into a federated supergraph alongside other subgraphs, though, `Query`
can become crowded and fields from different subgraphs can be hard to tell apart. A _namespace type_
lets you group ElasticGraph's root query fields under a nested path—for example, `Query.olap.widgets`
instead of `Query.widgets`—so they remain discoverable among fields contributed by other subgraphs.

## Minimal Example

A namespace is an object type declared with [`namespace_type`](/elasticgraph/api-docs/main/ElasticGraph/SchemaDefinition/API.html#namespace_type-instance_method).
Route an indexed type's root fields to it by passing `on:` to [`root_query_fields`](/elasticgraph/api-docs/main/ElasticGraph/SchemaDefinition/Mixins/HasIndices.html#root_query_fields-instance_method),
then expose the namespace as a field on `Query`.

{% include copyable_code_snippet.html language="ruby" code="ElasticGraph.define_schema do |schema|
  schema.namespace_type \"OlapQuery\"

  schema.on_root_query_type do |t|
    t.field \"olap\", \"OlapQuery!\" do |f|
      f.resolve_with :constant_value, value: {}
    end
  end

  schema.object_type \"Widget\" do |t|
    t.field \"id\", \"ID\"
    t.field \"name\", \"String\"
    t.index \"widgets\"
    t.root_query_fields plural: \"widgets\", on: \"OlapQuery\"
  end
end" %}

This produces a GraphQL API where `Widget`s are queried through `olap`:

{% include copyable_code_snippet.html language="graphql" code="query {
  olap {
    widgets(first: 10) {
      nodes { id name }
    }
    widgetAggregations { ... }
  }
}" %}

The field on `Query` that returns the namespace type (`olap` in the example) needs a resolver. The
built-in `:constant_value` resolver is a convenient choice: it returns the configured value (here,
an empty hash) so the child fields on the namespace have a parent object to resolve against.

## Nested Example

Namespace types can be nested inside other namespace types. ElasticGraph auto-wires `:constant_value`
for any no-argument field on a namespace type whose return type is also a namespace type, so you
don't have to configure a resolver for every intermediate field.

{% include copyable_code_snippet.html language="ruby" code="ElasticGraph.define_schema do |schema|
  schema.namespace_type \"OlapQuery\" do |t|
    # Auto-wired to `:constant_value` because `DomainQuery` is a namespace type.
    t.field \"domain\", \"DomainQuery!\"
  end

  schema.namespace_type \"DomainQuery\"

  schema.on_root_query_type do |t|
    t.field \"olap\", \"OlapQuery!\" do |f|
      f.resolve_with :constant_value, value: {}
    end
  end

  schema.object_type \"Widget\" do |t|
    t.field \"id\", \"ID\"
    t.index \"widgets\"
    t.root_query_fields plural: \"widgets\", on: \"DomainQuery\"
  end
end" %}

Widgets are now queried at `Query.olap.domain.widgets`.

## Tradeoffs

### Single Target per Indexed Type

An indexed type's root fields (`plural` and `singular`) are always placed together on one target
type—either `Query` (the default) or a single namespace. You cannot split them; for example, you
cannot put `widgets` on `Query` and `widgetAggregations` on `OlapQuery`. If you need different
groupings for the list field and the aggregation field, consider whether the namespace is actually
the right grouping, or model the split at the supergraph level.

### Reachability from `Query`

Every namespace type you declare must be reachable from `Query` through a chain of field
references, otherwise ElasticGraph raises an error at schema-artifact generation time. This prevents
orphaned namespace types that would hold root fields nothing can reach. Cycles among namespace
types are also rejected.

## Apollo Federation

If you expose ElasticGraph through [elasticgraph-apollo](/elasticgraph/api-docs/main/ElasticGraph/Apollo.html),
namespace types appear in the `_service` SDL like any other type. Depending on your composition
strategy, you may need to apply federation directives:

- `@shareable` — if another subgraph also defines a type with the same name and overlapping fields,
  use `apollo_shareable` on the namespace type (and on shared fields) so Apollo composition allows
  the overlap.
- `@inaccessible` — use `apollo_inaccessible` on fields you don't want exposed in the final
  supergraph schema.

Unlike ElasticGraph's other built-in types, user-declared namespace types are not automatically
tagged with `@shareable`. Apply the directive explicitly when your supergraph composition requires
it.
