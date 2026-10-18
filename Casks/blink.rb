# Homebrew cask. This repository doubles as a tap:
#   brew tap marek-e/blink https://github.com/marek-e/blink
#   brew install --cask marek-e/blink/blink
# The release workflow checks that `version` matches the tag being released.
cask "blink" do
  version "1.3.0"
  sha256 :no_check

  url "https://github.com/marek-e/blink/releases/download/v#{version}/Blink-#{version}.dmg"
  name "Blink"
  desc "Browser picker and link router"
  homepage "https://github.com/marek-e/blink"

  depends_on macos: :sonoma

  app "Blink.app"

  uninstall quit: "dev.melmayan.blink"

  zap trash: "~/Library/Application Support/dev.melmayan.blink"

  caveats <<~EOS
    Open Blink once to choose your browsers and make it the default browser.
    If macOS says Blink can't be opened, see "Install" in https://github.com/marek-e/blink#install
  EOS
end
