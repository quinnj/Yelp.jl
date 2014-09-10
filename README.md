# Yelp

An interface to the [Yelp API](http://www.yelp.com/developers/documentation/v2/search_api).

Usage:
```julia
Pkg.add("Yelp")

using Yelp, JSON

# OAuth credential placeholders that must be filled in by users.
CONSUMER_KEY = "..."
CONSUMER_SECRET = "..."
TOKEN = "..."
TOKEN_SECRET = "..."

cred = Yelp.OAuth(CONSUMER_SECRET,TOKEN_SECRET,CONSUMER_KEY,TOKEN)

q = Yelp.search(cred; ll=(40.435941,-79.896413),
                      sort=Yelp.DISTANCE,
                      radius_filter=1600)
t = Yelp.get(q)
q = Yelp.search(cred; location="london",
                      cc="GB",
                      lang="es",
                      term="food")
t = Yelp.get(q)

JSON.parse(t.data)["total"]
map(x->x["id"],JSON.parse(t.data)["businesses"])
map(x->x["categories"],JSON.parse(t.data)["businesses"])
map(x->x["snippet_text"],JSON.parse(t.data)["businesses"])
```
