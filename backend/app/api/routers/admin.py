from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from pydantic import BaseModel
from app.db.database import get_db
from app.crud import crud
from app.ml.recommender import run_ml_pipeline
from app.services import server_manager

router = APIRouter(prefix="/admin", tags=["admin"])

class MLJobRunResponse(BaseModel):
    id: int
    status: str
    started_at: float
    completed_at: Optional[float] = None
    users_processed: int = 0
    recommendations_generated: int = 0
    error_message: Optional[str] = None
    
    class Config:
        from_attributes = True

class ContainerActionRequest(BaseModel):
    action: str # "restart", "stop", "start"

@router.get("/jobs/ml/metrics", response_model=List[MLJobRunResponse])
def get_ml_metrics(db: Session = Depends(get_db)):
    """Fetch the history of ML job runs for the analytics dashboard."""
    runs = crud.get_ml_job_runs(db, limit=20)
    return runs

@router.post("/jobs/ml/trigger")
def trigger_ml_job(background_tasks: BackgroundTasks):
    """Manually trigger the ML pipeline to run in the background."""
    background_tasks.add_task(run_ml_pipeline)
    return {"message": "ML pipeline triggered successfully in the background."}

# --- SERVER HUB ENDPOINTS ---

@router.get("/server/system", response_model=Dict[str, Any])
def get_system_telemetry():
    """Fetch real-time CPU, RAM, Disk, Temperature, Uptime and OS metrics."""
    try:
        return server_manager.get_system_metrics()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/server/containers", response_model=List[Dict[str, Any]])
def get_containers():
    """Fetch list of all Docker containers and their states."""
    try:
        return server_manager.get_docker_containers()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/server/containers/{container_id}/action", response_model=Dict[str, Any])
def container_action(container_id: str, req: ContainerActionRequest):
    """Execute restart, stop, or start on a Docker container."""
    try:
        result = server_manager.perform_container_action(container_id, req.action)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/server/containers/{container_id}/logs", response_model=Dict[str, Any])
def get_container_logs(container_id: str, tail: int = Query(150, ge=10, le=1000)):
    """Fetch stdout/stderr logs for a given container."""
    try:
        logs = server_manager.get_container_logs(container_id, tail=tail)
        return {"container_id": container_id, "logs": logs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/server/docker/prune", response_model=Dict[str, Any])
def prune_docker():
    """Run docker system prune to free unused space."""
    try:
        return server_manager.prune_docker_system()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/server/services", response_model=List[Dict[str, Any]])
async def get_services_status():
    """Health check all Cloudflare tunnel routes and subdomains."""
    try:
        return await server_manager.get_all_services_health()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- FILE EXPLORER ENDPOINTS ---

class FileWriteRequest(BaseModel):
    path: str
    content: str

class FileMkdirRequest(BaseModel):
    path: str
    name: str

class FileRenameRequest(BaseModel):
    old_path: str
    new_name: str

@router.get("/server/fs/list", response_model=Dict[str, Any])
def list_server_directory(path: str = Query("~")):
    """List directory contents on host server."""
    try:
        return server_manager.list_directory(path)
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/server/fs/read", response_model=Dict[str, Any])
def read_server_file(path: str = Query(...)):
    """Read a text or code file from the server."""
    try:
        return server_manager.read_file_content(path)
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/server/fs/write", response_model=Dict[str, Any])
def write_server_file(req: FileWriteRequest):
    """Write/save content to a file on the server."""
    try:
        return server_manager.write_file_content(req.path, req.content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/server/fs/mkdir", response_model=Dict[str, Any])
def create_server_folder(req: FileMkdirRequest):
    """Create a new folder on the server."""
    try:
        return server_manager.create_directory(req.path, req.name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/server/fs/delete", response_model=Dict[str, Any])
def delete_server_file(path: str = Query(...)):
    """Delete a file or folder on the server."""
    try:
        return server_manager.delete_file_or_dir(path)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/server/fs/rename", response_model=Dict[str, Any])
def rename_server_file(req: FileRenameRequest):
    """Rename a file or folder on the server."""
    try:
        return server_manager.rename_file_or_dir(req.old_path, req.new_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

