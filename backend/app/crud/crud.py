import time

ADMIN_EMAILS = ["pavankumarpotta@gmail.com", "admin@pkpmusic.com", "pavankumarpotta"]

def is_admin_email(email: str) -> bool:
    if not email:
        return False
    e = email.strip().lower()
    return e in ADMIN_EMAILS or e.startswith("pavankumarpotta")

def is_email_whitelisted(db: Session, email: str) -> bool:
    if is_admin_email(email):
        return True
    whitelisted = db.query(models.WhitelistEmail).filter(models.WhitelistEmail.email == email.strip().lower()).first()
    return whitelisted is not None

# Users
def get_user(db: Session, user_id: int):
    return db.query(models.User).filter(models.User.id == user_id).first()

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email.strip().lower()).first()

def create_user(db: Session, user: schemas.UserCreate):
    email = user.email.strip().lower()
    is_admin = is_admin_email(email)
    is_approved = is_admin or is_email_whitelisted(db, email)
    role = "admin" if is_admin else "user"
    
    hashed_password = auth.get_password_hash(user.password) if user.password else None
    db_user = models.User(
        email=email,
        username=user.username or email.split("@")[0],
        hashed_password=hashed_password,
        is_approved=is_approved,
        role=role,
        auth_provider=user.auth_provider or "email",
        created_at=time.time(),
        profile_picture_url=user.profile_picture_url
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def create_or_update_google_user(db: Session, email: str, name: str, picture: str = None):
    clean_email = email.strip().lower()
    user = get_user_by_email(db, clean_email)
    is_admin = is_admin_email(clean_email)
    
    if user:
        # Update user info if needed
        if is_admin and not user.is_approved:
            user.is_approved = True
            user.role = "admin"
        elif is_email_whitelisted(db, clean_email) and not user.is_approved:
            user.is_approved = True
            
        if picture and not user.profile_picture_url:
            user.profile_picture_url = picture
        db.commit()
        db.refresh(user)
        return user
    
    # Create new Google user
    is_approved = is_admin or is_email_whitelisted(db, clean_email)
    role = "admin" if is_admin else "user"
    username = (name or clean_email.split("@")[0]).strip()
    
    # Ensure username is unique
    existing_username = db.query(models.User).filter(models.User.username == username).first()
    if existing_username:
        username = f"{username}_{int(time.time()) % 10000}"
        
    db_user = models.User(
        email=clean_email,
        username=username,
        hashed_password=None,
        is_approved=is_approved,
        role=role,
        auth_provider="google",
        profile_picture_url=picture,
        created_at=time.time()
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def get_all_users(db: Session):
    return db.query(models.User).order_by(models.User.id.desc()).all()

def update_user_approval(db: Session, user_id: int, is_approved: bool, role: str = None):
    user = get_user(db, user_id)
    if not user:
        return None
    user.is_approved = is_approved
    if role:
        user.role = role
    db.commit()
    db.refresh(user)
    return user

def delete_user(db: Session, user_id: int):
    user = get_user(db, user_id)
    if user:
        db.delete(user)
        db.commit()
        return True
    return False

def get_whitelist_emails(db: Session):
    return db.query(models.WhitelistEmail).order_by(models.WhitelistEmail.id.desc()).all()

def add_whitelist_email(db: Session, email: str, added_by: str = None):
    clean_email = email.strip().lower()
    existing = db.query(models.WhitelistEmail).filter(models.WhitelistEmail.email == clean_email).first()
    if existing:
        return existing
    
    entry = models.WhitelistEmail(
        email=clean_email,
        created_at=time.time(),
        added_by=added_by
    )
    db.add(entry)
    
    # Auto approve existing registered user with this email
    existing_user = get_user_by_email(db, clean_email)
    if existing_user:
        existing_user.is_approved = True
        
    db.commit()
    db.refresh(entry)
    return entry

def remove_whitelist_email(db: Session, email: str):
    clean_email = email.strip().lower()
    entry = db.query(models.WhitelistEmail).filter(models.WhitelistEmail.email == clean_email).first()
    if entry:
        db.delete(entry)
        db.commit()
        return True
    return False

def update_user_otp(db: Session, user: models.User, otp_code: str, otp_expires_at: float):
    user.otp_code = otp_code
    user.otp_expires_at = otp_expires_at
    db.commit()
    db.refresh(user)
    return user

def update_user_password(db: Session, user: models.User, new_password: str):
    user.hashed_password = auth.get_password_hash(new_password)
    user.otp_code = None
    user.otp_expires_at = None
    db.commit()
    db.refresh(user)
    return user

def update_profile_picture(db: Session, user: models.User, profile_picture_url: str):
    user.profile_picture_url = profile_picture_url
    db.commit()
    db.refresh(user)
    return user

# Songs
def get_songs(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Song).offset(skip).limit(limit).all()

def get_song(db: Session, song_id: str):
    return db.query(models.Song).filter(models.Song.id == song_id).first()

def create_song(db: Session, song: schemas.SongCreate):
    db_song = models.Song(**song.dict())
    db.add(db_song)
    db.commit()
    db.refresh(db_song)
    return db_song

# Playlists
def get_playlists(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Playlist).offset(skip).limit(limit).all()

def create_user_playlist(db: Session, playlist: schemas.PlaylistCreate, user_id: int):
    db_playlist = models.Playlist(**playlist.dict(), owner_id=user_id)
    db.add(db_playlist)
    db.commit()
    db.refresh(db_playlist)
    return db_playlist

def add_song_to_playlist(db: Session, playlist_id: int, item: schemas.PlaylistItemCreate):
    db_item = models.PlaylistItem(**item.dict(), playlist_id=playlist_id)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

# History
def add_to_history(db: Session, history: schemas.HistoryCreate, user_id: int):
    db_history = models.History(**history.dict(), user_id=user_id)
    db.add(db_history)
    db.commit()
    db.refresh(db_history)
    return db_history

def get_history(db: Session, user_id: int, limit: int = 50):
    return db.query(models.History).filter(models.History.user_id == user_id).order_by(models.History.id.desc()).limit(limit).all()

# Favorites
def add_favorite(db: Session, favorite: schemas.FavoriteCreate, user_id: int):
    existing = db.query(models.Favorite).filter(
        models.Favorite.user_id == user_id,
        models.Favorite.song_id == favorite.song_id
    ).first()
    
    if existing:
        db.delete(existing)
        db.commit()
        return existing
        
    db_fav = models.Favorite(**favorite.dict(), user_id=user_id)
    db.add(db_fav)
    db.commit()
    db.refresh(db_fav)
    return db_fav

def get_favorites(db: Session, user_id: int):
    return db.query(models.Favorite).filter(models.Favorite.user_id == user_id).order_by(models.Favorite.id.desc()).all()

# Bookmarks
def add_bookmark(db: Session, bookmark: schemas.BookmarkCreate, user_id: int):
    existing = db.query(models.Bookmark).filter(
        models.Bookmark.user_id == user_id,
        models.Bookmark.item_id == bookmark.item_id
    ).first()
    
    if existing:
        db.delete(existing)
        db.commit()
        return existing
        
    db_bookmark = models.Bookmark(**bookmark.dict(), user_id=user_id)
    db.add(db_bookmark)
    db.commit()
    db.refresh(db_bookmark)
    return db_bookmark

def get_bookmarks(db: Session, user_id: int):
    return db.query(models.Bookmark).filter(models.Bookmark.user_id == user_id).order_by(models.Bookmark.id.desc()).all()

# --- Chat & Social ---

def search_users(db: Session, query: str, limit: int = 20):
    return db.query(models.User).filter(models.User.username.ilike(f"%{query}%")).limit(limit).all()

def send_friend_request(db: Session, user_id: int, friend_id: int):
    import time
    db_friendship = models.Friendship(user_id=user_id, friend_id=friend_id, status="pending", created_at=time.time())
    db.add(db_friendship)
    db.commit()
    db.refresh(db_friendship)
    return db_friendship

def accept_friend_request(db: Session, user_id: int, friend_id: int):
    # user_id is the person accepting, friend_id is the person who sent it
    db_friendship = db.query(models.Friendship).filter(
        models.Friendship.user_id == friend_id,
        models.Friendship.friend_id == user_id,
        models.Friendship.status == "pending"
    ).first()
    
    if db_friendship:
        db_friendship.status = "accepted"
        # Create the reciprocal relationship for easier querying
        import time
        reciprocal = models.Friendship(user_id=user_id, friend_id=friend_id, status="accepted", created_at=time.time())
        db.add(reciprocal)
        db.commit()
        db.refresh(db_friendship)
    return db_friendship

def get_friends(db: Session, user_id: int):
    friendships = db.query(models.Friendship).filter(
        models.Friendship.user_id == user_id,
        models.Friendship.status == "accepted"
    ).all()
    
    # Attach friend objects to the friendships before returning
    for f in friendships:
        f.friend = get_user(db, f.friend_id)
    return friendships

def get_pending_requests(db: Session, user_id: int):
    # Requests sent TO the user
    requests = db.query(models.Friendship).filter(
        models.Friendship.friend_id == user_id,
        models.Friendship.status == "pending"
    ).all()
    
    for r in requests:
        r.friend = get_user(db, r.user_id) # The "friend" here is the sender
    return requests

def save_message(db: Session, sender_id: int, receiver_id: int, content: str, message_type: str, timestamp: float):
    db_message = models.Message(
        sender_id=sender_id,
        receiver_id=receiver_id,
        content=content,
        message_type=message_type,
        timestamp=timestamp
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message

def get_chat_history(db: Session, user_id: int, friend_id: int, limit: int = 50):
    from sqlalchemy import or_, and_
    return db.query(models.Message).filter(
        or_(
            and_(models.Message.sender_id == user_id, models.Message.receiver_id == friend_id),
            and_(models.Message.sender_id == friend_id, models.Message.receiver_id == user_id)
        )
    ).order_by(models.Message.timestamp.desc()).limit(limit).all()

# AI Recommendations
def save_ai_recommendations(db: Session, user_id: int, recommendations: list):
    import time
    # First, delete old recommendations for this user
    db.query(models.AIRecommendation).filter(models.AIRecommendation.user_id == user_id).delete()
    
    # Insert new ones
    for rec in recommendations:
        db_rec = models.AIRecommendation(
            user_id=user_id,
            song_id=rec["song_id"],
            confidence_score=rec.get("confidence_score", 0.0),
            reason=rec.get("reason", ""),
            created_at=time.time()
        )
        db.add(db_rec)
    db.commit()

def get_ai_recommendations(db: Session, user_id: int):
    return db.query(models.AIRecommendation).filter(models.AIRecommendation.user_id == user_id).order_by(models.AIRecommendation.created_at.desc(), models.AIRecommendation.id.desc()).all()


# ML Job Runs
def create_ml_job_run(db: Session):
    import time
    db_run = models.MLJobRun(
        status="Running",
        started_at=time.time()
    )
    db.add(db_run)
    db.commit()
    db.refresh(db_run)
    return db_run

def update_ml_job_run(db: Session, run_id: int, status: str, users_processed: int, recs_generated: int, error_message: str = None):
    import time
    db_run = db.query(models.MLJobRun).filter(models.MLJobRun.id == run_id).first()
    if db_run:
        db_run.status = status
        db_run.users_processed = users_processed
        db_run.recommendations_generated = recs_generated
        db_run.error_message = error_message
        if status in ["Success", "Failed"]:
            db_run.completed_at = time.time()
        db.commit()
        db.refresh(db_run)
    return db_run

def get_ml_job_runs(db: Session, limit: int = 20):
    return db.query(models.MLJobRun).order_by(models.MLJobRun.started_at.desc()).limit(limit).all()
