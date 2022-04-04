# Rust GraphQL Example

## Query: Members

```graphql
query ListMembers {
  members {
    id
    name
  }
}
```

## Query: Teams and associated Members

```graphql
query ListTeamsAndMembers {
  teams {
    id
    name
    members {
      id
      name
      knockouts
      teamId
    }
  }
}
```

## Mutation: Create Member

```graphql
mutation CreateMember($data: NewMember!) {
  createMember(data: $data) {
    id
    name
    knockouts
    teamId
  }
}
```

Query Variables

```graphql
{
  "data": {
    "name": "Samus",
    "knockouts": 19,
    "teamId": 1
  }
}
```
