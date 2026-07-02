"""Gunicorn WSGI entrypoint for Fava, tuned for low-power multi-core boards.

Why this exists (vs. the `fava` CLI, which uses cheroot):
  fava-dashboards fires several BQL queries per page load. BQL execution is
  pure-Python and CPU-bound, so under a single process the GIL serialises the
  queries no matter how many cores the box has. cheroot is thread-based → same
  problem. gunicorn with N *worker processes* gives real parallelism: the
  browser's concurrent requests land on different workers → different cores
  (matters on a multi-core box).

Two knobs are baked in here:
  - load=True eagerly parses the ledger at import time. Under `gunicorn
    --preload` that import runs once in the master, and forked workers inherit
    the parsed ledger via copy-on-write — so N workers cost ~1 load's worth of
    RAM, not N. It also doubles as startup warmup: the cold parse (several seconds on a slow box) is paid once at boot, never on a request.
  - prefix handling mirrors Fava's own CLI (--prefix) via DispatcherMiddleware,
    so URLs stay correct behind a reverse proxy that mounts the app at `/fava`.

Config via env:
  FAVA_BEANFILE  path to the root .bean            (default /data/main.bean)
  FAVA_PREFIX    URL prefix, "" to disable          (default /fava)

Run:  gunicorn --preload -w ${FAVA_WORKERS:-3} -b 0.0.0.0:5000 fava_wsgi:app
"""
from __future__ import annotations

import logging
import os
from pathlib import Path

from fava.application import create_app

log = logging.getLogger("fava_wsgi")


def _install_query_parse_cache(maxsize: int = 256) -> None:
    """Memoise BQL query parsing (the tatsu PEG parse) across requests.

    `BQLShell.parse` rebuilds the AST via tatsu on every request, even though
    dashboards fire the *same* query strings on each refresh. Parsing depends
    only on the query text, so it is cacheable; execution (which depends on the
    ledger and date) still runs every time. Measured saving ~50 ms/query on a
    dev box, roughly a few hundred ms on a slow board — modest per call but it compounds
    across the several queries a dashboard fires. (An earlier cProfile run made
    parse look like ~40% of the cost; that was profiler overhead inflating
    tatsu's many tiny calls — the un-profiled cost is the ~50 ms above.)

    Correctness: the parsed AST cannot be deep-copied (it holds a tatsu Buffer),
    so we cache and reuse the *same* statement object across executions. This is
    safe because compile/execute reads the AST without mutating it — verified
    empirically: the same cached statement, executed repeatedly and interleaved
    with other queries, yields byte-identical results. The only in-place write is
    ``from_clause.close = default_close_date`` inside the original parse, which is
    why the cache key includes ``default_close_date``.

    This is a runtime monkeypatch on our own side — it edits no installed Fava/
    beanquery files. It is *pure optimisation*: any failure (API drift) falls back
    to the original parser, so it can never change results.
    """
    try:
        from beanquery.shell import BQLShell
    except Exception as e:  # noqa: BLE001 — beanquery layout changed; skip silently
        log.warning("query parse cache not installed: %s", e)
        return

    if getattr(BQLShell.parse, "_forge_cached", False):
        return  # idempotent under gunicorn --preload re-import

    _orig_parse = BQLShell.parse
    _cache: dict[tuple, object] = {}

    def _cached_parse(self, line, default_close_date=None, **kwargs):  # noqa: ANN001
        key = (line, default_close_date)
        cached = _cache.get(key)
        if cached is not None:
            return cached
        statement = _orig_parse(self, line, default_close_date, **kwargs)
        if len(_cache) < maxsize:
            _cache[key] = statement
        return statement

    _cached_parse._forge_cached = True  # type: ignore[attr-defined]
    BQLShell.parse = _cached_parse  # type: ignore[method-assign]
    log.info("BQL query parse cache installed (maxsize=%d)", maxsize)


_install_query_parse_cache()

_BEANFILE = os.environ.get("FAVA_BEANFILE", "/data/main.bean")
_PREFIX = os.environ.get("FAVA_PREFIX", "/fava")

# load=True → parse eagerly at import (see module docstring: warmup + CoW share).
app = create_app([Path(_BEANFILE)], load=True)

if _PREFIX:
    from werkzeug.middleware.dispatcher import DispatcherMiddleware

    from fava.util import simple_wsgi

    # Identical shape to fava/cli.py: mount the app under the prefix, fall back
    # to a minimal WSGI app for anything outside it.
    app.wsgi_app = DispatcherMiddleware(  # type: ignore[method-assign]
        simple_wsgi,
        {_PREFIX: app.wsgi_app},
    )
