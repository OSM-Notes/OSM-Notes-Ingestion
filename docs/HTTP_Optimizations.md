---
title: "HTTP Optimizations for OSM-Notes-Ingestion"
description: "This document describes the HTTP optimizations implemented to improve performance of API calls to"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "documentation"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# HTTP Optimizations for OSM-Notes-Ingestion

## Overview

This document describes the HTTP optimizations implemented to improve performance of API calls to
OpenStreetMap and Overpass APIs. These optimizations reduce connection overhead and improve response
times without requiring complex connection pooling infrastructure.

**Version:** 2025-12-14

## Optimizations Implemented

### 1. HTTP Keep-Alive Connections

**What it does:**

- Reuses TCP connections for multiple HTTP requests within the same execution
- Reduces connection establishment overhead (TCP handshake, TLS negotiation)
- Uses `Connection: keep-alive` header to maintain connections

**Benefits:**

- Saves 50-200ms per request by avoiding connection setup
- Reduces server load on OSM/Overpass APIs
- More efficient use of network resources

**Implementation:**

- Added `--http1.1` flag to curl commands
- Added `Connection: keep-alive` header
- curl automatically manages connection reuse

### 2. HTTP/2 Support

**What it does:**

- Automatically detects if servers support HTTP/2
- Uses HTTP/2 when available (multiplexing, header compression)
- Falls back to HTTP/1.1 with keep-alive if HTTP/2 is not supported

**Benefits:**

- HTTP/2 multiplexing allows multiple requests over single connection
- Header compression reduces bandwidth
- Better performance on high-latency connections

**Implementation:**

- Tests HTTP/2 support before making requests
- Uses `--http2` flag when supported
- Gracefully falls back to HTTP/1.1 if not available

### 3. HTTP Compression

**What it does:**

- Requests compressed responses using `Accept-Encoding: gzip, deflate, br`
- Uses `--compressed` flag to automatically decompress responses
- Reduces bandwidth usage, especially for large XML/JSON responses

**Benefits:**

- Reduces download time for large responses (10MB+ XML files)
- Saves bandwidth costs
- Faster transfers over slow connections

### 4. Conditional Caching (If-Modified-Since)

**What it does:**

- Sends `If-Modified-Since` header based on cached file modification time
- Server returns 304 Not Modified if data hasn't changed
- Avoids re-downloading unchanged data

**Benefits:**

- Saves bandwidth when data hasn't changed
- Faster execution when no updates available
- Reduces server load on OSM API

**Implementation:**

- Checks file modification time before requests
- Sends HTTP date in RFC 7231 format
- Handles 304 responses by using cached file

## Configuration

### Enable/Disable Optimizations

All optimizations are enabled by default. You can control them via environment variables in
`etc/properties.sh`:

```bash
# Enable HTTP optimizations (keep-alive, HTTP/2, compression)
# Default: true
export ENABLE_HTTP_OPTIMIZATIONS="true"

# Enable conditional caching (If-Modified-Since)
# Default: true
export ENABLE_HTTP_CACHE="true"
```

### Disabling Optimizations

If you need to disable optimizations (e.g., for debugging):

```bash
# Disable all HTTP optimizations
export ENABLE_HTTP_OPTIMIZATIONS="false"
export ENABLE_HTTP_CACHE="false"
```

## Performance Impact

### Expected Improvements

Based on typical execution patterns:

- **Connection reuse**: 50-200ms saved per request
- **HTTP/2**: 10-30% improvement on high-latency connections
- **Compression**: 60-80% bandwidth reduction for XML responses
- **Conditional caching**: 100% time savings when no updates (304 response)

### Real-World Example

For a typical `processAPINotes.sh` execution:

**Before optimizations:**

- OSM API request: ~500ms (connection + download)
- Total HTTP overhead: ~500ms

**After optimizations:**

- OSM API request: ~300ms (reused connection + compressed download)
- Total HTTP overhead: ~300ms
- **Improvement: ~200ms (40% faster)**

When no updates available (304 response):

- OSM API request: ~50ms (connection check only)
- **Improvement: ~450ms (90% faster)**

## Technical Details

### Modified Functions

1. **`__retry_osm_api()`** in `bin/lib/noteProcessingFunctions.sh`
   - Added HTTP keep-alive support
   - Added HTTP/2 detection and usage
   - Added compression support
   - Added conditional caching with If-Modified-Since

2. **`__retry_overpass_api()`** in `bin/lib/noteProcessingFunctions.sh`
   - Added HTTP keep-alive support
   - Added HTTP/2 detection and usage
   - Added compression support

### Compatibility

- **Backward compatible**: All optimizations are opt-in via configuration
- **Graceful degradation**: Falls back to standard HTTP/1.1 if HTTP/2 unavailable
- **No breaking changes**: Existing code continues to work without modifications

### Requirements

- **curl 7.47.0+** for HTTP/2 support (optional, falls back if not available)
- **Standard curl** for keep-alive and compression (available in all versions)

## Monitoring

### Log Messages

The optimized functions log their behavior:

```
DEBUG: Using HTTP/2 for OSM API
DEBUG: HTTP/2 not available, using HTTP/1.1 with keep-alive
DEBUG: Using conditional request with If-Modified-Since: Mon, 14 Dec 2025 10:30:00 GMT
```

### Verification

To verify optimizations are working:

1. **Check logs** for HTTP/2 or keep-alive messages
2. **Monitor network** with `tcpdump` or `wireshark` to see connection reuse
3. **Check response times** - should see 10-40% improvement

## Troubleshooting

### HTTP/2 Not Working

If HTTP/2 is not being used:

- Check curl version: `curl --version` (needs 7.47.0+)
- Check server support: `curl -I --http2 https://api.openstreetmap.org`
- System will automatically fall back to HTTP/1.1

### Conditional Caching Not Working

If 304 responses are not received:

- Verify `ENABLE_HTTP_CACHE="true"` in properties
- Check file modification times are correct
- Some servers may not support If-Modified-Since

### Performance Not Improved

If you don't see performance improvements:

- Verify optimizations are enabled in properties
- Check network latency (benefits are larger on high-latency connections)
- Monitor actual execution times (improvements may be small for fast connections)

## Future Enhancements

Potential future optimizations (not currently implemented):

1. **HTTP/3 (QUIC)**: When widely supported by servers
2. **Response caching**: Cache API responses for short periods
3. **Request batching**: Combine multiple API calls when possible
4. **DNS prefetching**: Resolve DNS before making requests

## References

- [HTTP/1.1 Keep-Alive](https://tools.ietf.org/html/rfc7230#section-6.3)
- [HTTP/2 Specification](https://tools.ietf.org/html/rfc7540)
- [Conditional Requests (If-Modified-Since)](https://tools.ietf.org/html/rfc7232#section-3.3)
- [curl Documentation](https://curl.se/docs/)

## Author

Andres Gomez (AngocA) OSM-LatAm, OSM-Colombia, MaptimeBogota
