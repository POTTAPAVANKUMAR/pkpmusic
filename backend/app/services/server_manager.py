import os
import shutil
import time
import platform
import socket
import logging
import asyncio
from typing import Dict, List, Any, Optional
import httpx

logger = logging.getLogger(__name__)

DOCKER_SOCKET = "/var/run/docker.sock"

def format_bytes(bytes_num: int) -> str:
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_num < 1024.0:
            return f"{bytes_num:.1f} {unit}"
        bytes_num /= 1024.0
    return f"{bytes_num:.1f} PB"

def format_uptime(seconds: float) -> str:
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    parts = []
    if days > 0:
        parts.append(f"{days}d")
    if hours > 0:
        parts.append(f"{hours}h")
    parts.append(f"{minutes}m")
    return " ".join(parts)

def get_system_metrics() -> Dict[str, Any]:
    """Collect real-time Raspberry Pi / host system telemetry."""
    # 1. Host Info
    hostname = "pavankumarpotta"
    uname = platform.uname()
    os_name = f"Raspberry Pi OS ({uname.system} {uname.release})"
    arch = uname.machine
    
    # 2. CPU info & load
    cpu_count = os.cpu_count() or 4
    load_avg = [0.0, 0.0, 0.0]
    try:
        load_avg = list(os.getloadavg())
    except Exception:
        pass
    
    cpu_usage_pct = min(100.0, max(0.0, (load_avg[0] / cpu_count) * 100.0))
    
    # 3. CPU Temperature
    temp_c = None
    for temp_path in [
        "/host_sys/class/thermal/thermal_zone0/temp",
        "/sys/class/thermal/thermal_zone0/temp"
    ]:
        if os.path.exists(temp_path):
            try:
                with open(temp_path, "r") as f:
                    raw_val = f.read().strip()
                    temp_c = round(float(raw_val) / 1000.0, 1)
                    break
            except Exception:
                pass
                
    # 4. Memory Usage (/proc/meminfo)
    mem_total = 0
    mem_avail = 0
    mem_free = 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                key = parts[0].strip()
                val = parts[1].strip().split()[0]
                if key == "MemTotal":
                    mem_total = int(val) * 1024
                elif key == "MemAvailable":
                    mem_avail = int(val) * 1024
                elif key == "MemFree":
                    mem_free = int(val) * 1024
    except Exception:
        pass
        
    if mem_total > 0:
        mem_used = mem_total - (mem_avail if mem_avail > 0 else mem_free)
        mem_pct = round((mem_used / mem_total) * 100.0, 1)
    else:
        mem_total = 4 * 1024 * 1024 * 1024
        mem_used = 1 * 1024 * 1024 * 1024
        mem_avail = 3 * 1024 * 1024 * 1024
        mem_pct = 25.0

    # 5. Disk Usage
    try:
        disk_usage = shutil.disk_usage("/")
        disk_total = disk_usage.total
        disk_used = disk_usage.used
        disk_free = disk_usage.free
        disk_pct = round((disk_used / disk_total) * 100.0, 1) if disk_total > 0 else 0.0
    except Exception:
        disk_total, disk_used, disk_free, disk_pct = 0, 0, 0, 0.0

    # 6. Uptime
    uptime_sec = 0.0
    try:
        with open("/proc/uptime", "r") as f:
            uptime_sec = float(f.readline().split()[0])
    except Exception:
        pass
        
    # 7. Local IP
    local_ip = "192.168.1.151"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        pass

    return {
        "hostname": hostname,
        "os_name": os_name,
        "arch": arch,
        "local_ip": local_ip,
        "uptime_seconds": uptime_sec,
        "uptime_formatted": format_uptime(uptime_sec),
        "cpu_count": cpu_count,
        "load_avg": [round(x, 2) for x in load_avg],
        "cpu_usage_pct": round(cpu_usage_pct, 1),
        "temperature_c": temp_c,
        "memory": {
            "total_bytes": mem_total,
            "used_bytes": mem_used,
            "free_bytes": mem_avail,
            "total_formatted": format_bytes(mem_total),
            "used_formatted": format_bytes(mem_used),
            "free_formatted": format_bytes(mem_avail),
            "usage_pct": mem_pct
        },
        "disk": {
            "total_bytes": disk_total,
            "used_bytes": disk_used,
            "free_bytes": disk_free,
            "total_formatted": format_bytes(disk_total),
            "used_formatted": format_bytes(disk_used),
            "free_formatted": format_bytes(disk_free),
            "usage_pct": disk_pct
        }
    }

def get_docker_client() -> Optional[httpx.Client]:
    if os.path.exists(DOCKER_SOCKET):
        try:
            return httpx.Client(transport=httpx.HTTPTransport(uds=DOCKER_SOCKET), timeout=8.0)
        except Exception as e:
            logger.warning(f"Could not initialize Docker UDS client: {e}")
    return None

