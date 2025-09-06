# Small bash scripts for personal use 

The small scripts were designed to process videos according to the specified requirements, a few years ago.

They also served as a way to learn the basics of Bash scripting.  
They are without any graphical user interface.

## Video(AVI) Stabilization Script

This is a script to stabilize videos. It uses ffmpeg to improve shaky footage.

### Requirements

You must have these programs installed:

- ffmpeg: For video processing.
- ImageMagick: For image manipulation (used during stabilization).
- mediainfo: To check video details.
- realpath: To handle file paths.

### Installation

On Ubuntu/Debian:

```bash
sudo apt install ffmpeg imagemagick mediainfo realpath
```

### How to Use

Make sure your video file is in a folder without special characters or spaces in its name.

Run the script:
```bash
bash stabilizeAvi.sh
```

### Notes

If you see "unable to read exif data from opened file", don't worry — it's normal.

## Convert the video to a gif and back to a video to achieve the gif effect.

### Requirements

You need to have these programs installed:

- ffmpeg: For video processing.
- ImageMagick: For image manipulation (used during stabilization).
- mediainfo: To check video details.
- realpath: To handle file paths.

### Installation

On Ubuntu/Debian:

```bash
sudo apt install ffmpeg imagemagick mediainfo realpath
```

### How to Use

Make sure your video file is in a folder without special characters or spaces in its name.

Run the script:
```bash
bash video_to_gif_to_video.sh
```
