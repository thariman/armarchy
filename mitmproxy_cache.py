"""
mitmproxy caching addon
"""
import hashlib
import pickle
from pathlib import Path
from mitmproxy import http


class Cache:
    def __init__(self):
        self.cache_dir = Path.home() / ".mitmproxy" / "cache"
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def _get_cache_key(self, flow: http.HTTPFlow) -> str:
        """Generate cache key from request"""
        key_data = f"{flow.request.method}:{flow.request.url}"
        return hashlib.sha256(key_data.encode()).hexdigest()

    def _get_cache_path(self, key: str) -> Path:
        return self.cache_dir / f"{key}.cache"

    def request(self, flow: http.HTTPFlow) -> None:
        """Check cache before making request"""
        if flow.request.method != "GET":
            return

        key = self._get_cache_key(flow)
        cache_path = self._get_cache_path(key)

        if cache_path.exists():
            try:
                with open(cache_path, "rb") as f:
                    cached_response = pickle.load(f)
                
                flow.response = http.Response.make(
                    status_code=cached_response["status_code"],
                    content=cached_response["content"],
                    headers=cached_response["headers"]
                )
                flow.response.headers["X-Cache"] = "HIT"
                print(f"Cache HIT: {flow.request.url}")
            except Exception as e:
                print(f"Cache read error: {e}")

    def response(self, flow: http.HTTPFlow) -> None:
        """Cache successful GET responses"""
        if flow.request.method != "GET":
            return

        if flow.response and flow.response.status_code == 200:
            key = self._get_cache_key(flow)
            cache_path = self._get_cache_path(key)

            if "X-Cache" not in flow.response.headers:
                try:
                    cached_data = {
                        "status_code": flow.response.status_code,
                        "content": flow.response.content,
                        "headers": dict(flow.response.headers)
                    }
                    with open(cache_path, "wb") as f:
                        pickle.dump(cached_data, f)
                    flow.response.headers["X-Cache"] = "MISS"
                    print(f"Cache MISS: {flow.request.url}")
                except Exception as e:
                    print(f"Cache write error: {e}")


addons = [Cache()]
