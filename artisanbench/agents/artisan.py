from artisan.run import run_with_artisan as _run_with_artisan

def run_with_artisan(
    workspace_dir: str,
    table_path: str,
    paper_path: str,
    artifact_url: str,
    interactive: bool,
    model_name: str | None = None,
    prompt_path: str | None = None,
    without_judge: bool = False,
    ablation: str | None = None,
):
    return _run_with_artisan(
        workspace_dir=workspace_dir,
        table_path=table_path,
        paper_path=paper_path,
        artifact_url=artifact_url,
        interactive=interactive,
        model_name=model_name,
        prompt_path=prompt_path,
        without_judge=without_judge,
        ablation=ablation,
    )
