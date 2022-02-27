//
//  CustomVideoPlayer.swift
//  CameraTest
//
//  Created by Trevor Welsh on 2/24/22.
//

import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
	@EnvironmentObject var cvm: CameraViewModel
	public var player: AVPlayer
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(parent: self)
	}
	
	func makeUIViewController(context: Context) -> AVPlayerViewController {
		let controller = AVPlayerViewController()
		controller.player = self.player
		controller.showsPlaybackControls = false
		controller.videoGravity = self.cvm.videoGravity
		player.actionAtItemEnd = .none
		
		NotificationCenter.default.addObserver(context.coordinator, selector: #selector(context.coordinator.restartPlayback), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
		
		return controller
	}
	
	func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) { }
	
	class Coordinator: NSObject {
		public var parent: CustomVideoPlayer
		init(parent: CustomVideoPlayer) {
			self.parent = parent
		}
		
		@objc func restartPlayback () {
			self.parent.player.seek(to: .zero)
		}
	}
}

//struct CustomVideoPlayer_Previews: PreviewProvider {
//    static var previews: some View {
//        CustomVideoPlayer()
//    }
//}
