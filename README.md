# Forced subtitle Extractor

This script is based on [AmineI/SubtitleExtractor-Docker](https://github.com/AmineI/SubtitleExtractor-Docker)

It extracts subtitles, named as forced(or similar) and places them in the folder with videofile. It will help you if you have issues with plex which wants subtitles to have forced flag.

##### How to run

docker run -d --restart unless-stopped -v /volume1/Media/Movies:/data/Movies -v /volume1/Media/TV\ Show:/data/TV\ Show -v /volume1/Docker/forced-subtitles:/db -p 19191:3000 --name extract-forced-subtitles fuzz1986/extract-forced-subtitles

### Notes, credits & Licences
Credits & thanks to the ffmpeg developer team.

The code in the repo is subject to the unlicence, and the Docker Image, containing a compiled ffmpeg static binary, is under GPL.
