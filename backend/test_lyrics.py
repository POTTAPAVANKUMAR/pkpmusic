import sys
from ytmusicapi import YTMusic

yt = YTMusic()
video_id = "dQw4w9WgXcQ" # Rick Astley
watch_playlist = yt.get_watch_playlist(videoId=video_id)
lyrics_id = watch_playlist.get('lyrics')
print("Lyrics ID:", lyrics_id)
if lyrics_id:
    print(yt.get_lyrics(lyrics_id))
