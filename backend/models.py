from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Float
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    otp_code = Column(String, nullable=True)
    otp_expires_at = Column(Float, nullable=True) # Epoch timestamp

    playlists = relationship("Playlist", back_populates="owner")


class Song(Base):
    __tablename__ = "songs"

    id = Column(String, primary_key=True, index=True) # YouTube Video ID
    title = Column(String, index=True)
    artist = Column(String, index=True)
    album = Column(String)
    duration_ms = Column(Integer)
    cover_art_url = Column(String)
    
    # Audio features for recommendation
    bpm = Column(Float, nullable=True)
    energy = Column(Float, nullable=True)
    danceability = Column(Float, nullable=True)

    playlist_items = relationship("PlaylistItem", back_populates="song")
    history_items = relationship("History", back_populates="song")
    favorite_items = relationship("Favorite", back_populates="song")


class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String)
    owner_id = Column(Integer, ForeignKey("users.id"))

    owner = relationship("User", back_populates="playlists")
    items = relationship("PlaylistItem", back_populates="playlist")


class PlaylistItem(Base):
    __tablename__ = "playlist_items"

    id = Column(Integer, primary_key=True, index=True)
    playlist_id = Column(Integer, ForeignKey("playlists.id"))
    song_id = Column(String, ForeignKey("songs.id"))
    position = Column(Integer)

    playlist = relationship("Playlist", back_populates="items")
    song = relationship("Song", back_populates="playlist_items")

class History(Base):
    __tablename__ = "history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    song_id = Column(String, ForeignKey("songs.id"))
    played_at = Column(String) # Simple ISO string for now

    song = relationship("Song", back_populates="history_items")

class Favorite(Base):
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    song_id = Column(String, ForeignKey("songs.id"))

    song = relationship("Song", back_populates="favorite_items")
