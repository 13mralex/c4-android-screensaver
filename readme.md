# C4 Android Screensaver
## What is it?
 - This driver replicates official C4 Navigator screensavers by displaying a combination of:
		 - Time
		 - Date
		 - Weather
		 - Current Media
## How it works:
 - Find an applicable app from the Play Store
		- [This](https://m.apkpure.com/web-screensaver/se.andreasottesen.WebScreensaver) is the one I use
 - The URL is formatted simply as `ip:port/roomId`
		- Default port is 8089
 - That's it! Whenever the room is on, the screensaver will automatically display the current media
## Notes
 - Weather is determined by the Project coordinates in Composer. Make sure this is set to see the weather!
## Roadmap
 - [ ] Change port number in Composer
 - [ ] Configure & personalize which widgets are showing
		 - Right now this only shows date, time, weather, and media with no option to change
 - [ ] Make this a fully inclusive Android app
## Known Issues:
 - When no media is defined, but the room is active, it will switch to media mode with blank fields.
		 - Need to display device name/icon when this happens
