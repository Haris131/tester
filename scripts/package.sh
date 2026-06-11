#!/bin/bash
set -e
cd "$GITHUB_WORKSPACE/artifacts"
ls -lh
tar czf "$GITHUB_WORKSPACE/${ARTIFACT_NAME}.tar.gz" *
