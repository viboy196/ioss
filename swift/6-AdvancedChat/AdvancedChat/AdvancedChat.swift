//
//  GroupChat.swift
//  GroupChat
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import linphonesw



class AdvancedChatTutorialContext : ObservableObject
{
	var mCore: Core!
	@Published var coreVersion: String = Core.getVersion
	
	var mRegistrationDelegate : CoreDelegate!
	@Published var username : String = "user"
	@Published var passwd : String = "pwd"
	@Published var domain : String = "sip.example.org"
	@Published var loggedIn: Bool = false
	@Published var transportType : String = "TLS"
	
	/*------------ Advanced chat tutorial related variables -------*/
	var mChatroom : ChatRoom?
	var mChatroomDelegate : ChatRoomDelegate!
	var mChatMessageDelegate : ChatMessageDelegate!
	var mChatMessage : ChatMessage?
	var mLastFileMessageReceived : ChatMessage?
	@Published var msgToSend : String = "msg"
	@Published var remoteAddress : String = "sip:remote@sip.example.org"
	@Published var canEditAddress : Bool = true
	@Published var isDownloading : Bool = false
	@Published var messagesReceived : String = ""
	var fileFolderUrl : URL!
	var fileUrl : URL!
	
	init()
	{
		LoggingService.Instance.logLevel = LogLevel.Debug
		
		try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
		try? mCore.start()
		
		mRegistrationDelegate = CoreDelegateStub(onMessageReceived : { (core: Core, chatRoom: ChatRoom, message: ChatMessage) in
			if (self.mChatroom == nil) {
				// Check it is an one-to-one encrypted chat room
				if (chatRoom.hasCapability(mask: ChatRoomCapabilities.OneToOne.rawValue) &&
						chatRoom.hasCapability(mask: ChatRoomCapabilities.Encrypted.rawValue)) {
					// Keep the chatRoom object to use it to send messages if it hasn't been created yet
					self.mChatroom = chatRoom
					self.mChatroom!.addDelegate(delegate: self.mChatroomDelegate)
					self.enableEphemeral()
					if let remoteAddress = chatRoom.peerAddress?.asStringUriOnly() {
						self.remoteAddress = remoteAddress
					}
					self.canEditAddress = false
				}
			}
			
			chatRoom.markAsRead()
			
			for content in message.contents {
				if (content.isFileTransfer) {
					self.mLastFileMessageReceived = message
					self.messagesReceived += "\n--File available for download--"
				} else if (content.isText) {
					self.messagesReceived += "\nThem: \(message.utf8Text)"
				}
			}
			
		}, onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
			NSLog("New registration state is \(state) for user id \( String(describing: account.params?.identityAddress?.asString()))\n")
			if (state == .Ok) {
				self.loggedIn = true
			} else if (state == .Cleared) {
				self.loggedIn = false
			}
		})
		mCore.addDelegate(delegate: mRegistrationDelegate)
		
		// This delegate has to be attached to each specific chat message we want to monitor, before sending it
		mChatMessageDelegate = ChatMessageDelegateStub(onMsgStateChanged : { (message: ChatMessage, state: ChatMessage.State) in
			print("MessageTrace - msg state changed: \(state)\n")
			if (state == .InProgress) {
				
			} else if (state == .Delivered) {
				// The proxy server has acknowledged the message with a 200 OK
				self.messagesReceived += "\nMe: \(message.utf8Text)"
			} else if (state == .DeliveredToUser) {
				// User has received it
			} else if (state == .Displayed) {
				// User has read it (client called chatRoom.markAsRead()
			} else if (state == .NotDelivered) {
				// User might be invalid or not registered
			} else if (state == .FileTransferDone && self.isDownloading == true) {
				// We finished uploading/downloading the file
				self.isDownloading = false
			}
		})
		
		
		mChatroomDelegate =	ChatRoomDelegateStub ( onStateChanged: { (chatRoom: ChatRoom, newState: ChatRoom.State?) in
			if (newState == ChatRoom.State.Created) {
				self.enableEphemeral()
			}
		}, onEphemeralEvent: { (chatRoom: ChatRoom, eventLog: EventLog) in
			// This event is generated when the chat room ephemeral settings are being changed
		}, onEphemeralMessageTimerStarted: { (chatRoom: ChatRoom, eventLog: EventLog) in
			// This is called when a message has been read by all recipient, so the timer has started
		}, onEphemeralMessageDeleted: { (chatRoom: ChatRoom, eventLog: EventLog) in
			// This is called when a message has expired and we should remove it from the view
		})
		
		
		// example file to send
		let documentsPath = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
		fileFolderUrl = documentsPath.appendingPathComponent("TutorialFiles")
		fileUrl = fileFolderUrl?.appendingPathComponent("file_to_transfer.txt")
		do{
			try FileManager.default.createDirectory(atPath: fileFolderUrl!.path, withIntermediateDirectories: true, attributes: nil)
			try String("My file content").write(to: fileUrl!, atomically: false, encoding: .utf8)
		}catch let error as NSError{
			print("Unable to create d)irectory",error)
		}
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
			
