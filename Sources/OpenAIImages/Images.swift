import Foundation
import OpenAICore

/// A request to generate one or more images from a text prompt.
///
/// Use this struct to configure image generation requests to OpenAI's DALL-E models.
/// The generated images can be returned as URLs or base64-encoded JSON strings.
///
/// Example:
/// ```swift
/// let request = ImageGenerationRequest(
///     prompt: "A futuristic cityscape at sunset with flying cars",
///     model: "dall-e-3",
///     size: .size1024x1024,
///     quality: .hd,
///     n: 1
/// )
/// ```
public struct ImageGenerationRequest: Codable, Sendable {
    /// The text description of the desired image(s).
    /// Maximum length is 1000 characters for dall-e-2 and 4000 characters for dall-e-3.
    public let prompt: String

    /// The model to use for image generation.
    /// Options include "dall-e-2" and "dall-e-3". Defaults to "dall-e-2".
    public let model: String?

    /// The number of images to generate.
    /// Must be between 1 and 10. For dall-e-3, only n=1 is supported.
    public let n: Int?

    /// The quality of the image that will be generated.
    /// Only supported for dall-e-3. Defaults to "standard".
    public let quality: Quality?

    /// The format in which the generated images are returned.
    /// Can be either URL or base64-encoded JSON. Defaults to "url".
    public let responseFormat: ImageResponseFormat?

    /// The size of the generated images.
    /// Options vary by model. Defaults to 1024x1024.
    public let size: ImageSize?

    /// The style of the generated images.
    /// Only supported for dall-e-3. Defaults to "vivid".
    public let style: Style?

    /// A unique identifier representing your end-user.
    /// Can help OpenAI monitor and detect abuse.
    public let user: String?

    /// Creates a new image generation request.
    ///
    /// - Parameters:
    ///   - prompt: The text description of the desired image(s).
    ///   - model: The model to use for image generation. Defaults to nil.
    ///   - n: The number of images to generate. Defaults to nil.
    ///   - quality: The quality of the image (dall-e-3 only). Defaults to nil.
    ///   - responseFormat: The format of the response. Defaults to nil.
    ///   - size: The size of the generated images. Defaults to nil.
    ///   - style: The style of the generated images (dall-e-3 only). Defaults to nil.
    ///   - user: A unique identifier for the end-user. Defaults to nil.
    public init(
        prompt: String,
        model: String? = nil,
        n: Int? = nil,
        quality: Quality? = nil,
        responseFormat: ImageResponseFormat? = nil,
        size: ImageSize? = nil,
        style: Style? = nil,
        user: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.quality = quality
        self.responseFormat = responseFormat
        self.size = size
        self.style = style
        self.user = user
    }

    private enum CodingKeys: String, CodingKey {
        case prompt, model, n, quality, size, style, user
        case responseFormat = "response_format"
    }
}

/// A request to edit an existing image based on a text prompt.
///
/// Use this struct to configure image editing requests where you provide an original image
/// and a text prompt describing the desired edits. Optionally, you can provide a mask
/// indicating which areas of the image should be edited.
///
/// Example:
/// ```swift
/// let request = ImageEditRequest(
///     image: imageData,
///     prompt: "Add a red sports car in the foreground",
///     mask: maskData,
///     size: .size1024x1024
/// )
/// ```
///
/// - Note: Only PNG images are supported. The mask, if provided, must be a valid PNG image
///         with the same dimensions as the image. The mask should be fully transparent (alpha=0)
///         where the image should be edited.
public struct ImageEditRequest {
    /// The image to edit. Must be a valid PNG image.
    /// Must be less than 4MB, and must be square.
    public let image: Data

    /// A text description of the desired edit(s) to the image.
    /// Maximum length is 1000 characters.
    public let prompt: String

    /// An additional image whose fully transparent areas indicate where the image should be edited.
    /// Must be a valid PNG image, less than 4MB, and have the same dimensions as the image.
    public let mask: Data?

    /// The model to use for image editing.
    /// Only "dall-e-2" is supported for image edits. Defaults to "dall-e-2".
    public let model: String?

    /// The number of images to generate.
    /// Must be between 1 and 10. Defaults to 1.
    public let n: Int?

    /// The size of the generated images.
    /// Must be one of 256x256, 512x512, or 1024x1024. Defaults to 1024x1024.
    public let size: ImageSize?

    /// The format in which the generated images are returned.
    /// Can be either URL or base64-encoded JSON. Defaults to "url".
    public let responseFormat: ImageResponseFormat?

    /// A unique identifier representing your end-user.
    /// Can help OpenAI monitor and detect abuse.
    public let user: String?

    /// Creates a new image edit request.
    ///
    /// - Parameters:
    ///   - image: The image to edit. Must be a valid PNG image.
    ///   - prompt: A text description of the desired edit(s).
    ///   - mask: An optional mask indicating where edits should be applied.
    ///   - model: The model to use for editing. Defaults to nil.
    ///   - n: The number of images to generate. Defaults to nil.
    ///   - size: The size of the generated images. Defaults to nil.
    ///   - responseFormat: The format of the response. Defaults to nil.
    ///   - user: A unique identifier for the end-user. Defaults to nil.
    public init(
        image: Data,
        prompt: String,
        mask: Data? = nil,
        model: String? = nil,
        n: Int? = nil,
        size: ImageSize? = nil,
        responseFormat: ImageResponseFormat? = nil,
        user: String? = nil
    ) {
        self.image = image
        self.prompt = prompt
        self.mask = mask
        self.model = model
        self.n = n
        self.size = size
        self.responseFormat = responseFormat
        self.user = user
    }
}