def get_docker_containers() -> List[Dict[str, Any]]:
    """List all Docker containers with normalized statuses."""
    client = get_docker_client()
    if not client:
        return []
    
    try:
        response = client.get("http://docker/containers/json?all=1")
        if response.status_code != 200:
            return []
        
        raw_containers = response.json()
        containers = []
        for c in raw_containers:
            names = c.get("Names", [])
            name = names[0].lstrip("/") if names else c.get("Id", "")[:12]
            state = c.get("State", "").lower() # 'running', 'exited', 'restarting', etc.
            status_text = c.get("Status", "")
            image = c.get("Image", "")
            
            # Format ports
            ports = []
            for p in c.get("Ports", []):
                pub = p.get("PublicPort")
                priv = p.get("PrivatePort")
                t = p.get("Type", "tcp")
                if pub:
                    ports.append(f"{pub}:{priv}/{t}")
                elif priv:
                    ports.append(f"{priv}/{t}")
                    
            containers.append({
                "id": c.get("Id", ""),
                "short_id": c.get("Id", "")[:12],
                "name": name,
                "image": image,
                "state": state,
                "status": status_text,
                "is_running": state == "running",
                "created": c.get("Created", 0),
                "ports": ports
            })
        return sorted(containers, key=lambda x: (not x["is_running"], x["name"]))
    except Exception as e:
        logger.error(f"Error fetching docker containers: {e}")
        return []
    finally:
        client.close()

def perform_container_action(container_id: str, action: str) -> Dict[str, Any]:
    """Execute action on a Docker container (restart, stop, start)."""
    if action not in ["restart", "stop", "start"]:
        raise ValueError(f"Invalid action: {action}")
        
    client = get_docker_client()
    if not client:
        raise RuntimeError("Docker socket is not accessible")
        
    try:
        url = f"http://docker/containers/{container_id}/{action}"
        response = client.post(url)
        if response.status_code in [204, 200, 304]:
            return {"success": True, "action": action, "container_id": container_id}
        else:
            return {"success": False, "error": response.text, "status_code": response.status_code}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        client.close()

def clean_docker_log_stream(raw_bytes: bytes) -> str:
    """Strip 8-byte Docker multiplexed headers if present."""
    try:
        # Standard multiplexed header: 1 byte stream type, 3 bytes zero, 4 bytes payload size
        cleaned_parts = []
        i = 0
        n = len(raw_bytes)
        # Check if stream has standard docker headers
        if n >= 8 and raw_bytes[0] in [1, 2] and raw_bytes[1:4] == b'\x00\x00\x00':
            while i < n:
                if i + 8 <= n:
                    size = int.from_bytes(raw_bytes[i+4:i+8], byteorder='big')
                    chunk = raw_bytes[i+8:i+8+size]
                    cleaned_parts.append(chunk.decode('utf-8', errors='replace'))
                    i += 8 + size
                else:
                    cleaned_parts.append(raw_bytes[i:].decode('utf-8', errors='replace'))
                    break
            return "".join(cleaned_parts)
        else:
            return raw_bytes.decode('utf-8', errors='replace')
    except Exception:
        return raw_bytes.decode('utf-8', errors='replace')

def get_container_logs(container_id: str, tail: int = 150) -> str:
    """Fetch recent stdout/stderr logs from a container."""
    client = get_docker_client()
    if not client:
        return "Docker socket unavailable"
        
    try:
        url = f"http://docker/containers/{container_id}/logs?stdout=1&stderr=1&tail={tail}&timestamps=1"
        response = client.get(url)
        if response.status_code == 200:
            return clean_docker_log_stream(response.content)
        else:
            return f"Failed to fetch logs: {response.text}"
    except Exception as e:
        return f"Error retrieving logs: {str(e)}"
    finally:
        client.close()

