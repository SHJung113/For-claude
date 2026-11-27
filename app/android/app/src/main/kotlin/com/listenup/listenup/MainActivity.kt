package com.listenup.listenup

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity shares the Flutter engine with the background audio
// service, so playback continues with the screen off.
class MainActivity : AudioServiceActivity()
