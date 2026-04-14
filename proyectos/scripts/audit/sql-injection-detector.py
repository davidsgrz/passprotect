#!/usr/bin/env python3
"""
Detector de intentos de SQL Injection en logs de MariaDB.
Analiza general.log y slow.log buscando patrones sospechosos.
"""
import re
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from collections import Counter

# Patrones de SQLi comunes (basados en OWASP + sqlmap payloads)
SQLI_PATTERNS = [
    # Union-based
    (r"\bUNION\s+(?:ALL\s+)?SELECT\b", "UNION_SELECT"),
    # Boolean-based blind
    (r"\bAND\s+\d+\s*=\s*\d+", "BOOLEAN_BLIND"),
    (r"\bOR\s+\d+\s*=\s*\d+", "BOOLEAN_OR"),
    # Time-based blind
    (r"\bSLEEP\s*\(", "TIME_BASED"),
    (r"\bBENCHMARK\s*\(", "TIME_BASED"),
    (r"\bWAITFOR\s+DELAY\b", "TIME_BASED"),
    # Error-based
    (r"\bEXTRACTVALUE\s*\(", "ERROR_BASED"),
    (r"\bUPDATEXML\s*\(", "ERROR_BASED"),
    # Stacked queries
    (r";\s*(?:DROP|DELETE|INSERT|UPDATE|CREATE)\s+", "STACKED_QUERY"),
    # Comments used to bypass filters
    (r"(?:--|#|/\*)", "COMMENT_BYPASS"),
    # File operations
    (r"\bLOAD_FILE\s*\(", "FILE_READ"),
    (r"\bINTO\s+(?:OUT|DUMP)FILE\b", "FILE_WRITE"),
    # Information schema probing
    (r"\binformation_schema\b", "SCHEMA_PROBE"),
    # Hex encoding (often used to bypass filters)
    (r"0x[0-9a-fA-F]{10,}", "HEX_ENCODED"),
    # Char encoding
    (r"\bCHAR\s*\(\s*\d+", "CHAR_ENCODED"),
]


def analyze_log(log_path):
    """Analiza un fichero de log de MariaDB buscando patrones SQLi."""
    if not log_path.exists():
        return {"error": f"Log not found: {log_path}"}

    detections = []
    pattern_count = Counter()
    ip_count = Counter()

    with open(log_path, "r", errors="replace") as f:
        for line_num, line in enumerate(f, 1):
            for pattern, name in SQLI_PATTERNS:
                if re.search(pattern, line, re.IGNORECASE):
                    detection = {
                        "line": line_num,
                        "pattern": name,
                        "content": line.strip()[:200],
                    }
                    # Extraer IP si es posible
                    ip_match = re.search(
                        r"\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b", line
                    )
                    if ip_match:
                        detection["ip"] = ip_match.group(1)
                        ip_count[ip_match.group(1)] += 1

                    detections.append(detection)
                    pattern_count[name] += 1
                    break  # Un match por linea es suficiente

    total = len(detections)
    if total > 10:
        severity = "HIGH"
    elif total > 0:
        severity = "MEDIUM"
    else:
        severity = "LOW"

    return {
        "log_file": str(log_path),
        "scanned_at": datetime.now().isoformat(),
        "total_detections": total,
        "by_pattern": dict(pattern_count),
        "top_ips": dict(ip_count.most_common(10)),
        "severity": severity,
        "detections": detections[:50],
    }


def main():
    parser = argparse.ArgumentParser(
        description="SQL Injection detector for MariaDB logs"
    )
    parser.add_argument("--log", "-l", default="/var/log/mysql/general.log")
    parser.add_argument("--output", "-o", default="./sqli-report.json")
    args = parser.parse_args()

    report = analyze_log(Path(args.log))

    with open(args.output, "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"[*] Analizadas {args.log}")
    print(f"[*] Detecciones: {report.get('total_detections', 0)}")
    print(f"[*] Severidad: {report.get('severity', 'N/A')}")

    if report.get("by_pattern"):
        print("\n[*] Patrones detectados:")
        for p, c in report["by_pattern"].items():
            print(f"    {p}: {c}")

    sys.exit(2 if report.get("severity") == "HIGH" else 0)


if __name__ == "__main__":
    main()
