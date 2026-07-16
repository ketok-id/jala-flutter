/// GraphQL link for Jala, the in-app Flutter network inspector.
///
/// Wraps any `gql_link`-based GraphQL client (`graphql_flutter`, `ferry`) to
/// capture operation name/type, query text, variables, response
/// data/errors, and duration into `JalaBinding.instance`. See
/// [JalaGraphQLLink] for the recommended way to wire it into a `Link`
/// chain.
library;

export 'src/jala_graphql_link.dart';
