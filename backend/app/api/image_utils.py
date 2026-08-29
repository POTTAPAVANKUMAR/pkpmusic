import re

def upscale_thumbnail(url: str) -> str:
    if not url:
        return url
    
    # Google User Content URLs (replace with optimal high-res 544x544 or 800x800 square cover art)
    if "ggpht.com" in url or "googleusercontent.com" in url:
        return re.sub(r'=w\d+-h\d+[^\s]*', '=w544-h544-l90-rj', url)
    
    # YouTube standard thumbnails (use reliable hqdefault.jpg which is guaranteed 100% available without 404)
    if "i.ytimg.com" in url or "img.youtube.com" in url:
        # Upgrade lower-res thumbnails to hqdefault
        for quality in ['sddefault.jpg', 'mqdefault.jpg', 'default.jpg']:
            if quality in url:
                return url.replace(quality, 'hqdefault.jpg')
                
    return url

def extract_thumbnail_url(item: dict) -> str:
    """Safely extract and upscale thumbnail url from any ytmusic dictionary."""
    if not item or not isinstance(item, dict):
        return None
    thumbs = item.get('thumbnails') or item.get('thumbnail')
    if thumbs and isinstance(thumbs, list) and len(thumbs) > 0:
        for t in reversed(thumbs):
            if isinstance(t, dict) and t.get('url'):
                return upscale_thumbnail(t['url'])
    elif isinstance(thumbs, str):
        return upscale_thumbnail(thumbs)
    return None
