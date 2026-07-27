#!/usr/bin/env python3
"""将本地 Agent 的模型请求转发到固定上游，不向 Agent 暴露真实密钥。"""

from __future__ import annotations

import argparse
import http.client
import http.server
import os
import re
import ssl
import sys
from collections.abc import Iterable
from pathlib import Path
from urllib.parse import SplitResult, urlsplit


MAX_REQUEST_BYTES = 128 * 1024 * 1024
HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}
CLIENT_SECRET_HEADERS = {
    "authorization",
    "proxy-authorization",
    "x-api-key",
}


def request_is_allowed(provider: str, method: str, target: str) -> bool:
    """只开放 Agent CLI 实际使用的模型 API 路径。"""
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        return False
    path = parsed.path
    if provider == "codex":
        return bool(
            (method == "POST" and re.fullmatch(r"/(?:v1/)?responses(?:/compact)?", path))
            or (method == "GET" and re.fullmatch(r"/(?:v1/)?models", path))
        )
    if provider == "claude":
        return method == "POST" and bool(
            re.fullmatch(r"/(?:v1/)?messages(?:/count_tokens)?", path)
        )
    return False


def parse_upstream(raw_url: str) -> SplitResult:
    parsed = urlsplit(raw_url.rstrip("/"))
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("upstream URL 只允许 http 或 https")
    if not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("upstream URL 必须包含固定主机，且不得包含用户信息")
    if parsed.query or parsed.fragment:
        raise ValueError("upstream URL 不得包含 query 或 fragment")
    return parsed


def upstream_target(upstream: SplitResult, client_target: str) -> str:
    parsed_target = urlsplit(client_target)
    base_path = upstream.path.rstrip("/")
    request_path = parsed_target.path
    # 同时兼容 BASE_URL 指向 origin 和已经带 /v1 的两种配置。
    if base_path.endswith("/v1") and request_path.startswith("/v1/"):
        request_path = request_path[3:]
    target = f"{base_path}{request_path}" or "/"
    if parsed_target.query:
        target = f"{target}?{parsed_target.query}"
    return target


def upstream_headers(
    incoming: Iterable[tuple[str, str]], provider: str, secret: str, body_length: int
) -> dict[str, str]:
    """去掉客户端凭据和逐跳字段，再由代理注入真实凭据。"""
    result: dict[str, str] = {}
    for name, value in incoming:
        lowered = name.lower()
        if lowered in HOP_BY_HOP_HEADERS | CLIENT_SECRET_HEADERS | {"host", "content-length"}:
            continue
        if lowered == "forwarded" or lowered.startswith("x-forwarded-"):
            continue
        result[name] = value
    result["Content-Length"] = str(body_length)
    result["Authorization"] = f"Bearer {secret}"
    if provider == "claude":
        result["x-api-key"] = secret
    return result


class FixedUpstreamProxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "ctex-model-proxy/1"

    def do_GET(self) -> None:  # noqa: N802 — BaseHTTPRequestHandler API
        self._forward("GET")

    def do_POST(self) -> None:  # noqa: N802 — BaseHTTPRequestHandler API
        self._forward("POST")

    def do_CONNECT(self) -> None:  # noqa: N802 — BaseHTTPRequestHandler API
        self.send_error(405, "CONNECT is disabled")

    def _forward(self, method: str) -> None:
        server = self.server
        assert isinstance(server, ModelProxyServer)
        if not request_is_allowed(server.provider, method, self.path):
            self.send_error(403, "model API path is not allowed")
            return

        raw_length = self.headers.get("Content-Length", "0")
        try:
            body_length = int(raw_length)
        except ValueError:
            self.send_error(400, "invalid Content-Length")
            return
        if body_length < 0 or body_length > MAX_REQUEST_BYTES:
            self.send_error(413, "request body is too large")
            return
        if self.headers.get("Transfer-Encoding"):
            self.send_error(400, "chunked request bodies are not supported")
            return
        body = self.rfile.read(body_length)

        connection_class = (
            http.client.HTTPSConnection
            if server.upstream.scheme == "https"
            else http.client.HTTPConnection
        )
        kwargs: dict[str, object] = {"timeout": 300}
        if server.upstream.scheme == "https":
            kwargs["context"] = ssl.create_default_context()
        connection = connection_class(
            server.upstream.hostname,
            server.upstream.port,
            **kwargs,
        )
        response_started = False
        try:
            connection.request(
                method,
                upstream_target(server.upstream, self.path),
                body=body,
                headers=upstream_headers(
                    self.headers.items(), server.provider, server.secret, len(body)
                ),
            )
            response = connection.getresponse()
            self.send_response_only(response.status, response.reason)
            response_started = True
            for name, value in response.getheaders():
                if name.lower() not in HOP_BY_HOP_HEADERS | {"connection"}:
                    self.send_header(name, value)
            self.send_header("Connection", "close")
            self.end_headers()
            while chunk := response.read(64 * 1024):
                self.wfile.write(chunk)
                self.wfile.flush()
            self.close_connection = True
        except (OSError, http.client.HTTPException) as error:
            if not response_started and not self.wfile.closed:
                self.send_error(502, f"fixed model upstream failed: {type(error).__name__}")
            self.close_connection = True
        finally:
            connection.close()

    def log_message(self, fmt: str, *args: object) -> None:
        # 日志只含本地请求路径和状态，不记录请求头或正文。
        sys.stderr.write("model-proxy: %s\n" % (fmt % args))


class ModelProxyServer(http.server.ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self, provider: str, upstream: SplitResult, secret: str
    ) -> None:
        super().__init__(("127.0.0.1", 0), FixedUpstreamProxy)
        self.provider = provider
        self.upstream = upstream
        self.secret = secret


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", choices=("codex", "claude"), required=True)
    parser.add_argument("--upstream", required=True)
    parser.add_argument("--secret-file", type=Path, required=True)
    parser.add_argument("--ready-file", type=Path, required=True)
    args = parser.parse_args()

    secret = args.secret_file.read_text(encoding="utf-8")
    if not secret or "\n" in secret or "\r" in secret:
        raise SystemExit("model API key 必须是非空单行字符串")
    upstream = parse_upstream(args.upstream)
    server = ModelProxyServer(args.provider, upstream, secret)
    host, port = server.server_address

    temporary_ready = args.ready_file.with_suffix(f".tmp-{os.getpid()}")
    temporary_ready.write_text(f"http://{host}:{port}\n", encoding="utf-8")
    temporary_ready.chmod(0o644)
    os.replace(temporary_ready, args.ready_file)

    try:
        server.serve_forever(poll_interval=0.2)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
