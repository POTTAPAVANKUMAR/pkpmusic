from ytmusicapi import YTMusic
import json

yt = YTMusic()

print("Fetching Home...")
try:
    # Get home page recommendations (requires auth for personalized, but might return generic without auth)
    home = yt.get_home(limit=3)
    print("HOME SECTIONS:")
    for section in home:
        print(f"- {section.get('title')}: {len(section.get('contents', []))} items")
except Exception as e:
    print(f"Home error: {e}")

print("\nFetching Explore/Charts...")
try:
    charts = yt.get_charts(country='US')
    print("CHARTS:")
    for k, v in charts.items():
        if isinstance(v, dict) and 'items' in v:
            print(f"- {k}: {len(v['items'])} items")
        else:
            print(f"- {k}")
except Exception as e:
    print(f"Charts error: {e}")

print("\nFetching Moods/Genres...")
try:
    moods = yt.get_mood_categories()
    print("MOODS:")
    for k, v in moods.items():
        print(f"- {k}: {len(v)} categories")
except Exception as e:
    print(f"Moods error: {e}")
