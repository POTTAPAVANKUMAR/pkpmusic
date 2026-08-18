import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import linear_kernel
from app.db.database import SessionLocal
from app.db import models
from app.crud import crud
import logging

logger = logging.getLogger(__name__)

def run_ml_pipeline():
    logger.info("Starting Nightly ML Pipeline...")
    
    db = SessionLocal()
    try:
        # 1. Fetch all songs
        songs = db.query(models.Song).all()
        if not songs:
            logger.info("No songs found in DB. Exiting ML pipeline.")
            return

        # 2. Build DataFrame
        song_data = []
        for s in songs:
            song_data.append({
                'song_id': s.id,
                'title': s.title or "",
                'artist': s.artist or "",
                'text': f"{s.title} {s.artist} {s.album}"
            })
        
        df = pd.DataFrame(song_data)
        
        # 3. Compute TF-IDF
        tfidf = TfidfVectorizer(stop_words='english')
        tfidf_matrix = tfidf.fit_transform(df['text'])
        
        # 4. Compute Cosine Similarity
        cosine_sim = linear_kernel(tfidf_matrix, tfidf_matrix)
        
        # Helper to get indices
        indices = pd.Series(df.index, index=df['song_id']).drop_duplicates()
        
        # 5. Get all users
        users = db.query(models.User).all()
        for user in users:
            # Get user history
            history = db.query(models.History).filter(models.History.user_id == user.id).order_by(models.History.id.desc()).limit(100).all()
            if not history:
                continue
                
            played_song_ids = [h.song_id for h in history if h.song_id in indices]
            if not played_song_ids:
                continue
                
            # Compute a user profile score (aggregate similarity of all songs they played)
            # We take the top 5 most recently played unique songs
            unique_recent = []
            for sid in played_song_ids:
                if sid not in unique_recent:
                    unique_recent.append(sid)
                if len(unique_recent) >= 5:
                    break
                    
            user_scores = pd.Series(0.0, index=df.index)
            for sid in unique_recent:
                idx = indices[sid]
                sim_scores = pd.Series(cosine_sim[idx])
                user_scores = user_scores + sim_scores
                
            # Average out
            user_scores = user_scores / len(unique_recent)
            
            # Sort by score
            top_indices = user_scores.sort_values(ascending=False).index
            
            # Filter out songs already played
            recommendations = []
            for idx in top_indices:
                rec_song_id = df.iloc[idx]['song_id']
                if rec_song_id not in played_song_ids:
                    score = float(user_scores[idx])
                    if score > 0.1: # Threshold
                        recommendations.append({
                            "song_id": rec_song_id,
                            "confidence_score": score,
                            "reason": f"Based on your recent listens to {df.iloc[indices[unique_recent[0]]]['artist']}"
                        })
                if len(recommendations) >= 20:
                    break
                    
            if recommendations:
                crud.save_ai_recommendations(db, user.id, recommendations)
                logger.info(f"Generated {len(recommendations)} recommendations for user {user.id}")
                
    except Exception as e:
        logger.error(f"Error in ML pipeline: {e}")
    finally:
        db.close()
        logger.info("Nightly ML Pipeline finished.")
