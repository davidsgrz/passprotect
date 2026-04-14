#!/usr/bin/env python3
"""
audit.py — Analisis de logs de Vaultwarden
Detecta brute force, credential stuffing y accesos en horarios anomalos.
"""
import re
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime, time
from collections import Counter, defaultdict


# Horarios considerados anomalos (fuera de horario laboral)
ANOMALOUS_HOURS = (time(0, 0), time(6, 0))  # 00:00 - 06:00

# Umbrales de deteccion
BRUTE_FORCE_THRESHOLD = 5        # intentos fallidos desde misma IP
CREDENTIAL_STUFFING_THRESHOLD = 5  # usuarios distintos desde misma IP
ANOMALOUS_ACCESS_THRESHOLD = 3    # accesos fuera de horario desde misma IP


def parse_log_line(line):
    """Extrae timestamp, IP, usuario y tipo de evento de una linea de log."""
    result = {"raw": line.strip()}

    # Extraer timestamp
    ts_match = re.search(r'\[(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})', line)
    if ts_match:
        ts_str = ts_match.group(1).replace('T', ' ')
        try:
            result["timestamp"] = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
        except ValueError:
            pass

    # Extraer IP
    ip_match = re.search(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b', line)
    if ip_match:
        result["ip"] = ip_match.group(1)

    # Extraer email/usuario
    user_match = re.search(r'["\']?(\S+@\S+\.\S+)["\']?', line)
    if user_match:
        result["user"] = user_match.group(1)

    # Detectar tipo de evento
    line_lower = line.lower()
    if "failed" in line_lower or "invalid" in line_lower or "error" in line_lower:
        result["event"] = "failed_login"
    elif "success" in line_lower or "authenticated" in line_lower:
        result["event"] = "successful_login"
    elif "admin" in line_lower:
        result["event"] = "admin_access"

    return result


def analyze_logs(log_path):
    """Analiza el fichero de logs y genera el reporte."""
    if not log_path.exists():
        return {"error": f"Log no encontrado: {log_path}"}

    failed_by_ip = Counter()
    users_by_ip = defaultdict(set)
    anomalous_by_ip = Counter()
    events = []

    with open(log_path, "r", errors="replace") as f:
        for line in f:
            parsed = parse_log_line(line)
            ip = parsed.get("ip")
            user = parsed.get("user")
            event = parsed.get("event")
            ts = parsed.get("timestamp")

            if not ip:
                continue

            if event == "failed_login":
                failed_by_ip[ip] += 1
                if user:
                    users_by_ip[ip].add(user)

            if ts and ANOMALOUS_HOURS[0] <= ts.time() <= ANOMALOUS_HOURS[1]:
                anomalous_by_ip[ip] += 1

            if event:
                events.append(parsed)

    # Generar alertas
    alerts = []

    # Brute force
    for ip, count in failed_by_ip.items():
        if count >= BRUTE_FORCE_THRESHOLD:
            alerts.append({
                "type": "BRUTE_FORCE",
                "severity": "HIGH",
                "ip": ip,
                "failed_attempts": count,
                "description": f"{count} intentos fallidos desde {ip}",
            })

    # Credential stuffing
    for ip, users in users_by_ip.items():
        if len(users) >= CREDENTIAL_STUFFING_THRESHOLD:
            alerts.append({
                "type": "CREDENTIAL_STUFFING",
                "severity": "HIGH",
                "ip": ip,
                "unique_users": len(users),
                "users": list(users)[:10],
                "description": f"{len(users)} usuarios distintos desde {ip}",
            })

    # Accesos anomalos
    for ip, count in anomalous_by_ip.items():
        if count >= ANOMALOUS_ACCESS_THRESHOLD:
            alerts.append({
                "type": "ANOMALOUS_HOURS",
                "severity": "MEDIUM",
                "ip": ip,
                "access_count": count,
                "description": f"{count} accesos fuera de horario desde {ip}",
            })

    # Severidad global
    high_count = sum(1 for a in alerts if a["severity"] == "HIGH")
    if high_count > 0:
        severity = "HIGH"
    elif alerts:
        severity = "MEDIUM"
    else:
        severity = "LOW"

    return {
        "log_file": str(log_path),
        "scanned_at": datetime.now().isoformat(),
        "total_events": len(events),
        "failed_logins": sum(failed_by_ip.values()),
        "unique_ips": len(failed_by_ip),
        "severity": severity,
        "alerts": alerts,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Auditor de logs de Vaultwarden — detecta brute force y credential stuffing"
    )
    parser.add_argument("--log", "-l", default="/data/vaultwarden.log",
                        help="Ruta al log de Vaultwarden")
    parser.add_argument("--output", "-o", default="./audit-report.json",
                        help="Ruta del reporte JSON")
    args = parser.parse_args()

    report = analyze_logs(Path(args.log))

    with open(args.output, "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=str)

    print(f"[*] Analizado: {args.log}")
    print(f"[*] Eventos: {report.get('total_events', 0)}")
    print(f"[*] Logins fallidos: {report.get('failed_logins', 0)}")
    print(f"[*] Severidad: {report.get('severity', 'N/A')}")

    if report.get("alerts"):
        print(f"\n[!] ALERTAS: {len(report['alerts'])}")
        for alert in report["alerts"]:
            print(f"    [{alert['severity']}] {alert['type']}: {alert['description']}")

    sys.exit(2 if report.get("severity") == "HIGH" else 0)


if __name__ == "__main__":
    main()
