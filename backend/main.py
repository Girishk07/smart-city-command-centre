from datetime import datetime
from pathlib import Path
import os
import platform
import shutil

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI(
    title="Smart City Command Centre API",
    description="System monitoring, department logs, and administrator alerts",
    version="1.0.0",
)

PROJECT_DIR = Path.home() / "smart-city-command-centre"
LOG_DIR = PROJECT_DIR / "logs"
STATIC_DIR = PROJECT_DIR / "backend" / "static"

DEPARTMENTS = [
    "traffic",
    "water",
    "power",
    "waste",
    "safety",
    "healthcare",
]

ALERT_FILE = LOG_DIR / "administrator_alerts.log"


@app.get("/", include_in_schema=False)
def dashboard():
    index_file = STATIC_DIR / "index.html"
    if not index_file.is_file():
        raise HTTPException(status_code=404, detail="Dashboard not found")
    return FileResponse(index_file)


@app.get("/api/v1/health")
def health_check():
    return {
        "status": "healthy",
        "service": "Smart City Command Centre API",
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/api/v1/system-status")
def system_status():
    disk = shutil.disk_usage("/")
    return {
        "hostname": platform.node(),
        "operating_system": platform.system(),
        "os_release": platform.release(),
        "python_version": platform.python_version(),
        "cpu_count": os.cpu_count(),
        "disk_total_gb": round(disk.total / (1024**3), 2),
        "disk_used_gb": round(disk.used / (1024**3), 2),
        "disk_free_gb": round(disk.free / (1024**3), 2),
        "timestamp": datetime.now().isoformat(),
    }


@app.get("/api/v1/departments")
def list_departments():
    return {"departments": DEPARTMENTS, "total": len(DEPARTMENTS)}


@app.get("/api/v1/logs/{department}")
def get_department_logs(
    department: str,
    limit: int = Query(default=50, ge=1, le=500),
):
    department = department.lower()

    if department not in DEPARTMENTS:
        raise HTTPException(
            status_code=404,
            detail={
                "message": "Invalid department",
                "allowed_departments": DEPARTMENTS,
            },
        )

    log_file = LOG_DIR / f"{department}.log"

    if not log_file.is_file():
        raise HTTPException(status_code=404, detail="Department log not found")

    with log_file.open("r", encoding="utf-8", errors="replace") as file:
        logs = [line.rstrip("\n") for line in file if line.strip()]

    selected_logs = logs[-limit:]

    return {
        "department": department,
        "total": len(logs),
        "returned": len(selected_logs),
        "logs": selected_logs,
    }


@app.get("/api/v1/alerts")
def get_administrator_alerts(
    limit: int = Query(default=50, ge=1, le=500),
):
    if not ALERT_FILE.is_file():
        raise HTTPException(status_code=404, detail="Alerts file not found")

    with ALERT_FILE.open("r", encoding="utf-8", errors="replace") as file:
        alerts = [line.rstrip("\n") for line in file if line.strip()]

    selected_alerts = alerts[-limit:]

    return {
        "source": str(ALERT_FILE),
        "total": len(alerts),
        "returned": len(selected_alerts),
        "alerts": selected_alerts,
        "message": "No administrator alerts recorded" if not alerts else None,
    }


@app.get("/api/v1/overview")
def overview():
    department_counts = {}

    for department in DEPARTMENTS:
        log_file = LOG_DIR / f"{department}.log"
        if log_file.is_file():
            with log_file.open(
                "r", encoding="utf-8", errors="replace"
            ) as file:
                department_counts[department] = sum(
                    1 for line in file if line.strip()
                )
        else:
            department_counts[department] = 0

    alert_count = 0
    if ALERT_FILE.is_file():
        with ALERT_FILE.open(
            "r", encoding="utf-8", errors="replace"
        ) as file:
            alert_count = sum(1 for line in file if line.strip())

    return {
        "departments": len(DEPARTMENTS),
        "department_log_counts": department_counts,
        "total_department_logs": sum(department_counts.values()),
        "administrator_alerts": alert_count,
        "timestamp": datetime.now().isoformat(),
    }


app.mount(
    "/static",
    StaticFiles(directory=str(STATIC_DIR), check_dir=False),
    name="static",
)
