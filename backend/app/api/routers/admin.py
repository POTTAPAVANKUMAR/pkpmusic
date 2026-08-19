from fastapi import APIRouter, Depends, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from app.db.database import get_db
from app.crud import crud
from app.ml.recommender import run_ml_pipeline

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

