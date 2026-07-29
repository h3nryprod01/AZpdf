cask "azpdf" do
  version "1.1.0"
  sha256 "bbddd76ae4875e520ad3dcf0711f435f6f700a6775eabd84fc196247eccbfef5"

  url "https://github.com/h3nryprod01/AZpdf/releases/download/v#{version}/AZpdf-macOS.zip"
  name "AZpdf"
  desc "Local-first PDF reader and editor"
  homepage "https://github.com/h3nryprod01/AZpdf"

  # The binary is arm64-only; without this the cask would install on Intel
  # and fail at launch with no useful message.
  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "AZpdf.app"

  zap trash: [
    "~/Library/Application Support/AZpdf",
    "~/Library/Preferences/org.azpdf.mac.plist",
    "~/Library/Saved Application State/org.azpdf.mac.savedState",
  ]
end
