extension TSD_ImageArchive {
  var isWebVideo: Bool {
    return self.hasTSA_WebVideoInfo_webVideoInfo
  }

  var webVideoAttributes: [String: String]? {
    guard self.isWebVideo else { return nil }
    let webVideoInfo = self.TSA_WebVideoInfo_webVideoInfo

    guard webVideoInfo.hasAttribution else { return nil }

    let attribution = webVideoInfo.attribution
    var attributes: [String: String] = [:]

    if attribution.hasTitle {
      attributes["title"] = attribution.title
    }

    if attribution.hasDescriptionText {
      attributes["description"] = attribution.descriptionText
    }

    if attribution.hasExternalURL {
      attributes["externalURL"] = attribution.externalURL
    }

    if attribution.hasAuthorName {
      attributes["authorName"] = attribution.authorName
    }

    if attribution.hasAuthorURL {
      attributes["authorURL"] = attribution.authorURL
    }
    return attributes.isEmpty ? nil : attributes
  }
}
