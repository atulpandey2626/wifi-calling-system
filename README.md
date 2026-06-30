Wifi Call - LAN WebRTC Voice Calling App
A voice calling Android app that works over local WiFi without needing internet access.
## Why I built this
Apps like WhatsApp or Google Meet need internet because they route calls through cloud servers. If two phones are on the same WiFi but there's no internet, calling doesn't work. This app fixes that by letting two devices find each other on the same network and call directly using WebRTC (the same tech behind Google Meet).
## Tech used
- Flutter / Dart- WebRTC (flutter_webrtc package) for the actual audio call- UDP sockets for finding nearby devices on the network- TCP sockets for exchanging connection info before the call starts- permission_handler for mic/network permissions
## How it works
1. Every device broadcasts a UDP signal every 2 seconds so other devices on the same WiFi can find it
2. Once a device is selected, a TCP connection is used to exchange WebRTC connection details (SDP/ICE candidates)
3. WebRTC then handles the actual audio call - echo cancellation, noise suppression, etc happen automatically
## Problems I ran into while building this
- Large WebRTC data getting split into pieces by routers (TCP fragmentation) - fixed by buffering the data until a complete message arrives- Connection data sometimes arriving before the call was fully accepted - fixed by queuing it temporarily- Too many network connections opening at once causing crashes - fixed by adding a small delay between connection attempts
## Running it
1. `flutter pub get`
2. Connect two Android phones to the same WiFi
3. Allow microphone and network permissions4. `flutter run --release`
Detailed write-up in the PDF in this repo.
Built by Atul Pandey
