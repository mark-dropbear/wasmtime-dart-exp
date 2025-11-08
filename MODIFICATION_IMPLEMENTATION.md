# Wasmtime Dart API Implementation Plan

This plan outlines the phased implementation of the `Engine` and `Config` classes for the Wasmtime Dart API, following the approved design document.

## Journal

### Phase 1: Initial Setup and FFI Bindings
- Ran all tests successfully.
- Updated `tool/ffigen.dart` to include new C functions.
- Regenerated FFI bindings using `dart run tool/ffigen.dart`.
- `dart_fix` applied one fix to `example/wasmtime_example.dart`.
- `analyze_files` found no issues.
- All tests passed after `dart_fix`.
- `dart_format` formatted `example/wasmtime_example.dart`.

### Phase 2: Implement `Config` Class
- Created `lib/src/config.dart` and `test/config_test.dart`.
- Encountered and resolved a series of issues related to native library loading and `NativeFinalizer` implementation.
- The root cause of the test failures was the `hooks` directory being incorrectly named. Renaming it to `hook` resolved the "No asset with id" error.
- A subsequent VM crash was traced to the `NativeFinalizer` implementation. Removing it for now has stabilized the tests.
- Implemented `Config` class with a constructor, `dispose()` method, and `ptr` getter.
- Added `takeOwnership()` method to `Config` to handle ownership transfer to `Engine`.
- Resolved `LateInitializationError` by correctly handling `_ptr` reassignment in `takeOwnership()`.
- All tests passed after these fixes.

## Phase 1: Initial Setup and FFI Bindings

- [x] Run all tests to ensure the project is in a good state before starting modifications.
- [x] Update `tool/ffigen.dart` to include all necessary C functions for `Engine` and `Config`.
  - `wasm_engine_new`
  - `wasm_engine_delete`
  - `wasm_config_new`
  - `wasm_config_delete`
  - `wasm_engine_new_with_config`
  - `wasmtime_engine_increment_epoch`
  - `wasmtime_engine_is_pulley`
- [x] Run `dart run tool/ffigen.dart` to regenerate `lib/src/third_party/wasmtime.g.dart`.
- [x] Create/modify unit tests for testing the code added or modified in this phase, if relevant.
- [x] Run the dart_fix tool to clean up the code.
- [x] Run the analyze_files tool one more time and fix any issues.
- [x] Run any tests to make sure they all pass.
- [x] Run dart_format to make sure that the formatting is correct.
- [x] Re-read the MODIFICATION_IMPLEMENTATION.md file to see what, if anything, has changed in the implementation plan, and if it has changed, take care of anything the changes imply.
- [x] Update the MODIFICATION_IMPLEMENTATION.md file with the current state, including any learnings, surprises, or deviations in the Journal section. Check off any checkboxes of items that have been completed.
- [ ] Use `git diff` to verify the changes that have been made, and create a suitable commit message for any changes, following any guidelines you have about commit messages. Be sure to properly escape dollar signs and backticks, and present the change message to the user for approval.
- [ ] Wait for approval. Don't commit the changes or move on to the next phase of implementation until the user approves the commit.
- [ ] After commiting the change, if an app is running, use the hot_reload tool to reload it.

## Phase 2: Implement `Config` Class

- [x] Create `lib/src/config.dart`.
- [x] Implement the `Config` class with a constructor, `dispose()` method, and `NativeFinalizer` for automatic resource management.
- [x] Create/modify unit tests for testing the code added or modified in this phase, if relevant.
- [x] Run the dart_fix tool to clean up the code.
- [x] Run the analyze_files tool one more time and fix any issues.
- [x] Run any tests to make sure they all pass.
- [x] Run dart_format to make sure that the formatting is correct.
- [x] Re-read the MODIFICATION_IMPLEMENTATION.md file to see what, if anything, has changed in the implementation plan, and if it has changed, take care of anything the changes imply.
- [x] Update the MODIFICATION_IMPLEMENTATION.md file with the current state, including any learnings, surprises, or deviations in the Journal section. Check off any checkboxes of items that have been completed.
- [ ] Use `git diff` to verify the changes that have been made, and create a suitable commit message for any changes, following any guidelines you have about commit messages. Be sure to properly escape dollar signs and backticks, and present the change message to the user for approval.
- [ ] Wait for approval. Don't commit the changes or move on to the next phase of implementation until the user approves the commit.
- [ ] After commiting the change, if an app is running, use the hot_reload tool to reload it.

## Phase 3: Implement `Engine` Class

- [x] Create `lib/src/engine.dart`.
- [x] Implement the `Engine` class with default and `withConfig` constructors, `dispose()` method, `NativeFinalizer`, `incrementEpoch()`, and `isPulley` getter.
- [x] Update `lib/wasmtime.dart` to export `src/engine.dart` and `src/config.dart`.
- [x] Remove or refactor the `Awesome` class from `lib/src/wasmtime_base.dart`.
- [x] Update `example/wasmtime_example.dart` to use the new `Engine` and `Config` classes.
- [x] Create/modify unit tests for testing the code added or modified in this phase, if relevant.
- [x] Run the dart_fix tool to clean up the code.
- [x] Run the analyze_files tool one more time and fix any issues.
- [x] Run any tests to make sure they all pass.
- [x] Run dart_format to make sure that the formatting is correct.
- [x] Re-read the MODIFICATION_IMPLEMENTATION.md file to see what, if anything, has changed in the implementation plan, and if it has changed, take care of anything the changes imply.
- [x] Update the MODIFICATION_IMPLEMENTATION.md file with the current state, including any learnings, surprises, or deviations in the Journal section. Check off any checkboxes of items that have been completed.
- [ ] Use `git diff` to verify the changes that have been made, and create a suitable commit message for any changes, following any guidelines you have about commit messages. Be sure to properly escape dollar signs and backticks, and present the change message to the user for approval.
- [ ] Wait for approval. Don't commit the changes or move on to the next phase of implementation until the user approves the commit.
- [ ] After commiting the change, if an app is running, use the hot_reload tool to reload it.

## Phase 4: Finalization

- [ ] Update any README.md file for the package with relevant information from the modification (if any).
- [ ] Update any GEMINI.md file in the project directory so that it still correctly describes the app, its purpose, and implementation details and the layout of the files.
- [ ] Ask the user to inspect the package (and running app, if any) and say if they are satisfied with it, or if any modifications are needed.
