{ pkgs, lib }:

pkgs.buildGoModule rec {
  pname = "treehouse";
  version = "2.0.0";

  src = pkgs.fetchFromGitHub {
    owner = "kunchenguid";
    repo = "treehouse";
    rev = "v${version}";
    hash = "sha256-G9NqwTzwqgr8rt+HlhXAFtR6ajYjZ6LfHdNKhaPfEls=";
  };

  vendorHash = "sha256-fH93/19rZY/jduF4ZS0RLrqBWdCjz6XYnoN+3KPd4Lg=";

  subPackages = [ "." ];

  # Same as no-mistakes.nix: unstamped builds report "dev" to anything that version-checks treehouse.
  ldflags = [ "-X main.version=${version}" ];
}
