from pydantic import BaseModel
from typing import List, Optional

class SongBase(BaseModel):
    id: str # YouTube ID
    title: str
    artist: str
    album: Optional[str] = None
    duration_ms: Optional[int] = None
    cover_art_url: Optional[str] = None
    bpm: Optional[float] = None
    energy: Optional[float] = None
    danceability: Optional[float] = None

class SongCreate(SongBase):
    pass

class Song(SongBase):
    class Config:
        from_attributes = True

class PlaylistItemBase(BaseModel):
    song_id: str
    position: int

class PlaylistItemCreate(PlaylistItemBase):
    pass

class PlaylistItem(PlaylistItemBase):
    id: int
    playlist_id: int
    song: Song

    class Config:
        from_attributes = True

class PlaylistBase(BaseModel):
    name: str
    description: Optional[str] = None

class PlaylistCreate(PlaylistBase):
    pass

class Playlist(PlaylistBase):
    id: int
    owner_id: int
    items: List[PlaylistItem] = []

    class Config:
        from_attributes = True

class HistoryBase(BaseModel):
    song_id: str
    played_at: str

class HistoryCreate(HistoryBase):
    pass

class History(HistoryBase):
    id: int
    user_id: int
    song: Song

    class Config:
        from_attributes = True

class FavoriteBase(BaseModel):
    song_id: str

class FavoriteCreate(FavoriteBase):
    pass

class Favorite(FavoriteBase):
    id: int
    user_id: int
    song: Song

    class Config:
        from_attributes = True

class UserBase(BaseModel):
    username: str
    email: str

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool
    playlists: List[Playlist] = []

    class Config:
        from_attributes = True

class DashboardItem(BaseModel):
    id: str # YouTube ID or category ID
    title: str
    subtitle: Optional[str] = None
    image_url: Optional[str] = None
    type: str # "song", "playlist", "mood"

class DashboardSection(BaseModel):
    title: str
    items: List[DashboardItem]
