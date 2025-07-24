// MapKitPinRenderer.swift
// Utility class for rendering custom MapKit pin graphics

import UIKit

struct MapKitPinRenderer {
    
    static func createPhotoPinImage(from originalImage: UIImage) -> UIImage {
        let croppedImage = cropToSquare(originalImage)
        let pinSize = CGSize(width: 60, height: 75)
        let photoSize = CGSize(width: 50, height: 50)
        
        let renderer = UIGraphicsImageRenderer(size: pinSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Photo frame rectangle
            let photoRect = CGRect(
                x: (pinSize.width - photoSize.width) / 2,
                y: 5,
                width: photoSize.width,
                height: photoSize.height
            )
            
            // Pin tip triangle
            let tipPath = UIBezierPath()
            let centerX = pinSize.width / 2
            tipPath.move(to: CGPoint(x: centerX - 8, y: photoRect.maxY + 5))
            tipPath.addLine(to: CGPoint(x: centerX, y: pinSize.height - 5))
            tipPath.addLine(to: CGPoint(x: centerX + 8, y: photoRect.maxY + 5))
            tipPath.close()
            
            // Draw shadow
            cgContext.setShadow(offset: CGSize(width: 2, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.4).cgColor)
            
            // Draw white background frame
            let frameRect = photoRect.insetBy(dx: -3, dy: -3)
            let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 8)
            UIColor.white.setFill()
            framePath.fill()
            
            // Draw photo with rounded corners
            cgContext.saveGState()
            let photoPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            photoPath.addClip()
            croppedImage.draw(in: photoRect)
            cgContext.restoreGState()
            
            // Draw pin tip
            UIColor.white.setFill()
            tipPath.fill()
            
            // Draw border around photo
            UIColor.systemGray4.setStroke()
            let borderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            borderPath.lineWidth = 1
            borderPath.stroke()
        }
    }
    
    static func createPlaceholderPinImage() -> UIImage {
        let pinSize = CGSize(width: 60, height: 75)
        let photoSize = CGSize(width: 50, height: 50)
        
        let renderer = UIGraphicsImageRenderer(size: pinSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Photo frame rectangle
            let photoRect = CGRect(
                x: (pinSize.width - photoSize.width) / 2,
                y: 5,
                width: photoSize.width,
                height: photoSize.height
            )
            
            // Pin tip triangle
            let tipPath = UIBezierPath()
            let centerX = pinSize.width / 2
            tipPath.move(to: CGPoint(x: centerX - 8, y: photoRect.maxY + 5))
            tipPath.addLine(to: CGPoint(x: centerX, y: pinSize.height - 5))
            tipPath.addLine(to: CGPoint(x: centerX + 8, y: photoRect.maxY + 5))
            tipPath.close()
            
            // Draw shadow
            cgContext.setShadow(offset: CGSize(width: 2, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.4).cgColor)
            
            // Draw white background frame
            let frameRect = photoRect.insetBy(dx: -3, dy: -3)
            let framePath = UIBezierPath(roundedRect: frameRect, cornerRadius: 8)
            UIColor.white.setFill()
            framePath.fill()
            
            // Draw gray placeholder background
            let placeholderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            UIColor.systemGray5.setFill()
            placeholderPath.fill()
            
            // Draw photo icon
            let iconRect = CGRect(
                x: photoRect.midX - 12,
                y: photoRect.midY - 12,
                width: 24,
                height: 24
            )
            
            if let photoIcon = UIImage(systemName: "photo")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)) {
                UIColor.systemGray3.setFill()
                photoIcon.draw(in: iconRect)
            }
            
            // Draw pin tip
            UIColor.white.setFill()
            tipPath.fill()
            
            // Draw border
            UIColor.systemGray4.setStroke()
            let borderPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 6)
            borderPath.lineWidth = 1
            borderPath.stroke()
        }
    }
    
    private static func cropToSquare(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let x = (image.size.width - size) / 2
        let y = (image.size.height - size) / 2
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}