def prune_docker_system() -> Dict[str, Any]:
    """Run docker system prune to free space on host."""
    client = get_docker_client()
    if not client:
        return {"success": False, "error": "Docker socket unavailable"}
        
    try:
        # Prune stopped containers
        r_cont = client.post("http://docker/containers/prune")
        # Prune dangling images
        r_img = client.post("http://docker/images/prune")
        
        reclaimed_bytes = 0
        containers_deleted = 0
        images_deleted = 0
        
        if r_cont.status_code == 200:
            d = r_cont.json()
            reclaimed_bytes += d.get("SpaceReclaimed", 0)
            containers_deleted = len(d.get("ContainersDeleted") or [])
            
        if r_img.status_code == 200:
            d = r_img.json()
            reclaimed_bytes += d.get("SpaceReclaimed", 0)
            images_deleted = len(d.get("ImagesDeleted") or [])
            
        return {
            "success": True,
            "space_reclaimed_bytes": reclaimed_bytes,
            "space_reclaimed_formatted": format_bytes(reclaimed_bytes),
            "containers_deleted": containers_deleted,
            "images_deleted": images_deleted
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        client.close()

MONITORED_SERVICES = [
    {"name": "Landing Dashboard", "url": "https://pottapk.win", "service": "Landing Page", "port": 3000, "icon": "house.fill"},
    {"name": "PKP Music Web Player", "url": "https://pkpmusicweb.pottapk.win", "service": "Angular Web App", "port": 3001, "icon": "music.note.house.fill"},
    {"name": "PKP Music API", "url": "https://pkpmusic.pottapk.win/docs", "service": "FastAPI Backend", "port": 8000, "icon": "music.note"},
    {"name": "Live Server Logs", "url": "https://pkpmusiclogs.pottapk.win", "service": "Dozzle Log Viewer", "port": 8888, "icon": "terminal.fill"},
    {"name": "PostgreSQL pgAdmin", "url": "https://postgresql.pottapk.win", "service": "pgAdmin DB GUI", "port": 5050, "icon": "cylinder.split.1x2"},
    {"name": "Portainer Docker GUI", "url": "https://portainer.pottapk.win", "service": "Portainer CE", "port": 9000, "icon": "shippingbox.fill"},
    {"name": "CasaOS Cloud", "url": "https://cloud.pottapk.win", "service": "CasaOS Dashboard", "port": 80, "icon": "cloud.fill"},
    {"name": "PiCloud Web", "url": "https://app.pottapk.win", "service": "PiCloud Portal", "port": 8080, "icon": "internaldrive.fill"},
    {"name": "PiCloud API", "url": "https://api.pottapk.win", "service": "PiCloud API", "port": 5000, "icon": "network"},
]

async def check_service_health(service_info: Dict[str, Any]) -> Dict[str, Any]:
    url = service_info["url"]
    start = time.time()
    try:
        async with httpx.AsyncClient(timeout=4.0, verify=False) as client:
            resp = await client.get(url)
            latency = int((time.time() - start) * 1000)
            return {
                **service_info,
                "is_online": resp.status_code < 500,
                "status_code": resp.status_code,
                "latency_ms": latency
            }
    except Exception:
        latency = int((time.time() - start) * 1000)
        return {
            **service_info,
            "is_online": False,
            "status_code": 0,
            "latency_ms": latency
        }

async def get_all_services_health() -> List[Dict[str, Any]]:
    """Concurrent health check of all Cloudflare subdomains."""
    tasks = [check_service_health(s) for s in MONITORED_SERVICES]
    results = await asyncio.gather(*tasks)
    return results

# --- FILE EXPLORER / FILE MANAGER ---

def resolve_fs_path(path: str) -> str:
    """Resolve and normalize host filesystem paths safely."""
    if not path or path in ["~", "home", "/home"]:
        if os.path.exists("/host_home"):
            return "/host_home"
        return "/app"
    
    # Map user friendly prefixes
    if path.startswith("~/"):
        if os.path.exists("/host_home"):
            path = os.path.join("/host_home", path[2:])
        else:
            path = os.path.join("/app", path[2:])
    elif path.startswith("/home/pavankumarpotta"):
        if os.path.exists("/host_home"):
            path = path.replace("/home/pavankumarpotta", "/host_home", 1)
            
    norm = os.path.abspath(os.path.normpath(path))
    return norm

def get_file_icon(name: str, is_dir: bool) -> str:
    if is_dir:
        return "folder.fill"
    ext = os.path.splitext(name)[1].lower()
    if ext in [".yml", ".yaml", ".conf", ".config", ".ini", ".env"]:
        return "doc.badge.gearshape.fill"
    elif ext in [".py", ".sh", ".bash", ".zsh", ".js", ".ts", ".html", ".css", ".sql"]:
        return "chevron.left.forwardslash.chevron.right"
    elif ext in [".log", ".txt", ".md", ".json"]:
        return "doc.text.fill"
    elif ext in [".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"]:
        return "photo.fill"
    elif ext in [".mp3", ".m4a", ".flac", ".wav", ".aac"]:
        return "music.note"
    elif ext in [".mp4", ".mov", ".mkv"]:
        return "film.fill"
    elif ext in [".zip", ".tar", ".gz", ".deb"]:
        return "archivebox.fill"
    else:
        return "doc.fill"

def list_directory(raw_path: str = "~") -> Dict[str, Any]:
    """List contents of a directory on the server."""
    target_path = resolve_fs_path(raw_path)
    if not os.path.exists(target_path):
        raise FileNotFoundError(f"Path does not exist: {raw_path}")
    if not os.path.isdir(target_path):
        raise NotADirectoryError(f"Path is not a directory: {raw_path}")
        
    parent_path = os.path.dirname(target_path)
    if target_path == "/host_home" or target_path == "/":
        parent_path = None
        
    items = []
    try:
        entries = os.scandir(target_path)
        for entry in entries:
            name = entry.name
            is_dir = entry.is_dir(follow_symlinks=True)
            size_bytes = 0
            mtime = 0.0
            try:
                stat = entry.stat(follow_symlinks=True)
                size_bytes = stat.st_size if not is_dir else 0
                mtime = stat.st_mtime
            except Exception:
                pass
                
            mtime_str = time.strftime("%b %d, %H:%M", time.localtime(mtime)) if mtime > 0 else ""
            ext = os.path.splitext(name)[1].lower() if not is_dir else ""
            
            items.append({
                "id": entry.path,
                "name": name,
                "path": entry.path,
                "is_dir": is_dir,
                "size_bytes": size_bytes,
                "size_formatted": format_bytes(size_bytes) if not is_dir else "",
                "modified_time": mtime,
                "modified_formatted": mtime_str,
                "extension": ext,
                "icon": get_file_icon(name, is_dir)
            })
    except PermissionError:
        raise PermissionError(f"Permission denied accessing: {raw_path}")
        
    sorted_items = sorted(items, key=lambda x: (not x["is_dir"], x["name"].lower()))
    
    display_path = target_path.replace("/host_home", "~")
    display_parent = parent_path.replace("/host_home", "~") if parent_path else None
    
    return {
        "current_path": target_path,
        "display_path": display_path,
        "parent_path": parent_path,
        "display_parent": display_parent,
        "items": sorted_items,
        "item_count": len(sorted_items)
    }

def read_file_content(raw_path: str, max_bytes: int = 2 * 1024 * 1024) -> Dict[str, Any]:
    """Read content of a text or code file."""
    target_path = resolve_fs_path(raw_path)
    if not os.path.exists(target_path):
        raise FileNotFoundError(f"File not found: {raw_path}")
    if os.path.isdir(target_path):
        raise IsADirectoryError(f"Target is a directory: {raw_path}")
        
    stat = os.stat(target_path)
    size = stat.st_size
    if size > max_bytes:
        raise ValueError(f"File is too large to edit on mobile ({format_bytes(size)} > {format_bytes(max_bytes)})")
        
    try:
        with open(target_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        return {
            "path": target_path,
            "display_path": target_path.replace("/host_home", "~"),
            "name": os.path.basename(target_path),
            "content": content,
            "size_bytes": size,
            "size_formatted": format_bytes(size),
            "is_text": True
        }
    except Exception as e:
        raise ValueError(f"Could not read file: {e}")

def write_file_content(raw_path: str, content: str) -> Dict[str, Any]:
    """Save content to a file on the server."""
    target_path = resolve_fs_path(raw_path)
    parent_dir = os.path.dirname(target_path)
    if not os.path.exists(parent_dir):
        os.makedirs(parent_dir, exist_ok=True)
        
    with open(target_path, "w", encoding="utf-8") as f:
        f.write(content)
        
    stat = os.stat(target_path)
    return {
        "success": True,
        "path": target_path,
        "size_bytes": stat.st_size,
        "size_formatted": format_bytes(stat.st_size)
    }

def create_directory(raw_parent_path: str, name: str) -> Dict[str, Any]:
    """Create a new folder."""
    target_dir = resolve_fs_path(raw_parent_path)
    new_dir_path = os.path.join(target_dir, name.strip().lstrip("/"))
    os.makedirs(new_dir_path, exist_ok=True)
    return {"success": True, "path": new_dir_path}

def delete_file_or_dir(raw_path: str) -> Dict[str, Any]:
    """Delete a file or directory."""
    target_path = resolve_fs_path(raw_path)
    if not os.path.exists(target_path):
        raise FileNotFoundError(f"Path does not exist: {raw_path}")
        
    if target_path in ["/", "/host_home", "/app", "/etc", "/var"]:
        raise PermissionError("Cannot delete root system directories")
        
    if os.path.isdir(target_path):
        shutil.rmtree(target_path)
    else:
        os.remove(target_path)
    return {"success": True, "deleted_path": target_path}

def rename_file_or_dir(raw_path: str, new_name: str) -> Dict[str, Any]:
    """Rename a file or directory."""
    target_path = resolve_fs_path(raw_path)
    if not os.path.exists(target_path):
        raise FileNotFoundError(f"Path does not exist: {raw_path}")
        
    parent_dir = os.path.dirname(target_path)
    new_path = os.path.join(parent_dir, new_name.strip())
    os.rename(target_path, new_path)
    return {"success": True, "old_path": target_path, "new_path": new_path}

