//
//  HellowolrdTutorial.swift
//  HellowolrdTutorial
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

// Check the Podfile to see how to import the LibLinphone SDK !!!
import linphonesw

class HelloworldTutorialContext : ObservableObject
{
	var mCore: Core!
	@Published var coreVersion: String = Core.getVersion
	
	/*------------ Login tutorial related variables -------*/
	var mRegistrationDelegate : CoreDelegate!
	@Published var username : String = "user"
	@Published var passwd : String = "pwd"
	@Published var domain : String = "sip.example.org"
	@Published var loggedIn: Bool = false
	@Published var transportType : String = "TLS"
	
	init()
	{
		
		// Some configuration can be done before the Core is created, for example enable debug logs.
		LoggingService.Instance.logLevel = LogLevel.Debug
		
		// Core is the main object of the SDK. You can't do much without it.
		// To create a Core, we need the instance of the Factory.
		let factory = Factory.Instance
		
		// Your Core can use up to 2 configuration files, but that isn't mandatory.
		try! mCore = factory.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
		try! mCore.start()
		
		// Create a Core listener to listen for the callback we need
		// In this case, we want to know about the account registration status
		mRegistrationDelegate = CoreDelegateStub(onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
			
			// If account has been configured correctly, we will go through Progress and Ok states
			// Otherwise, we will be Failed.
			NSLog("New registration state is \(state) for user id \( String(describing: account.params?.identityAddress?.asString()))\n")
			if (state == .Ok) {
				self.loggedIn = true
			} else if (state == .Cleared) {
				self.loggedIn = false
			}
		})
		mCore.addDelegate(delegate: mRegistrationDelegate)
		coreVersion = Core.getVersion
		// Now we can start using the Core object
	}
	
	
}
