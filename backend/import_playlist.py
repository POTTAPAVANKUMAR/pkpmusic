import csv
import argparse
from sqlalchemy.orm import Session
import models, schemas, crud
from database import SessionLocal, engine

# Ensure tables exist
models.Base.metadata.create_all(bind=engine)

def import_csv(file_path: str, playlist_name: str, user_id: int):
    """
    Imports a CSV file exported from TuneMyMusic/Soundiiz (Amazon Music -> CSV).
    Expected CSV columns: Title, Artist, Album
    """
    db = SessionLocal()
    try:
        # Create the playlist
        playlist_data = schemas.PlaylistCreate(name=playlist_name, source="imported_csv")
        playlist = crud.create_user_playlist(db=db, playlist=playlist_data, user_id=user_id)
        
        print(f"Created Playlist: {playlist.name} (ID: {playlist.id})")
        
        with open(file_path, mode='r', encoding='utf-8') as file:
            csv_reader = csv.DictReader(file)
            
            position = 1
            for row in csv_reader:
                title = row.get("Title") or row.get("Track Name")
                artist = row.get("Artist") or row.get("Artist Name")
                album = row.get("Album")
                
                if not title or not artist:
                    continue
                    
                # Check if song already exists
                song = db.query(models.Song).filter(
                    models.Song.title == title, 
                    models.Song.artist == artist
                ).first()
                
                # If not, create it
                if not song:
                    song_data = schemas.SongCreate(
                        title=title,
                        artist=artist,
                        album=album,
                        # Provide default audio features for the ML model to work with
                        bpm=120.0, 
                        energy=0.5,
                        danceability=0.5
                    )
                    song = crud.create_song(db=db, song=song_data)
                
                # Add song to playlist
                item_data = schemas.PlaylistItemCreate(song_id=song.id, position=position)
                crud.add_song_to_playlist(db=db, playlist_id=playlist.id, item=item_data)
                
                print(f"Added: {title} by {artist}")
                position += 1
                
        print("Import completed successfully!")
        
    finally:
        db.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import Amazon Music CSV playlist.")
    parser.add_argument("file", help="Path to the CSV file")
    parser.add_argument("name", help="Name of the new playlist")
    parser.add_argument("--user", type=int, default=1, help="User ID to own the playlist")
    
    args = parser.parse_args()
    import_csv(args.file, args.name, args.user)
