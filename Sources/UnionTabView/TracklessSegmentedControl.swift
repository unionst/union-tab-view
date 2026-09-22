import UIKit

class TracklessSegmentedControl: UISegmentedControl {
    override func layoutSubviews() {
        super.layoutSubviews()
        hideTrack()
    }

    private func hideTrack() {
        let indicator = subviews.last
        for subview in subviews where subview is UIImageView && subview !== indicator {
            subview.alpha = 0
        }
    }
}
