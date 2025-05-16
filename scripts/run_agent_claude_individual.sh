#!/bin/bash

REPO_NAME=$1
TASK_NAME=$2
RUN=$3
LEVEL=$4

CURR_DIR=$(pwd)

export LLM_MODEL="anthropic/claude-3-7-sonnet-20250219"
export LLM_API_KEY=$ANTHROPIC_KEY
export LLM_INPUT_TOKEN_COST="0.000003"
export LLM_OUTPUT_TOKEN_COST="0.000015"
export AGENT_NAME="openhands_claude"

OPENHANDS_PATH=/home/ubuntu/OpenHands
REPOS_ROOT=/home/ubuntu/rexbench-repos
PATCHES_ROOT=/home/ubuntu/patches/${AGENT_NAME}
INSTRUCTIONS_ROOT=/home/ubuntu/instructions

echo "Creating PATCHES DIR $PATCHES_ROOT..."
mkdir -p $PATCHES_ROOT


cd $REPOS_ROOT
if [ ! -d "$REPOS_ROOT/${REPO_NAME}" ]; then
  echo "Cloning repo git@bitbucket.org:research-agents/${REPO_NAME}..."
  git clone git@bitbucket.org:research-agents/${REPO_NAME}
fi

REPO_PATH=${REPOS_ROOT}/${REPO_NAME}

cd $REPO_PATH
git pull

mkdir -p ${REPO_PATH}/trajectories/

mkdir -p ${PATCHES_ROOT}/${TASK_NAME}

export WORKSPACE_BASE=$REPO_PATH


echo "Copying instructions from ${INSTRUCTIONS_ROOT}/${TASK_NAME}/instructions-${LEVEL}.md"
cp ${INSTRUCTIONS_ROOT}/${TASK_NAME}/instructions-${LEVEL}.md $REPO_PATH/instructions.md


cd $OPENHANDS_PATH
echo "Running agent..."
docker run -it -e DEBUG=false -e SANDBOX_RUNTIME_CONTAINER_IMAGE=docker.all-hands.dev/all-hands-ai/runtime:0.34-nikolaik     -e SANDBOX_USER_ID=$(id -u)     -e WORKSPACE_MOUNT_PATH=$WORKSPACE_BASE     -e LLM_API_KEY=$LLM_API_KEY -e SAVE_TRAJECTORY_PATH="/opt/workspace_base/trajectories" -e AGENT="CodeWriteAgent"     -e LLM_MODEL=$LLM_MODEL   -e INPUT_COST_PER_TOKEN=$LLM_INPUT_TOKEN_COST -e OUTPUT_COST_PER_TOKEN=$LLM_OUTPUT_TOKEN_COST  -e LOG_ALL_EVENTS=true     -v $WORKSPACE_BASE:/opt/workspace_base     -v /var/run/docker.sock:/var/run/docker.sock     -v ~/.openhands-state:/.openhands-state     --add-host host.docker.internal:host-gateway     --name openhands-app-$(date +%Y%m%d%H%M%S) local/openhands     python -m openhands.core.main -c CodeWriteAgent  -t "Read the instructions in instructions.md and carry out the specified task."

echo "Creating patch at ${PATCHES_ROOT}/${TASK_NAME}/${LEVEL}/${AGENT_NAME}_${LEVEL}_run${RUN}.patch..."
cd $REPO_PATH
rm instructions.md
mkdir -p ${PATCHES_ROOT}/${TASK_NAME}/${LEVEL}
mv trajectories/*.json  ${PATCHES_ROOT}/${TASK_NAME}/${LEVEL}/${AGENT_NAME}_${LEVEL}_run${RUN}.json



git add .
git diff --cached > ${PATCHES_ROOT}/${TASK_NAME}/${LEVEL}/${AGENT_NAME}_${LEVEL}_run${RUN}.patch
git restore --staged .
git restore .
git clean -f

# Remove "/workspace" from any paths
sed -i 's|/workspace/|./|g' ${PATCHES_ROOT}/${TASK_NAME}/${level}/${AGENT_NAME}_${LEVEL}_run${RUN}.patch

cd $CURR_DIR

echo "Deleting ${REPO_PATH}"
rm -rf $REPO_PATH

