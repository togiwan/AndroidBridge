import Foundation

public enum WirelessHTMLRenderer {
    public static func pageHTML(
        sharedItems: [SharedDownloadItem],
        authenticated: Bool,
        sessionToken: String? = nil
    ) -> String {
        let pathPrefix = sessionToken.map { "/\($0)" } ?? ""
        let list = sharedItems.map { item in
            """
            <li>
              <span>\(escape(item.name))</span>
              <a href="\(pathPrefix)/download/\(item.id.uuidString)">Download</a>
            </li>
            """
        }.joined(separator: "\n")

        let authBlock = authenticated ? "" : """
        <section>
          <h2>Enter PIN</h2>
          <form method="POST" action="\(pathPrefix)/pin">
            <input name="pin" inputmode="numeric" autocomplete="one-time-code" maxlength="6">
            <button type="submit">Unlock</button>
          </form>
        </section>
        """

        let transferBlock = authenticated ? """
        <section>
          <h2>Send to Mac</h2>
          <form method="POST" action="\(pathPrefix)/upload" enctype="multipart/form-data">
            <input type="file" name="files" multiple>
            <button type="submit">Send</button>
          </form>
        </section>
        <section>
          <h2>Get from Mac</h2>
          <ul>
            \(list.isEmpty ? "<li>No files shared from Mac.</li>" : list)
          </ul>
        </section>
        """ : ""

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>AndroidBridge</title>
          <style>
            body { font-family: system-ui, sans-serif; margin: 24px; color: #171717; }
            h1 { font-size: 24px; }
            section { border-top: 1px solid #ddd; padding: 18px 0; }
            button, input { font: inherit; }
            li { margin: 10px 0; }
          </style>
        </head>
        <body>
          <h1>AndroidBridge</h1>
          \(authBlock)
          \(transferBlock)
        </body>
        </html>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
