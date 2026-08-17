import re

def upscale_thumbnail(url: str) -> str:
    if not url:
        return url
    
    # Google User Content URLs (replace =w120-h120... with =w1080-h1080...)
    if "ggpht.com" in url or "googleusercontent.com" in url:
        # Match the resolution part and replace it
        return re.sub(r'=w\d+-h\d+', '=w1080-h1080', url)
    
    # YouTube standard thumbnails (upgrade to maxresdefault)
    if "i.ytimg.com" in url or "img.youtube.com" in url:
        for quality in ['hqdefault.jpg', 'sddefault.jpg', 'mqdefault.jpg', 'default.jpg']:
            if quality in url:
                return url.replace(quality, 'maxresdefault.jpg')
                
    return url