/// A request to create variations of an existing image.
///
/// Use this struct to generate new variations of an existing image. The API will create
/// new images that maintain the same general composition and style as the original
/// but with variations in details.
///
/// Example:
/// ```swift
/// let request = ImageVariationRequest(
///     image: originalImageData,
///     n: 2,
///     size: .size1024x1024
/// )
/// ```
///
/// - Note: Only PNG images are supported. The input image must be less than 4MB and square.
public struct ImageVariationRequest {
    /// The image to use as the basis for the variation(s).
    /// Must be a valid PNG image, less than 4MB, and square.
    public let image: Data

    /// The model to use for generating variations.
    /// Only "dall-e-2" is supported for image variations. Defaults to "dall-e-2".
    public let model: String?

    /// The number of images to generate.
    /// Must be between 1 and 10. Defaults to 1.
    public let n: Int?

    /// The format in which the generated images are returned.
    /// Can be either URL or base64-encoded JSON. Defaults to "url".
    public let responseFormat: ImageResponseFormat?

    /// The size of the generated images.
    /// Must be one of 256x256, 512x512, or 1024x1024. Defaults to 1024x1024.
    public let size: ImageSize?

    /// A unique identifier representing your end-user.
    /// Can help OpenAI monitor and detect abuse.
    public let user: String?

    /// Creates a new image variation request.
    ///
    /// - Parameters:
    ///   - image: The image to use as the basis for variations. Must be a valid PNG image.
    ///   - model: The model to use for generating variations. Defaults to nil.
    ///   - n: The number of variations to generate. Defaults to nil.
    ///   - responseFormat: The format of the response. Defaults to nil.
    ///   - size: The size of the generated images. Defaults to nil.
    ///   - user: A unique identifier for the end-user. Defaults to nil.
    public init(
        image: Data,
        model: String? = nil,
        n: Int? = nil,
        responseFormat: ImageResponseFormat? = nil,
        size: ImageSize? = nil,
        user: String? = nil
    ) {
        self.image = image
        self.model = model
        self.n = n
        self.responseFormat = responseFormat
        self.size = size
        self.user = user
    }
}

/// The quality of the generated image.
///
/// This setting is only supported for DALL-E 3 and controls the quality/detail level
/// of the generated images.
public enum Quality: String, Codable, Sendable {
    /// Standard quality images.
    /// Faster generation time and lower cost.
    case standard

    /// High definition quality images.
    /// More detailed and higher quality but takes longer to generate.
    case hd
}

/// The format in which generated images are returned.
public enum ImageResponseFormat: String, Codable, Sendable {
    /// Return images as URLs.
    /// URLs are temporary and expire after one hour.
    case url

    /// Return images as base64-encoded JSON strings.
    /// Useful when you need to store or process the image data directly.
    case b64Json = "b64_json"
}

/// Available sizes for generated images.
///
/// The available sizes depend on the model used:
/// - DALL-E 2: Supports 256x256, 512x512, and 1024x1024
/// - DALL-E 3: Supports 1024x1024, 1792x1024, and 1024x1792
public enum ImageSize: String, Codable, Sendable {
    /// Square image: 256x256 pixels.
    /// Only supported by DALL-E 2.
    case size256x256 = "256x256"

    /// Square image: 512x512 pixels.
    /// Only supported by DALL-E 2.
    case size512x512 = "512x512"

    /// Square image: 1024x1024 pixels.
    /// Supported by both DALL-E 2 and DALL-E 3.
    case size1024x1024 = "1024x1024"

    /// Landscape image: 1792x1024 pixels.
    /// Only supported by DALL-E 3.
    case size1792x1024 = "1792x1024"

    /// Portrait image: 1024x1792 pixels.
    /// Only supported by DALL-E 3.
    case size1024x1792 = "1024x1792"
}

/// The style of the generated images.
///
/// This setting is only supported for DALL-E 3 and affects the artistic style
/// of the generated images.
public enum Style: String, Codable, Sendable {
    /// Vivid style produces more hyper-real and dramatic images.
    /// This is the default style for DALL-E 3.
    case vivid

    /// Natural style produces more natural, less hyper-real looking images.
    case natural
}

/// The response from an image generation, edit, or variation request.
///
/// Contains an array of generated images along with metadata about when they were created.
public struct ImageResponse: Codable, Sendable {
    /// Unix timestamp (in seconds) of when the images were created.
    public let created: Int

    /// Array of generated image data.
    /// Each element represents one generated image.
    public let data: [ImageData]
}

/// Data for a single generated image.
///
/// Contains either a URL to the image or the base64-encoded image data,
/// depending on the response format requested.
public struct ImageData: Codable, Sendable {
    /// The URL of the generated image.
    /// Present when response format is set to "url".
    /// URLs expire after one hour.
    public let url: String?

    /// Base64-encoded JSON string of the generated image.
    /// Present when response format is set to "b64_json".
    public let b64Json: String?

    /// The revised prompt used to generate the image.
    /// Only present for DALL-E 3 generations where the model revised the prompt
    /// for safety or clarity reasons.
    public let revisedPrompt: String?
}
