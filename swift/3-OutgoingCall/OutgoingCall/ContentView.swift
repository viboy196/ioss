//
//  ContentView.swift
//  IncomingCall tutorial
//
//  Created by QuentinArguillere on 09/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import SwiftUI
import linphonesw

struct ContentView: View {
	
	@ObservedObject var tutorialContext : OutgoingCallTutorialContext
	
	func callStateString() -> String {
		if (tutorialContext.isCallRunning) {
			return "Call running"
		} else {
			return "No Call"
		}
	}
	
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
				}
				VStack {
					HStack {
						Text("Call dest:")
							.font(.title)
						TextField("", text : $tutorialContext.remoteAddress)
							.textFieldStyle(RoundedBorderTextFieldStyle())
							.disabled(!tutorialContext.loggedIn)
					}
					HStack {
						Button(action: {
							if (self.tutorialContext.isCallRunning) {
								self.tutorialContext.terminateCall()
							} else {
								self.tutorialContext.outgoingCall()
							}
						})
						{
							Text( (tutorialContext.isCallRunning) ? "End" : "Call")
								.font(.largeTitle)
								.foregroundColor(Color.white)
								.frame(width: 180.0, height: 42.0)
								.background(Color.gray)
						}
						HStack {
							Text(tutorialContext.isCallRunning ? "Running" : "")
								.italic().foregroundColor(.green)
							Spacer()
						}
					}
					HStack {
						Text("Call msg:").font(.title3).underline()
						Text(tutorialContext.callMsg)
						Spacer()
					}.padding(.top, 5)
					HStack {
						Button(action: tutorialContext.toggleVideo)
						{
							Text((tutorialContext.isVideoEnabled) ? "Video OFF" : "Video ON")
								.font(.title3)
								.foregroundColor(Color.white)
								.frame(width: 130.0, height: 42.0)
								.background(Color.gray)
						}
						.disabled(!tutorialContext.isCallRunning)
						Button(action: tutorialContext.toggleCamera)
						{
							Text("Change camera")
								.font(.title3)
								.foregroundColor(Color.white)
								.frame(width: 160.0, height: 42.0)
								.background(Color.gray)
						}
						.disabled(!tutorialContext.canChangeCamera || !tutorialContext.isVideoEnabled)
					}.padding(.top, 5)
					HStack {
						VStack {
							LinphoneVideoViewHolder() { view in
								self.tutorialContext.mCore.nativeVideoWindow = view
							}
							.frame(width: 120, height: 160.0)
							.border(Color.gray)
							.padding(.leading)
							Text("What I receive")
						}
						Spacer()
						VStack {
							LinphoneVideoViewHolder() { view in
								self.tutorialContext.mCore.nativePreviewWindow = view
							}
							.frame(width: 120, height: 160.0)
							.border(Color.gray)
							.padding(.leading)
							Text("What I send")
						}
					}
				}.padding(.top, 30)
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
		ContentView(tutorialContext: OutgoingCallTutorialContext())
	}
}
