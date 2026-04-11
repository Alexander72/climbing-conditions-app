# Crag Data Provider Assessment

> **Note (April 2026):** The app now serves crags from **local JSON** via `GET /api/crags` (`services/crag_catalog.py`, `data/crags/`). The sections below are a **historical** provider comparison from March 2026.

**Region focus:** Belgium · Germany · Luxembourg  
**Date:** 16 March 2026  
**Context:** Evaluating replacements / supplements for the former OpenBeta integration

---

## Executive Summary

OpenBeta was the previous provider. Live API testing confirms it returns only **20 nodes** for the entire Belgium / Germany / Luxembourg bounding box — mostly country-level stubs with fabricated coordinates. It is **not viable** for this region.

This document evaluates five alternative providers against the following criteria:
access model, authentication, free tier, API integration pattern, documentation quality, and European coverage.

---

## 1. OpenBeta (current)

| Property | Detail |
|---|---|
| **Data model** | GraphQL (`cragsWithin`, `areas` queries) |
| **Authentication** | None (public, unauthenticated) |
| **Free tier** | Fully free |
| **License** | CC-BY-SA (community contributed) |
| **Docs** | https://openbeta.io/blog/openbeta-api |

### Coverage verdict — FAIL

Live bbox query `[2.5, 49.3, 15.5, 55.0]` (Belgium + Germany + Luxembourg):

| Country | Top-level nodes | Named crags with coords |
|---|---|---|
| Belgium | 1 (`Belgium` stub) | 1 (`Freyr` only — dozens missing) |
| Germany | 1 (`Germany` stub) | 8 areas, all share centroid `(51,9)` |
| Luxembourg | 1 (`Luxembourg` stub) | **0** (empty) |

**Total: 20 nodes.** Coordinates are mostly wrong (national centroid). Dataset originates from a Mountain Project import — that project is US-biased and European edits are sparse. Not recommended for Europe.

---

## 2. OpenStreetMap / Overpass API ⭐ Recommended (free tier)

### Access model

