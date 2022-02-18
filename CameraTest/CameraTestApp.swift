//
//  CameraTestApp.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/16/22.
//

import SwiftUI

@main
struct CameraTestApp: App {
	let uv = UserEvents()
    var body: some Scene {
        WindowGroup {
            ContentView()
				.environmentObject(uv)
        }
    }
}
