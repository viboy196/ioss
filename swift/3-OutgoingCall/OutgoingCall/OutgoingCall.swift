//
//  OutgoingCall.swift
//  OutgoingCall tutorial
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import linphonesw

class OutgoingCallTutorialContext : ObservableObject
{
	var mCore: Core!
	@Published var coreVersion: String = Core.getVersion
	
	var mAccount: Account?
	var mCoreDelegate : CoreDelegate!
	@Published var username : String = "user"
	@Published var passwd : String = "pwd"
	@Published var domain : String = "sip.example.org"
	@Published var loggedIn: Bool = false
	@Published var transportType : String = "TLS"
	
	// Outgoing call related variables
	@Published var callMsg : String = ""
	@Published var isCallRunning : Bool = false
	@Published var isVideoEnabled : Bool = false
	@Published var canChangeCamera : Bool = false
	@Published var remoteAddress : String = "sip:arguillq@sip.linphone.org"
	
	init()
	{
		LoggingService.Instance.logLevel = LogLevel.Debug
		
		try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
		// Here we enable the video capture & display at Core level
		// It doesn't mean calls will be made with video automatically,
		// But it allows to use it later
		mCore.videoCaptureEnabled = true
		mCore.videoDisplayEnabled = true
		
		// When enabling the video, the remote will either automatically answer the update request
		// or it will ask it's user depending on it's policy.
		// Here we have configured the policy to always automatically accept video requests
		mCore.videoActivationPolicy!.automaticallyAccept = true
		// If you don't want to automatically accept,
		// you'll have to use a code similar to the one in toggleVideo to answer a received request
		
		
		// If the following property is enabled, it will automatically configure created call params with video enabled
		//core.videoActivationPolicy.automaticallyInitiate = true
		
		try? mCore.start()
		
		mCoreDelegate = CoreDelegateStub( onCallStateChanged: { (core: Core, call: Call, state: Call.State, message: String) in
			// This function will be called each time a call state changes,
			// which includes new incoming/outgoing calls
			self.callMsg = message
			
			if (state == .OutgoingInit) {
				// First state an outgoing call will go through
			} else if (state == .OutgoingProgress) {
				// Right after outgoing init
			} else if (state == .OutgoingRinging) {
				// This state will be reached upon reception of the 180 RINGING
			} else if (state == .Connected) {
				// When the 200 OK has been received
			} else if (state == .StreamsRunning) {
				// This state indicates the call is active.
				// You may reach this state multiple times, for example after a pause/resume
				// or after the ICE negotiation completes
				// Wait for the call to be connected before allowing a call update
				self.isCallRunning = true
				
				// Only enable toggle camera button if there is more than 1 camera
				// We check if core.videoDevicesList.size > 2 because of the fake camera with static image created by our SDK (see below)
				self.canChangeCamera = core.videoDevicesList.count > 2
			} else if (state == .Paused) {
				// When you put a call in pause, it will became Paused
				self.canChangeCamera = false
			} else if (state == .PausedByRemote) {
				// When the remote end of the call pauses it, it will be PausedByRemote
			} else if (state == .Updating) {
				// When we request a call update, for example when toggling video
			} else if (state == .UpdatedByRemote) {
				// When the remote requests a call update
			} else if (state == .Released) {
				// Call state will be released shortly after the End state
				self.isCallRunning = false
				self.canChangeCamera = false
			} else if (state == .Error) {
				
			}
		}, onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
			NSLog("New registration state is \(state) for user id \( String(describing: account.params?.identityAddress?.asString()))\n")
			if (state == .Ok) {
				self.loggedIn = true
			} else if (state == .Cleared) {
				self.loggedIn = false
			}
		})
		mCore.addDelegate(delegate: mCoreDelegate)
	}
	
	func login() {
		
		do {
			var transport : TransportType
			if (transportType == "TLS") { transport = TransportType.Tls }
			else if (transportType == "TCP") { transport = TransportType.Tcp }
			else  { transport = TransportType.Udp }
			
			let authInfo = try Factory.Instance.createAuthInfo(username: username, userid: "", passwd: passwd, ha1: "", realm: "", domain: domain)
			let accountParams = try mCore.createAccountParams()
			let identity = try Factory.Instance.createAddress(addr: String("sip:" + username + "@" + domain))
			try! accountParams.setIdentityaddress(newValue: identity)
			let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
			try address.setTransport(newValue: transport)
			try accountParams.setServeraddress(newValue: address)
			accountParams.registerEnabled = true
			mAccount = try mCore.createAccount(params: accountParams)
			mCore.addAuthInfo(info: authInfo)
			try mCore.addAccount(account: mAccount!)
			mCore.defaultAccount = mAccount
			
		} catch { NSLog(error.localizedDescription) }
	}
	
	func unregister()
	{
		if let account = mCore.defaultAccount {
			let params = account.params
			let clonedParams = params?.clone()
			clonedParams?.registerEnabled = false
			account.params = clonedParams
		}
	}
	func delete() {
		if let account = mCore.defaultAccount {
			mCore.removeAccount(account: account)
			mCore.clearAccounts()
			mCore.clearAllAuthInfo()
		}
	}
	
	
	func outgoingCall() {
		do {
			// As for everything we need to get the SIP URI of the remote and convert it to an Address
			let remoteAddress = try Factory.Instance.createAddress(addr: remoteAddress)
			
			// We also need a CallParams object
			// Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
			let params = try mCore.createCallParams(call: nil)
			
			// We can now configure it
			// Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
			params.mediaEncryption = MediaEncryption.None
			// If we wanted to start the call with video directly
			//params.videoEnabled = true
			
			// Finally we start the call
			let _ = mCore.inviteAddressWithParams(addr: remoteAddress, params: params)
			// Call process can be followed in onCallStateChanged callback from core listener
		} catch { NSLog(error.localizedDescription) }
		
	}
	
	func terminateCall() {
		do {
			if (mCore.callsNb == 0) { return }
			
			// If the call state isn't paused, we can get it using core.currentCall
			let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
			
			// Terminating a call is quite simple
			if let call = coreCall {
				try call.terminate()
			}
		} catch { NSLog(error.localizedDescription) }
	}
	
	func toggleVideo() {
		do {
			if (mCore.callsNb == 0) { return }
			let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
			// We will need the CAMERA permission for video call
			
			if let call = coreCall {
				// To update the call, we need to create a new call params, from the call object this time
				let params = try mCore.createCallParams(call: call)
				// Here we toggle the video state (disable it if enabled, enable it if disabled)
				// Note that we are using currentParams and not params or remoteParams
				// params is the object you configured when the call was started
				// remote params is the same but for the remote
				// current params is the real params of the call, resulting of the mix of local & remote params
				params.videoEnabled = !(call.currentParams!.videoEnabled)
				isVideoEnabled = params.videoEnabled
				// Finally we request the call update
				try call.update(params: params)
				// Note that when toggling off the video, TextureViews will keep showing the latest frame displayed
			}
		} catch { NSLog(error.localizedDescription) }
	}
	
	func toggleCamera() {
		do {
			// Currently used camera
			let currentDevice = mCore.videoDevice
			
			// Let's iterate over all camera available and choose another one
			for camera in mCore.videoDevicesList {
				// All devices will have a "Static picture" fake camera, and we don't want to use it
				if (camera != currentDevice && camera != "StaticImage: Static picture") {
					try mCore.setVideodevice(newValue: camera)
					break
				}
			}
		} catch { NSLog(error.localizedDescription) }
	}
	
	func pauseOrResume() {
		do {
			if (mCore.callsNb == 0) { return }
			let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
			
			if let call = coreCall {
				if (call.state != Call.State.Paused && call.state != Call.State.Pausing) {
					// If our call isn't paused, let's pause it
					try call.pause()
				} else if (call.state != Call.State.Resuming) {
					// Otherwise let's resume it
					try call.resume()
				}
			}
		} catch { NSLog(error.localizedDescription) }
	}
}