Fully open, read-only, no account or API key required. Data is under [ODbL license](https://www.openstreetmap.org/copyright). Attribution to "© OpenStreetMap contributors" required.

### Authentication

**None.** Anonymous HTTP GET or POST to the interpreter endpoint.

### Free tier

Completely free. Main public instance:
```
https://overpass-api.de/api/interpreter
```
Usage policy: safe under **10,000 queries/day** and **1 GB/day** download. Additional public instances available (no rate limits on some):
- `https://overpass.private.coffee/api/interpreter` — no rate limit
- `https://maps.mail.ru/osm/tools/overpass/api/interpreter` — no restriction

### Integration pattern

Send a POST (or GET) with an Overpass QL query:

```python
import httpx

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

CLIMBING_CRAGS_QUERY = """
[out:json][timeout:25];
(
  node["sport"="climbing"]["climbing"~"crag|area"]{bbox};
  relation["sport"="climbing"]["climbing"~"crag|area"]{bbox};
);
out center;
"""

async def get_crags_overpass(min_lat, min_lng, max_lat, max_lng):
    bbox = f"({min_lat},{min_lng},{max_lat},{max_lng})"
    query = CLIMBING_CRAGS_QUERY.replace("{bbox}", bbox)
    async with httpx.AsyncClient() as client:
        r = await client.post(OVERPASS_URL, data={"data": query}, timeout=30)
    return r.json()["elements"]
```

Response fields per element: `type`, `id`, `lat`/`lon` (nodes) or `center.lat`/`center.lon` (relations), `tags` (includes `name`, `climbing`, `sport`, `website`, `description`, `ele`, `access`, etc.)

### Coverage — EXCELLENT

Live bbox query returned **406 climbing crags and areas** for the target region, all with accurate GPS coordinates. Includes:
- Frankenjura (hundreds of individual crags)
- Elbsandsteingbirge / Saxon Switzerland
- Berdorf (Luxembourg)
- Belgian Meuse valley crags

### Limitations

- **No route-level data** — you get crag pins, not individual route grades/names (route-level OSM tagging is incomplete in this region).
- Tags are community-contributed; quality varies (`name`, `ele`, `website` often present, `description` rarely).
- No hierarchy (no parent/child area tree); everything is a flat list of tagged nodes/relations.
- No topo images.

### Documentation

- API: https://wiki.openstreetmap.org/wiki/Overpass_API
- Language guide: https://wiki.openstreetmap.org/wiki/Overpass_API/Language_Guide
- Climbing tags: https://wiki.openstreetmap.org/wiki/Tag:sport=climbing
- Interactive query builder: https://overpass-turbo.eu/

---

## 3. theCrag

### Access model

REST API with JSON responses. Comprehensive endpoint coverage: areas, routes, ascents, topos, discussions, facet search, bbox map queries.

**Critical blocker: API is currently CLOSED for new non-commercial applications.** Direct quote from their docs (as of 15 March 2026):

> "We are not accepting non-commercial API applications while we focus on other areas of the business."

If/when access is granted, a signed legal agreement is required.

### Authentication

Two-tier:
1. **API Key** — required for all read access. Supplied as `?key=abc` URL param or `X-CData-Key` HTTP header.
2. **OAuth 1.0 (HMAC-SHA1)** — required for protected resources (user data, write operations). Endpoints:
   - Temp credentials: `https://www.thecrag.com/oauth/request_token`
   - User auth: `https://www.thecrag.com/oauth/authorize`
   - Access token: `https://www.thecrag.com/oauth/access_token`

### Free tier

Non-commercial use intended to be free (revenue-share for commercial apps). No published rate limits beyond "< 10 calls per 10 seconds" as a guideline.

### Integration pattern (once access granted)

```
GET https://www.thecrag.com/api/map/bbox/heirachy
  ?s={minLng},{minLat},{maxLng},{maxLat}
  &f=geometry,gearStyles,numberRoutes,numberAscents
  &v=0.001
  &key=YOUR_KEY
```

Or area hierarchy:
```
GET https://www.thecrag.com/api/area/id/{nodeID}?show=info,children,location&key=YOUR_KEY
```

Development sandbox: `sandpit.thecrag.com` (same endpoints, safe for testing).

### Coverage — GOOD

theCrag has significantly better European coverage than OpenBeta/Mountain Project:
- Belgium, Germany, and Luxembourg have user-contributed data stretching back years.
- Frankenjura is documented with individual crags.
- Hierarchical area tree (World → Country → Region → Crag → Sector → Route).

### Limitations

- **API is currently closed** — no path to access without waiting for them to re-open.
- Beta product, no SLA, no continuity guarantee.
- Caching on server side not allowed (only mobile client caching is permitted).
- CC-BY-NC-SA license — no commercial use without negotiation.

### Documentation

- https://www.thecrag.com/en/article/api
- WADL reference: https://www.thecrag.com/api-wadl.xml

---

## 4. 27crags

### Access model

**No documented public API.** 27crags operates as a SaaS application. Their web app uses internal JSON endpoints (e.g., `/crags/{slug}.json`, `/areas/{slug}.json`) but these are undocumented, unauthenticated when public, and subject to change without notice. Using them constitutes scraping and violates their Terms of Use.

There is no developer portal, no API key signup, no documented REST or GraphQL API. Contact would be required for a commercial data partnership.

### Authentication

Internal endpoints exist but are not publicly authenticated; ToS prohibits programmatic access without consent.

### Free tier

**None for API access.** End-user subscriptions start at ~€4.16/month for premium topo content.

### Coverage — EXCELLENT (data quality)

Despite the API gap, 27crags has the richest European data for the target region:

| Area | Route count | Crags |
|---|---|---|
| Belgium (full country) | **4,222 routes** | **44 crags** |
| Frankenjura (Germany) | 15,000+ routes | 100s of crags |
| Berdorf (Luxembourg) | **226 routes** | 1 crag |

Includes: Freyr, Beez, Pont-à-Lesse, Yvoir, Dave/Néviau, and many more Belgian crags. Berdorf is fully documented with sector topos.

### Limitations

- No public API — data is only accessible through their app/website.
- Topo images are paywalled (Premium subscription required).
- Must contact them for any data partnership or bulk access; they are a for-profit company.

### Documentation

- Website: https://27crags.com
- Contact: https://27crags.com/contact
- Terms: https://27crags.com/site/terms

---

## 5. Vertical-Life

### Access model

Vertical-Life (based in Brixen, Italy) is a commercial digital guidebook platform. It partners with traditional guidebook publishers to sell licensed digital topos in-app. There is no documented public API.

### Authentication

The platform uses an OpenID Connect / Keycloak auth system (`vlatka.vertical-life.info`). No developer API key mechanism is exposed publicly.

### Free tier

**None.** End-user premium subscription required to access topo content. B2B data licensing is possible but requires direct negotiation with their authors/commercial team (`support@vertical-life.info`).

### Coverage — EXCELLENT (for licensed areas)

Very high quality data where it exists — full topo images, route grades, sector info. European coverage includes major destinations.
Coverage for Belgium / Luxembourg specifically is unknown without app access; Germany (Frankenjura, Bavarian Alps) appears well-covered based on their app listing.

### Limitations

- No public API.
- Data is publisher-licensed — significant contractual and financial overhead.
- Not suitable as a self-service data source.

### Documentation

- Website: https://www.vertical-life.info/en/
- Authors portal (for guidebook publishers): https://authors.vertical-life.info/

---

## 6. climbfinder.com — NOT APPLICABLE

Despite the name, climbfinder.com is a **cycling climb finder** (mountain passes, cols, hills). It has no rock-climbing data. Not relevant to this project.

---

## Comparison Matrix

| Provider | Free | No Auth | EU Coverage | API Quality | Route Data | Viable Now? |
|---|---|---|---|---|---|---|
| **OpenBeta** | ✅ | ✅ | ❌ Poor | ✅ GraphQL | Sparse | ❌ |
| **Overpass (OSM)** | ✅ | ✅ | ✅ 406 crags | ✅ Well-documented | Crag pins only | ✅ Yes |
| **theCrag** | ✅ (NC) | ❌ Key + OAuth | ✅ Good | ✅ Rich REST | ✅ Full hierarchy | ⚠️ API closed |
| **27crags** | ❌ | N/A | ✅ Excellent | ❌ No public API | ✅ 4000+ in BE | ❌ No API |
| **Vertical-Life** | ❌ | N/A | ✅ Good | ❌ No public API | ✅ Topo quality | ❌ No API |

---

## Recommendation

### Immediate: Replace OpenBeta with Overpass API

Use Overpass as the primary crag-location data source. It has 20× more coverage in the target region, is completely free, requires zero authentication, and is trivially easy to integrate with the existing `httpx`-based architecture. Limitations (no route counts, no topos) are acceptable for map-pin display.

**Sample Overpass QL query for the crags router:**

```
[out:json][timeout:25];
(
  node["sport"="climbing"]["climbing"~"^(crag|area)$"](bbox_values);
  relation["sport"="climbing"]["climbing"~"^(crag|area)$"](bbox_values);
  node["sport"="climbing"]["natural"="cliff"](bbox_values);
);
out center tags;
```

### Medium-term: Monitor theCrag API re-opening

theCrag has the best openly-documented API with bbox/hierarchy support. Monitor https://www.thecrag.com/en/article/api for the non-commercial application process to re-open. When available, integrate as a richer fallback for route counts and area hierarchy.

### For route-level data: Consider 27crags partnership

If full route data (grades, topos) is a product requirement, contact 27crags directly for a data/embed partnership. They have the best coverage for Belgium + Luxembourg and already feature Berdorf in their featured destinations.

---

## Integration Effort Estimate

| Option | Effort | Blocker |
|---|---|---|
| Overpass API swap | **Low** — 1–2 hours | None |
| theCrag | Medium — OAuth + key management | API currently closed |
| 27crags partnership | High — business arrangement required | No public API |
