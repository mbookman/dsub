#!/bin/bash

# Copyright 2016 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset

# unit_flags.google.sh
#
# Collection of unit tests for dsub command-line flags
# specific to the google provider.

readonly SCRIPT_DIR="$(dirname "${0}")"

# Do standard test setup
source "${SCRIPT_DIR}/test_setup_unit.sh"

# Define a utility routine for running a test of the "--command" flag

function call_dsub() {
  local command="${1:-}"
  local script="${2:-}"
  local zones="${3:-}"
  local preemptible="${4:-}"
  local keep_alive="${5:-}"

  ZONES="${zones}" \
  run_dsub \
    "${preemptible:+--preemptible}" \
    ${keep_alive:+"--keep-alive" "${keep_alive}"} \
    --command "${command}" \
    --script "${script}" \
    --env TEST_NAME="${TEST_NAME}" \
    --dry-run \
    1> "${TEST_STDOUT}" \
    2> "${TEST_STDERR}"
}
readonly -f call_dsub

# Define tests

function test_with_command() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"'; then

    # Check that the output contains expected values
    local expected=$(echo -e '#!/bin/bash\necho "${TEST_NAME}"')
    assert_pipeline_environment_variable_equals \
      0 "_SCRIPT" "${expected}"

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_with_command

function test_zone_single() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-central1-f"; then

    # Check that the output contains expected values
    assert_err_value_equals \
      "[0].ephemeralPipeline.resources.zones.[0]" "us-central1-f"

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_zone_single

function test_zones_regional() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-central1-*"; then

    # Check that the output contains expected values
    local idx=0
    for zone in us-central1-a us-central1-b us-central1-c us-central1-f; do
      assert_err_value_equals \
        "[0].ephemeralPipeline.resources.zones.[${idx}]" ${zone}

      ((++idx))
    done

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_zones_regional

function test_zones_multi_regional() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-*"; then

    # Check that the output contains expected values
    local idx=0
    for zone in us-central1-a us-central1-b us-central1-c us-central1-f \
                us-east1-b us-east1-c us-east1-d \
                us-east4-a us-east4-b us-east4-c \
                us-west1-a us-west1-b; do
      assert_err_value_equals \
        "[0].ephemeralPipeline.resources.zones.[${idx}]" ${zone}

      ((++idx))
    done

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_zones_multi_regional

function test_preemptible() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-*" \
    "True"; then

    # Check that the output contains expected values
    assert_err_value_equals \
     "[0].ephemeralPipeline.resources.preemptible" "True"
    assert_err_value_equals \
     "[0].pipelineArgs.resources.preemptible" "True"

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_preemptible

function test_no_preemptible() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-*"; then

    # Check that the output contains expected values
    assert_err_value_equals \
     "[0].ephemeralPipeline.resources.preemptible" "False"
    assert_err_value_equals \
     "[0].pipelineArgs.resources.preemptible" "False"

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_preemptible

function test_keep_alive() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-*" \
    "" \
    3600; then

    # Check that the output contains expected values
    assert_err_value_equals \
     "[0].pipelineArgs.keep_vm_alive_on_failure_duration" "3600s"

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_keep_alive

function test_no_keep_alive() {
  local subtest="${FUNCNAME[0]}"

  if call_dsub \
    'echo "${TEST_NAME}"' \
    "" \
    "us-*"; then

    # Check that the output contains expected values
    assert_err_value_equals \
     "[0].pipelineArgs.keep_vm_alive_on_failure_duration" ""

    test_passed "${subtest}"
  else
    test_failed "${subtest}"
  fi
}
readonly -f test_no_keep_alive

# Run the tests
trap "exit_handler" EXIT

mkdir -p "${TEST_TMP}"

echo
test_with_command

echo
test_zone_single
test_zones_regional
test_zones_multi_regional

echo
test_preemptible
test_no_preemptible

echo
test_keep_alive
test_no_keep_alive
