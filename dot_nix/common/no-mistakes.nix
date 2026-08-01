{ pkgs, lib }:

pkgs.buildGoModule rec {
  pname = "no-mistakes";
  version = "1.32.2";

  src = pkgs.fetchFromGitHub {
    owner = "kunchenguid";
    repo = "no-mistakes";
    rev = "v${version}";
    hash = "sha256-bXeE/tX1xXrDXWr+c9UVftQaEGX/0I6s8aq7oTHG1aI=";
  };

  vendorHash = "sha256-NZOYxNYvt4192uqKBdKRxdgrKFvWx3585psdCnRdPSM=";

  subPackages = [ "cmd/no-mistakes" ];

  # Upstream's Makefile stamps this; unstamped it self-reports "dev" and version checks (firstmate needs >=1.31.2) fail.
  ldflags = [ "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.Version=${version}" ];
}