			// We need a conference factory URI set on the Account to be able to create chat rooms with flexisip backend
			accountParams.conferenceFactoryUri = "sip:conference-factory@sip.linphone.org"
			
			mCore.addAuthInfo(info: authInfo)
			
			let account = try mCore.createAccount(params: accountParams)
			try mCore.addAccount(account: account)
			mCore.defaultAccount = account
			
			// We also need a LIME X3DH server URL configured for end to end encryption
			mCore.limeX3DhServerUrl = "https://lime.linphone.org/lime-server/lime-server.php"
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
	
	
	func createFlexisipChatRoom() {
		do {
			// In this tutorial we will create a Flexisip one-to-one chat room with end-to-end encryption
			// For it to work, the proxy server we connect to must be an instance of Flexisip
			// And we must have configured on the Account a conference-factory URI
			let params = try mCore.createDefaultChatRoomParams()
			
			// We won't create a group chat, only a 1-1 with advanced features such as end-to-end encryption
			params.backend = ChatRoomBackend.FlexisipChat
			params.groupEnabled = false
			
			// We will rely on LIME encryption backend (we must have configured the core.limex3dhServerUrl first)
			params.encryptionEnabled = true
			params.encryptionBackend = ChatRoomEncryptionBackend.Lime
			
			// A flexisip chat room must have a subject
			// But as we are doing a 1-1 chat room here we won't display it, so we can set whatever we want
			params.subject = "dummy subject"
			
			if (params.isValid) {
				// We also need the SIP address of the person we will chat with
				let remote = try Factory.Instance.createAddress(addr: remoteAddress)
				
				// And finally we will need our local SIP address
				let localAddress = mCore.defaultAccount?.params?.identityAddress
				mChatroom = try mCore.createChatRoom(params: params, localAddr: localAddress, participants: [remote])
				// If chat room isn't created yet, wait for it to go in state Created
				// as Flexisip chat room creation process is asynchronous
				mChatroom!.addDelegate(delegate: mChatroomDelegate)
				
				// Chat room may already be created (for example if you logged in with an account for which the chat room already exists)
				if (mChatroom!.state == ChatRoom.State.Created) {
					enableEphemeral()
					canEditAddress = false
				}
			}
		} catch { NSLog(error.localizedDescription) }
	}
	
	func sendMessage() {
		do {
			if (mChatroom == nil) {
				createFlexisipChatRoom()
			}
			mChatMessage = nil
			mChatMessage = try mChatroom!.createMessageFromUtf8(message: msgToSend)
			mChatMessage!.addDelegate(delegate: mChatMessageDelegate)
			mChatMessage!.send()
			msgToSend.removeAll()
		} catch { NSLog(error.localizedDescription) }
	}
	
	func sendFile() {
		do {
			if (mChatroom == nil) {
				createFlexisipChatRoom()
			}
			
			let content = try Factory.Instance.createContent()
			content.name = "file_to_transfer.txt"
			content.type = "text"
			content.subtype = "plain"
			content.filePath = fileUrl.path
			let chatMessage = try mChatroom!.createFileTransferMessage(initialContent: content)
			chatMessage.addDelegate(delegate: mChatMessageDelegate)
			mCore.fileTransferServer = "https://www.linphone.org:444/lft.php"
			chatMessage.send()
			
		} catch { NSLog(error.localizedDescription) }
	}
	
	func downloadLastFileMessage() {
		if let message = mLastFileMessageReceived {
			for content in message.contents {
				if (content.isFileTransfer && content.filePath.isEmpty) {
					let contentName = content.name
					if (!contentName.isEmpty) {
						content.filePath = fileFolderUrl!.appendingPathComponent(contentName).path
						print("Start downloading \(content.name) into \(content.filePath)")
						isDownloading = true
						if (!message.downloadContent(content: content)) {
							print ("Download of \(contentName) failed")
						}
					}
				}
			}
		}
	}
	
	
	func enableEphemeral() {
		// Once chat room has been created, we can enable ephemeral feature
		// We enable ephemeral messages at the chat room level
		// Please note this only affects messages we send, not the ones we receive
		mChatroom?.ephemeralEnabled = true
		// Here we ask for a lifetime of 60 seconds, starting the moment the message has been read
		mChatroom?.ephemeralLifetime = 60
	}
}
