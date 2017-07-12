defmodule Mix.Tasks.Compile.Erlydtl do
  use Mix.Task

  @recursive true
  @manifest ".compile.erlydtl"

  def manifests, do: [manifest()]
  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)

  defp update_manifest(manifest, new_files) do
    new_files = :ordsets.from_list(new_files)
    case File.read(manifest) do
      {:ok, contents} ->
        old_files = String.split(contents, "\n")
        Enum.each(old_files -- new_files, &File.rm/1)
      {:error, _} ->
        Path.dirname(manifest) |> File.mkdir_p!
    end

    File.write!(manifest, Enum.join(new_files, "\n"))
  end

  def clean do
    Mix.Compilers.Erlang.clean(manifest())
  end

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [force: :boolean])
    verbose = opts[:verbose]
    force = opts[:force]
    ext = "dtl"

    project = Mix.Project.config
    source_paths = project[:dtl_path] || "templates"
    dest = Mix.Project.compile_path(project)
    suffix = "_dtl"

    entities = for file <- Mix.Utils.extract_files([source_paths], [ext]) do
      module = (Path.basename(file) |> Path.rootname("." <> ext)) <> suffix
      target = Path.join(dest, module <> ".beam")

      if force || Mix.Utils.stale?([file], [target]) do
        {:stale, file, target, module}
      else
        {:ok, file, target, module}
      end
    end

    update_manifest(manifest(), Enum.map(entities, fn {_, _, target, _} -> target end))

    stale = for {:stale, src, _, module} <- entities, do: {src, module}
    if stale != [] do
      Mix.Utils.compiling_n(length(stale), ext)
      Mix.Project.ensure_structure()
      File.mkdir_p!(dest)
      ensure_erlydtl()

      results = for {src, module} <- stale do
        case :erlydtl.compile(to_charlist(src), to_charlist(module),
              [{:out_dir, to_charlist(dest)}, :report]) do
          {:ok, _} ->
            verbose && Mix.shell.info "Compiled #{src}"
            :ok
          :error ->
            Mix.shell.error "Error while compiling #{src}"
            :error
        end
      end

      if :error in results do
        Mix.raise "Encountered compilation errors"
      end
      :ok
    end
  end

  defp ensure_erlydtl do
    with nil <- Application.get_application(:erlydtl),
         {:error, _} <- Application.ensure_all_started(:erlydtl) do
      case Mix.Project.deps_paths().erlydtl do
        nil ->
          Mix.shell.error("Can't find erlydtl project in deps")
        dep ->
          true = Code.append_path(Path.join(dep, "ebin"))
          {:ok, _} = Application.ensure_all_started(:erlydtl)
      end
    end
  end
end
