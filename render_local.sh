#!/usr/bin/env bash
set -e
set -x

own_dir="$(readlink -f "$(dirname "${0}")")"

repo_root="${own_dir}/.."
bin_dir="${repo_root}/bin"

promote_target='snapshot'      # snapshot, release --> glci.model.PipelineFlavour
publishing_actions='manifests' # manifests, image, release --> glci.model.BuildType
gardenlinux_dir=.
branch_name="main"
flavour_set='all'     # -> $gardenlinux_dir/flavours.yaml
gardenlinux_tkn_ws='gardenlinux'

export PATH="${PATH}:${bin_dir}"

function cleanup_pipelineruns {
  echo "purging old pipelineruns"
  tkn \
    --namespace "${gardenlinux_tkn_ws}" \
    pipelineruns \
    delete \
    --force \
    --all \
    --keep 20
}

echo "render pipelines"
echo "gardenlinux_dir: ${gardenlinux_dir}"
pwd

head_commit="$(git rev-parse @)"
echo "Head commit_ ${head_commit}"


pipeline_cfg="${gardenlinux_dir}/flavours.yaml"
outfile='rendered_pipeline.yaml'

credentials_namespace='test'
credentials_outfile='config.json'

# injected from pipeline_definitions
promote_target="${promote_target:-snapshot}"
publishing_actions="${publishing_actions:-manifests}"

if [ ! -z "${VERSION:-}" ]; then
  EXTRA_ARGS="--version=${VERSION}"
fi

# cleanup_pipelineruns

head_commit="$(git rev-parse @)"

pipeline_run="$PWD/pipeline_run.yaml"
rendered_task="$PWD/rendered_task.yaml"

# create pipeline-run for current commit
ci/render_pipeline_run.py $EXTRA_ARGS \
  --branch "${branch_name}" \
  --committish "${head_commit}" \
  --cicd-cfg 'default' \
  --flavour-set "${flavour_set}" \
  --promote-target "${promote_target}" \
  --publishing-action "${publishing_actions}" \
  --outfile "${pipeline_run}"

ci/render_pipelines.py \
  --pipeline_cfg "${pipeline_cfg}" \
  --flavour-set "${flavour_set}" \
  --cicd-cfg 'default' \
  --outfile "${outfile}"

ci/render_task.py \
  --outfile "${rendered_task}"

ci/render_credentials.py \
  --outfile "${credentials_outfile}"

kubectl create secret generic secrets \
  -n "${credentials_namespace}" \
  --from-file=config.json="${credentials_outfile}"

# XXX hardcode other resources for now

for manifest in \
  "${rendered_task}" \
  "${outfile}" \
  "${pipeline_run}"
do
  kubectl apply -f "${manifest}"
done

echo 'done: refreshed pipeline(s) and created a new pipeline-run for current commit'