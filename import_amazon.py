import csv
import sys
import os
import json
import time
from ytmusicapi import YTMusic

# Assuming we run this INSIDE the docker container where crud, schemas, database, models are available
sys.path.append("/app")
from database import SessionLocal
import crud
import schemas

db = SessionLocal()
yt = YTMusic()

print("Starting import from MyAmazonMusicLibrary.csv...")
with open("/app/MyAmazonMusicLibrary.csv", "r", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    imported = 0
    total = 0
    for row in reader:
        total += 1
        title = row.get("Track name")
        artist = row.get("Artist name")
        if not title:
            continue
            
        print(f"Searching [{total}]: {title} by {artist}...")
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
                
                # Check if it's already in favorites
                existing_favs = crud.get_favorites(db, user_id=1)
                if not any(f.song_id == video_id for f in existing_favs):
                    fav = schemas.FavoriteCreate(song_id=video_id)
                    crud.add_favorite(db, fav, user_id=1)
                    imported += 1
                    print(f"Added {title} to Favorites! (Total imported: {imported})")
                else:
                    print(f"Already in Favorites: {title}")
            else:
                print(f"Not found on YouTube Music: {title}")
        except Exception as e:
            print(f"Error importing {title}: {e}")
            time.sleep(2) # Backoff on error

print(f"Import complete! Successfully added {imported} songs out of {total}.")
