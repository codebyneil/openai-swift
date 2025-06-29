import Foundation
import OpenAICore

extension OpenAI {
    /// Generates one or more images from a text prompt.
    ///
    /// This method uses OpenAI's DALL-E models to create images based on your text description.
    /// You can specify various parameters like size, quality, and style depending on the model used.
    ///
    /// Example:
    /// ```swift
    /// let openAI = OpenAI(apiKey: "your-api-key")
    /// let request = ImageGenerationRequest(
    ///     prompt: "A white siamese cat sitting on a windowsill during sunset",
    ///     model: "dall-e-3",
    ///     size: .size1024x1024,
    ///     quality: .hd,
    ///     n: 1
    /// )
    ///
    /// do {
    ///     let response = try await openAI.createImage(request)
    ///     if let imageURL = response.data.first?.url {
    ///         print("Generated image URL: \(imageURL)")
    ///     }
    /// } catch {
    ///     print("Error generating image: \(error)")
    /// }
    /// ```
    ///
    /// - Parameter request: The image generation request containing the prompt and optional parameters.
    /// - Returns: An `ImageResponse` containing the generated image(s).
    /// - Throws: An error if the request fails or the response cannot be decoded.
    ///
    /// - Note: Generated image URLs expire after one hour. If you need persistent storage,
    ///         download the images or use the base64 response format.
    public func createImage(_ request: ImageGenerationRequest) async throws -> ImageResponse {
        let (data, response) = try await makeRequest(endpoint: "images/generations", body: request)
        return try decodeResponse(ImageResponse.self, from: data, response: response)
    }

    /// Edits an existing image based on a text prompt.
    ///
    /// This method allows you to modify specific parts of an image by providing a text description
    /// of the desired changes. You can optionally provide a mask to indicate which areas should be edited.
    ///
    /// Example:
    /// ```swift
    /// let openAI = OpenAI(apiKey: "your-api-key")
    ///
    /// // Load your image and mask data
    /// let imageData = try Data(contentsOf: imageURL)
    /// let maskData = try Data(contentsOf: maskURL)
    ///
    /// let request = ImageEditRequest(
    ///     image: imageData,
    ///     prompt: "Add a red sports car in the empty parking space",
    ///     mask: maskData,
    ///     size: .size1024x1024
    /// )
    ///
    /// do {
    ///     let response = try await openAI.editImage(request)
    ///     if let editedImageURL = response.data.first?.url {
    ///         print("Edited image URL: \(editedImageURL)")
    ///     }
    /// } catch {
    ///     print("Error editing image: \(error)")
    /// }
    /// ```
    ///
    /// - Parameter request: The image edit request containing the original image, prompt, and optional parameters.
    /// - Returns: An `ImageResponse` containing the edited image(s).
    /// - Throws: An error if the request fails or the response cannot be decoded.
    ///
    /// - Important: Both the image and mask must be valid PNG images less than 4MB in size.
    ///              The mask should use transparency (alpha channel) to indicate areas to edit.
    ///              Fully transparent pixels (alpha=0) indicate areas that should be edited.
    ///
    /// - Note: Image editing is only supported by DALL-E 2.
    public func editImage(_ request: ImageEditRequest) async throws -> ImageResponse {
        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(request.image)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(request.prompt)\r\n".data(using: .utf8)!)

        if let mask = request.mask {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"mask\"; filename=\"mask.png\"\r\n".data(
                    using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(mask)
            body.append("\r\n".data(using: .utf8)!)
        }

        if let model = request.model {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(model)\r\n".data(using: .utf8)!)
        }

        if let n = request.n {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"n\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(n)\r\n".data(using: .utf8)!)
        }

        if let size = request.size {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(size.rawValue)\r\n".data(using: .utf8)!)
        }

        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(
                    using: .utf8)!)
            body.append("\(responseFormat.rawValue)\r\n".data(using: .utf8)!)
        }

        if let user = request.user {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"user\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(user)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let url = baseURL.appendingPathComponent("images/edits")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(ImageResponse.self, from: data, response: response)
    }

    /// Creates variations of an existing image.
    ///
    /// This method generates new images that are variations of the provided source image.
    /// The variations maintain the general composition and style of the original while
    /// introducing creative differences in details, colors, and other visual elements.
    ///
    /// Example:
    /// ```swift
    /// let openAI = OpenAI(apiKey: "your-api-key")
    ///
    /// // Load your source image
    /// let imageData = try Data(contentsOf: originalImageURL)
    ///
    /// let request = ImageVariationRequest(
    ///     image: imageData,
    ///     n: 3,
    ///     size: .size1024x1024,
    ///     responseFormat: .url
    /// )
    ///
    /// do {
    ///     let response = try await openAI.createImageVariation(request)
    ///     for (index, imageData) in response.data.enumerated() {
    ///         if let url = imageData.url {
    ///             print("Variation \(index + 1): \(url)")
    ///         }
    ///     }
    /// } catch {
    ///     print("Error creating variations: \(error)")
    /// }
    /// ```
    ///
    /// - Parameter request: The image variation request containing the source image and optional parameters.
    /// - Returns: An `ImageResponse` containing the generated variation(s).
    /// - Throws: An error if the request fails or the response cannot be decoded.
    ///
    /// - Important: The source image must be a valid PNG image less than 4MB in size and must be square.
    ///              Non-square images will be rejected by the API.
    ///
    /// - Note: Image variations are only supported by DALL-E 2. The variations will have the same
    ///         dimensions as specified in the size parameter (defaulting to 1024x1024).
    public func createImageVariation(_ request: ImageVariationRequest) async throws -> ImageResponse
    {
        let boundary = UUID().uuidString
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"image\"; filename=\"image.png\"\r\n".data(
                using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(request.image)
        body.append("\r\n".data(using: .utf8)!)

        if let model = request.model {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(model)\r\n".data(using: .utf8)!)
        }

        if let n = request.n {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"n\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(n)\r\n".data(using: .utf8)!)
        }

        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(
                    using: .utf8)!)
            body.append("\(responseFormat.rawValue)\r\n".data(using: .utf8)!)
        }

        if let size = request.size {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(size.rawValue)\r\n".data(using: .utf8)!)
        }

        if let user = request.user {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"user\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(user)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let url = baseURL.appendingPathComponent("images/variations")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let organization = organization {
            request.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(ImageResponse.self, from: data, response: response)
    }
}
