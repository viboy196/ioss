//
//  IncomingCall.swift
//  IncomingCall tutorial
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import linphonesw

class IncomingCallTutorialContext : ObservableObject
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
	
	// Incoming call related variables
	@Published var callMsg : String = ""
	@Published var isCallIncoming : Bool = false
	@Published var isCallRunning : Bool = false
	@Published var remoteAddress : String = "Nobody yet"
	@Published var isSpeakerEnabled : Bool = false
	@Published var isMicrophoneEnabled : Bool = false
	
	init()
	{
		LoggingService.Instance.logLevel = LogLevel.Debug
		
		try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
		try? mCore.start()
		
		mCoreDelegate = CoreDelegateStub( onCallStateChanged: { (core: Core, call: Call, state: Call.State, message: String) in
			self.callMsg = message
			if (state == .IncomingReceived) { // When a call is received
				self.isCallIncoming = true
				self.isCallRunning = false
				self.remoteAddress = call.remoteAddress!.asStringUriOnly()
			} else if (state == .Connected) { // When a call is over
				self.isCallIncoming = false
				self.isCallRunning = true
			} else if (state == .Released) { // When a call is over
				self.isCallIncoming = false
				self.isCallRunning = false
				self.remoteAddress = "Nobody yet"
			}
		}, onAudioDeviceChanged: { (core: Core, device: AudioDevice) in
			// This callback will be triggered when a successful audio device has been changed
		}, onAudioDevicesListUpdated: { (core: Core) in
			// This callback will be triggered when the available devices list has changed,
			// for example after a bluetooth headset has been connected/disconnected.
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
	
	func terminateCall() {
		do {
			// Terminates the call, whether it is ringing or running
			try mCore.currentCall?.terminate()
		} catch { NSLog(error.localizedDescription) }
	}
	
	func acceptCall() {
		// IMPORTANT : Make sure you allowed the use of the microphone (see key "Privacy - Microphone usage description" in Info.plist) !
		do {
			// if we wanted, we could create a CallParams object
			// and answer using this object to make changes to the call configuration
			// (see OutgoingCall tutorial)
			try mCore.currentCall?.accept()
		} catch { NSLog(error.localizedDescription) }
	}
	
	func muteMicrophone() {
		// The following toggles the microphone, disabling completely / enabling the sound capture
		// from the device microphone
		mCore.micEnabled = !mCore.micEnabled
		isMicrophoneEnabled = !isMicrophoneEnabled
	}
	
	func toggleSpeaker() {
		// Get the currently used audio device
		let currentAudioDevice = mCore.currentCall?.outputAudioDevice
		let speakerEnabled = currentAudioDevice?.type == AudioDeviceType.Speaker
		
		let test = currentAudioDevice?.deviceName
		// We can get a list of all available audio devices using
		// Note that on tablets for example, there may be no Earpiece device
		for audioDevice in mCore.audioDevices {
			
			// For IOS, the Speaker is an exception, Linphone cannot differentiate Input and Output.
			// This means that the default output device, the earpiece, is paired with the default phone microphone.
			// Setting the output audio device to the microphone will redirect the sound to the earpiece.
			if (speakerEnabled && audioDevice.type == AudioDeviceType.Microphone) {
				mCore.currentCall?.outputAudioDevice = audioDevice
				isSpeakerEnabled = false
				return
			} else if (!speakerEnabled && audioDevice.type == AudioDeviceType.Speaker) {
				mCore.currentCall?.outputAudioDevice = audioDevice
				isSpeakerEnabled = true
				return
			}
			/* If we wanted to route the audio to a bluetooth headset
			else if (audioDevice.type == AudioDevice.Type.Bluetooth) {
			core.currentCall?.outputAudioDevice = audioDevice
			}*/
		}
	}
}
