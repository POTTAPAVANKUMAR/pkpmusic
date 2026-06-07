from fastapi import FastAPI
from app.api.routers import auth, playlists, songs, social, dashboard
from app.services import websocket
from app.db.database import engine
from app.db import models
import asyncio
import app.api.routers.dashboard as dashboard_router

# Create the database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="PKP Music API", description="Backend for the new cross-platform music app.")

app.include_router(auth.router)
app.include_router(playlists.router)
app.include_router(songs.router)
app.include_router(social.router)
app.include_router(dashboard.router)
app.include_router(websocket.router)

@app.on_event("startup")
async def startup_event():
    # Pre-warm the cache in the background
    asyncio.create_task(prewarm_dashboard_cache())

async def prewarm_dashboard_cache():
    try:
        await asyncio.sleep(5)
        from app.db.database import SessionLocal
        db = SessionLocal()
        dashboard_router.get_dashboard_sync(user_id=1, db=db)
        db.close()
    except Exception as e:
        print(f"Error pre-warming cache: {e}")

@app.get("/")
def read_root():
    return {"message": "Welcome to the PKP Music API"}
