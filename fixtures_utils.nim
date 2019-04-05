# beacon_chain
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  # Standard lib
  json, streams, strutils,
  # Dependencies
  yaml.tojson,
  # Status libs
  blscurve, nimcrypto, byteutils,
  eth/common, serialization, json_serialization,
  # Beacon chain internals
  # submodule in nim-beacon-chain/tests/official/fixtures/
  ../../../beacon_chain/spec/[datatypes, crypto, digest]

export nimcrypto.toHex

type
  # TODO: use ref object to avoid allocating
  #       so much on the stack - pending https://github.com/status-im/nim-json-serialization/issues/3
  StateTest* = object
    title*: string
    summary*: string
    test_suite*: string
    fork*: string
    test_cases*: seq[TestCase]
  
  TestConstants* = object
    SHARD_COUNT*: int
    TARGET_COMMITTEE_SIZE*: int
    MAX_BALANCE_CHURN_QUOTIENT*: int
    MAX_INDICES_PER_SLASHABLE_VOTE*: int
    MAX_EXIT_DEQUEUES_PER_EPOCH*: int
    SHUFFLE_ROUND_COUNT*: int
    DEPOSIT_CONTRACT_TREE_DEPTH*: int
    MIN_DEPOSIT_AMOUNT*: uint64
    MAX_DEPOSIT_AMOUNT*: uint64
    FORK_CHOICE_BALANCE_INCREMENT*: uint64
    EJECTION_BALANCE*: uint64
    GENESIS_FORK_VERSION*: uint32
    GENESIS_SLOT*: Slot
    GENESIS_EPOCH*: Epoch
    GENESIS_START_SHARD*: uint64
    BLS_WITHDRAWAL_PREFIX_BYTE*: array[1, byte]
    SECONDS_PER_SLOT*: uint64
    MIN_ATTESTATION_INCLUSION_DELAY*: uint64
    SLOTS_PER_EPOCH*: int
    MIN_SEED_LOOKAHEAD*: int
    ACTIVATION_EXIT_DELAY*: int
    EPOCHS_PER_ETH1_VOTING_PERIOD*: uint64
    SLOTS_PER_HISTORICAL_ROOT*: int
    MIN_VALIDATOR_WITHDRAWABILITY_DELAY*: uint64
    PERSISTENT_COMMITTEE_PERIOD*: uint64
    LATEST_RANDAO_MIXES_LENGTH*: int
    LATEST_ACTIVE_INDEX_ROOTS_LENGTH*: int
    LATEST_SLASHED_EXIT_LENGTH*: int
    BASE_REWARD_QUOTIENT*: uint64
    WHISTLEBLOWER_REWARD_QUOTIENT*: uint64
    ATTESTATION_INCLUSION_REWARD_QUOTIENT*: uint64
    INACTIVITY_PENALTY_QUOTIENT*: uint64
    MIN_PENALTY_QUOTIENT*: int
    MAX_PROPOSER_SLASHINGS*: int
    MAX_ATTESTER_SLASHINGS*: int
    MAX_ATTESTATIONS*: int
    MAX_DEPOSITS*: int
    MAX_VOLUNTARY_EXITS*: int
    MAX_TRANSFERS*: int
    DOMAIN_BEACON_BLOCK*: SignatureDomain
    DOMAIN_RANDAO*: SignatureDomain
    DOMAIN_ATTESTATION*: SignatureDomain
    DOMAIN_DEPOSIT*: SignatureDomain
    DOMAIN_VOLUNTARY_EXIT*: SignatureDomain
    DOMAIN_TRANSFER*: SignatureDomain

  TestCase* = object
    name*: string
    config*: TestConstants
    verify_signatures*: bool
    initial_state*: BeaconState
    blocks*: seq[BeaconBlock]
    expected_state*: ExpectedState
  
  ExpectedState* = object
    ## TODO what is this?
    slot*: Slot

# #######################
# Default init
proc default*(T: typedesc): T = discard

# #######################
# JSON deserialization

proc readValue*[N: static int](r: var JsonReader, a: var array[N, byte]) {.inline.} =
  # Needed for;
  #   - BLS_WITHDRAWAL_PREFIX_BYTE
  #   - FOrk datatypes
  # TODO: are all bytes and bytearray serialized as hex?
  #       if so export that to nim-eth
  hexToByteArray(r.readValue(string), a)

proc parseStateTests*(jsonPath: string): StateTest =
  try:
    result = Json.loadFile(jsonPath, StateTest)
  except SerializationError as err:
    writeStackTrace()
    stderr.write "Json load issue for file \"", jsonPath, "\"\n"
    stderr.write err.formatMsg(jsonPath), "\n"
    quit 1

# #######################
# Yaml to JSON conversion

proc yamlToJson*(file: string): seq[JsonNode] =
  try:
    let fs = openFileStream(file)
    defer: fs.close()
    result = fs.loadToJson()
  except IOError:
    echo "Exception when reading file: " & file
    raise
  except OverflowError:
    echo "Overflow exception when parsing. Did you stringify 18446744073709551615 (-1)?"
    raise

when isMainModule:
  # Do not forget to stringify FAR_EPOCH_SLOT = 18446744073709551615 (-1) in the YAML file
  # And unstringify it in the produced JSON file

  import os, typetraits

  const
    # TODO: consume the whole YAML test and not just the first test
    DefaultYML = "tests/official/fixtures/json_tests/sanity-check_default-config_100-vals-first_test.yaml"
    DefaultOutputPath = "tests/official/fixtures/json_tests/sanity-check_default-config_100-vals-first_test.json"

  var fileName, outputPath: string
  if paramCount() == 0:
    fileName = DefaultYML
    outputPath = DefaultOutputPath
  elif paramCount() == 1:
    fileName = paramStr(1)
    outputPath = DefaultOutputPath
  elif paramCount() >= 2:
    fileName = paramStr(1)
    outputPath = paramStr(2)

  let jsonString = $DefaultYML.yamlToJson[0]
  DefaultOutputPath.writeFile jsonString

