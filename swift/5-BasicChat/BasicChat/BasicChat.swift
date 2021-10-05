//
//  BasicChat.swift
//  BasicChat
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import linphonesw



class BasicChatTutorialContext : ObservableObject
{
	var mCore: Core!
	@Published var coreVersion: String = Core.getVersion
	
	var mRegistrationDelegate : CoreDelegate!
	@Published var username : String = "user"
	@Published var passwd : String = "pwd"
	@Published var domain : String = "sip.example.org"
	@Published var loggedIn: Bool = false
	@Published var transportType : String = "TLS"
	
	/*------------ Basic chat tutorial related variables -------*/
	var mChatroom : ChatRoom?
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
			// We will be called in this when a message is received
			// If the chat room wasn't existing, it is automatically created by the library
			// If we already sent a chat message, the chatRoom variable will be the same as the one we already have
			if (self.mChatroom == nil) {
				if (chatRoom.hasCapability(mask: ChatRoomCapabilities.Basic.rawValue)) {
					// Keep the chatRoom object to use it to send messages if it hasn't been created yet
					self.mChatroom = chatRoom
					if let remoteAddress = chatRoom.peerAddress?.asStringUriOnly() {
						self.remoteAddress = remoteAddress
					}
					self.canEditAddress = false
				}
			}
			// We will notify the sender the message has been read by us
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
			if (state == ChatMessage.State.FileTransferDone && self.isDownloading == true) {
				self.isDownloading = false
			} else if (state == .Delivered) {
				self.messagesReceived += "\nMe: \(message.utf8Text)"
			}
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
			let account = try mCore.createAccount(params: accountParams)
			
			mCore.addAuthInfo(info: authInfo)
			try mCore.addAccount(account: account)
			
			mCore.defaultAccount = account
			
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
	
	func createBasicChatRoom() {
		do {
			// In this tutorial we will create a Basic chat room
			// It doesn't include advanced features such as end-to-end encryption or groups
			// But it is interoperable with any SIP service as it's relying on SIP SIMPLE messages
			// If you try to enable a feature not supported by the basic backend, isValid() will return false
			let params = try mCore.createDefaultChatRoomParams()
			params.backend = ChatRoomBackend.Basic
			params.encryptionEnabled = false
			params.groupEnabled = false
			
			if (params.isValid) {
				// We also need the SIP address of the person we will chat with
				let remote = try Factory.Instance.createAddress(addr: remoteAddress)
				// And finally we will need our local SIP address
				let localAddress = mCore.defaultAccount?.params?.identityAddress
				mChatroom = try mCore.createChatRoom(params: params, localAddr: localAddress, participants: [remote])
				if (mChatroom != nil) {
					canEditAddress = false
				}
			}
		} catch { NSLog(error.localizedDescription) }
	}
	
	func sendMessage() {
		do {
			if (mChatroom == nil) {
				// We need a ChatRoom object to send chat messages in it, so let's create it if it hasn't been done yet
				createBasicChatRoom()
			}
			mChatMessage = nil
			// We need to create a ChatMessage object using the ChatRoom
			mChatMessage = try mChatroom!.createMessageFromUtf8(message: msgToSend)
			
			// Then we can send it, progress will be notified using the onMsgStateChanged callback
			mChatMessage!.addDelegate(delegate: mChatMessageDelegate)
			
			// Send the message
			mChatMessage!.send()
			
			// Clear the message input field
			msgToSend.removeAll()
		} catch { NSLog(error.localizedDescription) }
	}
	
	func sendFile() {
		do {
			if (mChatroom == nil) {
				// We need a ChatRoom object to send chat messages in it, so let's create it if it hasn't been done yet
				createBasicChatRoom()
			}
			
			// We need to create a Content for our file transfer
			let content = try Factory.Instance.createContent()
			// Every content needs a content type & subtype
			content.name = "file_to_transfer.txt"
			content.type = "text"
			content.subtype = "plain"
			
			// The simplest way to upload a file is to provide it's path
			content.filePath = fileUrl.path
			
			// We need to create a ChatMessage object using the ChatRoom
			let chatMessage = try mChatroom!.createFileTransferMessage(initialContent: content)
			
			// Then we can send it, progress will be notified using the onMsgStateChanged callback
			chatMessage.addDelegate(delegate: mChatMessageDelegate)
			
			// Ensure a file sharing server URL is correctly set in the Core
			mCore.fileTransferServer = "https://www.linphone.org:444/lft.php"
			
			// Send the message
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
}
