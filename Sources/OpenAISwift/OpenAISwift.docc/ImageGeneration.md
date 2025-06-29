# Image Generation

Generate images using DALL-E models.

## Overview

OpenAISwift provides access to DALL-E image generation capabilities, allowing you to create images from text descriptions, edit existing images, and create variations.

## Basic Image Generation

```swift
let request = ImageRequest(
    prompt: "A serene landscape with mountains and a lake at sunset",
    model: "dall-e-3",
    size: .size1024x1024,
    quality: .hd,
    n: 1
)

let response = try await openAI.createImage(request)
if let imageData = response.data.first {
    print("Image URL: \(imageData.url ?? "")")
    // Use imageData.b64Json if you requested base64 format
}
```

## Image Models and Options

### Available Models
- `dall-e-2`: Fast generation, lower quality
- `dall-e-3`: Higher quality, more accurate prompt following

### Size Options
- DALL-E 2: `256x256`, `512x512`, `1024x1024`
- DALL-E 3: `1024x1024`, `1024x1792`, `1792x1024`

### Quality Settings (DALL-E 3 only)
- `.standard`: Faster generation
- `.hd`: Higher detail and quality

## See Also

- ``ImageRequest``
- ``ImageResponse``