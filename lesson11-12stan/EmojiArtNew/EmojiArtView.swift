//
//  EmojiArtView.swift
//  EmojiArt
//
//  Created by Анастасия Распутняк on 13.09.2019.
//  Copyright © 2019 Anastasiya Rasputnyak. All rights reserved.
//

import UIKit

protocol EmojiArtViewDelegate: class {
    func emojiArtViewChanged(_ sender : EmojiArtView)
}

extension Notification.Name {
    static let EmojiArtViewDidChange = Notification.Name("EmojiArtViewDidChange")
}

class EmojiArtView: UIView {
    
    weak var delegate : EmojiArtViewDelegate?
    private var labelObservations = [UIView : NSKeyValueObservation]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        addInteraction(UIDropInteraction(delegate: self))
    }
    
    var backgroundImage : UIImage? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        backgroundImage?.draw(in: bounds)
    }

}


extension EmojiArtView : UIDropInteractionDelegate {
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: NSAttributedString.self) { providers in
            let dropPoint = session.location(in: self)
            for attributedString in providers as? [NSAttributedString] ?? [] {
                self.addLabel(with: attributedString, centeredAt: dropPoint)
                
                self.delegate?.emojiArtViewChanged(self)
                NotificationCenter.default.post(name: .EmojiArtViewDidChange, object: self)
            }
        }
    }
    
    
    func addLabel(with attributedString : NSAttributedString, centeredAt dropPoint : CGPoint) {
        let label = UILabel()
        label.backgroundColor = .clear
        label.attributedText = attributedString
        label.sizeToFit()
        label.center = dropPoint
        addEmojiArtGestureRecognizers(to: label)
        self.addSubview(label)
        
        labelObservations[label] = label.observe(\.center) { (label, change) in
            self.delegate?.emojiArtViewChanged(self)
            NotificationCenter.default.post(name: .EmojiArtViewDidChange, object: self)
        }
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if labelObservations[subview] != nil {
            labelObservations[subview] = nil
        }
    }
}


extension EmojiArtView {
    
    func addEmojiArtGestureRecognizers(to view: UIView) {
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.selectSubview(by:))))
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.selectAndMoveSubview(by:))))
    }
    
    var selectedSubview: UIView? {
        get { return subviews.filter { $0.layer.borderWidth > 0 }.first }
        set {
            subviews.forEach { $0.layer.borderWidth = 0 }
            newValue?.layer.borderWidth = 1
            if newValue != nil {
                enableRecognizers()
            } else {
                disableRecognizers()
            }
        }
    }
    
    @objc func selectSubview(by recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            selectedSubview = recognizer.view
        }
    }
    
    @objc func selectAndMoveSubview(by recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            if selectedSubview != nil, recognizer.view != nil {
                selectedSubview = recognizer.view
            }
        case .changed, .ended:
            if selectedSubview != nil {
                recognizer.view?.center = recognizer.view!.center.offset(by: recognizer.translation(in: self))
                recognizer.setTranslation(CGPoint.zero, in: self)
                
                if recognizer.state == .ended {
                    self.delegate?.emojiArtViewChanged(self)
                    NotificationCenter.default.post(name: .EmojiArtViewDidChange, object: self)
                }
            }
        default:
            break
        }
    }
    
    func enableRecognizers() {
        if let scrollView = superview as? UIScrollView {
            // if we are in a scroll view, disable its recognizers
            // so that ours will get the touch events instead
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.pinchGestureRecognizer?.isEnabled = false
        }
        if gestureRecognizers == nil || gestureRecognizers!.count == 0 {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.deselectSubview)))
            addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(self.resizeSelectedLabel(by:))))
        } else {
            gestureRecognizers?.forEach { $0.isEnabled = true }
        }
    }
    
    func disableRecognizers() {
        if let scrollView = superview as? UIScrollView {
            // if we are in a scroll view, re-enable its recognizers
            scrollView.panGestureRecognizer.isEnabled = true
            scrollView.pinchGestureRecognizer?.isEnabled = true
        }
        gestureRecognizers?.forEach { $0.isEnabled = false }
    }
    
    @objc func deselectSubview() {
        selectedSubview = nil
    }
    
    @objc func resizeSelectedLabel(by recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            if let label = selectedSubview as? UILabel {
                label.attributedText = label.attributedText?.withFontScaled(by: recognizer.scale)
                label.stretchToFit()
                recognizer.scale = 1.0
                
                if recognizer.state == .ended {
                    self.delegate?.emojiArtViewChanged(self)
                    NotificationCenter.default.post(name: .EmojiArtViewDidChange, object: self)
                }
            }
        default:
            break
        }
    }
    
    @objc func selectAndSendSubviewToBack(by recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            if let view = recognizer.view, let index = subviews.index(of: view) {
                selectedSubview = view
                exchangeSubview(at: 0, withSubviewAt: index)
            }
        }
    }
}
