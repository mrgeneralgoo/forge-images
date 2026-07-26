#!/usr/bin/env python3
import argparse
import csv
import ipaddress
import json
import os
import re
import tempfile
from pathlib import Path

MAX_BYTES = 2_097_152
MAX_LINE_BYTES = 8_192
MAX_ENTRIES = 100_000
DOMAIN = re.compile(r"^[a-z0-9_-]+(?:\.[a-z0-9_-]+)*$")
KEYWORD = re.compile(r"^[a-z0-9._-]+$")
# A routing target is any valid dae outbound/group identifier (e.g. `direct`,
# `block`, or a user-defined group such as `AI_CHAIN`). Group names live in the
# operator's own config.dae, so this image must not hard-code a specific set;
# the identifier pattern keeps the generated `-> {target}` injection-safe.
TARGET = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def parse_scalar(text: str) -> str:
    if text.startswith('"'):
        return json.loads(text)
    if text.startswith("'"):
        if not text.endswith("'"):
            raise ValueError("unterminated single-quoted YAML scalar")
        return text[1:-1].replace("''", "'")
    if " #" in text or text.startswith(("&", "*", "!", "|", ">", "[", "{")):
        raise ValueError("unsupported YAML scalar syntax")
    return text


def load_payload(path: Path) -> list[str]:
    document = path.read_bytes()
    if len(document) > MAX_BYTES or document.startswith(b"\xef\xbb\xbf"):
        raise ValueError(f"{path}: invalid document size or BOM")
    if b"\x00" in document or b"\t" in document:
        raise ValueError(f"{path}: NUL and tabs are forbidden")
    text = document.decode("utf-8")
    payload: list[str] = []
    saw_payload = False
    for number, line in enumerate(text.splitlines(), 1):
        if len(line.encode()) > MAX_LINE_BYTES:
            raise ValueError(f"{path}:{number}: line too long")
        if not line or line.startswith("#"):
            continue
        if line == "payload:":
            if saw_payload:
                raise ValueError(f"{path}:{number}: duplicate payload key")
            saw_payload = True
            continue
        if saw_payload and line.startswith("  - ") and not line.startswith("   - "):
            value = parse_scalar(line[4:])
            if not value:
                raise ValueError(f"{path}:{number}: empty rule")
            payload.append(value)
            if len(payload) > MAX_ENTRIES:
                raise ValueError(f"{path}: too many entries")
            continue
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        raise ValueError(f"{path}:{number}: unsupported YAML structure")
    if not saw_payload or not payload:
        raise ValueError(f"{path}: payload must be a non-empty sequence")
    return payload


def clean_domain(value: str) -> str:
    value = value.lower().rstrip(".")
    if not DOMAIN.fullmatch(value):
        raise ValueError("invalid domain pattern")
    return value


def clean_keyword(value: str) -> str:
    value = value.lower()
    if not KEYWORD.fullmatch(value):
        raise ValueError("invalid domain keyword")
    return value


def parse_cidr(kind: str, value: str) -> str:
    network = ipaddress.ip_network(value, strict=False)
    expected = 4 if kind == "IP-CIDR" else 6
    if network.version != expected:
        raise ValueError(f"address family mismatch for {kind}")
    return str(network)


def convert_payload(
    behavior: str,
    payload: list[str],
    asn_expansions: dict[str, list[str]] | None = None,
) -> list[tuple[str, str]]:
    converted: list[tuple[str, str]] = []
    asn_expansions = asn_expansions or {}
    if behavior == "domain":
        for value in payload:
            if not value.startswith("+."):
                raise ValueError("domain providers initially require +. suffix entries")
            converted.append(("suffix", clean_domain(value[2:])))
        return converted
    if behavior != "classical":
        raise ValueError(f"unsupported provider behavior: {behavior}")

    mapping = {
        "DOMAIN": "full",
        "DOMAIN-SUFFIX": "suffix",
        "DOMAIN-KEYWORD": "keyword",
        "IP-CIDR": "dip",
        "IP-CIDR6": "dip",
    }
    for raw in payload:
        fields = next(csv.reader([raw], skipinitialspace=True))
        kind = fields[0].upper()
        if kind == "IP-ASN":
            if len(fields) != 3 or fields[2] != "no-resolve":
                raise ValueError("IP-ASN requires no-resolve")
            prefixes = asn_expansions.get(fields[1])
            if not prefixes:
                raise ValueError("IP-ASN has no pinned expansion")
            converted.extend(("dip", str(ipaddress.ip_network(prefix, strict=False))) for prefix in prefixes)
            continue
        if kind not in mapping:
            raise ValueError(f"unsupported rule type: {kind}")
        matcher = mapping[kind]
        expected_fields = 3 if matcher == "dip" else 2
        if len(fields) != expected_fields:
            raise ValueError(f"invalid field count for {kind}")
        if matcher == "dip" and fields[2] != "no-resolve":
            raise ValueError(f"{kind} requires no-resolve")
        value = fields[1]
        if matcher in {"full", "suffix"}:
            value = clean_domain(value)
        elif matcher == "keyword":
            value = clean_keyword(value)
        else:
            value = parse_cidr(kind, value)
        converted.append((matcher, value))
    return converted


def render(providers: list[tuple[str, list[tuple[str, str]]]]) -> str:
    lines = ["routing {"]
    for target, rules in providers:
        if not TARGET.fullmatch(target):
            raise ValueError(f"unsupported target: {target}")
        for matcher, value in rules:
            if matcher in {"full", "suffix", "keyword"}:
                lines.append(f"    domain({matcher}: '{value}') -> {target}")
            elif matcher == "dip":
                lines.append(f"    dip('{value}') -> {target}")
            else:
                raise ValueError(f"unsupported matcher: {matcher}")
    lines.append("}")
    return "\n".join(lines) + "\n"


def convert_manifest(manifest_path: Path, source_dir: Path) -> str:
    manifest = json.loads(manifest_path.read_text())
    expansions = {
        asn: item["prefixes"] for asn, item in manifest.get("asn_expansions", {}).items()
    }
    providers = []
    for provider in manifest["providers"]:
        payload = load_payload(source_dir / f"{provider['name']}.yaml")
        providers.append(
            (
                provider["target"],
                convert_payload(provider["behavior"], payload, expansions),
            )
        )
    return render(providers)


def write_output_0600(path: Path, content: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=str(path.parent))
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(content)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        finally:
            raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    content = convert_manifest(args.manifest, args.source_dir)
    write_output_0600(args.output, content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
