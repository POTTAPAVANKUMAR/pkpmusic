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
    job_run = crud.create_ml_job_run(db)
    users_processed = 0
    recs_generated = 0
    
    try:
        # 1. Fetch all songs
        songs = db.query(models.Song).all()
        if not songs or len(songs) < 2:
            logger.info("Not enough songs found in DB (< 2). Exiting ML pipeline.")
            crud.update_ml_job_run(db, job_run.id, "Success", users_processed, recs_generated)
            return

        # 2. Build DataFrame
        song_data = []
        for s in songs:
            text_features = f"{s.title or ''} {s.artist or ''} {s.album or ''}".strip()
            if not text_features:
                text_features = "music track song"
            song_data.append({
                'song_id': s.id,
                'title': s.title or "Unknown Title",
                'artist': s.artist or "Unknown Artist",
                'text': text_features
            })
        
        df = pd.DataFrame(song_data)
        
        # 3. Compute TF-IDF safely
        try:
            tfidf = TfidfVectorizer(stop_words='english', token_pattern=r'(?u)\b\w+\b')
            tfidf_matrix = tfidf.fit_transform(df['text'])
        except Exception:
            tfidf = TfidfVectorizer(token_pattern=r'(?u)\b\w+\b')
            tfidf_matrix = tfidf.fit_transform(df['text'])
        
        # 4. Compute Cosine Similarity
        cosine_sim = linear_kernel(tfidf_matrix, tfidf_matrix)
        
        # Fast song_id -> index dictionary
        song_to_idx = {sid: i for i, sid in enumerate(df['song_id'])}
        
        # 5. Get all users
        users = db.query(models.User).all()
        for user in users:
            users_processed += 1
            # Get user history
            history = db.query(models.History).filter(models.History.user_id == user.id).order_by(models.History.id.desc()).limit(100).all()
            if not history:
                continue
                
            played_song_ids = [h.song_id for h in history if h.song_id in song_to_idx]
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
                idx = song_to_idx[sid]
                sim_scores = pd.Series(cosine_sim[idx])
                user_scores = user_scores + sim_scores
                
            # Average out
            user_scores = user_scores / len(unique_recent)
            
            # Sort by score
            top_indices = user_scores.sort_values(ascending=False).index
            
            # Filter out songs already played
            recommendations = []
            primary_artist = df.iloc[song_to_idx[unique_recent[0]]]['artist'] if unique_recent else "your favorites"
            
            for idx in top_indices:
                rec_song_id = df.iloc[idx]['song_id']
                if rec_song_id not in played_song_ids:
                    score = float(user_scores[idx])
                    if score > 0.05: # Threshold
                        recommendations.append({
                            "song_id": rec_song_id,
                            "confidence_score": score,
                            "reason": f"Based on your recent listens to {primary_artist}"
                        })
                if len(recommendations) >= 20:
                    break
                    
            if recommendations:
                crud.save_ai_recommendations(db, user.id, recommendations)
                recs_generated += len(recommendations)
                logger.info(f"Generated {len(recommendations)} recommendations for user {user.id}")
                
            crud.update_ml_job_run(db, job_run.id, "Running", users_processed, recs_generated)
                
        crud.update_ml_job_run(db, job_run.id, "Success", users_processed, recs_generated)
        
        # Invalidate dashboard cache so the latest recommendations appear immediately
        try:
            from app.api.routers.dashboard import clear_dashboard_cache
            clear_dashboard_cache()
        except Exception as e:
            logger.error(f"Error clearing dashboard cache: {e}")
    except Exception as e:
        logger.error(f"Error in ML pipeline: {e}")
        crud.update_ml_job_run(db, job_run.id, "Failed", users_processed, recs_generated, str(e))
    finally:
        db.close()
        logger.info("Nightly ML Pipeline finished.")

