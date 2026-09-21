import UIKit

class TracklessSegmentedControl: UISegmentedControl {
    override func layoutSubviews() {
        super.layoutSubviews()
        hideTrack()
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        setNeedsLayout()
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        setNeedsLayout()
    }

    private func hideTrack() {
        let indicator = subviews.last
        for subview in subviews where subview is UIImageView && subview !== indicator {
            subview.alpha = 0
        }
    }
}
