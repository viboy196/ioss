//
//  ContentView.swift
//  HelloworldTutorial
//
//  Created by QuentinArguillere on 08/09/2021.
//  Copyright © 2021 BelledonneCommunications. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	
	@ObservedObject var tutorialContext : HelloworldTutorialContext
	
	var body: some View {
		
		VStack {
			Group {
				Spacer()
				Text("Hello World ! \nCore Version is \(tutorialContext.coreVersion)")
				Spacer()
			}
		}
		.padding()
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView(tutorialContext: HelloworldTutorialContext())
	}
}
