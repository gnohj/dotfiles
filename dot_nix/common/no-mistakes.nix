{ pkgs, lib }:

pkgs.buildGoModule {
  pname = "no-mistakes";
  version = "1.32.2";

  src = pkgs.fetchFromGitHub {
    owner = "kunchenguid";
    repo = "no-mistakes";
    rev = "v1.32.2";
    hash = "sha256-bXeE/tX1xXrDXWr+c9UVftQaEGX/0I6s8aq7oTHG1aI=";
  };

  vendorHash = "sha256-NZOYxNYvt4192uqKBdKRxdgrKFvWx3585psdCnRdPSM=";

  subPackages = [ "cmd/no-mistakes" ];
}
