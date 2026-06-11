# Smoke tests for the package scaffold. These exist so the test harness is
# green from day one and prove the datom dependency is reachable. They are
# expected to be replaced/extended as real gov_* functions land.

test_that("datomanager loads and depends on datom", {
  expect_true(requireNamespace("datomanager", quietly = TRUE))
  expect_true(requireNamespace("datom", quietly = TRUE))
})

test_that("the datom platform surface datomanager will orchestrate is present", {
  # The Phase 22 storage/repo extension API is the stable seam datomanager
  # calls into. If any of these disappear, the lift-out plan needs revisiting.
  platform_api <- c(
    "datom_storage_list",
    "datom_storage_copy",
    "datom_storage_verify",
    "datom_storage_delete_prefix",
    "datom_repo_set_data_store",
    "datom_repo_delete"
  )
  exported <- getNamespaceExports("datom")
  expect_true(all(platform_api %in% exported))
})
