//
//  LoginExample.swift
//  LoginTutorial
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import linphonesw

class LoginTutorialContext : ObservableObject
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
		
		LoggingService.Instance.logLevel = LogLevel.Debug
		
		try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
		try? mCore.start()
		
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
	}
	
	func login() {
		
		do {
			// Get the transport protocol to use.
			// TLS is strongly recommended
			// Only use UDP if you don't have the choice
			var transport : TransportType
			if (transportType == "TLS") { transport = TransportType.Tls }
			else if (transportType == "TCP") { transport = TransportType.Tcp }
			else  { transport = TransportType.Udp }
			
			// To configure a SIP account, we need an Account object and an AuthInfo object
			// The first one is how to connect to the proxy server, the second one stores the credentials
			
			// The auth info can be created from the Factory as it's only a data class
			// userID is set to null as it's the same as the username in our case
			// ha1 is set to null as we are using the clear text password. Upon first register, the hash will be computed automatically.
			// The realm will be determined automatically from the first register, as well as the algorithm
			let authInfo = try Factory.Instance.createAuthInfo(username: username, userid: "", passwd: passwd, ha1: "", realm: "", domain: domain)
			
			// Account object replaces deprecated ProxyConfig object
			// Account object is configured through an AccountParams object that we can obtain from the Core
			let accountParams = try mCore.createAccountParams()
			
			// A SIP account is identified by an identity address that we can construct from the username and domain
			let identity = try Factory.Instance.createAddress(addr: String("sip:" + username + "@" + domain))
			try! accountParams.setIdentityaddress(newValue: identity)
			
			// We also need to configure where the proxy server is located
			let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
			
			// We use the Address object to easily set the transport protocol
			try address.setTransport(newValue: transport)
			try accountParams.setServeraddress(newValue: address)
			// And we ensure the account will start the registration process
			accountParams.registerEnabled = true
			
			// Now that our AccountParams is configured, we can create the Account object
			let account = try mCore.createAccount(params: accountParams)
			
			// Now let's add our objects to the Core
			mCore.addAuthInfo(info: authInfo)
			try mCore.addAccount(account: account)
			
			// Also set the newly added account as default
			mCore.defaultAccount = account
			
		} catch { NSLog(error.localizedDescription) }
	}
	
	func unregister()
	{
		// Here we will disable the registration of our Account
		if let account = mCore.defaultAccount {
			
			let params = account.params
			// Returned params object is const, so to make changes we first need to clone it
			let clonedParams = params?.clone()
			
			// Now let's make our changes
			clonedParams?.registerEnabled = false
			
			// And apply them
			account.params = clonedParams
		}
	}
	func delete() {
		// To completely remove an Account
		if let account = mCore.defaultAccount {
			mCore.removeAccount(account: account)
			
			// To remove all accounts use
			mCore.clearAccounts()
			
			// Same for auth info
			mCore.clearAllAuthInfo()
		}
	}
	
	
}
