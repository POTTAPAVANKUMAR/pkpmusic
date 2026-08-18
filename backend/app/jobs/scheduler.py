from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from app.ml.recommender import run_ml_pipeline
import logging

logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler()

def start_scheduler():
    # Schedule the ML pipeline to run every day at 3:00 AM
    scheduler.add_job(
        run_ml_pipeline,
        CronTrigger(hour=3, minute=0),
        id="nightly_ml_pipeline",
        replace_existing=True
    )
    
    scheduler.start()
    logger.info("APScheduler started. Nightly ML pipeline scheduled at 3:00 AM.")
