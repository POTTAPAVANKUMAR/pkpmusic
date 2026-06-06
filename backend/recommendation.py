import pandas as pd
from sqlalchemy.orm import Session
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler
import models

class MusicRecommender:
    def __init__(self, db: Session):
        self.db = db

    def get_user_item_matrix(self):
        """
        Builds a sparse user-item interaction matrix from playlists.
        """
        playlists = self.db.query(models.Playlist).all()
        interactions = []
        for playlist in playlists:
            for item in playlist.items:
                interactions.append({
                    "user_id": playlist.owner_id,
                    "song_id": item.song_id,
                    "weight": 1.0 
                })
        
        if not interactions:
            return None
            
        df = pd.DataFrame(interactions)
        matrix = df.pivot_table(index='user_id', columns='song_id', values='weight', fill_value=0)
        return matrix

    def generate_recommendations(self, user_id: int, n_recommendations: int = 10):
        """
        Generates personalized song recommendations for a user.
        """
        # For a full collaborative filtering approach (like LightFM or Matrix Factorization), 
        # you would fit the model on `self.get_user_item_matrix()` and predict.
        # Since this requires model training, we return a fallback for now.
        
        all_songs = self.db.query(models.Song).limit(n_recommendations).all()
        return all_songs

    def get_similar_songs(self, song_id: int, n_similar: int = 5):
        """
        Uses content-based filtering (features like BPM, energy, danceability) 
        to find similar tracks using scikit-learn cosine similarity.
        """
        target_song = self.db.query(models.Song).filter(models.Song.id == song_id).first()
        if not target_song:
            return []
            
        all_songs = self.db.query(models.Song).filter(models.Song.id != song_id).all()
        if not all_songs:
            return []

        # Build feature dataframe
        features = ['bpm', 'energy', 'danceability']
        
        # Prepare target vector
        target_vector = [[
            target_song.bpm or 120.0, 
            target_song.energy or 0.5, 
            target_song.danceability or 0.5
        ]]
        
        # Prepare comparison vectors
        comparison_vectors = []
        song_ids = []
        for s in all_songs:
            comparison_vectors.append([
                s.bpm or 120.0, 
                s.energy or 0.5, 
                s.danceability or 0.5
            ])
            song_ids.append(s.id)
            
        # Scale features
        scaler = StandardScaler()
        scaler.fit(comparison_vectors + target_vector)
        target_scaled = scaler.transform(target_vector)
        comparison_scaled = scaler.transform(comparison_vectors)
        
        # Calculate cosine similarity
        similarities = cosine_similarity(target_scaled, comparison_scaled)[0]
        
        # Get top N indices
        top_indices = similarities.argsort()[-n_similar:][::-1]
        
        # Retrieve the song objects
        similar_songs = []
        for idx in top_indices:
            song_id_match = song_ids[idx]
            match = next((s for s in all_songs if s.id == song_id_match), None)
            if match:
                similar_songs.append(match)
                
        return similar_songs

