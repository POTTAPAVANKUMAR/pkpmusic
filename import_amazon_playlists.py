import csv
import sys
import os
import time
from ytmusicapi import YTMusic

sys.path.append("/app")
from database import SessionLocal
import crud
import schemas
import models

db = SessionLocal()
yt = YTMusic()

# Get existing playlists to avoid duplicates
existing_playlists = crud.get_playlists(db, limit=1000)
playlist_map = {p.name: p.id for p in existing_playlists}

print("Starting playlist-aware import from MyAmazonMusicLibrary.csv...")
with open("/app/MyAmazonMusicLibrary.csv", "r", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    imported = 0
    total = 0
    for row in reader:
        total += 1
        title = row.get("Track name")
        artist = row.get("Artist name")
        playlist_name = row.get("Playlist name", "")
        
        if not title:
            continue
            
        print(f"Searching [{total}]: {title} by {artist} (Dest: {playlist_name})...")
        query = f"{title} {artist}"
        try:
            results = yt.search(query, filter="songs")
            if results:
                top_hit = results[0]
                video_id = top_hit['videoId']
                if not video_id:
                    continue
                    
                db_song = crud.get_song(db, video_id)
                if not db_song:
                    song_data = schemas.SongCreate(
                        id=video_id,
                        title=top_hit.get('title', title),
                        artist=top_hit['artists'][0]['name'] if top_hit.get('artists') else artist,
                        album=top_hit['album']['name'] if top_hit.get('album') else None,
                        duration_ms=top_hit.get('duration_seconds', 0) * 1000 if top_hit.get('duration_seconds') else None,
                        cover_art_url=top_hit['thumbnails'][-1]['url'] if top_hit.get('thumbnails') else None
                    )
                    crud.create_song(db, song_data)
                
                if playlist_name in ["Library Songs", "My Likes", "Library Albums", ""]:
                    # Add to Favorites
                    existing_favs = crud.get_favorites(db, user_id=1)
                    if not any(f.song_id == video_id for f in existing_favs):
                        fav = schemas.FavoriteCreate(song_id=video_id)
                        crud.add_favorite(db, fav, user_id=1)
                        print(f"Added to Favorites: {title}")
                else:
                    # Add to specific Playlist
                    if playlist_name not in playlist_map:
                        p_create = schemas.PlaylistCreate(name=playlist_name)
                        new_p = crud.create_user_playlist(db, p_create, user_id=1)
                        playlist_map[playlist_name] = new_p.id
                        print(f"Created Playlist: {playlist_name}")
                        
                    pid = playlist_map[playlist_name]
                    db_playlist = db.query(models.Playlist).filter(models.Playlist.id == pid).first()
                    if db_playlist and not any(i.song_id == video_id for i in db_playlist.items):
                        item = schemas.PlaylistItemCreate(song_id=video_id, position=0)
                        crud.add_song_to_playlist(db, playlist_id=pid, item=item)
                        print(f"Added {title} to Playlist: {playlist_name}")
                    
                imported += 1
        except Exception as e:
            print(f"Error importing {title}: {e}")
            time.sleep(2)

print(f"Import complete! Successfully added {imported} songs out of {total}.")
