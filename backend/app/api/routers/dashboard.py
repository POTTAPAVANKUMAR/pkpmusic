from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
import time
import asyncio

from app import schemas
from app.crud import crud
from app.core import security as auth
from app.db.database import get_db, SessionLocal
from app.services.youtube import yt
from app.db import models

router = APIRouter(tags=["dashboard"])

dashboard_cache = {
    "data": None,
    "timestamp": 0
}
CACHE_TTL = 3600 # 1 hour

def get_dashboard_sync(user_id: int, db: Session):
    global dashboard_cache
    sections = []
    
    # 1. Trending Songs (Charts)
    try:
        charts = yt.get_charts(country='US')
        trending_items = []
        if 'trending' in charts and 'items' in charts['trending']:
            for track in charts['trending']['items'][:10]:
                trending_items.append(schemas.DashboardItem(
                    id=track['videoId'],
                    title=track.get('title', 'Unknown'),
                    subtitle=", ".join([a['name'] for a in track.get('artists', [])]),
                    image_url=track.get('thumbnails', [{}])[-1].get('url'),
                    type="song"
                ))
            if trending_items:
                sections.append(schemas.DashboardSection(title="Trending Hits", items=trending_items))
    except Exception as e:
        print(f"Error fetching charts: {e}")

    # 2. For You (Personalized Recommendations based on history)
    history = crud.get_history(db, user_id=user_id, limit=1)
    if history:
        try:
            seed_song = history[0].song_id
            watch_playlist = yt.get_watch_playlist(videoId=seed_song, limit=15)
            foryou_items = []
            for track in watch_playlist.get('tracks', [])[1:11]: # Skip the seed song itself
                if track.get('videoId'):
                    foryou_items.append(schemas.DashboardItem(
                        id=track['videoId'],
                        title=track.get('title', 'Unknown'),
                        subtitle=", ".join([a['name'] for a in track.get('artists', [])]),
                        image_url=track.get('thumbnail', [{}])[-1].get('url'),
                        type="song"
                    ))
            if foryou_items:
                sections.append(schemas.DashboardSection(title="Recommended For You", items=foryou_items))
        except Exception as e:
            print(f"Error fetching recommendations: {e}")

    # 3. Moods & Genres
    try:
        moods = yt.get_mood_categories()
        mood_items = []
        for category_group in moods.values():
            for mood in category_group[:5]:
                mood_items.append(schemas.DashboardItem(
                    id=mood['params'],
                    title=mood['title'],
                    type="mood"
                ))
            if len(mood_items) > 15:
                break
        if mood_items:
            sections.append(schemas.DashboardSection(title="Moods & Genres", items=mood_items))
    except Exception as e:
        print(f"Error fetching moods: {e}")

    # 4. Featured Playlists
    try:
        home = yt.get_home(limit=2)
        for section in home:
            title = section.get('title', 'Featured')
            items = []
            for content in section.get('contents', [])[:10]:
                if content.get('videoId'):
                    items.append(schemas.DashboardItem(
                        id=content['videoId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=", ".join([a['name'] for a in content.get('artists', [])]) if content.get('artists') else "",
                        image_url=content.get('thumbnails', [{}])[-1].get('url'),
                        type="song"
                    ))
                elif content.get('playlistId'):
                    items.append(schemas.DashboardItem(
                        id=content['playlistId'],
                        title=content.get('title', 'Unknown'),
                        subtitle=content.get('description'),
                        image_url=content.get('thumbnails', [{}])[-1].get('url'),
                        type="playlist"
                    ))
            if items:
                sections.append(schemas.DashboardSection(title=title, items=items))
    except Exception as e:
        print(f"Error fetching home features: {e}")

    dashboard_cache["data"] = sections
    dashboard_cache["timestamp"] = time.time()
    return sections

@router.get("/dashboard/", response_model=List[schemas.DashboardSection])
def get_dashboard(current_user: models.User = Depends(auth.get_current_user), db: Session = Depends(get_db)):
    global dashboard_cache
    if dashboard_cache["data"] and (time.time() - dashboard_cache["timestamp"]) < CACHE_TTL:
        return dashboard_cache["data"]
    return get_dashboard_sync(current_user.id, db)

@router.get("/moods/{params}", response_model=List[schemas.DashboardItem])
def get_mood_playlists(params: str):
    try:
        playlists = yt.get_mood_playlists(params)
        items = []
        for p in playlists:
            if 'videoId' in p or 'playlistId' in p:
                items.append(schemas.DashboardItem(
                    id=p.get('playlistId') or p.get('videoId'),
                    title=p.get('title', 'Unknown'),
                    subtitle=p.get('description') or p.get('subtitle', ''),
                    image_url=p.get('thumbnails', [{}])[-1].get('url'),
                    type="playlist"
                ))
        return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
