#reckonMe [![Download on the App Store](https://linkmaker.itunes.apple.com/htmlResources/assets/en_us/images/web/linkmaker/badge_appstore-lrg.svg)](https://itunes.apple.com/us/app/reckonme/id951420572?mt=8)

Live inertial navigation and collaborative localisation on an iPhone.

![Preview](iTunesConnectAssets/reckonMe.gif?raw=true "Animated Preview")
![Preview](iTunesConnectAssets/4,7inch/4smaller.png?raw=true "Settings Screen")

##How-to

* Un-mute your iPhone so you can hear what's going on.
* Put the red pin onto your starting position on the map. It is automatically moved to the current GPS position until you drag it.
* Tap "Start Dead-Reckoning".
* Put the unlocked iPhone into your pocket.
* Walk around. reckonMe tries to detect your steps and their direction.
* Should you notice a drift in the path you walked, you can manually adjust its heading as well as the position estimate itself.
* Meet other reckonMe users and automagically exchange your estimates.


##Overview

The approach is rather simple: Given a starting position (fix), one's current position can be calculated by advancing that position based on one's course and speed, i.e. the number of steps walked. This process is called dead-reckoning (from correct "ded" for deduced reckoning, DR) and has been used in marine navigation for centuries.

Once started, reckonMe evaluates your iPhone's gyroscope and accelerometer data in order to detect your steps and their direction. It does not rely on external data, such as GPS or any other infrastructure. Therefore, it is ideally suited for indoor positioning, where GPS is typically unavailable.

However, DR is far from perfect. Over time, the errors in the heading and speed estimates accumulate to ever-greater values. This is where collaboration comes into play: The error in an individual location estimate can be significantly reduced if these estimates are shared with others and combined.

While reckonMe is running, its current position estimate is constantly broadcasted using Bluetooth Low-Energy (BLE) to be picked up by other peers. Once a peer is close enough, its position estimate is incorporated into one's own estimate. Even though some individuals may be worse of after an exchange, the average systemic error shrinks as a location "awareness" emerges.


##Inertial navigation: Details
	
-	Phone orientation: derived from the *CMAttitudeReferenceFrameXArbitraryZVertical* reference frame, i.e. accelerometer & gyroscope only. Pros: immune to the indoor magnetometer distortions. Cons: long-term yaw calibration required due to the gyroscope drift.

-	Step detection: computed from the peaks in the filtered Z-axis of the gravity vector in the device's reference frame. -	Pros: we are able to detect individual steps (the classic method, searching for the foot impact, misses every second step), peaks in the Z-axis gravity vector are equally well pronounced for slower walking speeds and pinpoint the maximum forward- and backward swing of the phone occurring in each step.

-	Axis of movement and step length: we exploit the fact that the thigh (and hence a phone in the trouser pocket) performs a swing in the axis of the motion and moreover, the rotation axis is approximately orthogonal to the motion axis. For each step we compute the rotation axis and the rotation angle of the full swing 
motion of the phone.  Rotation axis gives us the approximation of the (orthogonal) axis of movement, rotation angle is used to estimate the length of the step.
We analyse the swing phase of each step in one chunk in order to get an estimate on the step length
and the walking direction.

-	Forward direction: determined by the maxima of the norm in the user's acceleration.

##Versions

Over time, several versions with slightly different features have been developed:

- [Version 1.2.3](https://github.com/reckonMe/reckonMe/releases/tag/thesisBen) for iOS 6, extensively evaluated in [Ben's master's thesis](Assets/bensThesis.pdf?raw=true) (German 'Diplomarbeit'), whose features are:
	 
	 - Collaborative localisation:
	 
		-	When two devices detect being close to each other, they automatically exchange and update their location estimates. The premise: this improvement not only affects the two involved users, but also all the others they meet and collaborate with in the future. 

		-	The app can also run in a *Stationary Beacon Mode*, with fixed location. It serves then as a `beacon' and corrects the location estimates of other devices.
		
		-	GameKit's `GKSession` is used for establishing the peer-to-peer Bluetooth connections. Due to the lack of an API for the signal strength (RSSI), sound is used for detecting proximity. 
		
	- Sound-based proximity detection (with an accuracy of 3m, see [conference paper](http://doi.acm.org/10.1145/ 2389148.2389152)):

		-	First, Bluetooth pairing is used to confirm that the two devices are broadly in the same space, i.e. are 'eligible' for the close-proximity test.

		-	Next, one device starts emitting repeating sound patterns in the inaudible 18 kHz spectrum and the other tries to detect them. Once detected, an exchange is initiated.

	- [Watch a demo on vimeo](http://vimeo.com/reckonme/reckonme-demo)
	
- [Version 2.x](https://github.com/reckonMe/reckonMe/tree/ble_p2p) (the current default **branch ble_p2p**, also current [App Store](https://itunes.apple.com/us/app/reckonme/id951420572?mt=8) version) for iOS 8, which is a descendant of 1.2 with several changes:

	- UI changes to accommodate the new, "flat" design
	
	- Collaborative localisation:
	
		- The now deprecated `GKSession` has been dropped in favor of a connectionless Bluetooth Low Energy approach using CoreBluetooth's `CBCentralManager` and `CBPeripheralManager`. Instead of establishing a connection, each device is simultaneously broadcasting its position and scanning for other devices. The position is encoded in a Base64 string used as the device's name.
		
		- Since the signal strength is now accessible, it is used as a proxy for proximity and the sound-based approach has been dropped. As a result, a mutual exchange is not guaranteed to happen, as the two devices may have different RSSI measurements and no further information is exchanged due to the lack of a connection.
		
	- Furthermore, the recording of sessions has been dropped.
	
	- [Watch the App Preview](iTunesConnectAssets/reckonMeAppPreview.mp4?raw=true "App Preview Video")
		
- The [master branch](https://github.com/reckonMe/reckonMe/tree/master) is also a descendant of version 1.2. It also uses Bluetooth Low Energy for proximity detection, but instead of individual exchanges, it constantly pushes the collected data to a common CouchDB backend for further processing.

===
[@benFnord](https://twitter.com/benFnord), [@kamil_k](https://twitter.com/kamil_k)
