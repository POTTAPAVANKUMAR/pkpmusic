from fastapi import APIRouter, HTTPException
from app.services.youtube import yt

router = APIRouter(prefix="/podcasts", tags=["podcasts"])

@router.get("/channel/{channel_id}", response_model=dict)
def get_podcast_channel(channel_id: str):
    """
    Get a podcast channel's details.
    """
    try:
        channel_info = yt.get_channel(channel_id)
        return {"channel": channel_info}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/channel/{channel_id}/episodes", response_model=dict)
def get_podcast_channel_episodes(channel_id: str, params: str):
    """
    Get a podcast channel's episodes.
    """
    try:
        episodes = yt.get_channel_episodes(channel_id, params)
        return {"episodes": episodes}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{podcast_id}", response_model=dict)
def get_podcast_details(podcast_id: str):
    """
    Get podcast details.
    """
    try:
        podcast_info = yt.get_podcast(podcast_id)
        return {"podcast": podcast_info}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/episode/{episode_id}", response_model=dict)
def get_podcast_episode(episode_id: str):
    """
    Get podcast episode details.
    """
    try:
        episode_info = yt.get_episode(episode_id)
        return {"episode": episode_info}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/episode/{episode_id}/playlist", response_model=dict)
def get_podcast_episodes_playlist(episode_id: str):
    """
    Get the playlist of episodes for a given podcast episode.
    """
    try:
        # We need the playlist ID for get_episodes_playlist, but typically episode_id refers to videoId
        # ytmusicapi documentation says `get_episodes_playlist(playlist_id)`
        # I'll just map it directly.
        playlist_data = yt.get_episodes_playlist(episode_id)
        return {"playlist": playlist_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
