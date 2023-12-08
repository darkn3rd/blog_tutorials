# Getting started

This is content from the getting started material from the command line.

For this guide, set the environment variable `DGRAPH_HTTP` to point to the Dgraph Alpha service.  For example:

```bash
export DGRAPH_HTTP="localhost:8080"  # set to approprite value
```

## Upload Data

You can upload data using either RDF or JSON. Below are examples of each with the same dataset.

### Upload Data using RDF

```bash
curl "$DGRAPH_HTTP/mutate?commitNow=true" --silent --request POST \
 --header  "Content-Type: application/rdf" \
 --data $'
{
  set {
   _:luke <name> "Luke Skywalker" .
   _:luke <dgraph.type> "Person" .
   _:leia <name> "Princess Leia" .
   _:leia <dgraph.type> "Person" .
   _:han <name> "Han Solo" .
   _:han <dgraph.type> "Person" .
   _:lucas <name> "George Lucas" .
   _:lucas <dgraph.type> "Person" .
   _:irvin <name> "Irvin Kernshner" .
   _:irvin <dgraph.type> "Person" .
   _:richard <name> "Richard Marquand" .
   _:richard <dgraph.type> "Person" .

   _:sw1 <name> "Star Wars: Episode IV - A New Hope" .
   _:sw1 <release_date> "1977-05-25" .
   _:sw1 <revenue> "775000000" .
   _:sw1 <running_time> "121" .
   _:sw1 <starring> _:luke .
   _:sw1 <starring> _:leia .
   _:sw1 <starring> _:han .
   _:sw1 <director> _:lucas .
   _:sw1 <dgraph.type> "Film" .

   _:sw2 <name> "Star Wars: Episode V - The Empire Strikes Back" .
   _:sw2 <release_date> "1980-05-21" .
   _:sw2 <revenue> "534000000" .
   _:sw2 <running_time> "124" .
   _:sw2 <starring> _:luke .
   _:sw2 <starring> _:leia .
   _:sw2 <starring> _:han .
   _:sw2 <director> _:irvin .
   _:sw2 <dgraph.type> "Film" .

   _:sw3 <name> "Star Wars: Episode VI - Return of the Jedi" .
   _:sw3 <release_date> "1983-05-25" .
   _:sw3 <revenue> "572000000" .
   _:sw3 <running_time> "131" .
   _:sw3 <starring> _:luke .
   _:sw3 <starring> _:leia .
   _:sw3 <starring> _:han .
   _:sw3 <director> _:richard .
   _:sw3 <dgraph.type> "Film" .

   _:st1 <name> "Star Trek: The Motion Picture" .
   _:st1 <release_date> "1979-12-07" .
   _:st1 <revenue> "139000000" .
   _:st1 <running_time> "132" .
   _:st1 <dgraph.type> "Film" .
  }
}
' | jq
```


### Upload Data using JSON

```bash
curl "$DGRAPH_HTTP/mutate?commitNow=true" --silent --request POST \
 --header  "Content-Type: application/json" \
 --data $'
{
  "set": [
    {"uid": "_:luke","name": "Luke Skywalker", "dgraph.type": "Person"},
    {"uid": "_:leia","name": "Princess Leia", "dgraph.type": "Person"},
    {"uid": "_:han","name": "Han Solo", "dgraph.type": "Person"},
    {"uid": "_:lucas","name": "George Lucas", "dgraph.type": "Person"},
    {"uid": "_:irvin","name": "Irvin Kernshner", "dgraph.type": "Person"},
    {"uid": "_:richard","name": "Richard Marquand", "dgraph.type": "Person"},
    {
      "uid": "_:sw1",
      "name": "Star Wars: Episode IV - A New Hope",
      "release_date": "1977-05-25",
      "revenue": 775000000,
      "running_time": 121,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:lucas"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:sw2",
      "name": "Star Wars: Episode V - The Empire Strikes Back",
      "release_date": "1980-05-21",
      "revenue": 534000000,
      "running_time": 124,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:irvin"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:sw3",
      "name": "Star Wars: Episode VI - Return of the Jedi",
      "release_date": "1983-05-25",
      "revenue": 572000000,
      "running_time": 131,
      "starring": [{"uid": "_:luke"},{"uid": "_:leia"},{"uid": "_:han"}],
      "director": [{"uid": "_:richard"}],
      "dgraph.type": "Film"
    },
    {
      "uid": "_:st1",
      "name": "Star Trek: The Motion Picture",
      "release_date": "1979-12-07",
      "revenue": 139000000,
      "running_time": 132,
      "dgraph.type": "Film"
    }
  ]
}
' | jq
```


## Upload Schema

Alter the schema to add indexes on some of the data so queries can use term matching, filtering and sorting.

```bash
# NOTE: Whitelist required
curl "$DGRAPH_HTTP/alter" --silent --request POST \
 --data $'
name: string @index(term) .
release_date: datetime @index(year) .
revenue: float .
running_time: int .
starring: [uid] .
director: [uid] .

type Person {
  name
}

type Film {
  name
  release_date
  revenue
  running_time
  starring
  director
}
' | jq
```

## Example Query 1

List out all of the movies that have a `starring` edge.

```bash
curl "$DGRAPH_HTTP/query" --silent --request POST \
  --header "Content-Type: application/dql" \
  --data $'{ me(func: has(starring)) { name } }' \
  | jq .data
```

## Example Query 2

Query Star Wars movies released after 1980. 

```bash
curl "$DGRAPH_HTTP/query" --silent --request POST \
  --header "Content-Type: application/dql" \
  --data $'
{
    me(func: allofterms(name, "Star Wars"), orderasc: release_date) 
     @filter(ge(release_date, "1980")) {
        name
        release_date
        revenue
        running_time
        director { name }
        starring (orderasc: name) { name }
    }
}
' | jq .data
```
