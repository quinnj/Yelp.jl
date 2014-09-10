module Yelp

using Nettle, Requests

type OAuth
    consumer_secret::String
    oauth_secret::String
    consumer_key::String
    oauth_token::String
end

type Query
    cred::OAuth
    baseurl::String
    params::Dict
end

encode(s::Dict)   = tostring(s,x->Requests.encodeURI(string(x)))
encode(s::String) = Requests.encodeURI(s)

function tostring(params::Dict, func=identity)
    pkeys = collect(keys(params))
    sort!(pkeys)
    q = ""
    for k in pkeys
        k == "oauth_signature" && continue
        v = func(params[k])
        q *= "$k=$v&"
    end
    return chop(q)
end

function oauth_sign!(q::Query)
    signing_key = "$(encode(q.cred.consumer_secret))&$(encode(q.cred.oauth_secret))"
    h = Nettle.HMACState(Nettle.SHA1, signing_key)
    sig = "GET&$(encode(q.baseurl))&$(encode(tostring(q.params)))"
    # for whatever reason, Yelp doesn't like a few values
    # that Requests.encodeURI puts in
    sig = replace(sig,"%2C","%252C")
    sig = replace(sig,"%20","%2520")
    sig = replace(sig,"%7","%257")
    println(sig)
    Nettle.update!(h, sig)
    q.params["oauth_signature"] = encode(base64(Nettle.digest!(h)))
    return "OAuth realm= oauth_consumer_key=\"$(q.params["oauth_consumer_key"])\", oauth_nonce=\"$(q.params["oauth_nonce"])\", oauth_signature=\"$(q.params["oauth_signature"])\", oauth_signature_method=\"$(q.params["oauth_signature_method"])\", oauth_timestamp=\"$(q.params["oauth_timestamp"])\", oauth_token=\"$(q.params["oauth_token"])\""
end

SEARCH_API = "http://api.yelp.com/v2/search"
BUSINESS_API = "http://api.yelp.com/v2/business"

BEST_MATCHED = 0
DISTANCE = 1
HIGHEST_RATED = 2
SORT_OPTIONS = [BEST_MATCHED,DISTANCE,HIGHEST_RATED]

MAX_RADIUS_FILTER = 40000

typealias LatLon (Float64,Float64)

function Base.search(cred::OAuth;
                     term::String = "",
                     location::String = "San Francisco, CA",
                     cll::LatLon = (0.0,0.0),
                     ll::LatLon = (0.0,0.0),
                     sw_bounds::LatLon = (0.0,0.0),
                     ne_bounds::LatLon = (0.0,0.0),
                     limit::Int = 5,
                     offset::Int = 0,
                     sort::Int = BEST_MATCHED,
                     category_filter::String = "",
                     radius_filter::Int = 40000,
                     deals_filter::Bool = false,
                     cc::String = "US",
                     lang::String = "en")
    # input validation
    radius_filter <= MAX_RADIUS_FILTER || throw(ArgumentError("radius_filter = $radius_filter; must be <= $MAX_RADIUS_FILTER"))
    sort in SORT_OPTIONS || throw(ArgumentError("sort = $sort; must be in $SORT_OPTIONS"))

    # build options dict
    params = ["limit"         => limit,
              "offset"        => offset,
              "sort"          => sort,
              "radius_filter" => radius_filter,
              "deals_filter"  => deals_filter,
              "cc"            => cc,
              "lang"          => lang]

    # only include these parameters if explicitly set
    term            == "" || (params["term"] = term)
    category_filter == "" || (params["category_filter"] = category_filter)

    # add a few OAuth parameters
    params["oauth_consumer_key"] = cred.consumer_key
    params["oauth_token"] = cred.oauth_token
    params["oauth_signature_method"] = "HMAC-SHA1"

    # figure out location parameter
    if ll != (0.0,0.0)
        params["ll"] = string(ll)[2:end-1]
    elseif sw_bounds != (0.0,0.0) && ne_bounds != (0.0,0.0)
        s = string(string(sw_bounds)[2:end-1],"|",string(ne_bounds)[2:end-1])
        params["bounds"] = s
    else
        params["location"] = location
        if cll != (0.0,0.0)
            params["cll"] = string(cll)[2:end-1]
        end
    end

    # construct and return a Query instance
    return Query(cred,SEARCH_API,params)
end

function business(cred, business_id; cc="US",lang="en",lang_filter::Bool=false)
    params = ["cc" => cc, "lang" => lang, "lang_filter" => lang_filter]
    return Query(cred,BUSINESS_API*business_id,params)
end

function Base.get(q::Query)
    q.params["oauth_nonce"] = randstring(32)
    q.params["oauth_timestamp"] = int(time())
    oauth_header = oauth_sign!(q)
    url = URI("$(q.baseurl)?$(encode(q.params))")
    return Requests.get(url; 
                headers = {"Content-Type" => "application/x-www-form-urlencoded",
                "Authorization" => oauth_header,
                "Accept" => "*/*"})
end

end # module