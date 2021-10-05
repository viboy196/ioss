//
//  ContentView.swift
//  BasicChat
//
//  Created by QuentinArguillere on 31/07/2020.
//  Copyright © 2020 BelledonneCommunications. All rights reserved.
//

import SwiftUI

struct ActivityIndicator: UIViewRepresentable {
	func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView
	{
		return UIActivityIndicatorView(style: .medium)
	}
	
	func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>)
	{
		uiView.startAnimating()
	}
}

struct ContentView: View {
	
	@ObservedObject var tutorialContext : BasicChatTutorialContext
	
	var body: some View {
		
		VStack {
			Group {
				HStack {
					Text("Username:")
						.font(.title)
					TextField("", text : $tutorialContext.username)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.disabled(tutorialContext.loggedIn)
				}
				HStack {
					Text("Password:")
						.font(.title)
					TextField("", text : $tutorialContext.passwd)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.disabled(tutorialContext.loggedIn)
				}
				HStack {
					Text("Domain:")
						.font(.title)
					TextField("", text : $tutorialContext.domain)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						.disabled(tutorialContext.loggedIn)
				}
				Picker(selection: $tutorialContext.transportType, label: Text("Transport:")) {
					Text("TLS").tag("TLS")
					Text("TCP").tag("TCP")
					Text("UDP").tag("UDP")
				}.pickerStyle(SegmentedPickerStyle()).padding()
				VStack {
					HStack {
						Button(action:  {
							if (self.tutorialContext.loggedIn)
							{
								self.tutorialContext.unregister()
								self.tutorialContext.delete()
							} else {
								self.tutorialContext.login()
							}
						})
						{
							Text(tutorialContext.loggedIn ? "Log out & \ndelete account" : "Create & \nlog in account")
								.font(.largeTitle)
								.foregroundColor(Color.white)
								.frame(width: 220.0, height: 90)
								.background(Color.gray)
						}
						
					}
					HStack {
						Text("Login State : ")
							.font(.footnote)
						Text(tutorialContext.loggedIn ? "Looged in" : "Unregistered")
							.font(.footnote)
							.foregroundColor(tutorialContext.loggedIn ? Color.green : Color.black)
					}.padding(.top, 10.0)
					HStack {
						Text("Chat with:")
						TextField("", text : $tutorialContext.remoteAddress)
							.textFieldStyle(RoundedBorderTextFieldStyle())
							.disabled(!tutorialContext.canEditAddress)
					}
					Text("Chat received").bold()
					ScrollView {
						Text(tutorialContext.messagesReceived)
							.font(.footnote)
							.frame(width: 330, height: 400)
					}.border(Color.gray)
					HStack {
						TextField("Sent text", text : $tutorialContext.msgToSend)
							.textFieldStyle(RoundedBorderTextFieldStyle())
						Button(action: tutorialContext.sendMessage)
						{
							Text("Send")
								.font(.callout)
								.foregroundColor(Color.white)
								.frame(width: 50.0, height: 30.0)
								.background(Color.gray)
						}
					}
					HStack {
						Button(action: tutorialContext.sendFile)
						{
							Text("Send example \n file")
								.foregroundColor(Color.white)
								.multilineTextAlignment(.center)
								.frame(width: 120.0, height: 50.0)
								.background(Color.gray)
						}
						Button(action: tutorialContext.downloadLastFileMessage)
						{
							Text("Download last files \n received")
								.foregroundColor(Color.white)
								.multilineTextAlignment(.center)
								.frame(width: 150.0, height: 50.0)
								.background(Color.gray)
						}.disabled(tutorialContext.mLastFileMessageReceived == nil)
						if (tutorialContext.isDownloading) {
							ActivityIndicator()
						}
					}
				}
			}
			Group {
				Spacer()
				Text("Core Version is \(tutorialContext.coreVersion)")
			}
		}
		.padding()
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView(tutorialContext: BasicChatTutorialContext())
	}
}
