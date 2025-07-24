// ArcGISSymbolRenderer.swift
// Utilities for creating ArcGIS symbols and graphics

import UIKit
import ArcGIS

struct ArcGISSymbolRenderer {
    
    static func createSymbol(for entry: JournalEntry) -> Symbol {
        if let photoData = entry.photoData, let originalImage = UIImage(data: photoData) {
            // Create a pin with the stamp photo
            let pinImage = createModernPinImage(from: originalImage)
            let pictureSymbol = PictureMarkerSymbol(image: pinImage)
            pictureSymbol.width = 50.0
            pictureSymbol.height = 65.0
            // Offset so pin tip points to location
            pictureSymbol.offsetY = 32.5
            return pictureSymbol
        } else {
            // Fallback pin for entries without photos
            let simpleSymbol = SimpleMarkerSymbol(
                style: .circle,
                color: .systemOrange,
                size: 24.0
            )
            simpleSymbol.outline = SimpleLineSymbol(
                style: .solid,
                color: .white,
                width: 3.0
            )
            return simpleSymbol
        }
    }
    
    private static func createModernPinImage(from originalImage: UIImage) -> UIImage {
        let croppedImage = cropImageToSquare(originalImage)
        let pinSize = CGSize(width: 50, height: 65)
        let imageSize = CGSize(width: 36, height: 36)
        
        let renderer = UIGraphicsImageRenderer(size: pinSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            let centerX = pinSize.width / 2
            let imageY: CGFloat = 8
            let imageRect = CGRect(
                x: (pinSize.width - imageSize.width) / 2,
                y: imageY,
                width: imageSize.width,
                height: imageSize.height
            )
            
            // Rounded rectangle for photo area
            let photoPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 8)
            
            // Pin tip triangle
            let tipPath = UIBezierPath()
            tipPath.move(to: CGPoint(x: centerX - 8, y: imageRect.maxY + 4))
            tipPath.addLine(to: CGPoint(x: centerX, y: pinSize.height - 4))
            tipPath.addLine(to: CGPoint(x: centerX + 8, y: imageRect.maxY + 4))
            tipPath.close()
            
            // Draw shadow
            cgContext.setShadow(
                offset: CGSize(width: 1, height: 2),
                blur: 4,
                color: UIColor.black.withAlphaComponent(0.3).cgColor
            )
            
            // Draw white background for photo area
            UIColor.white.setFill()
            photoPath.fill()
            
            // Draw photo with rounded corners
            cgContext.saveGState()
            photoPath.addClip()
            croppedImage.draw(in: imageRect)
            cgContext.restoreGState()
            
            // Draw pin tip
            UIColor.white.setFill()
            tipPath.fill()
            
            // Draw border
            UIColor.systemGray4.setStroke()
            photoPath.lineWidth = 1
            photoPath.stroke()
        }
    }
    
    private static func cropImageToSquare(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let origin = CGPoint(
            x: (image.size.width - size) / 2,
            y: (image.size.height - size) / 2
        )
        
        guard let cgImage = image.cgImage?.cropping(to: CGRect(
            x: origin.x * image.scale,
            y: origin.y * image.scale,
            width: size * image.scale,
            height: size * image.scale
        )) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}