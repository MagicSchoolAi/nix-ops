# [supabase-cli](https://github.com/supabase/cli) is the main CLI interface for [supabase](https://supabase.com)
{ lib
, buildGoModule
, installShellFiles
, fetchFromGitHub
, testers
, supabase-cli
}:

buildGoModule rec {
  pname = "supabase-cli-stable";
  version = "2.106.0";

  src = fetchFromGitHub {
    owner = "supabase";
    repo = "cli";
    rev = "v${version}";
    hash = "sha256-F6/7/NEd+MENOz+TVI5xkBRKwhhnzs57cECn4cEhwYg=";
  };

  # Upstream moved the Go CLI into a monorepo subdirectory at v2.101.0.
  sourceRoot = "${src.name}/apps/cli-go";

  vendorHash = "sha256-B8GMwIrPM5RM0XYjbr8E0yBBNFGBk0xOu/6DdjeO2y4=";

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/supabase/cli/internal/utils.Version=${version}"
  ];

  doCheck = false; # tests are trying to connect to localhost

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    mv $out/bin/{cli,supabase}

    installShellCompletion --cmd supabase \
      --bash <($out/bin/supabase completion bash) \
      --fish <($out/bin/supabase completion fish) \
      --zsh <($out/bin/supabase completion zsh)
  '';

  passthru = {
    tests.version = testers.testVersion {
      package = supabase-cli;
    };
  };

  meta = with lib; {
    description = "Supabase CLI. Manage postgres migrations, run Supabase locally, deploy edge functions. Postgres backups. Generating types from your database schema";
    homepage = "https://github.com/supabase/cli";
    license = licenses.mit;
    maintainers = with maintainers; [ jpetrucciani ];
    mainProgram = "supabase";
  };
}
