reckonMe
========

Live inertial navigation, proximity detection and collaborative localisation on a mobile device (iOS).

![Preview](iTunesConnectAssets/reckonMe.gif?raw=true "Animated Preview")

Video: [http://vimeo.com/reckonme/reckonme-demo](http://vimeo.com/reckonme/reckonme-demo)


Feature Overview (initial release)
----------------------------------

- Inertial navigation:
	
	-	Phone orientation: derived from the *CMAttitudeReferenceFrameXArbitraryZVertical* reference frame, i.e. accelerometer & gyroscope only. Pros: immune to the indoor magnetometer distortions. Cons: long-term yaw calibration required due to the gyroscope drift.

	-	Step detection: computed from the peaks in the filtered Z-axis of the gravity vector in the device's reference frame. Pros: we are able to detect individual steps (the classic method, searching for the foot impact, misses every second step), peaks in the Z-axis gravity vector are equally well pronounced for slower walking speeds and pinpoint the maximum forward- and backward swing of the phone occurring in each step.

	-	Axis of movement and step length: we exploit the fact that the thigh (and hence a phone in the trouser pocket) performs a swing in the axis of the motion and moreover, the rotation axis is approximately orthogonal to the motion axis. For each step we compute the rotation axis and the rotation angle of the full swing 
motion of the phone.  Rotation axis gives us the approximation of the (orthogonal) axis of movement, rotation angle is used to estimate the length of the step.
analyses the swing phase of each step in one chunk in order to get an estimate on the step length
and the walking direction.

	-	Forward direction: determined by the maxima of the norm in the user's acceleration.

- Proximity detection (with an accuracy of 3m):

	-	First, Bluetooth paring is used to confirm that the two devices are broadly in the same space i.e., are `eligible' for the close-proximity test.

	-	Next, the one device starts emitting repeating sound patterns in a predefined inaudible narrow spectrum and the other tries to detect them.

- Collaborative localisation:

	-	When two devices detect being close to each other, the application may decide to automatically exchange and update their absolute location estimates. The premise: this improvement not only affects the two involved users, but also all the others they meet and collaborate with in the future. 

	-	The app can also run in a *Stationary Beacon Mode*, with fixed location. It serves then as a `beacon' and corrects the location estimates of other devices. 


The goal
--------

Build an indoor navigation application, which combines the existing fingerprinting-based localisation solutions with inertial navigation from the pocket, proximity detection and collaborative localisation approach. 

[@benFnord](https://twitter.com/benFnord), [@kamil_k](https://twitter.com/kamil_k)
